**The first beta — feature-freeze, and the Pro tier is here.**

Every artifact below is signed by GPG key `2F0CAD36DC1D46F3347B7EF293CDC77EACF98990` (SKYPhoenix IT). Verify before installing — see [Verifying your download](https://github.com/skyphoenix-it/XeneonEdge_Linux#verifying-your-download):

```sh
gpg --import edgehub-signing.pub          # from the repo, or your keyring
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum -c SHA256SUMS
```

---

## Since alpha.2

### Pro — a low-cost supporter tier
Xeneon Edge stays **free and fully functional**. Pro adds cosmetic extras — the first is a **premium theme pack** (Synthwave, Cyberpunk, Vaporwave, Matrix, and the five distro themes); ~20 themes remain free, and no widget, accessibility feature, or data source is ever gated. A Pro key is an **offline, signed token**: verified on-device with no network and no hardware fingerprint (identical under `unshare -n`), and any bad key silently reads as free. Paste it in **Manager → About → Activate Pro** — it verifies as you type and unlocks live, no restart.

### The sizing rework, part 2
Every widget is now genuinely *designed* for each size it declares — in both orientations — rather than one layout stretched. Tile reorders and edits **glide** instead of teleporting; removed tiles fade, added tiles arrive.

### Manager clarity
Every control carries a scope tag (this widget / this page / everywhere), the copy says what each setting actually does, Appearance previews live, and the preset library is reachable after setup — not just in the wizard.

### Calm by default
A fresh install is quiet: Atkinson Hyperlegible font, no animated background, no glow — opt into the ambient effects when you want them. Motion transitions stay on; reduce-motion is still its own respected setting.

### Updates that stick
An installed **AppImage can now self-update** (embedded update-information → zsync delta). The local update flow restarts **both** the hub and the Manager, so you're never left half-upgraded.

### Fixed
A long tail of correctness work: a gauge reading that overflowed its ring on some fonts, a Hydration overlay that spilled off a landscape screen, a medication test that failed every night at midnight, three tests that never actually ran, a `--reset` that destroyed your layout with no backup, a security-report address that pointed at an unregistered domain, and ~202 MB of accidentally-committed build output. See the [CHANGELOG](https://github.com/skyphoenix-it/XeneonEdge_Linux/blob/master/CHANGELOG.md).

## Install
**Arch/CachyOS**: `yay -S xeneon-edge-hub` (AUR), the portable tarball below, or source. **Fedora/Ubuntu**: RPM/DEB from CI or source. **Anything else**: portable tarball, AppImage, or source.

> Beta: feature-frozen — only fixes from here to RC and GA. The motion and sizing work is verified in the automated suite; if anything feels off on your panel, please open an issue.

**Not affiliated with Corsair.** MIT OR Apache-2.0.
