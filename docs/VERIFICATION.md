# Verification and release identity

This page distinguishes native gameplay tests, API tests, hosted-file checks and browser gameplay. None proves the others automatically.

## Identify the public version

- [Public game](https://cafe-shift-rush-hour.vercel.app/)
- [Current source commit and runtime hashes](https://cafe-shift-rush-hour.vercel.app/release.json)
- [Compiled release downloads and verification attachments](https://github.com/Hustlenix/cafe-shift-rush-hour/releases/latest)

Maintainer releases stamp a clean committed checkout with `python tools/stamp_export.py`. `release.json` identifies the exact source commit and SHA-256 hashes of the six game runtime files. Compare it with the release tag before reporting a version mismatch. Later documentation changes do not imply a different compiled game.

`python tools/verify_live_export.py` makes anonymous requests and compares all six files with `builds/web`, checks WASM MIME and, when present, verifies the hosted source manifest. Its JSON report belongs to that particular URL and execution time. HTTP 200 and matching files establish public file availability and build identity, not a browser playthrough.

## Reproduced on 18 October 2026

A fresh public clone of gameplay commit `06786339c074754f90fd1fb563c24531f55a736b` was imported in Godot 4.7.1 without the paid assets. It passed:

| Suite | Result | Scope |
| --- | --- | --- |
| Core | 97 checks | Fresh launch paused, orders, quantities, totals, scoring, five-order win, saves and legacy migration |
| Customers | 2,094 checks | Seeded generation, personality fairness, recipe variation and restored RNG state |
| Preparation | 104 checks | All nine recipes, recoverable misses, saved checkpoints and exact tray requirements |
| Events | 204 checks | Event windows, warnings, non-overlap and reward gates |
| Progression | 32 checks | Quality, achievements and duplicate-reward protection |
| Order smoke | Passed | Menu/cart/ticket lifecycle and NPC request |
| Sync reliability | 42 checks | Real local API, lost acknowledgement, outage/recovery, idempotent retry and room revocation |

The backend separately passed 30 authorization, validation, idempotency and transition checks using a real SQLite fixture. Fixture security tests are not a production penetration test.

The graphical onboarding suite uses actual native input and a real-time five-order shift. During this release check, a timing-dependent automation failure and a freed-button test reference were detected. The helper now observes the running gauge and resolves live controls after layout. A console PASS with a script error is not accepted as a clean test.

After those test-helper repairs, onboarding passed 145 checks / 136 input events with no script errors, the UI suite passed 54 pointer activations, and physical preparation passed 60 checks. Onboarding counts vary with the randomly generated recipes; the five-order success assertion remains required.

## Native gameplay and screenshots

The graphical suites cover welcome/tutorial completion and skip, untimed practice, Rush Hour, settings, saved progress and kitchen preparation. The physical-input suite covers all nine recipes at 1440×900, 1920×1080, 390×844, 360×800 and 844×390, including mouse, synthetic touch and keyboard preparation. These are native desktop viewports, not physical mobile devices.

Current [welcome](screenshots/current-welcome.png), [phone preparation](screenshots/current-preparation-phone.png) and [results](screenshots/current-results.png) screenshots are captures from the running native game. They include the owner's licensed Modern Interiors artwork; the public source uses original fallback rendering when the pack is absent.

For exact commands, prerequisites and sequential UI test instructions, see the [README](../README.md). Keep port 8790 free for `test_sync.gd`; it manages its own server. Headless model tests do not establish correct graphical layout.

## Live synchronization

`tools/test_network.py` starts two independent Godot processes. The till creates a private temporary room and submits a ticket; the second process joins as Kitchen and advances it; the till receives DONE automatically. The test revokes its temporary room. Its JSON output records the endpoint, time, client process IDs and results without publishing credentials.

Release attachments contain the latest executed proof. The tracked [sync-proof.json](sync-proof.json) and [live-export-proof.json](live-export-proof.json) are older historical records, retained for provenance. They must not be presented as tests of a newer release.

## Explicit limits

- Browser automation is disabled in the current Codex Work environment. A current browser playthrough and console/network inspection could not be performed for this release check.
- A real touchscreen, physical phone, controller and mobile-network recovery remain unverified.
- Room credentials stay in memory; reloading can require re-pairing. Web saves depend on browser site-storage permissions.
- Source-only tests validate fallback play; they do not redistribute paid source artwork.
- Commit history, automated test execution and heartbeat counts do not establish eligible human development hours. Personal reflection and journal attribution require the owner's confirmation.

## Asset rights

Modern Interiors is licensed artwork by [LimeZu](https://limezu.itch.io/moderninteriors). Raw paid artwork is ignored by Git and excluded from deployment uploads. It is embedded only in compiled game artifacts. Code/original assets use MIT; the third-party art does not.
