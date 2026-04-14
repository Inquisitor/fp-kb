---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43018
---

# FP-43018: Add `BoatMinSaggingDistance` Global Variable

## Status

Complete. Variable added, committed to LBM (r16004), merged to MFT (r16005).

## Summary

### Goal

Add a new global variable `BoatMinSaggingDistance` (int, default 15 meters) to control the minimum distance for fish AI
sagging behavior when fighting from a rod holder on a boat. Part of a fix for an exploit where fish could be caught
instantly without fight.

### What Was Done (server side only)

- Property in `GlobalVariablesCache` (placed in rod stand / boat fishing group near `FishPullingUpSpeed`,
  `MinTimeRodStandSlack`)
- Client relay in `GameClientPeer.GetGlobalVariables()`
- SQL patch `LBM.M.2026.04.14-039 [GlobalVariables] [BoatMinSaggingDistance].sql` — inserts
  `Fishing.BoatMinSaggingDistance` = 15

### Context

- Client-side fix by Maksym Bondarchuk (assignee)
- Variable requested by Andrii Maslov in JIRA comment (2026-04-14)
- DB prefix `Fishing.` stripped by `RemovePrefix()` on load

## Milestones

- 2026-04-14: r16004 (LBM), r16005 (MFT merge) — variable added and merged
