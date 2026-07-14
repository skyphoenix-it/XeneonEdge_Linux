import QtQuick
import QtTest
import "../../ui/qml" as App

// Theme (ui/qml/Theme.qml) — the design-token source + accent/theme appliers.
// Pure logic (a QtObject), so we assert the derived values directly.
Item {
    id: root
    width: 100; height: 100
    App.Theme { id: theme }

    // A pristine Theme, to assert the untouched defaults a pre-existing config
    // would land on (the shared `theme` above is mutated by other tests).
    Component { id: freshTheme; App.Theme {} }

    TestCase {
        name: "Theme"
        when: windowShown

        function init() {
            theme.applyTheme("dark"); theme.applyAccent("blue"); theme.glassOpacity = 0.6
            theme.reduceMotion = false; theme.systemReduceMotion = false
            theme.reduceMotionPreference = "auto"; theme.textScale = 1.0
        }

        // ── accentPresets ────────────────────────────────────────────────────
        function test_accent_presets_complete() {
            var names = ["blue","purple","green","orange","pink","teal","red","gold",
                         "cyan","indigo","mint","coral","amber","magenta"]
            compare(Object.keys(theme.accentPresets).length, 22, "fourteen house + eight Okabe–Ito accents")
            for (var i = 0; i < names.length; i++) {
                var p = theme.accentPresets[names[i]]
                verify(p && p.a !== undefined && p.b !== undefined, names[i] + " has a+b tones")
            }
        }

        // ── BACKWARD COMPATIBILITY ───────────────────────────────────────────
        // Accents are referenced BY NAME in saved configs (Dashboard.applyAppearance
        // → applyAccent(a.accent)), so adding names cannot shift an index — but it
        // could still silently retune a tone. These are the literal hexes shipped
        // before the Okabe–Ito set landed: an existing user's stored accent must
        // resolve to the SAME colour. Pinned as literals on purpose — comparing
        // against theme.accentPresets would just compare the table to itself.
        function test_existing_accents_resolve_unchanged() {
            var legacy = { "blue": "#58A6FF", "purple": "#A371F7", "green": "#3FB950",
                           "orange": "#F0883E", "pink": "#F778BA", "teal": "#56D4DD",
                           "red": "#F85149", "gold": "#E3B341", "cyan": "#22D3EE",
                           "indigo": "#818CF8", "mint": "#34D399", "coral": "#FB7185",
                           "amber": "#FBBF24", "magenta": "#E879F9" }
            for (var name in legacy) {
                theme.applyAccent(name)
                compare(theme.accentName, name, name + " still applies")
                verify(Qt.colorEqual(theme.accent, legacy[name]),
                       "stored accent '" + name + "' resolves to its original colour " + legacy[name])
            }
        }

        // A stored theme mode must keep painting the same surfaces too.
        function test_existing_theme_modes_resolve_unchanged() {
            theme.applyTheme("dark")
            verify(Qt.colorEqual(theme.backgroundColor, "#0D1117"), "dark background unchanged")
            verify(Qt.colorEqual(theme.cardBackground, "#161B22"), "dark card unchanged")
            verify(Qt.colorEqual(theme.textPrimary, "#E6EDF3"), "dark text unchanged")
            theme.applyTheme("nord")
            verify(Qt.colorEqual(theme.backgroundColor, "#2E3440"), "nord background unchanged")
        }

        // A config written before this change carries no textScale/preference; the
        // defaults must reproduce the OLD rendering exactly.
        function test_defaults_match_pre_change_rendering() {
            var fresh = freshTheme.createObject(root)
            compare(fresh.textScale, 1.0, "text scale defaults to 1.0")
            compare(fresh.fontData, 40, "fontData default unchanged")
            compare(fresh.fontDataLarge, 48, "fontDataLarge default unchanged")
            compare(fresh.fontTitle, 17, "fontTitle default unchanged")
            compare(fresh.fontLabel, 15, "fontLabel default unchanged")
            compare(fresh.fontCaption, 13, "fontCaption default unchanged")
            compare(fresh.reduceMotionPreference, "auto", "preference defaults to auto")
            compare(fresh.systemReduceMotion, false, "no OS signal by default")
            compare(fresh.effectiveReduceMotion, false, "motion stays on by default")
            compare(fresh.motionPage, 250, "motionPage default unchanged")
            fresh.destroy()
        }

        // ── Okabe–Ito colour-blind-safe accents ──────────────────────────────
        // Canonical CUD hexes — the palette's guarantee holds for the 8 together,
        // so a "close enough" tone silently breaks it. Pinned exactly.
        function test_okabe_ito_canonical_hexes() {
            var oi = { "oi_black": "#000000", "oi_orange": "#E69F00",
                       "oi_sky_blue": "#56B4E9", "oi_bluish_green": "#009E73",
                       "oi_yellow": "#F0E442", "oi_blue": "#0072B2",
                       "oi_vermillion": "#D55E00", "oi_reddish_purple": "#CC79A7" }
            var count = 0
            for (var name in oi) {
                var p = theme.accentPresets[name]
                verify(p && p.a !== undefined && p.b !== undefined, name + " has a+b tones")
                verify(Qt.colorEqual(p.a, oi[name]), name + " uses the canonical hex " + oi[name])
                theme.applyAccent(name)
                compare(theme.accentName, name, name + " applies")
                verify(Qt.colorEqual(theme.accent, oi[name]), name + " primary set")
                verify(Qt.colorEqual(theme.accent2, p.b), name + " secondary set")
                count++
            }
            compare(count, 8, "all eight Okabe–Ito accents present")
        }

        function test_okabe_ito_accents_are_mutually_distinct() {
            var names = ["oi_black","oi_orange","oi_sky_blue","oi_bluish_green",
                         "oi_yellow","oi_blue","oi_vermillion","oi_reddish_purple"]
            for (var i = 0; i < names.length; i++)
                for (var j = i + 1; j < names.length; j++)
                    verify(!Qt.colorEqual(theme.accentPresets[names[i]].a, theme.accentPresets[names[j]].a),
                           names[i] + " differs from " + names[j])
        }

        function test_okabe_ito_survives_theme_switch() {
            theme.applyAccent("oi_vermillion")
            theme.applyTheme("light")
            verify(Qt.colorEqual(theme.accent, "#D55E00"), "an Okabe–Ito accent survives a theme switch")
        }

        // ── applyAccent ──────────────────────────────────────────────────────
        function test_applyAccent_sets_primary_secondary_and_name() {
            theme.applyAccent("green")
            compare(theme.accentName, "green", "accentName updated")
            verify(Qt.colorEqual(theme.accent, theme.accentPresets["green"].a), "primary accent set")
            verify(Qt.colorEqual(theme.accent2, theme.accentPresets["green"].b), "secondary accent set")
        }

        function test_applyAccent_unknown_falls_back_to_blue() {
            theme.applyAccent("chartreuse")
            verify(Qt.colorEqual(theme.accent, theme.accentPresets["blue"].a),
                   "an unknown accent name falls back to blue")
        }

        // ── applyTheme ───────────────────────────────────────────────────────
        function test_applyTheme_light() {
            theme.applyTheme("light")
            verify(Qt.colorEqual(theme.backgroundColor, "#FFFFFF"), "light background")
            verify(Qt.colorEqual(theme.textPrimary, "#1F2328"), "light text")
            compare(theme.decorative, true, "light keeps decoration on")
            compare(theme.cardBorderWidth, 1, "light border width")
        }

        function test_applyTheme_dark_default() {
            theme.applyTheme("dark")
            verify(Qt.colorEqual(theme.backgroundColor, "#0D1117"), "dark background")
            compare(theme.decorative, true, "dark keeps decoration on")
        }

        function test_applyTheme_high_contrast_disables_decoration() {
            theme.applyTheme("high_contrast")
            compare(theme.decorative, false, "high-contrast turns decoration off")
            compare(theme.cardBorderWidth, 2, "high-contrast thickens the border")
            verify(Qt.colorEqual(theme.cardBorder, "#FFFFFF"), "high-contrast uses a white border")
        }

        function test_applyTheme_reapplies_accent() {
            theme.applyAccent("red")
            theme.applyTheme("midnight")   // ends with applyAccent(accentName)
            verify(Qt.colorEqual(theme.accent, theme.accentPresets["red"].a),
                   "applyTheme re-applies the current accent so it survives a mode switch")
        }

        function test_unknown_mode_uses_dark_default() {
            theme.applyTheme("banana")
            verify(Qt.colorEqual(theme.backgroundColor, "#0D1117"), "an unknown mode falls back to the dark default")
        }

        // ── New Phase-2 theme modes ──────────────────────────────────────────
        // Shared assertions: every token the appliers set is populated, the
        // theme is decorative (all 8 new modes are lush gradients), and the
        // primary text is legibly distinct from the background.
        function _assertThemeCoherent(mode, expectBg, expectDecorative) {
            theme.applyTheme(mode)
            verify(Qt.colorEqual(theme.backgroundColor, expectBg), mode + " sets its backgroundColor")
            // All colour tokens set (non-empty).
            verify(theme.backgroundColor2 != "" && theme.backgroundColor3 != "", mode + " sets bg2/bg3")
            verify(theme.cardBackground != "" && theme.cardBackgroundAlt != "" && theme.cardBorder != "",
                   mode + " sets card tokens")
            verify(theme.textPrimary != "" && theme.textSecondary != "" && theme.textTertiary != "",
                   mode + " sets text tokens")
            // Radii + border width set to sane positive values.
            verify(theme.radiusSm > 0 && theme.radiusMd > 0 && theme.radiusLg > 0 && theme.radiusXl > 0,
                   mode + " sets all radii")
            verify(theme.cardBorderWidth >= 1, mode + " sets a border width")
            compare(theme.decorative, expectDecorative, mode + " decorative flag")
            // Contrast: primary text must differ from the background.
            verify(!Qt.colorEqual(theme.textPrimary, theme.backgroundColor),
                   mode + " has text distinct from background")
        }

        function test_applyTheme_synthwave()   { _assertThemeCoherent("synthwave",   "#1A0B2E", true) }
        function test_applyTheme_cyberpunk()   { _assertThemeCoherent("cyberpunk",   "#04110F", true) }
        function test_applyTheme_deep_forest() { _assertThemeCoherent("deep_forest", "#0A1A0E", true) }
        function test_applyTheme_deep_ocean()  { _assertThemeCoherent("deep_ocean",  "#04121F", true) }
        function test_applyTheme_ember()       { _assertThemeCoherent("ember",       "#1A0E0A", true) }
        function test_applyTheme_vaporwave()   { _assertThemeCoherent("vaporwave",   "#1E0F2E", true) }
        function test_applyTheme_rose_gold()   { _assertThemeCoherent("rose_gold",   "#21121A", true) }
        function test_applyTheme_matrix()      { _assertThemeCoherent("matrix",      "#000000", true) }

        // ── Well-loved developer palettes (all dark, all decorative) ─────────
        function test_applyTheme_nord()        { _assertThemeCoherent("nord",        "#2E3440", true) }
        function test_applyTheme_dracula()     { _assertThemeCoherent("dracula",     "#282A36", true) }
        function test_applyTheme_solarized()   { _assertThemeCoherent("solarized",   "#002B36", true) }
        function test_applyTheme_gruvbox()     { _assertThemeCoherent("gruvbox",     "#282828", true) }
        function test_applyTheme_catppuccin()  { _assertThemeCoherent("catppuccin",  "#1E1E2E", true) }
        function test_applyTheme_tokyonight()  { _assertThemeCoherent("tokyonight",  "#1A1B26", true) }

        function test_new_accents_have_tones() {
            var names = ["cyan","indigo","mint","coral","amber","magenta"]
            for (var i = 0; i < names.length; i++) {
                var p = theme.accentPresets[names[i]]
                verify(p && p.a !== undefined && p.b !== undefined, names[i] + " has a+b tones")
                theme.applyAccent(names[i])
                compare(theme.accentName, names[i], names[i] + " applied")
                verify(Qt.colorEqual(theme.accent, p.a), names[i] + " primary set")
            }
        }

        // ── cardFill derivation ──────────────────────────────────────────────
        function test_cardFill_translucency_scales_with_glass() {
            theme.applyTheme("dark")   // decorative
            theme.glassOpacity = 0.0
            var opaqueA = theme.cardFill().a
            theme.glassOpacity = 1.0
            var glassA = theme.cardFill().a
            fuzzyCompare(opaqueA, 0.84, 0.001, "glass 0 → ~0.84 alpha (near opaque)")
            fuzzyCompare(glassA, 0.22, 0.001, "glass 1 → ~0.22 alpha (most translucent)")
            verify(opaqueA > glassA, "more glass means a more translucent card")
        }

        function test_cardFill_preserves_card_rgb() {
            theme.applyTheme("dark")
            var f = theme.cardFill()
            verify(Qt.colorEqual(Qt.rgba(f.r, f.g, f.b, 1), Qt.rgba(theme.cardBackground.r, theme.cardBackground.g, theme.cardBackground.b, 1)),
                   "cardFill keeps the cardBackground RGB, varying only alpha")
        }

        function test_cardFill_opaque_when_not_decorative() {
            theme.applyTheme("high_contrast")   // decorative false
            var f = theme.cardFill()
            verify(Qt.colorEqual(f, theme.cardBackground), "non-decorative themes use fully-opaque cards")
        }

        // ── Category colours are stable across theme switches ────────────────
        function test_category_colors_stable() {
            var before = [theme.catSystem, theme.catProductivity, theme.catInfo,
                          theme.catEntertainment, theme.catGaming, theme.catServices]
            theme.applyTheme("light"); theme.applyTheme("nebula"); theme.applyTheme("dark")
            var after = [theme.catSystem, theme.catProductivity, theme.catInfo,
                         theme.catEntertainment, theme.catGaming, theme.catServices]
            for (var i = 0; i < before.length; i++)
                verify(Qt.colorEqual(before[i], after[i]), "category colour " + i + " is stable across theme switches")
        }

        function test_category_colors_known_values() {
            verify(Qt.colorEqual(theme.catSystem, "#58A6FF"), "catSystem tone")
            verify(Qt.colorEqual(theme.catGaming, "#F0883E"), "catGaming tone")
        }

        // ── glass / glow aliases + motion tokens ─────────────────────────────
        function test_glass_glow_aliases() {
            theme.glassOpacity = 0.33
            fuzzyCompare(theme.glass, 0.33, 1e-9, "glass mirrors glassOpacity")
            theme.showWidgetGlow = false
            compare(theme.glow, false, "glow mirrors showWidgetGlow")
            theme.showWidgetGlow = true
        }

        function test_reduce_motion_zeroes_motion_tokens() {
            theme.reduceMotion = false
            verify(theme.motionPage > 0 && theme.motionFast > 0, "non-zero when motion allowed")
            theme.reduceMotion = true
            compare(theme.motionPage, 0, "motionPage zeroed")
            compare(theme.motionAdd, 0, "motionAdd zeroed")
            compare(theme.motionFast, 0, "motionFast zeroed")
            theme.reduceMotion = false
        }

        // ── Reduce-motion precedence: explicit > OS > legacy flag ────────────
        // The whole matrix is pinned, because the interesting cases are the
        // conflicts and a regression here is silent (motion just stops, or
        // doesn't). `data` rows: [preference, osSignal, configFlag, expected].
        function test_reduce_motion_precedence_data() {
            return [
                // No explicit choice → the OS signal decides.
                { tag: "auto/os-off/cfg-off", pref: "auto", os: false, cfg: false, expect: false },
                { tag: "auto/os-ON/cfg-off",  pref: "auto", os: true,  cfg: false, expect: true },
                // Legacy persisted flag still reduces motion on its own.
                { tag: "auto/os-off/cfg-ON",  pref: "auto", os: false, cfg: true,  expect: true },
                { tag: "auto/os-ON/cfg-ON",   pref: "auto", os: true,  cfg: true,  expect: true },
                // THE precedence case: the OS asks to reduce motion, the user has
                // explicitly said "off" on this device → the user wins, motion RUNS.
                { tag: "off/os-ON  (user beats OS)", pref: "off", os: true,  cfg: true,  expect: false },
                { tag: "off/os-off",                pref: "off", os: false, cfg: false, expect: false },
                // Explicit "on" reduces motion even with no OS signal at all.
                { tag: "on/os-off (user beats OS)",  pref: "on",  os: false, cfg: false, expect: true },
                { tag: "on/os-ON",                   pref: "on",  os: true,  cfg: true,  expect: true },
                // An unrecognised preference must degrade to "auto", never throw.
                { tag: "garbage → auto/os-ON",       pref: "zzz", os: true,  cfg: false, expect: true }
            ]
        }

        function test_reduce_motion_precedence(d) {
            theme.reduceMotionPreference = d.pref
            theme.systemReduceMotion = d.os
            theme.reduceMotion = d.cfg
            compare(theme.effectiveReduceMotion, d.expect, d.tag)
            compare(theme.motionPage, d.expect ? 0 : 250, d.tag + " → motionPage")
            compare(theme.motionFast, d.expect ? 0 : 150, d.tag + " → motionFast")
        }

        // The OS signal must never leak back into the persisted config flag —
        // main.qml aliases `reduceMotion` onto the saved value, so a write here
        // would rewrite the user's config from an unrelated desktop setting.
        function test_os_signal_does_not_mutate_config_flag() {
            theme.reduceMotion = false
            theme.systemReduceMotion = true
            compare(theme.effectiveReduceMotion, true, "OS signal reduces motion")
            compare(theme.reduceMotion, false, "…without touching the persisted flag")
        }

        function test_effective_reduce_motion_is_reactive() {
            theme.reduceMotionPreference = "auto"
            theme.systemReduceMotion = false
            compare(theme.motionPage, 250, "motion running")
            theme.systemReduceMotion = true   // e.g. the OS setting flips at runtime
            compare(theme.motionPage, 0, "motion tokens react to a live OS change")
        }

        // ── Text scale ───────────────────────────────────────────────────────
        function test_text_scale_multiplies_font_tokens() {
            theme.textScale = 1.5
            compare(theme.fontData, 60, "fontData scales (40 × 1.5)")
            compare(theme.fontDataLarge, 72, "fontDataLarge scales (48 × 1.5)")
            compare(theme.fontTitle, 26, "fontTitle scales (17 × 1.5 → 26)")
            compare(theme.fontLabel, 23, "fontLabel scales (15 × 1.5 → 23)")
            compare(theme.fontCaption, 20, "fontCaption scales (13 × 1.5 → 20)")
        }

        function test_text_scale_is_clamped() {
            theme.textScale = 99.0
            compare(theme.textScaleEff, 1.6, "absurdly large scale clamps to 1.6")
            compare(theme.fontData, 64, "…and the token follows the clamp (40 × 1.6)")
            theme.textScale = 0.0
            compare(theme.textScaleEff, 0.8, "zero/negative scale clamps to 0.8")
            compare(theme.fontData, 32, "…and the token follows the clamp (40 × 0.8)")
        }

        function test_text_scale_tokens_stay_whole_pixels() {
            theme.textScale = 1.13   // deliberately awkward multiplier
            compare(theme.fontLabel, Math.round(theme.fontLabel), "fontLabel is a whole pixel size")
            compare(theme.fontCaption, Math.round(theme.fontCaption), "fontCaption is a whole pixel size")
            verify(theme.fontCaption > 0, "fontCaption stays positive")
        }

        function test_text_scale_survives_theme_switch() {
            theme.textScale = 1.4
            theme.applyTheme("light")
            compare(theme.fontData, 56, "text scale is independent of the theme mode (40 × 1.4)")
        }
    }
}
