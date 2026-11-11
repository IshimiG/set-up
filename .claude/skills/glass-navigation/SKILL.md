---
name: glass-navigation
description: Page structure and navigation of the approved warm liquid-glass design system (cream #EEECE8 / coral #EC5B34, light and dark themes). Covers the app shell and page layout (main max-width 1080px, padding, header with serif page title, subtitle and round glass header buttons), the 12-column grid with c-3/c-4/c-5/c-6/c-7/c-8/c-12 span classes and its responsive collapse, the floating bottom glass pill nav with the stretching pastille (exact CSS plus the JS that measures the active button and animates left/width), the mobile icon-over-label variant, active state via aria-current, view switching with exit/enter transitions and staggered card entrance, the theme toggle button and its JS (data-tema, localStorage), the header button that opens the components sheet, keyboard/aria/focus rules, and a minimal full-page skeleton with shell, nav and two views. Trigger when the user asks to design, build or restyle a UI, panel, dashboard, page, app shell, tab bar, bottom navigation or multi-view layout in "our glass style / liquid glass / panel style". Part of the glass-design family; the hub skill is glass-design.
---

# glass-navigation

Purpose: everything about how a glass page is laid out and how the user moves between views. Tokens (colors, radii, easing), the glass surface recipe, controls, sheets and charts live in sibling skills; this one assumes `:root` tokens from **glass-tokens** and the `.vidrio` class from **glass-surfaces** are already present (the skeleton at the end is self-contained with a minimal subset).

Tokens used here (from glass-tokens): `--muelle:cubic-bezier(.34,1.45,.4,1)` (spring), `--cierra:cubic-bezier(.55,-.3,.45,1)` (anticipation close), `--r-l:40px`, `--r-s:16px`, `--pill` (active pastille fill: `rgba(255,255,255,.95)` light / `rgba(255,255,255,.15)` dark), `--reflejo`, `--interior` (`rgba(28,24,20,.05)` light / `rgba(255,255,255,.07)` dark), `--interior-2`, `--tinta`, `--tinta-2`, `--tinta-3`, `--coral`, `--serif`.

## 1. App shell and page layout

```
<body>
  .capa.luz      fixed background light (no blobs)
  .capa.grano    fixed grain
  <main>         max-width 1080px, centered
    header.top   serif title + subtitle (left), round glass buttons (right)
    .vista x N   one per view; only one visible
  <nav.flota.vidrio>   floating bottom pill
  (velo, sheets, menu, toasts: see glass-overlays)
```

| Element | Exact rule |
|---|---|
| `main` | `max-width:1080px;margin:0 auto;padding:28px 20px 140px` (140px bottom clears the floating nav). At `max-width:560px`: `padding:20px 16px 140px` |
| `header.top` | `display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin:18px 4px 28px` |
| `h1` | `font-family:var(--serif);font-weight:400;font-size:clamp(40px,6vw,64px);letter-spacing:-.02em;line-height:1` (serif is allowed here: it is the highlighted page title) |
| `.sub` | `color:var(--tinta-2);font-size:14px;margin-top:8px` |
| `.acc` | `display:flex;gap:10px` holds header buttons |
| `.rbtn` | 48x48 circle, `border-radius:50%`, `display:grid;place-items:center`, `font-size:20px`, `transition:transform .5s var(--muelle)`, always combined with `.vidrio` |
| `.rbtn:active` | `transform:scale(.86)` |
| `.rbtn:hover` | only inside `@media(hover:hover)`: `transform:scale(1.08);background:var(--interior-2)` |
| Title change | wrapper `.tt-wrap` gets class `cambia`: `animation:tit .7s var(--muelle)`; `@keyframes tit{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}` |

Page title rules: one serif `h1` per view, short ("Servidor", "Finanzas", a greeting on home). Subtitle is sans, one line of context (date, host, hint). Never put numbers in the serif title.

Background layers (decorative, `pointer-events:none`):

```css
html{background:var(--fondo);transition:background .5s}
.capa{position:fixed;inset:0;z-index:-1;pointer-events:none}
.luz{background:radial-gradient(70vw 40vw at 50% -8%,var(--luz),transparent 70%)}
/* .grano: see glass-tokens / glass-surfaces for the SVG noise data URI */
```

## 2. 12-column grid

```css
.rejilla{display:grid;grid-template-columns:repeat(12,1fr);gap:16px}
.card{padding:24px;transition:transform .5s var(--muelle);min-width:0}
.c-3{grid-column:span 3}.c-4{grid-column:span 4}.c-5{grid-column:span 5}.c-6{grid-column:span 6}
.c-7{grid-column:span 7}.c-8{grid-column:span 8}.c-12{grid-column:span 12}
@media(max-width:900px){.c-3{grid-column:span 6}}
@media(max-width:760px){.c-4,.c-5,.c-6,.c-7,.c-8{grid-column:span 12}}
@media(max-width:560px){.sol.c-3{grid-column:span 12}.card{padding:20px}.rejilla{gap:12px}main{padding:20px 16px 140px}}
```

- Always put `min-width:0` on cards so tables/charts do not blow the grid.
- Typical compositions: 4x`c-3` (KPI row), `c-8`+`c-4`, 3x`c-4`, then a full-width `c-12`.
- Collapse order: `c-3` -> 2 per row at <=900px; everything else full width at <=760px; solid `c-3` panels full width at <=560px.
- Cards are glass (`.card.vidrio`), padding 24px, radius 40px (`--r-l`). Cards and rows have NO hover/transform on hover.

## 3. Floating bottom glass nav (pill + stretching pastille)

HTML (inside `<body>`, outside `<main>`):

```html
<nav class="flota vidrio" id="nav" aria-label="Main navigation">
  <span class="pastilla" id="pastilla"></span>
  <button data-v="inicio" aria-current="page"><span data-ic="home"></span><span>Home</span></button>
  <button data-v="servidor"><span data-ic="server"></span><span>Server</span></button>
  <!-- ...2-5 destinations total -->
</nav>
```

CSS (exact):

```css
nav.flota{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);display:flex;gap:4px;padding:7px;border-radius:99px;z-index:5;max-width:calc(100% - 24px)}
nav.flota button{font-weight:600;font-size:14px;color:var(--tinta-2);background:none;border:0;padding:11px 20px;border-radius:99px;cursor:pointer;position:relative;z-index:1;
  transition:color .3s;display:flex;align-items:center;gap:8px}
nav.flota button .i{font-size:18px}
nav.flota button[aria-current=page]{color:var(--tinta)}
nav .pastilla{position:absolute;top:7px;bottom:7px;left:0;border-radius:99px;background:var(--pill);
  box-shadow:inset 0 1px 0 var(--reflejo),0 4px 14px -6px rgba(0,0,0,.3);
  transition:left .6s var(--muelle),width .6s var(--muelle)}
@media(max-width:560px){nav.flota button{flex-direction:column;gap:3px;font-size:11.5px;padding:9px 14px;min-width:64px}}
@media(hover:hover){nav.flota button:not([aria-current=page]):hover{color:var(--tinta);background:var(--interior)}}
```

Rules:
- `nav.flota` uses the `.vidrio` surface (blur 26px, saturate 1.6, border `--borde`) with `border-radius:99px` overriding the 40px default; `.flota` comes after `.vidrio` in the cascade (or use equal specificity order) so the pill radius wins.
- The pastille is a sibling `<span>` positioned absolutely; buttons sit above it with `z-index:1`. It is not a gradient; it is the `--pill` fill plus an inner top highlight.
- Active = `aria-current="page"` (never a class). Inactive buttons are `--tinta-2`; active is `--tinta`.
- Spring on both `left` and `width` makes the pastille overshoot and stretch; that is the signature, keep `.6s var(--muelle)`.
- Mobile (<=560px): icon over label, 11.5px, `min-width:64px`. Keep at most 5 destinations so the pill fits within `calc(100% - 24px)`.
- The pill never has a container hover; only the inactive buttons do.

JS that measures and animates (call on load, on font load, on resize, and on every view change):

```js
const nav=document.querySelector('#nav'),past=document.querySelector('#pastilla');
const moverPast=()=>{const b=nav.querySelector('[aria-current=page]');
  past.style.left=b.offsetLeft+'px';past.style.width=b.offsetWidth+'px'};
addEventListener('load',moverPast);
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(moverPast);   // label widths change when fonts load
let rz;addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(moverPast,120)}); // mobile layout changes widths
```

Note: `offsetLeft` is relative to the nav (positioned ancestor), which is exactly the pastille's containing block. Do not use `getBoundingClientRect` minus nav rect unless you subtract the border.

## 4. View switching

Each view is a `<div class="vista" id="v-NAME">`; inactive ones have the `hidden` attribute. Mechanism: old view gets `.sale` (fast out, 170ms) -> after 170ms it is hidden, the new view is un-hidden and gets `.entra` (cards enter with spring, staggered 45ms by `--i`), title block animates, pastille slides.

```css
.vista.entra .card,.vista.entra .rejilla>*{animation:ent .75s var(--muelle) backwards;animation-delay:calc(var(--i,0)*45ms)}
@keyframes ent{from{opacity:0;transform:translateY(30px) scale(.96)}to{opacity:1;transform:none}}
.vista.sale{opacity:0;transform:translateY(-10px) scale(.985);transition:opacity .18s,transform .18s var(--cierra)}
```

```js
const $=(s,e=document)=>e.querySelector(s),$$=(s,e=document)=>[...e.querySelectorAll(s)];
let actual='inicio',cambio=0;
const TITULOS={inicio:['Good morning','Tuesday, 11 November'],servidor:['Server','nuc-home · 41 days up']};

function cabecera(v){
  const T=TITULOS[v];$('#titulo').textContent=T[0];$('#subtitulo').textContent=T[1];
  const w=$('#tt-wrap');w.classList.remove('cambia');void w.offsetWidth;w.classList.add('cambia'); // restart animation
  document.title='App · '+T[0];
}
function muestra(v){
  const vista=$('#v-'+v);vista.hidden=false;
  $$('.rejilla>*',vista).forEach((c,i)=>c.style.setProperty('--i',i));   // stagger index
  vista.classList.add('entra');setTimeout(()=>vista.classList.remove('entra'),1100);
  // per-view init here (charts, bars: data-w -> width, lazy loading skeletons...)
}
function ir(v){
  if(v===actual)return;
  const id=++cambio;                       // guards against rapid clicks
  // close any open menu/sheet first (see glass-overlays): cierraMenu();cierraHoja(true);
  $$('button',nav).forEach(b=>{b.dataset.v===v?b.setAttribute('aria-current','page'):b.removeAttribute('aria-current')});
  moverPast();cabecera(v);
  const vieja=$('#v-'+actual);vieja.classList.add('sale');actual=v;
  setTimeout(()=>{
    if(id!==cambio)return;                 // a newer navigation superseded this one
    vieja.hidden=true;vieja.classList.remove('sale');
    $$('.vista').forEach(x=>{if(x.id!=='v-'+v)x.hidden=true});
    muestra(v);scrollTo({top:0,behavior:'smooth'});
  },170);
}
$$('button',nav).forEach(b=>b.onclick=()=>ir(b.dataset.v));
// Any element can navigate: <button data-go="tareas"> (delegated click handler)
document.addEventListener('click',e=>{const g=e.target.closest('[data-go]');if(g)ir(g.dataset.go)});
```

Initial view on load: set `--i` on its children and add `.entra` once (same as `muestra` without un-hiding), then `cabecera('inicio')`.

Slow data (e.g. a finance view): show a glass skeleton grid with `aria-busy="true"` inside the view, then swap it for the real grid (`hidden` toggle) when loaded (skeleton styles: glass-data).

## 5. Theme toggle

Header button (round glass) with a half-filled circle icon (`tema` path `M12 3a9 9 0 100 18 9 9 0 000-18zM12 3v18M12 3a9 9 0 010 18`):

```html
<button class="rbtn vidrio" id="tema" aria-label="Toggle light or dark theme" title="Toggle theme"><span data-ic="tema"></span></button>
```

```js
const R=document.documentElement;
try{const t=localStorage.getItem('app-tema');if(t)R.dataset.tema=t}catch(e){}   // run as early as possible (inline in <head> to avoid a flash)
$('#tema').onclick=()=>{
  const n=R.dataset.tema==='claro'?'oscuro':'claro';
  R.dataset.tema=n;
  try{localStorage.setItem('app-tema',n)}catch(e){}
};
```

- Themes are `:root[data-tema="claro"]` and `:root[data-tema="oscuro"]` (set `data-tema="claro"` on `<html>` by default; `color-scheme` is set per theme in tokens). Optionally default from `matchMedia('(prefers-color-scheme: dark)')` when nothing is stored.
- `html{transition:background .5s}` gives the soft cross-fade of the background; surfaces follow through their tokens.
- Always wrap localStorage in try/catch. If a palette/swatch view shows token values, re-render it after toggling.

## 6. Components-sheet header button

Second round header button, grid icon (`grid` path `M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z`), opens the "Components" design-system sheet (sheet markup/behaviour in glass-overlays):

```html
<div class="acc">
  <button class="rbtn vidrio" id="b-comp" aria-label="Open components" title="Components"><span data-ic="grid"></span></button>
  <button class="rbtn vidrio" id="tema" aria-label="Toggle light or dark theme" title="Toggle theme"><span data-ic="tema"></span></button>
</div>
```
```js
$('#b-comp').onclick=()=>abreHoja('h-comp');   // abreHoja from glass-overlays
```
Order: contextual button(s) first, theme toggle last. Header buttons stay at most 3; icon only, always with `aria-label` and `title`.

## 7. Keyboard, aria, focus

- Nav is a `<nav aria-label="...">` of real `<button>`s; active one has `aria-current="page"` (exactly one). Tab order follows visual order; Enter/Space activate natively.
- Header icon buttons: `aria-label` + `title`; the inline SVG icon is `aria-hidden="true"`.
- Focus ring: `:focus-visible{outline:2px solid var(--coral);outline-offset:3px}`; on solid coral/ink surfaces use `outline-color:var(--tinta)`.
- Hidden views use the `hidden` attribute (removes them from the a11y tree and tab order). Sheets use `inert` when closed.
- Anything that opens (menu, sheet) closes on outside click and Esc; navigating also closes it (call the close functions at the start of `ir`).
- Skeleton regions: `aria-busy="true"` plus `aria-label`.
- Respect reduced motion:
```css
@media (prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;transition-delay:0s!important}}
```
- Hover only inside `@media(hover:hover)`; buttons/controls have hover, cards/rows/containers do not.

## 8. Minimal full-page skeleton (shell + nav + two views)

```html
<!doctype html>
<html lang="en" data-tema="claro">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>App · Home</title>
<script>try{var t=localStorage.getItem('app-tema');if(t)document.documentElement.dataset.tema=t}catch(e){}</script>
<style>
:root{--coral:#EC5B34;--sans:"Inter","Adwaita Sans","SF Pro Text",system-ui,sans-serif;--serif:"Instrument Serif","Noto Serif Display",Georgia,serif;
  --r-l:40px;--muelle:cubic-bezier(.34,1.45,.4,1);--cierra:cubic-bezier(.55,-.3,.45,1)}
:root[data-tema="claro"]{color-scheme:light;--fondo:#EEECE8;--luz:rgba(255,255,255,.85);--tinta:#151412;--tinta-2:#55514b;--tinta-3:#6f6a62;
  --vidrio:rgba(255,255,255,.52);--pill:rgba(255,255,255,.95);--borde:rgba(255,255,255,.85);--reflejo:rgba(255,255,255,.9);
  --sombra:0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22);--interior:rgba(28,24,20,.05);--interior-2:rgba(28,24,20,.09)}
:root[data-tema="oscuro"]{color-scheme:dark;--fondo:#121210;--luz:rgba(255,255,255,.07);--tinta:#f4f2ee;--tinta-2:rgba(244,242,238,.74);--tinta-3:rgba(244,242,238,.6);
  --vidrio:rgba(34,32,30,.42);--pill:rgba(255,255,255,.15);--borde:rgba(255,255,255,.18);--reflejo:rgba(255,255,255,.3);
  --sombra:0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18);--interior:rgba(255,255,255,.07);--interior-2:rgba(255,255,255,.12)}
*{box-sizing:border-box;margin:0}
html{background:var(--fondo);transition:background .5s}
body{font-family:var(--sans);color:var(--tinta);min-height:100vh;overflow-x:hidden;-webkit-font-smoothing:antialiased}
button{font:inherit;color:inherit}
:focus-visible{outline:2px solid var(--coral);outline-offset:3px}
.capa{position:fixed;inset:0;z-index:-1;pointer-events:none}
.luz{background:radial-gradient(70vw 40vw at 50% -8%,var(--luz),transparent 70%)}
/* add .grano layer from glass-tokens */
.vidrio{background:var(--vidrio);-webkit-backdrop-filter:blur(26px) saturate(1.6);backdrop-filter:blur(26px) saturate(1.6);
  border:1px solid var(--borde);box-shadow:var(--sombra),inset 0 1px 0 var(--reflejo);border-radius:var(--r-l)}
svg.i{width:1em;height:1em;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}

main{max-width:1080px;margin:0 auto;padding:28px 20px 140px}
header.top{display:flex;justify-content:space-between;align-items:flex-end;gap:16px;margin:18px 4px 28px}
h1{font-family:var(--serif);font-weight:400;font-size:clamp(40px,6vw,64px);letter-spacing:-.02em;line-height:1}
.tt-wrap.cambia{animation:tit .7s var(--muelle)}
@keyframes tit{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
.sub{color:var(--tinta-2);font-size:14px;margin-top:8px}
.acc{display:flex;gap:10px}
.rbtn{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;cursor:pointer;font-size:20px;color:var(--tinta);transition:transform .5s var(--muelle);padding:0}
.rbtn:active{transform:scale(.86)}
.rejilla{display:grid;grid-template-columns:repeat(12,1fr);gap:16px}
.card{padding:24px;min-width:0}
.c-4{grid-column:span 4}.c-8{grid-column:span 8}.c-12{grid-column:span 12}
@media(max-width:760px){.c-4,.c-8{grid-column:span 12}}
@media(max-width:560px){.card{padding:20px}.rejilla{gap:12px}main{padding:20px 16px 140px}}
.vista.entra .rejilla>*{animation:ent .75s var(--muelle) backwards;animation-delay:calc(var(--i,0)*45ms)}
@keyframes ent{from{opacity:0;transform:translateY(30px) scale(.96)}to{opacity:1;transform:none}}
.vista.sale{opacity:0;transform:translateY(-10px) scale(.985);transition:opacity .18s,transform .18s var(--cierra)}
.etq{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--tinta-3);font-weight:600}
.num{font-weight:600;font-size:46px;line-height:1;margin:12px 0 6px;letter-spacing:-.03em;font-variant-numeric:tabular-nums}
.num small{font-size:20px;font-weight:500;color:var(--tinta-2);letter-spacing:0;margin-left:3px}

nav.flota{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);display:flex;gap:4px;padding:7px;border-radius:99px;z-index:5;max-width:calc(100% - 24px)}
nav.flota button{font-weight:600;font-size:14px;color:var(--tinta-2);background:none;border:0;padding:11px 20px;border-radius:99px;cursor:pointer;position:relative;z-index:1;transition:color .3s;display:flex;align-items:center;gap:8px}
nav.flota button .i{font-size:18px}
nav.flota button[aria-current=page]{color:var(--tinta)}
nav .pastilla{position:absolute;top:7px;bottom:7px;left:0;border-radius:99px;background:var(--pill);box-shadow:inset 0 1px 0 var(--reflejo),0 4px 14px -6px rgba(0,0,0,.3);transition:left .6s var(--muelle),width .6s var(--muelle)}
@media(max-width:560px){nav.flota button{flex-direction:column;gap:3px;font-size:11.5px;padding:9px 14px;min-width:64px}}
@media(hover:hover){
  .rbtn:hover{transform:scale(1.08);background:var(--interior-2)}
  nav.flota button:not([aria-current=page]):hover{color:var(--tinta);background:var(--interior)}
}
@media (prefers-reduced-motion:reduce){*,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;transition-delay:0s!important}}
</style>
</head>
<body>
<div class="capa luz"></div>
<main>
  <header class="top">
    <div class="tt-wrap" id="tt-wrap"><h1 id="titulo">Home</h1><p class="sub" id="subtitulo"></p></div>
    <div class="acc">
      <button class="rbtn vidrio" id="tema" aria-label="Toggle light or dark theme" title="Toggle theme"><span data-ic="tema"></span></button>
    </div>
  </header>

  <div class="vista" id="v-inicio">
    <div class="rejilla">
      <section class="card vidrio c-4"><div class="etq">Balance</div><div class="num">12.480<small>,35 EUR</small></div></section>
      <section class="card vidrio c-8"><div class="etq">Activity</div></section>
    </div>
  </div>
  <div class="vista" id="v-servidor" hidden>
    <div class="rejilla">
      <section class="card vidrio c-12"><div class="etq">Containers</div></section>
    </div>
  </div>
</main>

<nav class="flota vidrio" id="nav" aria-label="Main navigation">
  <span class="pastilla" id="pastilla"></span>
  <button data-v="inicio" aria-current="page"><span data-ic="home"></span><span>Home</span></button>
  <button data-v="servidor"><span data-ic="server"></span><span>Server</span></button>
</nav>

<script>
const $=(s,e=document)=>e.querySelector(s),$$=(s,e=document)=>[...e.querySelectorAll(s)];
const IC={home:'M3 11l9-7 9 7M5 10v10h14V10M10 20v-6h4v6',server:'M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01',tema:'M12 3a9 9 0 100 18 9 9 0 000-18zM12 3v18M12 3a9 9 0 010 18'};
const ic=n=>`<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="${IC[n]}"/></svg>`;
$$('[data-ic]').forEach(e=>{if(!e.firstChild)e.innerHTML=ic(e.dataset.ic)});

const R=document.documentElement;
$('#tema').onclick=()=>{const n=R.dataset.tema==='claro'?'oscuro':'claro';R.dataset.tema=n;try{localStorage.setItem('app-tema',n)}catch(e){}};

const T={inicio:['Hello','Tuesday, 11 November'],servidor:['Server','nuc-home · 41 days up']};
const nav=$('#nav'),past=$('#pastilla');let actual='inicio',cambio=0;
const moverPast=()=>{const b=$('[aria-current=page]',nav);past.style.left=b.offsetLeft+'px';past.style.width=b.offsetWidth+'px'};
function cabecera(v){$('#titulo').textContent=T[v][0];$('#subtitulo').textContent=T[v][1];
  const w=$('#tt-wrap');w.classList.remove('cambia');void w.offsetWidth;w.classList.add('cambia');document.title='App · '+T[v][0]}
function muestra(v){const vista=$('#v-'+v);vista.hidden=false;
  $$('.rejilla>*',vista).forEach((c,i)=>c.style.setProperty('--i',i));
  vista.classList.add('entra');setTimeout(()=>vista.classList.remove('entra'),1100)}
function ir(v){
  if(v===actual)return;const id=++cambio;
  $$('button',nav).forEach(b=>b.dataset.v===v?b.setAttribute('aria-current','page'):b.removeAttribute('aria-current'));
  moverPast();cabecera(v);
  const vieja=$('#v-'+actual);vieja.classList.add('sale');actual=v;
  setTimeout(()=>{if(id!==cambio)return;vieja.hidden=true;vieja.classList.remove('sale');
    $$('.vista').forEach(x=>{if(x.id!=='v-'+v)x.hidden=true});muestra(v);scrollTo({top:0,behavior:'smooth'})},170);
}
$$('button',nav).forEach(b=>b.onclick=()=>ir(b.dataset.v));
document.addEventListener('click',e=>{const g=e.target.closest('[data-go]');if(g)ir(g.dataset.go)});

cabecera('inicio');
(()=>{const v=$('#v-inicio');$$('.rejilla>*',v).forEach((c,i)=>c.style.setProperty('--i',i));v.classList.add('entra');setTimeout(()=>v.classList.remove('entra'),1100)})();
addEventListener('load',moverPast);
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(moverPast);
let rz;addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(moverPast,120)});
</script>
</body>
</html>
```

## 9. Do / Don't

Do:
- One floating pill nav, centered, `bottom:22px`, with the spring pastille; 2 to 5 destinations; icon + label.
- Keep `main` bottom padding at 140px so content never hides behind the nav.
- Serif only on the page `h1` (and sheet `h2`); everything else sans; numbers semi-bold sans with tabular figures.
- Stagger card entrance by `--i` x 45ms; exit 170ms; spring both ways.
- Recompute the pastille on load, font load and resize.
- Close open overlays when navigating; guard rapid navigation with the `cambio` counter.

Don't:
- Don't use a top navbar, sidebar, or opaque tab bar; don't use emojis; don't use a class for active state instead of `aria-current`.
- Don't add hover to cards, panels or table rows; don't apply hover outside `@media(hover:hover)`.
- Don't animate the pastille with `transform` from JS-less guesses (hard-coded widths); always measure.
- Don't use `display:none` styling instead of the `hidden` attribute for inactive views.
- Don't add blobs, color gradients or shapes to the background; only grain plus the soft top `.luz`.
- Don't put more than 2 solid (coral/ink) panels on a screen.

## Related skills

glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion.
