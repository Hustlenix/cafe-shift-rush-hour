# Verification evidence — 2026-10-13

Engine: Godot 4.7.1 stable, official build a13da4feb. Windows Compatibility renderer, AMD Radeon Graphics.

## Baseline

Import reported `The function signature doesn't match the parent. Parent signature is "_input(InputEvent) -> void"` in `scripts/main.gd:269`. The starter's helper was renamed `_form_input`. The original order test printed PASS but leaked its manually created store; it now frees that object.

## Offline implementation

`tests/test_core.gd`: **PASS: 61 core checks; 0 failures**.

`tests/test_ui.gd`: **PASS: native GUI, 49 pointer activations; 0 failures**. Run with a real OpenGL viewport. Godot mouse down/up events activate the controls. Keyboard Enter activates the kitchen tab. Separate native Window dialogs use their semantic signals for confirmation tests; physical dialog clicks, a controller and a real touchscreen have not been tested.

The GUI pass found and repaired wrapping-induced layout expansion, missing customer-card attachment, and competing exclusive dialogs. Final test exit was clean. Actual viewport images: `docs/screenshots/till.png`, `kitchen.png`, `rush-hour.png`.

`backend/tests/security.mjs`: **PASS: 26 backend authorization, validation, idempotency and transition checks (real SQLite fixture)**. This invokes Worker request handling with a SQLite-backed D1 adapter. It does not prove a deployed D1 instance or two-device operation.

## Honest boundaries

No browser release or live synchronization has been verified yet. No PIXL journal or claimed development duration has been created. Existing Hackatime endpoint remains unchanged. Physical touch/controller QA and mobile layout QA remain outstanding.
