# Pixl — Front-End Design Reference

Reverse-engineered, pixel-accurate design specification of **https://play.pixl.hackclub.com/** ("Pixl: The Game"), captured on **2026-10-17** from the live site, its launcher page, and its public source repository (`github.com/hackclub/pixl`).

Everything below is either **(L) live-verified** (Playwright screenshots in `work/pixl-play/shots/`) or **(S) source-verified** (files downloaded to `work/pixl-play/src/`). Where the game's runtime sync changes a value away from its authored constant, the runtime value is shown in parentheses.

---

## 1. What the site actually is

play.pixl.hackclub.com is **not a marketing page**. It is a single-page **Godot 4.6 web export** wrapped in a minimal vanilla-HTML shell:

- The shell (`index.html`, ~9.5 KB) owns: the cream boot splash, a native `<progress>` load bar, a failure notice box, and a touch-only fullscreen button. It then boots `index.wasm` (37,686,550 B) + `index.pck` (20,666,452 B).
- The game itself renders into a single `<canvas>` at exactly **1600×900** (logical and CSS pixel size are both 1600×900 — adaptive, canvasResizePolicy 2). **(L)**
- The marketing/landing site, dashboard, shop, and projects pages are **separate apps on other subdomains**. A 2026-10-11 "hardened relaunch" deleted the old in-repo HTML/JS front-end (`apps/game/web`, ~16k lines) and now the game opens plain `https://pixl.hackclub.com/...` links in a new tab. The game and dashboard deliberately share **nothing** — no tokens, no localStorage, no postMessage.

| Surface | Host | Stack |
|---|---|---|
| Game | `play.pixl.hackclub.com` | Godot 4.6 web export + HTML shell |
| Dashboard (projects, shop, profile) | `pixl.hackclub.com` | Next.js (`apps/pixl-dashboard`) |
| Internal ops | `dash.pixl.hackclub.com` | Next.js (`apps/internal-dashboard`) |
| Game server | `server.pixl.hackclub.com` | Node (`apps/server`) |
| Music | `apps/pixorpheus` | — |

The shell sits behind Cloudflare. Its only in-page behavior beyond the loader is the fullscreen toggle and iOS pinch-zoom suppression.

---

## 2. The launcher shell (index.html) — full spec **(S)**

### 2.1 Document

- `<title>Pixl: The Game</title>`; favicon `index.icon.png`; apple-touch-icon `index.apple-touch-icon.png`.
- Meta description / OG: *"A retro 2D world where you level up by building real things"*.
- Viewport: `width=device-width, user-scalable=no, initial-scale=1.0`.
- `html, body { height: 100%; height: 100dvh; overscroll-behavior: none; }`
- `body { color: #fff; background: #000; overflow: hidden; touch-action: none; }`
- `#canvas { display: block; }` — no focus outline.

### 2.2 Boot splash overlay

- `#status` — full-viewport (absolute inset 0), **background `#f5eed2`** (the signature cream — same as the game's native boot splash bg and the web "PAPER" `panel-deep`), flex column centered.
- Splash image `index.png`, `image-rendering: pixelated` (class `use-filter--false`), never scaled up beyond viewport (`max-width/height: 100%`, `object-fit: contain` when fullsize).
- The rendered splash **(L)**: the PIXL wordmark — gold pixel letters with black outline, khaki stepped drop-shadow, and sparkle plus-signs — centered on cream.

### 2.3 Progress bar

- `#status-progress` is a **native `<progress>` element** — no custom styling. Position: `absolute; left: 0; right: 0; bottom: 10%; width: 50%; margin: 0 auto;` → renders in Chromium's default blue. **(L)** confirmed.
- Driven by `engine.startGame({ onProgress })`: `value`/`max` set from bytes loaded; indeterminate state (attributes removed) before sizes are known. On success the whole overlay is **removed from the DOM** (`remove()`).

### 2.4 Failure notice

- `#status-notice` — hidden by default. When shown: background **`#5b3943`**, border **`1px solid #9b3943`**, radius **0.5rem**, text **`#e0e0e0`**, font stack `'Noto Sans', 'Droid Sans', Arial, sans-serif`, `line-height 1.3`, `margin: 0 2rem`, `padding: 1rem`, centered, `z-index: 1`. Lines broken with `<br>`; engine errors surfaced verbatim.

### 2.5 Fullscreen button `#pixl-fs-btn` **(L + S)**

```css
position: fixed; top: 10px; right: 10px; z-index: 99999;
width: 40px; height: 40px; border-radius: 8px;
border: 1px solid rgba(255,255,255,.3);
background: rgba(0,0,0,.45); color: #fff;
font-size: 18px; line-height: 1; cursor: pointer;
```

- Only ever injected on touch-capable devices (`'ontouchstart' in window || navigator.maxTouchPoints > 0`).
- Injected via `document.write` **during initial HTML parse** — a deliberate workaround: appending it at runtime raced Godot's boot DOM mutation observers and tripped the engine's scene-tree reentrancy warning.
- Text toggles `⛶` (enter) ↔ `✕` (exit) on `fullscreenchange`. `aria-label="Toggle fullscreen"`.
- **Auto-fullscreen**: on the first `touchstart` / `touchend` / `click`, the page requests fullscreen on `<html>` and then attempts `screen.orientation.lock('landscape')` (inside the fullscreen promise).
- Live-verified geometry on a 390×844 touch viewport: rect `[340, 10, 40, 40]`, visible, computed styles exactly as above. **(L)**

### 2.6 iOS pinch blocking

`touch-action: none` and `user-scalable=no` are unreliable on iOS Safari, so the shell additionally blocks:

```js
document.addEventListener('touchmove', e => { if (e.touches.length > 1) e.preventDefault(); }, { passive: false });
document.addEventListener('gesturestart', e => e.preventDefault(), { passive: false });
document.addEventListener('gesturechange', e => e.preventDefault(), { passive: false });
```

(Rationale in source: zooming past 1:1 blurs/pixelates the canvas, destroying the pixel-art look.)

### 2.7 GODOT_CONFIG

`canvasResizePolicy: 2`, `ensureCrossOriginIsolationHeaders: true`, `experimentalVK: true`, `focusCanvas: true`, `godotPoolSize: 4`, `emscriptenPoolSize: 8`, threads **disabled** (`GODOT_THREADS_ENABLED = false`).

---

## 3. Brand marks

### 3.1 PIXL wordmark **(L + S)**

Chunky pixel-letter logotype, used everywhere (web splash, native boot splash, login, main menu). Left to right: **P I X L**.

Anatomy (per pixel-art assets):
- Letter body: **`#FFC93A`** (brand gold), with **`#C77800`** (dark gold) as the face-shading on the right/receding edges of each letter (the P and L especially), giving a 2.5-D bevel.
- Outline: **`#111111`**, 1-block thick, crisp (`crispEdges`, no anti-aliasing anywhere).
- Stepped drop-shadow behind/below letters: **`#C4B894`** (warm khaki), offset right+down in 1-block steps.
- Highlight facet on some letter faces: **`#FFEA78`**.
- Sparkles: pixel plus-signs — gold `#FFC93A` top-left of the P and bottom-right of the L, plus a **white** plus-sign top-right (heavy version). Secondary echoes of the sparks in paler tones.
- On the cream splash the wordmark sits on **`#F5EED2`**; in-game (login/menu) the transparent version sits on near-black.

Asset: `assets/ui/pixl_wordmark.png` — **720×224**, 6 palette colors: `#111111`, `#FFC93A`, `#C77800`, `#FFFFFF`, `#FFEA78`, (transparent). Native boot splash: `assets/ui/boot_splash.png` — **600×390**, same palette on cream `#F5EED2` bg.

### 3.2 App icon (`icon.svg` — the "P" tile) **(S)**

128×128 SVG, `shape-rendering: crispEdges`, drawn on an 8px block grid (16×16 pixels):

- Background: **`#F5EED2`** (cream).
- Letterform: a chunky pixel **"P"** (matching the wordmark's P) — body `#FFC93A`, face shading `#C77800`, highlight `#FFEA78`, outline `#111111`, stepped shadow `#C4B894` trailing bottom-right.
- This is the browser favicon/desktop icon identity: cream tile + gold P + black outline + khaki long-shadow.

### 3.3 Currency mark

`pixel_currency_gold.png` — **340×340** four-point sparkle/star (a diamond with concave steps), palette `#FFC93A` body, `#FFE896` highlights, `#C99414` shade, white square **hole in the dead center**, black outline off. Reads as a collectible "coin" without a circle. The red variant (`pixel_currency_red.png`, 340×340) uses `#EC3750` / `#F5788C` / `#961C2E` — Hack Club red family.

---

## 4. Color system

Three token sets live in one source of truth: `packages/theme/palette.json`, synced by `bun run theme:sync` (`packages/theme/sync.ts`) into (a) the dashboard's CSS custom properties (marker blocks `<pixl-theme:...>` in `app/globals.css`) and (b) `apps/game/theme.json`, which the Godot game reads at runtime.

### 4.1 The three identities

- **PIXL PAPER** (`web.light`) — the neo-brutalist cream look: warm cream surfaces, black rules, hard offset shadows, Hack Club red + orange. Deliberately warm everywhere — *"Separation comes from the black rules and the hard shadows, never from lightening a surface toward white."* **(S, quoted from the palette notes)**
- **LEDGER** (`web.dark`) — charcoal surfaces with an **ember coral** accent; not a 1:1 inversion of light.
- **godot.dark** — the game's charcoal + LEDGER gold. The palette file explicitly notes godot.* is **not** part of the PAPER port; the game runs the older gold-on-charcoal look. The two identities intentionally no longer share values.

### 4.2 Exact tokens

**`web.light` — PIXL PAPER:**

| Token | Value |
|---|---|
| ink | `#16161e` |
| dim | `#4a4a52` |
| faint | `#6f6f78` |
| muted | `#9a9aa2` |
| panel | `#faf4de` |
| panel-2 | `#ece0bd` |
| panel-deep | `#f5eed2`  ← shell splash cream |
| gold | `#ff8c37` |
| gold-soft | `#ffa45c` |
| accent | `#ec3750` |
| teal | `#52aeb9` |
| teal-hover | `#6bc3cd` |
| good | `#3faa5f` |
| bad | `#ec3750` |
| stroke | `#16161e` |
| btn-ink | `#f5eed2` |
| effects.drop | `4px 4px 0 #16161e` |
| effects.dropLg | `8px 8px 0 #16161e` |
| effects.dither | `none` |

**`web.dark` — LEDGER:**

| Token | Value |
|---|---|
| ink | `#ece8e2` |
| dim | `#b3ada2` |
| faint | `#847e72` |
| muted | `#5c574c` |
| panel | `#211f1e` |
| panel-2 | `#2a2724` |
| panel-deep | `#171615` |
| gold | `#ff6b4a` |
| gold-soft | `#ff8a6b` |
| accent | `#ff4763` |
| teal | `#5fc2cd` |
| teal-hover | `#7ad4de` |
| good | `#4ade80` |
| bad | `#ff4763` |
| stroke | `#4a453d` |
| btn-ink | `#171615` |
| effects.drop / dropLg | `4px 4px 0 #000000` / `8px 8px 0 #000000` |

**`godot.dark` — the game's runtime palette** (`apps/game/theme.json`, generated):

| Token | Value |
|---|---|
| gold | `#d99a1f` |
| gold-soft | `#e8ac35` |
| ink | `#ece8e2` |
| panel | `#211f1e` |
| panel-deep | `#171615` |
| btn-ink | `#241204` |
| good | `#4f9f62` |
| bad | `#d1584f` |

### 4.3 The three-golds rule (pixel-parity critical)

The game UI contains **three distinct golds** that must not be conflated:

1. **Art/brand gold `#FFC93A`** (with `#C77800` shade, `#FFEA78` highlight) — every raster asset: wordmark, icon, currency, arrows, boot splash. Never used in theme styleboxes.
2. **Static UI gold `#FFD166`** — the authored value in `main_theme.tres` for buttons, plates, focus rings, sliders. This is what the theme looks like *before* runtime sync.
3. **Runtime-synced gold `#D99A1F`** — what `godot.dark` repaints the controls to at boot, when the theme file is present.

Additional golds outside the game: web PAPER orange `#FF8C37`, web LEDGER ember `#FF6B4A`. Day-phase Day tint in HUD copy is `#FFD166` (authored), SceneTree tween colors for Dawn/Dusk `#FFA659`, Night `#8C9EF2`.

### 4.4 Theme pipeline & runtime apply **(S)**

- `packages/theme/sync.ts` writes `apps/game/theme.json` (with `"_generated"` warning header — do not hand-edit) and rewrites the `<pixl-theme:...>` marker blocks in the dashboard CSS.
- `apps/game/scripts/pixl_theme.gd` — `PixlTheme` autoload: reads `res://theme.json`, exposes `color(token)`. Unknown token → **magenta `Color(1,0,1)`** (loud failure, never silent). `boot()` reads `localStorage['pixl_theme']` (dashboard-set preference) and calls `apply()`, which repaints a subset of `main_theme.tres` at runtime.
- **Exact-match constraint**: `apply()` only swaps styleboxes/colors whose authored value exactly equals the expected static token. Near-black outline borders (`#17100A`) and art golds are intentionally left alone — the sync must never "fix" the brand art. Default fallback: dark.

---

## 5. Game UI theme — `main_theme.tres` **(S)**

Godot 4 Theme resource. Global properties: default font **PixelifySans**, 15 px; `corner_detail = 1` and `anti_aliasing = false` on every StyleBoxFlat (cut pixel corners, hard edges). Runtime-synced values in parentheses.

### 5.1 Buttons

**Button (primary, gold)**
- normal: bg **`#FFD166`** (`#D99A1F`), border **`#17100A`** widths L/T/R **3** / B **7** px (bottom-heavy), content margins 24 / 10 / 24 / 14.
- hover: bg **`#FFDF8A`** (`#E8AC35`); shadow alpha 0.15 → 0.45.
- pressed: content margins **flip vertically** (24/14/24/10) — the label moves down 4 px, the bottom border "compresses". This is the entire press animation: no scale, no tween.
- corner radius: via `corner_detail=1` (1 px cut) — butt-jointed pixel corners.
- shadow: tinted `#F4E3C2` (cream), offset/size 2 — a soft warm glow, not a black drop.
- disabled: everything at **50 % alpha**.
- focus: `draw_center = false`, **2 px `#FFD166`** border, **expand 4 px** (an outer gold ring).
- text: 17 px, **`#3A2410`** (`#241204` btn-ink), i.e. dark chocolate on gold.

**GreyButton (secondary)**: normal `#6E5A41`, hover `#7D6749`, text cream `#F4E3C2`.
**SmallButton**: margins 14 / 6 / 14 / 8, bottom border 5.
**StepButton**: grey variant, same family as GreyButton.

### 5.2 Panels & plates

- **Panel**: bg **`#2B1D12`** (`#211F1E`), border `#17100A` 3 px, corner_detail 1, shadow **black @ 0.5 alpha, size 4, offset (8,8)** — the hard offset shadow of the whole brand.
- **RowPanel**: bg `#3A2817`, margins 14 / 10 (list rows).
- **TitlePlate**: bg gold `#FFD166`, border `#17100A`, bottom border **8 px**, margins L/R 30, top 7, bottom 5 — the notched title tab that overlaps panel tops (see §7.3).
- **HudPanel**: `StyleBoxTexture` — 9-patch of `hud_panel.png`, `texture_margin 5`, `content_margin 8`.

### 5.3 Inputs

- **LineEdit / TextEdit**: bg **`#1C1209`** (`#171615`), border `#5A4632`, focus border gold; margins 12 / 9 / 12 / 7; text cream `#F4E3C2`; placeholder **`#9A835F`**; caret gold `#FFD166` (width 3 in TextEdit); selection gold @ 0.65; font 15.
- **CheckButton**: hover bg `#462F1C`, hover text `#FFE7A3`.
- **HSlider**: track `#1C1209` with `#17100A` 2 px border; fill `#FFD166`.
- **VScrollBar**: grabber gold `#FFD166`, 2 px `#17100A` border; track `#1C1209`.

### 5.4 Type variations

| Variation | Size | Color | Notes |
|---|---|---|---|
| Label (default) | 15 | `#F4E3C2` | PixelifySans |
| TitleText | **56** bold | `#FFD166` | big screen titles |
| SubText | 19 | `#FFD166` | |
| InfoText | 13 | `#C9B18C` | hints, help lines |
| FooterText | 12 | `#888899` | footers (e.g. menu footer) |
| StatusText | 14 | `#7BDC8B` | success/status green |
| TitlePlateText | 26 bold (FontVariation wght 700) | `#2B1D12` | on gold plate |

**Fonts**: `assets/fonts/PixelifySans.ttf` (default; Google-Fonts family) and `assets/fonts/Monocraft.ttf` — used **only** for the main menu and pause menu (preloaded as `OLD_MENU_FONT`, the theme is duplicated and font-swapped at runtime). The onboarding guide deliberately uses a **system sans** stack instead (see §7.3) for readability of long prose.

**Container default**: `VBoxContainer` separation 8.

### 5.5 Touch scaling **(S)** — no transform scaling, ever

Two layers, in `settings.gd`:

1. `font_scale` — user preference, default **1.0**, **1.3 on touch devices**, clamp 1.0–1.6. `fs(base)` = `round(base × font_scale)`.
2. `menu_scale_factor()` — touch-only: the 1600×900 canvas is shrunk by `min(real/1600, real/900)` on phones, which makes the big central menus tiny. The factor **undoes the shrink** and stacks font_scale on top: `clampf(1/shrink × font_scale, 1.0, 2.2)`.
3. `touch_menu_theme(theme)` duplicates the theme and rescales **every** font size, constant, and stylebox content margin by the factor.

Why not `Control.scale`: a transform stretches already-rasterized glyph bitmaps — a pixel font turns blurry and "reads as a completely different (wrong) font". Re-rasterizing at final size keeps it crisp. Other settings: `music_volume` default **0.2**, `zoom_level` 0.6–1.4 (default 1.0), `day_night_enabled`, `theme_name = "dark"` (the only theme).

---

## 6. Screens & flows

### 6.1 Boot sequence **(L + S)**

1. **HTML splash** — cream `#f5eed2` full-bleed with the PIXL wordmark (`index.png`, pixelated) + native blue `<progress>` bar at bottom 10 %, half the screen width, centered. **(L)**
2. Overlay removed from the DOM when the engine boots; a brief **black flash** until the game's first frame.
3. **Engine boot splash** — Godot's own splash: bg `#F5EED2`, image `assets/ui/boot_splash.png` (600×390), nearest-neighbor filter. **(L)** (identical visual language to step 1).
4. Game starts at `main_menu.tscn` (autoloads initialize; PixlTheme boots; audio starts).

### 6.2 Login screen — `login.tscn` **(L + S)**

- Full-screen backdrop: **`#140F0A`** (near-black warm brown).
- Centered `VBoxContainer`, **320 px** wide: wordmark **300×93** (`pixl_wordmark.png`, nearest), status line (InfoText style, e.g. *"Not logged in"*), and a full-width **gold Button** "**Login with Hack Club**".
- Live-verified **(L)**: black backdrop; wordmark ~300 px; small dim status text; gold button (bg matches `#FFD166`, dark label, hard dark offset shadow, ~42 px tall, ~310 px wide) with focused gold ring.
- Flow: button → `NetworkManager.start_login()` opens the browser auth page; on `connected`, `Loader.change_scene("res://scenes/main_menu.tscn")`.
- Layout density: generous vertical spacing, everything centered; no panels, no borders — the wordmark is the anchor.

### 6.3 Main menu — `main_menu.tscn` **(S)**

- Backdrop **`#0E0904`** (darkest warm black; same as the in-game loading screen).
- Centered `VBoxContainer`, **400 px** wide.
- Wordmark **320×100**; subtitle *"a tiny multiplayer world"* (13 px, FooterText `#888899`); status label (`Signed in as …`).
- Button stack (top→bottom): **Play / Enter Village** (primary gold), **Lobbies**, **Friends**, **Inbox**, **Character** (customise), **Settings**, **Logout** (GreyButton).
- Footer, 12 px FooterText: *"ESC pauses the game once you're in"*.
- Font: **Monocraft** (menu only), re-rasterized for touch via `touch_menu_theme`.

### 6.4 First run — name modal **(S, from ONBOARDING_REDESIGN.md)**

New accounts get a **"PICK A NAME"** modal: prompt *"Welcome to Pixl! What should other villagers call you?"*, LineEdit (max 24 chars, prefilled with current name kept via "Keep current"), posts to the profile API. Old accounts see nothing.

### 6.5 Intro cinematic

Four full-bleed paintings (`assets/cinematic/`: `origin`, `overload`, `last_spacecraft`, `arrival`) tell the 5-beat story — Origin, the Core, **the Great Static**, the ruins renamed Pixl, your arrival. Shown as `intro_cinematic.tscn`. Tap-to-advance (same input model as dialogue).

### 6.6 The onboarding guide — `guide_hud.gd` **(S)**

A 9-page illustrated manual that **auto-opens only for brand-new players**, then hands off to the web dashboard.

- **Layer** 105, always-process; only opens once per device (`user://guide_seen.dat`) AND while the shared `onboarding` counter reads step **0** (0 = new, 1 = game leg done / dashboard tour pending, 2 = fully onboarded — server-synced, forwards-only).
- **Backdrop**: `#0A0602` @ **0.78 alpha** (warm near-black dim); mouse-blocking.
- **The notched panel idiom**: a centered vertical stack with `separation = -22` — the **TitlePlate** (z-index 1) overlaps the top edge of the **Panel** by 22 px, reading as a tabbed folder label. Panel min-size **640×400**.
- **Corner accents**: four **8×8 px squares** of `#D9A440`, floating 9 px inside each panel corner (the "rivet dots").
- **Panel content**: margins 30 / 34 / 30 / 22; body VBox separation 10; each page = paragraphs (Label, word-wrap) + hint lines (`InfoText` `#C9B18C`) + two-column key rows: key = 150 px min width, **right-aligned `#FFD166`**; description = InfoText, expanding.
- **Footer**: **Back** (GreyButton, 130 px) — dark **dot pagination** (10×10 px squares: current = `#FFD166`, others = `#C9B18C` @ 35 % alpha) — **Next** (gold, 130 px). Next gets focus.
- **Page titles** (exact, in order): **WELCOME TO PIXL · THE STORY · WHY YOU'RE HERE · GETTING AROUND · HANG OUT · PROJECTS & PIXELS · SHOP & TRIALS · EXPLORE · HANDY KEYS**.
- **Last page button**: *"Open my Dashboard →"* when onboarding; posts step 1 to the server, closes the guide, opens the dashboard Projects page. Otherwise *"Let's go!"*.
- **Page-flip motion**: new page pops from **scale 0.94 → 1.0** with `TRANS_BACK` / `EASE_OUT` over **0.18 s**, alpha 0 → 1 over 0.12 s.
- **Keys**: ← / → / A / D to turn pages; Esc closes.
- **Typography exception**: the guide body (and this HUD only) swaps PixelifySans for a **system sans stack** (`Sans-Serif, Noto Sans, DejaVu Sans, Arial`) at `fs(20)` — long-form instructions are meant to be read, not decoded.
- **Content surfaces real product truths**: pixels pay $4–6/hr ($4 base + level bonus; 1 approved hour = 1 XP = 1 level, cap 100); keys **H** projects, **B** shop, **J** trial log, **E** explore, **N** inbox, **M** map, **F3 / ⌘K** shortcut list, **Esc** pause; Enter chat, T + 1–5 emotes, Tab player list; Shift to run.

### 6.7 In-game loading overlay — `loader.gd` + `loading_screen.tscn` **(S)**

- Autoloaded `CanvasLayer` **layer 128** that survives scene swaps (covers the gap until the server's `scene_init` round-trip).
- Screen: bg **`#0E0904`**, centered 560 px column: logo 560×140, **ProgressBar 560×34** — cream `#F5F0E8` track, **8 px `#1A1A17` border**, **coral `#D45F6A` fill** (the one coral bar in game UI), label **"LOADING"** 18 px cream @ 70 % with a 0.4 s dot-cycle animation.
- Progress model: file load maps to 0–90 %, then creeps toward 97 %; 8 s safety timeout (never stuck). `cover_jump()` runs an explicit 0→100 tween for in-world jumps (boat rides) with a hidden midpoint callback.

---

## 7. In-world HUD & components

### 7.1 Chat HUD

- Text `#F4E3C2`; dim `#C9B18C`; accent (mentions/system) `#FFD166`; **DMs lavender `#D9B8FF`**.
- Input border white @ 0.18; separators white @ 0.1; scrollbar backdrop `Color(0.05, 0.04, 0.03, 0.92)`.
- Enter opens/focuses; Esc closes; blocked while guide/dialogue open (`global.ui_blockers`).

### 7.2 Player HUD

- Top-left column anchored at (12, 12) — level readout ("level shows in the top-left" per guide), status.
- Modal dim overlay: `#0A0602` @ **0.66** (slightly lighter than the guide's 0.78 backdrop).
- Inbox notification dot: grey `#9E9480` — deliberately *not* red (red = Hack Club red = destructive/attention elsewhere).
- **HUD-hide toggle**: F2 (⌘H on macOS) hides minimap, emotes, player card — for clean screenshots.

### 7.3 Dialogue system — `dialogue.gd` **(S)**

- Layer 110. A **bottom-centered panel 1040 px wide** (offsets −520 / +520), anchored 28 px above the bottom edge, **minimum height 120 px, grows upward** (`GROW_DIRECTION_BEGIN`) — short lines stay compact, choice prompts expand.
- Content margins 22 / 16 / 22 / 14. Optional **96×96 portrait** (nearest-filter) left of the text column, 14 px gap.
- Type scale: speaker = TitleText **24 px**, body = default font **22 px**, choice buttons **20 px** full-width, hint = InfoText **16 px** right-aligned.
- **Typewriter**: **48 chars/sec**; interact key (E) or tap **snaps to full** first, then advances. Hint text: `[E]` → `[E] next` → `[E] close`.
- **Choice prompts** ("ask" mode): buttons appear only after the last prompt line finishes typing; buttons are click-only (`focus_mode = NONE` — prevents Enter accidentally picking option 1 while the player meant to chat); Esc is a **no-op during a choice** (picking is mandatory).
- Whole overlay is tap-to-advance on touch (no [E] key on phones).

---

## 8. Motion & interaction rules

| Element | Motion |
|---|---|
| Button press | Margins flip vertically (label drops 4 px) — instant, no tween |
| Focus | Static outer gold ring (2 px, expand 4) |
| Guide page flip | scale 0.94→1.0, TRANS_BACK/EASE_OUT, 0.18 s + fade 0.12 s |
| Dialogue text | 48 chars/sec typewriter; snap-to-full on input |
| Loading bar | Real progress 0–90 %, then creep to 97 %; 8 s timeout guard |
| Boot splash progress | Native `<progress>`, indeterminate until byte sizes known |
| Day/night tint | Day `#FFD166`, Dawn/Dusk `#FFA659`, Night `#8C9EF2` |

Nothing in the UI scales continuously or eases slowly; all feedback is discrete, step-based, or short (≤0.2 s). No motion on hover besides color/shadow warmth.

---

## 9. Asset inventory (all pixel art, nearest-neighbor, `corner_detail=1` everywhere)

| Asset | Size | Palette / notes |
|---|---|---|
| `ui/boot_splash.png` | 600×390 | cream `#F5EED2` bg; `#111111`, `#C4B894`, `#FFC93A`, `#C77800`, white |
| `ui/pixl_wordmark.png` | 720×224 | `#111111`, `#FFC93A`, `#C77800`, `#FFFFFF`, `#FFEA78`, transparent |
| `ui/hud_panel.png` | 16×16 | 9-patch: `#17100A` border, `#6B4F33` edge, `#2B1D12` fill |
| `ui/map_frame.png` + `_top` | 1392×816 | parchment `#F3DDBE`; browns `#A96C4E`, `#241A17`, `#76503C`, `#D19369` |
| `ui/minimap_frame.png` | 64×64 | gold decorative frame |
| `ui/pixel_currency_gold.png` | 340×340 | `#FFC93A`, `#FFE896`, `#C99414`, white; square center hole |
| `ui/pixel_currency_red.png` | 340×340 | `#EC3750`, `#F5788C`, `#961C2E`, white |
| `ui/trial_arrow.png` | 45×70 | `#000000`, `#FFC93A`, `#FFE896`, `#C99414` |
| `ui/switch_buttons/` | — | `button_a`, `button_b`, `dpad`, `minus`, `plus` (controller glyphs) |
| `cinematic/arrival.png` | — | story panel 4 |
| `cinematic/last_spacecraft.png` | — | story panel 3 |
| `cinematic/origin.png` | — | story panel 1 |
| `cinematic/overload.png` | — | story panel 2 (the Great Static) |
| `songs/intro_looped.mp3` | — | intro loop |
| `songs/pixl_theme_2.mp3` | — | main theme |
| `fonts/Monocraft.ttf` | — | menus only |
| `fonts/PixelifySans.ttf` | — | everything else |

Scene inventory (room types): `village`, `open_world`, `lobby_menu`, `house_interior`, `character_editor`, `cyberpunk_city`, `factory_island`, `pixel_cafe`; NPCs: `npc`, `chicken`, `cow`, `sheep`; player/remote_player.

---

## 10. Pixel-parity invariants ("do not" list)

1. **Never scale UI with transforms.** Re-rasterize (font sizes/constants/margins) instead — `Control.scale` blurs pixel fonts.
2. **Never anti-alias.** `anti_aliasing=false`, `corner_detail=1`, `TEXTURE_FILTER_NEAREST`, `image-rendering: pixelated`.
3. **Never substitute the golds.** Art `#FFC93A` ≠ static UI `#FFD166` ≠ runtime `#D99A1F` ≠ web orange `#FF8C37` / ember `#FF6B4A`.
4. **Runtime sync is exact-match only.** Anything not in `theme.json` (near-black outlines `#17100A`, art golds) stays as authored.
5. **Borders are bottom-heavy** (3 top / 7 bottom on buttons, 8 on title plates) — the "chunky shelf" look.
6. **Shadows are hard offsets** — black @ 0.5, offset (8,8) on panels; the web shell uses `4px 4px 0` / `8px 8px 0` hard shadows; buttons use a warm cream glow instead.
7. **Cream is a surface, never a near-white.** Separation comes from rules + shadows (PAPER rule).
8. **All timing is short and discrete** — presses are instant, page flips 0.18 s, typewriter 48 cps.
9. Text hierarchy pairs gold for emphasis (`#FFD166`) with cream body (`#F4E3C2`), khaki for hints (`#C9B18C`), grey for footers (`#888899`).
10. **Long-form reading surfaces get system fonts** (guide) — the pixel font is for identity, not paragraphs.

---

## 11. Provenance & evidence

- Live captures: `work/pixl-play/shots/` (desktop 1600×900 ×4, mobile 390×844 touch ×2) via `work/pixl-play/capture.mjs` (Playwright). One benign Godot engine console warning only.
- Launcher page: `work/pixl-play/index.html`.
- Source snapshot: `work/pixl-play/src/` — `packages/theme/{palette.json, sync.ts}`, `apps/game/{project.godot, theme.json, themes/main_theme.tres, icon.svg}`, scripts (`pixl_theme`, `settings`, `guide_hud`, `dialogue`, `loader`, `global`, `main_menu`, `login_screen`, `player_hud`, `chat_hud`), scenes, `docs/superpowers/specs/2026-10-11-hardened-relaunch-design.md`, `ONBOARDING_REDESIGN.md`.
- Repo tree: `work/pixl-play/pixl-tree.json` (2,847 entries).
- UI art analyzed with Pillow: `work/pixl-play/ui-assets/`.
- Source repo `github.com/hackclub/pixl` (MIT claimed; **license not independently verified — do not copy code verbatim without checking**). This document reproduces design facts for compatibility/reference only.

*Compiled 2026-10-17. Live values win over source values where they differ; runtime-synced values are marked in parentheses throughout.*
