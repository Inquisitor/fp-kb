---
task: FP-43177
title: "Refinement of the price adjustment tool"
status: investigating
assignee: Stanislav Samoilov
area: product-local-prices
created: 2026-04-01
---

## Status

Google Sheets spec analyzed, draft algorithm documented. Awaiting requirement refinement and possible additional features.

## Summary

Enhance price calculation logic in WebAdmin tables "Editing table: RegionalPriceRates" and "Editing table: VW_ProductLocalPrices" to improve original price / discount price computation for different regions and currencies. Requirements documented in an external Google Sheets spec.

## Artifacts

- [Smart Beautify v1](artifacts/smart-beautify-v1.md) — draft algorithm: three-tier beautification with 3% deviation guard, auto-direction by coefficient. Replaces current single-tier `LocalPriceCalculator` logic.

## Plan

TBD — pending requirements refinement.

## Milestones
