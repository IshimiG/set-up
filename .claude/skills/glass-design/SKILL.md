---
name: glass-design
description: Hub skill for the user's own UI design system ("glass style", "liquid glass", "our panel style", "estilo cristal"). Use it whenever the user asks to design, build, restyle, mock up or review any UI — panel, dashboard, web page, app screen, component, landing, artifact — in their style, or says "design it like our panel", or whenever a UI task has no other style instruction. It states the non-negotiable rules of the system (warm cream/coral palette, light+dark themes, Apple-style liquid glass surfaces, plain grain background, solid coral/ink panels only for important items, very rounded corners, sans type with serif only for highlighted titles and never for numbers, spring motion, hover on controls but never on containers) and routes to the component skills glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data and glass-motion. Read this first, then load only the component skills the task needs.
---

# glass-design — hub

The user's approved visual system, defined in ~10 rounds of feedback on 2026-11-11. It mixes the **palette of demo B** (warm cream, coral, forest green, amber) with the **material and components of demo F** (Apple-style liquid glass).

A complete working reference lives in this skill: `reference/demo-complete.html` (single file, no dependencies; open it with `xdg-open`). **When in doubt, copy from the reference rather than inventing.**

## The rules (non-negotiable)

1. **Themes:** light AND dark, always, with a toggle. Light is the default look; both must be polished.
2. **Palette:** cream `#EEECE8` base, coral `#EC5B34` is THE accent. Forest green and amber exist only as status dots, chips and text. Never add new hues.
3. **Material:** every surface is liquid glass (blur + saturate, light border, inner top reflection) **except** solid panels.
4. **Solid panels:** only **coral** or **ink**, only for the single most important/actionable item, **max 2 per screen**. They have a gradient with a light corner, visible grain, a coloured halo shadow, an icon badge top-right and a translucent chip. Green/amber panels are forbidden.
5. **Background:** plain base colour + subtle grain + a soft light from the top. **Forbidden:** blurred colour blobs, colour gradients, geometric shapes, photos.
6. **Corners:** very rounded — cards ~40px, inner elements 24px, controls pill (99px), sheets 44px top radius.
7. **Typography:** sans for everything. Serif (Instrument Serif) **only** for highlighted page/sheet titles. **Never** serif for numbers or percentages: they are semi-bold sans with tabular figures and a small unit beside them. Mono only for technical data (IDs, ports, logs, commands).
8. **Hover:** buttons and controls get hover (lift + brightness/halo, spring ease). **Containers never do** — cards, panels, table rows, list rows stay still. Hover only inside `@media(hover:hover)`.
9. **Overlays:** anything that opens (sheet, menu, popover, toast, modal) closes on **outside click and Esc**, and animates elastically in both directions.
10. **Motion:** spring/elastic easing, symmetric open/close, respect `prefers-reduced-motion`.
11. **Icons:** inline SVG, line style, stroke 1.6, round caps/joins, inside rounded badges. No emojis, no icon fonts.
12. **Delivery:** single self-contained HTML/CSS/JS unless the target project dictates otherwise; no CDN needed for the style. Responsive down to 360px; the nav stays a bottom floating pill on mobile.

## Routing — which skill to load

| Task involves | Load |
|---|---|
| any new UI (colours, radii, fonts, spacing, theme variables) | `glass-tokens` |
| page background, glass cards, solid coral/ink panels | `glass-surfaces` |
| buttons, chips, inputs, toggles, checkboxes, segmented control, hover | `glass-controls` |
| page shell, header, grid, floating nav pill, view switching, theme toggle | `glass-navigation` |
| sheets, menus, popovers, toasts, tooltips, modals, close-on-outside | `glass-overlays` |
| metric cards, tables, lists, charts, skeletons, empty states, status colours | `glass-data` |
| animations, springs, reduced motion, icons | `glass-motion` |

A full screen/dashboard needs all of them: start with `glass-tokens` + `glass-surfaces`, then add per component. A single component usually needs tokens + that component's skill.

## Workflow

1. Load this hub, then `glass-tokens` and the component skills that apply.
2. Start from the reference demo's CSS variables and component CSS; do not re-derive values.
3. Build light AND dark from the first draft.
4. Before finishing, run the checklist below.
5. For large builds, delegate pieces to subagents (Sonnet to code, Haiku to read) and verify yourself.

## Final checklist

- [ ] Both themes look right; toggle works.
- [ ] Background is plain + grain + soft top light (no blobs/shapes/colour gradients).
- [ ] At most 2 solid panels, each coral or ink, each important/actionable.
- [ ] No serif on any number or percentage; serif only on highlighted titles.
- [ ] Controls have hover (in `@media(hover:hover)`); no container has hover.
- [ ] Everything that opens closes on outside click and Esc; open and close are both animated.
- [ ] Corners match the radius scale; icons are line SVG; no emojis.
- [ ] `prefers-reduced-motion` handled; focus-visible rings present; icon-only buttons have aria-labels.
- [ ] Works at 360px wide.

## Extending the system

New decisions the user gives (a colour, a component, a rule) go into the **component skill file** they belong to (durable rules live in the skill), and are logged wherever the user keeps their design notes. Never silently deviate from these rules; if a task seems to need an exception, ask the user.

## Related skills

glass-tokens, glass-surfaces, glass-controls, glass-navigation, glass-overlays, glass-data, glass-motion.
