# CAFÉ SHIFT — Rush Hour

A playable **Godot 4** café game for [PIXL project 1646](https://pixl.hackclub.com/projects/1646). Ring up drinks and bites, print kitchen tickets, prepare orders, and keep the regulars happy.

![Actual Godot gameplay](docs/screenshots/rush-hour.png)

## Play

Open `project.godot` in Godot **4.7.1** and press **F5**. The core uses native Godot Controls and GDScript.

- **The till:** nine items, four categories, search, quantity controls, cart total, guest/table entry, and order placement.
- **The kitchen:** submitted tickets move **New → Preparing → Done**. Completion awards XP and sales exactly once.
- **Free Play:** no timer. Serve customer requests or create custom orders.
- **Rush Hour:** serve **five exact customer requests in three minutes**. Waiting customers have 65 seconds of patience. Early service earns bonus XP. Submitted tickets stay valid when patience runs out.
- **Progress:** cart, tickets, lifetime XP and the current shift save locally. Reset requires confirmation. A fresh shift preserves lifetime XP.
- **Options:** sound effects and reduced motion. Standard buttons support keyboard focus and activation.

Click **Take order**, read the requested items/quantities, add them from the menu, and send the order. Then open the kitchen, start preparing, and mark it done. A mismatched cart gives feedback without removing its contents.

## Verified status

On 2026-10-13 the project was imported and tested with Godot 4.7.1 on Windows:

- Original parser failure fixed: the starter's `_input()` form helper collided with Godot's built-in input callback.
- Original order smoke test passes without leaked objects.
- **61 core checks pass:** totals, quantities, exact recipes, duplicate rewards, five-order victory, timer failure, persistence, invalid save lines, duplicate restored IDs, and future-schema protection.
- **49 native GUI pointer activations pass**, plus keyboard kitchen-tab activation. These exercise categories, all nine Add buttons, every quantity button, cart clearing, order placement, preparation, completion, customer selection, shift controls, options, and reset confirmation.
- **26 backend security checks pass** against a real SQLite fixture: role enforcement, room isolation, menu/quantity validation, authoritative prices, idempotent order submission, and atomic status transitions.

Screenshots in `docs/screenshots/` are captured from the running Godot game by the UI test. They are not mockups.

**Still being completed:** live backend deployment, Godot client synchronization, two independent client proof, Web export and public demo verification. Backend fixture tests are not proof of live synchronization. No development hours or PIXL journal entries have been invented.

## Run tests

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_orders.gd
godot --headless --path . --script res://tests/test_core.gd
godot --path . --script res://tests/test_ui.gd
cd backend
node tests/security.mjs
```

The core tests use isolated temporary data. The GUI test disables saving and uses Godot viewport input; it also writes actual gameplay screenshots. Node 24 or newer supports the backend's built-in SQLite test adapter. A passing process exit alone is insufficient for import checks: inspect output for `SCRIPT ERROR` and `ERROR` too.

## Art and licenses

The owner's paid **Modern Interiors** pack by [LimeZu](https://limezu.itch.io/moderninteriors) supplies the café props and six animated regulars. The café layout is composed specifically for this game. Raw paid sprites and the composed paid-art room are ignored by Git because the asset license prohibits redistributing the asset pack. Gameplay screenshots may show the artwork as part of the game.

The public source runs with an original simple room/character fallback when the licensed art is absent. To reproduce the owner's art build using your own licensed pack:

```sh
python -m pip install pillow
python tools/import_assets.py --pack "/path/to/moderninteriors-win"
```

The script composes `assets/licensed/cafe.png` and copies the required animation strips locally. **Do not add `assets/licensed/` to Git.** Food icons and sample chimes in `assets/original/` are original code-authored assets, included with the source.

## Architecture

| File | Responsibility |
| --- | --- |
| `scripts/order_store.gd` | Menu, cart, tickets, XP, authoritative mutation methods, validated atomic local saves |
| `scripts/shift_rules.gd` | Requests, recipes, patience, arrivals, run goal, bonuses, results |
| `scripts/main.gd` | Stable native UI, menu/search/cart, kitchen, dialogs, sound |
| `scripts/cafe_view.gd` | Live café art, customer animation, speech bubbles, steam |
| `scripts/main_starter.gd` | Preserved repaired starter interface for reference |
| `backend/worker/index.js` | HTTPS room API with hashed 192-bit role credentials and D1 persistence |
| `backend/drizzle/0000_cafe.sql` | Versioned database schema |
| `tests/` | Godot smoke, core and GUI checks |

The offline game runs without keys or services. Browser local saves depend on storage permission; private browsing may discard them. Prices are fictional rupee amounts; no payment processing occurs.

## AI assistance and tracking

The supplied starter was AI-assisted. OpenAI Codex audited and repaired it, wrote and revised the game/UI/backend code, authored the original icon/chime generation script, ran the tests, and captured the screenshots. LimeZu authored the purchased art. This README does not claim the human independently wrote or tested AI-authored code.

The existing Hackatime configuration was inspected read-only and still points to Hack Club's endpoint. It was not rewritten. Automated work is not represented as human development hours; no synthetic heartbeats or journal entries were submitted.

## Build and release

Use the Godot Web export templates matching 4.7.1 and the Compatibility renderer. Disable threads for a static host. Publish all generated files together, then verify menu → cart → kitchen → done and persistence on the hosted build before treating a demo URL as shipped. See [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).
