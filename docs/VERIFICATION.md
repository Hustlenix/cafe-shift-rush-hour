# Verification evidence — 2026-10-13

Engine: Godot 4.7.1 stable, official build a13da4feb. Windows Compatibility renderer, AMD Radeon Graphics.

## Baseline

Import reported `The function signature doesn't match the parent. Parent signature is "_input(InputEvent) -> void"` in `scripts/main.gd:269`. The starter's helper was renamed `_form_input`. The original order test printed PASS but leaked its manually created store; it now frees that object.

## Offline implementation

`tests/test_core.gd`: **PASS: 61 core checks; 0 failures**.

`tests/test_ui.gd`: **PASS: native GUI, 49 pointer activations; 0 failures**. Run with a real OpenGL viewport. Godot mouse down/up events activate the controls. Keyboard Enter activates the kitchen tab. Separate native Window dialogs use their semantic signals for confirmation tests; physical dialog clicks, a controller and a real touchscreen have not been tested.

The GUI pass found and repaired wrapping-induced layout expansion, missing customer-card attachment, and competing exclusive dialogs. Final test exit was clean. Actual viewport images: `docs/screenshots/till.png`, `kitchen.png`, `rush-hour.png`.

A clean archive of the tracked source, without `assets/licensed/`, imported and started successfully in Godot. The public-source fallback runs without missing paid textures. Licensed artwork is included only in the compiled owner's game and gameplay screenshots.

`backend/tests/security.mjs`: **PASS: 30 backend authorization, validation, idempotency and transition checks (real SQLite fixture)**. This invokes the shared API handler against real SQLite, including invalid enum values and retrying an order when the room is full.

## Live synchronization

The Vercel API at `https://cafe-shift-rush-hour.vercel.app/api/health` responds with `ready: true` and `storage: Neon Postgres`. The real production schema was applied and verified. Production uses a parameterized Postgres adapter; the SQLite fixture is a separate development path.

`python tools/test_network.py --endpoint https://cafe-shift-rush-hour.vercel.app`: **PASS in both independent Godot processes**. The actual process IDs and outputs are in [sync-proof.json](sync-proof.json). The kitchen automatically received New (two lattes + one chai, Rs 470), moved it through Preparing and Done, and the POS automatically received Done in **4,341 ms**. The room was revoked afterward. Only the pairing credential was handed between processes; no ticket state or model was shared.

The Windows console wrapper stalled when its output was piped. The runner now writes each process's output to its own file and reads those files after exit. Credentials pass through a unique private temporary handoff/environment and never appear in commands, logs, evidence, URLs, source or the exported game.

Two Web runtime instances also passed the full visible flow: create till room, copy code, Paste on the kitchen, join, submit Ada's Rs 470 ticket #7, Start preparing, Mark done, and automatically receive Done at the till. Screenshots show both roles with the same completed ticket. The browser test found a paste issue and led to an explicit asynchronous Clipboard API button. No browser errors/warnings appeared in either client after the corrected flow.

Reloading the kitchen client and rejoining with its code recovered the same **Done ticket #7** from Postgres. The final layout was checked at 1360×860, 1280×720 and 960×620 desktop viewports; temporary viewport overrides were reset.

## Hosted Web game

The single-thread Compatibility Web export loads at [the public demo](https://cafe-shift-rush-hour.vercel.app/). A real hosted order was submitted, prepared and completed. Refresh preserved the completed local ticket, **41 XP**, and **1 / 5 served**. The original build's missing glyphs were replaced with readable text; pairing dialogs have a contrasting title bar and clear controls.

`tools/verify_live_export.py`: **PASS: all six hosted runtime files match the local export; WASM MIME is correct.** Actual sizes/hashes are in [live-export-proof.json](live-export-proof.json), separate from the browser gameplay test. The release archive contains compiled runtime files and instructions, with no raw paid asset pack.

## Honest boundaries

No PIXL journal or claimed development duration was created. AI assistance is documented. Existing Hackatime endpoint remains unchanged; automated edits were not converted into synthetic human hours. Both synchronization proofs used independent clients on one computer. A physical phone, touchscreen, controller and loss-of-connectivity recovery on an actual mobile network have not been tested. Rooms expire in seven days; tokens remain in memory, so refreshing the till requires a fresh room.
