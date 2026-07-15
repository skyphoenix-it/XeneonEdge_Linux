# Packaging

Distro packages for the Xeneon Edge Linux Hub (and the bundled Manager). See
`docs/DISTRIBUTION.md` for the strategy/rationale. Rollout order: **AUR → AppImage
→ .deb/.rpm → Flatpak**.

Shared install metadata lives in `assets/` and is wired into `install(...)` in the
top-level `CMakeLists.txt`: both `.desktop` files, both AppStream `metainfo` files,
the hicolor icons (scalable SVG + PNG 16–512), the `LICENSE`, and the udev rule.

| Format | Location | Status |
|---|---|---|
| **AUR** | `packaging/aur/` (`PKGBUILD`, `.SRCINFO`, `.install`) | ✅ build-tested with `makepkg` |
| **CPack .rpm** | `CMakeLists.txt` (CPack block) | ✅ Fedora 43: built, installed on a clean image, launches (CI: `distro.yml`) |
| **CPack .deb** | `CMakeLists.txt` (CPack block) | ✅ Ubuntu 26.04 LTS: built, installed on a clean image, launches (CI: `distro.yml`) |
| **CPack .tgz** | `CMakeLists.txt` (CPack block) | ✅ TGZ tested |
| **AppImage** | `packaging/appimage/build-appimage.sh` | ⚠️ recipe written, not build-tested here |
| **Flatpak** | `packaging/flatpak/` | ⚠️ starter manifest, open items (see `flatpak/README.md`) |

"Installs on a clean image" means the package was installed into a container with
**no Qt and no `-devel` packages present**, so its declared dependencies had to
pull the entire runtime themselves. Installing into the build container proves
nothing — the `-devel` packages already dragged Qt in.

### Verified distro support

| Distro | Qt (distro's own) | Build | Package | Clean install | Launch |
|---|---|---|---|---|---|
| Fedora 43 | 6.10.3 | ✅ | ✅ RPM | ✅ | ✅ |
| Ubuntu 26.04 LTS | 6.10.2 | ✅ | ✅ DEB | ✅ | ✅ |
| Arch / CachyOS | rolling | ✅ (dev box + AUR) | ✅ AUR | — | ✅ |

Both distros now ship Qt ≥ 6.5 in their own repos, so neither needs the
`jurplel/install-qt-action` Qt that `ci.yml` uses for the Ubuntu 24.04 jobs
(24.04's apt Qt is 6.4.2 — too old for `QtQuick.Effects`).

Ubuntu 24.04 LTS is **not** supported for the `.deb`: its Qt is 6.4.2 and the app
requires ≥ 6.5. 24.04 users need the AppImage or a backported Qt.

### The .deb dependency gotcha

QML modules are `dlopen`'d plugins, so `dpkg-shlibdeps` cannot see them, and
Debian/Ubuntu ship each as a separate `qml6-module-*` package. With only the
shlibdeps-derived list the `.deb` installed perfectly and then died on launch:

```
module "QtQuick.Controls" plugin "qtquickcontrols2plugin" not found
```

`CPACK_DEBIAN_PACKAGE_DEPENDS` in `CMakeLists.txt` therefore lists every
`qml6-module-*` explicitly; keep it in sync with the `import` lines under
`ui/qml/` and `manager/`. Fedora needs no equivalent — `qt6-qtdeclarative`
bundles all of them in one RPM.

`packaging/ci/smoke.sh` guards this. It launches the installed binary offscreen
**and** checks every module imported by the sources is present, because launching
alone is not enough: `main.qml` only imports QtQuick/Controls/Layouts/Window/
VirtualKeyboard, so `QtQuick.Effects`/`Shapes`/`Dialogs` (reached via lazily
loaded widgets) can be missing and the app still starts cleanly for 10s.

## AUR

```sh
cd packaging/aur
makepkg -si            # build + install (fetches the v$pkgver release tarball)
```
Publishing: push `PKGBUILD` + `.SRCINFO` to `ssh://aur@aur.archlinux.org/xeneon-edge-hub.git`.
Requires a tagged GitHub release `v0.1.0` (the source URL points at the release tarball).
Before publishing, replace `sha256sums=('SKIP')` with the real checksum
(`updpkgsums`).

## CPack (.deb / .rpm / portable tarball)

Configure + build the project, then from the build dir:

```sh
cpack -G TGZ           # portable tarball (works anywhere)
cpack -G DEB           # on Debian/Ubuntu (needs dpkg for shlibdeps)
cpack -G RPM           # on Fedora/openSUSE (needs rpmbuild)
```

Build each on the distro it targets — the generated dependency versions come from
whatever is installed on the build host. The exact per-distro build dependencies
are in `.github/workflows/distro.yml`, which is the executable version of this:

```sh
# Fedora 43
dnf -y install cmake gcc-c++ make rpm-build cargo rust mesa-libGL-devel \
  qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtsvg-devel \
  qt6-qtvirtualkeyboard-devel qt6-qtwayland-devel

# Ubuntu 26.04 LTS (ca-certificates is required or cargo's crates.io fetch
# fails with "[77] Problem with the SSL CA cert" on a bare image)
apt-get install -y ca-certificates cmake g++ make file dpkg-dev rustc cargo \
  libgl1-mesa-dev qt6-base-dev qt6-declarative-dev qt6-svg-dev \
  qt6-virtualkeyboard-dev
```

## AppImage

```sh
./packaging/appimage/build-appimage.sh
```
Downloads `linuxdeploy` + the Qt plugin and bundles Qt into a single portable
`.AppImage`. Run it on a normal desktop with the Qt6 dev stack.

## Flatpak

See `packaging/flatpak/README.md` — the manifest is a starting point; a Flathub
submission still needs cargo vendoring and the sandbox-access items resolved.

## Note on auto-rotate

No package format can enable the Edge's orientation sensor by itself — it lives on
a root-only hidraw node. The udev rule (`packaging/udev/99-xeneon-edge.rules`) is
installed by the AUR/deb/rpm packages under `/usr/lib/udev/rules.d`; AppImage/Flatpak
users install it manually. Everything else works without it (manual orientation
modes still apply).
