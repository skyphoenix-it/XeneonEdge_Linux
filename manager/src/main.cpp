// Xeneon Edge Manager — a standalone companion desktop app to manage the Edge
// hub: build/reorder the widget layout, tune appearance, upload images, and set
// display/startup options. It edits the SAME config the hub reads (via the Rust
// core) and, when the hub is running, stays in live sync over the hub's local
// control socket (pushes its own edits, pulls the hub's). Works with or without
// the hub running.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QScreen>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QDateTime>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QTextStream>
#include <QTimer>
#include <QImage>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QLocalSocket>

#include "xeneon_core.h"

// --- RAII string wrapper (mirrors the hub's) ---
class XeneonString {
    char* ptr;
public:
    explicit XeneonString(char* p) : ptr(p) {}
    ~XeneonString() { if (ptr) xeneon_string_free(ptr); }
    XeneonString(const XeneonString&) = delete;
    XeneonString& operator=(const XeneonString&) = delete;
    QString qstring() const { return ptr ? QString::fromUtf8(ptr) : QString(); }
};

// --- ManagerBackend ---
// Presents the SAME interface the hub's ConfigBridge exposes (uiState/
// saveUiState/starterLayout/configJson) so the shared DashboardStore.qml drives
// it unchanged, plus display/image/startup operations and LIVE two-way sync with
// a running hub (push our edits + pull the hub's over the control socket, plus a
// file watcher for the offline case).
class ManagerBackend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool hubConnected READ hubConnected NOTIFY hubConnectedChanged)
public:
    explicit ManagerBackend(QObject* parent = nullptr) : QObject(parent) {
        m_config = xeneon_config_load();
        if (!m_config)
            qCritical() << "Manager: failed to load config";

        XeneonString cd(xeneon_config_dir());
        m_configPath = cd.qstring() + "/config.toml";

        m_sock = new QLocalSocket(this);
        connect(m_sock, &QLocalSocket::connected, this, [this] {
            m_hubConnected = true;
            emit hubConnectedChanged();
            // Flush any edit made while the socket was down, then pull the hub's
            // authoritative state so we don't overwrite device-side changes.
            if (!m_pendingPush.isEmpty()) {
                writeMsg(QJsonObject{{"type", "setUiState"}, {"state", m_pendingPush}});
                m_pendingPush.clear();
            }
            syncFromHub();
        });
        connect(m_sock, &QLocalSocket::disconnected, this, [this] {
            m_hubConnected = false; emit hubConnectedChanged();
        });
        connect(m_sock, &QLocalSocket::errorOccurred, this, [this](QLocalSocket::LocalSocketError) {
            m_hubConnected = false; emit hubConnectedChanged();
        });
        connect(m_sock, &QLocalSocket::readyRead, this, &ManagerBackend::onSocketReadyRead);

        // Reconnect loop so the "connected" indicator recovers when the hub starts
        // AFTER the Manager (or restarts) — the ctor connect alone isn't enough.
        auto* reconnect = new QTimer(this);
        reconnect->setInterval(2000);
        connect(reconnect, &QTimer::timeout, this, [this] { tryConnectHub(); });
        reconnect->start();

        // Gentle periodic pull so device-side edits on the hub appear in the
        // Manager (getUiState is cheap; QML only reloads when the state differs).
        auto* pull = new QTimer(this);
        pull->setInterval(4000);
        connect(pull, &QTimer::timeout, this, [this] { syncFromHub(); });
        pull->start();

        // Watch the config file so an OFFLINE external change (e.g. hub shutdown
        // save) is reflected. When the hub is connected we prefer getUiState.
        m_watcher = new QFileSystemWatcher(this);
        if (QFile::exists(m_configPath)) m_watcher->addPath(m_configPath);
        connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this] {
            // Atomic saves rename over the file and drop the watch — re-add it.
            QTimer::singleShot(60, this, [this] {
                if (!m_watcher->files().contains(m_configPath) && QFile::exists(m_configPath))
                    m_watcher->addPath(m_configPath);
                if (QDateTime::currentMSecsSinceEpoch() < m_ignoreWatchUntilMs) return; // our own write
                if (m_hubConnected) return;   // IPC keeps us in sync when connected
                reloadConfig();
            });
        });

        // Live display hotplug → Display tab refresh.
        connect(qApp, &QGuiApplication::screenAdded, this, [this](QScreen*) { emit screensChanged(); });
        connect(qApp, &QGuiApplication::screenRemoved, this, [this](QScreen*) { emit screensChanged(); });

        tryConnectHub();
    }
    ~ManagerBackend() override {
        if (m_config) xeneon_config_free(m_config);
    }

    bool hubConnected() const { return m_hubConnected; }

    // Dev/doc affordances (headless capture).
    Q_INVOKABLE QString grabPath() const { return qEnvironmentVariable("XENEON_GRAB"); }
    Q_INVOKABLE int startTab() const { return qEnvironmentVariable("XENEON_TAB", "0").toInt(); }
    Q_INVOKABLE QString autoConfig() const { return qEnvironmentVariable("XENEON_CFG"); }

    // Live system metrics (same source + JSON shape the hub uses).
    Q_INVOKABLE QString metricsJson() const {
        MetricsHandle* m = xeneon_metrics_collect();
        if (!m) return QStringLiteral("{}");
        XeneonString s(xeneon_metrics_to_json(m));
        xeneon_metrics_free(m);
        return s.qstring();
    }

    // ── configBridge-compatible surface (DashboardStore uses these) ──
    Q_INVOKABLE QString uiState() const {
        if (!m_config) return QString();
        XeneonString s(xeneon_config_get_ui_state(m_config));
        return s.qstring();
    }
    Q_INVOKABLE bool saveUiState(const QString& json) {
        if (!m_config) return false;
        xeneon_config_set_ui_state(m_config, json.toUtf8().constData());
        markSelfWrite();
        bool ok = xeneon_config_save(m_config) == 0;
        if (!ok) qWarning() << "Manager: failed to persist UI state";
        pushLive(json);   // live-update a running hub (buffers if not yet connected)
        return ok;
    }
    Q_INVOKABLE QString starterLayout() const {
        if (!m_config) return QString();
        XeneonString s(xeneon_config_get_starter_layout(m_config));
        return s.qstring();
    }
    Q_INVOKABLE QString configJson() const {
        if (!m_config) return QString();
        XeneonString s(xeneon_config_to_json(m_config));
        return s.qstring();
    }
    // Pull the hub's current UI state over IPC (called on connect + window focus).
    Q_INVOKABLE void syncFromHub() {
        if (m_sock->state() == QLocalSocket::ConnectedState)
            writeMsg(QJsonObject{{"type", "getUiState"}});
    }

    // ── Display / startup settings ──
    Q_INVOKABLE QString screensJson() const {
        // Headless/offscreen exposes a single bogus 800x800 screen — hide it so the
        // Display tab doesn't offer a garbage target in dev/capture runs.
        if (QGuiApplication::platformName().contains("offscreen", Qt::CaseInsensitive))
            return QStringLiteral("[]");
        QJsonArray arr;
        const auto screens = QGuiApplication::screens();
        QScreen* primary = QGuiApplication::primaryScreen();
        for (auto* s : screens) {
            arr.append(QJsonObject{
                {"name", s->name()},
                {"model", s->model()},
                {"manufacturer", s->manufacturer()},
                {"serial", s->serialNumber()},
                {"width", s->size().width()},
                {"height", s->size().height()},
                {"primary", s == primary},
                {"isEdge", (s->size().width() == 2560 && s->size().height() == 720)
                            || (s->size().width() == 720 && s->size().height() == 2560)
                            || s->model().contains("XENEON", Qt::CaseInsensitive)}
            });
        }
        return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
    }
    Q_INVOKABLE QString targetConnector() const {
        if (!m_config) return QString();
        XeneonString s(xeneon_config_get_target_connector(m_config)); return s.qstring();
    }
    Q_INVOKABLE QString targetModel() const {
        if (!m_config) return QString();
        XeneonString s(xeneon_config_get_target_model(m_config)); return s.qstring();
    }
    Q_INVOKABLE bool setTargetDisplay(const QString& connector, const QString& model) {
        if (!m_config) return false;
        xeneon_config_set_target_connector(m_config, connector.toUtf8().constData());
        xeneon_config_set_target_model(m_config, model.toUtf8().constData());
        markSelfWrite();
        return xeneon_config_save(m_config) == 0;
    }
    Q_INVOKABLE bool setAutostart(bool enabled) {
        if (!m_config) return false;
        xeneon_config_set_autostart(m_config, enabled ? 1 : 0);
        // Install/remove the XDG entry AND persist the flag — both must succeed for
        // the switch to be honest. Report the combined result.
        bool fileOk = applyAutostart(enabled);
        markSelfWrite();
        bool saveOk = xeneon_config_save(m_config) == 0;
        if (!fileOk) qWarning() << "Manager: autostart .desktop write failed";
        return fileOk && saveOk;
    }
    // Effective autostart state = the XDG autostart entry actually exists.
    Q_INVOKABLE bool isAutostart() const {
        return QFile::exists(autostartPath());
    }

    // ── Images ──
    Q_INVOKABLE QString imagesDir() const {
        XeneonString cd(xeneon_config_dir());
        QString dir = cd.qstring() + "/images";
        QDir().mkpath(dir);
        return dir;
    }
    Q_INVOKABLE QStringList listImages() const {
        QDir d(imagesDir());
        return d.entryList({"*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp"},
                           QDir::Files, QDir::Time);
    }
    // Copy an image into the hub's images dir, keeping a unique name (never
    // silently overwrite an existing image with a colliding basename).
    Q_INVOKABLE QString importImage(const QString& fileUrl) {
        QString src = fileUrl;
        if (src.startsWith("file:")) src = QUrl(src).toLocalFile();
        QFileInfo fi(src);
        if (!fi.exists() || !fi.isReadable()) { qWarning() << "importImage: unreadable" << src; return QString(); }
        const QString dir = imagesDir();
        const QString base = fi.completeBaseName();
        const QString ext = fi.suffix();
        QString name = fi.fileName();
        QString dst = dir + "/" + name;
        for (int n = 1; QFile::exists(dst); ++n) {
            name = base + "-" + QString::number(n) + (ext.isEmpty() ? QString() : "." + ext);
            dst = dir + "/" + name;
        }
        if (!QFile::copy(src, dst)) { qWarning() << "importImage: copy failed" << src << "→" << dst; return QString(); }
        emit imagesChanged();
        return name;
    }
    Q_INVOKABLE bool deleteImage(const QString& name) {
        bool ok = QFile::remove(imagesDir() + "/" + name);
        if (ok) emit imagesChanged();
        return ok;
    }

signals:
    void hubConnectedChanged();
    void imagesChanged();
    void screensChanged();
    void configChanged();   // config reloaded (from the hub or disk) → QML re-reads

private slots:
    void onSocketReadyRead() {
        m_rxBuf += m_sock->readAll();
        int nl;
        while ((nl = m_rxBuf.indexOf('\n')) >= 0) {
            const QByteArray line = m_rxBuf.left(nl);
            m_rxBuf.remove(0, nl + 1);
            const QJsonObject o = QJsonDocument::fromJson(line).object();
            const QString type = o.value("type").toString();
            if (type == "uiState") {
                const QString st = o.value("state").toString();
                // Ignore pulled state briefly after we push, so a reply that
                // predates the hub applying our edit can't revert it.
                if (QDateTime::currentMSecsSinceEpoch() < m_suppressAdoptUntilMs)
                    continue;
                if (!st.isEmpty() && m_config) {
                    // This IS the hub's live state — adopt it WITHOUT re-saving, and
                    // only tell QML to reload when it actually differs (so the gentle
                    // periodic pull doesn't churn the UI when nothing changed).
                    XeneonString cur(xeneon_config_get_ui_state(m_config));
                    if (cur.qstring() != st) {
                        xeneon_config_set_ui_state(m_config, st.toUtf8().constData());
                        emit configChanged();
                    }
                }
            } else if (type == "error") {
                qWarning() << "Manager: hub rejected update:" << o.value("message").toString();
            }
        }
    }

private:
    static QString autostartPath() {
        return QDir::homePath() + "/.config/autostart/xeneon-edge-hub.desktop";
    }
    void markSelfWrite() { m_ignoreWatchUntilMs = QDateTime::currentMSecsSinceEpoch() + 900; }
    void tryConnectHub() {
        if (m_sock->state() == QLocalSocket::UnconnectedState)
            m_sock->connectToServer(QStringLiteral("xeneon-edge-hub-ctl"));
    }
    void writeMsg(const QJsonObject& o) {
        m_sock->write(QJsonDocument(o).toJson(QJsonDocument::Compact));
        m_sock->write("\n");
        m_sock->flush();
    }
    void pushLive(const QString& uiStateJson) {
        m_suppressAdoptUntilMs = QDateTime::currentMSecsSinceEpoch() + 1500;
        if (m_sock->state() == QLocalSocket::ConnectedState) {
            writeMsg(QJsonObject{{"type", "setUiState"}, {"state", uiStateJson}});
        } else {
            // connectToServer is async — buffer and flush on the `connected` signal
            // so the edit is never silently lost (was the "first save dropped" bug).
            m_pendingPush = uiStateJson;
            tryConnectHub();
        }
    }
    void reloadConfig() {
        ConfigHandle* fresh = xeneon_config_load();
        if (!fresh) return;
        if (m_config) xeneon_config_free(m_config);
        m_config = fresh;
        emit configChanged();
    }
    bool applyAutostart(bool enabled) {
        const QString path = autostartPath();
        if (!enabled) { QFile::remove(path); return true; }
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile f(path);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
        // Prefer the hub binary next to this Manager; fall back to PATH.
        QString exec = QCoreApplication::applicationDirPath() + "/xeneon-edge-hub";
        if (!QFile::exists(exec)) {
            exec = QStringLiteral("xeneon-edge-hub");
            qWarning() << "Manager: hub binary not next to the Manager; autostart Exec relies on PATH";
        }
        QTextStream ts(&f);
        ts << "[Desktop Entry]\nType=Application\nName=Xeneon Edge Hub\n"
           << "Exec=" << exec << "\nX-GNOME-Autostart-enabled=true\n";
        return true;
    }

    ConfigHandle* m_config = nullptr;
    QLocalSocket* m_sock = nullptr;
    QFileSystemWatcher* m_watcher = nullptr;
    QString m_configPath;
    QString m_pendingPush;
    QByteArray m_rxBuf;
    qint64 m_ignoreWatchUntilMs = 0;
    qint64 m_suppressAdoptUntilMs = 0;
    bool m_hubConnected = false;
};

int main(int argc, char* argv[]) {
    xeneon_logging_init("info");
    QGuiApplication app(argc, argv);
    app.setApplicationName("Xeneon Edge Manager");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("xeneon-edge-hub");

    // Fusion style so Switch/Button/Slider render properly on the desktop.
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    // Declare the backend BEFORE the engine so it outlives it (locals destroy in
    // reverse order; the engine holds context-property references to the backend).
    ManagerBackend backend;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("configBridge", &backend);
    engine.rootContext()->setContextProperty("backend", &backend);

    engine.load(QUrl(QStringLiteral("qrc:/manager/Manager.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Manager: failed to load QML";
        return 1;
    }

    // Doc/review capture: XENEON_GRAB=<path> renders the window to a PNG and quits.
    const QString grabPath = qEnvironmentVariable("XENEON_GRAB");
    if (!grabPath.isEmpty()) {
        QObject* root = engine.rootObjects().first();
        QTimer::singleShot(1800, [root, grabPath]() {
            auto* win = qobject_cast<QQuickWindow*>(root);
            if (win) {
                const QImage img = win->grabWindow();
                if (!img.isNull() && img.save(grabPath))
                    qInfo() << "Manager: saved grab to" << grabPath;
                else
                    qWarning() << "Manager: grab failed";
            } else {
                qWarning() << "Manager: grab skipped (root is not a window)";
            }
            QCoreApplication::quit();   // always quit so a headless run never hangs
        });
    }

    return app.exec();
}

#include "main.moc"
