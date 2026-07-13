import QtQuick
import QtTest
import "../../ui/qml" as App

// ─────────────────────────────────────────────────────────────────────────
// Comprehensive coverage for the shared area  ui/qml/DashboardStore.qml.
//
// The store resolves the C++ `configBridge` global by UNQUALIFIED name via the
// QML scope chain (exactly as a widget resolves `theme`/`store`/`media` off the
// WidgetHarness). So we expose a mock `configBridge` as a property on this
// document's root object; the store's _hasBridge()/_flush()/load() then talk to
// it and we can observe every save + control every load.
//
// Tests marked "(BUG)" encode the behaviour the audit says the store SHOULD
// have; they FAIL against the current code and the failure is the finding.
// Tests marked "(OK)" pin down correct behaviour and are expected to pass.
// ─────────────────────────────────────────────────────────────────────────
Item {
    id: root
    width: 100; height: 100

    // Mock persistence bridge, resolved by the store as the `configBridge` global.
    QtObject {
        id: _bridge
        property string stored: ""     // what uiState() will return (prior saved doc)
        property int    saveCount: 0   // number of saveUiState() calls
        property string lastJson: ""   // JSON of the most recent save
        function saveUiState(json) { lastJson = json; stored = json; saveCount++ }
        function uiState() { return stored }
        function reset() { stored = ""; saveCount = 0; lastJson = "" }
    }
    property var configBridge: _bridge

    App.DashboardStore { id: store }

    // Helper: build a stored doc string.
    function docStr(o) { return JSON.stringify(o) }

    // ── 0. Mock wiring sanity ───────────────────────────────────────────────
    TestCase {
        name: "StoreBridgeWiring"
        when: windowShown

        // (OK) The store must actually see the injected configBridge; if this
        // fails, every bridge-observing test below is meaningless.
        function test_bridge_is_reachable() {
            _bridge.reset()
            store.load("blank")   // stored=="" ⇒ seed path ⇒ immediate _flush()
            verify(_bridge.saveCount >= 1, "seed-on-load flushes through the mock bridge (bridge reachable)")
        }

        // (OK) A stored doc is read back by load() through the bridge.
        function test_bridge_roundtrip_on_load() {
            _bridge.reset()
            _bridge.stored = docStr({ version: 1, appearance: {}, settings: {},
                pages: [ { name: "Persisted", tiles: [] } ] })
            store.load("productivity")
            compare(store.pageCount(), 1)
            compare(store.pages()[0].name, "Persisted")
        }
    }

    // ── 1. Force-flush semantics of structural edits ────────────────────────
    TestCase {
        name: "StoreForceFlush"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank"); _bridge.reset() }

        // (OK) resetTo() calls flushNow() → immediate, synchronous save.
        function test_resetTo_flushes_immediately() {
            store.resetTo("minimal")
            compare(_bridge.saveCount, 1, "resetTo persists immediately (flushNow)")
        }

        // (BUG) _commitStructure only debounces (saveTimer.restart), so a page
        // added from the tab bar outside edit mode is not persisted for 400ms
        // and is lost on abrupt power-off.
        function test_addPage_force_flushes() {
            store.addPage("Extra")
            compare(_bridge.saveCount, 1,
                "a structural edit (addPage) should force an immediate save, not a 400ms debounce")
        }

        // (BUG) Same debounce hole for addTile.
        function test_addTile_force_flushes() {
            store.addTile(0, "cpu")
            compare(_bridge.saveCount, 1,
                "addTile should force an immediate save")
        }

        // (BUG) Same debounce hole for setPageColumns (BackgroundPicker path).
        function test_setPageColumns_force_flushes() {
            store.setPageColumns(0, 3)
            compare(_bridge.saveCount, 1,
                "setPageColumns should force an immediate save")
        }

        // (BUG) …and for setPageBackground.
        function test_setPageBackground_force_flushes() {
            store.setPageBackground(0, "style", "waves")
            compare(_bridge.saveCount, 1,
                "setPageBackground should force an immediate save")
        }
    }

    // ── 2. Page-index bounds ────────────────────────────────────────────────
    TestCase {
        name: "StorePageBounds"
        when: windowShown
        function init() {
            _bridge.reset()
            store.load("blank")
            store.addPage("B"); store.addPage("C")   // 3 pages: Home, B, C
            _bridge.reset()
        }

        // (BUG) removePage(-1) splices from the end and deletes the LAST page.
        function test_removePage_negative_is_noop() {
            var before = store.pageCount()
            var names = store.pages().map(function (p) { return p.name })
            store.removePage(-1)
            compare(store.pageCount(), before,
                "removePage(-1) must not delete any page (negative index deletes the last)")
            compare(store.pages().map(function (p) { return p.name }), names,
                "page list unchanged after removePage(-1)")
        }

        // (BUG) removePage(999) removes nothing but still bumps revisions + queues a save.
        function test_removePage_oob_no_side_effects() {
            var sr = store.structureRevision
            var rv = store.revision
            store.removePage(999)
            compare(store.structureRevision, sr,
                "an out-of-range removePage must not bump structureRevision")
            compare(store.revision, rv,
                "an out-of-range removePage must not bump revision")
            compare(_bridge.saveCount, 0,
                "an out-of-range removePage must not queue/force a save")
        }

        // (OK) A valid removePage deletes exactly that page and its tiles' settings.
        function test_removePage_valid_drops_only_that_pages_settings() {
            store.load("blank")
            var id0 = store.addTile(0, "cpu")
            store.addPage("Two")
            var id1 = store.addTile(1, "gpu")
            store.setSetting(id0, "a", 1)
            store.setSetting(id1, "b", 2)
            store.removePage(1)
            compare(store.pageCount(), 1, "page removed")
            verify(store.data.settings.hasOwnProperty(id0), "surviving page's tile settings kept")
            verify(!store.data.settings.hasOwnProperty(id1), "removed page's tile settings dropped")
        }

        // (OK) removePage never drops below one page.
        function test_removePage_keeps_last_page() {
            store.load("blank")   // one page
            store.removePage(0)
            compare(store.pageCount(), 1, "the last page is protected")
        }
    }

    // ── 3. Tile-mutation bounds (must not throw) ────────────────────────────
    TestCase {
        name: "StoreTileBounds"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank"); _bridge.reset() }

        // (BUG) removeTile dereferences data.pages[pageIdx].tiles with no guard.
        function test_removeTile_oob_page_does_not_throw() {
            var threw = false
            try { store.removeTile(5, "whatever") } catch (e) { threw = true }
            verify(!threw, "removeTile with an out-of-range pageIdx must return safely, not throw")
        }

        // (BUG) moveTile dereferences data.pages[pageIdx].tiles with no guard.
        function test_moveTile_oob_page_does_not_throw() {
            var threw = false
            try { store.moveTile(5, 0, 0) } catch (e) { threw = true }
            verify(!threw, "moveTile with an out-of-range pageIdx must return safely, not throw")
        }

        // (OK) removeTile / moveTile on a valid page still behave.
        function test_removeTile_valid_still_works() {
            var id = store.addTile(0, "cpu")
            store.removeTile(0, id)
            compare(store.pages()[0].tiles.length, 0)
        }
    }

    // ── 4. load()/applyExternal() normalisation & pruning ───────────────────
    TestCase {
        name: "StoreLoadNormalise"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank"); _bridge.reset() }

        // (BUG) load() does not guarantee each page has a tiles array; addTile
        // then throws on the un-normalised page.
        function test_load_normalises_tiles_array() {
            _bridge.stored = docStr({ version: 1, appearance: {}, settings: {},
                pages: [ { name: "NoTiles" } ] })    // page WITHOUT a tiles array
            store.load("productivity")
            var threw = false
            try { store.addTile(0, "cpu") } catch (e) { threw = true }
            verify(!threw,
                "load() should normalise every page to have a tiles array so addTile does not throw")
        }

        // (BUG) applyExternal() accepts a page without a tiles array.
        function test_applyExternal_normalises_tiles_array() {
            verify(store.applyExternal(docStr({ version: 1, pages: [ { name: "NoTiles" } ] })))
            var threw = false
            try { store.addTile(0, "cpu") } catch (e) { threw = true }
            verify(!threw,
                "applyExternal() should normalise pages so a later addTile does not throw")
        }

        // (BUG) applyExternal() keeps settings for tile ids no longer present.
        function test_applyExternal_prunes_orphan_settings() {
            store.applyExternal(docStr({ version: 1,
                pages: [ { name: "P", tiles: [ { id: "keep-1", type: "cpu" } ] } ],
                settings: { "keep-1": { a: 1 }, "orphan-9": { b: 2 } } }))
            verify(store.data.settings.hasOwnProperty("keep-1"), "live tile settings kept")
            verify(!store.data.settings.hasOwnProperty("orphan-9"),
                "settings for a tile absent from every page should be pruned")
        }

        // (BUG) load() keeps orphaned settings too.
        function test_load_prunes_orphan_settings() {
            _bridge.stored = docStr({ version: 1, appearance: {}, settings: { "orphan-x": { z: 1 } },
                pages: [ { name: "P", tiles: [ { id: "keep-2", type: "cpu" } ] } ] })
            store.load("productivity")
            verify(!store.data.settings.hasOwnProperty("orphan-x"),
                "load() should prune settings whose ids no longer exist in any page")
        }

        // (OK) load() scrubs the stray empty-id settings entry.
        function test_load_scrubs_empty_id_settings() {
            _bridge.stored = docStr({ version: 1, appearance: {},
                settings: { "": { junk: 1 }, "t1": { ok: 1 } },
                pages: [ { name: "P", tiles: [ { id: "t1", type: "cpu" } ] } ] })
            store.load("productivity")
            verify(!store.data.settings.hasOwnProperty(""), "empty-id settings scrubbed on load")
        }

        // (BUG) load() discards a valid saved doc with pages:[] and re-seeds,
        // while applyExternal() honours it — an inconsistency the audit flags.
        function test_load_honours_empty_pages_like_applyExternal() {
            // Prove applyExternal honours pages:[].
            store.applyExternal(docStr({ version: 1, appearance: {}, settings: {}, pages: [] }))
            compare(store.pageCount(), 0, "applyExternal accepts an intentionally-blank layout")
            // load() of the same saved doc should be consistent (also blank).
            _bridge.stored = docStr({ version: 1, appearance: {}, settings: {}, pages: [] })
            store.load("productivity")
            compare(store.pageCount(), 0,
                "load() should honour a saved pages:[] consistently with applyExternal, not re-seed")
        }

        // (BUG) applyExternal() does not stop a pending debounced save, so the
        // externally-applied doc gets echoed back to the hub 400ms later.
        function test_applyExternal_cancels_pending_save() {
            store.load("blank"); store.flushNow(); _bridge.reset()
            store.setSetting("someTile", "k", 1)    // schedules saveTimer (400ms), no save yet
            compare(_bridge.saveCount, 0, "settings edit is debounced, not saved yet")
            store.applyExternal(docStr({ version: 1, appearance: {}, settings: {},
                pages: [ { name: "Ext", tiles: [] } ] }))
            wait(600)                                 // let any pending timer fire
            compare(_bridge.saveCount, 0,
                "applyExternal should cancel the pending save so external state is never written back")
        }

        // (OK) applyExternal rejects clearly invalid docs.
        function test_applyExternal_rejects_garbage() {
            verify(!store.applyExternal("not json"))
            verify(!store.applyExternal('{"no":"pages"}'))
        }
    }

    // ── 5. settingsFor / ensureSettings semantics ───────────────────────────
    TestCase {
        name: "StoreSettingsSemantics"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank"); _bridge.reset() }

        // (BUG) settingsFor() lazily creates a persisted empty {} entry as a
        // side effect of a read used inside widget bindings.
        function test_settingsFor_read_creates_no_persisted_entry() {
            verify(!store.data.settings.hasOwnProperty("ghost-id"), "precondition: no entry yet")
            store.settingsFor("ghost-id")
            verify(!store.data.settings.hasOwnProperty("ghost-id"),
                "reading settingsFor for an unknown id must not permanently create a persisted {} entry")
        }

        // (BUG) ensureSettings() seeds defaults but never bumps revision, so a
        // second instance (expanded overlay) never re-reads the seeded values.
        function test_ensureSettings_bumps_revision() {
            var r0 = store.revision
            store.ensureSettings("e1", { foo: 1, bar: 2 })
            verify(store.revision > r0,
                "ensureSettings should bump revision so a second instance sees the seeded defaults")
        }

        // (BUG) ensureSettings() never schedules a save, so seeded defaults are
        // lost if the app closes before any other mutation.
        function test_ensureSettings_schedules_save() {
            store.flushNow()   // stop any pending debounced save leaked from an earlier test
            _bridge.reset()
            store.ensureSettings("e2", { foo: 1 })
            wait(600)          // only a save scheduled BY ensureSettings could land here
            verify(_bridge.saveCount > 0,
                "ensureSettings should schedule a save so the seeded defaults are persisted")
        }

        // (OK) ensureSettings only fills missing keys, never clobbers existing.
        function test_ensureSettings_no_clobber() {
            store.setSetting("e3", "phase", "break")
            store.ensureSettings("e3", { phase: "work", running: false })
            compare(store.settingsFor("e3").phase, "break", "existing value kept")
            compare(store.settingsFor("e3").running, false, "missing default seeded")
        }

        // (OK) resetSettings deep-copies the defaults so two resets do not share
        // the same array/object reference.
        function test_resetSettings_deep_clones() {
            var defaults = { tasks: [], n: 0 }
            store.resetSettings("a", defaults)
            store.resetSettings("b", defaults)
            store.settingsFor("a").tasks.push("only-a")
            compare(store.settingsFor("a").tasks.length, 1)
            compare(store.settingsFor("b").tasks.length, 0, "b's array is independent")
            compare(defaults.tasks.length, 0, "the shared defaults object is untouched")
        }

        // (OK) resetSettings drops stale keys not present in defaults.
        function test_resetSettings_drops_stale_keys() {
            store.setSetting("c", "leftover", 42)
            store.resetSettings("c", { fresh: 1 })
            compare(store.settingsFor("c").fresh, 1)
            compare(store.settingsFor("c").leftover, undefined, "stale key removed")
        }

        // (OK) Two tiles added in quick succession get distinct ids AND distinct
        // settings objects.
        function test_two_tiles_distinct_ids_and_settings() {
            var a = store.addTile(0, "cpu")
            var b = store.addTile(0, "cpu")
            verify(a && b && a !== b, "distinct ids")
            store.setSetting(a, "x", 1)
            store.setSetting(b, "y", 2)
            verify(store.settingsFor(a) !== store.settingsFor(b), "distinct settings objects")
            compare(store.settingsFor(a).y, undefined, "settings objects do not bleed")
        }
    }

    // ── 6. Reactivity: revision vs structureRevision ────────────────────────
    TestCase {
        name: "StoreReactivity"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank"); _bridge.reset() }

        // (OK) Every kind of settings/appearance mutation bumps revision.
        function test_revision_bumps_on_every_settings_mutation() {
            var r = store.revision
            store.setSetting("t", "k", 1);              verify(store.revision > r, "setSetting bumps"); r = store.revision
            store.patchSettings("t", { k2: 2 });        verify(store.revision > r, "patchSettings bumps"); r = store.revision
            store.resetSettings("t", { k3: 3 });        verify(store.revision > r, "resetSettings bumps"); r = store.revision
            store.setAppearance("accent", "purple");    verify(store.revision > r, "setAppearance bumps")
        }

        // (OK) A structural edit bumps structureRevision; a settings edit does NOT
        // (so tile Loaders don't rebuild on every keystroke).
        function test_structureRevision_only_on_structural_edits() {
            var sr = store.structureRevision
            store.setSetting("t", "k", 1)
            compare(store.structureRevision, sr, "a settings edit must NOT bump structureRevision")
            store.addTile(0, "cpu")
            verify(store.structureRevision > sr, "a tile add must bump structureRevision")
        }

        // (OK) Per-page cols/background overrides are structural.
        function test_page_overrides_bump_structureRevision() {
            var sr = store.structureRevision
            store.setPageColumns(0, 2)
            verify(store.structureRevision > sr, "setPageColumns is structural"); sr = store.structureRevision
            store.setPageBackground(0, "style", "orbs")
            verify(store.structureRevision > sr, "setPageBackground is structural")
        }

        // (OK) Global appearance gridCols is readable + reactive via revision.
        function test_global_gridcols_appearance() {
            var r = store.revision
            store.setAppearance("gridCols", 2)
            compare(store.appearance().gridCols, 2)
            verify(store.revision > r, "appearance change is revision-keyed")
        }
    }

    // ── 7. Page / tile utility behaviour ────────────────────────────────────
    TestCase {
        name: "StorePageUtils"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank") }

        // (OK) setPageColumns(0) and negatives clear the override; fallback is 0.
        function test_setPageColumns_clear() {
            store.setPageColumns(0, 4)
            compare(store.pageColumns(0), 4)
            store.setPageColumns(0, 0)
            compare(store.pageColumns(0), 0, "0 clears the override")
            store.setPageColumns(0, 5)
            store.setPageColumns(0, -1)
            compare(store.pageColumns(0), 0, "a negative value clears the override")
        }

        // (OK) setPageBackground clears on empty value.
        function test_setPageBackground_clear() {
            store.setPageBackground(0, "style", "waves")
            compare(store.pageBackground(0).style, "waves")
            store.setPageBackground(0, "style", "")
            compare(store.pageBackground(0).style, undefined, "empty value clears the override")
        }

        // (OK) renamePage trims, keeps the old name when blank, de-dupes.
        function test_renamePage_validation() {
            var was = store.pages()[0].name
            store.renamePage(0, "   ")
            compare(store.pages()[0].name, was, "blank rename keeps the old name")
            store.renamePage(0, "  Work  ")
            compare(store.pages()[0].name, "Work", "trimmed")
            store.addPage("Play")
            store.renamePage(1, "Work")     // collides with page 0
            verify(store.pages()[1].name !== "Work", "duplicate disambiguated, got " + store.pages()[1].name)
        }

        // (OK) _uniquePageName avoids collisions.
        function test_unique_page_name() {
            store.addPage(""); store.addPage("")
            var names = store.pages().map(function (p) { return p.name })
            var seen = {}
            for (var i = 0; i < names.length; i++) {
                verify(seen[names[i]] === undefined, "no duplicate page name: " + names[i])
                seen[names[i]] = true
            }
        }

        // (OK) moveTile clamps and has no off-by-one at first/last positions.
        function test_moveTile_first_and_last() {
            var a = store.addTile(0, "cpu")
            var b = store.addTile(0, "gpu")
            var c = store.addTile(0, "ram")
            store.moveTile(0, 2, 0)   // ram to the very front
            compare(store.pages()[0].tiles[0].id, c, "moved to first position")
            store.moveTile(0, 0, 99)  // clamp to last
            compare(store.pages()[0].tiles[store.pages()[0].tiles.length - 1].id, c, "clamped to last")
        }

        // (OK) bounds-guarded page ops don't throw.
        function test_page_ops_bounds_guarded() {
            var threw = false
            try {
                store.setPageColumns(99, 2)
                store.setPageBackground(-1, "style", "x")
                store.renamePage(99, "z")
            } catch (e) { threw = true }
            verify(!threw, "out-of-range page ops are guarded")
            compare(store.pageColumns(99), 0, "oob pageColumns falls back to 0")
        }
    }

    // ── 8. Id generation / collisions ───────────────────────────────────────
    TestCase {
        name: "StoreIds"
        when: windowShown
        function init() { _bridge.reset(); store.load("blank") }

        // (BUG) seed()/_mk() mint ids as `type-<idSeq>` with no revision suffix,
        // and _idSeq resets to 0 every launch — so a fresh-launch seed reproduces
        // an id that a persisted tile still owns settings for, silently sharing state.
        function test_seed_ids_can_collide_with_persisted_settings() {
            store.setSetting("clock-0", "persisted", 1)   // as if left over from a prior session
            store._idSeq = 0                               // simulate the fresh-launch counter reset
            var doc = store.seed("minimal")                // first tile type is "clock"
            var firstId = doc.pages[0].tiles[0].id
            compare(firstId, "clock-0", "mechanism: _mk reproduces clock-0 after the counter reset")
            verify(!store.data.settings.hasOwnProperty(firstId),
                "a freshly-seeded id must not collide with an existing tile's persisted settings")
        }

        // (OK) Within a live session, addTile ids are globally distinct.
        function test_addTile_ids_globally_distinct() {
            var seen = {}
            for (var i = 0; i < 6; i++) {
                var id = store.addTile(0, "cpu")
                verify(seen[id] === undefined, "addTile id reused: " + id)
                seen[id] = true
            }
        }
    }
}
