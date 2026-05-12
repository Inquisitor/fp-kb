# WebAdmin — Change Log

Append-only milestone log. Decisions with rationale + lessons learned. Status fields belong in [_card.md], not here.

## Milestones

- 2026-05-05 [LBM r16063 / MFT r16064]: **First embedded Vue 3 + TS island** (`AntiCheatTool`, FP-43579). Pattern: Razor host page + `<div data-initial-state="...">` mount-point + Vite static asset under `Scripts/vue/<tool>/`, no UI kit (Vuetify's global CSS reset broke admin chrome in prior `TargetedAdsPlanningTool`), scoped styles per component, jQuery-bridge for Kendo widget reuse, custom route ahead of Default (not an MVC Area — see Findings below). Full pattern documented in [embedded-vue-pattern.md](embedded-vue-pattern.md).

## Findings

- 2026-05-05 [FP-43579]: **MVC Areas are an antipattern for admin tools sharing `_Layout` ActionLinks.** Ambient `area` route token strands on root Default route during URL generation — shared layout links (`Html.ActionLink("Home", ...)`) produce `/<Area>/Home/Index` 404 from inside Area context. Partial-fix attempts (`namespaces` constraint, `controller` regex constraint) make it worse. Final fix: drop Area entirely, register a custom route + namespaced controller folder. Codified globally in [feedback/aspnet_mvc_area_ambient_strand](../../../../feedback/aspnet_mvc_area_ambient_strand.md). Affects: any future admin tool considering Areas.

- 2026-05-05 [FP-43579]: **Bare HTML5 semantic tags inside Vue islands inherit admin's global CSS.** `<header>` gets `height: 135px` from `Content/Layout.css`; `<main>/<aside>/<footer>/<nav>` are at similar risk. Vue `<style scoped>` does NOT override globally cascading rules targeting the element itself — only the component's own rules. Use `<div class="<component>-header">` etc. Codified globally in [feedback/vue_island_bare_semantic_tags](../../../../feedback/vue_island_bare_semantic_tags.md).

- 2026-05-05 [FP-43579]: **`LogBase.Find(userId, from, to)` materialises the full user/range slice from Mongo** before client-side filtering. For active-player queries on heavy collections (`fishingLog`), this is a 30-minute wait. Fix: new `LogBase.Find(...)` overload accepting `BsonRegularExpression` pushes the content filter to Mongo. Codified globally in [reference/mongo_logbase_pushdown](../../../../reference/mongo_logbase_pushdown.md). Affects: any admin tool querying `fishingLog` (or similarly volumetric log) by message-kind subset.

- 2026-05-05 [FP-43579]: **Mongo log providers have two semantic kinds** — event-stream (errors, fishing actions, chats) and stateful-snapshot (sys info, IP/MAC changes). Reflex-cloning `Find(userId, from, to)` from one kind to the other returns wrong results (empty when carry-over needed). Codified globally in [feedback/mongo_log_semantics](../../../../feedback/mongo_log_semantics.md). Affects: any admin tool extending log provider Find methods.
