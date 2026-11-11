---
name: glass-overlays
description: Everything that opens over the page in the approved warm liquid-glass design system - bottom sheets (veil, 44px top radius, handle, spring open/close, drag-to-dismiss with inertia), modal/form sheets, contextual popover menus (positioning, items, arrow-key focus), toasts (stack, spring entrance, auto-dismiss), chart tooltips, plus the mandatory close-on-outside-click and Esc rules with a reusable single-open-overlay registry (focus return, role/aria-modal/inert, scroll lock) and the exact open/close animations in both directions. Use when the user asks to design, build or restyle a sheet, modal, dialog, drawer, popover, dropdown/context menu, toast/notification, tooltip or any overlay in "our glass style / liquid glass / panel style". Part of the glass-design family; the hub skill is glass-design.
---

# glass-overlays

Source of truth: `~/.claude/skills/glass-design/reference/demo-complete.html`. Values below are copied from it. Token names (`--vidrio-hoja`, `--velo`, `--muelle`, `--cierra`, ...) are defined in `glass-tokens`; this skill only uses them. Class/ID names in the demo are Spanish (`hoja`, `velo`, `menu`, `tip`, `toasts`); keep them or rename consistently, but never change the values.

## Core rules (user-approved)

- Every overlay surface is **liquid glass** (never a solid coral/ink panel; those are only for inline actionable cards).
- **Anything that opens closes on outside click AND Esc.** No exceptions (sheet, menu, popover, tooltip, toast-by-click).
- **Spring/elastic in both directions**: open uses `--muelle` (overshoot), close uses `--cierra` (anticipation, goes slightly back then out). Close is always shorter than open.
- Containers do not get hover; **menu items and buttons do** (inside `@media(hover:hover)` for buttons; menu items use `:hover,:focus-visible`, see below).
- Sheet titles are the only place for serif (`Instrument Serif`, 38px). Numbers never serif. Icons inline line SVG, stroke 1.6, round caps. No emojis.
- Respect `prefers-reduced-motion` (snippet at the end).

## Motion tokens used here

```css
--muelle:cubic-bezier(.34,1.45,.4,1);   /* open / enter: overshoot spring */
--cierra:cubic-bezier(.55,-.3,.45,1);   /* close / exit: anticipation */
--r-xl:44px; --r-l:40px; --r-m:24px; --r-s:16px;
/* light */ --vidrio-hoja:rgba(255,255,255,.78); --velo:rgba(10,8,6,.3);
/* dark  */ --vidrio-hoja:rgba(28,27,25,.8);     --velo:rgba(0,0,0,.5);
--borde: light rgba(255,255,255,.85) / dark rgba(255,255,255,.18);
--reflejo: light rgba(255,255,255,.9) / dark rgba(255,255,255,.3);
--sombra: light 0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22)
          dark  0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18);
--interior: light rgba(28,24,20,.05) / dark rgba(255,255,255,.07);
--interior-2: light rgba(28,24,20,.09) / dark rgba(255,255,255,.12);
```

Overlay surfaces use `--vidrio-hoja` (denser than the card glass `--vidrio`) so text stays legible over content.

Base glass class (all overlays also carry it, or replicate it):

```css
.vidrio{
  background:var(--vidrio);
  -webkit-backdrop-filter:blur(26px) saturate(1.6);backdrop-filter:blur(26px) saturate(1.6);
  border:1px solid var(--borde);
  box-shadow:var(--sombra),inset 0 1px 0 var(--reflejo),inset 0 -1px 0 rgba(255,255,255,.05);
  border-radius:var(--r-l);
}
```

## Summary table

| Overlay | z-index | Radius | Fill | Open | Close |
|---|---|---|---|---|---|
| Veil | 8 | - | `--velo` | opacity .4s | opacity .4s |
| Bottom sheet | 9 | 44px 44px 0 0 | `--vidrio-hoja` + blur 26px sat 1.6 | translate `.8s var(--muelle)` | `.55s var(--cierra)` to `translate(-50%,108%)` |
| Menu | 20 | 24px | `--vidrio-hoja` + blur 26px sat 1.6 | scale .8 -> 1 `.55s var(--muelle)` | `.3s var(--cierra)` |
| Chart tooltip | 30 | 16px | `--vidrio-hoja` + blur 20px | `.35s var(--muelle)` | opacity `.15s` |
| Toasts | 25 | 24px | `--vidrio` (class `vidrio`) | `.6s var(--muelle)` | `.35s var(--cierra)` |

## 1. Bottom sheet / modal / form sheet

Anatomy: veil + `aside.hoja.vidrio` (`role="dialog" aria-modal="true" aria-labelledby tabindex="-1" inert`) with a drag zone + handle, optional `.etq` eyebrow, serif `h2`, body, `.btns` row (primary action coral or ink `.btn`, secondary `.btn.sec` with `data-cierra`).

```css
.velo{position:fixed;inset:0;background:var(--velo);opacity:0;pointer-events:none;transition:opacity .4s;z-index:8}
body.abierta .velo{opacity:1;pointer-events:auto}
.hoja{position:fixed;left:50%;bottom:0;width:min(580px,100%);max-height:92vh;overflow:auto;padding:12px 28px 40px;z-index:9;
  background:var(--vidrio-hoja);border-radius:var(--r-xl) var(--r-xl) 0 0;
  transform:translate(-50%,108%);transition:transform .55s var(--cierra);overscroll-behavior:contain}
.hoja.ancha{width:min(820px,100%)}
.hoja.on{transform:translate(-50%,0);transition:transform .8s var(--muelle)}
.hoja h2{font-family:var(--serif);font-weight:400;font-size:38px;margin:6px 0 8px;letter-spacing:-.01em}
.asa-z{height:30px;display:grid;place-items:center;cursor:grab;touch-action:none;margin:0 -28px}
.asa{width:44px;height:5px;border-radius:9px;background:var(--interior-2)}
.form{display:grid;gap:16px;margin-top:18px}
.dos{display:grid;grid-template-columns:1fr 1fr;gap:12px}
@media(max-width:480px){.dos{grid-template-columns:1fr}}
```

Notes:
- Width `min(580px,100%)` (form/detail) or `.ancha` `min(820px,100%)` (component catalogs). Centered with `left:50%` + `translate(-50%,...)` - every transform on the sheet must keep the `-50%` X.
- Hidden state `translate(-50%,108%)` plus `inert` so it is not focusable/readable while closed.
- The `.on` rule carries the open transition (`.8s var(--muelle)`); the base rule carries the close transition (`.55s var(--cierra)`). That is how both directions get their own curve.
- The sheet inherits `.vidrio` (blur + borde + sombra); the `.hoja` rules come after and override background and radius. Keep that order.
- Mobile: padding 12px 28px 40px stays; bottom padding clears the home indicator.

HTML skeleton:

```html
<div class="velo" id="velo"></div>
<aside class="hoja vidrio" id="h-tarea" role="dialog" aria-modal="true" aria-labelledby="nt-h" tabindex="-1" inert>
  <div class="asa-z" data-asa><div class="asa"></div></div>
  <div class="etq">Tareas</div>
  <h2 id="nt-h">Nueva tarea</h2>
  <form class="form" novalidate> ... 
    <div class="btns"><button type="submit" class="btn coral">Crear tarea</button><button type="button" class="btn sec" data-cierra>Cancelar</button></div>
  </form>
</aside>
```

Validation inside a form sheet: do not close; shake the field (`.campo.mal{animation:sacude .45s}`, keyframes in glass-controls), refocus it and fire an error toast.

### Open / close JS (exact)

```js
let sheetAbierta=null,foco=null;
function abreHoja(id){
  cierraMenu();ocultar();if(sheetAbierta&&sheetAbierta!==id)cierraHoja(true);
  const h=$('#'+id);foco=document.activeElement;sheetAbierta=id;h.inert=false;h.style.transform='';
  document.body.classList.add('abierta');
  requestAnimationFrame(()=>{h.classList.add('on')});
  setTimeout(()=>h.focus({preventScroll:true}),60);
}
function cierraHoja(sinFoco){
  if(!sheetAbierta)return;const h=$('#'+sheetAbierta);h.style.transition='';h.style.transform='';h.classList.remove('on');h.inert=true;
  document.body.classList.remove('abierta');sheetAbierta=null;ocultar();
  if(!sinFoco&&foco&&document.contains(foco))foco.focus({preventScroll:true});
}
$('#velo').onclick=()=>cierraHoja();
```

Only one sheet at a time: opening another closes the first with `cierraHoja(true)` (skips focus return, so the new one's opener is remembered).

### Drag to dismiss with inertia (exact)

Drag zone = `[data-asa]` (the 30px strip with the handle). Follows the finger 1:1 downward only; closes if displaced > 120px OR release velocity > .7 px/ms; otherwise springs back (clearing inline transform re-enables the CSS transition, which is the base `--cierra` curve... for snap-back the inline `transition:''` falls to the `.on` rule, i.e. `.8s var(--muelle)` - an elastic return).

```js
document.querySelectorAll('[data-asa]').forEach(z=>{
  let y0,t0,dy=0,h,act=false;
  z.addEventListener('pointerdown',e=>{h=z.closest('.hoja');y0=e.clientY;t0=performance.now();act=true;dy=0;z.setPointerCapture(e.pointerId);h.style.transition='none'});
  z.addEventListener('pointermove',e=>{if(!act)return;dy=Math.max(0,e.clientY-y0);h.style.transform=`translate(-50%,${dy}px)`});
  const fin=e=>{if(!act)return;act=false;const v=dy/Math.max(1,performance.now()-t0);h.style.transition='';
    if(dy>120||v>.7){cierraHoja()}else{h.style.transform=''}};
  z.addEventListener('pointerup',fin);z.addEventListener('pointercancel',fin);
});
```

Key details: `touch-action:none` on the zone, `setPointerCapture`, `transition:'none'` while dragging, `translate(-50%,${dy}px)` keeps centering, velocity = `dy / elapsed ms`. On dismiss, `cierraHoja()` clears the inline transform so the sheet continues from its dragged position into `108%` with the `--cierra` curve (the inertia feel). Never let `dy` go negative.

## 2. Contextual popover menu

```css
.menu{position:fixed;z-index:20;min-width:210px;padding:8px;border-radius:var(--r-m);background:var(--vidrio-hoja);
  -webkit-backdrop-filter:blur(26px) saturate(1.6);backdrop-filter:blur(26px) saturate(1.6);border:1px solid var(--borde);
  box-shadow:var(--sombra),inset 0 1px 0 var(--reflejo);opacity:0;visibility:hidden;transform:scale(.8);transform-origin:var(--ox,100%) var(--oy,0);
  transition:transform .3s var(--cierra),opacity .18s,visibility 0s .3s}
.menu.on{opacity:1;visibility:visible;transform:none;transition:transform .55s var(--muelle),opacity .18s,visibility 0s}
.menu button{display:flex;align-items:center;gap:12px;width:100%;padding:11px 14px;border:0;background:none;border-radius:16px;cursor:pointer;font-size:14.5px;font-weight:500;text-align:left}
.menu button:hover,.menu button:focus-visible{background:var(--interior-2);outline-offset:-2px}
.menu button.pel{color:var(--coral-txt)}   /* destructive item: coral text, not a solid fill */
```

- Panel radius 24px, items radius 16px, padding 8px / 11px 14px, min-width 210px (positioning code assumes width 230 and 46px per item).
- Items: icon (`ic()` 1em svg) + label, gap 12px. The destructive/risky item gets `.pel` (coral text).
- Item hover is allowed (it is a control). Focus-visible uses the same fill so keyboard and mouse look identical.
- Trigger: a `.mas` round button (`aria-haspopup="menu" aria-expanded`); the menu has `role="menu"`, items `role="menuitem"`.
- Scale origin is the trigger corner: the menu grows out of the button (`--ox`, `--oy`) and, when flipped above, from the bottom edge (`--oy:100%`).

Positioning + open/close (exact):

```js
const menu=$('#menu');let menuDe=null,menuBtn=null;
function abreMenu(btn,id){
  menuBtn=btn;
  menu.innerHTML=`<button role="menuitem" data-a="det">${ic('file')}Ver detalle</button>...`;
  const b=btn.getBoundingClientRect(),w=230,h=4*46+16;
  let x=Math.min(innerWidth-w-10,Math.max(10,b.right-w)),y=b.bottom+8,arriba=false;
  if(y+h>innerHeight-10){y=Math.max(10,b.top-h-8);arriba=true}   // flip above if no room below
  menu.style.left=x+'px';menu.style.top=y+'px';
  menu.style.setProperty('--ox',(b.right-x)+'px');menu.style.setProperty('--oy',arriba?'100%':'0');
  btn.setAttribute('aria-expanded','true');menu.classList.add('on');setTimeout(()=>$('button',menu).focus(),30);
}
function cierraMenu(foco){if(!menu.classList.contains('on'))return;menu.classList.remove('on');
  if(menuBtn){menuBtn.setAttribute('aria-expanded','false');if(foco)menuBtn.focus()}}
menu.addEventListener('keydown',e=>{const bs=[...menu.querySelectorAll('button')],i=bs.indexOf(document.activeElement);
  if(e.key==='ArrowDown'){e.preventDefault();bs[(i+1)%bs.length].focus()}
  if(e.key==='ArrowUp'){e.preventDefault();bs[(i-1+bs.length)%bs.length].focus()}});
```

Rules: right-aligned to trigger, 8px gap, 10px viewport margin; focus first item on open (after 30ms), return focus to the trigger only on Esc (`cierraMenu(true)`), not on outside click or item pick. Close on **scroll** too (`addEventListener('scroll',()=>{cierraMenu(false);ocultar()},{passive:true})`).

Toggle trick: clicking the trigger while open should close, not reopen. In the capture-phase `pointerdown` handler store `ultimoCierre=trigger` when the press was on the menu's own trigger, and in the click handler skip reopening when `m===ultimoCierre` (see section 6).

## 3. Toasts

```css
.toasts{position:fixed;left:50%;bottom:104px;transform:translateX(-50%);z-index:25;display:flex;flex-direction:column;gap:10px;align-items:center;pointer-events:none;width:min(420px,calc(100% - 28px))}
.toast{pointer-events:auto;display:flex;align-items:center;gap:12px;padding:10px 20px 10px 10px;border-radius:var(--r-m);cursor:pointer;
  opacity:0;transform:translateY(28px) scale(.85);transition:transform .6s var(--muelle),opacity .25s}
.toast.in{opacity:1;transform:none}
.toast.out{opacity:0;transform:translateY(20px) scale(.9);transition:transform .35s var(--cierra),opacity .25s}
.toast .ib{width:36px;height:36px;font-size:18px}
.toast span{font-size:14px;font-weight:500}
```
```html
<div class="toasts" id="toasts" role="status" aria-live="polite"></div>
```
```js
function toast(msg,icono='check'){
  const c=$('#toasts');while(c.children.length>=3)quita(c.firstChild);          // max 3 stacked, oldest leaves
  const t=document.createElement('div');t.className='toast vidrio';
  t.innerHTML=`<span class="ib ${icono==='alert'?'coral':''}">${ic(icono)}</span><span>${esc(msg)}</span>`;
  t.onclick=()=>quita(t);c.appendChild(t);void t.offsetWidth;t.classList.add('in');   // reflow, then spring in
  t._t=setTimeout(()=>quita(t),3400);                                                   // auto-dismiss 3.4s
}
function quita(t){if(!t||t._q)return;t._q=1;clearTimeout(t._t);t.classList.remove('in');t.classList.add('out');setTimeout(()=>t.remove(),400)}
```

- Sits above the floating nav (`bottom:104px`), centered, newest at the bottom, 10px gap, max 3.
- Glass (class `vidrio`), left icon tile `.ib` 36px (error uses `.ib.coral`; success neutral), text 14px/500. Click dismisses. Never a solid colored toast.
- Messages are short, sentence case; escape user text with `esc()`.
- Toasts are exempt from the Esc registry (non-modal, auto-dismiss, click-to-dismiss) but must not steal focus.

## 4. Chart tooltips

Glass pill that follows the pointer, never captures it.

```css
.tip{position:fixed;z-index:30;pointer-events:none;padding:10px 14px;border-radius:var(--r-s);font-size:12.5px;line-height:1.5;
  opacity:0;transform:translateY(6px) scale(.92);transition:opacity .15s,transform .35s var(--muelle);
  background:var(--vidrio-hoja);-webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px);border:1px solid var(--borde);box-shadow:var(--sombra);white-space:nowrap}
.tip.on{opacity:1;transform:none}
.tip b{display:block;font-weight:600;margin-bottom:2px}
.tip .punto{width:8px;height:8px;margin-right:6px}
.tip span.v{font-variant-numeric:tabular-nums;font-weight:600}   /* numbers: semi-bold sans, tabular, never serif */
```
```html
<div class="tip" id="tip" role="tooltip"></div>
```
```js
const tip=$('#tip');
function mostrar(html,x,y){tip.innerHTML=html;tip.classList.add('on');const w=tip.offsetWidth,h=tip.offsetHeight;
  tip.style.left=Math.min(innerWidth-w-8,Math.max(8,x-w/2))+'px';let t=y-h-16;if(t<8)t=y+20;tip.style.top=t+'px'}
const ocultar=()=>tip.classList.remove('on');
```
Content pattern: `<b>label</b>` then one `<div>` per series with a colored `.punto` and `<span class="v">value unit</span>`. Wire to `pointermove` + `pointerdown` (touch) and hide on `pointerleave`, scroll, Esc, opening a sheet, changing view. Centered over the pointer, 16px above (flips below with `y+20` if no room), clamped 8px from edges. Chart internals are in `glass-data`.

## 5. Reusable overlay registry (recommended pattern)

The demo hard-codes sheet + menu + tip. For new work use one registry: exactly one modal/popover open at a time, one outside-click handler, one Esc handler, focus return, scroll lock. Behavior matches the demo (capture-phase `pointerdown`, Esc closes the topmost, focus returns to the opener on Esc/close-button, not on outside click of a menu).

```js
/* overlay registry: sheet | menu | popover. Toasts and tooltips are outside it. */
const Overlays=(()=>{
  let cur=null;                                   // {el,opener,kind,close}
  const lock=on=>{document.body.classList.toggle('abierta',on);document.documentElement.style.overflow=on?'hidden':''};
  function open(el,{kind='sheet',opener=document.activeElement,show,hide}){
    if(cur&&cur.el!==el)close(true);              // single open overlay
    cur={el,opener,kind,hide};
    el.inert=false;show&&show(el);
    if(kind==='sheet'){lock(true);el.setAttribute('role','dialog');el.setAttribute('aria-modal','true');setTimeout(()=>el.focus({preventScroll:true}),60)}
    else setTimeout(()=>el.querySelector('button,[href],input,[tabindex]')?.focus(),30);
  }
  function close(skipFocus){
    if(!cur)return;const {el,opener,kind,hide}=cur;cur=null;
    hide&&hide(el);if(kind==='sheet'){el.inert=true;lock(false)}
    if(!skipFocus&&opener&&document.contains(opener))opener.focus({preventScroll:true});
  }
  document.addEventListener('pointerdown',e=>{                   // outside click (capture: runs before targets)
    if(cur&&cur.kind!=='sheet'&&!cur.el.contains(e.target)&&!e.target.closest('[aria-expanded="true"]'))close(true);
  },true);
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&cur){e.preventDefault();close(false)}});
  addEventListener('scroll',()=>{if(cur&&cur.kind!=='sheet')close(true)},{passive:true});
  return {open,close,get current(){return cur}};
})();
```
Sheets close on veil click (`#velo` `onclick`), popovers on any outside `pointerdown`. If the trigger of an open popover is pressed again it should toggle closed: skip reopen via the `ultimoCierre` flag shown in section 6.

Required attributes checklist:
- Sheet: `role="dialog"` `aria-modal="true"` `aria-labelledby=<h2 id>` `tabindex="-1"` and `inert` while closed (so it cannot be tabbed into). Focus the sheet itself on open, return to opener on close.
- Menu: `role="menu"`, items `role="menuitem"`, trigger `aria-haspopup="menu"` + `aria-expanded`.
- Tooltip: `role="tooltip"`; toast container `role="status" aria-live="polite"`.
- Scroll lock: `body.abierta` toggles the veil; also set `overflow:hidden` on `<html>` if the page behind scrolls on mobile. The sheet itself keeps `overscroll-behavior:contain` and `overflow:auto`.
- Opening a view change, another overlay or the theme toggle must close/hide stale overlays (`cierraMenu(); cierraHoja(true); ocultar();`).
- Never trap Esc inside inputs without closing; Esc always closes the topmost overlay first (menu before sheet).

## 6. Close-on-outside + Esc as in the demo

```js
let ultimoCierre=null;
document.addEventListener('pointerdown',e=>{
  if(menu.classList.contains('on')&&!menu.contains(e.target)){
    const t=e.target.closest('[data-menu]');ultimoCierre=(t&&t===menuBtn)?t:null;cierraMenu(false)}
  else ultimoCierre=null;
},true);
// in the global click delegate: if(m===ultimoCierre){ultimoCierre=null;return}   // pressing the trigger again = close only
addEventListener('scroll',()=>{cierraMenu(false);ocultar()},{passive:true});
document.addEventListener('keydown',e=>{if(e.key!=='Escape')return;
  if(menu.classList.contains('on'))cierraMenu(true);else if(sheetAbierta)cierraHoja();ocultar()});
```
Close buttons inside sheets use `data-cierra` handled by the delegate (`if(e.target.closest('[data-cierra]'))return cierraHoja()`).

## Reduced motion

```css
@media (prefers-reduced-motion:reduce){
  *,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important;transition-delay:0s!important}
}
```
Also keep `:focus-visible{outline:2px solid var(--coral);outline-offset:3px}` global (`--tinta` outline on solid panels).

## Do

- Use `--vidrio-hoja` + backdrop blur for every overlay; keep `inset 0 1px 0 var(--reflejo)` highlight.
- Put the open curve on the `.on` rule and the close curve on the base rule.
- Set `transform-origin` from the trigger for popovers.
- Return focus to the opener on Esc/close; `inert` closed sheets; lock scroll behind sheets.
- Keep toast text short; max 3 stacked; 3.4s lifetime.
- Escape all dynamic strings (`esc()`).

## Don't

- No solid coral/ink sheets, menus or toasts; no colored gradients or blobs behind overlays.
- No hover on the sheet, veil, menu container or toast (only on items/buttons).
- No serif anywhere except the sheet `h2`; never in tooltip/toast numbers.
- No overlays that only close via an X: outside click and Esc must always work.
- No linear/ease transitions on open/close; no animations on `display` (use `visibility`/`inert` + opacity/transform).
- No emojis, no emoji-style icons; line SVG only.
- No stacking two sheets or a menu over an open sheet without closing the first.

## Related skills

glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion
