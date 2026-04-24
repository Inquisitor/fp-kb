---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15733, r15734 (inherited by MFT via branch copy)
jira: https://fishingplanet.atlassian.net/browse/FP-41827
---

# Review: FP-41827 — Daily Missions: filter recently-caught by bite system

## Summary

Bug: on catching an event fish, the species could be added to the "recently caught" list used by the Daily Missions generator, so missions could target fish that do not belong to the pond's bite system. Fix gates the `DailyMissionContext.FishCaught(...)` call by `pond.AllFish.Contains(fish.FishId)` — the precomputed bite-system species set for the pond. r15734 is a tangential cleanup: hides the server-only `DailyMissionSettings` from the client-bound JSON.

Current promotion: **Test env only** (LBM/Content), not in Stable. MFT (Code) inherits both commits through its branch-copy from LBM — no `svn merge` needed.

## Scope

- **LBM r15733** — Count fish as recent for daily missions only when it exists in pond bite system
  - Added `if (pond.AllFish.Contains(fish.FishId))` gate before `DailyMissionContext.FishCaught` in `GameProcessor.HandleCatchFish`
  - Migrated `ServerLocation.AllFish` and `Pond.GetAllFishIds()` return type from `int[]` to `HashSet<int>` (O(1) `Contains` in the catch hot path)
  - Adjusted downstream boundaries: `config.AllFish.ToArray()` only where external `int[]`-typed APIs (`pond.FishIds`, `result.FishIds`) require it
- **LBM r15734** — Do not send Daily Mission settings (server data) to client
  - Added `[JsonIgnore]` to `Shared/ObjectModel/Travel/Pond.DailyMissionSettings`

## Findings

### F-1: Bite-system source verified [Info]

**Description.** Fix relies on `ServerLocation.AllFish` being the pond's bite-system set. Confirmed: `GameServerCache.LoadPondConfigurations()` seeds it from `config.LocationFish` + `config.FishBoxes[].Conditions[].Fish` (both FishId > 0). Event fish whose FishId is not in that set will be skipped by the new gate; event fish that share a FishId with a bite-system species will still count — matches the executor's explicit note ("Still allow different fish sources. This will simplify testing with fish set in WebAdmin").

**Investigation.** Traced `AllFish` population in `GameServerCache.cs:356-368`; confirmed `pond` variable in `GameProcessor.HandleCatchFish` is typed `ServerLocation` (`GameProcessor.cs:232`), i.e. the same cached object. Raised a follow-up concern: could `DynamicFishBox` legitimately introduce pond species not captured by `AllFish`? User (project knowledge): `DynamicFishBox` is legacy, surviving only inside the mission system — the bite system replaced boxes as the canonical pond fish source. So `AllFish` fully represents "bite-system species" in current code. Recorded in `missions/log.md`.

**Resolution.** Accepted — no under-counting risk.

**Discovered by.** Skill recon.

### F-2: `int[]` → `HashSet<int>` migration is internally consistent [Info]

**Description.** `ServerLocation.AllFish`, `GameServerCache.config.AllFish`, `Pond.GetAllFishIds()` all moved to `HashSet<int>`; all existing callers work on the new type (`.Count`, `.Contains`, `foreach`, assignment). Two boundary sites where the value exits via `int[]`-typed external fields (`pond.FishIds` in `BiteSystemCache.cs`, `result.FishIds` in `GameServerCache.cs`) correctly convert with `.ToArray()`. Negligible extra allocation at cache-init time.

**Investigation.** Grepped `.AllFish`, `GetAllFishIds()` across the codebase; unrelated namesakes (`MissionDynamicFish.GetAllFishIds`, `DailyMissionsSettings.GetAllFishIds`, `TournamentAdapter.Stats.AllFish`) are distinct types and unaffected.

**Resolution.** Accepted.

**Discovered by.** Skill recon.

### F-3: Commit message under-describes the refactor [Low, Skipped]

**Description.** r15733 commit message mentions only the bite-system gate, not the `int[]` → `HashSet<int>` change touching 5 files.

**Resolution.** Skipped — project style uses one-line commit summaries; internal refactor-detail in the summary is atypical. Too minor to flag.

### F-4: `[JsonIgnore]` is a band-aid for an architectural leak [Low, Filed-candidate]

**Description.** `DailyMissionSettings` lives on `Shared/ObjectModel/Travel/Pond` — the client-visible travel model. r15734 hides it from the wire with `[JsonIgnore]`. The property is still declared on a client-visible class; proper ownership is `ServerLocation` (server-only), matching the pattern set by **r15678 (FP-41626)** which moved other server-only pond properties off `ObjectModel.Pond` onto `ServerLocation`.

**Investigation.** Reviewed r15678 context and grepped `DailyMissionSettings` usages — all server-side (`CachedPondSettingsService`, `GameServerCache`, `ServerFish`); no client-side reader found in the server repo. Test fixtures (`TestPondSettingsService`) already keep the field as a plain property independent of the model class.

**Resolution.** Accepted as-is. User decision: `[JsonIgnore]` achieves the stated goal; overhead of a separate architectural-cleanup ticket outweighs the value. Noted for opportunistic pickup if anyone touches `Travel/Pond` in the future.

**Discovered by.** Skill recon (architectural-precedent check).

## Verdict (draft, not posted)

**LGTM.** Minimal, correct fix. Note that Andrii Smilianets already posted `LGTM` on 2026-02-05 — my approval is the formal assignee sign-off, not a second opinion. No merge line in the JIRA comment: MFT (Code) inherits both commits via branch-copy (MFT was forked from LBM at r15943, after r15734).

## Notes

- **MFT inheritance check.** `svn log .../MFT20260325/Shared/ObjectModel/Travel/Pond.cs` shows r15734 directly in history, before r15943 (FTUE branch creation). `svn mergeinfo` would not show this — documented in the review-workflow draft under "Fix already present in Code branch via branch copy".
- **Stable/OldStable.** KNW (Stable) and IMV (OldStable) do not include r15733/r15734; consistent with the feature being Test-only, not promoted to prod yet.
- **Long review age.** Ticket sat in review 2026-01-29 → today (2026-04-23, ~3 months). Andrii's ad-hoc LGTM was mid-stream; formal assignee review catching up now.
