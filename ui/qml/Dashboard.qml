import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ─────────────────────────────────────────────────────────────────────────
// Dashboard — iCUE-style square-tile layout.
//
// Each page shows THREE large square slots (a row in landscape, a column in
// portrait). A slot is either:
//   • full : one widget fills the whole square, or
//   • split: two half-height widgets stacked inside the square.
// Tiles are glanceable previews; tapping a tile expands it full-screen for
// interaction (via ExpandedWidget). Layout is data-driven (see `pages`).
// ─────────────────────────────────────────────────────────────────────────
Item {
    id: dashboard
    anchors.fill: parent

    // 1 Hz tick used to refresh time-based widgets.
    property int _tick: 0

    // Parsed live metrics from C++ (single parse, shared by all widgets).
    property var metrics: {
        try { return JSON.parse(metricsJson || "{}"); } catch (e) { return {}; }
    }

    property bool isLandscape: width > height

    // Currently expanded widget (null = none).
    property var expandComp: null
    property string expandTitle: ""

    // StackView that hosts this page (for opening Diagnostics/Settings).
    property var host: StackView.view

    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(1) + " GB"
        if (b >= 1048576) return (b / 1048576).toFixed(0) + " MB"
        return (b / 1024).toFixed(0) + " KB"
    }

    Rectangle { anchors.fill: parent; color: theme.backgroundColor }

    // Master tick (paused when the app is not active to save CPU).
    Timer { interval: 1000; running: Qt.application.active; repeat: true; onTriggered: dashboard._tick++ }

    // ═══════════════════════════════════════════════════════════════════
    //  Widget registry — inline components keyed by id.
    //  Each widget fills its tile and scales with available height:
    //  `r.big` (expanded / large) shows richer content & interactivity.
    // ═══════════════════════════════════════════════════════════════════

    Component {
        id: clockComp
        Item { id: r
            property bool big: height > 240
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 8 : 2
                Text { Layout.alignment: Qt.AlignHCenter; visible: r.big; text: "🕐"; font.pixelSize: 40 }
                Text { Layout.alignment: Qt.AlignHCenter
                    text: (dashboard._tick, Qt.formatTime(new Date(), "HH:mm"))
                    font.pixelSize: r.big ? 120 : (height < 150 ? 34 : 54); font.bold: true
                    font.family: theme.fontMono; color: theme.textPrimary }
                Text { Layout.alignment: Qt.AlignHCenter
                    text: (dashboard._tick, Qt.formatDate(new Date(), r.big ? "dddd, MMMM d" : "ddd, MMM d"))
                    font.pixelSize: r.big ? 24 : 13; color: theme.textSecondary }
            }
        }
    }

    Component {
        id: cpuComp
        Item { id: r
            property real v: dashboard.metrics.cpu_usage_percent || 0
            property real temp: dashboard.metrics.cpu_temp_celsius || -1
            property bool big: height > 240
            function col(p) { return p > 80 ? theme.error : p > 50 ? theme.warning : theme.accent }
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 12 : 4; width: r.width * 0.78
                Text { Layout.alignment: Qt.AlignHCenter; text: "🖥  CPU"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; text: r.v.toFixed(0) + "%"
                    font.pixelSize: r.big ? 96 : (height < 150 ? 28 : 40); font.bold: true; font.family: theme.fontMono; color: r.col(r.v) }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: r.big ? 12 : 6; radius: height / 2; color: theme.cardBorder
                    Rectangle { height: parent.height; radius: height / 2; width: parent.width * Math.min(r.v / 100, 1); color: r.col(r.v)
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } } }
                Text { Layout.alignment: Qt.AlignHCenter; visible: r.temp > 0; text: "🌡 " + r.temp.toFixed(0) + "°C"; font.pixelSize: r.big ? 20 : 12; color: theme.warning }
            }
        }
    }

    Component {
        id: ramComp
        Item { id: r
            property real v: dashboard.metrics.ram_usage_percent || 0
            property bool big: height > 240
            function col(p) { return p > 90 ? theme.error : p > 70 ? theme.warning : theme.accent }
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 12 : 4; width: r.width * 0.78
                Text { Layout.alignment: Qt.AlignHCenter; text: "🧠  RAM"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; text: r.v.toFixed(0) + "%"
                    font.pixelSize: r.big ? 96 : (height < 150 ? 28 : 40); font.bold: true; font.family: theme.fontMono; color: r.col(r.v) }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: r.big ? 12 : 6; radius: height / 2; color: theme.cardBorder
                    Rectangle { height: parent.height; radius: height / 2; width: parent.width * Math.min(r.v / 100, 1); color: r.col(r.v)
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } } } }
                Text { Layout.alignment: Qt.AlignHCenter
                    text: dashboard.fmtBytes(dashboard.metrics.ram_used_bytes || 0) + " / " + dashboard.fmtBytes(dashboard.metrics.ram_total_bytes || 0)
                    font.pixelSize: r.big ? 16 : 10; color: theme.textSecondary }
            }
        }
    }

    Component {
        id: sensorsComp
        Item { id: r
            property bool big: height > 240
            property real cpu: dashboard.metrics.cpu_usage_percent || 0
            property real ram: dashboard.metrics.ram_usage_percent || 0
            property real temp: dashboard.metrics.cpu_temp_celsius || -1
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 10 : 4
                Text { Layout.alignment: Qt.AlignHCenter; text: "📊  Sensors"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; text: "CPU " + r.cpu.toFixed(0) + "%"; font.pixelSize: r.big ? 30 : 15; font.family: theme.fontMono; color: theme.textPrimary }
                Text { Layout.alignment: Qt.AlignHCenter; text: "RAM " + r.ram.toFixed(0) + "%"; font.pixelSize: r.big ? 30 : 15; font.family: theme.fontMono; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; visible: r.temp > 0; text: "TEMP " + r.temp.toFixed(0) + "°C"; font.pixelSize: r.big ? 26 : 13; font.family: theme.fontMono; color: theme.warning }
            }
        }
    }

    Component {
        id: networkComp
        Item { id: r
            Canvas { id: cv; anchors.fill: parent; anchors.margins: theme.spacingSm
                onPaint: {
                    var ctx = getContext('2d'); ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = theme.accent; ctx.lineWidth = 2; ctx.beginPath()
                    var mid = height * 0.6
                    for (var i = 0; i < 28; i++) {
                        var x = i * width / 27
                        var y = mid + Math.sin(i * 0.6 + Date.now() * 0.001) * (height * 0.12)
                              + Math.sin(i * 1.3 + Date.now() * 0.002) * (height * 0.06)
                        i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }
                Timer { interval: 300; running: Qt.application.active; repeat: true; onTriggered: cv.requestPaint() }
            }
            Text { anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; anchors.topMargin: 2
                text: "📡  Network"; font.pixelSize: r.height > 240 ? 20 : 12; font.bold: true; color: theme.textSecondary }
        }
    }

    Component {
        id: pomodoroComp
        Item { id: r
            property int mins: 25; property int secs: 0; property bool running: false
            property bool big: height > 240
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 16 : 4
                Text { Layout.alignment: Qt.AlignHCenter; text: "⏱  Focus"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; text: String(r.mins).padStart(2, '0') + ":" + String(r.secs).padStart(2, '0')
                    font.pixelSize: r.big ? 120 : (height < 150 ? 30 : 46); font.bold: true; font.family: theme.fontMono; color: r.running ? theme.accent : theme.textPrimary }
                Text { Layout.alignment: Qt.AlignHCenter; visible: !r.big; text: r.running ? "running…" : "tap to open"; font.pixelSize: 11; color: theme.textSecondary }
                RowLayout { Layout.alignment: Qt.AlignHCenter; visible: r.big; spacing: theme.spacingMd
                    Rectangle { Layout.preferredWidth: 180; Layout.preferredHeight: theme.touchPrimary; radius: theme.radiusMd; color: r.running ? theme.error : theme.accent
                        Text { anchors.centerIn: parent; text: r.running ? "Stop" : "Start"; font.pixelSize: theme.fontTitle; color: "#fff" }
                        MouseArea { anchors.fill: parent; onClicked: r.running = !r.running } }
                    Rectangle { Layout.preferredWidth: theme.touchPrimary; Layout.preferredHeight: theme.touchPrimary; radius: theme.radiusMd; color: theme.cardBorder
                        Text { anchors.centerIn: parent; text: "⟲"; font.pixelSize: 26; color: theme.textPrimary }
                        MouseArea { anchors.fill: parent; onClicked: { r.running = false; r.mins = 25; r.secs = 0 } } }
                }
            }
            Timer { interval: 1000; repeat: true; running: r.running
                onTriggered: { if (r.secs > 0) r.secs--; else if (r.mins > 0) { r.mins--; r.secs = 59 } else r.running = false } }
        }
    }

    Component {
        id: checklistComp
        Item { id: r
            property bool big: height > 240
            property var items: ["Review PRs", "Update docs", "Standup", "Sync", "Deploy"]
            property var checked: [false, false, false, false, false]
            ColumnLayout { anchors.fill: parent; anchors.margins: r.big ? theme.spacingLg : theme.spacingSm; spacing: r.big ? 8 : 2
                Text { text: "✅  Checklist"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                Repeater { model: r.items
                    Item { Layout.fillWidth: true; Layout.preferredHeight: r.big ? theme.touchSecondary : 22
                        RowLayout { anchors.fill: parent; spacing: theme.spacingSm
                            Rectangle { Layout.preferredWidth: r.big ? 28 : 18; Layout.preferredHeight: r.big ? 28 : 18; radius: 6
                                color: r.checked[index] ? theme.accent : theme.cardBorder
                                Text { anchors.centerIn: parent; visible: r.checked[index]; text: "✓"; font.pixelSize: r.big ? 16 : 11; color: "#000" } }
                            Text { text: modelData; font.pixelSize: r.big ? 20 : 12; Layout.fillWidth: true; elide: Text.ElideRight
                                color: r.checked[index] ? theme.textSecondary : theme.textPrimary }
                        }
                        MouseArea { anchors.fill: parent; enabled: r.big
                            onClicked: { var c = r.checked.slice(); c[index] = !c[index]; r.checked = c } }
                    }
                }
            }
        }
    }

    Component {
        id: habitsComp
        Item { id: r
            property bool big: height > 240
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 10 : 4
                Text { Layout.alignment: Qt.AlignHCenter; text: "📅  Habits"; font.pixelSize: r.big ? 20 : 12; font.bold: true; color: theme.textSecondary }
                GridLayout { Layout.alignment: Qt.AlignHCenter; columns: 7; rowSpacing: r.big ? 6 : 3; columnSpacing: r.big ? 6 : 3
                    Repeater { model: 28
                        Rectangle { property int cell: r.big ? 26 : 14; width: cell; height: cell; radius: 4
                            color: index < new Date().getDate() ? Qt.rgba(0.34, 0.65, 1, 0.35 + (index % 5) * 0.1) : theme.cardBorder } }
                }
            }
        }
    }

    Component {
        id: moonComp
        Item { id: r
            property bool big: height > 240
            property var phases: ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]
            property var names: ["New", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full", "Waning Gibbous", "Last Quarter", "Waning Crescent"]
            property int idx: {
                var lp = 2551443, now = new Date().getTime() / 1000
                var since = now - new Date(2000, 0, 6, 18, 14).getTime() / 1000
                return Math.floor(((since % lp) / lp) * 8 + 0.5) % 8
            }
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 10 : 2
                Text { Layout.alignment: Qt.AlignHCenter; text: r.phases[r.idx]; font.pixelSize: r.big ? 110 : 40 }
                Text { Layout.alignment: Qt.AlignHCenter; text: r.names[r.idx]; font.pixelSize: r.big ? 22 : 11; color: theme.textSecondary }
            }
        }
    }

    Component {
        id: quoteComp
        Item { id: r
            property bool big: height > 240
            property var quotes: [
                "Simplicity is the soul of efficiency.",
                "Make it work, make it right, make it fast.",
                "The best way out is always through.",
                "Focus is saying no to a thousand good ideas."
            ]
            property string q: quotes[new Date().getDate() % quotes.length]
            ColumnLayout { anchors.centerIn: parent; width: r.width * 0.85; spacing: r.big ? 12 : 4
                Text { Layout.alignment: Qt.AlignHCenter; text: "💬"; font.pixelSize: r.big ? 40 : 18 }
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: r.q; font.pixelSize: r.big ? 30 : 13; font.italic: true; color: theme.textPrimary }
            }
        }
    }

    Component {
        id: countdownComp
        Item { id: r
            property bool big: height > 240
            property int days: { var t = new Date("2026-12-25"); return Math.max(0, Math.ceil((t - new Date()) / 86400000)) }
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 10 : 2
                Text { Layout.alignment: Qt.AlignHCenter; text: r.days > 0 ? r.days : "🎉"; font.pixelSize: r.big ? 110 : 42; font.bold: true; font.family: theme.fontMono; color: theme.accent }
                Text { Layout.alignment: Qt.AlignHCenter; text: r.days > 0 ? "days to Christmas" : "Merry Christmas!"; font.pixelSize: r.big ? 22 : 11; color: theme.textSecondary }
            }
        }
    }

    Component {
        id: eodComp
        Item { id: r
            property bool big: height > 240
            property string remaining: {
                dashboard._tick
                var n = new Date(), e = new Date(n); e.setHours(17, 0, 0, 0)
                var d = (e - n) / 1000
                return d > 0 ? Math.floor(d / 3600) + "h " + Math.floor((d % 3600) / 60) + "m" : "done"
            }
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 10 : 2
                Text { Layout.alignment: Qt.AlignHCenter; text: "🌆  End of Day"; font.pixelSize: r.big ? 20 : 11; font.bold: true; color: theme.textSecondary }
                Text { Layout.alignment: Qt.AlignHCenter; text: r.remaining; font.pixelSize: r.big ? 80 : 26; font.bold: true; font.family: theme.fontMono; color: theme.accent }
            }
        }
    }

    Component {
        id: diceComp
        Item { id: r
            property bool big: height > 240
            property int sides: 6; property int last: 0
            ColumnLayout { anchors.centerIn: parent; spacing: r.big ? 16 : 4
                Text { Layout.alignment: Qt.AlignHCenter; text: r.last > 0 ? "🎲 " + r.last : "🎲 d" + r.sides
                    font.pixelSize: r.big ? 100 : (r.last > 0 ? 40 : 22); font.bold: true; color: theme.textPrimary }
                RowLayout { Layout.alignment: Qt.AlignHCenter; visible: r.big; spacing: theme.spacingSm
                    Repeater { model: [4, 6, 8, 12, 20]
                        Rectangle { Layout.preferredWidth: theme.touchSecondary; Layout.preferredHeight: theme.touchSecondary; radius: theme.radiusSm
                            color: r.sides === modelData ? theme.accent : theme.cardBorder
                            Text { anchors.centerIn: parent; text: "d" + modelData; font.pixelSize: 13; color: r.sides === modelData ? "#000" : theme.textSecondary }
                            MouseArea { anchors.fill: parent; onClicked: { r.sides = modelData; r.last = 0 } } } }
                }
                Rectangle { Layout.alignment: Qt.AlignHCenter; visible: r.big; Layout.preferredWidth: 180; Layout.preferredHeight: theme.touchPrimary; radius: theme.radiusMd; color: theme.accent
                    Text { anchors.centerIn: parent; text: "🎲 Roll"; font.pixelSize: theme.fontTitle; color: "#fff" }
                    MouseArea { anchors.fill: parent; onClicked: r.last = Math.floor(Math.random() * r.sides) + 1 } }
            }
        }
    }

    Component {
        id: analogComp
        Item { id: r
            Canvas { id: cv; anchors.fill: parent; anchors.margins: theme.spacingMd
                onPaint: {
                    var ctx = getContext('2d'); var cx = width / 2, cy = height / 2, rad = Math.min(cx, cy) - 6
                    ctx.clearRect(0, 0, width, height)
                    ctx.strokeStyle = theme.cardBorder; ctx.lineWidth = Math.max(4, rad * 0.06)
                    ctx.beginPath(); ctx.arc(cx, cy, rad, 0, 2 * Math.PI); ctx.stroke()
                    var now = new Date(), h = now.getHours() % 12, m = now.getMinutes(), s = now.getSeconds()
                    var ha = (h + m / 60) * Math.PI / 6 - 1.57, ma = (m + s / 60) * Math.PI / 30 - 1.57, sa = s * Math.PI / 30 - 1.57
                    ctx.strokeStyle = theme.textPrimary; ctx.lineWidth = Math.max(3, rad * 0.045)
                    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(ha) * rad * 0.5, cy + Math.sin(ha) * rad * 0.5); ctx.stroke()
                    ctx.lineWidth = Math.max(2, rad * 0.03)
                    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(ma) * rad * 0.75, cy + Math.sin(ma) * rad * 0.75); ctx.stroke()
                    ctx.strokeStyle = theme.accent; ctx.lineWidth = Math.max(1, rad * 0.02)
                    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(sa) * rad * 0.85, cy + Math.sin(sa) * rad * 0.85); ctx.stroke()
                }
                Timer { interval: 1000; running: Qt.application.active; repeat: true; onTriggered: cv.requestPaint() }
            }
        }
    }

    property var registry: ({
        "clock": clockComp, "cpu": cpuComp, "ram": ramComp, "sensors": sensorsComp, "network": networkComp,
        "pomodoro": pomodoroComp, "checklist": checklistComp, "habits": habitsComp, "moon": moonComp,
        "quote": quoteComp, "countdown": countdownComp, "eod": eodComp, "dice": diceComp, "analog": analogComp
    })
    property var titles: ({
        "clock": "Clock", "cpu": "CPU", "ram": "Memory", "sensors": "Sensors", "network": "Network",
        "pomodoro": "Focus Timer", "checklist": "Checklist", "habits": "Habits", "moon": "Moon Phase",
        "quote": "Daily Quote", "countdown": "Countdown", "eod": "End of Day", "dice": "Dice Roller", "analog": "Analog Clock"
    })

    // ═══════════════════════════════════════════════════════════════════
    //  Layout model — 3 square slots per page. A slot is `full` (one widget)
    //  or `split` (two half widgets). Easy to reconfigure / persist later.
    // ═══════════════════════════════════════════════════════════════════
    property var pages: [
        { name: "System",  slots: [ { w: "clock" }, { split: true, top: "cpu", bottom: "ram" }, { split: true, top: "network", bottom: "sensors" } ] },
        { name: "Focus",   slots: [ { w: "pomodoro" }, { w: "checklist" }, { split: true, top: "habits", bottom: "countdown" } ] },
        { name: "Ambient", slots: [ { w: "analog" }, { split: true, top: "moon", bottom: "eod" }, { w: "quote" } ] }
    ]

    // Reusable tile frame. `tileId` provided by the loading Loader.
    Component {
        id: tileComp
        Rectangle {
            id: tile
            radius: theme.radiusLg
            color: theme.cardBackground
            border.width: 1
            border.color: tileMA.containsMouse ? theme.accent : theme.cardBorder
            Behavior on border.color { ColorAnimation { duration: theme.motionFast } }
            scale: tileMA.pressed ? 0.985 : 1.0
            Behavior on scale { NumberAnimation { duration: theme.motionFast; easing.type: Easing.OutCubic } }

            Rectangle { anchors.fill: parent; radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.04) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.06) }
                } }

            Loader { anchors.fill: parent; anchors.margins: theme.spacingLg; sourceComponent: dashboard.registry[tileId] }

            Text { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: theme.spacingSm
                text: "↗"; font.pixelSize: 16; color: theme.accent
                opacity: tileMA.containsMouse ? 0.9 : 0.35
                Behavior on opacity { NumberAnimation { duration: theme.motionFast } } }

            MouseArea { id: tileMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { dashboard.expandComp = dashboard.registry[tileId]; dashboard.expandTitle = dashboard.titles[tileId] } }
        }
    }

    Component { id: fullSlot
        Loader { anchors.fill: parent; sourceComponent: tileComp; property string tileId: slotData.w }
    }
    Component { id: splitSlot
        ColumnLayout { anchors.fill: parent; spacing: theme.spacingMd
            Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: tileComp; property string tileId: slotData.top }
            Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: tileComp; property string tileId: slotData.bottom }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Page container
    // ═══════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: theme.spacingMd
        spacing: theme.spacingSm

        SwipeView {
            id: swipeView
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true

            Repeater {
                model: dashboard.pages
                delegate: Item {
                    required property int index
                    property var pageData: dashboard.pages[index]

                    GridLayout {
                        anchors.fill: parent
                        rows: dashboard.isLandscape ? 1 : 3
                        columns: dashboard.isLandscape ? 3 : 1
                        rowSpacing: theme.spacingMd
                        columnSpacing: theme.spacingMd

                        Repeater {
                            model: pageData.slots
                            delegate: Loader {
                                required property var modelData
                                property var slotData: modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                sourceComponent: modelData.split ? splitSlot : fullSlot
                            }
                        }
                    }
                }
            }
        }

        // Bottom bar: page indicator + settings
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: theme.touchSecondary
            spacing: theme.spacingMd

            Item { Layout.preferredWidth: theme.touchSecondary }

            PageIndicator {
                Layout.alignment: Qt.AlignCenter
                Layout.fillWidth: true
                count: swipeView.count
                currentIndex: swipeView.currentIndex
                interactive: true
                onCurrentIndexChanged: swipeView.currentIndex = currentIndex

                delegate: Rectangle {
                    implicitWidth: 10; implicitHeight: 10; radius: 5
                    color: theme.accent
                    opacity: index === swipeView.currentIndex ? 0.95 : 0.3
                    Behavior on opacity { NumberAnimation { duration: theme.motionFast } }
                }
            }

            // Settings / diagnostics
            Rectangle {
                Layout.preferredWidth: theme.touchSecondary
                Layout.preferredHeight: theme.touchSecondary
                radius: theme.radiusMd
                color: gearMA.containsMouse ? theme.cardBackground : "transparent"
                border.width: 1; border.color: theme.cardBorder
                Text { anchors.centerIn: parent; text: "⚙"; font.pixelSize: 22; color: theme.textSecondary }
                MouseArea {
                    id: gearMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (dashboard.host)
                            dashboard.host.push("qrc:/qml/Diagnostics.qml", {
                                "metricsJson": Qt.binding(function () { return metricsJson }),
                                "screensData": screensData
                            })
                    }
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  Expanded widget overlay (repeatable open/close — see ExpandedWidget)
    // ═══════════════════════════════════════════════════════════════════
    ExpandedWidget {
        id: overlay
        shown: dashboard.expandComp !== null
        widgetTitle: dashboard.expandTitle
        widgetContent: dashboard.expandComp
        onCloseRequested: { dashboard.expandComp = null; dashboard.expandTitle = "" }
    }
}



