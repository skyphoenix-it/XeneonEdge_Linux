# Beta plan — from alpha.2 to the public beta

_Status baseline: `v1.0.0-alpha.2` (signed, published, AUR live). Every MUST epic
(E1–E11) and blocker (B1–B7) from the v1.0 plan is done. E7 Phase B (keyring) is
parked by decision; payments deferred to beta._

The beta gate from the release train is **feature freeze**: after it, only fixes.
So the beta plan is exactly: the work that must be *inside* the freeze, the
quality bar that work must clear, and the decisions that pick the defaults.

## Workstreams (in flight from 2026-07-16)

### W1 — Sizing, part 2: per-widget optimization
Part 1 (alpha.2) built the machinery: size vocabulary, per-widget declarations,
absolute cells, rotation-stable packing. Part 2 is the payoff — each widget
genuinely *designed* for each size it declares, in both orientations, instead of
one layout stretched. Waves, cheapest first, so the pattern is proven before the
expensive widgets consume it:
- **Wave 1 (S):** analog, countdown, quote, rightnow, break, disk
- **Wave 2 (M):** cpu, gpu, ram, net, sensors, moon, clock, tasks, notes, habit,
  hydration, kpi, eod + the four E5 widgets
- **Wave 3 (L):** focus, media, calendar, weather, httpjson
Each wave: layout keyed off `sizeClass` (never `expanded`), real-device grabs at
every declared size × both orientations, tests per size, full suite green.

### W2 — Manager UX clarity (Design / Layout / Appearance)
Owner feedback: it is not clear **which setting changes which behavior**, and the
Design/Layout/Appearance split is muddled. Approach: audit first (walk the
Manager as a new user, write down every point of confusion with a screenshot),
then restructure — grouping by *what the user is trying to do*, plain-language
labels, live-preview affordances that show the effect before committing, and a
visible scope tag on every control (this page / this widget / everywhere).

### W3 — Widget smoothness
Owner feedback: some widgets feel "clunky". Diagnose before fixing: audit the
interaction paths (tap, resize, expand/collapse, page swipe, config open) for
missing eased transitions, abrupt property jumps, blocking work on the
interaction thread, and layout pop-in. Fix in the shared layer (WidgetChrome,
overlay open/close, edit mode, motion tokens) so every widget inherits it —
per-widget fixes only where the widget itself is the problem. Respect
reduce-motion throughout: smooth ≠ more animation.

### W4 — Test-suite growth (Hub + Manager)
- Runtime E2E: from 1 scenario (focus goal bonus) to a battery — policy
  enforcement, secrets refs, update-check-off-by-default, w/h→size migration on a
  real persisted config, org-managed startup.
- Manager: behavior tests for the reworked UX (after W2 lands, so tests assert
  the new intended behavior, not the confusing old one).
- Hardware E2E: per-size × orientation widget assertions once W1 waves land.
- Gate stays ≥95% everywhere; the behavior matrix stays at 100%.

### W5 — End-user validation ("rubber duck" loops)
After each major merge: a persona-driven walkthrough on the real device — a
developer, a first-run user, a Manager-only user — executing real tasks
("connect my CI status", "make the screen calmer", "resize the clock") and
recording every hesitation. Findings feed W2/W3 as concrete items, not vibes.
The bar: what Simon wanted, and what a stranger can use without a manual.

## Decisions that pick the beta's face (Simon)
- [ ] Calm as the default theme? (shipped default: dark)
- [ ] Default font: system vs Atkinson Hyperlegible
- [ ] Lawyer pass on distro theme naming (selling B2B)
- [ ] Payment provider (deferred from alpha — needed before Pro sells)

## Freeze criteria (entering beta)
1. W1 waves complete: every widget honest at every declared size, both
   orientations, on the real panel.
2. W2 restructure landed + validated by a W5 loop with no critical confusion.
3. W3: no known clunky interaction on the real device.
4. Full suite + all 3 CI workflows green; hardware E2E ≥ current 212 checks,
   extended for sizes.
5. The two defaults decided; legal check done.

## Beta exit → RC (unchanged from the release train)
No P0/P1; packaging smoke green on all targets (incl. AppImage zsync update
actually exercised once); egress + perf + a11y gates green; string/UX freeze;
48–72h real-hardware soak; launch copy ready (r/linux, r/unixporn, AUR beta).
