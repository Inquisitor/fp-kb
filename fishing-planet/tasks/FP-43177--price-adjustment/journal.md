---
task: FP-43177
title: "Refinement of the price adjustment tool"
status: completed
assignee: Stanislav Samoilov
area: product-local-prices
created: 2026-04-01
---

## Status

Completed. Phase 1: Smart Beautify algorithm (three-tier, 3% deviation guard). Phase 2: Exchange Rate Snapshot (manual rate management, saved rate replaces MonetizationCache for pricing). Committed r15959–r15973 (Phase 1), r15997+r15999 (Phase 2). All merged to MFT.

## Summary

Enhance price calculation logic in WebAdmin tables "Editing table: RegionalPriceRates" and "Editing table: VW_ProductLocalPrices" to improve original price / discount price computation for different regions and currencies. Requirements documented in an external Google Sheets spec.

## Artifacts

- [Smart Beautify v1](artifacts/smart-beautify-v1.md) — approved algorithm: three-tier beautification with 3% deviation guard, auto-direction by coefficient
- [Deprecated Fields](artifacts/deprecated-fields.md) — RoundingAmount, RoundingType, Beautify: kept in schema, removal deferred
- [Implementation Spec](artifacts/implementation-spec.md) — Phase 1: method signature, callers, UI changes, testing strategy
- [Exchange Rate Snapshot Spec](artifacts/exchange-rate-snapshot-spec.md) — Phase 2: manual exchange rate management, snapshot from live rates
- [Exchange Rate Snapshot Plan](artifacts/exchange-rate-snapshot-plan.md) — Phase 2: implementation plan (9 tasks)

## Plan

See [implementation-spec.md](artifacts/implementation-spec.md).

## Milestones

- 2026-04-02: Algorithm design approved by GD (Smart Beautify v1)
- 2026-04-05: Core implementation — new algorithm, callers updated, UI columns hidden, tests green (53/53)
- 2026-04-06: Committed r15959 (LBM), merged to MFT r15960, JIRA commented
- 2026-04-06: UI improvements — Deviation column (signed %, red/bold >3%), Details trace, BaseAmount locale fix. Committed r15961, merged r15962
- 2026-04-06: ProductLocalPrices UI — Select All checkbox, page sizes 200/500/1000, column styling. Committed r15969, merged r15970
- 2026-04-07: MaxJsonDeserializerMembers 1000→5000 in all WebAdmin configs (48 files). Committed r15973, merged r15974
- 2026-04-13: Reopened for Phase 2 — Exchange Rate Snapshot. Design spec approved
- 2026-04-13: Phase 2 implemented. Committed r15997 (LBM), merged r15998 (MFT). JIRA commented
- 2026-04-13: Build fix — removed Groupable(false) incompatible with build server Kendo. Committed r15999 (LBM), merged r16000 (MFT)
