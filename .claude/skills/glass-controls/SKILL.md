---
name: glass-controls
description: Exact CSS, markup, JS and state rules for every interactive control of the approved warm liquid-glass design system - buttons (primary, coral, secondary, ink, disabled, small, inside solid panels), round header buttons and icon buttons, chips and tags (static vs clickable, colour variants), the segmented control with sliding pill, toggle switch, checkbox with animated check, text input, search field with icon, select, date input, the icon badge (.ib), plus all states (default, hover, active/pressed, focus-visible, disabled) and the hover rules (only inside @media(hover:hover); controls lift/brighten, containers never do). Use it whenever the user asks to design, build or restyle a button, input, form, toggle, chip, tab switcher, filter, checkbox or any clickable element in "our glass style / liquid glass / panel style". Part of the glass-design family; the hub skill is glass-design.
---

# glass-controls - every interactive control

Source of truth: `~/.claude/skills/glass-design/reference/demo-complete.html`. Copy values exactly; do not eyeball them. Tokens (colours, radii, springs, light/dark variables) live in `glass-tokens`; the glass surface itself in `glass-surfaces`. This skill only defines the controls that sit on those surfaces.

## 0. Prerequisites (tokens these snippets use)

Class names below are the demo's (Spanish: `tinta` = ink, `muelle` = spring, `cierra` = closing curve, `interior` = inset fill, `campo` = field, `togl` = toggle, `chk` = checkbox, `peq` = small, `rbtn` = round button, `pastilla`/`sp` = sliding pill). Keep them so all sibling skills and the demo stay copy-compatible.

```css
:root{
  --coral:#EC5B34; --coral-2:#F6A285; --coral-tint:#FCEAE3; --coral-ink:#B8461F;
  --forest-dot:#2E8A63; --amber-dot:#D99A2B;
  --r-xl:44px; --r-l:40px; --r-m:24px; --r-s:16px;
  --muelle:cubic-bezier(.34,1.45,.4,1);   /* spring, opening / press release */
  --cierra:cubic-bezier(.55,-.3,.45,1);   /* closing */
}
:root[data-tema="claro"]{ --tinta:#151412; --tinta-2:#55514b; --tinta-3:#6f6a62;
  --pill:rgba(255,255,255,.95); --linea:rgba(28,24,20,.09); --reflejo:rgba(255,255,255,.9);
  --interior:rgba(28,24,20,.05); --interior-2:rgba(28,24,20,.09);
  --btn:#151412; --btn-tinta:#fff;
  --verde-txt:#1F5C45; --ambar-txt:#8A5410; --coral-txt:#B8461F; }
:root[data-tema="oscuro"]{ --tinta:#f4f2ee; --tinta-2:rgba(244,242,238,.74); --tinta-3:rgba(244,242,238,.6);
  --pill:rgba(255,255,255,.15); --linea:rgba(255,255,255,.11); --reflejo:rgba(255,255,255,.3);
  --interior:rgba(255,255,255,.07); --interior-2:rgba(255,255,255,.12);
  --btn:#f4f2ee; --btn-tinta:#151412;
  --verde-txt:#6FD3A6; --ambar-txt:#EDBB62; --coral-txt:#F6A285; }
*{box-sizing:border-box;margin:0}
button,input,select{font:inherit;color:inherit}
svg.i{width:1em;height:1em;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}
```

## 1. Global rules for all controls

- **Focus-visible (global, every control):**
  ```css
  :focus-visible{outline:2px solid var(--coral);outline-offset:3px}
  .sol:focus-visible,.btn.coral:focus-visible{outline-color:var(--tinta)}  /* coral-on-coral would vanish */
  ```
  Fields override to `outline-offset:2px`; table rows/menu items use a negative offset (`-3px` / `-2px`) so the ring stays inside.
- **Hover exists ONLY for controls**, always inside `@media(hover:hover)` (no sticky hover on touch). **Containers never get hover**: cards, glass panels, solid panels, table rows, list rows, sheets, toasts have no hover lift/colour/brightness. (`.tabla tbody tr` has `cursor:pointer;transition:background .2s` but NO `:hover` rule - keep it that way.)
- **Pressed (`:active`)** is a spring squeeze: buttons `scale(.93)`, round buttons `scale(.86)`, `.mas` `scale(.85)`, checkbox `scale(.82)`, toggle thumb widens to 30px.
- **Spring both directions:** transforms use `var(--muelle)` (.45s-.55s); colour/opacity/filter use short plain transitions (.2s-.3s). Closing/leaving uses `var(--cierra)`. See `glass-motion`.
- **Disabled:** `opacity:.4;cursor:not-allowed;transform:none` (buttons), `opacity:.45` (fields). Hover rules exclude disabled via `:not(:disabled)`.
- Shape: controls are **pills** (`border-radius:99px`) or circles; icon badges/menu items use `--r-s` (16px); big shortcut buttons may use `--r-m` (24px). Never square corners.
- Icons: inline `<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="..."/></svg>`, stroke 1.6, round caps. No emojis, no icon fonts.
- Typeface: sans for all control labels, weight 600. Serif is never used in controls.
- A control must be a real `<button>` / `<input>` / `<select>` with an accessible name (`aria-label` or visible text or `.sr` span).

## 2. Buttons `.btn`

```css
.btn{font-weight:600;border:0;cursor:pointer;padding:12px 22px;border-radius:99px;background:var(--btn);color:var(--btn-tinta);
  display:inline-flex;align-items:center;gap:8px;font-size:14.5px;
  transition:transform .45s var(--muelle),opacity .2s,background-color .25s,box-shadow .3s,filter .25s}
.btn:active{transform:scale(.93)}
.btn.sec{background:var(--interior);color:var(--tinta);border:1px solid var(--linea)}
.btn.coral{background:var(--coral);color:#fff}
.btn.tinta{background:#151412;color:#fff;box-shadow:inset 0 0 0 1px rgba(255,255,255,.16)}
.btn:disabled{opacity:.4;cursor:not-allowed;transform:none}
.btn.peq{padding:8px 16px;font-size:13px}
.btns{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}
@media(hover:hover){
  .btn:not(:disabled):hover{transform:translateY(-2px);filter:brightness(1.1);box-shadow:0 10px 22px -10px rgba(0,0,0,.45)}
  .btn.coral:not(:disabled):hover{filter:brightness(1.08);box-shadow:0 12px 26px -10px rgba(236,91,52,.8)}
  .btn.sec:not(:disabled):hover{filter:none;background:var(--interior-2);box-shadow:0 8px 18px -12px rgba(0,0,0,.35)}
  .sol .btn:not(:disabled):hover{filter:none;box-shadow:0 10px 22px -10px rgba(0,0,0,.5)}
}
```

```html
<div class="btns">
  <button class="btn">Primary</button>              <!-- default: ink in light, cream in dark (--btn / --btn-tinta) -->
  <button class="btn coral">Coral</button>          <!-- the single main action of a view -->
  <button class="btn sec">Secondary</button>        <!-- inset glass + 1px --linea border -->
  <button class="btn tinta">Ink</button>            <!-- always #151412, theme independent -->
  <button class="btn" disabled>Disabled</button>
  <button class="btn peq sec">Small</button>        <!-- 8px 16px, 13px -->
  <button class="btn coral"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M20 11a8 8 0 00-14-4L4 9M4 4v5h5M4 13a8 8 0 0014 4l2-2M20 20v-5h-5"/></svg>With icon</button>
</div>
```

| Variant | Background / text | Hover | Focus ring |
|---|---|---|---|
| `.btn` primary | `--btn` / `--btn-tinta` | lift -2px, brightness 1.1, shadow `0 10px 22px -10px rgba(0,0,0,.45)` | coral |
| `.btn.coral` | `#EC5B34` / `#fff` | lift -2px, brightness 1.08, halo `0 12px 26px -10px rgba(236,91,52,.8)` | `--tinta` |
| `.btn.sec` | `--interior` + 1px `--linea` / `--tinta` | lift -2px, no filter, bg `--interior-2`, shadow `0 8px 18px -12px rgba(0,0,0,.35)` | coral |
| `.btn.tinta` | `#151412` + inset 1px rgba(255,255,255,.16) / `#fff` | same as primary | coral |
| `:disabled` | opacity .4 | none (`:not(:disabled)`) | - |

Rules: at most one coral/primary action per card or sheet footer; pair it with a `.sec` (cancel/close). Coral buttons are the call to action, ink buttons the destructive/neutral-strong one (e.g. "Parar").

### Buttons inside solid panels (`.sol`)
Solid panels (coral or ink, max 2 per screen, see `glass-surfaces`) recolour their buttons:
```css
.sol .btn{background:#fff;color:#151412}
.sol .btn.sec{background:rgba(255,255,255,.18);color:#fff;border:0}
:root[data-tema="oscuro"] .sol-tinta .btn{background:#151412;color:#fff}  /* ink panel is light in dark mode */
.sol .ico{background:rgba(255,255,255,.2);color:#fff}
:root[data-tema="oscuro"] .sol-tinta .ico{background:rgba(21,20,18,.12);color:#151412}
```
Hover inside `.sol`: no brightness filter, only `box-shadow:0 10px 22px -10px rgba(0,0,0,.5)` plus the lift. A clickable solid panel is itself a `<button class="card sol ...">` whose only affordance is `cursor:pointer` and the inner `.chipw` pill - it gets **no hover** (container rule).

## 3. Round header buttons `.rbtn` and icon buttons

```css
.rbtn{width:48px;height:48px;border-radius:50%;display:grid;place-items:center;cursor:pointer;font-size:20px;color:var(--tinta);
  transition:transform .5s var(--muelle);padding:0}
.rbtn:active{transform:scale(.86)}
@media(hover:hover){ .rbtn:hover,.ib:is(button):hover{transform:scale(1.08);background:var(--interior-2)} }
```
```html
<button class="rbtn vidrio" aria-label="Toggle theme" title="Toggle theme"><span data-ic="tema"></span></button>
```
`.rbtn` is combined with the glass surface class `.vidrio` (blur 26px, see `glass-surfaces`). Header buttons sit in `.acc{display:flex;gap:10px}`. Always give `aria-label` + `title`.

Row "more" button (inside tables/lists, flat on the row):
```css
.mas{width:36px;height:36px;border-radius:50%;border:0;background:var(--interior);display:inline-grid;place-items:center;cursor:pointer;font-size:18px;transition:transform .4s var(--muelle)}
.mas:active{transform:scale(.85)}
```
Hover for `.mas` follows the generic round-control feel (scale 1.08 + `--interior-2`); add it to the `.rbtn:hover` selector list if you need it. An `.ib` is hoverable only when it is a `<button>` (`.ib:is(button)`); decorative `.ib` spans have no hover.

## 4. Icon badge `.ib`

```css
.ib{display:inline-grid;place-items:center;width:40px;height:40px;border-radius:var(--r-s);background:var(--interior);font-size:19px;flex:none;color:var(--tinta)}
.ib.coral{background:var(--coral-tint);color:var(--coral-ink)}
:root[data-tema="oscuro"] .ib.coral{background:rgba(236,91,52,.2);color:var(--coral-2)}
.ico{position:absolute;top:20px;right:20px;width:42px;height:42px;border-radius:var(--r-s);display:grid;place-items:center;font-size:20px} /* corner badge on a card */
.toast .ib{width:36px;height:36px;font-size:18px}
.vacio .ib{width:64px;height:64px;font-size:28px;border-radius:24px}   /* empty state */
```
```html
<span class="ib"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg></span>
<span class="ib coral">...</span>   <!-- error / alert / attention -->
```
Static by default (no hover). Only a `<button class="ib">` gets hover. Inside `.sol` use `.ico` (white 20% tint). When a card has a corner `.ico`, its label gets `padding-right:50px` (`.card:has(.ico) .etq`).

## 5. Chips and tags `.chip`

```css
.chip{display:inline-flex;align-items:center;gap:7px;padding:6px 12px;border-radius:99px;font-size:12.5px;font-weight:600;background:var(--interior);white-space:nowrap}
.chip.coral{background:var(--coral);color:#fff}
.chip.verde{color:var(--verde-txt)} .chip.ambar{color:var(--ambar-txt)} .chip.err{color:var(--coral-txt)}
.chip.borde{background:none;border:1px solid var(--linea);color:var(--tinta-2)}
.punto{display:inline-block;width:9px;height:9px;border-radius:50%;flex:none}
.ok{background:var(--forest-dot)} .av{background:var(--amber-dot)} .er{background:var(--coral)} .off{background:var(--tinta-3)}
@media(hover:hover){ .chip:is(button,a):hover,button.chip:hover{background:var(--interior-2);transform:translateY(-1px)} }
.chipw{display:inline-flex;align-items:center;gap:6px;margin-top:14px;padding:6px 13px;border-radius:99px;font-size:12.5px;font-weight:600;background:rgba(255,255,255,.2)} /* pill inside a solid panel */
:root[data-tema="oscuro"] .sol-tinta .chipw{background:rgba(21,20,18,.1)}
```
```html
<span class="chip">Neutral</span>
<span class="chip coral">Coral</span>
<span class="chip verde"><i class="punto ok"></i>Active</span>
<span class="chip ambar"><i class="punto av"></i>Warning</span>
<span class="chip err"><i class="punto er"></i>Error</span>
<span class="chip borde">Outline</span>
<button class="chip">Clickable chip</button>   <!-- hover only if button or a -->
```
- **Static chip** (`<span>`): status, counts, tags (e.g. task tag `<span class="chip">clase</span>`). No hover, no cursor change.
- **Clickable chip** (`<button>`/`<a>`): hover `--interior-2` + lift -1px, same spring transition as other controls (add `transition:transform .4s var(--muelle),background-color .25s`).
- Status meaning is carried by the coloured dot + coloured text, not by filled backgrounds. `.chip.coral` (filled) is reserved for one emphasised count/state.
- A tag is just a neutral `.chip` with a short lowercase word.

## 6. Segmented control `.seg` (sliding pill)

```css
.seg{position:relative;display:inline-flex;padding:5px;border-radius:99px;background:var(--interior);border:1px solid var(--linea)}
.seg button{position:relative;z-index:1;font-weight:600;font-size:13.5px;padding:8px 18px;border:0;background:none;color:var(--tinta-2);border-radius:99px;cursor:pointer;transition:color .3s}
.seg button[aria-pressed=true]{color:var(--tinta)}
.seg .sp{position:absolute;top:5px;bottom:5px;left:0;border-radius:99px;background:var(--pill);
  box-shadow:inset 0 1px 0 var(--reflejo),0 4px 14px -6px rgba(0,0,0,.3);
  transition:left .55s var(--muelle),width .55s var(--muelle)}
@media(hover:hover){ .seg button:not([aria-pressed=true]):hover{color:var(--tinta);background:var(--interior-2)} }
```
```html
<div class="seg" id="seg-rango" role="group" aria-label="Time range">
  <button data-v="1h"  aria-pressed="false">1 h</button>
  <button data-v="24h" aria-pressed="true">24 h</button>
  <button data-v="7d"  aria-pressed="false">7 d</button>
</div>
```
```js
const $=(s,e=document)=>e.querySelector(s),$$=(s,e=document)=>[...e.querySelectorAll(s)];
function segMove(s){const b=$('[aria-pressed=true]',s),p=$('.sp',s);
  if(b&&p&&b.offsetWidth){p.style.left=b.offsetLeft+'px';p.style.width=b.offsetWidth+'px'}}
function segInit(s,fn){
  if(!$('.sp',s))s.insertAdjacentHTML('afterbegin','<span class="sp"></span>');
  $$('button',s).forEach(b=>b.addEventListener('click',()=>{
    $$('button',s).forEach(x=>x.setAttribute('aria-pressed',x===b));
    segMove(s);fn&&fn(b.dataset.v)}));
}
const segsDe=r=>$$('.seg',r).forEach(segMove);
/* init + re-measure when fonts/layout/visibility change */
segInit($('#seg-rango'),v=>{/* react to v */});
addEventListener('load',()=>segsDe(document));
if(document.fonts&&document.fonts.ready)document.fonts.ready.then(()=>segsDe(document));
let rz;addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(()=>segsDe(document),120)});
```
Notes: state is `aria-pressed` (no extra class). The pill is measured with `offsetLeft/offsetWidth`, so call `segMove`/`segsDe` after a hidden view becomes visible (`offsetWidth` is 0 while `hidden`) and when programmatically changing the pressed button. First placement has the spring transition, which looks fine; to avoid a slide-in on first paint set `p.style.transition='none'` for the first call. The same pill technique powers the floating nav (`.pastilla`) - see `glass-navigation`.

## 7. Toggle switch `.togl`

```css
.togl{position:relative;width:52px;height:32px;border-radius:99px;border:1px solid var(--linea);background:var(--interior-2);cursor:pointer;padding:0;flex:none;transition:background .3s}
.togl::after{content:"";position:absolute;top:3px;left:3px;width:24px;height:24px;border-radius:50%;background:var(--pill);
  box-shadow:0 2px 6px rgba(0,0,0,.3);transition:transform .55s var(--muelle),width .3s}
:root[data-tema="claro"] .togl::after{background:#fff}
.togl[aria-checked=true]{background:var(--coral);border-color:transparent}
.togl[aria-checked=true]::after{transform:translateX(20px);background:#fff}
.togl:active::after{width:30px}
.togl[aria-checked=true]:active::after{transform:translateX(14px)}   /* thumb stretches but stays anchored right */
@media(hover:hover){ .togl:hover{filter:brightness(1.08)} }
.trow{display:flex;align-items:center;justify-content:space-between;gap:12px}
```
```html
<div class="trow">
  <span id="rec-l" style="font-weight:500">Notification reminder</span>
  <button type="button" class="togl" role="switch" aria-checked="true" aria-labelledby="rec-l"></button>
</div>
```
```js
document.addEventListener('click',e=>{
  const sw=e.target.closest('[role=switch]');
  if(sw)sw.setAttribute('aria-checked',sw.getAttribute('aria-checked')!=='true');
});
```
Checked = coral track with white thumb. Unchecked track is `--interior-2`. It is a `<button role="switch">`, so Space/Enter work natively. Always label via `aria-labelledby` or `aria-label`.

## 8. Checkbox `.chk` with animated check

```css
.chk{width:30px;height:30px;border-radius:12px;border:1.6px solid var(--tinta-3);background:none;cursor:pointer;display:grid;place-items:center;padding:0;color:#fff;flex:none;
  transition:background .3s,border-color .3s,transform .5s var(--muelle)}
.chk svg{width:18px;height:18px;fill:none;stroke:currentColor;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}
.chk path{stroke-dasharray:1;stroke-dashoffset:1;transition:stroke-dashoffset .45s .05s var(--muelle)}  /* draws the tick */
.chk[aria-checked=true]{background:var(--coral);border-color:var(--coral);transform:scale(1.08)}
.chk[aria-checked=true] path{stroke-dashoffset:0}
.chk:active{transform:scale(.82)}
@media(hover:hover){ .chk:hover{border-color:var(--coral);transform:scale(1.1)} }
.tarea.hecha .nombre{opacity:.5;text-decoration:line-through}   /* row label when done */
```
```html
<button class="chk" role="checkbox" aria-checked="false" aria-label="Complete: Pay invoice">
  <svg viewBox="0 0 24 24" aria-hidden="true"><path pathLength="1" d="M5 12.5l4.5 4.5L19 7.5"/></svg>
</button>
```
```js
b.addEventListener('click',()=>{const on=b.getAttribute('aria-checked')!=='true';
  b.setAttribute('aria-checked',on);li.classList.toggle('hecha',on)});
```
`pathLength="1"` is what makes `stroke-dasharray:1` work. Note: the checkbox gets hover, the list row `.tarea` does not.

## 9. Text input, search, select, date `.campo`

```css
.campo{display:block;width:100%;padding:13px 18px;border-radius:99px;border:1px solid var(--linea);background:var(--interior);font-size:15px;outline-offset:2px;min-width:0}
.campo::placeholder{color:var(--tinta-3)}
.campo:disabled{opacity:.45}
.cwrap{position:relative;display:block}
.cwrap>.i{position:absolute;left:16px;top:50%;transform:translateY(-50%);color:var(--tinta-3);pointer-events:none;font-size:18px}
.cwrap>.campo{padding-left:44px}
.cwrap.sel>.i{left:auto;right:16px}
.cwrap.sel>.campo{padding-left:18px;padding-right:42px;appearance:none;-webkit-appearance:none}
.campo.mal{animation:sacude .45s}                      /* validation error: add class, remove on animationend */
@keyframes sacude{20%{transform:translateX(-7px)}45%{transform:translateX(6px)}70%{transform:translateX(-3px)}}
label.lb{display:block;font-size:12.5px;font-weight:600;color:var(--tinta-2);margin:0 0 7px 6px}
.form{display:grid;gap:16px;margin-top:18px}
.dos{display:grid;grid-template-columns:1fr 1fr;gap:12px}
@media(max-width:480px){.dos{grid-template-columns:1fr}}
```
```html
<!-- plain text -->
<div><label class="lb" for="t">Title</label><input class="campo" id="t" placeholder="What needs doing?" autocomplete="off"></div>

<!-- search with leading icon -->
<label class="cwrap"><span class="sr">Search task</span>
  <span class="i"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M11 4a7 7 0 100 14 7 7 0 000-14zM20 20l-4-4"/></svg></span>
  <input class="campo" type="search" placeholder="Search task" autocomplete="off"></label>

<!-- select with trailing chevron -->
<span class="cwrap sel"><select class="campo" aria-label="Tag"><option>clase</option><option>casa</option></select>
  <span class="i"><svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6"/></svg></span></span>

<!-- date -->
<div><label class="lb" for="d">Date</label><input class="campo" id="d" type="date"></div>

<!-- disabled -->
<input class="campo" placeholder="Disabled" disabled aria-label="Disabled">
```
(In the demo the icon holder is `<span class="i" data-ic="search">` filled by JS; the wrapper `.i` span and the inner `svg.i` can be a single element - the CSS `.cwrap>.i` targets the direct child.)

States: default = `--interior` fill + `--linea` border; focus = global coral 2px ring (offset 2px); disabled = opacity .45; error = `.mal` shake. Fields have **no hover**. `.sr` helper: `.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}`. Add `font-family:var(--sans)` via `font:inherit`; use `--mono` only for technical values (hashes, ports) with `class="campo mono"`-style overrides.

## 10. State matrix (quick reference)

| Control | Default | Hover (`@media(hover:hover)`) | Active | Focus-visible | Disabled / selected |
|---|---|---|---|---|---|
| `.btn` | pill, 12px 22px | translateY(-2px) + brightness + shadow/halo | scale(.93) | coral ring (ink on coral) | opacity .4, no hover |
| `.rbtn` | 48px circle glass | scale(1.08) + `--interior-2` | scale(.86) | coral ring | - |
| `.chip` button | `--interior` | `--interior-2` + lift -1px | - | coral ring | static chips: none |
| `.seg button` | `--tinta-2` text | text `--tinta` + bg `--interior-2` (not pressed only) | - | coral ring | `aria-pressed=true`: pill under it |
| `.togl` | `--interior-2` track | brightness 1.08 | thumb 30px wide | coral ring | `aria-checked=true`: coral track |
| `.chk` | 1.6px `--tinta-3` border | border coral + scale(1.1) | scale(.82) | coral ring | checked: coral fill, tick drawn, scale 1.08 |
| `.campo` | `--interior` pill | none | - | coral ring offset 2px | opacity .45 |
| `.ib` | static | only if `<button>`: scale(1.08) | - | - | - |
| cards / panels / rows | - | NONE | - | - | - |

## Do / Don't

Do
- Wrap every hover rule in `@media(hover:hover)` and exclude `:disabled`.
- Use spring (`--muelle`) for transforms; keep colour fades short and linear-ish.
- Use pills/circles; coral only for the main action, ink for strong neutral.
- Make toggles/checkboxes/segmented controls real buttons with `role`/`aria-*`, keyboard operable.
- Give icon-only buttons an `aria-label`.
- Close menus/sheets opened from a control on outside click and Esc (see `glass-overlays`).

Don't
- Don't add hover to cards, solid panels, glass panels, table rows, list rows or toasts.
- Don't use gradients, shadows-as-glow in colours other than the coral halo on `.btn.coral`.
- Don't use serif in labels or numbers inside controls; no emojis; no native-looking unstyled checkboxes/selects (`appearance:none` + chevron).
- Don't put more than one coral button per view region, or more than two solid panels per screen.
- Don't write hover rules outside the media query (the demo's `.menu button:hover` should be wrapped too).
- Don't forget `segMove` after showing a hidden segmented control.

Related skills: glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion
