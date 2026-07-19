# EdgeHub — Free vs Pro

*Draft store copy. Every claim below is derived from the code in this repository;
sources are cited inline. Read the "Unverified" section at the end before publishing.*

---

## What EdgeHub is

EdgeHub turns a Corsair Xeneon Edge — the 2560×720 secondary touchscreen — into a
native Linux widget dashboard. Swipeable pages of live widgets you arrange by
touch, right on the panel. It also runs on any other secondary or portrait
display.

A Rust core handles metrics and configuration; Qt 6/QML draws the interface.
There is no browser engine, no Electron, no bundled web server, and no account.
A companion desktop app, **EdgeHub Manager**, mirrors the Edge live so you can
design your layout from your main monitor.

Source: `README.md`, `docs/architecture/overview.md`

---

## The short version

**EdgeHub is free and complete. Pro is a cosmetic supporter tier.**

Pro adds 9 extra colour themes. That is the entire functional difference in the
current code. No widget, no layout feature, no data source and no part of the
Manager is behind the licence. If a theme pack is not worth money to you, the free
build is not a crippled version of anything — it is the whole product.

We would rather say that plainly than have you discover it after paying.

---

## Free vs Pro

| | **Free** | **Pro** |
|---|---|---|
| Widgets | **All 30** | All 30 (same) |
| Widget categories | System, Time, Focus, Media, Data, Info | Same |
| Ready-made preset screens | **All 19** | All 19 (same) |
| Colour themes | **20** | **29** (all 20 free + 9 Pro) |
| — Standard group | 19 | 19 |
| — Premium group (Synthwave, Cyberpunk, Vaporwave, Matrix) | — | **4** |
| — Inspired group (Keystone, Cascade, Swirl, Trilby, Fizz) | — | **5** |
| — Accessibility group (Contrast) | 1 | 1 |
| Accent colours | **22** (14 standard + 8 Okabe–Ito colour-blind-safe) | 22 (same) |
| Animated backgrounds | **All 11** | All 11 (same) |
| Bundled wallpapers | **All 18** | All 18 (same) |
| Custom wallpaper upload | Yes | Yes |
| Multi-page dashboards | Yes | Yes |
| Both orientations (portrait + landscape) | Yes | Yes |
| HID rotation sensor following the panel | Yes | Yes |
| EdgeHub Manager (live clone, drag/resize/restyle) | Yes | Yes |
| Live data widgets (HTTP/JSON, KPI) | Yes | Yes |
| Weather, ICS calendar, media control | Yes | Yes |
| Accessibility (reduce-motion, high contrast, large touch targets) | Yes | Yes |
| Updates | Yes | Yes |

Counts verified against `ui/qml/WidgetCatalog.qml` (30 entries),
`ui/qml/PresetCatalog.qml` (19 entries), `ui/qml/Theme.qml` (`themeCatalog`,
29 entries of which 9 carry `pro: true`; `accentPresets`, 22 entries),
`ui/qml/BackgroundCatalog.qml` (11 styles), `ui/qml/WallpaperCatalog.qml`
(18 bundled images).

---

## What Pro does **not** gate

This is the section that matters most, so it is explicit.

- **Every widget is free.** All 30 entries in `ui/qml/WidgetCatalog.qml` — including
  the live-data ones (HTTP/JSON, KPI), the system monitors, the focus and health
  widgets — carry no `pro` flag. There is no such flag in the widget registry at all.
- **Every preset screen is free.** All 19 entries in `ui/qml/PresetCatalog.qml`,
  including the developer, homelab, trading-desk, analyst and enterprise screens.
- **Every animated background and every bundled wallpaper is free.** Neither catalog
  has a gating flag.
- **Every accent colour is free**, including the 8-colour Okabe–Ito palette chosen to
  stay distinguishable under protanopia, deuteranopia and tritanopia.
- **All layout features are free** — multi-page dashboards, every widget size, both
  orientations, drag/resize/reorder.
- **EdgeHub Manager is free**, in full.
- **Accessibility is free.** The high-contrast theme sits in the free Accessibility
  group; reduce-motion and touch-target sizing are unconditional.
- **Updates are free**, and a Pro key never expires unless it was explicitly issued
  with an expiry (`--expires` defaults to `never` — `docs/LICENSING.md`).
- **Nothing degrades if your licence lapses.** An expired key resolves to the free
  tier: your dashboards, widgets, layouts and data connections keep working
  untouched. Only the 9 Pro themes stop being selectable
  (`core/src/license.rs`, `Status::Expired → Tier::Free`).

The only gate in the codebase is one flag on nine theme entries and one
`license.isPro` check in each of the two theme pickers
(`ui/qml/widgets/SettingsPanel.qml:169`, `manager/qml/Manager.qml:406`/`:1058`).

---

## Why buy Pro, then?

Two honest reasons, and no others:

1. **You want the themes.** Synthwave, Cyberpunk, Vaporwave, Matrix, and five
   distribution-flavoured looks (Keystone, Cascade, Swirl, Trilby, Fizz). They are
   original palettes, not reproductions of anyone's branding.
2. **You want the project to keep going.** EdgeHub is open source (MIT OR
   Apache-2.0) and there is no other revenue in it. Pro is the supporter tier.

If neither is true for you, use the free build with our blessing. It is not a trial.

---

## Privacy and offline properties

These are verifiable claims, not marketing adjectives.

**Your licence never touches the network.** A Pro key is an offline, signed
`XE1.<payload>.<signature>` token verified against an Ed25519 public key compiled
into the app. Verifying it opens no socket, reads no file, and uses no hardware
fingerprint — the result is identical under `unshare -n`. There is no activation
server and no "phone home". The key is not a secret and is safe to keep in plain
`config.toml`; the entitlement is recomputed from the signature every time rather
than trusted from a stored flag.
Source: `core/src/license.rs`, `docs/LICENSING.md`, `app/src/license_bridge.h`

**It fails soft, never hard.** Any bad key — empty, garbage, forged, expired, or
signed for a future format — resolves to the free tier. It never panics and never
blocks the app.
Source: `core/src/license.rs` (`Status::Unlicensed`/`Expired` → `Tier::Free`),
covered by the unit tests in that file.

**One audited network choke point.** Every outbound request from every widget goes
through a single gate, `ui/qml/widgets/NetHub.qml`, which enforces a global offline
kill switch and an optional host allowlist. A CI lint
(`scripts/check_no_raw_xhr.sh`) fails the build the moment any file outside that
gate constructs its own `XMLHttpRequest`, with no exemption list. The gate's
ordering is tested offline against a fake transport in `tests/ui/tst_nethub.qml`.

**No telemetry, no account, no cloud.** EdgeHub reaches the network only for widgets
you explicitly configure — Weather, a calendar feed, or a data widget you pointed
somewhere — and all of it goes through the gate above.

---

## Honest note on how thin Pro currently is

Flagged for the owner, not for the store page.

- **Pro is 9 themes.** That is the whole delta. `docs/LICENSING.md` describes the
  *intent* as "premium themes, premium preset packs, and custom user widgets", but
  no preset carries a `pro` flag and `ui/qml/UserWidgetCatalog.qml` performs no
  licence check. Only themes are actually gated today.
- **The in-app copy already overstates this.** `manager/qml/Manager.qml:1780` tells
  free users "Pro adds premium themes, preset packs and custom widgets", and the
  expired-licence string says "Renew to keep the premium extras". Both promise more
  than the code delivers. Fix the string or ship the gating before selling.
- **Pricing implication.** At 9 cosmetic themes, this reads as a €3–7 tip jar, not a
  €15+ upgrade. Anything priced as a feature tier will feel like the "scam" you
  wanted to avoid. If you want a higher price point, gate the premium preset packs
  and/or custom user widgets first — `docs/LICENSING.md` notes gating is a one-line
  `pro:` flag per item.
- **The "Get Pro" button points at a GitHub anchor**
  (`manager/qml/Manager.qml:1797` → `.../XeneonEdge_Linux#pro`), not a store. That
  needs to be the real product URL before launch.

---

## Unverified — do not publish without checking

Claims that appear in existing repo copy but that I could **not** confirm from the
code, or that depend on something outside it:

1. **"~3.5% CPU"** (`docs/LAUNCH_COPY.md:74`). No benchmark in the repo supports
   this. Do not repeat it without a fresh measurement on target hardware.
2. **"15 ready-made screens"** (`README.md`). The catalog contains **19**. One of
   the two is stale — the table above uses 19, the code's number.
3. **Alpha status.** `README.md` states the current release is an unsigned alpha
   with "still fluid" feature set and widget sizing being reworked. Selling Pro
   against an alpha is a business decision; the store page should say so.
4. **Purchase and delivery flow.** `docs/LICENSING.md` describes Lemon Squeezy /
   Gumroad integration and a mint webhook, but I did not verify that a store
   product, price, or working delivery pipeline exists. Confirm before publishing
   any "instant delivery" wording.
5. **Refund policy, support commitments, and platform/distro compatibility list.**
   Not derivable from the code. Write these yourself.
6. **Theme screenshots.** The nine Pro themes are defined as palettes in
   `Theme.qml`; I did not render them. Capture real screenshots — for a purely
   cosmetic tier, the screenshots *are* the product page.
7. **Trademark posture of the "Inspired" themes.** The names were deliberately made
   non-nominative (Keystone, Cascade, Swirl, Trilby, Fizz) and the code comments
   claim no logo is reproduced. That is a design intent recorded in comments, not a
   legal review. Get one before shipping paid distro-flavoured cosmetics.
