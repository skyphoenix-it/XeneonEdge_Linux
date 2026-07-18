import QtQuick
import QtTest
import "../../ui/qml" as App

// Hub page-navigation suite, hosted in the REAL shell (main.qml → contentRoot →
// StackView → Dashboard → SwipeView). tst_dashboard loads Dashboard alone in a
// plain Item and CANNOT see the deferred-relayout snap-back that the rotating
// contentRoot host produces; this suite pushes the real Dashboard into the real
// StackView and asserts the current page is REACHED AND SUSTAINED (a transient
// tryVerify passes even if the view snaps back a moment later).
//
// COVERS: fn:Dashboard.appendPreset
//
// Honest caveat: qmltestrunner runs offscreen with no Wayland compositor, so its
// relayout timing differs from the device — this may not force the exact snap, but
// it exercises the real stack, uses the fixed geometry-committing goToPage, and
// (with the sustained checks) locks the navigation contract against regressions.
Item {
    id: root
    width: 2560; height: 720                 // device panel dimensions (landscape)

    // Shell context props main.qml reads as `property x: _x` (mirror tst_main.qml).
    property bool _isFirstRun: false
    property string _screens: "[]"
    property string _metricsJson: "{}"
    property string _themeMode: "midnight"
    property string _targetEdidHash: ""
    property string _targetConnector: ""
    property string _targetModel: ""
    property string _configDir: "/tmp"
    property bool _safeMode: false
    property bool _startInDiagnostics: false
    property bool _windowedMode: true
    property int _targetScreenX: 0
    property int _targetScreenY: 0
    property int _targetScreenWidth: 2560
    property int _targetScreenHeight: 720

    property var win: null

    function eachItem(node, fn) {
        if (!node) return
        fn(node)
        var kids = node.children
        if (kids) for (var i = 0; i < kids.length; i++) eachItem(kids[i], fn)
    }
    function findPred(node, pred) {
        var f = null
        eachItem(node, function (n) { if (!f && pred(n)) f = n })
        return f
    }
    function swipe() { return findPred(win.contentItem, function (x) { return x && x.objectName === "pageSwipe" }) }
    function dash()  { return findPred(win.contentItem, function (x) { return x && x.appendPreset !== undefined && x.netGate !== undefined }) }
    function store() { return findPred(win.contentItem, function (x) { return x && x.applyExternal !== undefined && x.structureRevision !== undefined }) }

    TestCase {
        name: "HubNavigation"
        when: windowShown

        function initTestCase() {
            var c = Qt.createComponent("../../ui/qml/main.qml")
            tryVerify(function () { return c.status !== Component.Loading }, 5000)
            compare(c.status, Component.Ready, "main.qml compiles: " + c.errorString())
            win = c.createObject(root)
            verify(win !== null, "main.qml instantiated")
            // Force LANDSCAPE — drives contentRotation=90 and the contentRoot
            // width/height swap (the failing host on device).
            win.orientationMode = "landscape"
            compare(win.contentRotation, 90, "shell is in the landscape (swapped) orientation")
            // main.qml's StackView initialItem is a qrc: URL that doesn't resolve under
            // qmltestrunner, so push the REAL Dashboard by relative URL instead.
            var sv = findPred(win.contentItem, function (n) {
                return n && typeof n.push === "function" && n.currentItem !== undefined })
            verify(sv, "found the StackView")
            sv.push(Qt.resolvedUrl("../../ui/qml/Dashboard.qml"))
            tryVerify(function () { return dash() !== null && swipe() !== null }, 6000,
                      "the real Dashboard + SwipeView loaded in the shell")
        }
        function cleanupTestCase() { if (win) win.destroy() }

        // The bug: after adding pages the view must LAND on the new page and STAY —
        // not snap back to page 0 a moment later.
        function test_add_page_lands_and_stays_landscape() {
            var s = store(), sw = swipe()
            verify(s && sw, "store + SwipeView present")
            s.load("blank")
            tryVerify(function () { return sw.count === s.pageCount() }, 3000, "SwipeView synced to blank")
            for (var n = 0; n < 3; n++) {
                var target = s.pageCount()               // the new page's index
                s.addPage("")
                sw.goToPage(target)
                tryVerify(function () { return sw.currentIndex === target }, 4000,
                          "reached new page " + target)
                wait(900)                                 // outlast a deferred relayout
                compare(sw.currentIndex, target,
                        "STAYED on new page " + target + " (did not snap back)")
            }
        }

        // Applying a preset is additive and must land+stay on the appended screen.
        function test_additive_preset_lands_and_stays() {
            var s = store(), sw = swipe(), d = dash()
            s.load("blank")
            tryVerify(function () { return sw.count === s.pageCount() }, 3000)
            var target = s.pageCount()
            verify(d.appendPreset("system-monitor"), "appended a preset screen")
            tryVerify(function () { return sw.currentIndex === target }, 4000, "reached appended screen")
            wait(900)
            compare(sw.currentIndex, target, "STAYED on the appended screen")
        }

        // A widget that overflows a full screen starts a new screen and the view
        // follows to it (and stays).
        function test_widget_overflow_navigates_and_stays() {
            var s = store(), sw = swipe()
            s.load("blank")
            s.addTile(0, "cpu"); s.addTile(0, "gpu"); s.addTile(0, "ram")   // page 0 now full
            var overflowId = s.addTile(0, "clock")                          // → new screen
            verify(overflowId, "overflow tile added")
            var target = s.pageIndexForTile(overflowId)
            compare(target, 1, "overflow created a second screen")
            sw.goToPage(target)
            tryVerify(function () { return sw.currentIndex === target }, 4000, "reached overflow screen")
            wait(900)
            compare(sw.currentIndex, target, "STAYED on the overflow screen")
        }

        // Removing the current page re-clamps to a valid, in-range index.
        function test_remove_page_reclamps() {
            var s = store(), sw = swipe()
            s.load("blank")
            s.addPage(""); s.addPage("")                 // 3 pages: 0,1,2
            sw.goToPage(2)
            tryVerify(function () { return sw.currentIndex === 2 }, 3000)
            var i = sw.currentIndex
            s.removePage(i)
            sw.goToPage(Math.max(0, Math.min(i, s.pageCount() - 1)))
            tryVerify(function () { return sw.currentIndex === s.pageCount() - 1 }, 3000,
                      "clamped onto a valid page after removing the last")
            verify(sw.currentIndex >= 0 && sw.currentIndex < sw.count, "index in range")
        }

        // A rotation must PRESERVE the current page (the reflow re-projects, it does
        // not reset navigation) — the rotation analogue of the add-page bug.
        function test_nav_survives_a_rotation() {
            var s = store(), sw = swipe()
            s.load("blank")
            s.addPage(""); s.addPage("")
            sw.goToPage(2)
            tryVerify(function () { return sw.currentIndex === 2 }, 3000)
            win.orientationMode = "portrait"             // rotate
            wait(700)
            compare(sw.currentIndex, 2, "current page survived the rotation to portrait")
            win.orientationMode = "landscape"            // rotate back
            wait(700)
            compare(sw.currentIndex, 2, "current page survived the rotation back to landscape")
        }
    }
}
