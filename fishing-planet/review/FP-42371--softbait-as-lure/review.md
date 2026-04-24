---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15869
jira: https://fishingplanet.atlassian.net/browse/FP-42371
---

# Review: FP-42371 — Daily Missions: Server — count SoftBait as Lure

## Summary

Bug fix for Daily Missions equipment matching. Mission tasks requiring `MissionRequirementBaitLure.Lures` previously rejected silicone (soft) baits; the fix extends the match set so any `JigBait` item now satisfies a `Lures` requirement. The pre-existing `SoftBaits` requirement remains scoped to `JigBait` only — asymmetry is intentional and codified by a regression test.

Feature is pre-release (Test environment); `Fix Version = 2026.3 Leaderboards`, scheduled 2026-04-29.

## Scope

- **LBM r15869** — Include JigBaits as proper equipment for mission Lure requirement
  - `Shared/SharedLib/DailyMissions/DailyMissionUtils.cs`: `Lures` switch arm in `CreateTaskConditionCatch` widened from `[Lure]` to `[Lure, JigBait]`
  - Visibility of `CreateTaskConditionCatch`: `private → internal` for test access (`InternalsVisibleTo("SharedLib.Tests")` already configured)
  - New `Shared/SharedLib.Tests/DailyMissions/DailyMissionUtilsTests.cs`: positive test (`Lures_IncludesSoftBaits`) + asymmetry-regression test (`SoftBaits_DoesNotIncludeLures`)

> **Branch routing:** r15869 ≤ MFT base r15942 → MFT (Code) inherits the change via `svn copy`. No explicit merge required, no `Merged → MFT` line in the JIRA comment.

## Findings

### F-1: Two-level naming — SoftBait (concept) vs JigBait (item type) [Info]

**Description:** The codebase uses a deliberate two-level naming scheme for silicone baits, easy to misread as a terminology split:

- **SoftBait** is the GDD-side concept. Used in:
  - `MissionRequirementBaitLure.SoftBaits` (mission requirement enum)
  - `MissionRequirementTackleTemplate.{JigHeadSoftBaitRig, BassJigSoftBaitRig, OffsetHookSoftBaitRig, SpinnerbaitSoftBaitRig}` (rod templates)
  - `UserCompetitionRodEquipmentAllowed.{JigHeadsAndSoftBaits, OffsetHookAndSoftBaits, BassJigsSpinnerbaitsAndSoftBaits, SaltwaterJigHeadsAndSaltwaterSoftBaits}` (tournament rules)
  - SQL: `BassJigSoftBaitRig*` columns and translation terms
  - Test suite: `Shared/ObjectModel.Tests/SoftBaitTests.cs`
- **JigBait** is the inventory-side item type — `ItemTypes.JigBait`, `ItemSubTypes.JigBait`, class `JigBait : Item`. Concrete subtypes (Shad, Worm, Grub, Tube, Craw, Slug, etc.) are what the player sees in inventory.
- Mapping: `MissionRequirementBaitLure.SoftBaits` → `[ItemSubTypes.JigBait]`. Every "SoftBait" concept resolves to item type `JigBait`.

JIRA-summary uses "SoftBait" (concept), commit-msg uses "JigBait" (impl) — both correct on their respective level. Not a mismatch, namespace separation.

**Investigation:** Grepped `JigSoftBait`/`JigheadSoftBait`/`SoftBait`/`soft.?bait` across the codebase. `SoftBaitTests.cs` confirms the model: `var shad = new JigBait { ItemType = IT.JigBait, ItemSubType = IST.Shad };` — `JigBait` is the implementation, `Shad`/`Worm`/etc. are the concrete subtypes.

**Resolution:** Info — design decision, not a bug. Worth surfacing in `modules/missions/_card.md` glossary or `fishing-planet/glossary.md` as an explicit "SoftBait (GDD concept) ↔ JigBait (item type) ↔ Shad/Worm/... (concrete subtypes)" mapping. Not added to triage — no actionable item for the meeting.

**Discovered by:** manual scan.

### F-2: Asymmetric inclusion `Lures ⊇ JigBait` and `SoftBaits ⊉ Lure` is intentional [Info]

**Description:** Post-fix, `Lures` arm = `[Lure, JigBait]`, while `SoftBaits` arm remains `[JigBait]` (does not include `Lure`). Regression test 2 (`CreateTaskConditionCatch_SoftBaits_DoesNotIncludeLures`) explicitly pins the negative direction with `CollectionAssert.DoesNotContain(catchCondition.BaitLureCategoryIds, (int)ItemSubTypes.Lure)`.

**Investigation:** File inspection of the switch and the new test.

**Resolution:** Info — deliberate design. Test 2 guards the contract against future "harmonize the arms" refactors. Not added to triage.

**Discovered by:** skill recon.

## Verdict

LGTM. Pre-release feature in Test environment. No merge required (MFT inherits via branch copy at base r15942).

## Investigation Journal

- 2026-04-24: Card created post-intake, pre-exploration, per updated process draft. (Retrospective creation — original review proceeded before the new process discipline was agreed; card backfilled for paper trail.)
- 2026-04-24: Read `svn diff -c 15869` — scope limited to one production file + one test file.
- 2026-04-24: Verified `[InternalsVisibleTo("SharedLib.Tests")]` is generated in `Shared/SharedLib/obj/Debug/SharedLib.AssemblyInfo.cs` — `internal` visibility is sufficient for the new test.
- 2026-04-24: Read full `MissionRequirementBaitLure` enum and all switch arms in `CreateTaskConditionCatch` — confirmed `SoftBaits` arm exists pre-existing as `[JigBait]`. Asymmetry between `Lures` and `SoftBaits` arms after the fix is intentional (see F-2).
- 2026-04-24: Branch ancestry verified per `_index.md` Server Branch Ancestry: r15869 ≤ MFT base r15942 → inherited via `svn copy`, no merge action needed.
- 2026-04-24: F-1 (terminology) emerged from grepping `JigSoftBait`/`JigheadSoftBait`/`SoftBait`/`soft.?bait` across the codebase — surfaced rod-template, tournament, and SQL usages; together they reveal the two-level naming model rather than a split. Routed as Info; will propose a glossary entry separately if the user approves.
- 2026-04-24: No items routed to triage-file — both findings are Info with no decision pending.
