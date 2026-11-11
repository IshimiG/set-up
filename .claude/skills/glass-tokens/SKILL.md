---
name: glass-tokens
description: Complete design-token layer of the user-approved warm "liquid glass" design system - every CSS custom property for the light and dark themes (cream #EEECE8 / coral #EC5B34 / forest / amber palette, ink levels, glass fills, borders, reflection, shadows, interior fills, text-safe state colors, button colors, chart colors, scrim), the radius scale, spacing, gutters, max-width, 12-column grid and breakpoints, typography (Inter-style sans stack, Instrument Serif only for highlighted titles, never for numbers; tabular semi-bold numbers with a small unit; mono for technical data), spring easing curves, focus ring, theme switching via the data-tema attribute with localStorage persistence, and a ready-to-paste :root block for both themes. Trigger when the user asks to design, build or restyle a UI, panel, dashboard, page or component in "our glass style / liquid glass / panel style", or when any colors, radii, fonts, sizes or theme toggling are needed. Part of the glass-design family (hub skill: glass-design); sibling skills cover surfaces, controls, navigation, overlays, data and motion.
---

# glass-tokens - the token layer

Source of truth: `~/.claude/skills/glass-design/reference/demo-complete.html`. This skill owns every raw value (colors, radii, fonts, sizes, easing). Other glass-* skills consume these tokens via `var(--...)`; never hard-code a value that has a token.

Token names are Spanish in the demo (`--fondo`, `--tinta`, `--vidrio`...). Keep these names so snippets from all sibling skills work unchanged.

| Token | Meaning |
|---|---|
| `fondo` | page background | `luz` | soft top light |
| `tinta` | ink / text | `vidrio` | glass fill |
| `vidrio-hoja` | sheet/menu/tooltip glass (more opaque) | `pill` | selected pill inside segmented/nav |
| `borde` | glass edge | `linea` | hairline divider |
| `reflejo` | top inner highlight | `sombra` | shadow |
| `interior` | inner fill | `velo` | scrim behind sheets |
| `muelle` | spring-out easing | `cierra` | closing easing (anticipation) |
| `verde/ambar/coral-txt` | text-safe state colors | `grano` | grain layer |

## Fixed (theme-independent) tokens

| Token | Value | Use |
|---|---|---|
| `--coral` | `#EC5B34` | primary accent, focus ring, error dot, coral solid |
| `--coral-2` | `#F6A285` | light coral (gradient start, dark-theme text, donut) |
| `--coral-tint` | `#FCEAE3` | light-theme coral icon-box fill |
| `--coral-ink` | `#B8461F` | coral text/icon on tint |
| `--forest` | `#1F5C45` | forest green (text) |
| `--forest-dot` | `#2E8A63` | OK status dot |
| `--amber` | `#9A5F14` | amber (text) |
| `--amber-dot` | `#D99A2B` | warning status dot |
| `--sans` | `"Inter","Adwaita Sans","SF Pro Text",system-ui,sans-serif` | everything |
| `--serif` | `"Instrument Serif","Noto Serif Display","Newsreader",Georgia,serif` | highlighted titles only |
| `--mono` | `"JetBrains Mono","SF Mono",ui-monospace,monospace` | technical data |
| `--r-xl` | `44px` | sheets (top corners) |
| `--r-l` | `40px` | cards, glass panels, solid panels |
| `--r-m` | `24px` | inner blocks, menus, toasts, log boxes, big shortcut buttons |
| `--r-s` | `16px` | icon boxes, tooltips, menu items, skeleton bars |
| (literal) | `99px` / `50%` | pills: buttons, chips, fields, segmented, nav, toggle; circles: round buttons |
| `--muelle` | `cubic-bezier(.34,1.45,.4,1)` | spring (opening / any entering motion) |
| `--cierra` | `cubic-bezier(.55,-.3,.45,1)` | elastic close (anticipation then exit) |

Other literal radii in the demo: checkbox `12px`, skeleton big number `18px`, empty-state icon `24px`, swatch `14px`, handle/bars `9px`/`99px`, legend swatch `5px`.

## Theme tokens

### Light (`data-tema="claro"`)

| Token | Value |
|---|---|
| `color-scheme` | `light` |
| `--fondo` | `#EEECE8` (cream) |
| `--luz` | `rgba(255,255,255,.85)` |
| `--tinta` / `--tinta-2` / `--tinta-3` | `#151412` / `#55514b` / `#6f6a62` |
| `--vidrio` | `rgba(255,255,255,.52)` |
| `--vidrio-hoja` | `rgba(255,255,255,.78)` |
| `--pill` | `rgba(255,255,255,.95)` |
| `--borde` | `rgba(255,255,255,.85)` |
| `--linea` | `rgba(28,24,20,.09)` |
| `--reflejo` | `rgba(255,255,255,.9)` |
| `--sombra` | `0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22)` |
| `--interior` / `--interior-2` | `rgba(28,24,20,.05)` / `rgba(28,24,20,.09)` |
| `--btn` / `--btn-tinta` | `#151412` / `#fff` |
| `--verde-txt` / `--ambar-txt` / `--coral-txt` | `#1F5C45` / `#8A5410` / `#B8461F` |
| `--c1..--c5` (chart) | `#EC5B34` `#F6A285` `#151412` `#8a857d` `#CFCAC1` |
| `--velo` | `rgba(10,8,6,.3)` |

### Dark (`data-tema="oscuro"`)

| Token | Value |
|---|---|
| `color-scheme` | `dark` |
| `--fondo` | `#121210` |
| `--luz` | `rgba(255,255,255,.07)` |
| `--tinta` / `--tinta-2` / `--tinta-3` | `#f4f2ee` / `rgba(244,242,238,.74)` / `rgba(244,242,238,.6)` |
| `--vidrio` | `rgba(34,32,30,.42)` |
| `--vidrio-hoja` | `rgba(28,27,25,.8)` |
| `--pill` | `rgba(255,255,255,.15)` |
| `--borde` | `rgba(255,255,255,.18)` |
| `--linea` | `rgba(255,255,255,.11)` |
| `--reflejo` | `rgba(255,255,255,.3)` |
| `--sombra` | `0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18)` |
| `--interior` / `--interior-2` | `rgba(255,255,255,.07)` / `rgba(255,255,255,.12)` |
| `--btn` / `--btn-tinta` | `#f4f2ee` / `#151412` |
| `--verde-txt` / `--ambar-txt` / `--coral-txt` | `#6FD3A6` / `#EDBB62` / `#F6A285` |
| `--c1..--c5` (chart) | `#EC5B34` `#F6A285` `#f4f2ee` `#8d8a84` `#4a4742` |
| `--velo` | `rgba(0,0,0,.5)` |

Rules:
- Ink levels: `--tinta` primary text, `--tinta-2` secondary (sub-lines, units, inactive controls), `--tinta-3` tertiary (uppercase labels, placeholders, axis text, "off" dot).
- Colored text on glass MUST use the text-safe `--verde-txt`, `--ambar-txt`, `--coral-txt` (they change per theme for contrast). `--forest`, `--amber`, `--coral` and the `*-dot` colors are for dots, fills and borders, not for body text.
- Dots: `.ok` = `--forest-dot`, `.av` = `--amber-dot`, `.er` = `--coral`, `.off` = `--tinta-3`.
- Coral solid with white text uses `#EC5B34`; ink solid in dark theme inverts to cream (see glass-surfaces).
- Fixed literals used inside solids (see glass-surfaces): coral gradient `#E9785A`, `#D8573A`, `#B94428`; ink gradient `#34312d`, `#211f1c`, `#121110`; dark-theme ink-inverted `#ece9e3`, `#d9d5ce`.
- Chart tokens `--c1..--c5` are the only series colors; details in glass-data.

## Layout tokens (literals in the demo)

| Item | Value |
|---|---|
| Page container | `main{max-width:1080px;margin:0 auto;padding:28px 20px 140px}` (140px bottom clears the floating nav) |
| Mobile (<=560px) container | `padding:20px 16px 140px` (16px side gutter) |
| Grid | `display:grid;grid-template-columns:repeat(12,1fr);gap:16px` (gap 12px at <=560px) |
| Spans | `.c-3 .c-4 .c-5 .c-6 .c-7 .c-8 .c-12` = `grid-column:span N` |
| Card padding | `24px` (20px at <=560px), `min-width:0` |
| Header block | `margin:18px 4px 28px`, gap 16px |
| Inner gaps | rows 12px, button groups 10px, form 16px, two-column form 12px, data tiles 10px |
| Sheet padding | `12px 28px 40px`; sheet width `min(580px,100%)`, wide `min(820px,100%)`, max-height `92vh` |
| Floating nav | `bottom:22px`, padding `7px`, `max-width:calc(100% - 24px)` |
| Toasts | `bottom:104px`, width `min(420px,calc(100% - 28px))` |

### Breakpoints

| Query | Effect |
|---|---|
| `max-width:900px` | `.c-3` spans 6 |
| `max-width:760px` | `.c-4 .c-5 .c-6 .c-7 .c-8` span 12 |
| `max-width:620px` | secondary table columns (`.oc`) hidden |
| `max-width:560px` | `.sol.c-3` spans 12; card padding 20px; grid gap 12px; main padding `20px 16px 140px`; `.num` 34px; nav buttons stack icon over label (11.5px) |
| `max-width:480px` | data tiles 2 columns; two-column forms 1 column |
| `hover:hover` | all hover styles live inside this query only |
| `prefers-reduced-motion:reduce` | all animation/transition durations -> `.01ms`, iteration 1 |

### z-index scale

| z | Element |
|---|---|
| `-1` | background layers `.capa` (grain, light) |
| `1` | segmented buttons/nav buttons above their sliding pill |
| `5` | floating nav |
| `8` | scrim `.velo` |
| `9` | sheet `.hoja` |
| `20` | context menu |
| `25` | toasts |
| `30` | chart tooltip |

## Typography

| Role | Spec |
|---|---|
| Base | `font-family:var(--sans)`, `-webkit-font-smoothing:antialiased`, color `var(--tinta)`; form controls `font:inherit;color:inherit` |
| Page title `h1` | **serif**, weight 400, `font-size:clamp(40px,6vw,64px)`, `letter-spacing:-.02em`, `line-height:1` |
| Sheet title `h2` | **serif**, weight 400, `38px`, `letter-spacing:-.01em`, margin `6px 0 8px` |
| Subtitle `.sub` | sans 14px, `--tinta-2`, margin-top 8px (12.5px inside tasks/solids' small lines) |
| Label `.etq` | sans 12px, weight 600, `letter-spacing:.06em`, uppercase, `--tinta-3` (11px inside data tiles) |
| Number `.num` | sans, weight 600, 46px, `line-height:1`, `letter-spacing:-.03em`, `font-variant-numeric:tabular-nums`, margin `12px 0 6px`; `.xl` = 56px; at <=560px 34px / xl 44px |
| Unit `.num small` | 20px, weight 500, `--tinta-2`, `letter-spacing:0`, `margin-left:3px` (16px at <=560px) |
| Inline amount `.amt` | weight 600, tabular-nums, nowrap; its `small` is `.85em`, weight 500, `--tinta-2`, margin-left 2px |
| Donut center `.dn` | sans 26px, 600, tabular-nums |
| Body/rows | 14.5-15px sans; row name weight 500; row sub 12.5px `--tinta-2` |
| Buttons | weight 600, 14.5px (small 13px); chips 12.5px weight 600; segmented 13.5px weight 600; nav 14px weight 600 |
| Field label `.lb` | 12.5px, weight 600, `--tinta-2`, margin `0 0 7px 6px` |
| Table head | 12px, 600, uppercase, `.06em`, `--tinta-3` |
| Chart text | sans 11.5px, `--tinta-3`, tabular-nums |
| Mono `.m,.mono` | `--mono` 13px `--tinta-2` (12.5px in tables, 11.5px swatch hex); logs 12.5px, line-height 1.75 |

Where serif is allowed: ONLY `h1` page titles and `h2` sheet titles (highlighted titles). Serif is FORBIDDEN for numbers, percentages, amounts, labels, buttons, body, table text, empty-state `h3` (that one is sans 18px/600). Numbers = semi-bold sans, tabular figures, unit/currency/suffix in a smaller `<small>` beside it (`12.480<small>,35 €</small>`, `34<small>%</small>`, `7<small>/ 8</small>`).

Mono is for technical data only: container names, IDs, versions, timestamps in logs, paths, hex values, uptime, memory in tables, log output.

## Theme switching

- Attribute on `<html>`: `data-tema="claro"` (default) or `data-tema="oscuro"`; tokens live in `:root[data-tema="..."]` selectors and set `color-scheme`.
- `html{background:var(--fondo);transition:background .5s}` so the switch cross-fades.
- Persistence: `localStorage` key `g2-tema` (rename per project, e.g. `<app>-tema`), always inside try/catch.
- Toggle: a round glass button (48px) in the page header with an inline SVG icon; no `prefers-color-scheme` auto-detect in the demo (optional: default from `matchMedia('(prefers-color-scheme: dark)')` when nothing is stored).
- Theme-specific overrides beyond tokens: grain (`mix-blend-mode:screen;opacity:.35;filter:invert(1)` in dark), ink solid inverts, skeleton shimmer opacity `.16`, coral icon box, toggle knob. Redraw JS-rendered color swatches/charts on switch.

```js
const R = document.documentElement;
try { const t = localStorage.getItem('app-tema'); if (t) R.dataset.tema = t; } catch (e) {}
document.querySelector('#tema').onclick = () => {
  const n = R.dataset.tema === 'claro' ? 'oscuro' : 'claro';
  R.dataset.tema = n;
  try { localStorage.setItem('app-tema', n); } catch (e) {}
};
```

To avoid a flash of the wrong theme, run the `localStorage` read in a tiny inline `<script>` in `<head>` before first paint.

## Base reset and focus

```css
*{box-sizing:border-box;margin:0}
html{background:var(--fondo);transition:background .5s}
body{font-family:var(--sans);color:var(--tinta);min-height:100vh;overflow-x:hidden;position:relative;-webkit-font-smoothing:antialiased}
button,input,select{font:inherit;color:inherit}
:focus-visible{outline:2px solid var(--coral);outline-offset:3px}
.sol:focus-visible,.btn.coral:focus-visible{outline-color:var(--tinta)}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
@media (prefers-reduced-motion:reduce){
  *,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;transition-delay:0s!important}
}
```

## Background (plain: grain + soft top light)

No color blobs, no colored gradients, no shapes. Two fixed layers:

```css
.capa{position:fixed;inset:0;z-index:-1;pointer-events:none}
.grano{opacity:.5;mix-blend-mode:multiply;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/%3E%3CfeColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .09 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}
:root[data-tema="oscuro"] .grano{mix-blend-mode:screen;opacity:.35;filter:invert(1)}
.luz{background:radial-gradient(70vw 40vw at 50% -8%,var(--luz),transparent 70%)}
```
```html
<div class="capa luz"></div><div class="capa grano"></div>
```

## Icon token (inline SVG)

```css
svg.i{width:1em;height:1em;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}
```
Size comes from `font-size` of the parent (18-20px typical). No emojis anywhere.

## Ready-to-paste :root block (both themes)

```css
:root{
  --coral:#EC5B34; --coral-2:#F6A285; --coral-tint:#FCEAE3; --coral-ink:#B8461F;
  --forest:#1F5C45; --forest-dot:#2E8A63; --amber:#9A5F14; --amber-dot:#D99A2B;
  --sans:"Inter","Adwaita Sans","SF Pro Text",system-ui,sans-serif;
  --serif:"Instrument Serif","Noto Serif Display","Newsreader",Georgia,serif;
  --mono:"JetBrains Mono","SF Mono",ui-monospace,monospace;
  --r-xl:44px; --r-l:40px; --r-m:24px; --r-s:16px;
  --muelle:cubic-bezier(.34,1.45,.4,1);
  --cierra:cubic-bezier(.55,-.3,.45,1);
}
:root[data-tema="claro"]{
  color-scheme:light;
  --fondo:#EEECE8; --luz:rgba(255,255,255,.85);
  --tinta:#151412; --tinta-2:#55514b; --tinta-3:#6f6a62;
  --vidrio:rgba(255,255,255,.52); --vidrio-hoja:rgba(255,255,255,.78); --pill:rgba(255,255,255,.95);
  --borde:rgba(255,255,255,.85); --linea:rgba(28,24,20,.09);
  --reflejo:rgba(255,255,255,.9);
  --sombra:0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22);
  --interior:rgba(28,24,20,.05); --interior-2:rgba(28,24,20,.09);
  --btn:#151412; --btn-tinta:#fff;
  --verde-txt:#1F5C45; --ambar-txt:#8A5410; --coral-txt:#B8461F;
  --c1:#EC5B34; --c2:#F6A285; --c3:#151412; --c4:#8a857d; --c5:#CFCAC1;
  --velo:rgba(10,8,6,.3);
}
:root[data-tema="oscuro"]{
  color-scheme:dark;
  --fondo:#121210; --luz:rgba(255,255,255,.07);
  --tinta:#f4f2ee; --tinta-2:rgba(244,242,238,.74); --tinta-3:rgba(244,242,238,.6);
  --vidrio:rgba(34,32,30,.42); --vidrio-hoja:rgba(28,27,25,.8); --pill:rgba(255,255,255,.15);
  --borde:rgba(255,255,255,.18); --linea:rgba(255,255,255,.11);
  --reflejo:rgba(255,255,255,.3);
  --sombra:0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18);
  --interior:rgba(255,255,255,.07); --interior-2:rgba(255,255,255,.12);
  --btn:#f4f2ee; --btn-tinta:#151412;
  --verde-txt:#6FD3A6; --ambar-txt:#EDBB62; --coral-txt:#F6A285;
  --c1:#EC5B34; --c2:#F6A285; --c3:#f4f2ee; --c4:#8d8a84; --c5:#4a4742;
  --velo:rgba(0,0,0,.5);
}
```
Page shell: `<html lang="es" data-tema="claro">` (set `lang` to the app language).

## Do / Don't

Do:
- Reference tokens (`var(--tinta-2)`, `var(--r-l)`) instead of literals; add new tokens to BOTH theme blocks.
- Use `--verde-txt/--ambar-txt/--coral-txt` for any colored text; dots/fills use `*-dot`/`--coral`.
- Cards 40px, inner blocks 24px, icon boxes/tooltips 16px, controls pill (99px), sheets 44px top corners.
- Numbers: sans 600 tabular-nums with a small unit beside; mono for technical strings.
- Keep hover only inside `@media(hover:hover)` and only on controls.
- Keep `--muelle` for entering and `--cierra` for leaving (details in glass-motion).

Don't:
- Use serif for numbers, percentages, amounts, labels or body text; use it for anything except `h1`/`h2` highlighted titles.
- Add colored gradients, blurry blobs or decorative shapes to the background; only grain + top light.
- Use pure `#000`/`#fff` page backgrounds, other cream/coral values, or text colors without a token.
- Use hex colors for text on glass instead of the text-safe variants.
- Hard-code theme colors outside the `data-tema` blocks, or forget a dark-theme counterpart.
- Use emojis or icon fonts; use inline line SVG (stroke 1.6, round caps).
- Make the page horizontally scroll at phone width (16px gutter, `overflow-x:hidden` on body).

## Related skills

glass-design (hub), glass-tokens (this), glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion.
