# Distributing, Packaging & Monetizing

How to let other people install this, and your options for making money.

---

## 1. What users need to build & run

**Runtime:** a Linux desktop with **Qt6 ≥ 6.5** (Quick, QuickControls2, Svg, DBus,
Network, VirtualKeyboard) and a working GPU/compositor. No web browser, no server.
The ≥ 6.5 floor is real — the widgets use `QtQuick.Effects`, which does not exist
before it.

**Build:** a C++17 toolchain, CMake ≥ 3.22, the Rust toolchain (`cargo`), and the
Qt6 dev packages. See `docs/installation/` for per-distro package lists
(`cachyos.md`, `ubuntu.md`, `generic-linux.md`), and
`.github/workflows/distro.yml` for the exact, CI-executed Fedora/Ubuntu lists.

### Distro support (what CI actually proves)

`.github/workflows/distro.yml` builds against each distro's **own** Qt packages,
then installs the resulting package into a **clean** container (no Qt, no
`-devel`) and launches it offscreen. Verified:

| Distro | Distro's Qt | Status |
|---|---|---|
| **Fedora 43** | 6.10.3 | ✅ builds, RPM installs clean, launches |
| **Ubuntu 26.04 LTS** | 6.10.2 | ✅ builds, DEB installs clean, launches |
| **Arch / CachyOS** | rolling | ✅ dev box + AUR (`makepkg`) |
| **Ubuntu 24.04 LTS** | 6.4.2 | ❌ Qt too old for `QtQuick.Effects` — use the AppImage |

Both Fedora 43 and Ubuntu 26.04 now ship Qt ≥ 6.5 themselves, so building from
source on either needs nothing beyond the distro's own packages. (`ci.yml` still
installs Qt 6.7 via `jurplel/install-qt-action` because its jobs run on Ubuntu
24.04, whose apt Qt is 6.4.2.)

### AppImage

Built by `packaging/appimage/build-appimage.sh` on **Ubuntu 24.04 + upstream Qt
6.7.3** (aqtinstall / `install-qt-action`), not 24.04's own Qt 6.4.2. That pairing
is deliberate: an AppImage's glibc floor is its build host's, so the oldest
practical distro gives the widest reach, while the bundled Qt still has to be
≥ 6.5 for `QtQuick.Effects`. ~46 MB, bundles 41 Qt libraries.

**What it does not bundle, by design:** `libGL`/`libGLX`/`libOpenGL`/`libEGL` and
`libfontconfig` + fonts. `linuxdeploy` excludes the graphics stack on purpose — a
bundled `libGL` breaks on a host with a different (e.g. NVIDIA) driver, so GL must
come from the host. Every normal desktop already has these; a bare container does
not, which is why `appimage-smoke` installs exactly that set (and nothing from Qt)
before running.

Verified in a bare `ubuntu:24.04` container with **no Qt and no Rust**: launches
offscreen and all nine imported QML modules are present inside the AppImage.

The AppImage cannot install the auto-rotate udev rule (no package manager hooks) —
users install `packaging/udev/99-xeneon-edge.rules` by hand. Everything else works.

#### The two traps this recipe encodes

Both were hit for real while getting it to build, and both fail *silently*:

1. **No `--executable`** → `linuxdeploy` scans nothing, the Qt plugin reports
   `Found Qt modules:` (empty), and you get a ~29 MB "AppImage" containing **no Qt
   and no QML at all** — which still exits 0 and looks like a successful build.
2. **Qt not on `LD_LIBRARY_PATH`** → same silent-empty outcome (or
   `Could not find dependency: libQt6DBus.so.6`), because a Qt outside the ldconfig
   cache (`/opt/Qt/...`) is invisible to dependency resolution.

`QML_SOURCES_PATHS` is equally load-bearing: the QML is compiled into the binaries
via qrc, so `qmlimportscanner` has no `.qml` files to read and must be pointed at
the source tree — otherwise the lazily-imported modules are dropped and the app
**still starts cleanly**, then fails when a widget loads.

### Do they need sudo?

**To build and run: no.** The whole thing works from a normal user build:

```sh
git clone <repo> && cd xeneon-edge-linux-hub
./scripts/build.sh release
./build/xeneon-edge-hub        # the dashboard
./build/xeneon-edge-manager    # the companion app
```

Config lives in `~/.config/xeneon-edge-hub/`. Metrics come from world-readable
`/proc` and `/sys`; media from the session D-Bus. None of that needs root.

**Sudo is needed only for two optional things:**

1. **A system-wide install** (`sudo cmake --install build`) — or install to
   `~/.local` with `-DCMAKE_INSTALL_PREFIX=~/.local` and skip sudo entirely.
2. **Auto-rotate** — the Edge's orientation sensor lives on a root-only HID node,
   so the one-time udev rule in `packaging/udev/99-xeneon-edge.rules` must be
   installed with sudo:
   ```sh
   sudo cp packaging/udev/99-xeneon-edge.rules /etc/udev/rules.d/
   sudo udevadm control --reload && sudo udevadm trigger --action=change --subsystem-match=hidraw
   ```
   Without it, everything works except auto-rotate (manual orientation modes still
   do). This is a genuine hardware-permission requirement, not app design.

So: **"clone, build, run" is clean and sudo-free.** Auto-rotate is the only thing
that asks for a one-line root command, and it degrades gracefully without it.

---

## 2. Packaging formats

Ranked by effort-vs-reach for this app:

| Format | Best for | Notes |
|---|---|---|
| **AppImage** | Widest reach, zero install | One portable file that bundles Qt. Ship the udev rule + a helper script alongside. Easiest for non-technical users. Recommended first target. |
| **AUR (PKGBUILD)** | Arch / CachyOS (your distro) | Cheap to maintain; installs the udev rule as part of the package. Great starting point since you're on CachyOS. |
| **.deb / .rpm** | Ubuntu 26.04+ & Fedora | `cpack` generates these from CMake; the udev rule ships under `/usr/lib/udev/rules.d`. Both are CI-verified end to end (build → install on a clean image → launch). Note the `.deb` must list every `qml6-module-*` by hand — `dpkg-shlibdeps` cannot see dlopen'd QML plugins. See `packaging/README.md`. |
| **Flatpak / Flathub** | Discoverability + auto-update + a built-in donation link | Sandboxed — you must grant `--device=all` (or specific hidraw) and `/proc`/`/sys` access, and the udev rule still has to be installed on the host. More work; do it after AppImage/AUR. |

Practical rollout: **AUR first** (you, today) → **AppImage** (everyone) →
**Flathub** (reach + donations) later.

The CMake install already places the binaries, the `.desktop` entry, and the udev
rule (`-DUDEV_RULES_DIR=/etc/udev/rules.d` for a real system path). `cpack` on top
gives you `.deb`/`.rpm`/`.tar.gz` for free.

---

## 3. Licensing (the part that decides your money options)

- **This project is MIT** (`LICENSE`) — the most permissive license. You may sell
  it, ship binaries, and build a business on it. So can everyone else (MIT lets
  others redistribute too), which is why the usual model here is **goodwill +
  donations + paid extras**, not locked-down sales.
- **Qt6 is LGPLv3** (or a paid Qt commercial license). Dynamically linking it — as
  this app does — is fine for both open-source and commercial distribution, as
  long as users can replace/relink the Qt libraries. AppImage/Flatpak that ship Qt
  as separate `.so` files satisfy this. You do **not** need a paid Qt license.
- **Rust crates** are MIT/Apache-2.0; **Phosphor icons** are MIT. The whole stack
  is commercial-friendly.
- The Edge orientation protocol was **independently reverse-engineered from your
  own device's HID reports** — no third-party (e.g. GPL) code was copied, so it
  doesn't encumber the MIT license.

> If you ever want to sell a **closed-source "Pro" edition**, keep the open core
> MIT and put the proprietary widgets/features in a separate, differently-licensed
> module. The MIT core stays free; your additions can be commercial.

---

## 4. Making money (you want to, but don't have to)

Low-friction, community-friendly options — you can stack several:

**Donations (easiest, keeps everything free & open):**
- **GitHub Sponsors** — zero fees, shows on the repo, monthly or one-off.
- **Ko-fi / Buy Me a Coffee** — one-off tips, no account needed by donors.
- **Liberapay / Open Collective** — recurring, transparent, FOSS-friendly.
- Add a `.github/FUNDING.yml` so a **Sponsor** button appears on the repo, and a
  "Support this project" section in the README with the links.

**Paid, while staying open:**
- **Flathub + donation link** — reach + a prominent donate button.
- **Sell convenience, not the code:** paid AppImage/installer on **itch.io** or
  **Gumroad** ("pay what you want", suggested price), pre-built & signed, so people
  who don't want to compile just buy it. The source stays free.
- **Paid support / setup / custom widgets** — consulting or commissioned widgets.
- **A "Pro" widget pack** (proprietary module on the MIT core) — advanced/branded
  widgets, integrations (Home Assistant, stocks, calendars), sold once or as a
  small subscription.

**Recommended starting point:** MIT core stays free; add **GitHub Sponsors +
Ko-fi** now (5 minutes), ship an **AUR package** and an **AppImage** so people can
actually use it, and put a friendly "if this is useful, buy me a coffee" line in
the README. If it gets traction, add a **Pro widget pack** for real revenue. This
keeps goodwill high (which drives adoption) while leaving the door open to income.

**Don't:** relicense away from MIT retroactively (you can't, for existing
contributions, without every contributor's consent), or hide the whole thing
behind a paywall (kills the community that makes it valuable).

---

## 5. Checklist to go public

- [ ] Fill in the real repo URL/badges in `README.md` (currently `your-org`).
- [ ] Confirm per-distro build docs in `docs/installation/` are current.
- [ ] Add `.github/FUNDING.yml` + a Support section in the README.
- [ ] Write an AUR `PKGBUILD` (installs binaries + udev rule).
- [x] Produce an AppImage (bundles Qt; builds + runs on a host with no Qt).
      Still open: ship an install helper for the udev rule alongside it.
- [x] `.deb`/`.rpm` build + install + launch verified in CI (`distro.yml`).
- [ ] Tag a release; attach the AppImage + `.deb`/`.rpm` from `cpack`.
- [ ] (Later) Flathub submission.

See also: [authoring widgets](widgets/authoring.md) · [installation](installation/).
