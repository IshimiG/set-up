---
name: glass-motion
description: Motion and iconography rules of the approved glass design system (warm cream/coral liquid-glass UI, light and dark themes). Covers the two spring easings (--muelle open/overshoot, --cierra close/anticipation) with exact cubic-bezier values, which easing and duration to use for press, hover lift, toggle thumb, segmented/nav pill stretch, sheet open/close, context menu, toast, view transition, staggered entrance, chart draw-in, checkbox stroke draw, progress bars, input shake and skeleton shimmer; the symmetric open-and-close rule; drag-to-dismiss inertia math; prefers-reduced-motion CSS; and the inline SVG icon system (JS icon map with every id and path, stroke 1.6, round caps/joins, svg.i sizing, icon badge .ib, how to add a new icon, focus-visible rings and aria-labels for icon-only buttons). Use whenever the user asks to design, build or restyle a UI, panel, dashboard, page or component in "our glass style / liquid glass / panel style" and animation, transitions, springs, hover or press feedback, or icons are involved. Part of the glass-design family; the hub skill is glass-design.
---

# glass-motion — spring animation and icons

Source of truth: `~/.claude/skills/glass-design/reference/demo-complete.html`. Values below are copied from it. Write all deliverables in English (rename the demo's Spanish identifiers `muelle`/`cierra` if you like, but keep the values; this file calls them `--spring` / `--close` in prose and keeps the demo's variable names in code so snippets stay copy-pasteable).

## 1. Principles

- Everything animates elastically in BOTH directions: opening overshoots, closing anticipates (dips back before leaving). Never a plain `ease`/`linear` for movement.
- Two easings only, defined once on `:root`. Opacity/colour use short plain durations (no easing function needed).
- Buttons and controls have hover and press; containers (cards, panels, table rows) do NOT get hover lift.
- All hover rules are wrapped in `@media(hover:hover)`.
- Anything that opens must close on outside click AND Esc, with the symmetric close animation (see 4).
- Honour `prefers-reduced-motion` (see 7).

## 2. Easing tokens (exact)

```css
:root{
  --muelle:cubic-bezier(.34,1.45,.4,1);   /* spring: opens, enters, overshoots */
  --cierra:cubic-bezier(.55,-.3,.45,1);   /* anticipation: closes, exits */
}
```

## 3. Which easing/duration for which interaction

| Interaction | Property | Duration | Easing | Notes |
|---|---|---|---|---|
| Button press | `transform:scale(.93)` on `:active` | .45s (base transition) | `--muelle` | `.btn` transition: `transform .45s var(--muelle),opacity .2s,background-color .25s,box-shadow .3s,filter .25s` |
| Round icon button (`.rbtn`) | transform | .5s | `--muelle` | `:active scale(.86)`, hover `scale(1.08)` |
| Small icon button (`.mas`) | transform | .4s | `--muelle` | `:active scale(.85)` |
| Button hover lift | `translateY(-2px)` + `filter:brightness(1.1)` + shadow `0 10px 22px -10px rgba(0,0,0,.45)` | .45s | `--muelle` | coral variant: brightness 1.08, shadow `0 12px 26px -10px rgba(236,91,52,.8)` |
| Chip button hover | `translateY(-1px)`, bg `--interior-2` | .45s | `--muelle` | only `button.chip` / `a.chip` |
| Toggle thumb | `transform .55s var(--muelle),width .3s` | .55s | `--muelle` | track `background .3s`; thumb stretches to 30px on `:active` |
| Segmented pill / nav pill | `left`+`width` | .55s seg / .6s nav | `--muelle` | pill slides and overshoots (stretch effect) |
| Segmented/nav label colour | color | .3s | default | |
| Checkbox box | `background .3s,border-color .3s,transform .5s var(--muelle)` | .5s | `--muelle` | checked `scale(1.08)`, `:active scale(.82)`, hover `scale(1.1)` |
| Checkbox tick draw | `stroke-dashoffset` | .45s, delay .05s | `--muelle` | `pathLength="1"`, dasharray 1 |
| Sheet open | `transform` | .8s | `--muelle` | from `translate(-50%,108%)` |
| Sheet close | `transform` | .55s | `--cierra` | set on the base rule, so it applies when `.on` is removed |
| Sheet scrim (`.velo`) | opacity | .4s | default | |
| Context menu open | `transform .55s var(--muelle),opacity .18s` | .55s | `--muelle` | from `scale(.8)`, origin at trigger (`--ox`,`--oy`) |
| Context menu close | `transform .3s var(--cierra),opacity .18s,visibility 0s .3s` | .3s | `--cierra` | visibility delayed so exit is visible |
| Toast in | `transform .6s var(--muelle),opacity .25s` | .6s | `--muelle` | from `translateY(28px) scale(.85)` |
| Toast out | `transform .35s var(--cierra),opacity .25s` | .35s | `--cierra` | to `translateY(20px) scale(.9)`; removed after 400ms; auto-dismiss 3400ms |
| Tooltip | `opacity .15s,transform .35s var(--muelle)` | .35s | `--muelle` | from `translateY(6px) scale(.92)` |
| View exit | `opacity .18s,transform .18s var(--cierra)` | .18s | `--cierra` | to `translateY(-10px) scale(.985)` |
| View enter (cards) | `ent` keyframes | .75s | `--muelle` | stagger `calc(var(--i,0)*45ms)` |
| Page title change | `tit` keyframes | .7s | `--muelle` | |
| Progress bar | `width` | 1.1s | `--muelle` | width reset to 0 then set after 60ms |
| Line chart draw-in | `trazo` keyframes | 1.2s | `--muelle` | `pathLength="1"` |
| Bar chart grow | `crece` keyframes | .9s | `--muelle` | stagger `calc(var(--i)*70ms)` |
| Donut entrance | `gira` keyframes | .9s | `--muelle` | |
| Donut segment hover | `stroke-width .35s var(--muelle),opacity .3s` | .35s | `--muelle` | 22 -> 28 |
| Input error | `sacude` keyframes | .45s | linear default | |
| Skeleton shimmer | `brilla` | 1.4s infinite | default | |
| Theme switch | `html{transition:background .5s}` | .5s | default | |
| New list item | `ent` | .7s | `--muelle` | `.tarea.nueva` |
| Row/tab text fades | opacity/color | .2-.3s | default | |

Rule of thumb: movement that arrives = `--muelle` (.35-.8s); movement that leaves = `--cierra` (.18-.55s, always shorter than the open); opacity = .15-.4s without a curve.

## 4. Symmetric open AND close

Put the CLOSE transition on the base (closed) state and the OPEN transition on the `.on` state. Removing the class then plays the close curve automatically.

```css
/* sheet */
.velo{position:fixed;inset:0;background:var(--velo);opacity:0;pointer-events:none;transition:opacity .4s;z-index:8}
.hoja{position:fixed;left:50%;bottom:0;width:min(580px,100%);max-height:92vh;overflow:auto;padding:12px 28px 40px;z-index:9;
  background:var(--vidrio-hoja);border-radius:var(--r-xl) var(--r-xl) 0 0;
  transform:translate(-50%,108%);transition:transform .55s var(--cierra);overscroll-behavior:contain}
.hoja.on{transform:translate(-50%,0);transition:transform .8s var(--muelle)}
body.abierta .velo{opacity:1;pointer-events:auto}

/* context menu */
.menu{opacity:0;visibility:hidden;transform:scale(.8);transform-origin:var(--ox,100%) var(--oy,0);
  transition:transform .3s var(--cierra),opacity .18s,visibility 0s .3s}
.menu.on{opacity:1;visibility:visible;transform:none;transition:transform .55s var(--muelle),opacity .18s,visibility 0s}

/* toast: .toast (closed) -> .in (open) -> .out (leaving, own curve) */
.toast{opacity:0;transform:translateY(28px) scale(.85);transition:transform .6s var(--muelle),opacity .25s}
.toast.in{opacity:1;transform:none}
.toast.out{opacity:0;transform:translateY(20px) scale(.9);transition:transform .35s var(--cierra),opacity .25s}
```

Outside-click + Esc (menu example; sheets use the scrim `onclick=cierraHoja`):

```js
document.addEventListener('pointerdown',e=>{
  if(menu.classList.contains('on')&&!menu.contains(e.target)){
    const t=e.target.closest('[data-menu]');ultimoCierre=(t&&t===menuBtn)?t:null;cierraMenu(false)} /* avoids re-open when clicking the trigger */
  else ultimoCierre=null;
},true);
addEventListener('scroll',()=>{cierraMenu(false);ocultar()},{passive:true});
document.addEventListener('keydown',e=>{if(e.key!=='Escape')return;
  if(menu.classList.contains('on'))cierraMenu(true);else if(sheetAbierta)cierraHoja();ocultar()});
```

Also: closed sheets get `inert=true` (set `inert=false` on open), focus returns to the opener on close, `.on` is added inside `requestAnimationFrame` so the transition runs.

## 5. Keyframes (exact)

```css
@keyframes ent{from{opacity:0;transform:translateY(30px) scale(.96)}to{opacity:1;transform:none}}
@keyframes tit{from{opacity:0;transform:translateY(14px)}to{opacity:1;transform:none}}
@keyframes sacude{20%{transform:translateX(-7px)}45%{transform:translateX(6px)}70%{transform:translateX(-3px)}}
@keyframes trazo{to{stroke-dashoffset:0}}
@keyframes fund{from{opacity:0}}
@keyframes crece{from{transform:scaleY(0)}}
@keyframes gira{from{opacity:0;transform:rotate(-40deg) scale(.8)}}
@keyframes brilla{to{transform:translateX(100%)}}
```

Usage:

```css
/* staggered view entrance: set --i per child in JS, add .entra to the view, remove it after 1100ms */
.vista.entra .card,.vista.entra .rejilla>*{animation:ent .75s var(--muelle) backwards;animation-delay:calc(var(--i,0)*45ms)}
.vista.sale{opacity:0;transform:translateY(-10px) scale(.985);transition:opacity .18s,transform .18s var(--cierra)}
.tt-wrap.cambia{animation:tit .7s var(--muelle)}          /* re-trigger: remove class, void el.offsetWidth, add class */
.tarea.nueva{animation:ent .7s var(--muelle)}
.campo.mal{animation:sacude .45s}                          /* re-trigger the same way; remove on input */

/* charts */
.trazo{stroke-dasharray:1;stroke-dashoffset:1;animation:trazo 1.2s var(--muelle) forwards}   /* path needs pathLength="1" */
.g-mem.trazo{stroke-dasharray:none;animation:fund 1s .3s backwards}
.g-area{animation:fund 1s .2s backwards}
.barg rect{transform-box:fill-box;transform-origin:bottom;animation:crece .9s var(--muelle) backwards;animation-delay:calc(var(--i)*70ms)}
.donut-w svg{animation:gira .9s var(--muelle) backwards}
.seg-d{fill:none;stroke-width:22;transition:stroke-width .35s var(--muelle),opacity .3s;cursor:pointer}
.seg-d:hover{stroke-width:28}

/* glass skeleton shimmer */
.sk{position:relative;overflow:hidden;border-radius:var(--r-s);background:var(--interior);height:14px}
.sk::after{content:"";position:absolute;inset:0;transform:translateX(-100%);background:linear-gradient(90deg,transparent,var(--reflejo),transparent);opacity:.55;animation:brilla 1.4s infinite}
:root[data-tema="oscuro"] .sk::after{opacity:.16}
```

(The shimmer gradient is the one allowed gradient exception: it is a highlight sweep, not a colour fill.)

## 6. Component motion snippets

```css
/* button: press + hover lift */
.btn{transition:transform .45s var(--muelle),opacity .2s,background-color .25s,box-shadow .3s,filter .25s}
.btn:active{transform:scale(.93)}
.btn:disabled{opacity:.4;cursor:not-allowed;transform:none}
@media(hover:hover){
  .btn:not(:disabled):hover{transform:translateY(-2px);filter:brightness(1.1);box-shadow:0 10px 22px -10px rgba(0,0,0,.45)}
  .btn.coral:not(:disabled):hover{filter:brightness(1.08);box-shadow:0 12px 26px -10px rgba(236,91,52,.8)}
  .rbtn:hover,.ib:is(button):hover{transform:scale(1.08);background:var(--interior-2)}
  .chk:hover{border-color:var(--coral);transform:scale(1.1)}
  .togl:hover{filter:brightness(1.08)}
}
.rbtn{transition:transform .5s var(--muelle)}.rbtn:active{transform:scale(.86)}

/* toggle: thumb stretches while pressed */
.togl{position:relative;width:52px;height:32px;border-radius:99px;border:1px solid var(--linea);background:var(--interior-2);padding:0;transition:background .3s}
.togl::after{content:"";position:absolute;top:3px;left:3px;width:24px;height:24px;border-radius:50%;background:var(--pill);box-shadow:0 2px 6px rgba(0,0,0,.3);transition:transform .55s var(--muelle),width .3s}
.togl[aria-checked=true]{background:var(--coral);border-color:transparent}
.togl[aria-checked=true]::after{transform:translateX(20px);background:#fff}
.togl:active::after{width:30px}.togl[aria-checked=true]:active::after{transform:translateX(14px)}

/* stretching pill (segmented; nav uses .6s and top/bottom 7px) */
.seg .sp{position:absolute;top:5px;bottom:5px;left:0;border-radius:99px;background:var(--pill);box-shadow:inset 0 1px 0 var(--reflejo),0 4px 14px -6px rgba(0,0,0,.3);transition:left .55s var(--muelle),width .55s var(--muelle)}
```
```js
function segMove(s){const b=s.querySelector('[aria-pressed=true]'),p=s.querySelector('.sp');
  if(b&&p&&b.offsetWidth){p.style.left=b.offsetLeft+'px';p.style.width=b.offsetWidth+'px'}}
/* re-run on load, document.fonts.ready and (debounced 120ms) resize */
```
```css
/* checkbox with drawn tick */
.chk{width:30px;height:30px;border-radius:12px;border:1.6px solid var(--tinta-3);background:none;display:grid;place-items:center;padding:0;color:#fff;
  transition:background .3s,border-color .3s,transform .5s var(--muelle)}
.chk svg{width:18px;height:18px;fill:none;stroke:currentColor;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}
.chk path{stroke-dasharray:1;stroke-dashoffset:1;transition:stroke-dashoffset .45s .05s var(--muelle)}
.chk[aria-checked=true]{background:var(--coral);border-color:var(--coral);transform:scale(1.08)}
.chk[aria-checked=true] path{stroke-dashoffset:0}
.chk:active{transform:scale(.82)}
/* markup: <button class="chk" role="checkbox" aria-checked="false" aria-label="..."><svg viewBox="0 0 24 24" aria-hidden="true"><path pathLength="1" d="M5 12.5l4.5 4.5L19 7.5"/></svg></button> */
```
```js
/* progress/number: reset to 0, then set after 60ms so the spring (1.1s) plays */
function barras(r){r.querySelectorAll('.barra b[data-w]').forEach(b=>{b.style.width='0';setTimeout(()=>b.style.width=b.dataset.w+'%',60)})}
/* .barra b{width:0;transition:width 1.1s var(--muelle)} — numbers themselves are swapped with textContent; they do not tick. */
/* re-trigger a one-shot CSS animation: */
/* el.classList.remove('mal'); void el.offsetWidth; el.classList.add('mal'); */
```

Toast JS (queue max 3, spring in, anticipation out):

```js
function toast(msg,icono='check'){
  const c=$('#toasts');while(c.children.length>=3)quita(c.firstChild);
  const t=document.createElement('div');t.className='toast vidrio';
  t.innerHTML=`<span class="ib ${icono==='alert'?'coral':''}">${ic(icono)}</span><span>${esc(msg)}</span>`;
  t.onclick=()=>quita(t);c.appendChild(t);void t.offsetWidth;t.classList.add('in');
  t._t=setTimeout(()=>quita(t),3400);
}
function quita(t){if(!t||t._q)return;t._q=1;clearTimeout(t._t);t.classList.remove('in');t.classList.add('out');setTimeout(()=>t.remove(),400)}
/* container: <div class="toasts" id="toasts" role="status" aria-live="polite"></div> */
```

View transition (exit 170ms with `--cierra`, then enter with `--muelle` stagger):

```js
const vieja=$('#v-'+actual);vieja.classList.add('sale');actual=v;
setTimeout(()=>{if(id!==cambio)return;      /* ignore if a newer navigation started */
  vieja.hidden=true;vieja.classList.remove('sale');muestra(v);scrollTo({top:0,behavior:'smooth'})},170);
/* muestra(): set --i on .rejilla>* children, add .entra, remove it after 1100ms */
```

## 7. Drag-to-dismiss inertia (sheets)

Handle zone (`.asa-z`, `touch-action:none`, 30px tall, `cursor:grab`) with a 44x5px grabber (`.asa`). While dragging, disable the transition; on release, either close (close curve plays from the current offset) or snap back (spring plays).

```js
$$('[data-asa]').forEach(z=>{
  let y0,t0,dy=0,h,act=false;
  z.addEventListener('pointerdown',e=>{h=z.closest('.hoja');y0=e.clientY;t0=performance.now();act=true;dy=0;
    z.setPointerCapture(e.pointerId);h.style.transition='none'});
  z.addEventListener('pointermove',e=>{if(!act)return;dy=Math.max(0,e.clientY-y0);   /* never drag upward */
    h.style.transform=`translate(-50%,${dy}px)`});
  const fin=e=>{if(!act)return;act=false;
    const v=dy/Math.max(1,performance.now()-t0);   /* average px/ms over the whole gesture */
    h.style.transition='';                          /* hand control back to CSS */
    if(dy>120||v>.7){cierraHoja()}else{h.style.transform=''}};   /* close if >120px OR faster than .7 px/ms; else spring back */
  z.addEventListener('pointerup',fin);z.addEventListener('pointercancel',fin);
});
```

`cierraHoja` clears the inline transform/transition and removes `.on`, so the sheet animates from where the finger left it using `--cierra` (.55s); the snap-back uses the base rule (`--cierra`) too. Esc and scrim click use the same function.

## 8. Reduced motion (exact, add to every page)

```css
@media (prefers-reduced-motion:reduce){
  *,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;transition-delay:0s!important}
}
```

Effects: transitions and animations complete instantly but still end in the right state (sheets still open/close, `animation:... backwards` still resolves, skeleton shimmer stops). Because state is driven by classes, no JS branch is required. If JS must decide (e.g. smooth scroll): `const rm=matchMedia('(prefers-reduced-motion:reduce)').matches; scrollTo({top:0,behavior:rm?'auto':'smooth'})`. Do not use timers longer than the visible animation to gate state; the demo's `setTimeout` waits (170ms, 400ms, 1100ms) are cleanup only.

## 9. Icon system

Inline line SVG, no sprite file, no icon font, no emojis. Icons live in a JS map of path data (24x24 viewBox) and are injected into `<span data-ic="name"></span>` placeholders or via `ic('name')`.

```css
svg.i{width:1em;height:1em;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}
```

Size is controlled by the parent `font-size` (1em): nav 18px, round button 20px, badge 19px, toast badge 18px, input leading icon 18px, empty-state badge 28px, solid-panel corner icon 20px. Colour is `currentColor`. Checkbox tick is the exception: stroke-width 2.2.

```js
const ic=n=>`<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="${IC[n]||IC.more}"/></svg>`;   /* unknown id falls back to "more" */
const icons=(r=document)=>$$('[data-ic]',r).forEach(e=>{if(!e.firstChild)e.innerHTML=ic(e.dataset.ic)});
```

### Icon map (all ids, exact paths)

```js
const IC={
 home:'M3 11l9-7 9 7M5 10v10h14V10M10 20v-6h4v6',
 server:'M4 5h16v6H4zM4 13h16v6H4zM8 8h.01M8 16h.01',
 wallet:'M3 7h15a3 3 0 013 3v8a2 2 0 01-2 2H5a2 2 0 01-2-2zM3 7l12-3v3M16 14h2',
 check:'M5 12.5l4.5 4.5L19 7.5',
 alert:'M12 4l9 16H3zM12 10v4M12 17h.01',
 tema:'M12 3a9 9 0 100 18 9 9 0 000-18zM12 3v18M12 3a9 9 0 010 18',
 grid:'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z',
 plus:'M12 5v14M5 12h14',
 more:'M5 12h.01M12 12h.01M19 12h.01',
 clock:'M12 3a9 9 0 100 18 9 9 0 000-18zM12 7v5l3 2',
 calendar:'M4 6h16v14H4zM4 10h16M8 3v4M16 3v4',
 search:'M11 4a7 7 0 100 14 7 7 0 000-14zM20 20l-4-4',
 refresh:'M20 11a8 8 0 00-14-4L4 9M4 4v5h5M4 13a8 8 0 0014 4l2-2M20 20v-5h-5',
 stop:'M7 7h10v10H7z',
 play:'M8 5l11 7-11 7z',
 x:'M6 6l12 12M18 6L6 18',
 cpu:'M7 7h10v10H7zM10 10h4v4h-4zM9 3v4M15 3v4M9 17v4M15 17v4M3 9h4M3 15h4M17 9h4M17 15h4',
 db:'M5 6c0-1.7 3.1-3 7-3s7 1.3 7 3-3.1 3-7 3-7-1.3-7-3zM5 6v12c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12c0 1.7 3.1 3 7 3s7-1.3 7-3',
 target:'M12 3a9 9 0 100 18 9 9 0 000-18zM12 8a4 4 0 100 8 4 4 0 000-8z',
 bolt:'M13 3L5 14h6l-1 7 8-11h-6z',
 list:'M9 6h11M9 12h11M9 18h11M4 6h.01M4 12h.01M4 18h.01',
 file:'M6 3h8l4 4v14H6zM14 3v4h4',
 download:'M12 4v11M7 11l5 5 5-5M5 20h14',
 chev:'M6 9l6 6 6-6',
 copy:'M9 9h11v11H9zM5 15V5h10',
 cart:'M3 4h3l2 11h10l2-8H7M10 20h.01M17 20h.01',
 car:'M5 16V11l2-5h10l2 5v5M3 16h18M7 19v-3M17 19v-3',
 home2:'M4 20V9l8-5 8 5v11zM9 20v-6h6v6',
 music:'M9 18V6l10-2v12M9 18a3 3 0 11-6 0 3 3 0 016 0zM19 16a3 3 0 11-6 0 3 3 0 016 0z',
 coffee:'M5 9h12v6a4 4 0 01-4 4H9a4 4 0 01-4-4zM17 10h1.5a2.5 2.5 0 010 5H17M8 3v3M12 3v3',
 up:'M7 17L17 7M8 7h9v9'
};
```

Dots (`more`, the `.01` segments in `server`, `alert`, `list`, `cart`) rely on round caps at stroke 1.6 to render as points; keep them as zero-length `h.01` segments, never `<circle fill>`.

### Icon badge `.ib`

```css
.ib{display:inline-grid;place-items:center;width:40px;height:40px;border-radius:var(--r-s);background:var(--interior);font-size:19px;flex:none;color:var(--tinta)}
.ib.coral{background:var(--coral-tint);color:var(--coral-ink)}
:root[data-tema="oscuro"] .ib.coral{background:rgba(236,91,52,.2);color:var(--coral-2)}
.toast .ib{width:36px;height:36px;font-size:18px}
.vacio .ib{width:64px;height:64px;font-size:28px;border-radius:24px;margin-bottom:14px}
/* corner icon on solid panels */
.ico{position:absolute;top:20px;right:20px;width:42px;height:42px;border-radius:var(--r-s);display:grid;place-items:center;font-size:20px}
.sol .ico{background:rgba(255,255,255,.2);color:#fff}
:root[data-tema="oscuro"] .sol-tinta .ico{background:rgba(21,20,18,.12);color:#151412}
```

Use `.ib.coral` only for alerts/errors/the important item; neutral `.ib` otherwise. Badge radius is `--r-s` (16px), 24px for the large empty-state badge. `button.ib` gets the hover `scale(1.08)` under `@media(hover:hover)`.

### Adding a new icon consistently

1. Draw on a 24x24 grid with 3px safe margin (content within 3..21), one visual weight: outline only, stroke 1.6, round caps and joins, no fills, no gradients, no emojis.
2. Prefer simple primitives: rects/rounded rects as `M x y h w v h h-w z`, circles as two arcs `M12 3a9 9 0 100 18 9 9 0 000-18z`, dots as `Mx yh.01`.
3. Compress to ONE path string (absolute/relative commands OK, no `<g>`, no attributes) and add it to `IC` with a short lowercase id (`home2`, `chev`, `up` style; function-named, not file-named).
4. Reference it with `<span data-ic="id"></span>` or `ic('id')`; never paste an `<svg>` by hand except custom animated ones (e.g. the checkbox tick, which sets `pathLength="1"`).
5. Check it at 18px and 28px in both themes; directional variants (chevron up/right) are made with CSS `transform:rotate()` and the spring easing, not new ids.
6. Update this skill's icon list when adding a shared icon.

## 10. Accessibility

- Global focus ring: `:focus-visible{outline:2px solid var(--coral);outline-offset:3px}`; on solid panels and coral buttons use `.sol:focus-visible,.btn.coral:focus-visible{outline-color:var(--tinta)}`. Table rows: `tr:focus-visible{outline-offset:-3px;border-radius:16px}`; menu items: `outline-offset:-2px`. Never `outline:none` without a replacement.
- Decorative icons: `aria-hidden="true"` (already in `ic()`). Icon-only buttons MUST have `aria-label` (and optionally `title` for the tooltip): e.g. `<button class="rbtn vidrio" aria-label="Toggle light or dark theme" title="Toggle theme"><span data-ic="tema"></span></button>`; menu triggers add `aria-haspopup="menu"` and `aria-expanded`.
- Never convey state by icon/colour alone; pair with text (status chips have a dot AND a word).
- Toast container `role="status" aria-live="polite"`; tooltip `role="tooltip"`; charts `role="img"` with an `aria-label`.
- Toggles use `role="switch"`/`aria-checked`; checkboxes `role="checkbox"` + `aria-checked` + `aria-label`; segmented buttons `aria-pressed`; nav `aria-current="page"`.
- Visually hidden helper: `.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}`.

## 11. Do / Don't

Do
- Use `--muelle` for anything arriving or pressed, `--cierra` for anything leaving; make the close shorter than the open.
- Put close transitions on the base state and open transitions on `.on`.
- Stagger entrances with `--i` (45ms cards, 70ms bars) and clean the entrance class after ~1100ms.
- Guard every hover with `@media(hover:hover)`; keep `:active` press feedback outside it.
- Re-trigger one-shot animations with remove class, `void el.offsetWidth`, add class.
- Cancel stale async view changes with a counter (`cambio`).

Don't
- No hover transform/shadow on cards, panels or table rows (rows may only change background where the demo does).
- No `ease`, `ease-in-out` or `linear` for movement; no bounce libraries; no motion over ~1.2s.
- No fade-only close for sheets/menus/toasts (they must move with `--cierra`).
- No emojis, icon fonts, filled icons, other stroke widths (except checkbox 2.2) or per-icon colours; no serif or animated counters for numbers.
- No decorative looping animations other than the skeleton shimmer.

## Related skills

glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion
