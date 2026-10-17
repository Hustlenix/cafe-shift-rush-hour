# Hands-on counter redesign — 2026-10-17

Target: the player should feel like a café craftsperson by preparing and handing over tangible orders while deciding which waiting guest and item to work on next.

The ten requested findings are the implementation scope. The attached 5,000 probes are source-based test hypotheses, not 5,000 reproduced defects or instructions to fabricate playtests.

Loop: select a guest in the café → choose one requested item → use its ingredients/equipment → place finished items on the tray → pick up the complete tray → tap that guest to deliver. Order states remain authoritative internally. No workflow columns, search, filters, customer form, or duplicate queue are exposed in this gameplay mode. The original trial ordering system and genuine online kitchen remain in a separate Order Desk mode.

Physical skills: hold/release extraction and cold pouring; alternating whisk strokes; ordered ingredient assembly; controlled heat and retrieval; a guided slice gesture; dragging food onto a plate. All nine products have authored step sequences. A spilled drink, early lift, missed cut, or misplaced plate can be retried without losing the order. Keyboard alternatives use Space, arrows, and Enter with contextual hints. Practice has no deadline; Rush must be explicitly started.

Ownership: main routes modes; CounterScreen coordinates the active guest and preparation; Preparation owns gesture rules and checkpoints; Recipes owns static definitions; PrepBench draws equipment and translates input; OrderStore owns tickets, finished counts, money, XP, and saves. Preparation checkpoints and tray counts persist inside their ticket. A partial gesture restarts only its unfinished step after reload. Legacy saves remain supported.

Responsive rule: active request, preparation surface, and tray fit one viewport without a page scroll. Portrait uses a compact guest stage and one large work surface. The delivery action is anchored. Desktop uses a larger café beside the work surface. Validate 1360×860, 1280×720, 390×844, 360×640, and short landscape.

Fun is a hypothesis until people play it. Automated correctness, browser proof, and native input tests do not substitute for blinded novice feedback; no such sessions are claimed here.

## The ten findings

| Finding | Implemented change |
| --- | --- |
| 1. ADD as the core action | Gameplay now handles ingredients, equipment, cuts, plates and a carried tray. |
| 2. Three workflow columns | Removed from gameplay. Internal ticket states are retained; the trial Order Desk remains a separate mode. |
| 3. One generic pour | Nine authored recipes combine six skill families: placement/assembly, extraction, whisking, controlled heat, slicing and plating. |
| 4. Search/filter/form overload | Gameplay shows only the selected guest's requested products and quantities. |
| 5. Duplicate floor and queue | Guest selection occurs on the café floor; there is no queue-record panel. |
| 6. Disconnected stations | Preparation and physical guest handoff share one scene, without station tabs. |
| 7. Portrait scrolling | Fixed request, bench and tray layouts; a separate short-landscape composition. Only the secondary pause menu can scroll. |
| 8. Large main controller | Main is a small router. Rules, input/equipment, request UI, menus, audio and persistence have distinct owners. |
| 9. Similar product cards | Large differentiated food/vessel silhouettes and product-specific equipment replace a catalog grid in gameplay. |
| 10. Rewards without depth | Skill completion gates the prepared counts; delivery is impossible before all items are made. Quality and time affect the reward. |

Live heat and active pouring require attention before switching; this avoids freezing a hot batch by choosing another item. Failed actions cost time in Rush and are recoverable. Pause freezes the shift and preparation.

Verification: 104 preparation checks and 79 existing core checks pass. The native counter suite serves six recipe combinations through all nine products using viewport events, with deterministic skill timing. It also exercises portrait/landscape bounds, wrong-recipient recovery, keyboard and touch input, settings, pause, new-shift confirmation, and the Order Desk round trip. Physical-device and novice preference testing remain unperformed.
