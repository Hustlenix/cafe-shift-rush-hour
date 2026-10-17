# Verification evidence — 2026-10-14

Engine: Godot 4.7.1 stable, official build a13da4feb. Windows Compatibility renderer, AMD Radeon Graphics.

## Baseline

Import reported `The function signature doesn't match the parent. Parent signature is "_input(InputEvent) -> void"` in `scripts/main.gd:269`. The starter's helper was renamed `_form_input`. The original order test printed PASS but leaked its manually created store; it now frees that object.

## Offline implementation

`tests/test_core.gd`: **PASS: 67 core checks; 0 failures**. Added checks cover first-run Rush setup, the pour timing window, and its capped XP reward.

`tests/test_ui.gd`: **PASS: native GUI, 52 pointer activations; 0 failures**. Run with a real OpenGL viewport. Godot mouse down/up events activate the controls. Keyboard Enter activates the kitchen tab. The flow starts with a selected guest, rejects a partial or incorrect recipe, accepts the exact recipe, displays the timing meter, and awards a tested pour bonus. It also verifies that the next waiting request becomes active when the selected guest times out. Separate native Window dialogs use their semantic signals for confirmation tests; physical dialog clicks, a controller and a real touchscreen have not been tested.

The GUI pass found and repaired wrapping-induced layout expansion, missing customer-card attachment, and competing exclusive dialogs. Final test exit was clean. Actual viewport images: `docs/screenshots/till.png`, `kitchen.png` (live pour timing), `kitchen-done.png`, and `rush-hour.png`.

A clean archive of the tracked source, without `assets/licensed/`, imported and started successfully in Godot. The public-source fallback runs without missing paid textures. Licensed artwork is included only in the compiled owner's game and gameplay screenshots.

`backend/tests/security.mjs`: **PASS: 30 backend authorization, validation, idempotency and transition checks (real SQLite fixture)**. This invokes the shared API handler against real SQLite, including invalid enum values and retrying an order when the room is full.

## Live synchronization

The Vercel API at `https://cafe-shift-rush-hour.vercel.app/api/health` responds with `ready: true` and `storage: Neon Postgres`. The real production schema was applied and verified. Production uses a parameterized Postgres adapter; the SQLite fixture is a separate development path.

`python tools/test_network.py --endpoint https://cafe-shift-rush-hour.vercel.app`: **PASS in both independent Godot processes**. Actual process IDs, timing and outputs are in [sync-proof.json](sync-proof.json). The kitchen automatically received New (two lattes + one chai, Rs 470), moved it through Preparing and Done, and the POS automatically received Done. The server acknowledged revocation of the temporary test room afterward. Only the pairing credential was handed between processes; no ticket state or model was shared.

The Windows console wrapper stalled when its output was piped. The runner now writes each process's output to its own file and reads those files after exit. Credentials pass through a unique private temporary handoff/environment and never appear in commands, logs, evidence, URLs, source or the exported game.

Two Web runtime instances also passed the full visible flow: create till room, copy code, Paste on the kitchen, join, submit Ada's Rs 470 ticket #7, Start preparing, Mark done, and automatically receive Done at the till. Screenshots show both roles with the same completed ticket. The browser test found a paste issue and led to an explicit asynchronous Clipboard API button. No browser errors/warnings appeared in either client after the corrected flow.

Reloading the kitchen client and rejoining with its code recovered the same **Done ticket #7** from Postgres. The final layout was checked at 1360×860, 1280×720 and 960×620 desktop viewports; temporary viewport overrides were reset.

## Hosted Web game

The single-thread Compatibility Web export loads at [the public demo](https://cafe-shift-rush-hour.vercel.app/). A new save now opens directly into a live Rush shift with two guests, a 3:00 timer, and the first guest selected. The till shows a live recipe checklist and blocks mismatched tickets. Each kitchen ticket has a moving pour meter; the player's timing can add up to 20 XP, with Rush time as the tradeoff. A guest timeout advances the order panel to the next waiting guest. Free Play no longer shows the five-order Rush goal. Existing saves remain intact. The original build's missing glyphs were replaced with readable text; pairing dialogs have a contrasting title bar and clear controls.

A fresh-origin run against the production deployment at [that day's Vercel build](https://cafe-shift-rush-hour-ni3jygkno-hustlenixs-projects.vercel.app/) passed the visible loop: the new save opened at 0/5 with two guests and Amelia selected; the exact Rs 320 latte-and-croissant order printed as ticket #101; the kitchen moved it from New to Preparing and showed the timing meter; serving during a good pour awarded **39 XP**, recorded Rs 320, and advanced Rush to **1 / 5**. The user-facing production alias was also reloaded successfully and retained its existing **41 XP / 1 served** save in Free Play.

`tools/verify_live_export.py`: **PASS: all six hosted runtime files match the local export; WASM MIME is correct.** Actual sizes and hashes are in [live-export-proof.json](live-export-proof.json). The release archive contains compiled runtime files and instructions, with no raw paid asset pack.

## Café-floor fidelity re-verification — 2026-10-17

`tests/test_core.gd`: **PASS: 71 core checks; 0 failures**. `tests/test_orders.gd`: **PASS** (cart, totals, placement, kitchen statuses, scoring, NPC ticket). `tests/test_ui.gd`: **PASS: native GUI, 52 pointer activations; 0 failures** — the rush-hour capture now waits for every walker to settle, so `rush-hour.png` shows both guests parked front-facing at their slots with legible name tags, the selected guest gold-framed under the order bubble, and no leftover status icons.

The floor animates the full visit now: guests enter from the door with the run sheet, face their direction of travel, turn front-facing while waiting, and depart with the pixel heart. Name tags and the selected guest's bubble draw in screen space so text stays crisp at any zoom; the queue portraits use the front-facing frame. A captured "extra guest" was decoded as a guest mid-transition between the Free Play auto-refill and the Rush restart, not a state bug; the one real defect the visual investigation found — waiting dots drawn over a departing guest — was fixed with a dedicated `LEAVING` state. The 24-frame character sheets are single-row strips: 6 frames each for right, up, left, down (front), in that order.

The deployed build was re-verified after the pass: `tools/verify_live_export.py` — **PASS: all six hosted runtime files match the local export; WASM MIME is correct** (refreshed [live-export-proof.json](live-export-proof.json)) — and the Chromium boot check at 1440×900 and 390×844 reported zero console, page and network errors. The public release bundle was repackaged, re-uploaded and re-downloaded: the published zip hash equals the local package (`f822cd27…`).

## Fun & Feedback batch re-verification — 2026-10-17

`tests/test_core.gd`: **PASS: 79 core checks; 0 failures** (up from 71). The new checks cover shift tips (`tips_total`), best-streak tracking, the one-time best-run record (`record_best()` returns true once and cannot fire twice for the same result), the walkout floor flag (`left_out`), a best-record save round-trip (`210/5/5`), and legacy saves starting best records at zero. `tests/test_orders.gd`: **PASS** (unchanged). `tests/test_ui.gd`: **PASS: native GUI, 53 pointer activations; 0 failures** — new coverage: Esc clears a partial tray ("Tray cleared."), number keys 1/2 switch stations, the rush clock turns coral under ten seconds and returns to gold, the Music toggle controls `music_on`, and a fabricated finished shift opens the results card with the "NEW BEST" banner, "PERFECT SHIFT" rating, a visible "Tips Rs 30" line and all three drawn stars filled, with the record stored (`best.score == 210`, `best.streak == 5`).

Sound: three original WAVs are generated by `work/make_sounds.py`: `tick.wav` (0.06 s), `fanfare.wav` (1.45 s), and a loop-ready `ambient.wav` (20.00 s @ 22050 Hz — every voice and shimmer-LFO rate is an integer multiple of 0.05 Hz so the loop is seamless). Godot's importer reimported all three with no errors. The star ratings are drawn shapes (`scripts/star_icon.gd`), not glyphs, after a font probe confirmed the bundled font has no star characters.

Screenshots: `docs/screenshots/shift-report.png` is new (results card with drawn stars over the rush floor, captured with the embedded dialog overlay); `till.png`, `kitchen.png`, `kitchen-done.png`, `rush-hour.png` and `till-phone.png` were refreshed by the same run.

Live: the export was deployed and re-verified — `tools/verify_live_export.py` **PASS: all six hosted runtime files match the local export; WASM MIME is correct** (refreshed [live-export-proof.json](live-export-proof.json)) — and the Chromium boot check at 1440×900 and 390×844 reported zero console, page and network errors. The release bundle was repackaged to `cafe-shift-rush-hour-web.zip` (10,495,169 bytes, sha256 `bd26c945…`); publishing it to the GitHub release awaits the owner's version decision (refresh v1.1.0 versus a v1.2.0 cut).

## Honest boundaries

No PIXL journal or claimed development duration was created. AI assistance is documented. Existing Hackatime endpoint remains unchanged; automated edits were not converted into synthetic human hours. Both synchronization proofs used independent clients on one computer. A physical phone, touchscreen, controller and loss-of-connectivity recovery on an actual mobile network have not been tested. Rooms expire in seven days; tokens remain in memory, so refreshing the till requires a fresh room.
