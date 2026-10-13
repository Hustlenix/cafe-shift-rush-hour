# Coding-agent brief: Cafe Shift / Pixl Cafe Trial

You are the lead Godot 4 GDScript engineer and game-feel designer improving the existing Cafe Shift starter. You must leave a working, testable cafe ordering system, not just screens or a Figma-style mockup.

## Non-negotiable context

- Challenge: "Build the cafe's ordering system: a menu, a cart, and a kitchen screen where orders appear and get marked done. Real-time updates are a bonus."
- Pixl project to associate with this work: https://pixl.hackclub.com/projects/1646. This project URL may require the user to log in. Do not invent details about its existing code, status, hours or trial tier.
- Start by inspecting all files, any existing repository/remote and the current code state. If these files are inside an existing project, preserve working features and build on them. Don't destroy or reinitialize the repository.
- Work in **Godot 4.x and GDScript**, with native Godot Control UI (not a substituted React website).
- Treat the challenge's menu/cart/kitchen workflow as higher priority than extra minigames or decorative effects.
- Keep Hackatime working with its existing configured Hack Club endpoint. Don't manually edit the user's `.wakatime.cfg`, alter heartbeats, or fake hours.
- Pixl requires honest AI disclosure and substantial user involvement; never fabricate personal journal entries, screenshots or testing results.

## Phase 1: audit and stabilize the existing starter

1. Inspect `project.godot`, `scripts/order_store.gd`, `scripts/main.gd`, and `scenes/main.tscn`.
2. Check the installed Godot version and import the project. Run it, capturing all parser/errors/warnings. Fix issues, don't ignore failures.
3. Prove that all nine menu items render with prices and categories. Search and filtering must work.
4. Prove that adding/removing quantity, clearing the cart and computing totals work correctly. Empty orders must be blocked.
5. Place two separate orders; prove that both appear in kitchen with the right name/table/line items/totals.
6. Prove transitions NEW -> PREPARING -> DONE; prevent double completion and double XP/revenue accounting.
7. Reload the application and prove orders and cart persisted. Verify Reset Demo confirmation.
8. Write automated tests where practical. Do not claim green until they actually run.

## Phase 2: make it feel like a coherent playable game

Visual tone: original cozy 2D pixel-art indie game, warm cafe ambience, hand-crafted UI, clean readable typography, smooth transitions, calm microanimations. Don't use generic AI-gradient hero sections, overstuffed menus, low-contrast text, or someone else's artwork without a compatible license.

- Create original food/drink icons, cashier counter, coffee machine, 2D customer characters and ticket print animations. Keep menu/product names legible.
- Introduce a **Shift Mode** separate from the POS demo. NPC customers spawn at believable intervals and ask for a specific order. The player sees the request, adds the items to the cart, and sends it to the kitchen.
- Track customer patience and reward prompt, correct completion with XP. Keep an accessible no-timer **Free Play** mode for reviewers.
- Offer a visible goal (e.g. complete five orders), session score, restart, and a positive completion screen.
- Match 1360x860 desktop layout, ensure at least one smaller-screen responsive pass and touch-friendly buttons.
- Use signals rather than fragile NodePath assumptions. No UI control should appear functional unless it actually works.

## Phase 3: optional real-time bonus — only after offline core is solid

- Add real two-client syncing with a shared authoritative backend; local Godot signals alone are not cross-device realtime.
- Use a secure server/API (e.g. Node.js + WebSocket + SQLite, or Supabase with proper Row Level Security and public/anon key handling).
- Client A should create an order while client B (separate browser/device) receives it automatically without refreshing. B marks it done; A sees the final state.
- Give each order a unique server-side ID, validate menu IDs/quantities/prices server-side, check allowed status transitions, and prevent duplicate updates.
- Include reconnect, loading, and error states. Don't leak administrator secrets into a Godot Web build.
- Make the online mode optional so the offline game still runs without any service credentials.
- Mark the realtime feature complete ONLY after a real two-client test.

## Phase 4: ship-quality verification and evidence

- Run project in the Godot editor without parser/runtime errors.
- Complete the entire demo flow end to end. Verify persistence and reset.
- Export a Web build with a matching export template and verify on a real hosted URL. Use a configuration compatible with GitHub Pages; disable threads unless isolation headers are configured.
- Create a clear README with commands and screenshots of the actual running game.
- Make meaningful incremental Git commits. Before pushing, show `git diff --stat`, errors and tests.
- Update the Pixl project's journal with real, specific work performed by the user. Ask the user to supply firsthand work/journal notes instead of writing fictitious tracked hours.
- Document AI assistance transparently. Never claim anything was tested, shipped or submitted unless verified.

## Required output from you

1. What the repository already had, what you changed, and what still needs work.
2. Exact files created/modified and what each does.
3. Proof of the menu -> cart -> kitchen -> done flow, with actual test results.
4. If hosted: working demo URL, not just a GitHub repo link.
5. One concise next-action list for the human developer to complete in Godot.

Begin with the inspection and test pass now. Don't substitute prose for implementation.
