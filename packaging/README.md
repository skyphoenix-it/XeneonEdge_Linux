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
| **CPack .deb/.rpm/.tgz** | `CMakeLists.txt` (CPack block) | ✅ TGZ tested; DEB/RPM configured (build on Debian/Fedora) |
| **AppImage** | `packaging/appimage/build-appimage.sh` | ⚠️ recipe written, not build-tested here |
| **Flatpak** | `packaging/flatpak/` | ⚠️ starter manifest, open items (see `flatpak/README.md`) |

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
