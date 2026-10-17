# Fun & Feedback Batch — Design (2026-10-17)

## Context

The operator pasted a large AI-generated critique list (~600 numbered items, heavily
duplicated). Fact-check against the current build showed the loudest repeated claims are
already shipped or wrong: sound effects exist and are wired (`main.gd` `_play`), saves are
atomic and auto-save during a rush (`order_store.gd`), guests leave at 65s patience
(`shift_rules.gd`), streaks already raise the bonus (`shift_rules.gd` line 72), hover/press
styles, an Options dialog (Sound + Reduce motion), a results dialog, and empty states all
exist. Those claims are NOT being re-shipped.

## Goal

Fix the real gaps — the loop's feedback and closure — with nine additive changes.
No changes to game rules, scoring math, patience, arrivals, or economy values.

## The nine changes

1. **Floating reward pops** — `cafe_view.float_text()`; called on serve ("+XP", "PERFECT
   POUR", "×N streak") and on patience walkout ("left without ordering"). Toasts stay;
   these appear at the actor.
2. **Streak & tip visibility** — `shift_rules` gains `tips_total` and `best_streak`
   (additive fields, snapshot/restore defaults). Result dialog shows "Tips Rs · best streak".
3. **Shift finale** — stars by served/missed, "NEW BEST · N shift XP" banner, confetti in
   `cafe_view` (respects reduced motion), fanfare sound on success/new-best. Uses existing
   `order_store.best` record (change 9).
4. **Clock urgency** — RUSH clock turns coral at ≤30s, pulses at ≤10s (off under reduced
   motion), soft tick each second in the final 10. Offline only.
5. **Storm-out feedback** — `shift_rules.left_out` (transient) identifies the guest who
   ran out of patience; main floats "left without ordering" over them before they leave.
6. **Ambience** — generated `ambient.wav` loop (seamless 20s pad), separate Music toggle
   in Options next to the existing Sound toggle. Volume kept very low (-16 dB).
7. **Keyboard shortcuts** — Esc: clear tray → else clear selection → else nothing; 1/2:
   switch screens; Enter: send ticket (only when nothing focused consumes it). Guarded
   against open dialogs and LineEdit focus. Native Button Enter semantics untouched
   (test_ui depends on them).
8. **Floor life** — brighter steam wisps over the brewer; "The floor is quiet — welcome a
   guest." caption when no actors are on the floor.
9. **Best-run persistence** — `order_store.best {score, served, streak}` saved in the
   existing version-2 schema (additive; old saves load with defaults, old builds ignore
   the key). Reset all progress clears it; dialog copy updated to say so.

## Non-goals (v2 roadmap, separate doc)

Economy sinks/upgrades, staff, weather/seasonal, VIP regulars, leaderboards,
table management, art overhaul, localization, difficulty modes, tutorial flow.

## Risk & rollback

Additive only; save format stays version 2. New sounds are generated wavs in
`assets/original/` (tick, fanfare, ambient). Full suite + windowed UI test + captures +
live byte-identity + smoke run before ship. Rollback = revert the commit.

## Verification plan

- `test_core`: new checks for `tips_total`, `best_streak`, best-record round-trip, legacy
  save defaults. Existing 71 checks unchanged and green.
- `test_ui`: new checks — Esc clears tray, 1/2 switch screens, Music toggle exists,
  result dialog contains stars + NEW BEST. Captures refreshed + new `shift-report` capture
  (embedded subwindows) verified visually.
- Live: byte-identity proof, browser smoke at desktop/mobile, zero console errors.
