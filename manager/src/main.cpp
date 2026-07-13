// Xeneon Edge Manager — a standalone companion desktop app to manage the Edge
// hub: build/reorder the widget layout, tune appearance, upload images, and set
// display/startup options. It edits the SAME config the hub reads (via the Rust
// core) and, when the hub is running, stays in live sync over the hub's local
// control socket (pushes its own edits, pulls the hub's). Works with or without
// the hub running.

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QString>
#include <QTimer>
#include <QImage>
#include <QPalette>
#include <QColor>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QUrl>

#include "xeneon_core.h"
#include "manager_backend.h"

// Build a dark QPalette from the app's dark design tokens. Fusion (set below)
// draws every Qt Quick control that ISN'T hand-restyled (Switch/Slider/Button/
// ScrollBar/Dialog button-boxes) from the application palette; without this it
// falls back to Fusion's default LIGHT gray, which looks broken on the dark UI.
static QPalette darkPalette() {
    const QColor window("#0D1117");
    const QColor base("#161B22");
    const QColor alt("#1C222B");
    const QColor button("#1C222B");
    const QColor text("#E6EDF3");
    const QColor muted("#8B949E");
    const QColor accent("#F26D6D");
    const QColor onAccent("#0D1117");

    QPalette pal;
    pal.setColor(QPalette::Window, window);
    pal.setColor(QPalette::WindowText, text);
    pal.setColor(QPalette::Base, base);
    pal.setColor(QPalette::AlternateBase, alt);
    pal.setColor(QPalette::Button, button);
    pal.setColor(QPalette::ButtonText, text);
    pal.setColor(QPalette::Text, text);
    pal.setColor(QPalette::PlaceholderText, muted);
    pal.setColor(QPalette::BrightText, text);
    pal.setColor(QPalette::ToolTipBase, base);
    pal.setColor(QPalette::ToolTipText, text);
    pal.setColor(QPalette::Highlight, accent);
    pal.setColor(QPalette::HighlightedText, onAccent);
    pal.setColor(QPalette::Link, accent);
    // Disabled group: dim text/placeholder so inactive controls read as muted.
    pal.setColor(QPalette::Disabled, QPalette::Text, muted);
    pal.setColor(QPalette::Disabled, QPalette::WindowText, muted);
    pal.setColor(QPalette::Disabled, QPalette::ButtonText, muted);
    pal.setColor(QPalette::Disabled, QPalette::Highlight, alt);
    return pal;
}

int main(int argc, char* argv[]) {
    xeneon_logging_init("info");
    QGuiApplication app(argc, argv);
    app.setApplicationName("Xeneon Edge Manager");
    app.setApplicationVersion("0.1.0");
    app.setOrganizationName("xeneon-edge-hub");

    // Fusion style so Switch/Button/Slider render properly on the desktop, with a
    // dark palette so those unstyled controls match the dark UI (not light gray).
    QQuickStyle::setStyle(QStringLiteral("Fusion"));
    QGuiApplication::setPalette(darkPalette());

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
