# CAFÉ SHIFT — v2 Direction (DRAFT — review before sharing)

*Internal strategy memo. Written 2026-10-17, after the Fun & Feedback batch shipped.
No numbers here are invented; every claim traces to something we built or verified.*

## Where the game stands

CAFÉ SHIFT is a one-screen café management game. The player takes orders at the till,
matches each guest's exact request, sends tickets to the kitchen, and times a pour
meter for bonus XP — all against a three-minute Rush Hour timer, or untimed in
Free Play. It runs in the browser (https://cafe-shift-rush-hour.vercel.app), as a
Windows build, and saves progress locally, with an optional two-device sync mode
(till + kitchen on separate screens).

What v1 proves: the core loop is **complete, tested and deployed** — 79 core checks,
53 native GUI activations, a backend security suite, a two-process sync proof against
a live database, and byte-identical live deployments verified after every change.
The latest batch added the feedback layer that makes results feel rewarding:
floating reward pop-ups, per-shift tips and best-streak tracking, a 0–3 star shift
report with a NEW BEST banner, confetti and a fanfare, a rushing clock in the final
ten seconds, looping café ambience (with a toggle), keyboard shortcuts, and a
persistent best-run record.

What v1 does **not** have: reasons to come back after the tenth shift. There is one
mode, one floor, one difficulty, no progression, and no story. That is the gap v2
fills.

## The one-sentence v2 goal

**Give the player a reason to return tomorrow** — a sense of ownership and progress
that survives after the novelty of the loop wears off.

## Candidate workstreams (ranked for impact per unit of work)

### 1. Café progression — earn, upgrade, personalize (the backbone)
The cheapest retention engine, because the economy already exists (XP, earnings,
tips). Add a light meta-layer *outside* the shift:
- Spend earnings on visible upgrades: better espresso machine (shorter pour window
  but bigger bonus), second counter slot, comfy chairs (guests wait longer), plants
  and wall colour choices (personalization).
- Each purchase changes how the floor looks and how the numbers behave — choice,
  not just accumulation.
- Keep it deterministic and testable: upgrades are modifiers to existing rule
  values, tracked in the save, covered by core checks.

### 2. A shift calendar / daily rhythm
- Named shifts with small modifiers (Morning: tea-heavy menu; Evening: bigger tips,
  faster patience drain) so no two sessions feel identical.
- A simple streak: play today, play tomorrow, keep a growth multiplier.

### 3. VIP regulars
- Recurring guests with names, orders and small stories (the guest characters
  already have deterministic names and recipes — R1 Amelia through R6 Ash).
- Serving a regular well unlocks their favourite item, a discount, or a floor
  decoration. Ties progression to the characters the batch just made more visible.

### 4. Staff
- Hire a barista to auto-serve simple recipes during rush; wages are a recurring
  cost that makes the economy a decision, not a counter.
- This is the biggest structural addition; schedule it after progression proves the
  loop holds.

### 5. Seasonal content (weather, festivals)
- Rainy-day slower arrivals, festival menu items (the menu and recipes are data,
  so new items are low-risk additions).
- Best used as a *marketing rhythm* — something visibly different to show each month.

### 6. Comfort and clarity (small but disproportionate)
- First-run tutorial overlay (three taps: take order, send, pour).
- One-line mission prompts ("Serve 3 teas before 12:00") to give short sessions a goal.
- Both are cheap, testable, and improve how the game reads to a brand-new player.

## Suggested v2.0 scope (one release, honest size)

In: progression economy + upgrades (workstream 1), the shift calendar with two
named shifts (2), VIP regulars for three guests (3), and the tutorial overlay (6).
Out (v2.1+): staff, weather system, leaderboards, localization, art overhaul.

Rationale: everything "in" reuses verified systems — save schema (already versioned
with forward-compatible loading), the deterministic menu/recipe data, and the
presentation layer that the batch just extended. Nothing in the list needs new
infrastructure, so each piece lands with tests and a screenshot, same as v1.

## What NOT to do

- Don't bolt on online accounts or cloud saves to a single-player game to chase
  "engagement" — local saves are a feature here (the web build plays fully offline).
- Don't add RNG-heavy systems that break determinism; the whole rule layer is
  testable today because it's deterministic, and that's worth more than variety
  theatre.
- Don't rebuild the art. The drawn, palette-locked pixel style is consistent and
  the character sheets work; spend effort on systems, not sprites.

## How each workstream gets verified (same standard as v1)

1. Model changes first: core/order checks (new rule values, save round-trips,
   legacy-save defaults).
2. UI changes: native GUI suite activation + refreshed capture.
3. Ship: export → deploy → byte-identity check → browser boot at desktop and phone
   size → release bundle repackage.

## Open questions for the owner

1. **Audience**: is v2 aimed at casual web players (broad, free-ish) or as a
   portfolio/hiring artifact for studio roles (show depth, ship polished, size
   matters less)? The roadmap above assumes the first; the second would weight
   "staff and economics" heavier than "calendar and seasons".
2. **Language**: the audience for the game's café setting may skew Indian
   (Rs pricing, menu). Should v2 add a Hindi/Telugu UI option? It's cheap to do
   late (short strings, no voice) but worth deciding before the UI grows.
3. **Release cadence**: refresh v1.1.0 assets per batch (what we've done so far),
   or move to numbered releases so players can follow progress? A v1.2.0 cut is
   ready now; numbered releases are the better long-term habit.
