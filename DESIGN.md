# TPLive landing page — Design reference

Single source of truth for how the **web landing page** (`site/`) looks and sounds.
It does not restyle the Android/web app; it borrows the app's tokens so the two
feel like one product. If a choice is not covered here, derive it from the app
(`lib/core/theme/app_theme.dart`, `app_motion.dart`, `format.dart`) — never invent
a parallel style. Material 3 is the base; the identity comes from **route
geometry and corridor colour**, not from decoration.

## 1. Principles
1. **Utility first.** A commuter wants "where is my bus, when does it arrive".
   Every screen and section answers that or gets cut.
2. **Show the real product.** Use real screenshots of the real app. No stock
   art, no illustrations of people, no abstract blobs/gradients.
3. **Route as motif.** The one recurring graphic is a line with stops (halte):
   dots joined by a line, a bus marker, corridor-coloured chips. Use it for
   structure (steps, dividers), not as ornament.
4. **Calm, not loud.** One accent (brand orange), neutrals from the tonal
   palette, corridor colours only where they *mean* a corridor.
5. **Honest.** Unofficial project; ETAs are straight-line estimates; service runs
   06.00–19.00 WIB. Say so plainly, near where it matters.

### Anti-slop rules (do not)
- No gradient text, glow shadows, glassmorphism, floating blobs, or emoji used
  as icons.
- No grid of N identical cards with icon + title + one line. Vary the layout:
  a feature earns space in proportion to how much the user cares about it.
- No centred-everything layout. Left-align text; centre only a single short
  call-to-action line.
- No filler superlatives ("revolutionary", "seamless", "powerful"). Copy states
  what the app does, in the user's words.
- No hover-only information; no animation that is not purposeful.
- No invented numbers/testimonials/ratings. Only facts we can verify
  (6 corridors, 286 stops, hours, version).

## 2. Colour
Seed `#F47F38` (logo orange), `ColorScheme.fromSeed` (the exact app values).
Website tokens are CSS custom properties with these names/values; dark values
apply under `prefers-color-scheme: dark`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `--primary` | `#9D4400` | `#FFB690` | links, filled buttons, key accents |
| `--on-primary` | `#FFFFFF` | `#542100` | text on primary |
| `--primary-container` | `#FFDBCA` | `#783200` | tonal highlights, selected |
| `--on-primary-container` | `#331100` | `#FFDBCA` | text on primary container |
| `--surface` | `#FFFBFF` | `#201A17` | page background |
| `--on-surface` | `#201A17` | `#ECE0DB` | body text |
| `--surface-variant` | `#F4DED4` | `#52443D` | panels, chips |
| `--on-surface-variant` | `#52443D` | `#D7C2B9` | secondary text |
| `--outline` | `#85746B` | `#A08D84` | borders needing 3:1 |
| `--outline-variant` | `#D7C2B9` | `#52443D` | hairlines, dividers |
| `--brand` | `#F47F38` | `#F47F38` | logo/route line only, never body text |

**Corridor colours** (fixed identity, from `corridorColor`): K1 `#C8163F`,
K2 `#EAA221`, K3 `#5CC49A`, K4 `#5F9A4F`, K5 `#1F2A6B`, K6 `#1E9BDB`. Text on a
corridor chip: dark (`#000000DE`) on K2/K3, white on others (`onCorridorColor`).
Outside-hours purple: `#7B1FA2` (light) / `#CE93D8` (dark).

Contrast: body text ≥ 4.5:1, large text/UI ≥ 3:1. `--brand` orange on light
surface fails for text, so text/links use `--primary`.

## 3. Typography
System stack (no web-font download; many users are on mobile data):
`system-ui, -apple-system, "Segoe UI", Roboto, sans-serif`. Scale follows MD3
roles; website uses fluid sizes via `clamp()`.

| Role | Size / line | Weight | Use |
|---|---|---|---|
| Display | `clamp(2.25rem, 5vw + 1rem, 3.5rem)` / 1.1 | 700, tracking −0.02em | hero headline only |
| Headline | `clamp(1.5rem, 2vw + 1rem, 2rem)` / 1.2 | 700 | section titles |
| Title | 1.125rem / 1.3 | 600 | card/step titles |
| Body | 1rem / 1.6 | 400 | paragraphs (max 62ch) |
| Label | 0.875rem / 1.3 | 600 | buttons, chips |
| Caption | 0.8125rem / 1.4 | 400 | footnotes, disclaimers |

Never go below 13 px. Numbers that change (times, distances) use
`font-variant-numeric: tabular-nums`.

## 4. Shape & elevation
Radii (from `AppShape`): `4 / 8 / 12 / 16 / 28 px` + full (`999px`). Buttons and
chips: full. Cards/panels: 16. Screenshots in a phone frame: 28 outer, 20 inner.
Elevation is expressed with tone and 1 px `--outline-variant` borders, **not**
drop shadows. Maximum one soft shadow (`0 1px 3px` at ≤ 12 % black) for the phone
frame.

## 5. Spacing & layout
4-px base grid: 4, 8, 12, 16, 24, 32, 48, 64, 96. Page gutter 16 px (phone) →
24 px (≥ 600). Content max-width 1040 px; prose 62ch. Breakpoints: 600, 900.
Section vertical rhythm 64 px (phone) / 96 px (desktop). Hero is a two-column
split ≥ 900 px (copy left, phone right); stacked below.
Touch targets ≥ 48 × 48 px.

## 6. Components
- **Button, filled** (`--primary` bg, `--on-primary` text, full radius, 48 px
  tall, 24 px side padding). **Button, tonal** (`--primary-container` bg).
  **Text link** underlined on hover/focus. Visible 3 px focus ring in
  `--primary`, offset 2.
- **Corridor chip**: circle 40 px, corridor colour, bold label — identical to
  `CorridorBadge`. Used as a legend and in the "pilih koridor" block.
- **Route line**: 2 px `--brand` line, 12 px stop dots (`--surface` fill, 3 px
  `--brand` ring); the last stop is filled. Used for the "how it works" steps.
- **Phone frame**: device screenshot with 28 px radius, 1 px outline, no
  fake notch/buttons. Light and dark screenshots swap with the colour scheme
  (`<picture>` + `prefers-color-scheme`).
- **Status note** (disclaimer, hours): left 4 px `--brand` bar on
  `--surface-variant`, caption text.
- **Details/FAQ**: native `<details>`, 1 px hairline separators, no boxes.

## 7. Motion
Same tokens as the app (`AppMotion`): durations 100/200/300/400 ms; standard
easing `cubic-bezier(0.65, 0, 0.35, 1)`, enter `cubic-bezier(0.05, 0.7, 0.1, 1)`.
Allowed: fade/translate-up (≤ 12 px) on first view, button state changes.
Everything respects `prefers-reduced-motion: reduce` (disable, not shorten).

## 8. Content & voice
- Indonesian first, English second via a visible toggle; both complete.
- Direct, specific, second person ("kamu"). Sentences ≤ 20 words.
- Name things like the app does: *koridor, halte, ikuti bus, cari tujuan*.
- Always pair the headline claim with the caveat that matters: hours,
  unofficial, estimate.
- Calls to action: "Buka Web App", "Unduh APK". No "Get started".

## 9. Accessibility
WCAG 2.2 AA. Semantic landmarks (`header/main/footer`), one `h1`, logical
heading order, `lang` kept in sync with the toggle, alt text describing the
screen (not "screenshot"), skip link, focus order = visual order, reduced-motion
and dark-mode support, text resizable to 200 % without loss.

## 10. Assets
Logo/icon: `assets/logo/app_icon.png` (→ `site/icon-*.png`). Screenshots live in
`site/img/` (`<screen>-<light|dark>.webp`, 1080 px wide originals, served ≤ 720 px
wide). Re-capture when the UI changes noticeably.
