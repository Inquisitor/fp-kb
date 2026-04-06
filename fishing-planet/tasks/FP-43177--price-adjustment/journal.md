---
task: FP-43177
title: "Refinement of the price adjustment tool"
status: completed
assignee: Stanislav Samoilov
area: product-local-prices
created: 2026-04-01
---

## Status

Completed. Smart Beautify algorithm (Gold/Silver/Bronze tiers) implemented in `LocalPriceCalculator`, all callers updated, deprecated fields hidden, Deviation + Details columns added to RegionalPriceRates grid, locale fix applied. Committed r15959+r15961 (LBM), merged r15960+r15962 (MFT).

## Summary

Enhance price calculation logic in WebAdmin tables "Editing table: RegionalPriceRates" and "Editing table: VW_ProductLocalPrices" to improve original price / discount price computation for different regions and currencies. Requirements documented in an external Google Sheets spec.

## Artifacts

- [Smart Beautify v1](artifacts/smart-beautify-v1.md) — approved algorithm: three-tier beautification with 3% deviation guard, auto-direction by coefficient
- [Deprecated Fields](artifacts/deprecated-fields.md) — RoundingAmount, RoundingType, Beautify: kept in schema, removal deferred
- [Implementation Spec](artifacts/implementation-spec.md) — method signature, callers, UI changes, testing strategy

## Plan

See [implementation-spec.md](artifacts/implementation-spec.md).

## Milestones

- 2026-04-02: Algorithm design approved by GD (Smart Beautify v1)
- 2026-04-05: Core implementation — new algorithm, callers updated, UI columns hidden, tests green (53/53)
- 2026-04-06: Committed r15959 (LBM), merged to MFT r15960, JIRA commented
- 2026-04-06: UI improvements — Deviation column (signed %, red/bold >3%), Details trace, BaseAmount locale fix. Committed r15961, merged r15962
