---
name: Avoid bare HTML5 semantic tags inside Vue islands in WebAdmin
description: WebAdmin's global Layout.css applies fixed sizes to bare <header>/<footer>/<aside>/<main>; Vue scoped styles do not override the global cascade for the element itself
type: feedback
---
Inside Vue island components embedded in WebAdmin, do **not** use bare HTML5 semantic tags (`<header>`, `<footer>`, `<aside>`, `<main>`, `<nav>`). Use `<div>` with a component-prefixed class instead.

**Why:** `WebAdmin/Content/Layout.css` (and adjacent admin stylesheets) apply global rules like `header { height: 135px }` site-wide. Vue `<style scoped>` produces `[data-v-XXXX]`-prefixed selectors that scope **the component's own rules**; they do not override globally cascading rules that target the element itself. A `<header>` inside a Vue component therefore reserves 135 px of vertical space — visible as a giant gap above the component's content, with no warning. The bug masquerades as «my title bar is huge» rather than as a CSS leak — costly to diagnose without prior awareness. Caught in FP-43579 post-VS4 smoke.

Same risk applies to any element name targeted globally in admin CSS. The tags listed above are the known offenders; if a new global rule lands on another bare element, the same trap reopens.

**How to apply:**

- Title bars / hero sections inside an island: `<div class="<component>-header">` not `<header>`.
- Footers: `<div class="<component>-footer">`.
- Side panels: `<div class="<component>-sidebar">`.
- Nav strips: `<div class="<component>-nav">`.

When in doubt: open DevTools, inspect the element, check the computed-styles "Inherited from" section — if a non-Vue source contributes a height/width/display rule, this trap is active.

**Confirmed offender:** `<header>` (135 px from `Content/Layout.css`). The same rule is captured at the per-tool level in `WebAdmin/Components/AntiCheatTool/README.md`; this KB entry is the WebAdmin-wide promotion.
