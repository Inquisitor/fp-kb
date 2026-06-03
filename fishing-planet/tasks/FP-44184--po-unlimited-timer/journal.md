---
jira: FP-44184
status: completed
executor: Stanislav
branch: MFT
related: FP-32370 (PO test coverage / TargetedAdsManager testability — first seam landed here); no TargetedAds module card yet
---

## Status

Completed. Unlimited Personal Offers no longer get a fake 1h element timer: the default was removed in `SwitchPersonalOfferDesignByIndex()`, so an unset `PersonalOffersElementShowTimeoutHours` leaves the offer bound by the campaign `End`. Shipped on MFT (r16139) and merged to NPN/Code (r16140); covered by 4 unit tests (`PersonalOfferDesignTimingTest`) via an `InternalsVisibleTo` seam. JIRA comment 122894; TDD updated to v12. The testability refactor (replace the `InternalsVisibleTo` stopgap) and removal of the dead `NumberOfPersonalOfferShowsPerDay` global are carried by FP-32370.

## Summary

**Bug.** For unlimited Personal Offers (`PersonalOffersChainTimeoutHours` and `PersonalOffersElementShowTimeoutHours` both unset) with `ShowTimer: true`, the client timer showed <1h and the offer re-popped every hour with a fresh 1h timer.

**Root cause.** `SwitchPersonalOfferDesignByIndex()` computed `DesignEndTime = startTime.AddHours(PersonalOffersElementShowTimeoutHours ?? DefaultProductChainElementCooldownHours)` with the constant = `1.0f`. For unlimited offers this imposed a fake 1h element timer: design "expired" hourly -> `ChainEndCooldown` -> immediate restart (no rerun gate) -> re-pop. `DesignEndTime` is exactly what the server sends to the client as the PO timer (`TargetedAdsManager_SendEvent.cs`: `slide.PersonalOfferEnd = personalOffer.DesignEndTime`).

**Key non-obvious finding.** The 1h default was **not** a code deviation — the original TDD ("Personal Offers - Server Technical Design", `/wiki/x/LYCl5Q`) explicitly specifies `ChainElementShowTimeout ... Default 1`. The code constant was merely misnamed (`...CooldownHours`, applied to the show timeout). So removing it is a **deliberate spec change** for unlimited offers, not a pure bugfix. Feature owner confirmed the 1h default is unused and must be removed everywhere.

**Fix.** Drop the default: when `PersonalOffersElementShowTimeoutHours` is unset, leave `DesignEndTime = null`; `AlignPersonalOfferEndTime()` then clamps it to `TargetedAd.End` (campaign end), or leaves it null if no campaign end. Timed offers (explicit `ElementShowTimeoutHours`) are unaffected. Removed the now-unused constant.

**Consequence (documented in code).** Design rotation in the `Active` state is driven by `DesignEndTime` elapsing, so a multi-design chain relies on `ElementShowTimeoutHours` to advance. An unlimited chain only rotates at campaign end; with no campaign end it stays on the first design. Unlimited chains are expected to be single-design.

## Changes

- `Photon/src-server/Loadbalancing/LoadBalancing/GameLogic/TargetedAdsManager_PersonalOffers.cs` — removed the default in `SwitchPersonalOfferDesignByIndex()`; removed the `DefaultProductChainElementCooldownHours` constant; method made `internal static` for testability; added a comment on the multi-design consequence.
- `Photon/src-server/Loadbalancing/LoadBalancing/Properties/AssemblyInternals.cs` (new) — `InternalsVisibleTo("LoadBalancing.Tests")`.
- `Photon/src-server/Loadbalancing/LoadBalancing.Tests/GameLogicTests/PersonalOfferDesignTimingTest.cs` (new) — 4 timing tests (unlimited->End, unlimited-no-End->null, timed, clamp).

## Plan

Remaining work tracked in [backlog.md](backlog.md): commit, JIRA comment, documentation update.

## Milestones

- 2026-06-03: Fix implemented under TDD (4 tests), independently reviewed, green. Testability seam (`InternalsVisibleTo`) is a stopgap tracked by FP-32370.
- 2026-06-03 [MFT r16139]: Committed (TargetedAdsManager_PersonalOffers.cs + AssemblyInternals.cs + PersonalOfferDesignTimingTest.cs). Decision to remove the default confirmed with Mykola Maslennykov (GDD owner). Pending JIRA comment + GDD/TDD doc edits.
- 2026-06-03 [NPN r16140]: Merged r16139 MFT -> NPN (Content -> Code; NPN forked from MFT@16130, so not inherited). Clean merge, byte-identical to the MFT change. NPN full build not run from this session (branch NuGet packages not restored + NU1902 audit gate — pre-existing env, unrelated to the change).
- 2026-06-03: JIRA comment 122894 posted (combined: commit MFT r16139 + merge NPN r16140; tagged Rudakov + Maslennykov; GDD edit requested). TDD finalized to v12 — all PO parameter lists converted to canonical-name tables, "Default 1" removed, dead `NumberOfPersonalOfferShowsPerDay` flagged "not implemented". DB check (dev Main): `NumberOfActivePersonalOffers` = 20; `NumberOfPersonalOfferShowsPerDay` has no code consumer and is absent from GD design — removal queued in FP-32370.
