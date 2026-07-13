import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// EdgeClone — a live WYSIWYG "clone" of the Xeneon Edge. Renders the REAL widgets
// of the current page in a device frame, in a GridLayout that mirrors the Edge's
// column count (1 or 2). Interactions:
//   • drag a tile onto another  → reorder (commit on drop)
//   • drag the corner handle    → resize width (1↔2 cols) and/or height (1↔2)
//   • ⚙ configure   ✕ remove
// All edits go through the shared store → persist + push live to a running hub.
// Resolves store/catalog/theme/media/backend from the Manager scope.
Item {
    id: clone
    property int pageIndex: 0
    signal configRequested(string tileId, string tileType)

    // Structural list → key on structureRevision, NOT revision, so a settings
    // keystroke (title/accent/…) doesn't rebuild every tile Loader (flicker/reload).
    property var tiles: {
        store.structureRevision
        var p = store.pages()[pageIndex]
        return p ? (p.tiles || []) : []
    }
    // Column count: per-page override → global default → 1 (capped at 2 here).
    property int cols: {
        store.revision
        var p = store.pages()[pageIndex] || ({})
        var want = (p.cols && p.cols > 0) ? p.cols : (store.appearance().gridCols || 1)
        return Math.max(1, Math.min(2, want))
    }

    // ── Page background (mirrors Dashboard.qml so the clone is truly WYSIWYG:
    //    animated style OR wallpaper, per-page override → global default) ──
    property var pageBg: {
        store.revision
        var pages = store.pages()
        var p = (pageIndex >= 0 && pageIndex < pages.length) ? pages[pageIndex] : ({})
        var pbg = p.bg || ({})
        var a = store.appearance() || ({})
        if (pbg.wallpaper) return { wallpaper: pbg.wallpaper, style: pbg.style || a.bgStyle || "orbs" }
        if (pbg.style)     return { wallpaper: "", style: pbg.style }
        return { wallpaper: a.wallpaper || "", style: a.bgStyle || "orbs" }
    }
    // Wallpapers are stored as file:// URLs into the Manager's images dir. Re-derive
    // a properly percent-encoded URL from the basename via backend.imageUrl(name) so
    // names with spaces / non-ASCII characters load (mirrors the hub, fixes raw paths).
    property string wallpaperSource: {
        var wp = clone.pageBg.wallpaper
        if (!wp || !wp.length) return ""
        var s = String(wp)
        var name = s.substring(s.lastIndexOf("/") + 1)
        return name.length ? backend.imageUrl(name) : ""
    }
    property bool animatedBg: {
        store.revision
        var a = store.appearance() || ({})
        return a.animatedBg === undefined ? true : a.animatedBg
    }
    property bool reduceMotion: { store.revision; return store.appearance().reduceMotion || false }

    property int tick: 0
    property var metricsObj: ({})
    Timer { interval: 1000; running: true; repeat: true; onTriggered: clone.tick++ }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            try { clone.metricsObj = JSON.parse(backend.metricsJson() || "{}") }
            catch (e) { clone.metricsObj = ({}) }
        }
    }

    function wsrc(type) {
        var s = catalog.source(type)
        return s ? s.replace("qrc:/qml/", "qrc:/manager/") : ""
    }
    // Total pixel height a tile spanning `h` rows occupies, including the row gap
    // between the spanned rows (so a 2-tall tile lines up with two stacked 1-talls).
    function spanH(h) { var n = Math.max(1, h); return 180 * n + 10 * (n - 1) }
    function injectInto(item, id, type) {
        if (!item) return
        store.ensureSettings(id, catalog.defaults(type))
        item.instanceId = id
        item.store = store
        item.expanded = false
        if (item.hasOwnProperty("active")) item.active = true
        item.metrics = Qt.binding(function () { return clone.metricsObj })
        if (item.hasOwnProperty("titleOverride"))
            item.titleOverride = Qt.binding(function () {
                store.revision; var s = store.settingsFor(id); return (s && s.title) ? s.title : ""
            })
        if (item.hasOwnProperty("accentName"))
            item.accentName = Qt.binding(function () {
                store.revision; var s = store.settingsFor(id); return (s && s.accent) ? s.accent : ""
            })
        if (item.hasOwnProperty("cardBackdrop"))
            item.cardBackdrop = Qt.binding(function () {
                store.revision; var s = store.settingsFor(id); return (s && s.cardBackdrop) ? s.cardBackdrop : "none"
            })
        if (item.hasOwnProperty("tick"))
            item.tick = Qt.binding(function () { return clone.tick })
    }

    // ── Drag-move state ──
    property int dragIndex: -1
    property int targetIndex: -1
    property real dragX: 0
    property real dragY: 0

    function targetAt(gx, gy) {
        for (var i = 0; i < tiles.length; i++) {
            var it = rep.itemAt(i)
            if (!it) continue
            if (gx >= it.x && gx <= it.x + it.width && gy >= it.y && gy <= it.y + it.height)
                return i
        }
        return -1
    }

    // ── Device frame — the WHOLE page, scaled to fit (no scrolling) ──
    Rectangle {
        id: frame
        anchors.centerIn: parent
        transformOrigin: Item.Center
        width: clone.cols === 2 ? 520 : 420
        height: screen.height + 16
        // Scale the entire device so the full page is visible at once. Capped so a
        // short page doesn't upscale to blurriness.
        scale: Math.min(clone.width / width, clone.height / height, 1.6)
        radius: 26; color: "#050507"; border.width: 2; border.color: "#000000"
        Behavior on scale { NumberAnimation { duration: 150 } }

        Rectangle {
            id: screen
            anchors.centerIn: parent
            width: parent.width - 16
            height: grid.implicitHeight + 24
            radius: 20; clip: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: theme.backgroundColor }
                GradientStop { position: 0.55; color: theme.backgroundColor2 }
                GradientStop { position: 1.0; color: theme.backgroundColor3 }
            }

            // Animated backdrop (orbs / waves / stars / …) — shown when no wallpaper
            // is set, mirroring the hub so the "Animated background" toggle + style
            // choice preview live. Declared before the grid so it sits underneath.
            BackdropLayer {
                anchors.fill: parent
                visible: clone.wallpaperSource === "" && theme.decorative
                style: clone.pageBg.style
                accent: theme.accent
                running: clone.animatedBg && !clone.reduceMotion
            }
            Image {
                id: cloneWall
                anchors.fill: parent
                source: clone.wallpaperSource
                visible: source != ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: true
            }
            Rectangle {
                anchors.fill: parent; visible: cloneWall.visible
                color: Qt.rgba(theme.backgroundColor.r, theme.backgroundColor.g, theme.backgroundColor.b, 0.28)
            }

            GridLayout {
                id: grid
                x: 12; y: 12; width: parent.width - 24
                columns: clone.cols
                columnSpacing: 10; rowSpacing: 10

                    Repeater {
                        id: rep
                        model: clone.tiles
                        delegate: Item {
                            id: tile
                            required property int index
                            required property var modelData
                            property int pvW: 0   // preview span/height during a resize drag
                            property int pvH: 0
                            property int effH: Math.max(1, (pvH > 0 ? pvH : (modelData.h || 1)))
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.columnSpan: Math.min((pvW > 0 ? pvW : (modelData.w || 1)), clone.cols)
                            // Tall (h=2) tiles span two GRID ROWS — mirrors Dashboard.qml so a
                            // short neighbour keeps its own row instead of floating in dead space.
                            Layout.rowSpan: tile.effH
                            Layout.minimumHeight: clone.spanH(tile.effH)
                            Layout.preferredHeight: clone.spanH(tile.effH)
                            opacity: clone.dragIndex === tile.index ? 0.3 : 1.0

                            Rectangle {   // placeholder / loading
                                anchors.fill: parent; radius: theme.radiusLg
                                color: theme.cardFill(); border.width: 1; border.color: theme.cardBorder
                                visible: wl.status !== Loader.Ready
                                Column {
                                    anchors.centerIn: parent; spacing: 6
                                    AppIcon { anchors.horizontalCenter: parent.horizontalCenter
                                        name: tile.modelData.type; size: 28; color: theme.textSecondary }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                        text: catalog.title(tile.modelData.type); color: theme.textSecondary; font.pixelSize: 12 }
                                }
                            }
                            Loader {
                                id: wl
                                anchors.fill: parent
                                source: clone.wsrc(tile.modelData.type)
                                onLoaded: clone.injectInto(item, tile.modelData.id, tile.modelData.type)
                            }

                            // Drop-target highlight.
                            Rectangle {
                                anchors.fill: parent; radius: theme.radiusLg
                                color: "transparent"; border.width: 3; border.color: theme.accent
                                visible: clone.dragIndex >= 0 && clone.targetIndex === tile.index
                                         && clone.dragIndex !== tile.index
                            }

                            // Drag / select overlay.
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                anchors.rightMargin: 26; anchors.bottomMargin: 26   // leave the corner handle
                                cursorShape: clone.dragIndex === tile.index ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                preventStealing: true
                                property real sx: 0; property real sy: 0
                                property bool dragging: false
                                onPressed: (mouse) => { ma.sx = mouse.x; ma.sy = mouse.y; ma.dragging = false }
                                onPositionChanged: (mouse) => {
                                    if (!ma.dragging && (Math.abs(mouse.x - ma.sx) > 8 || Math.abs(mouse.y - ma.sy) > 8)) {
                                        ma.dragging = true; clone.dragIndex = tile.index
                                    }
                                    if (ma.dragging) {
                                        var g = tile.mapToItem(grid, mouse.x, mouse.y)
                                        var c = tile.mapToItem(clone, mouse.x, mouse.y)
                                        clone.dragX = c.x; clone.dragY = c.y
                                        clone.targetIndex = clone.targetAt(g.x, g.y)
                                    }
                                }
                                onReleased: {
                                    if (ma.dragging) {
                                        var to = clone.targetIndex
                                        if (to >= 0 && to !== tile.index)
                                            store.moveTile(clone.pageIndex, tile.index, to)
                                        clone.dragIndex = -1; clone.targetIndex = -1
                                    } else {
                                        clone.configRequested(tile.modelData.id, tile.modelData.type)
                                    }
                                }
                            }

                            // Top-right controls.
                            Row {
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                                spacing: 6; z: 5
                                Rectangle {
                                    width: 32; height: 32; radius: 16; color: Qt.rgba(0, 0, 0, 0.55)
                                    AppIcon { anchors.centerIn: parent; name: "ui-settings"; color: "#fff"; size: 16 }
                                    MouseArea { anchors.fill: parent
                                        onClicked: clone.configRequested(tile.modelData.id, tile.modelData.type) }
                                }
                                Rectangle {
                                    width: 32; height: 32; radius: 16
                                    color: Qt.rgba(theme.error.r, theme.error.g, theme.error.b, 0.7)
                                    AppIcon { anchors.centerIn: parent; name: "ui-close"; color: "#fff"; size: 15 }
                                    MouseArea { anchors.fill: parent
                                        onClicked: store.removeTile(clone.pageIndex, tile.modelData.id) }
                                }
                            }

                            // Corner resize handle (→ width, ↓ height). Previews live;
                            // commits once on release (no mid-drag reload).
                            Rectangle {
                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 5
                                width: 24; height: 24; radius: 7; z: 6
                                color: Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.75)
                                AppIcon { anchors.centerIn: parent; name: "ui-resize"; color: "#0D1117"; size: 15 }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -8
                                    cursorShape: Qt.SizeFDiagCursor
                                    preventStealing: true
                                    property real sx: 0; property real sy: 0; property int sw: 1; property int sh: 1
                                    // Work in the UNSCALED content ("screen") space so the drag
                                    // distance needed to flip a span matches the visible tile edge
                                    // regardless of the device frame's fit-to-view scale.
                                    onPressed: (mp) => {
                                        var c = mapToItem(screen, mp.x, mp.y)
                                        sx = c.x; sy = c.y
                                        sw = tile.modelData.w || 1; sh = tile.modelData.h || 1
                                        tile.pvW = sw; tile.pvH = sh
                                    }
                                    onPositionChanged: (mp) => {
                                        var c = mapToItem(screen, mp.x, mp.y)
                                        var dx = c.x - sx, dy = c.y - sy
                                        var tW = tile.width * 0.55        // ~half a tile → flip
                                        var tH = clone.spanH(1) * 0.55
                                        tile.pvW = clone.cols >= 2 ? (dx > tW ? 2 : (dx < -tW ? 1 : sw)) : 1
                                        tile.pvH = dy > tH ? 2 : (dy < -tH ? 1 : sh)
                                    }
                                    onReleased: {
                                        var nw = tile.pvW > 0 ? tile.pvW : (tile.modelData.w || 1)
                                        var nh = tile.pvH > 0 ? tile.pvH : (tile.modelData.h || 1)
                                        tile.pvW = 0; tile.pvH = 0
                                        store.setTileSize(clone.pageIndex, tile.modelData.id, nw, nh)
                                    }
                                }
                            }
                        }
                    }
                }

            Text {
                anchors.centerIn: parent
                visible: clone.tiles.length === 0
                text: "This page is empty.\nUse “Add widget”."
                horizontalAlignment: Text.AlignHCenter
                color: theme.textTertiary; font.pixelSize: 15
            }
        }
    }

    // Floating drag ghost — tracks the cursor (both axes) and stays on-screen.
    Rectangle {
        id: dragGhost
        visible: clone.dragIndex >= 0 && clone.dragIndex < clone.tiles.length
        width: 210; height: 46; radius: 12; z: 100
        x: Math.max(6, Math.min(clone.width - width - 6, clone.dragX + 18))
        y: Math.max(6, Math.min(clone.height - height - 6, clone.dragY - height / 2))
        color: theme.cardBackgroundAlt; border.width: 1; border.color: theme.accent
        Row {
            anchors.centerIn: parent; spacing: 10
            AppIcon { anchors.verticalCenter: parent.verticalCenter; size: 22; color: theme.textPrimary
                name: clone.dragIndex >= 0 && clone.dragIndex < clone.tiles.length
                      ? clone.tiles[clone.dragIndex].type : "" }
            Text { text: clone.dragIndex >= 0 && clone.dragIndex < clone.tiles.length
                ? catalog.title(clone.tiles[clone.dragIndex].type) : ""
                color: theme.textPrimary; font.pixelSize: 15 }
        }
    }
}
