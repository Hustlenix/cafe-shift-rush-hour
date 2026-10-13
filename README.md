# Cafe Shift: Rush Hour

A tiny Godot 4 cafe-management prototype built for the Pixl cafe ordering system trial. Unlike a static mockup, the point-of-sale, cart, and kitchen board are connected to one working order state.

**Current status:** Godot source prototype. Please open it in Godot and run the smoke checks before you treat it as shipped. The environment used to prepare this starter did not have the Godot executable, so it has **not** been run or web-exported yet.

## What a tester can do

1. Open **Order Desk** to browse nine items across Coffee, Tea, Bites, and Desserts.
2. Search and filter the menu, add items to the cart, and use `+` / `-` for quantity changes.
3. Enter a customer and table (optional) and select **Send Order to Kitchen**.
4. Open **Kitchen Board** and see the incoming ticket and each line item.
5. Press **Start Preparing**, then **Mark Order Done**.
6. Watch the ticket move between Incoming, In Progress, and Completed. Each completed ticket awards 25 XP and its total is added to shift earnings.
7. Use **Generate Walk-in** to simulate random NPC customers for a rush-hour test.
8. Restart the game and see your orders, cart, and shift statistics restored from `user://cafe_shift_save.json`.
9. Use **Reset Demo** (requires confirmation) to start a fresh shift.

## Requirements

- Godot **4.3 or newer**, standard build, GDScript (no C#/.NET build needed)
- No API keys, backend, or plugins needed for offline/local use
- Tested target resolution: **1360 × 860** design canvas, desktop-first

## How to run

1. Download or clone this folder.
2. Launch Godot and choose **Import**, then select `project.godot`.
3. Open the project and press **F6** from `scenes/main.tscn` or **F5** for the whole project.
4. Use the Order Desk and Kitchen Board buttons at the top to switch screens.

### Run the logic checks (after installing Godot)

From the project folder run `godot --headless --path . --script res://tests/test_orders.gd`. The smoke test saves and restores any pre-existing local save. A passing result does **not** replace checking the UI visually.

### Quick test checklist

- [ ] Menu renders nine items and categories/search work
- [ ] A repeated Add increases quantity, not duplicate broken lines
- [ ] Minus removes an item when quantity reaches zero
- [ ] Empty cart cannot be ordered
- [ ] Order shows in Incoming with correct items and total
- [ ] New -> Preparing -> Done transitions each work exactly once
- [ ] XP and sales increase only when order becomes Done
- [ ] Walk-in order does not alter the normal cart
- [ ] Restart restores saved orders and cart
- [ ] Reset Demo clears all state only after confirmation
- [ ] Exported Web version launches and can complete an order

## Architecture

```
project.godot
scenes/
  main.tscn          Native Godot Control scene
scripts/
  main.gd            Order desk and kitchen UI, input signals
  order_store.gd     Autoload holding menu, cart, tickets, saves
tests/
  test_orders.gd     Optional automated logic smoke test
AI_BUILD_PROMPT.md  Suggested instructions for your coding AI
README.md
```

**Data flow:**

```
Menu -> cart[id] = quantity -> place_order()
                              -> orders array: NEW
Kitchen button -> advance_order(): NEW -> PREPARING -> DONE
OrderStore signal -> UI refreshes immediately within same running app
FileAccess -> saved JSON locally after each state change
```

Menu prices are sample Indian rupee amounts and there is no actual payment processing.

## Realtime: what is and isn't implemented

The order desk and kitchen update **instantly in one running application** via Godot signals. This is not two-device live sync: another browser/device has a separate local save and won't receive those orders. A real cafe's two-device kitchen display needs a shared backend, authentication/roles, and a realtime transport such as Supabase Realtime or a WebSocket server. See the AI prompt for the optional extension. Do not claim cross-device realtime in your submission until it is implemented and tested with two clients.

## Export a browser demo

1. Install Godot's **Web export template** that matches your Godot editor.
2. Project > Export > Add > **Web**.
3. Disable **Use Threads** for a simple static host where cross-origin isolation headers are not configured.
4. Export to a folder such as `builds/web/index.html`.
5. Host all generated files together on GitHub Pages or itch.io; don't open `index.html` directly as a `file://` URL.
6. Actually load the hosted version in a browser, place an order, finish it, and reload it before sharing the link.

Godot Web export docs: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html

## Pixl shipping checklist

Pixl's published software rules require a **public GitHub repository**, meaningful multiple commits, a working demo link distinct from the repo URL, a real screenshot thumbnail, setup instructions and an honest AI-use disclosure. Document actual tracked progress in your journal. Some trials have hour minimums, which the project dashboard displays. See: https://pixl.hackclub.com/docs/software-requirements

- Keep Hackatime active while *you* genuinely work in the editor/code. Do not fabricate tracked time.
- If you use OpenCode, maintain your existing Hackatime integration. Don't manually rewrite your `.wakatime.cfg` or switch to the WakaTime.com endpoint.
- Capture a **real screenshot** of the game running (not an AI mockup) for the project thumbnail.
- Describe what you actually wrote, debugged, designed and learned in devlogs.
- Explain how AI helped and which parts you implemented/tested yourself.

### Sample AI disclosure to adapt truthfully

> I used ChatGPT to help scaffold Godot scripts and outline the UI architecture. I reviewed and modified the code, tested the menu/cart/kitchen flow myself in Godot, and iterated on the layout and behavior. [Only retain statements that are true for your project.]

## Further ideas

- Make a drawn 2D customer queue, counter and expressive food sprites using your own original art.
- Add an actual countdown and customer patience level, with XP earned for timely service.
- Add item availability / sold-out states and order notes.
- Add authentic cross-device realtime using a server that validates prices/order transitions.
- Separate kitchen and POS into two independently running clients, then test sync under reconnect and offline conditions.
- Add keyboard shortcuts, accessibility checks and adaptive touch-friendly layout.

## Known limitations

- This is a desktop-first prototype; small phone displays may need a responsive redesign.
- It is a fictional cafe simulation, not a production POS system. No taxes, receipts, payments, customer data handling, or role-based access controls.
- The same-device signals are immediate but are **not** online multiplayer.
- This starter has not been executed in Godot by its authoring environment. Confirm it imports and fix any local issues before demo/submission.
