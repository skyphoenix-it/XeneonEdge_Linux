# Release media validation, 2026-07-21

## Result

**PASS.** The beta.1 marketing video and launch stills show real output from the
exact signed portable candidate. The physical display baseline and the user's
normal Hub configuration were restored and verified after capture.

## Candidate identity

| Item | Verified value |
|---|---|
| Tag | `v1.0.0-beta.1` |
| Commit | `009f2892d2c9426dc19d2fa25c3ad86611820ae0` |
| Hub version | `1.0.0-beta.1` |
| Manager version | `1.0.0-beta.1` |
| Hub binary SHA-256 | `6663d80961fafa84a81f270fefe4b6668df4df85a8ff9ea4e9bc7c6169d80b86` |
| Manager binary SHA-256 | `66213bf7d535b52042df9119b303e308e8a15abcff5fe5036e21103727e32eac` |
| Portable payload SHA-256 | `39d812a31e1f6aa948f46604adb6744703379deceafadb83ae73488b57e23313` |

## Capture environment and controls

- KDE Plasma on Wayland, captured through Spectacle and compositor APIs.
- Physical Edge output: `DP-3`.
- Baseline: `720x2560` logical, right rotation, position `5120,2880`.
- Hub and Manager used isolated temporary `XDG_CONFIG_HOME` and runtime paths.
- The normal Hub configuration hash stayed
  `05221f282de252f1568a5e59728a47cbc43cd08042b00c88c8d8fbfc205ffd8a`
  before and after the campaign.
- Physical orientation was changed through KScreen, verified in landscape, and
  restored to the exact baseline in a `finally` path.
- Full-desktop capture frames were private temporary files. They were cropped
  immediately to the target application or output and then removed.
- A rejected Manager crop that included the desktop underneath was not used. Its
  four derived images and stale manifest were moved to the desktop Trash and are
  recoverable there.
- The capture helper refuses to operate without explicit marketing-capture and
  physical-display opt-ins, validates the candidate version, and proves that the
  Manager is frontmost before taking Manager frames.

## Behavior shown

Two guarded exact-candidate integration sequences passed:

1. Manager reflection: 8/8 checks. Screen state, light and matrix themes,
   portrait preview, landscape preview, and matched Hub landscape were visible.
2. Manager-to-Hub screen mirror: 8/8 checks. Real Manager input selected pages
   2, 0, 3, and 1; the physical Hub reported the same pages. Adding a fifth
   screen selected new page 4 on the Hub and the Hub remained alive.

Portrait and landscape Hub heroes were captured from the physical output. The
landscape frame uses KScreen rotation with Hub orientation set to `auto`, which
avoids double rotation and demonstrates the shipped reflow behavior.

## Published media

The feature tour is an edited sequence of verified real product captures, not a
continuous raw screen recording. Slow zooms, fades, captions, and an end card are
editorial additions. No synthetic UI, pointer simulation, fake product state,
or fabricated performance data is presented as live behavior.

| Asset | Value |
|---|---|
| Video | `edgehub-v1.0.0-beta.1-feature-tour.mp4` |
| Format | H.264 MP4, 1920x1080, 30 fps, no audio |
| Duration | 52 seconds |
| SHA-256 | `91f12a297df65dd70db287a6e3b965f709df99fefc85cc55a5529be4ef550488` |
| Captions | `docs/marketing/release-kit/video-captions.vtt` |
| Asset hashes | `docs/marketing-site/assets/release/v1.0.0-beta.1/SHA256SUMS` |

The website hero, social landscape, social square, video thumbnail, native Hub
captures, and Manager captures are derived from those verified frames. Designed
campaign assets avoid third-party logos and include the independent-project
disclaimer where legal context is needed.

## Reproduction

Use `scripts/capture_release_media.py` to perform a guarded exact-candidate
capture and `scripts/render_release_video.sh` to render the final tour. The
capture helper must never be used to bypass the repository's synthetic-input
activity guard.
