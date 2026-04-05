---
task: FP-43177
title: "Refinement of the price adjustment tool"
status: in-progress
assignee: Stanislav Samoilov
area: product-local-prices
created: 2026-04-01
---

## Status

Algorithm approved by GD, implementation spec written. Next: implementation plan and coding.

## Summary

Enhance price calculation logic in WebAdmin tables "Editing table: RegionalPriceRates" and "Editing table: VW_ProductLocalPrices" to improve original price / discount price computation for different regions and currencies. Requirements documented in an external Google Sheets spec.

## Artifacts

- [Smart Beautify v1](artifacts/smart-beautify-v1.md) — approved algorithm: three-tier beautification with 3% deviation guard, auto-direction by coefficient
- [Deprecated Fields](artifacts/deprecated-fields.md) — RoundingAmount, RoundingType, Beautify: kept in schema, removal deferred
- [Implementation Spec](artifacts/implementation-spec.md) — method signature, callers, UI changes, testing strategy

## Plan

See [implementation-spec.md](artifacts/implementation-spec.md).

## Milestones
