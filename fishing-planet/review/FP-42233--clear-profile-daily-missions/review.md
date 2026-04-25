---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15833
jira: https://fishingplanet.atlassian.net/browse/FP-42233
---

# Review: FP-42233 — DAILY MISSIONS: Clear profile doesn't clear daily missions information

## Summary

Bug fix for the WebAdmin "Clear profile / Reset profile to default" tool: when an admin reset a player's profile, daily-missions context (`DailyMissionJson` column on `Profiles`) was preserved, leaving stale missions on the player after the reset.

## Scope

- **LBM r15833** — Reset player daily mission context on profile reset
  - Added `DailyMissionJson = NULL` to the `UPDATE Profiles` statement in `SqlProfileProvider.ResetProfileToDefault`

## Investigation Journal

- Inheritance check: per KB `_index.md` → Server Branch Ancestry, `MFT20260325` was branched at `LBM:15942`. Fix is on `r15833 ≤ 15942` → already inherited in MFT via `svn copy`; no `svn merge` required, no `Merged → MFT` line in JIRA.
- Verified both admin reset paths converge on this provider method:
  - WebAdmin "Reset Profile to Default" → `ToolsModel_Profile.ResetProfileById` → `IProfileProvider.ResetProfileToDefault`
  - WebAdmin "Reset Profile Keeping Friends" → `ProfileHelper.ResetProfileKeepingFriends` → same provider call
- Verified `DailyMissionJson` is a serialized `ObjectModel.DailyMissions.ProfileContext` (`ProfileHelper.GetDtoOutOfProfile` writes, `ProfileHelper.GetProfileOutOfDto` reads). `ProfileContext` fields without `[JsonIgnore]` (`RecentFish`, `RecentPonds`, `RecentMissions`, `CurrentMissions`, `CurrentMissionDifficulty`, `RegenerationAttempts`, `GenerationTime`) are all part of the JSON; `[JsonIgnore]` only on injected delegates and debug-time properties.
- Initial hypothesis "recent-fish / recent-ponds may live outside `DailyMissionJson`" disproven on a second pass — they are inside the JSON. The JIRA reporter's hedge "якщо не помиляюсь" was indeed mistaken; the single `DailyMissionJson = NULL` covers everything they listed.

## Verdict

LGTM. No findings; fix is complete and minimal.
