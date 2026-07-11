# Xeneon Edge Linux Hub — Roadmap

**Last Updated:** 2026-07-11  

---

## Phase 0: Discovery (Completed — July 2026) ✅

**Goal:** Establish product foundation, make irreversible architectural decisions, define MVP boundaries.

### Deliverables
- [x] Product vision document
- [x] User personas
- [x] Use cases
- [x] MVP scope definition
- [x] Technology comparison and stack selection ADR (Rust + Qt 6/QML selected)
- [x] Widget runtime ADR (Hybrid QML + WASM)
- [x] Threat model
- [x] Test strategy
- [x] Architecture overview
- [x] Initial wireframe descriptions (portrait + landscape)
- [x] Repository structure setup
- [x] CI pipeline skeleton

### Decision Points (Resolved)
- ✅ Application stack: Rust + Qt 6/QML (see ADR 0001)
- ✅ Widget runtime: Hybrid QML trusted + WASM sandbox for community (see ADR 0002)
- ✅ Build system: CMake + Cargo (Corrosion bridge for Rust)
- ✅ Documentation: Markdown in-repo (future: MkDocs Material or mdBook)

---

## Phase 1: Application Shell (Current — July 2026) 🔄

**Goal:** Buildable application that opens a window on the correct display and persists settings.

### Deliverables
- [x] Rust core library with FFI (config, display, metrics, logging)
- [x] 15 unit tests passing, clippy clean, cargo fmt clean
- [x] C FFI header (xeneon_core.h)
- [ ] CMake installed on dev machine (needs sudo pacman -S cmake)
- [x] C++ application entry point (main.cpp)
- [x] QML: FirstRunWizard, Dashboard with clock/CPU/RAM widgets
- [x] QML resource file
- [x] Build script with dependency checks
- [x] Desktop entry file
- [ ] Full CMake build verified (blocked: cmake not installed)
- [ ] Display enumeration via Qt QScreen API
- [ ] EDID-based display identity storage
- [ ] First-run wizard UI wired to C++ back-end
- [ ] Borderless fullscreen window on selected display
- [ ] Portrait and landscape orientation detection
- [ ] Basic touch event handling
- [ ] Configuration persistence (XDG directories, versioned schema)
- [ ] Structured logging (Rust tracing + Qt log bridge)
- [ ] Diagnostics screen
- [ ] Clean shutdown and restart

### Tests
- [ ] Unit: Display identity serialization/deserialization
- [ ] Unit: Configuration read/write/migration
- [ ] Unit: Orientation math and layout calculations
- [ ] Integration: Display enumeration on X11 and Wayland
- [ ] Integration: Window placement and fullscreen
- [ ] Integration: Configuration persistence across restarts
- [ ] UI: First-run wizard flow

---

## Phase 2: Layout Engine (Target: September 2026)

**Goal:** Responsive widget grid, edit mode, themes, multi-page dashboards.

### Deliverables
- [ ] Responsive grid layout engine
- [ ] Widget container with minimum/maximum sizes
- [ ] Edit mode (grid overlay, drag handles)
- [ ] Add widget catalog
- [ ] Remove widget
- [ ] Move widget (drag and drop)
- [ ] Resize widget (corner/edge handles)
- [ ] Duplicate widget
- [ ] Lock/unlock widget
- [ ] Undo/redo stack
- [ ] Orientation-specific layouts
- [ ] Multiple dashboard pages
- [ ] Page switching via swipe
- [ ] Theme system (dark, light, OLED, high contrast)
- [ ] Accent color selection
- [ ] Reduced motion mode
- [ ] Widget lifecycle management (init, update, render, teardown)
- [ ] Widget error boundaries
- [ ] Widget disable-on-repeated-failure

### Tests
- [ ] Unit: Grid layout calculations (various resolutions, orientations)
- [ ] Unit: Undo/redo stack operations
- [ ] Unit: Theme property resolution
- [ ] Integration: Widget lifecycle (add, move, resize, remove, duplicate)
- [ ] Integration: Layout persistence across restarts
- [ ] Integration: Page switching
- [ ] UI: Edit mode touch interactions
- [ ] UI: Theme switching
- [ ] UI: Widget error states

---

## Phase 3: Core Widgets (Target: October 2026)

**Goal:** All MVP widgets implemented and functional.

### Deliverables — System Widgets
- [ ] Clock widget (12h/24h, timezone, analog option later)
- [ ] Date widget (configurable format)
- [ ] CPU usage widget (percentage, per-core toggle, sparkline)
- [ ] CPU temperature widget (via hwmon, configurable sensor)
- [ ] RAM usage widget (percentage, absolute, sparkline)
- [ ] Disk usage widget (per-mount, percentage, absolute)
- [ ] Network throughput widget (per-interface, up/down)

### Deliverables — Productivity Widgets
- [ ] Focus timer widget (configurable duration, count-up/down)
- [ ] Current goal widget (editable text, single focus)
- [ ] Top-three priorities widget (editable checklist)
- [ ] Quick note widget (auto-saving scratchpad)
- [ ] Break reminder widget (configurable interval, gentle alert)

### Deliverables — Media Widgets
- [ ] MPRIS media control widget (play/pause, prev/next, progress, track info, album art)
- [ ] Volume control widget (PipeWire/PulseAudio)

### Deliverables — Control Widgets
- [ ] Application launcher widget (.desktop integration, custom commands)
- [ ] Page switcher widget
- [ ] Lock screen widget

### Tests
- [ ] Unit: System metric parsing from /proc and /sys
- [ ] Unit: Widget configuration schema validation
- [ ] Unit: Timer logic and accuracy
- [ ] Integration: MPRIS D-Bus communication
- [ ] Integration: PipeWire/PulseAudio volume control
- [ ] Integration: Application launch via .desktop
- [ ] UI: Each widget in view mode and edit mode
- [ ] UI: Widget configuration panels

---

## Phase 4: Integrations (Target: November 2026)

**Goal:** System integrations working reliably.

### Deliverables
- [ ] MPRIS adapter (player detection, metadata, control)
- [ ] PipeWire/PulseAudio adapter (volume, mute, default device)
- [ ] System sensors adapter (hwmon, /proc, /sys, lm-sensors)
- [ ] GPU metrics adapter (basic sysfs for AMD/Intel; NVML stubs for NVIDIA)
- [ ] Autostart integration (.desktop autostart, systemd user service option)
- [ ] Display hotplug detection (udev or compositor events)
- [ ] Display reconnection logic with EDID matching
- [ ] Notification on primary display (D-Bus notifications or libnotify)

### Tests
- [ ] Integration: MPRIS player lifecycle (appear, play, pause, disappear)
- [ ] Integration: Volume changes via PipeWire
- [ ] Integration: Sensor reading on various hardware
- [ ] Integration: Autostart entry creation and removal
- [ ] Integration: Display hotplug simulation
- [ ] Integration: Notification display

---

## Phase 5: Hardening (Target: December 2026)

**Goal:** Production-ready stability, performance, and packaging.

### Deliverables
- [ ] Performance profiling and optimization
- [ ] Memory leak detection and fix (valgrind, heaptrack)
- [ ] CPU usage optimization (reduce polling, batch updates)
- [ ] Startup time optimization
- [ ] Display reconnection robustness testing
- [ ] Suspend/resume testing
- [ ] Compositor restart handling
- [ ] Corrupted settings recovery
- [ ] Safe mode (disable all widgets, load defaults)
- [ ] Emergency reset command (`xeneon-edge-hub --reset`)
- [ ] Arch/CachyOS PKGBUILD
- [ ] Ubuntu/Debian packaging
- [ ] Desktop entry and icons
- [ ] Application metadata (AppStream)
- [ ] Complete user documentation
- [ ] Complete developer documentation
- [ ] Release notes template

### Tests
- [ ] Performance: Idle CPU and RAM baselines
- [ ] Performance: 10, 25, 50 widget load tests
- [ ] Stability: 24-hour continuous run
- [ ] Stability: 100 display disconnect/reconnect cycles
- [ ] Stability: 50 suspend/resume cycles
- [ ] Stability: Corrupted config recovery
- [ ] Packaging: Clean install/uninstall on CachyOS
- [ ] Packaging: Clean install/uninstall on Ubuntu 24.04
- [ ] Packaging: Upgrade from previous version

---

## Phase 6: Public MVP Release (Target: January 2027)

**Goal:** Signed, documented, stable public release.

### Deliverables
- [ ] Version 0.1.0 tagged release
- [ ] Signed release artifacts
- [ ] Arch/CachyOS package published (AUR or custom repo)
- [ ] Ubuntu .deb package published
- [ ] Flatpak (if ready) or AppImage
- [ ] Release notes with known limitations
- [ ] Public roadmap updated
- [ ] Contribution guide finalized
- [ ] Security policy published
- [ ] Demo video or screenshots
- [ ] Community communication channels (Discord, GitHub Discussions)

---

## Phase 7: Community Widget SDK (Target: Q2 2027)

**Goal:** Enable third-party widgets with stable SDK and sandboxing.

### Prerequisites
- [ ] Core application stable (no major API changes for 2+ months)
- [ ] Internal widget API well-defined and tested
- [ ] Sandbox mechanism chosen and prototyped

### Deliverables
- [ ] Widget manifest specification v1.0
- [ ] Widget SDK crate/library
- [ ] Permission system implementation
- [ ] Sandboxed widget runtime (WASM, seccomp, or process isolation)
- [ ] Widget development guide
- [ ] Widget validation tool (lint, security scan, compatibility check)
- [ ] 3+ example community widgets
- [ ] Widget submission and review process
- [ ] Community widget repository (git-based)

---

## Beyond v1.0 (Post-MVP)

### v1.1 (Q2 2027)
- Gaming profile auto-switch
- Web content widget (sandboxed embedded browser)
- OpenLinkHub integration
- Calendar agenda widget
- Weather widget
- Discord integration (where possible)
- OBS/stream controls
- Fedora RPM
- openSUSE RPM

### v1.2 (Q3 2027)
- Widget marketplace UI
- Habit tracker widget
- Visual regression test suite
- Multi-language support (i18n)
- Accessibility audit and improvements
- On-screen keyboard integration
- Multi-touch gesture support
- Nix package

### v2.0 (2028+)
- Cross-platform support evaluation (other OS if demand exists)
- Cloud sync for configurations (optional, privacy-preserving)
- AI-powered widget suggestions (optional, local processing)
- Advanced automation and scripting widgets
