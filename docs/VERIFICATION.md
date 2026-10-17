# Verification

CAFÉ SHIFT is a Godot 4.7.1 game with offline shifts and optional two-device till/kitchen synchronization. This page records **tested evidence**, not a guarantee that every device or network will work.

## Release and deployment

- [Play the Web game](https://cafe-shift-rush-hour.vercel.app/)
- [Download the latest version](https://github.com/Hustlenix/cafe-shift-rush-hour/releases/latest)
- [Hosted export verification](live-export-proof.json) — recorded SHA-256 matches for six runtime files and a check of the WebAssembly MIME type.
- [Two-client synchronization evidence](sync-proof.json) — two independent Godot processes completed the till → kitchen → done flow through the deployed API.

The linked JSON files are **historical test records**. A new deploy requires a new verification run. Git commit identity and compiled-build byte identity are different checks.

## Tested features

| Area | Recorded result | Scope |
| --- | --- | --- |
| Game rules | 79 checks passed | Orders, scoring, Rush Hour, saves, records, legacy save handling |
| Native GUI | 53 pointer activations passed | Customer selection, order flow, kitchen, timer, results, options and keyboard shortcuts |
| Backend security | 30 checks passed | Roles, room isolation, validation, idempotency and transitions using SQLite test fixtures |
| Client synchronization | 37 checks passed | Two-client local server flow, recovery, retry and room revocation |
| Production integration | Passed in recorded runs | Two independent Godot processes communicating through the live HTTPS/Postgres backend |
| Web export | Passed in recorded runs | Chromium boot on desktop (1440 × 900) and phone-sized (390 × 844) viewports, with no reported console/page/network errors |

These counts are taken from the project's October 2026 verification runs; they have **not** been rerun solely because this document was shortened.

## Gameplay captures

| Screenshot | What it shows |
| --- | --- |
| [Rush Hour](screenshots/rush-hour.png) | Café floor and customer requests |
| [Order desk](screenshots/till.png) | Menu, request selection and receipt |
| [Preparing](screenshots/kitchen.png) | Kitchen ticket and pour meter |
| [Completed ticket](screenshots/kitchen-done.png) | Finished kitchen flow |
| [Shift results](screenshots/shift-report.png) | Rating, rewards and results |
| [Phone layout](screenshots/till-phone.png) | Narrow-screen arrangement |
| [Web till, synchronized](screenshots/web-sync-done-pos.jpg) | Browser POS receives completed ticket |
| [Web kitchen, synchronized](screenshots/web-sync-done-kitchen.jpg) | Browser kitchen completes ticket |

These are real application captures from prior tests, not rendered mockups.

## Reproduce locally

Install Godot 4.7.1 and use its Compatibility renderer. Source-only builds use original fallback assets; the licensed Modern Interiors pack is not included in this repository.

```sh
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/test_core.gd
godot --headless --path . --script res://tests/test_orders.gd
npm run test:backend
godot --headless --path . --script res://tests/test_sync.gd
godot --headless --path . --export-release Web builds/web/index.html
python tools/package_release.py --out builds/release
```

The **GUI pointer suite** in `tests/test_ui.gd` requires a real graphics viewport and must not be treated as a headless visual verification. The sync test requires the local backend dependencies; the live two-process check is provided through `tools/test_network.py` and requires a configured Godot executable.

## Known testing limits

A physical phone/touchscreen, controller, and real mobile-network loss/recovery were not validated in the recorded runs. Browser local saves depend on site-storage permissions. Room credentials are stored only in memory, so reloading the till can require a new room. Production was not modified by this repository-cleanup commit.

## Asset rights

[LimeZu Modern Interiors](https://limezu.itch.io/moderninteriors) is a licensed third-party asset pack. Raw licensed sprites are intentionally excluded from public source control. Only original public assets and code are tracked.
