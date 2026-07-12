# Real-hardware tests (Xeneon Edge)

Headless end-to-end tests that run against the **actual Edge panel** — interaction
(synthetic touch), live IPC, performance, and stability. Complements the offscreen
`tests/ui` qmltest suite, which can't exercise the real compositor, touch input, or
the C++ backend on-device.

## Requirements

- The Edge connected and enabled (normally DP-3). The hub auto-detects it.
- A release build: `./scripts/build.sh release` (produces `build/xeneon-edge-hub`).
- `/dev/uinput` writable by your user — for synthetic touch. On this box the
  openlinkhub/Corsair daemon grants it via an ACL (`getfacl /dev/uinput` should show
  `user:<you>:rw-`). Otherwise add yourself to the `input` group.
- `python3` with `PIL` (Pillow) only if you want screenshots; the test itself needs
  no third-party packages. `kscreen-doctor` (KDE) is used to auto-detect geometry;
  override with `XENEON_EDGE_GEOM="x,y,w,h"` and `XENEON_CANVAS="w,h"` on other setups.
- No hub already running (the test launches its own and owns the control socket).

## Run

```sh
python3 tests/hardware/edge_hw_test.py     # exits 0 on pass, 1 on any failure; prints JSON
```

It **backs up and restores** `~/.config/xeneon-edge-hub/config.toml` (a live
`setUiState` persists to disk), so your layout/appearance is untouched.

## What it covers

- **Launch/placement** on the Edge + control socket comes up.
- **IPC**: `ping`, 300 `getUiState` round-trips (latency p50/p99), 25 concurrent
  connections, 500 connect/disconnect cycles — no drops.
- **Robustness**: malformed JSON, a >8 MB oversized message, and a partial message
  are all handled without crashing the hub.
- **Synthetic touch** (real events via a pure-python uinput virtual pointer): opens a
  tile's expanded overlay, taps the Focus preset segments and **verifies via
  `getUiState` that `cfg.preset` changed** (skipped if page 0 has no Focus tile),
  closes via the Done bar, swipes between pages, and runs a 40-tap storm.
- **Stability/perf**: no fd/thread leak, RSS reported, clean shutdown (exit 0).

## Files

- `uinput_touch.py` — reusable pure-python synthetic touch/pointer (no sudo, no
  ydotool). `VPointer` + `detect_edge()`. See its header for the two Wayland gotchas
  (24-byte `input_event` packing; the move→settle→click sequence).
- `edge_hw_test.py` — the consolidated test above.

## Not covered (needs a human)

- **Physical rotation → auto-rotate**: the sensor is read from `/dev/hidraw5` and the
  pipeline is wired + debounced, but only a person can physically turn the panel.
- Subjective feel (animation smoothness, readability at arm's length).
