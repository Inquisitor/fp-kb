---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15901
jira: https://fishingplanet.atlassian.net/browse/FP-42551
---

# Review: FP-42551 — DAILY MISSIONS: Server - Event fish form is counted wrong for daily missions

## Summary

Daily-mission conditions targeting fish *form* (Young / Trophy / Unique) failed to credit progress for event fish even though the chat / UI flagged them as the right form. Root cause: `FishConditions.GetFishForm(string codeName)` derived the form from the last letter of `Fish.CodeName` (`Y` / `T` / `U`). Event fish have arbitrary code names (e.g. `EventBass`), so the suffix carried no signal and the comparison lost.

The fix replaces `codeName.EndsWith(...)` checks with a direct read of `Fish.IsYoung / IsTrophy / IsUnique` flags (which originate from `ServerFish.Status`, set by content authors in `BehaviorJson`). A new `FishStatus FishForm` field is added to `LocalFish` and populated at the three constructor sites that feed mission-related caches. A second `ToMissionRequirementForm(FishStatus)` extension consolidates the enum→requirement mapping; the `LocalFish` overload now delegates to it.

Feature is on the Test environment, not production.

## Scope

- **LBM r15901** — Fix getting fish form for fish. Use settings instead of code name last letter
  - `FishConditions.GetFishForm(Fish)` reads `IsYoung / IsTrophy / IsUnique` instead of `codeName.EndsWith(...)`
  - `LocalFish` gets a new `FishStatus FishForm` property
  - Three `new LocalFish { ... }` sites populate `FishForm`: `FishGenerator.cs`, `BiteSystemCache.cs:223` (PondFishByCode), `RandomizeWeatherModel.DoRandomizeFish`
  - `ObjectModelExtensions.ToMissionRequirementForm(FishStatus)` added; `LocalFish` overload delegates to it
  - 6 new tests in `CatchFishConditionTests.cs`, 3 in `ObjectModelExtensionsTests.cs`, fixtures updated in `TaskBuilderBaseTests.cs`

## Investigation Journal

- VCS audit (`svn log -r 15800:HEAD | grep "FP-42551"`) found exactly the JIRA-listed commit r15901; no unposted commits.
- Generated six hypotheses up-front (regression on legacy LocalFish, coverage of `new LocalFish` sites, `default(FishStatus)`, parallel suffix-based logic, `Fish.IsYoung/IsTrophy/IsUnique` source of truth, `Fish.Status` ↔ `LocalFish.FishForm` typing); each verified before drafting findings.
- Delegated H1–H6 to code-reviewer agent. Cross-checked agent's claims by Read on `LocalFish.cs`, `FishEnums.cs`, `RandomizeWeatherModel.cs`, `BiteSystemCache.cs`, `DailyMissionGenerator_Utils.cs`, `ObjectModelExtensions.cs`, `FishUtils.cs`. Agent identified the correct production sites; key refinement made manually was the HEAD verification below.
- **HEAD verification (per FP-42190 — fix is ~7 weeks old):** `svn log -l 5 -v Shared/SharedLib/DailyMissions/ObjectModelExtensions.cs` revealed r15903 (FP-42549, same author, next day) introduced a `CandidateFish` entity and refactored mission-task building to use it. `LocalFish.ToMissionRequirementForm()` no longer exists on HEAD; `ObjectModelExtensions` extension is now defined on `CandidateFish`. The flag-based `FishConditions.GetFishForm(Fish)` (the primary fix surface) is unchanged on HEAD.
- `[JsonConfig]` semantics inspection: `FishId` is also unattributed, so the attribute is not "runtime vs persisted" but "what goes into one specific config blob". Without this read it would be easy to construct a false regression theory around the new `FishForm` field.
- F-1 → module backlog, F-2/F-3/F-4 routed card-only. None of the findings meet the triage 3-way AND (none are introduced by this commit). Triage file gets zero entries from this review.
- Branch-copy inheritance: r15901 ≤ MFT base r15942 → fix already inherited in MFT, no `svn merge` needed; verify at close-time via `svn log` on a touched file in MFT URL.

## Findings

### F-1: Same suffix-based logic still lives in `DailyMissionGenerator_Utils.GetFishId()` [Low (pre-existing)]

**Description.** `Shared/SharedLib/DailyMissions/DailyMissionGenerator_Utils.cs` → `GetFishId(int fishCategoryId, MissionRequirementFishForm fishForm)` (lines 24–33) selects a fish from a category by `fish.CodeName.EndsWith("Y" | "T" | "U")` — the exact bug shape the commit fixes, but on the **mission-generation** side rather than the credit side. If a category contains a fish whose `Status` is Trophy / Young / Unique without the conventional suffix (e.g. an event fish placed inside a regular `FishCategoryId`), this lookup will not find it and the generator returns `0`.

**Investigation.**
- Grep on `EndsWith("Y"|"T"|"U")` returned eight files. Of them, `DailyMissionGenerator_Utils` is the only one on the daily-missions code path.
- `categoryFish` is sourced from `FishCache.MultilingualFish` (`ServerFish` instances), which carries `Status`. The fix path (`f.Status == FishStatus.Trophy`) is straightforward.
- Other suffix sites are either (a) intentionally code-name-based grouping (`FishUtils.GetFishType` / `GetFishFormSign`, used to collapse `Bass` / `BassY` / `BassT` to a single visual group — event fish like `EventBass` are correctly treated as a separate group), (b) WebAdmin display models (`ItemBreaksModel`, `FishCountModel`, `PondFishTackleLuresModel`), (c) `FishGenerator.cs:464` attraction modifier for unique fish, or (d) `InventoryJsonModifier.BaitAttractionShort.GroupCode` (also a grouping helper). None on the credit path.

**Resolution.** `Pre-existing` — this code shape was in place before r15901 and was not touched by it. Logging in module backlog so re-enablement of event fish in standard categories has the right counterpart on the generator side.

**Discovered by:** code-reviewer agent (H4), verified manually via Grep + file reads.

### F-2: New `LocalFish.FishForm` is not in the `[JsonConfig]` set and is not emitted by `OneLineFishConverter.WriteJson` [Info (latent, superseded)]

**Description.** `Shared/ObjectModel/Fish/LocalFish.cs:17` adds `FishForm` without `[JsonConfig]`, while every other persisted property carries it. `OneLineFishConverter.WriteJson` (same file, 61–72) hard-codes a five-field output (`FishCode`, `Quantity`, `MinWeight`, `MaxWeight`, `Bias`); `FishForm` is dropped on every round-trip through `JsonConfigSerializerSettings` (registered via `Shared/ObjectModel/Serialization/ServerObjectModelBinder.cs:15`). The new field therefore exists only in-memory; deserialised `LocalFish` reverts to `default(FishStatus) = Common`.

**Investigation.**
- Confirmed missing attribute by reading the property block. `FishId` is also unattributed, so the attribute selects what goes into a particular config blob, not what is "persistent". Verified by inspecting `OneLineFishConverter` output spec.
- Possible reach: `RandomizeWeatherModel.DoRandomizeFish` copies `baseFish.FishForm`, and `baseFish` originates from a `WeatherPattern.FishBoxCondition.Fish` list which round-trips through pond config JSON. On the day r15901 landed, this path could in principle feed a `LocalFish` with stale `FishForm = Common` into anything that subsequently calls `LocalFish.ToMissionRequirementForm()`.
- **HEAD-state**: r15903 (FP-42549) replaced `LocalFish.ToMissionRequirementForm()` with `CandidateFish.ToMissionRequirementForm()`; `CandidateFish` is built from `ServerFish.Status` directly without going through the JSON config blob. The latent regression has no surface on HEAD.

**Resolution.** `Skipped` — concern is real on r15901 in isolation but its surface is bounded (mission-task **building**, not credit; credit goes through `Fish` not `LocalFish`) and has been removed by the immediate follow-up r15903. No action needed; recording for completeness.

**Discovered by:** code-reviewer agent (H1), verified via Read of `LocalFish.cs` and HEAD-versioned `ObjectModelExtensions.cs`.

### F-3: `BiteSystemCache.cs:94` builds `LocalFish` for `AllFishForms` without `FishForm` [Info (out of scope)]

**Description.** `BiteSystemCache.InitFishIdsFromMaps` constructs `config.AllFishForms` from `pondMaps.GetAllFish()` with `new LocalFish { FishId, MinWeight, MaxWeight }` — no `FishForm`. This is the second `new LocalFish` site in the same file; only the **other** one (line 223 — `PondFishByCode`) was updated.

**Investigation.**
- `config.AllFishForms` (`ServerLocation.AllFishForms`) is consumed only by `FishGenerator.cs:232` (`DebugFishId` lookup) and `:246` (`rnd.RandomElement(...)`). In both cases only `FishId` is used; the runtime `Fish` is built afterwards with proper `IsTrophy / IsYoung / IsUnique`.
- The same method also builds `formsCount` / `fishFormsCount` through `fish.Status` (lines 110–129), not through `LocalFish.FishForm`, so the per-pond statistics are correct.

**Resolution.** `Skipped` — `FishForm` is not consumed on this path; leaving it `default` causes no functional regression.

**Discovered by:** code-reviewer agent (H2).

### F-4: r15903 (one day later) refactored mission-task building off `LocalFish` onto `CandidateFish` [Info]

**Description.** `svn log -l 5 -v Shared/SharedLib/DailyMissions/ObjectModelExtensions.cs` shows r15903 (FP-42549, Yuriy Burda, 2026-03-10) introduced `CandidateFish` and refactored mission flow off `LocalFish`. On HEAD, `LocalFish.ToMissionRequirementForm()` no longer exists; the active extension is on `CandidateFish`. The primary surface of r15901 — `FishConditions.GetFishForm(Fish)` reading `IsYoung / IsTrophy / IsUnique` — is unchanged.

**Resolution.** `Info` — context note. Reduces the relevance of F-2 / F-3 on HEAD without changing the verdict on r15901 itself.

**Discovered by:** manual HEAD verification per FP-42190 lesson.

## Verdict

**LGTM.** The diff identifies the right root cause and applies the right fix at the credit path (`MatchFishPredicate` → `GetFishForm(Fish)` via flags). New tests cover the three forms and exercise both the suffix-without-flag and flag-without-suffix cross-cases. Auxiliary plumbing on `LocalFish.FishForm` is not load-bearing on HEAD (superseded by r15903) and has no harmful interaction with persisted JSON paths. None of the findings are introduced by this commit; F-1 belongs in module backlog as a pre-existing latent gap on the generator side, F-2 / F-3 / F-4 are card-only.

No triage entries.
