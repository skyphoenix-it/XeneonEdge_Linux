---
name: ci-setup
description: "GitHub Actions CI structure, coverage gates, and the Qt/gcovr/parser gotchas found when CI first ran"
metadata: 
  node_type: memory
  type: project
  originSessionId: 24803e10-a7cf-4b4e-8964-f63f8db8828e
---

CI lives in `.github/workflows/ci.yml` (added/fixed 2026-07-13, PR #1). It had NEVER
run before because it triggered only on `main` while the repo is on `master` — fixed to
`branches: [main, master]` on push + pull_request. `concurrency` cancels superseded runs.

**9 jobs:** `format` (cargo fmt), `lint` (clippy -D warnings), `test` (cargo test),
`audit` (cargo-audit), `build` (cmake Release), `docs` (md link check), `qml-test`
(offscreen qmltestrunner + `scripts/qml_coverage.py` gate), `cpp-test` (cmake
`-DXENEON_BUILD_TESTS=ON -DXENEON_COVERAGE=ON` + ctest + gcovr → uploads `cpp-lcov`
artifact), `coverage` (needs `[test, cpp-test]`: cargo-llvm-cov for Rust, downloads
cpp-lcov, `lcov` merge, gates **Rust ≥95 AND merged Rust+C++ ≥95** via a DA-line count).
Measured green: Rust 96.04%, merged 96.64%, QML behavior-matrix 99.4%. See
[[companion-and-testing]] for the test suites themselves.

GOTCHAS (each cost a red CI run the first time CI ever executed — the dev box is Qt
**6.11.1**, CI runs Qt **6.7.3**, so version-specific issues ONLY show in CI):

1. **apt Qt on ubuntu-24.04 is 6.4.2 — too old.** The app requires Qt ≥6.5
   (`CMakeLists.txt` `find_package(Qt6 6.5 …)`; uses `QtQuick.Effects`/MultiEffect), and
   the minimal `qt6-declarative-dev` also lacks bundled QML modules the widgets pull in
   (`QtQml.WorkerScript` — "module … is not installed"). FIX: install Qt via
   `jurplel/install-qt-action@v4` `version: '6.7.3'` `modules: 'qtvirtualkeyboard'`
   `cache: true` in the build/qml-test/cpp-test jobs (NOT apt qt6-*-dev). It ships a full
   Qt with all QML modules + `qmltestrunner` (added to PATH, so `run_ui_tests.sh` finds
   it). Running the OLDER 6.7.3 (not the dev 6.11) is deliberate — it catches #3/#4 below.

2. **gcovr MUST come from pipx, not apt.** The C++ sources mark hardware/QScreen/QProcess
   glue with in-source `// GCOVR_EXCL_START/STOP/LINE`. apt gcovr does NOT honor them, so
   it counts those lines (e.g. `orientation_sensor.cpp` 57% / 114 lines instead of the
   excluded ~100% / fewer lines) → C++ ~85% → **merged coverage 94.10% < 95, gate fails**.
   FIX: `pipx install gcovr` (preinstalled on the runner) + `echo "$HOME/.local/bin" >>
   $GITHUB_PATH`; matches the local gcovr 8.x → excluded lines dropped → C++ 96.7% → merged
   96.64%. Locally: gcovr installed via `uv tool install gcovr` (pip/pip3 are BOTH absent
   on this CachyOS dev box — `uv` works).

3. **Qt 6.7 V4 parser is stricter than 6.9+** in ways that pass locally but fail CI:
   (a) a JS reserved word used as an identifier — `var float = …` — is rejected with
   "Expected token `identifier'" (6.9 tolerated it). Never name a var `float`/`int`/`char`
   /etc. (b) `Layout.maximumWidth` is IGNORED for an oversized `implicitWidth` on 6.7, so a
   shrink-to-fit Text (`fontSizeMode: HorizontalFit`) overflows — a REAL widget bug on
   older Qt. FIX: use `Layout.preferredWidth` (forces the layout to allocate exactly that
   box) alongside maximumWidth. (Found in `CountdownWidget` — the number could overflow.)

4. **Headless font metrics are non-deterministic.** Under `QT_QPA_PLATFORM=offscreen` with
   NO font installed, `Text.fontSizeMode` fit and `paintedWidth` produce meaningless values
   (the countdown fit test failed only on CI). FIX (both): install `fonts-dejavu-core`
   `fontconfig` (+ `fc-cache -f`) on the qml-test job, AND assert the STRUCTURAL guarantee
   (the layout-bounded box `num.width <= avail`) rather than glyph ink (`paintedWidth`),
   which is what `docs/DEV_AND_TEST_PLAN.md` calls "genuinely unmeasurable headless".

RULE: because the dev box (Qt 6.11) is far ahead of CI (Qt 6.7), always assume CI can catch
parser/layout/coverage-tool differences the local suite can't. When a CI-only QML failure
appears, suspect (in order) missing Qt module → reserved-word/parser strictness → Layout
cap-vs-preferred → font/offscreen metrics → gcovr version. [[packaging]] covers the
runtime Qt deps; [[dashboard-architecture]] the widget contract.
