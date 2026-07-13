# Session handoff — continue from here

_Last updated: 2026-07-13 (Manager UI/UX + robustness session, autonomous). On
`master`; PR #1 (`552729c`) plus follow-up direct-to-master commits, CI green._

## Current state: GREEN — 95%+ coverage across all layers

Full plan + results: `docs/DEV_AND_TEST_PLAN.md`, `docs/MANAGER_UIUX_PLAN.md`. Run
everything: `./scripts/run_all_tests.sh` (→ `RESULT: SUCCESS`); coverage: `./scripts/coverage.sh`.

- **Build**: `./scripts/build.sh release` — clean (hub + manager).
- **QML**: `./scripts/run_ui_tests.sh` — ALL UI TESTS PASSED. Behavior matrix
  `python3 scripts/qml_coverage.py` — **100%** (165/165).
- **Rust**: `cd core && cargo test` — **116 passed**; **97.4%** line (config.rs 98.3%).
- **C++**: `./scripts/run_cpp_tests.sh` — **15/15 ctest**; ~97% filtered line.

### Post-PR#1 work (this session, newest first)
- **Manager UI/UX + themes + robustness** (`8df1ccc`/`fafb133` + follow-ups): dark
  `QPalette` on both apps (config Switch/Slider/Button/ScrollBar/dialog buttons no
  longer render as pale Fusion), restyled config controls, **config live-preview now
  scales to fit** (no clipped action rows), hover/cursor affordances. **Themes 8→16**
  (synthwave/cyberpunk/deep_forest/deep_ocean/ember/vaporwave/rose_gold/matrix),
  **accents 8→14**. `_normaliseDoc` is now a **validator** (corrupt/hostile pages/tiles/
  tasks can't blank the dashboard). IPC RX-cap, 25 MB image guard, saveError signal.
- **Single-instance guard** (`53e9dfa`): `app/src/single_instance.h` (QLockFile) on
  both apps — a 2nd hub/manager exits instead of racing config.toml (skipped when
  `XENEON_GRAB` set so QA grabs still work). This is the fix for the multi-writer
  config churn seen with several instances up at once.
- **Config self-binding fix** (`a11e24b`): `WidgetConfigPanel` property renamed
  `store`→`st` — `store: store` at the call sites self-bound to null, so the ENTIRE
  config form (hub + Manager) showed defaults + dropped edits. Regression gate
  `tst_config_panel_wiring.qml`.
- **Version in UI** (`0fb8ceb`): git-describe → `XENEON_VERSION` → `appVersion()` →
  Manager nav + hub Diagnostics. PKGBUILD passes `-DXENEON_VERSION_OVERRIDE`.
- New tests: `tst_config_panel_wiring`, `tst_all_widget_configs` (all 23 types render),
  `tst_store_validation`, `tst_single_instance` (C++), `tst_rx_cap` (C++).

### Prior test-push (PR #1)
- **On-device**: hub dashboard, Manager, and an expanded widget config all verified
  via `XENEON_GRAB` captures on the real Edge (DP-3). Wallpaper with spaces + `#`
  in the path loads correctly through `configBridge.imageUrl()`.

## What the last few commits did (newest first)

- **`736ba9f` — stop rewriting config.toml every 2s.** Metric widgets (cpu/gpu/ram/net)
  mirror sparkline history (`hist`/`peakRx`/`peakTx`) into the store every sample; the
  store used to persist every write → the hub rewrote `config.toml` ~every 2s forever
  (flash wear + a two-writer atomic-rename race with the Manager: "Failed to save
  config: No such file or directory"). Those keys are now **ephemeral** in
  `DashboardStore.qml` (`_ephemeralKeys`): kept in memory for compact↔expanded sparkline
  sharing, but a volatile-only write bumps `revision` without scheduling a save, and
  `_persistableData()` strips them from disk. Idle saves: ~1/2s → 0. 2 new regression
  tests in `tst_store_tiles.qml`.
- **`7cd491e` — shell/manager bug sweep + cross-file wiring.** Integrated the 8-agent
  QML fixes (Manager S2/S11/imageUrl/syncTheme guard/tall-tile clone/dialog/wizard; hub
  Dashboard S7/gridCols/expand/overlay-close, SettingsPanel S2, Diagnostics scroll+labels,
  main.qml keyboard-lift+diagnostics bindings). Plus the cross-file bits the agents could
  not do: `ConfigBridge::imageUrl()` on the **hub** (hub exposes `configBridge`, NOT the
  Manager's `backend`), S9 screen-hotplug rebuild+push of `screensData`, S7 accent on
  `WidgetChrome`'s BackdropLayer.
- **`ee63764`** — the big Phase 0–3 widget/shared-infra/Rust/C++ bug fixes.
- **`a5a742a`** — generated regression suites + `docs/BUG_FIX_PLAN.md` (the master plan).

## Remaining work (prioritized)

The three former items are now **DONE** this session:
1. ~~**S10 — write-only FFI config keys**~~ ✅ Added `xeneon_config_get_reconnect` +
   `get_notify_disconnect` to `ffi.rs`/`xeneon_core.h`, exposed all three via `ConfigBridge`
   (`reconnectOnHotplug`/`notifyOnDisconnect`/`fallbackBehavior`), and wired the hub
   `screenAdded`/`screenRemoved` handlers to honor them (reconnect→re-match+migrate window;
   notify→disconnect notice; fallback=="hide"→blank). Gated by `tst_config_bridge`.
2. ~~**Two-writer atomic-save race**~~ ✅ Single-writer: when the hub is connected the Manager
   pushes `setUiState` over IPC only and does NOT write `config.toml`; it writes directly only
   when offline. Gated by `tst_manager_backend_sync` (+ the #7 edit-loss fix).
3. ~~**Duplicate "Page 5" pages**~~ ✅ `_normaliseDoc` now de-dupes `pages[].name` on
   `load`/`applyExternal` (appends " 2", " 3", …). Gated by `tst_store_dedup`.

Still open (documented, non-blocking): `config.rs` ~93% line (merged gate passes at
96.64%; a corrupt-path IO test would close it); `mpris_bridge.cpp` D-Bus fan-out uncovered
(needs a session bus).

### CI is now live (first real run this session)
The trigger was fixed (`main`→`[main, master]`), so CI ran for the first time and surfaced
five environment/latent issues, all fixed in PR #1: Qt ≥6.5 via `jurplel/install-qt-action`
(apt Qt 6.4.2 lacks `MultiEffect`/`QtQml.WorkerScript`); a JS reserved-word (`float`) var
Qt 6.7 rejects; a font-metric test made deterministic (assert bounded box, not glyph ink) +
fonts installed; a **real widget bug** — `CountdownWidget` used `Layout.maximumWidth` which
Qt 6.7 ignores for oversized text, so a 5-digit day count could overflow (fixed with
`Layout.preferredWidth`); and `pipx gcovr` so CI honors the `GCOVR_EXCL` hardware-exclusion
markers (apt gcovr didn't → understated C++ coverage → merged 94.10%). CI runs Qt 6.7.3 via
aqt (older than the dev box's 6.11) on purpose — it catches exactly this class of bug.

## Key context for continuing

- **The plan**: `docs/BUG_FIX_PLAN.md` (systemic S1–S12 + discrete findings, phased).
- **Manager plan**: `.claude/plans/crystalline-mixing-hopper.md` (detailed Manager findings
  A1–A21 / B1–B18 / C P1–P3). Most are done; cross-check before re-doing.
- **CRITICAL runtime distinction**: the **hub** process exposes `configBridge` (no
  `backend`); the **Manager** process exposes `backend` (`ManagerBackend`, has `imageUrl`,
  `screensJson`, autostart, IPC). QML shared by both must feature-detect.
- **Config sync (already implemented, `manager/src/main.cpp`)**: pushLive buffers +
  flushes on `connected`, 2s reconnect timer, getUiState pull heartbeat with reconnect
  conflict-resolution (`m_pendingPushAwaitingHub`), `QFileSystemWatcher` on config.toml,
  `screensChanged` NOTIFY.
- **On-device capture**: `DISPLAY=:0 XENEON_GRAB=/path/out.png XENEON_GRAB_W=720
  XENEON_GRAB_H=2560 ./build/xeneon-edge-hub --windowed` (renders one frame → PNG → quits).
  `XENEON_EXPAND=<type>` auto-opens that widget's expanded config. Manager: same
  `XENEON_GRAB` env. Test against a temp `XDG_CONFIG_HOME` to avoid touching the live config.
- **Synthetic touch / hardware E2E**: `tests/hardware/edge_hw_test.py` (+ `uinput_touch.py`).
- Auto-memory (persists across sessions): `dashboard-architecture`, `product-decisions`,
  `companion-and-testing`, `packaging` — read the index at
  `~/.claude/projects/-home-simon-IdeaProjects-XeneonEdge-Linux/memory/MEMORY.md`.
