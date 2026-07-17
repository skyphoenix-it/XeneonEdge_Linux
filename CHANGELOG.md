# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

## [1.0.0-beta.1] - 2026-07-17

First public **beta**. Everything from alpha.2 plus the beta workstreams (sizing,
Manager clarity, widget smoothness), the Pro tier, and a long tail of correctness
fixes. Feature-freeze from here — beta → RC → GA is fixes only.

### Added
- **Pro tier (licensing).** Offline, signed Ed25519 licence keys (`XE1.…`),
  verified on-device with no network and no hardware fingerprint; any bad key
  fails soft to Free. A paste-your-key dialog in the Manager (About) verifies as
  you type and re-gates live over the control socket without a restart. The first
  premium content is a **premium theme pack** (Synthwave, Cyberpunk, Vaporwave,
  Matrix + the five distro themes); ~20 themes stay free and nothing functional is
  ever gated. Issuer tooling (`tools/license-tool`, `scripts/mint-license.sh`) and
  `docs/LICENSING.md` for selling via Lemon Squeezy / Gumroad.
- **W1 — per-size widget layouts.** Every widget genuinely designed for each size
  it declares, in both orientations, keyed off `sizeClass` (not the modal overlay).
  Waves 1–3 across all widgets; `habit` gained a real transposed `1x1.5` map.
- **W2 — Manager UX clarity.** A defined scope vocabulary with a tag on every
  control, honest copy, live Appearance preview, and a post-setup Screens picker
  so the preset library is no longer wizard-only.
- **W3 — widget smoothness.** Tile reorder MOVES instead of teleporting (Dashboard
  and the Manager's Edge clone), removed tiles fade out and added tiles arrive,
  eased gauges, and stable sensor rows that update values without rebuilding.
- **AppImage self-update.** Embedded `X-AppImage-UpdateInformation` (gh-releases
  zsync) so an installed AppImage can discover and delta-patch to the next release.
- **Diagnostics:** the Network tab surfaces the NetHub egress counters.
- Nine runtime end-to-end scenarios (up from one) driving the real hub binary.

### Changed
- **Accessibility-forward defaults:** Atkinson Hyperlegible is the default font,
  and a fresh install is calm/quiet (animated background and widget glow off).
  Motion transitions stay on; reduce-motion remains a separate, respected setting.
- `--reset` now backs up `config.toml` to `config.toml.bak` before clearing, and
  refuses if the backup fails — a mistyped `--reset` is no longer unrecoverable.
- The local update flow (`scripts/update-local.sh`) restarts BOTH the hub and the
  Manager onto the new build.

### Fixed
- The RAM/gauge ring's centre reading overflowed when the mono font fell back to a
  proportional face (`Layout.maximumWidth` inert without a paired `preferredWidth`);
  fixed here and at three sibling sites.
- The Hydration expanded overlay overran its box in landscape (fixed literals);
  now room-derived.
- `tst_meds` failed every night between 00:00–00:10 (a bare `HH:mm` schedule read
  as a future dose); pinned to an injected clock.
- Three tests that never executed (QtTest's `test_*_data` data-provider trap),
  plus a family of gates that reported success while doing no work — all now
  assert their own subjects exist. A live-test lint (`check_live_tests.sh`) gates
  the class in CI.
- The Manager's About "GitHub" button opened `"#"` and did nothing.
- Security policy (`SECURITY.md`) pointed vulnerability reports at an unregistered
  domain; replaced with GitHub private vulnerability reporting.
- Docs CI had been red over a link that was actually valid; the checker now strips
  anchors and verifies them.
- The local dogfood build versioned *below* the installed release (a `pacman -U`
  downgrade); pkgver is now tag-derived.
- Removed ~202 MB of accidentally-committed makepkg build output.

### Security
- Licence verification is offline and fails-soft; the private issuer seed is never
  in the repo or CI. GitHub private vulnerability reporting enabled.

---

## [1.0.0-alpha.2] - 2026-07-16
First signed release; AUR package live. Curated 15-screen preset library, HTTP/JSON
+ KPI primitive widgets behind the NetHub egress gate, org-managed policy, offline
licence-verification scaffolding, and the hardened control-socket / hermetic-test
foundations.

## [1.0.0-alpha.1] - 2026-07
Initial alpha: Rust core + Qt6/QML dashboard, first-run wizard, the widget set,
display matching, and the CI/coverage gates.

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0-beta.1 | 2026-07-17 | First public beta: Pro tier, sizing, Manager clarity, smoothness |
| 1.0.0-alpha.2 | 2026-07-16 | First signed release; AUR live |
| 1.0.0-alpha.1 | 2026-07 | Initial alpha |
| 0.0.0 | 2026-07-11 | Project inception — Phase 0 Discovery |
