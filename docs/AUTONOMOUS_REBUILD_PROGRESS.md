# CAFÉ SHIFT — Autonomous Rebuild Progress

## Current phase

Phase 0 complete. Phase 1 vertical slice is complete and verified, the game-feel pass (kitchen tab badge, ticket transition flashes, pour-meter zone glow) has landed, the display foundation scales the whole UI to any window size without letterboxing (`canvas_items` + `expand`), and the café-floor/balance pass is in: served guests leave with fading pixel hearts, and every served order tightens the rush-hour arrival cadence (12s → 8s). The backend/KitchenSync reliability sweep is complete: a new 37-check end-to-end sync suite drives the real local server through failure and recovery, the two client defects it exposed are fixed, and the two-process live proof was refreshed through the production deployment. The web export is assembled locally and smoke-tested in a real browser, and the portrait/phone reflow has landed: narrow windows now get a dedicated stacked arrangement on a 430×900 logical base (window-resize aware) instead of the desk scaled down to their width, and the one overflow the browser verification exposed — a single-line status label forcing a 486px minimum width against the 430px viewport — was root-caused with local probes and fixed. The AI-template-feel sweep has since run as well: the public surface (copy, links, README claims) came back clean, and the one flagged item — the game had no app icon, so the window icon and web favicon were the default Godot robot — is fixed with a new original code-authored pixel-art icon wired into the project.

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
- `tests/test_sync.gd` (new): PASS, 37 end-to-end checks / 0 failures. It spawns `backend/local-server.mjs`, drives two KitchenSync clients through room creation, dual-role join, submit and advance, then kills the server mid-run to prove graceful degradation, retry-key reuse, recovery, role guards and room revocation.
- `python tools/test_network.py` against the local server: PASS (two independent Godot processes completed the full POS → kitchen → DONE loop).
- `python tools/test_network.py --endpoint https://cafe-shift-rush-hour.vercel.app`: PASS on 2026-10-16; refreshed `docs/sync-proof.json`.
- After the sync client fixes, the whole suite is green again: import, core (71/0), orders, native GUI (52/0), backend (30/0), sync (37/0).
- Web export: `--export-release "Web"` assembled `builds/web/` from the installed 4.7.1.stable web template (index.wasm 39.5 MB, index.pck 119 KB, all six runtime files present).
- Browser smoke test: served `builds/web/` over local HTTP and drove it with Playwright 1.63 (Chromium). At 1440×900 and 390×844 the engine boots (`Godot Engine v4.7.1.stable.official.a13da4feb` on the console), the canvas fills the viewport, and there are zero console, page and network errors. The desktop screenshot shows the full shift UI (floor, queue with patience bars, shelf, receipt) correctly laid out; the phone portrait screenshot shows the same desk arrangement scaled to the device width.
- Phone reflow (this checkpoint): `_update_layout()` re-bases the logical canvas at 430×900 whenever the window is narrower than 800px — stacked stage/order/kitchen pages, two-column shelf, short `ORDER`/`KITCHEN` tab labels, `Sync` button, phone-sized dialogs — and re-applies live on window resize. A real-GUI phone block in `tests/test_ui.gd` asserts the arrangement and captures `docs/screenshots/till-phone.png`.
- Reflow verification: core (71/0), orders, native GUI (52/0 including the phone checks), backend (30/0) and sync (37/0) all green; the web export was rebuilt and re-driven in Chromium at 1440×900 and 390×844 with zero console, page and network errors, and the phone screenshot now shows every element fully visible (header XP readout, `+ Welcome`, `Selected`, `Take order`, `Options`, `Sync`).
- Phone overflow root cause: `work/probe_layout.gd` measured the phone layout's minimum width at 486px — the single-line status label `_status` (454px of text) plus 32px margins — against the 430px viewport, which clipped the right edge exactly as the browser screenshot showed. After enabling word-wrap the margin minimum is 430px and no control exceeds the 430px viewport.
- Desktop pixel regression check vs HEAD (`work/diff_shots.py`, per-channel tolerance 6): till 0.068%, kitchen 0.032%, kitchen-done 0.200%, rush-hour 0.291% — all inside the 0.4% noise budget and all confined to the café-floor animation region (x463–716, y175–373), with no HUD, menu, receipt or footer differences.
- AI-template sweep (this checkpoint): cliché/placeholder greps across code, docs and web files found only one internal test label; the public README's claims and links check out (repository public, release `v1.1.0` assets in place, PIXL project page resolves), and the "icon/chime generation script" claim is accurate (`tools/import_assets.py`). The one real template tell was the missing app icon.
- App icon (this checkpoint): `tools/make_app_icon.py` draws `assets/original/icon.png` (32×32 pixel art at 8x nearest scale = 256×256) from the in-game palette — verified hard pixels (zero partial-alpha pixels, all 32×32 native blocks uniform). Wired via `config/icon`; after re-export the Web favicons are the café cup (`index.icon.png` 256×256, `index.apple-touch-icon.png` 180×180).
- Icon-change verification: import clean with no errors, core (71/0), web export rebuilt, and a full Chromium re-run at 1440×900 and 390×844 with zero console, page and network errors.

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
- KitchenSync was the only major script with no automated coverage. `tests/test_sync.gd` now covers it end-to-end; run it with `godot --headless --path . --script res://tests/test_sync.gd` (Godot executable is off PATH) with `node` available and port 8790 free — the test owns the server lifecycle.
- Retry semantics are proven, not assumed: a failed poll keeps the connection armed, doubles the backoff toward its 20s cap and reports automatic retries; a failed submit keeps its request nonce, and the retried ticket lands exactly once carrying the original nonce (the server echoes each ticket's nonce).
- Sweep-discovered fix 1: `advance()` used to poll immediately after a 409, overwriting "Ticket already changed. Refreshing its status." within milliseconds so nobody could read it; the notice now stays visible until the scheduled auto-refresh (≤2s) performs the refresh it promises.
- Sweep-discovered fix 2: `submit()` from a kitchen session reused the generic busy message; it now clearly says "Only the till can send tickets to the kitchen."
- Live service re-verified 2026-10-16: the health endpoint reports ready on Neon Postgres, and two independent Godot processes completed POS → kitchen → DONE over HTTPS, then revoked their temporary room.
- The web export boots straight into offline play: a first-time browser player enters an active Rush shift exactly like the desktop build, with no console errors and no server traffic.
- Phones used to receive the 1360-wide desk scaled into a ~390px canvas — intact but cramped — so the phone fix became a dedicated arrangement, not more scaling. The reflow now re-bases the logical canvas at 430×900 for narrow windows, and the layout invariant to protect is that phone content must not force more than 430px of minimum width.
- `_label()` defaults to `AUTOWRAP_OFF` and every long-text label opts into `AUTOWRAP_WORD_SMART` individually; `_status` was the single long line that never did, which is how its 454px minimum silently propagated to the whole phone layout. Any new long label must opt in, or one line of text clips the entire right edge on narrow screens.
- The hosted Vercel export now trails the local build (today's client fixes are not deployed); redeployment is deferred until explicitly requested.
- The hosted favicon and window icon were the default Godot robot because the project never set `config/icon`; the fix is code-authored, not sourced: `tools/make_app_icon.py` composes the cup-through-heart icon and `assets/original/icon.png` is committed like the other original assets. A 16px downscale check (`work/icon-preview-16.png`) confirms the cup silhouette survives favicon size.

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
- Ran the backend/KitchenSync reliability sweep: wrote `tests/test_sync.gd` (37 end-to-end checks including server loss, retry-key reuse and recovery), fixed the two client defects it exposed, validated `tools/test_network.py` against the local server, refreshed the live production proof (`docs/sync-proof.json`), and re-ran every suite green.
- Assembled the web export locally and smoke-tested it in Chromium at desktop and phone-portrait sizes, capturing both screenshots (`docs/screenshots/web-desktop.jpg`, `web-mobile.jpg`) and verifying zero console, page and network errors.
- Implemented the portrait/phone reflow: a live `_update_layout()` (connected to `size_changed`) that re-bases the canvas at 430×900 and switches the header, stage, order desk and kitchen board to a stacked phone arrangement, with a real-GUI regression block and a `till-phone.png` capture in `tests/test_ui.gd`.
- Root-caused and fixed the phone right-edge clipping found in browser verification with two throwaway probes (`work/probe_layout.gd`, `work/probe-web.mjs`): the unwrapped `_status` label held the phone layout at 486px minimum width against the 430px viewport; after enabling word-wrap every suite was re-run green, the web export was re-verified in Chromium at both sizes, and the desk screenshots were pixel-diffed against HEAD to confirm they only differ inside the café-floor animation region.
- Ran the AI-template-feel sweep and fixed the one item it flagged: authored `tools/make_app_icon.py`, generated and wired `assets/original/icon.png` (`config/icon`), re-exported the web build and re-verified it in Chromium.

## Changed files

- `docs/AUTONOMOUS_REBUILD_PROGRESS.md` (this checkpoint)
- `assets/original/icon.png`, `assets/original/icon.png.import` (new original app icon)
- `tools/make_app_icon.py` (new icon generator)
- `project.godot` (app icon)
- `README.md` (app icon listed in the original-assets note)
- `docs/screenshots/web-desktop.jpg`, `docs/screenshots/web-mobile.jpg` (browser smoke evidence)
- `docs/screenshots/till-phone.png` (new phone-arrangement capture)
- `docs/sync-proof.json` (refreshed live two-process proof)
- `project.godot` (display stretch aspect)
- `scripts/main.gd`
- `scripts/shift_rules.gd`
- `scripts/cafe_view.gd`
- `scripts/kitchen_sync.gd` (clearer role guard, visible stale-transition notice)
- `tests/test_core.gd`
- `tests/test_ui.gd`
- `tests/test_sync.gd` (new end-to-end sync suite)

## Known regressions

- The kitchen-rail desk collapse and the phone right-edge overflow were both found during verification, fixed, and re-verified (native GUI suite, phone checks, browser re-run, pixel diff). No known regressions remain at this checkpoint.

## Next actionable task

The brief's four phases and the polish backlog (game feel, balance, web export, portrait reflow, AI-template sweep) are complete; nothing further is queued. The remaining items are explicitly gated: deploy the refreshed export only on explicit request, physical touchscreen/controller QA on real hardware, and the human's own PIXL journal notes (never fabricated).

## External blockers

- No Godot editor/runtime blocker. Physical touchscreen/controller testing remains intentionally out of scope until local changes are verified, and production deployment of the refreshed export waits on explicit user direction.
