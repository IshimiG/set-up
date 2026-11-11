---
name: glass-data
description: Data-display layer of the approved liquid-glass design system (glass-design family; hub skill is glass-design). Covers metric cards (uppercase label, big semi-bold tabular number with small unit, delta chip, coral progress bar), status rows and lists with green/amber/coral dots and chips, data tables (header, rows with NO row hover, context-menu trigger), task list items with animated coral checkbox, hand-written SVG charts in JS (smooth line/area chart with 1h/24h/7d range selector and crosshair, income/expense bar chart, donut with legend and segment growth on hover) with exact geometry helpers, chart colors via CSS variables, glass tooltips, es-ES number formatting, glass skeleton loading, empty states, and the rules for status colors (dots, chips and text only, never solid panels). Trigger whenever the user asks to design, build or restyle dashboards, KPI cards, stat tiles, tables, lists, task lists, charts, graphs, progress bars or data panels in "our glass style / liquid glass / panel style", or asks for loading or empty states in that style.
---

# glass-data — data display in the glass system

Part of the **glass-design family** (hub: `glass-design`). This skill only covers how data is shown: metrics, status, tables, task items, charts, tooltips, number formatting, skeleton and empty states. Palette/theme tokens live in `glass-tokens`, surfaces (`.vidrio`, `.sol`) in `glass-surfaces`, buttons/segmented/inputs in `glass-controls`, menus/sheets in `glass-overlays`, animation curves in `glass-motion`. The snippets below assume those tokens exist (they are reproduced minimally in "Token dependencies").

Class names come from the approved demo (Spanish: `.etq` label, `.num` number, `.barra` bar, `.fila` row, `.punto` dot, `.tabla` table, `.tarea` task, `.vacio` empty, `.sk` skeleton, `.graf` chart box, `.tip` tooltip). Keep them when extending the demo; in a new project you may rename but keep the values.

## Core rules

1. **Cards are glass, never solid.** Metric cards use `.card.vidrio`. Solid panels (`.sol-coral` / `.sol-tinta`) are reserved for the one or two important/actionable items per screen (see `glass-surfaces`). A metric being "bad" never justifies a solid panel by itself.
2. **Numbers**: semi-bold (600) **sans**, `font-variant-numeric: tabular-nums`, negative letter-spacing, unit as a small `<small>` beside it. NEVER serif, never italic, never in Instrument Serif. Same for percentages and money.
3. **Status colors (green / amber / coral) appear only as**: a 9px dot (`.punto`), a chip text colour (`.chip.verde|.ambar|.err`), or coloured text (`--verde-txt`, `--ambar-txt`, `--coral-txt`). Never as card backgrounds, never as large fills, never as solid panels. The only coral-filled things are: the progress-bar fill, the checkbox when checked, `.chip.coral`, one data series, and the (<=2) `.sol-coral` panel.
4. **Containers do not hover.** Cards, panels, list rows and table rows have no hover effect (no background change, no lift). Only controls (buttons, chips that are buttons, checkbox, `.mas` trigger, segmented options) hover, always inside `@media(hover:hover)`. Chart marks may react (bar opacity, donut stroke growth) because they are the data's own tooltip affordance.
5. **Colors in charts come from CSS variables** (`var(--coral)`, `var(--tinta)`, `var(--c1..c5)`, `var(--linea)`, `var(--tinta-3)`), so light/dark switch without re-rendering. Never hard-code hex in SVG attributes except through `var(...)`.
6. **Icons** are inline line SVG (`stroke-width:1.6`, round caps/joins, `currentColor`), no emojis anywhere, including empty states.
7. Everything that opens (row context menu, tooltip pinned by touch) closes on outside click and Esc. Tooltips are `pointer-events:none` and hide on pointer leave.
8. Spring/elastic both ways: bars grow with `--muelle`, line draws with `trazo`, progress fills with `width 1.1s var(--muelle)`; exits use `--cierra`.

## Token dependencies (from glass-tokens)

```css
:root{
  --coral:#EC5B34; --coral-2:#F6A285; --coral-tint:#FCEAE3; --coral-ink:#B8461F;
  --forest-dot:#2E8A63; --amber-dot:#D99A2B;
  --sans:"Inter","Adwaita Sans","SF Pro Text",system-ui,sans-serif;
  --mono:"JetBrains Mono","SF Mono",ui-monospace,monospace;
  --r-l:40px; --r-m:24px; --r-s:16px;
  --muelle:cubic-bezier(.34,1.45,.4,1);   /* spring open */
  --cierra:cubic-bezier(.55,-.3,.45,1);   /* anticipation close */
}
:root[data-tema="claro"]{
  --fondo:#EEECE8; --tinta:#151412; --tinta-2:#55514b; --tinta-3:#6f6a62;
  --vidrio:rgba(255,255,255,.52); --vidrio-hoja:rgba(255,255,255,.78); --pill:rgba(255,255,255,.95);
  --borde:rgba(255,255,255,.85); --linea:rgba(28,24,20,.09); --reflejo:rgba(255,255,255,.9);
  --sombra:0 1px 2px rgba(28,24,20,.04),0 18px 40px -18px rgba(28,24,20,.22);
  --interior:rgba(28,24,20,.05); --interior-2:rgba(28,24,20,.09);
  --verde-txt:#1F5C45; --ambar-txt:#8A5410; --coral-txt:#B8461F;
  --c1:#EC5B34; --c2:#F6A285; --c3:#151412; --c4:#8a857d; --c5:#CFCAC1;
}
:root[data-tema="oscuro"]{
  --fondo:#121210; --tinta:#f4f2ee; --tinta-2:rgba(244,242,238,.74); --tinta-3:rgba(244,242,238,.6);
  --vidrio:rgba(34,32,30,.42); --vidrio-hoja:rgba(28,27,25,.8); --pill:rgba(255,255,255,.15);
  --borde:rgba(255,255,255,.18); --linea:rgba(255,255,255,.11); --reflejo:rgba(255,255,255,.3);
  --sombra:0 22px 44px -22px rgba(0,0,0,.7),0 2px 8px rgba(0,0,0,.18);
  --interior:rgba(255,255,255,.07); --interior-2:rgba(255,255,255,.12);
  --verde-txt:#6FD3A6; --ambar-txt:#EDBB62; --coral-txt:#F6A285;
  --c1:#EC5B34; --c2:#F6A285; --c3:#f4f2ee; --c4:#8d8a84; --c5:#4a4742;
}
.sr{position:absolute;width:1px;height:1px;overflow:hidden;clip:rect(0 0 0 0)}
svg.i{width:1em;height:1em;fill:none;stroke:currentColor;stroke-width:1.6;stroke-linecap:round;stroke-linejoin:round;flex:none}
```

Categorical chart palette (`--c1..--c5`), in this order: coral, light coral, ink, warm grey, pale/dark neutral. Max 5 categories; group the rest into "Otros" (`--c5`). Do not add blue/purple/teal series.

## Number formatting (es-ES)

```js
const fmt=(n,d=0)=>n.toLocaleString('es-ES',{minimumFractionDigits:d,maximumFractionDigits:d,useGrouping:'always'});
// fmt(12480.35,2) -> "12.480,35"   fmt(1860) -> "1.860" (always groups, even 4 digits)   fmt(34.5,1) -> "34,5"
```

- Thousands `.`, decimal `,`. `useGrouping:'always'` so 4-digit numbers still group.
- Unit goes in `<small>` after the number, never glued in the same weight: `12.480<small>,35 €</small>` for big money (decimals move into the small part), `34<small>%</small>`, `11,2<small>GB</small>`, `86<small>Mb/s</small>`.
- In text/tooltips use a normal space before units: `34,2 %`, `1.842 €`. Signed amounts use a real minus `−` (U+2212) and `+`.
- Dates via `toLocaleDateString('es-ES', {...})`. Relative time helper:

```js
function atras(min){if(min<=0)return'ahora';if(min<60)return`hace ${min} min`;if(min<1440)return`hace ${Math.round(min/60)} h`;return`hace ${(min/1440).toFixed(1).replace('.',',')} d`}
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
```

Always `esc()` user data before putting it in `innerHTML`.

## Labels, numbers, bars (CSS)

```css
.etq{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--tinta-3);font-weight:600}
.card{padding:24px;transition:transform .5s var(--muelle);min-width:0}     /* NO :hover rule on .card */
.card:has(.ico) .etq{padding-right:50px}
.num{font-weight:600;font-size:46px;line-height:1;margin:12px 0 6px;letter-spacing:-.03em;font-variant-numeric:tabular-nums}
.num small{font-size:20px;font-weight:500;color:var(--tinta-2);letter-spacing:0;margin-left:3px}
.num.xl{font-size:56px}
@media(max-width:560px){.num{font-size:34px}.num small{font-size:16px}.num.xl{font-size:44px}}
.sub{color:var(--tinta-2);font-size:14px;margin-top:8px}
.m,.mono{font-family:var(--mono);font-size:13px;color:var(--tinta-2)}          /* technical data: ids, ports, uptime, hashes */
.amt{font-weight:600;font-variant-numeric:tabular-nums;white-space:nowrap}
.amt small{font-weight:500;color:var(--tinta-2);margin-left:2px;font-size:.85em}

.barra{height:10px;border-radius:99px;background:var(--interior-2);overflow:hidden;margin-top:14px}
.barra b{display:block;height:100%;width:0;border-radius:99px;background:linear-gradient(90deg,var(--coral-2),var(--coral));transition:width 1.1s var(--muelle)}
```

Progress bars: track `--interior-2`, fill coral (tonal coral-2 -> coral only), always `width:0` initially and animated after mount. The fill is always coral regardless of value; do not turn it green/amber/red. Express severity with a dot/chip next to it.

```js
const barras=r=>r.querySelectorAll('.barra b[data-w]').forEach(b=>{b.style.width='0';setTimeout(()=>b.style.width=b.dataset.w+'%',60)});
```
Call it after a view/sheet becomes visible and after data changes (set `dataset.w` then re-run).

## Metric card

```html
<section class="card vidrio c-3">
  <span class="ico ib"><!-- inline svg.i --></span>          <!-- optional 42px icon top-right (absolute, top/right 20px) -->
  <div class="etq">Disco</div>
  <div class="num">72<small>%</small></div>
  <div class="sub">1,4 TB libres</div>
  <div class="barra"><b data-w="72"></b></div>
</section>
```

Variants:
- Money: `<div class="num xl">12.480<small>,35 €</small></div>` then a delta chip.
- Fraction: `<div class="num"><span id="x">7</span><small>/ 8</small></div><div class="sub">activos ahora</div>`.
- Goal with bar: `.num` + `<small>/ 3.000 €</small>`, `.barra`, then a `.cab` row with a chip and "Faltan 1.140 €".
- Grid: 12-column grid, `gap:16px` (12px <=560px); metrics `c-3` (span 3, 6 at <=900px, 12 at <=560px), wide cards `c-4/c-6/c-8/c-12`.

```css
.ico{position:absolute;top:20px;right:20px;width:42px;height:42px;border-radius:var(--r-s);display:grid;place-items:center;font-size:20px}
.ib{display:inline-grid;place-items:center;width:40px;height:40px;border-radius:var(--r-s);background:var(--interior);font-size:19px;flex:none;color:var(--tinta)}
.ib.coral{background:var(--coral-tint);color:var(--coral-ink)}
:root[data-tema="oscuro"] .ib.coral{background:rgba(236,91,52,.2);color:var(--coral-2)}
.rejilla{display:grid;grid-template-columns:repeat(12,1fr);gap:16px}
.c-3{grid-column:span 3}.c-4{grid-column:span 4}.c-6{grid-column:span 6}.c-8{grid-column:span 8}.c-12{grid-column:span 12}
@media(max-width:900px){.c-3{grid-column:span 6}}
@media(max-width:760px){.c-4,.c-6,.c-8{grid-column:span 12}}
@media(max-width:560px){.card{padding:20px}.rejilla{gap:12px}}
```

## Delta chip, status dots, chips

```css
.punto{display:inline-block;width:9px;height:9px;border-radius:50%;flex:none}
.ok{background:var(--forest-dot)}.av{background:var(--amber-dot)}.er{background:var(--coral)}.off{background:var(--tinta-3)}
.chip{display:inline-flex;align-items:center;gap:7px;padding:6px 12px;border-radius:99px;font-size:12.5px;font-weight:600;background:var(--interior);white-space:nowrap}
.chip.coral{background:var(--coral);color:#fff}
.chip.verde{color:var(--verde-txt)}.chip.ambar{color:var(--ambar-txt)}.chip.err{color:var(--coral-txt)}
.chip.borde{background:none;border:1px solid var(--linea);color:var(--tinta-2)}
@media(hover:hover){ .chip:is(button,a):hover,button.chip:hover{background:var(--interior-2);transform:translateY(-1px)} } /* only when it is a control */
```

| Meaning | Dot | Chip |
|---|---|---|
| OK / active / positive delta | `.punto.ok` (#2E8A63) | `.chip.verde` (text `--verde-txt`) |
| Warning / pending | `.punto.av` (#D99A2B) | `.chip.ambar` (text `--ambar-txt`) |
| Error / failed / overdue | `.punto.er` (#EC5B34) | `.chip.err` (text `--coral-txt`) |
| Stopped / unknown | `.punto.off` | `.chip` |
| Neutral info | none | `.chip` / `.chip.borde` |

Delta chip: neutral glass chip with a status dot, the sign in the text, no arrow emojis: `<span class="chip"><span class="punto ok"></span>+3,2 % este mes</span>`. Negative delta uses `.punto.er` (or `.av`), same neutral chip. Do not tint the chip background.

State mapping helper:
```js
const ESTADO={ok:['Activo','verde'],av:['Aviso','ambar'],er:['Error','err'],off:['Parado','']};
const estChip=e=>`<span class="chip ${ESTADO[e][1]}"><i class="punto ${e}"></i>${ESTADO[e][0]}</span>`;
```
`.chip.coral` (solid) is for a single emphasised tag, not a status.

## Status rows / lists

```css
.fila{display:flex;align-items:center;gap:12px;padding:12px 0;border-top:1px solid var(--linea)}
.fila:first-child{border-top:0}
button.fila{width:100%;background:none;border-left:0;border-right:0;border-bottom:0;text-align:left;cursor:pointer;border-radius:0}
.fila .n{flex:1;font-weight:500;min-width:0}
.fila .n small{display:block;font-weight:400;font-size:12.5px;color:var(--tinta-2)}
.cab{display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap}
```
```js
$('#lista-serv').innerHTML=serv.map(s=>`<button class="fila" data-det="${s.id}" aria-label="Detalle de ${esc(s.n)}"><i class="punto ${s.estado}"></i><span class="n">${s.n}</span><span class="m">${s.up}</span>${estChip(s.estado)}</button>`).join('');
```
Row anatomy: `[dot | .ib icon] [.n name + small sub] [.m mono / .amt number] [chip]`. Rows are separated by a 1px `--linea` top border, no per-row card, no hover background. A clickable row (opens a sheet) is a `<button class="fila">` and gets focus-visible only. Money rows: `<span class="amt" style="min-width:104px;text-align:right">+1.620,00<small>€</small></span>`; expenses use `−` and keep ink colour (do not colour amounts green/red).

## Data table

```css
.tabla{width:100%;border-collapse:collapse;margin-top:10px}
.tabla th{text-align:left;font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:var(--tinta-3);font-weight:600;padding:8px 10px}
.tabla td{padding:12px 10px;border-top:1px solid var(--linea);font-size:14.5px;vertical-align:middle}
.tabla tbody tr{cursor:pointer;transition:background .2s}          /* NO tr:hover rule: rows never highlight on hover */
.tabla tbody tr:focus-visible{outline-offset:-3px;border-radius:16px}
.tabla td:first-child{font-weight:500}
.tabla td .mono{font-size:12.5px}
.tabla .r{text-align:right}
.sc{overflow-x:auto;margin:0 -8px;padding:0 8px}                   /* horizontal scroll wrapper */
@media(max-width:620px){.oc{display:none}}                          /* .oc = optional column hidden on phones */
.mas{width:36px;height:36px;border-radius:50%;border:0;background:var(--interior);display:inline-grid;place-items:center;cursor:pointer;font-size:18px;transition:transform .4s var(--muelle)}
.mas:active{transform:scale(.85)}
@media(hover:hover){ .rbtn:hover,.ib:is(button):hover,.mas:hover{transform:scale(1.08);background:var(--interior-2)} }
```
```html
<div class="sc"><table class="tabla"><caption class="sr">Lista de contenedores</caption>
  <thead><tr><th scope="col">Nombre</th><th scope="col">Estado</th><th scope="col" class="oc">Uptime</th><th scope="col">Memoria</th><th scope="col" class="r"><span class="sr">Acciones</span></th></tr></thead>
  <tbody></tbody></table></div>
```
```js
tbody.innerHTML=cont.map(c=>`<tr tabindex="0" data-det="${c.id}" aria-label="Detalle de ${esc(c.n)}"><td>${c.n}<div class="mono">${c.puerto}</div></td><td>${estChip(c.estado)}</td><td class="oc mono">${c.up}</td><td class="mono">${c.mem}</td><td class="r"><button class="mas" data-menu="${c.id}" aria-haspopup="menu" aria-label="Acciones de ${esc(c.n)}"><!-- svg.i more: M5 12h.01M12 12h.01M19 12h.01 --></button></td></tr>`).join('');
tbody.addEventListener('keydown',e=>{if(e.key==='Enter'&&e.target.matches('tr'))openDetail(e.target.dataset.det)});
```
- Header: 12px uppercase, tracking .06em, `--tinta-3`. Technical cells (ports, uptime, memory) in mono 12.5px.
- Right-aligned numeric columns use `.r` + tabular figures. Last column holds the `.mas` ("more") trigger that opens a context menu (see `glass-overlays`); clicking it must `stopPropagation` so the row action doesn't fire. The menu closes on outside click and Esc.
- The table sits inside a glass card; no table background of its own, no zebra stripes.

## Task list items

```css
.tarea{display:flex;align-items:center;gap:14px;padding:13px 0;border-top:1px solid var(--linea);list-style:none}
.tarea:first-child{border-top:0}
.tarea.nueva{animation:ent .7s var(--muelle)}
.tarea .tt{flex:1;min-width:0}
.tarea .nombre{display:block;font-weight:500;transition:opacity .3s,color .3s;overflow-wrap:anywhere}
.tarea .sub{margin-top:2px;font-size:12.5px}
.tarea.hecha .nombre{opacity:.5;text-decoration:line-through}
.chk{width:30px;height:30px;border-radius:12px;border:1.6px solid var(--tinta-3);background:none;cursor:pointer;display:grid;place-items:center;padding:0;color:#fff;flex:none;
  transition:background .3s,border-color .3s,transform .5s var(--muelle)}
.chk svg{width:18px;height:18px;fill:none;stroke:currentColor;stroke-width:2.2;stroke-linecap:round;stroke-linejoin:round}
.chk path{stroke-dasharray:1;stroke-dashoffset:1;transition:stroke-dashoffset .45s .05s var(--muelle)}
.chk[aria-checked=true]{background:var(--coral);border-color:var(--coral);transform:scale(1.08)}
.chk[aria-checked=true] path{stroke-dashoffset:0}
.chk:active{transform:scale(.82)}
@media(hover:hover){ .chk:hover{border-color:var(--coral);transform:scale(1.1)} }
@keyframes ent{from{opacity:0;transform:translateY(30px) scale(.96)}to{opacity:1;transform:none}}
```
```js
// check icon path: 'M5 12.5l4.5 4.5L19 7'  (draw it with pathLength="1")
`<li class="tarea ${t.done?'hecha':''}" data-id="${t.id}"><button class="chk" role="checkbox" aria-checked="${t.done}" aria-label="Completar: ${esc(t.t)}"><svg viewBox="0 0 24 24" aria-hidden="true"><path pathLength="1" d="M5 12.5l4.5 4.5L19 7"/></svg></button><div class="tt"><span class="nombre">${esc(t.t)}</span><span class="sub">${dateText}</span></div><span class="chip">${esc(t.tag)}</span></li>`
```
Checkbox = 30px, 12px radius (squircle), coral when checked with a stroke-drawn tick. Done tasks: 50% opacity + line-through. List `<ul style="padding:0">`; sort pending first then by date. Overdue date text may use `--coral-txt`, today `--ambar-txt`; no coloured backgrounds on rows.

## Charts (hand-written SVG, no libraries)

Shared CSS:
```css
.graf{position:relative;margin-top:14px;min-height:120px}
.graf svg{display:block;max-width:100%;overflow:visible}
.graf text{font-family:var(--sans);font-size:11.5px;fill:var(--tinta-3);font-variant-numeric:tabular-nums}
.g-lin{stroke:var(--linea);stroke-width:1}                           /* gridlines + crosshair base */
.g-cpu{fill:none;stroke:var(--coral);stroke-width:2.4;stroke-linecap:round}
.g-mem{fill:none;stroke:var(--tinta-2);stroke-width:1.8;stroke-linecap:round;stroke-dasharray:5 6}
.g-area{fill:var(--coral);fill-opacity:.14}
.trazo{stroke-dasharray:1;stroke-dashoffset:1;animation:trazo 1.2s var(--muelle) forwards}   /* needs pathLength="1" on the path */
.g-mem.trazo{stroke-dasharray:none;animation:fund 1s .3s backwards}
@keyframes trazo{to{stroke-dashoffset:0}}
@keyframes fund{from{opacity:0}}
.g-area{animation:fund 1s .2s backwards}
.leyenda{display:flex;gap:16px;font-size:12.5px;color:var(--tinta-2);align-items:center}
.leyenda i{display:inline-block;width:18px;height:3px;border-radius:9px;margin-right:6px;vertical-align:middle}
```
Conventions: render into a `.graf` box using `box.clientWidth` (skip if 0 = hidden view; re-render on view show and on `resize`), `W=Math.max(280,box.clientWidth)`, SVG `width/height/viewBox` set, `role="img"` + descriptive `aria-label`, gridlines `.g-lin`, y-labels right-aligned at `x=pl-8`, `y=Y(v)+4`. Primary series coral, secondary series ink-grey dashed. One filled area max, `fill-opacity:.14`, flat colour (no gradient).

### Tooltip (glass)
```css
.tip{position:fixed;z-index:30;pointer-events:none;padding:10px 14px;border-radius:var(--r-s);font-size:12.5px;line-height:1.5;
  opacity:0;transform:translateY(6px) scale(.92);transition:opacity .15s,transform .35s var(--muelle);
  background:var(--vidrio-hoja);-webkit-backdrop-filter:blur(20px);backdrop-filter:blur(20px);border:1px solid var(--borde);box-shadow:var(--sombra);white-space:nowrap}
.tip.on{opacity:1;transform:none}
.tip b{display:block;font-weight:600;margin-bottom:2px}
.tip .punto{width:8px;height:8px;margin-right:6px}
.tip span.v{font-variant-numeric:tabular-nums;font-weight:600}
```
```html
<div class="tip" id="tip" role="tooltip"></div>
```
```js
const tip=document.getElementById('tip');
function mostrar(html,x,y){tip.innerHTML=html;tip.classList.add('on');const w=tip.offsetWidth,h=tip.offsetHeight;
  tip.style.left=Math.min(innerWidth-w-8,Math.max(8,x-w/2))+'px';let t=y-h-16;if(t<8)t=y+20;tip.style.top=t+'px'}
const ocultar=()=>tip.classList.remove('on');
```
Tooltip body: bold title line, then one `div` per series with a coloured `.punto` (inline `background:var(--coral)`), label, and `<span class="v">` value with tabular figures. Bind both `pointermove` and `pointerdown` (touch), hide on `pointerleave`; also hide on view change and Esc.

### Line / area chart with range selector
Range selector is a `.seg` segmented control (see `glass-controls`): `<div class="seg" id="seg-rango" role="group" aria-label="Rango de tiempo"><button data-v="1h" aria-pressed="false">1 h</button><button data-v="24h" aria-pressed="true">24 h</button><button data-v="7d" aria-pressed="false">7 d</button></div>`; on change set `rango` and call `lineChart()`.

```js
const RANGOS={'1h':{n:60,step:1,sd:3},'24h':{n:48,step:30,sd:7},'7d':{n:56,step:180,sd:11}};  // n points, step minutes
let rango='24h';
// deterministic demo series (replace with real data, values 0..100)
function serie(n,base,amp,seed){let s=seed;const r=()=>{s=(s*16807)%2147483647;return s/2147483647};let v=base;
  return Array.from({length:n},(_,i)=>{v+=(r()-.5)*amp;v+=(base-v)*.15;return Math.max(4,Math.min(96,v+Math.sin(i/5)*amp*.4))})}
function lineChart(){
  const box=$('#grafico-carga'),c=RANGOS[rango];if(!box.clientWidth)return;
  const W=Math.max(280,box.clientWidth),H=240,pl=36,pr=8,pt=12,pb=28,n=c.n;
  const cpu=serie(n,34,18,c.sd),mem=serie(n,62,6,c.sd+2);
  const X=i=>pl+(W-pl-pr)*i/(n-1),Y=v=>pt+(H-pt-pb)*(1-v/100);
  // smooth path: cubic Bezier with horizontal tangents at the midpoint between points
  const ruta=d=>d.map((v,i)=>{if(!i)return`M${X(0).toFixed(1)},${Y(v).toFixed(1)}`;const m=(X(i-1)+X(i))/2;return`C${m.toFixed(1)},${Y(d[i-1]).toFixed(1)} ${m.toFixed(1)},${Y(v).toFixed(1)} ${X(i).toFixed(1)},${Y(v).toFixed(1)}`}).join('');
  let g='';[0,25,50,75,100].forEach(v=>g+=`<line class="g-lin" x1="${pl}" x2="${W-pr}" y1="${Y(v)}" y2="${Y(v)}"/><text x="${pl-8}" y="${Y(v)+4}" text-anchor="end">${v}%</text>`);
  [[0,'start'],[Math.round((n-1)/3),'middle'],[Math.round(2*(n-1)/3),'middle'],[n-1,'end']].forEach(([i,a])=>g+=`<text x="${X(i)}" y="${H-6}" text-anchor="${a}">${atras((n-1-i)*c.step)}</text>`);
  box.innerHTML=`<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Gráfico de carga de CPU y memoria, rango ${rango}">${g}
   <path class="g-area" d="${ruta(cpu)}L${X(n-1)},${Y(0)}L${X(0)},${Y(0)}Z"/>
   <path class="g-mem trazo" d="${ruta(mem)}"/><path class="g-cpu trazo" pathLength="1" d="${ruta(cpu)}"/>
   <g id="ch" style="display:none"><line class="g-lin" id="ch-l" y1="${pt}" y2="${H-pb}" style="stroke:var(--tinta-3)"/><circle id="ch-a" r="5" fill="var(--coral)" stroke="var(--fondo)" stroke-width="2"/><circle id="ch-b" r="4.5" fill="var(--tinta-2)" stroke="var(--fondo)" stroke-width="2"/></g>
   <rect x="${pl}" y="0" width="${W-pl-pr}" height="${H-pb}" fill="transparent" id="ch-r"/></svg>`;
  const svg=$('svg',box),ch=$('#ch',box);
  const mover=e=>{const b=svg.getBoundingClientRect();let i=Math.round((e.clientX-b.left-pl)/(W-pl-pr)*(n-1));i=Math.max(0,Math.min(n-1,i));
    ch.style.display='';$('#ch-l',box).setAttribute('x1',X(i));$('#ch-l',box).setAttribute('x2',X(i));
    $('#ch-a',box).setAttribute('cx',X(i));$('#ch-a',box).setAttribute('cy',Y(cpu[i]));$('#ch-b',box).setAttribute('cx',X(i));$('#ch-b',box).setAttribute('cy',Y(mem[i]));
    mostrar(`<b>${atras((n-1-i)*c.step)}</b><div><i class="punto" style="background:var(--coral)"></i>CPU <span class="v">${fmt(cpu[i],1)} %</span></div><div><i class="punto" style="background:var(--tinta-2)"></i>Memoria <span class="v">${fmt(mem[i],1)} %</span></div>`,e.clientX,b.top+Y(Math.min(cpu[i],mem[i])))};
  const r=$('#ch-r',box);r.addEventListener('pointermove',mover);r.addEventListener('pointerdown',mover);
  r.addEventListener('pointerleave',()=>{ch.style.display='none';ocultar()});
}
```
Geometry: plot padding `pl=36 pr=8 pt=12 pb=28`, height 240; `X(i)` linear in index, `Y(v)` linear inverted. Crosshair = vertical line in `--tinta-3` + one 5px dot per series stroked with `var(--fondo)` 2px. Hit area = transparent rect over the plot. Helpers `$ = (s,r=document)=>r.querySelector(s)`, `$$ = ...querySelectorAll`.

### Bar chart (income vs expense)
```css
.b-ing{fill:var(--tinta)}.b-gas{fill:var(--coral)}
.barg rect{transform-box:fill-box;transform-origin:bottom;animation:crece .9s var(--muelle) backwards;animation-delay:calc(var(--i)*70ms)}
@keyframes crece{from{transform:scaleY(0)}}
.barg:hover rect,.barg.hov rect{opacity:.8}
```
```js
const meses=['Jun','Jul','Ago','Sep','Oct','Nov'],ing=[2100,2000,2250,2000,2380,2000],gas=[1650,1720,1900,1580,1820,1842];
function barChart(){
  const box=$('#graf-barras');if(!box.clientWidth)return;
  const W=Math.max(280,box.clientWidth),H=250,pl=44,pr=6,pt=10,pb=28,max=2500,Y=v=>pt+(H-pt-pb)*(1-v/max),gw=(W-pl-pr)/6;
  let g='';[0,500,1000,1500,2000,2500].forEach(v=>g+=`<line class="g-lin" x1="${pl}" x2="${W-pr}" y1="${Y(v)}" y2="${Y(v)}"/><text x="${pl-8}" y="${Y(v)+4}" text-anchor="end">${fmt(v)}</text>`);
  const bw=Math.min(26,gw/3);
  meses.forEach((m,i)=>{const cx=pl+gw*i+gw/2;
    g+=`<g class="barg" style="--i:${i}" data-i="${i}"><rect x="${gw*i+pl+gw/2-bw-3}" y="${Y(ing[i])}" width="${bw}" height="${Y(0)-Y(ing[i])}" rx="${Math.min(12,bw/2)}" class="b-ing"/><rect x="${cx+3}" y="${Y(gas[i])}" width="${bw}" height="${Y(0)-Y(gas[i])}" rx="${Math.min(12,bw/2)}" class="b-gas"/><rect x="${pl+gw*i}" y="0" width="${gw}" height="${H-pb}" fill="transparent" style="animation:none"/></g><text x="${cx}" y="${H-7}" text-anchor="middle">${m}</text>`});
  box.innerHTML=`<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" role="img" aria-label="Ingresos y gastos de los últimos seis meses">${g}</svg>`;
  $$('.barg',box).forEach(gp=>{const i=+gp.dataset.i;
    const f=e=>{gp.classList.add('hov');mostrar(`<b>${meses[i]}</b><div><i class="punto" style="background:var(--tinta)"></i>Ingresos <span class="v">${fmt(ing[i])} €</span></div><div><i class="punto" style="background:var(--coral)"></i>Gastos <span class="v">${fmt(gas[i])} €</span></div><div>Ahorro <span class="v">${fmt(ing[i]-gas[i])} €</span></div>`,e.clientX,e.clientY)};
    gp.addEventListener('pointermove',f);gp.addEventListener('pointerdown',f);gp.addEventListener('pointerleave',()=>{gp.classList.remove('hov');ocultar()})});
}
```
Income = ink (`--tinta`, flips in dark), expense = coral. Bars have fully rounded tops (`rx=min(12,bw/2)`), pair gap 6px, group slot `gw`, bars grow from the baseline with a 70ms stagger. Put a `.leyenda` (18x3px pills) in the card header.

### Donut with legend and hover growth
```css
.seg-d{fill:none;stroke-width:22;transition:stroke-width .35s var(--muelle),opacity .3s;cursor:pointer}
.seg-d:hover{stroke-width:28}
.donut-w{display:flex;gap:24px;align-items:center;flex-wrap:wrap;justify-content:center}
.donut-w svg{animation:gira .9s var(--muelle) backwards}
@keyframes gira{from{opacity:0;transform:rotate(-40deg) scale(.8)}}
.leg{flex:1;min-width:180px}.leg .fila{padding:9px 0}
.leg .punto{width:11px;height:11px;border-radius:5px}
.dn{font-size:26px;font-weight:600;font-variant-numeric:tabular-nums;fill:var(--tinta)!important}   /* center total: sans, never serif */
```
```js
const cats=[['Vivienda',620,'--c1'],['Comida',410,'--c2'],['Ocio',264,'--c3'],['Transporte',218,'--c4'],['Otros',330,'--c5']];
function donut(){
  const tot=cats.reduce((a,c)=>a+c[1],0),r=70,C=2*Math.PI*r;let acc=0,s='';
  cats.forEach((c,i)=>{const l=c[1]/tot*C;s+=`<circle class="seg-d" data-i="${i}" cx="100" cy="100" r="${r}" stroke="var(${c[2]})" stroke-dasharray="${Math.max(0,l-3).toFixed(1)} ${(C-l+3).toFixed(1)}" stroke-dashoffset="${(-acc).toFixed(1)}" transform="rotate(-90 100 100)"/>`;acc+=l});
  $('#graf-donut').innerHTML=`<svg width="200" height="200" viewBox="0 0 200 200" role="img" aria-label="Gastos por categoría, total ${fmt(tot)} euros">${s}<text class="dn" x="100" y="102" text-anchor="middle">${fmt(tot)}</text><text x="100" y="124" text-anchor="middle">€ en noviembre</text></svg>`;
  $('#leyenda').innerHTML=cats.map(c=>`<div class="fila"><i class="punto" style="background:var(${c[2]})"></i><span class="n">${c[0]}</span><span class="amt">${fmt(c[1])}<small>€</small></span><span class="m" style="width:38px;text-align:right">${Math.round(c[1]/tot*100)}%</span></div>`).join('');
  $$('.seg-d').forEach(d=>{const c=cats[+d.dataset.i];const f=e=>mostrar(`<b>${c[0]}</b><div><span class="v">${fmt(c[1])} €</span> · ${fmt(c[1]/tot*100,1)} %</div>`,e.clientX,e.clientY);
    d.addEventListener('pointermove',f);d.addEventListener('pointerdown',f);d.addEventListener('pointerleave',ocultar)});
}
```
Geometry: viewBox 200, centre (100,100), r=70, `C=2πr`; each arc `dasharray="(len-3) (C-len+3)"` (3-unit gap), `dashoffset=-accumulated`, rotated -90deg so it starts at 12 o'clock; stroke 22 -> 28 on hover with spring. Legend rows use rounded-square 11px dots coloured by the same `var(--cN)`.

## Skeleton loading (glass)

```css
.sk{position:relative;overflow:hidden;border-radius:var(--r-s);background:var(--interior);height:14px}
.sk::after{content:"";position:absolute;inset:0;transform:translateX(-100%);background:linear-gradient(90deg,transparent,var(--reflejo),transparent);opacity:.55;animation:brilla 1.4s infinite}
:root[data-tema="oscuro"] .sk::after{opacity:.16}
@keyframes brilla{to{transform:translateX(100%)}}
.sk.g{height:46px;width:60%;border-radius:18px;margin:14px 0 10px}   /* big-number placeholder */
.sk.b{height:150px;border-radius:var(--r-m);margin-top:10px}          /* chart placeholder */
```
```html
<div class="rejilla" id="fin-skel" aria-busy="true" aria-label="Cargando finanzas">
  <section class="card vidrio c-4"><div class="sk" style="width:40%"></div><div class="sk g"></div><div class="sk" style="width:55%"></div></section>
  <section class="card vidrio c-8"><div class="sk" style="width:30%"></div><div class="sk b"></div></section>
  <section class="card vidrio c-12"><div class="sk" style="width:25%"></div><div class="sk" style="margin-top:20px;height:40px"></div><div class="sk" style="margin-top:12px;height:40px"></div></section>
</div>
```
Skeletons keep the real card layout (same grid spans) inside real `.vidrio` cards, so nothing jumps. The shimmer is a white glint (`--reflejo`), never a coloured gradient. Swap to real content (`hidden` toggle) and stagger entrance: `.rejilla>*{animation:ent .75s var(--muelle) backwards;animation-delay:calc(var(--i,0)*45ms)}` with `style.setProperty('--i',index)`. Respect `prefers-reduced-motion` by disabling the shimmer.

## Empty state

```css
.vacio{text-align:center;padding:34px 10px}
.vacio .ib{width:64px;height:64px;font-size:28px;border-radius:24px;margin-bottom:14px}
.vacio h3{font-size:18px;font-weight:600}
```
```html
<div class="vacio" hidden><span class="ib"><!-- line svg icon --></span><h3>Nada por aquí</h3>
  <p class="sub">No hay tareas que coincidan con el filtro o la búsqueda.</p>
  <div class="btns" style="justify-content:center"><button class="btn sec">Limpiar filtros</button></div></div>
```
Icon tile + sans heading (18px/600, NOT serif) + one muted line + at most one secondary button. Toggle with `list.hidden=!!items.length` style logic. Charts with no data show the same pattern inside `.graf`.

## Do

- Glass card per metric; one big number, one unit, one sub line, optionally one bar.
- Status via 9px dot + chip text colour; severity text via `--verde-txt/--ambar-txt/--coral-txt`.
- Re-read colours through variables so the theme toggle needs no chart re-render (re-render only for size).
- `aria-label` on every SVG chart; `<caption class="sr">` and `scope="col"` on tables; `role="checkbox"` + `aria-checked` on `.chk`.
- Make rows keyboard-reachable (`tabindex="0"` + Enter) when clickable.

## Don't

- Don't put serif on any number, percentage, chart label or donut total.
- Don't use green/amber/red as card, row, bar or panel backgrounds; don't make the progress fill green.
- Don't add hover (colour, lift, shadow) to cards, panels, list rows or table rows; hover only on controls and inside `@media(hover:hover)`.
- Don't use chart libraries, emoji, blob/gradient backgrounds, more than 5 donut categories, or more than 2 solid panels per screen.
- Don't hard-code hex colours in chart SVG; don't forget `esc()` on user text in `innerHTML`.
- Don't mix grouping styles; always `es-ES` with `useGrouping:'always'`.

Related skills: glass-design (hub), glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion.
