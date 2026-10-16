# CAFÉ SHIFT — Autonomous Rebuild Progress

## Current phase

Phase 0 complete. Phase 1 vertical slice is complete and verified, the game-feel pass (kitchen tab badge, ticket transition flashes, pour-meter zone glow) has landed, the display foundation scales the whole UI to any window size without letterboxing (`canvas_items` + `expand`), and the café-floor/balance pass is in: served guests leave with fading pixel hearts, and every served order tightens the rush-hour arrival cadence (12s → 8s). The next pass moves to backend reliability.

## Baseline evidence

- Branch: `codex/autonomous-rebuild`
- Baseline HEAD: `05daac7` (`Document verified Rush Hour deployment`)
- Working tree was clean before this checkpoint.
- Godot: 4.7.1 stable (`a13da4feb`), Compatibility renderer.
- Node: v24.16.0.
- `godot --headless --editor --path . --quit`: passed.
- `tests/test_orders.gd`: passed.
- `tests/test_core.gd`: passed, 67 checks / 0 failures.
- `tests/test_ui.gd` with the real OpenGL viewport: passed, 52 pointer activations / 0 failures.
- `tests/test_ui.gd` headless: not a valid visual baseline; viewport sizing caused layout-dependent failures. The project’s documented GUI test requires a real OpenGL viewport.
- `npm run test:backend`: passed, 30 checks / 0 failures.
- After the first visual slice, the native GUI test still passes: 52 pointer activations / 0 failures.
- Added a real café-floor pointer path and test coverage for selecting a waiting customer by clicking the drawn actor.
- Kitchen rail re-run after the presentation edits exposed a layout collapse; after the fix, the full suite is green: import, core (67/0), orders, native GUI (52/0), backend (30/0).
- After the game-feel pass, import, core (67/0), orders, and the native GUI suite (52/0, including the new kitchen-tab badge assertions) are green again.
- The display check (`work/stretch_check.gd`) shows the logical UI rect never drops below the 1360×860 design size at any tested window size (1360×860 → 1360×860; 1000×700 → 1360×952; 1600×900 → 1528×860), so the canvas scales uniformly and `expand` hands spare window space to the layout instead of black bars.
- After the display change, import, core (67/0), orders, and the native GUI suite (52/0) are green.
- After the café-floor/balance pass, import, orders, core (71/0, including four new arrival-ramp checks), and the native GUI suite (52/0, including the served-guest celebration check) are green; the `kitchen-done` screenshot visually shows the fading heart over the departing served guest.

## Findings

- `scripts/main.gd` is a 977-line runtime-built UI/controller and currently owns most presentation concerns.
- `scripts/order_store.gd` and `scripts/shift_rules.gd` are the authoritative offline state and rule owners; preserve them as the gameplay contract.
- `scripts/cafe_view.gd` already provides a small world view with fallback art, but customer actors are drawn rather than individually interactive.
- The new café-floor input path is deliberately presentation-only: `OrderStore.shift` remains authoritative and the view emits a request ID rather than mutating state.
- Existing UI tests assert stable control names and native input behavior; redesign work must preserve those contracts or update tests with equivalent observable behavior.
- Godot is installed outside PATH at `C:\Users\LalithReddy.b\Godot\Godot_v4.7.1-stable_win64_console.exe`.
- Hidden pages contribute no minimum size to the desk stack. The kitchen rail board had no minimum height, so switching to the kitchen tab let the desk collapse to about 150px, squeezing the columns to a ~16px visible slice and pushing the Advance button off-window (y=976). Fixed by giving the kitchen board a 320px floor and reserving the order page's height for the kitchen page at startup (`_stabilize_desk_pages`).
- Earlier notes about the UI clipping below a ~990px window width were stale: `window/stretch/mode="canvas_items"` already keeps the logical UI at 1360×860 and scales it down, so no window size clips content. Adding `window/stretch/aspect="expand"` lets spare window space extend the logical layout (bigger stage/menu) instead of producing black letterbox bars; portrait-phone reflow remains deferred to the export phase.
- The rush-hour ramp lives in `shift_rules.gd` (`arrival_interval()`, keyed to `served`), so the balance stays fully deterministic and testable with no RNG.
- The served-guest celebration is presentation-only: `main.gd` looks up the request id before `advance_order`, then asks `cafe_view.gd` to celebrate; the authoritative order transitions are untouched.

## Completed work

- Inspected repository, branch, recent history, project settings, scenes, core scripts, tests, backend entry points, and license notes.
- Created the isolated local branch `codex/autonomous-rebuild`.
- Ran the real baseline import, core, order, GUI, and backend checks.
- Reframed the active shift as a compact HUD, café-floor stage, queue rail, order station, and kitchen rail instead of a large header plus dashboard columns.
- Reduced product presentation to compact shelf slots while preserving every product ID, price, and existing test control name.
- Converted the cart actions into a compact counter receipt action row.
- Added café-floor mouse/touch customer hit testing, dialogue bubbles, and a native GUI regression check for actor selection.
- Root-caused and fixed the kitchen-rail desk collapse (kitchen board minimum height + kitchen page height stabilization), then re-verified every suite and refreshed all four screenshots.
- Added the kitchen game-feel pass: the KITCHEN RAIL tab shows a `· N new` badge while tickets wait in NEW, ticket cards flash briefly on the start and serve transitions, and the pour meter glows gold or green when the needle is inside a bonus zone.
- Established the display/responsive foundation: verified canvas stretch at three window sizes with `work/stretch_check.gd`, switched the stretch aspect to `expand` so the layout grows into spare window space (no letterbox bars), and re-verified every suite.
- Added the café-floor/balance pass: guests who are served now exit with a fading pixel heart above their dialogue bubble, and the rush hour builds — one fixed arrival interval (12s) tightens by 0.8s per served order with an 8s floor, keeping the shift deterministic.

## Changed files

- `docs/AUTONOMOUS_REBUILD_PROGRESS.md` (this checkpoint)
- `project.godot` (display stretch aspect)
- `scripts/main.gd`
- `scripts/shift_rules.gd`
- `scripts/cafe_view.gd`
- `tests/test_core.gd`
- `tests/test_ui.gd`

## Known regressions

- The kitchen-rail desk collapse found during re-verification is fixed and covered by the native GUI suite. No known regressions remain at this checkpoint.

## Next actionable task

Run the local backend/KitchenSync reliability sweep: exercise the online-sync failure paths and recovery, keep the 30-check backend suite green, and record any gaps found — then assemble the web export locally for a smoke test.

## External blockers

- No Godot editor/runtime blocker. Physical touchscreen/controller testing and production deployment remain intentionally out of scope until local changes are verified.
