---
name: glass-surfaces
description: Materials of the approved glass design system - the page background (plain base color + SVG grain overlay + soft top light, with a list of forbidden backgrounds), the Apple-style liquid glass material (backdrop-filter blur/saturate, fill, border, inner top reflection, shadow, light and dark values, fallback without backdrop-filter), the glass card anatomy (padding, radii, label, big number, sub text), the solid panels (coral and ink recipes with gradient, light corner, grain ::before, colored halo, icon badge, translucent chip, dark-theme ink inversion), the rule for when a panel may be solid (only important or actionable, max 2 per screen, only coral or ink, never green or amber) and the rule that containers have no hover. Trigger when the user asks to design, build or restyle a UI, panel, dashboard, page, card or component in "our glass style", "liquid glass", "panel style" or "the glass design", or asks about backgrounds, cards, glass, grain, solid or highlighted panels. Part of the glass-design family; the hub skill is glass-design.
---

# glass-surfaces

## Purpose
Everything that is a *surface* in the glass design system: the page background, the liquid glass material, cards and the rare solid panels. Colors/radii tokens live in `glass-tokens`; this skill shows how they are combined into materials. Source of truth: `~/.claude/skills/glass-design/reference/demo-complete.html`.

Rule of thumb: **everything is glass, except the one or two things that matter, which are solid coral or solid ink.**

## 1. Page background

Three stacked layers, nothing else:

1. Plain base color on `html` (`--fondo`): light `#EEECE8` (cream), dark `#121210`.
2. Grain overlay (fixed, `z-index:-1`, `pointer-events:none`).
3. Soft top light: one radial white glow fading at the top edge.

| Token / layer | Light | Dark |
|---|---|---|
| `--fondo` | `#EEECE8` | `#121210` |
| `--luz` (top light color) | `rgba(255,255,255,.85)` | `rgba(255,255,255,.07)` |
| grain opacity | `.5` | `.35` |
| grain blend mode | `multiply` | `screen` (+ `filter:invert(1)`) |

```html
<div class="capa luz"></div>
<div class="capa grano"></div>
```
```css
html{background:var(--fondo);transition:background .5s}
.capa{position:fixed;inset:0;z-index:-1;pointer-events:none}
.grano{opacity:.5;mix-blend-mode:multiply;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='160' height='160'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2' stitchTiles='stitch'/%3E%3CfeColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 .09 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}
:root[data-tema="oscuro"] .grano{mix-blend-mode:screen;opacity:.35;filter:invert(1)}
.luz{background:radial-gradient(70vw 40vw at 50% -8%,var(--luz),transparent 70%)}
```
Body: `position:relative; min-height:100vh; overflow-x:hidden;` and no own background (the html color shows through).

Forbidden backgrounds (never do any of these):
- Blurry color blobs / orbs / aurora / mesh gradients behind the glass.
- Color gradients of any kind on the page background (the only gradient allowed is the white/neutral top light above).
- Decorative shapes, circles, waves, patterns, illustrations, images or photos.
- Pure white `#fff` or pure black `#000` page background; saturated tinted backgrounds.
- A second light source, colored light, or a glow that is not the single top radial.

Why: liquid glass needs a calm, neutral backdrop so blur + saturate reads as material instead of as noise.

## 2. Liquid glass material

Class `.vidrio`. Used by cards, floating nav, round buttons, sheets, menus, toasts, tooltips.

Tokens per theme (defined on `:root[data-tema=...]`):

| Token | Light | Dark |
|---|---|---|
| `--vidrio` (card fill) | `rgba(255,255,255,.52)` | `rgba(34,32,30,.42)` |
| `--vidrio-hoja` (sheets, menus, tooltips: denser) | `rgba(255,255,255,.78)` | `rgba(28,27,25,.8)` |
| `--pill` (active pill inside glass) | `rgba(255,255,255,.95)` | `rgba(255,255,255,.15)` |
| `--borde` | `rgba(255,255,255,.85)` | `rgba(255,255,255,.18)` |
| `--linea` (dividers) | `rgba(28,24,20,.09)` | `rgba(255,255,255,.11)` |
| `--reflejo` (inner top highlight) | `rgba(255,255,255,.9)` | `rgba(255,255,255,.3)` |
| `--sombra` | `0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22)` | `0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18)` |
| `--interior` (inset tint on glass) | `rgba(28,24,20,.05)` | `rgba(255,255,255,.07)` |
| `--interior-2` | `rgba(28,24,20,.09)` | `rgba(255,255,255,.12)` |
| `--velo` (scrim behind sheets) | `rgba(10,8,6,.3)` | `rgba(0,0,0,.5)` |

```css
.vidrio{
  background:var(--vidrio);
  -webkit-backdrop-filter:blur(26px) saturate(1.6);backdrop-filter:blur(26px) saturate(1.6);
  border:1px solid var(--borde);
  box-shadow:var(--sombra),inset 0 1px 0 var(--reflejo),inset 0 -1px 0 rgba(255,255,255,.05);
  border-radius:var(--r-l); /* 40px */
}
```
Recipe in words: fill translucent + `blur(26px) saturate(1.6)` + 1px light border + inner 1px top reflection (`inset 0 1px 0 var(--reflejo)`) + faint inner bottom (`inset 0 -1px 0 rgba(255,255,255,.05)`) + soft long drop shadow.

Variants:
- Sheet / menu: `background:var(--vidrio-hoja)` with the same `blur(26px) saturate(1.6)`, border, `box-shadow:var(--sombra),inset 0 1px 0 var(--reflejo)`.
- Tooltip: `var(--vidrio-hoja)`, `blur(20px)` (no saturate), `--borde`, `--sombra`.
- Inner sub-surfaces (rows' icon tiles, data cells, log boxes, inputs) are NOT glass: they use `background:var(--interior)` (or `--interior-2`) with no blur.
- Dividers inside glass: `border-top:1px solid var(--linea)`.

Fallback when `backdrop-filter` is unsupported: the demo relies on the translucent fill, so add a denser fill so text stays legible (do not blur through `filter`):
```css
@supports not ((backdrop-filter:blur(1px)) or (-webkit-backdrop-filter:blur(1px))){
  :root[data-tema="claro"]{--vidrio:rgba(255,255,255,.82);--vidrio-hoja:rgba(255,255,255,.94)}
  :root[data-tema="oscuro"]{--vidrio:rgba(34,32,30,.82);--vidrio-hoja:rgba(28,27,25,.95)}
}
```
Rules: always keep the `-webkit-` prefixed line; glass only makes sense over the plain background (never stack more than two glass layers; a glass element inside glass should use `--interior`, not another `.vidrio`, except toasts/menus/tooltips which float above).

## 3. Glass card anatomy

```html
<section class="card vidrio c-3">
  <span class="ico ib" data-ic="wallet"></span>   <!-- optional icon badge, top-right -->
  <div class="etq">Saldo</div>                      <!-- label -->
  <div class="num">12.480<small>,35 €</small></div> <!-- big number + small unit -->
  <div class="sub">+3,2 % este mes</div>            <!-- sub text -->
</section>
```
```css
.card{padding:24px;transition:transform .5s var(--muelle);min-width:0}   /* mobile <=560px: padding:20px */
.etq{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--tinta-3);font-weight:600}
.card:has(.ico) .etq{padding-right:50px}
.num{font-weight:600;font-size:46px;line-height:1;margin:12px 0 6px;letter-spacing:-.03em;font-variant-numeric:tabular-nums}
.num small{font-size:20px;font-weight:500;color:var(--tinta-2);letter-spacing:0;margin-left:3px}
.num.xl{font-size:56px}
.sub{color:var(--tinta-2);font-size:14px;margin-top:8px}
@media(max-width:560px){.num{font-size:34px}.num small{font-size:16px}.num.xl{font-size:44px}}
.ico{position:absolute;top:20px;right:20px;width:42px;height:42px;border-radius:var(--r-s);display:grid;place-items:center;font-size:20px}
.ib{display:inline-grid;place-items:center;width:40px;height:40px;border-radius:var(--r-s);background:var(--interior);font-size:19px;flex:none;color:var(--tinta)}
```
(`.card` that hosts an `.ico` must be `position:relative`; `.sol` already is, add `position:relative` to glass cards that use `.ico`.)

| Part | Spec |
|---|---|
| Card radius | `--r-l` 40px (inner blocks `--r-m` 24px, icon tiles `--r-s` 16px, sheets `--r-xl` 44px, controls pill 99px) |
| Padding | 24px (20px at <=560px) |
| Grid gap | 16px (12px at <=560px), 12-col grid, spans `c-3 c-4 c-5 c-6 c-7 c-8 c-12` |
| Label (`.etq`) | 12px, uppercase, +.06em, 600, `--tinta-3` |
| Number (`.num`) | semi-bold (600) SANS, 46px (56px `.xl`), tabular-nums, -.03em; unit in `<small>` 20px/500 `--tinta-2`. NEVER serif, never light weight |
| Sub (`.sub`) | 14px `--tinta-2`, margin-top 8px |
| Icon badge | 42px / 16px radius, top 20px right 20px, line SVG stroke 1.6 |
| Status | small `.punto` (9px dot) + `.chip`; green/amber/coral appear only as dots and chip text, never as card fill |

Compose card interiors with `.fila` rows (`display:flex;gap:12px;padding:12px 0;border-top:1px solid var(--linea)`, first has no border), `.cab` header rows (label left, chip/segmented right), and `.barra` progress bars (10px, `--interior-2` track).

## 4. Solid panels (the exception)

### Decision rule - when may a panel be solid?
1. Only if the item is **important or actionable** (needs attention, or is the primary call to action of the screen): an error needing action, today's tasks, a pending payment, "new task".
2. **Maximum 2 solid panels per screen.** A third candidate stays glass.
3. **Only coral or ink.** Green and amber are NEVER solid fills (they appear only as dots and chip text on glass).
4. Coral = urgent/danger/pay/act now. Ink = important neutral/primary entry point. When in doubt, use glass.
5. Informational metrics (balance, CPU, counts) are always glass.
6. Max 2 total, not 2 of each: e.g. one coral + one ink, or two ink, or one coral.

### Shared base `.sol` (always together with `.sol-coral` or `.sol-tinta`)
```css
.sol{color:#fff;border:0;box-shadow:0 18px 40px -18px rgba(0,0,0,.45),inset 0 1px 0 rgba(255,255,255,.25);
  position:relative;overflow:hidden;isolation:isolate;display:block;text-align:left;cursor:pointer;width:100%;border-radius:var(--r-l)}
/* grain overlay inside the panel */
.sol::before{content:"";position:absolute;inset:0;z-index:-1;pointer-events:none;opacity:.55;mix-blend-mode:overlay;
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/%3E%3CfeColorMatrix values='0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 .55 0'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}
```

### Coral
```css
.sol-coral{background:radial-gradient(120% 90% at 85% -10%,#E9785A 0%,transparent 60%),linear-gradient(160deg,#D8573A,#B94428);
  box-shadow:0 26px 36px -22px rgba(236,91,52,.75),inset 0 1px 0 rgba(255,255,255,.28)}
```
Light corner = the radial `#E9785A` at top-right (85% -10%); halo = coral-colored shadow `rgba(236,91,52,.75)`. Identical in light and dark themes.

### Ink
```css
.sol-tinta{background:radial-gradient(110% 80% at 85% -10%,#34312d 0%,transparent 60%),linear-gradient(160deg,#211f1c,#121110);
  box-shadow:0 26px 36px -24px rgba(0,0,0,.6),inset 0 1px 0 rgba(255,255,255,.12)}
```

### Dark-theme inversion of ink (ink becomes a light panel, text turns dark)
```css
:root[data-tema="oscuro"] .sol-tinta{background:radial-gradient(110% 80% at 85% -10%,#fff 0%,transparent 60%),linear-gradient(160deg,#ece9e3,#d9d5ce);color:#151412}
:root[data-tema="oscuro"] .sol-tinta .etq,:root[data-tema="oscuro"] .sol-tinta .sub{color:rgba(21,20,18,.7)}
:root[data-tema="oscuro"] .sol-tinta .num,:root[data-tema="oscuro"] .sol-tinta .num small{color:#151412}
:root[data-tema="oscuro"] .sol-tinta .btn{background:#151412;color:#fff}
:root[data-tema="oscuro"] .sol-tinta .ico{background:rgba(21,20,18,.12);color:#151412}
:root[data-tema="oscuro"] .sol-tinta .chipw{background:rgba(21,20,18,.1)}
```

### Text, badge, chip and button colors inside solid panels
```css
.sol .etq,.sol .sub{color:rgba(255,255,255,.82)}
.sol .num,.sol .num small{color:#fff}
.sol .num small{opacity:.8}
.sol .btn{background:#fff;color:#151412}
.sol .btn.sec{background:rgba(255,255,255,.18);color:#fff;border:0}
.sol .ico{background:rgba(255,255,255,.2);color:#fff}          /* icon badge top-right */
.chipw{display:inline-flex;align-items:center;gap:6px;margin-top:14px;padding:6px 13px;border-radius:99px;font-size:12.5px;font-weight:600;background:rgba(255,255,255,.2)}  /* translucent chip */
.sol:focus-visible,.btn.coral:focus-visible{outline-color:var(--tinta)}
```
Mobile: `@media(max-width:560px){.sol.c-3{grid-column:span 12}}`.

### Markup
```html
<!-- clickable panel (whole panel is a button) -->
<button class="card sol sol-coral c-3" aria-label="Requiere acción: ver detalle">
  <span class="ico" data-ic="alert"></span>
  <div class="etq">Requiere acción</div>
  <div class="num">1</div>
  <div class="sub">Backup nocturno falló a las 03:10</div>
  <span class="chipw"><span data-ic="clock"></span> ver detalle</span>
</button>
<!-- panel with its own action: use <section>, style="cursor:default" and a .btn inside -->
<section class="card sol sol-coral c-4" style="cursor:default">
  <span class="ico" data-ic="bolt"></span><div class="etq">Pago pendiente</div>
  <div class="num">84<small>,20 €</small></div><div class="sub">Recibo de la luz · vence mañana</div>
  <div class="btns" style="margin-top:14px"><button class="btn">Pagar ahora</button></div>
</section>
```
Solid panels keep the same anatomy as glass cards (etq / num / sub), numbers still sans semi-bold.

## 5. Containers have no hover
Cards, solid panels, table rows, list rows (`.fila`), sheets: **no** `:hover` styles (no lift, no color change, no shadow change). They may have `cursor:pointer` and `:active`/`:focus-visible` feedback when clickable, and an enter animation (`ent`, see `glass-motion`). Only buttons and controls (`.btn`, chips-as-buttons, round buttons, segmented, toggles, nav items, checkboxes) get hover, and always wrapped in `@media(hover:hover){...}`. The demo's `.tabla tbody tr` has only `cursor:pointer;transition:background .2s` and no hover rule; keep it that way.

## Do / Don't
Do:
- Use `.vidrio` for every surface; `--interior` for sub-blocks inside it.
- Keep numbers semi-bold sans with tabular figures and a small unit.
- Use solid panels for at most 2 important/actionable items per screen, coral or ink only.
- Re-check dark theme: ink inverts to light, grain switches to `screen`.
- Provide the `@supports not` fallback with denser fills.

Don't:
- No color blobs, color gradients, shapes or images behind the glass.
- No green or amber solid panels (nor any other color), no solid third panel.
- No serif for numbers or percentages (Instrument Serif is only for page/sheet titles).
- No hover on cards, panels, rows or any container.
- No emojis; icons are inline line SVG (stroke 1.6, round caps).
- Don't skip the inner top reflection or the border: they are what makes it glass.

## Related skills
glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion
