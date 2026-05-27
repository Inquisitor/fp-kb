---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16078, r16080, merged to LBM @ r16087
jira: https://fishingplanet.atlassian.net/browse/FP-43707
---

# Review: FP-43707 — [DailyMissions] DailyMissionJson DragStyleConditionSelectionPool fix

## Summary

Some daily missions require catching the target fish by retrieve/trolling (lures), but the
target fish's `DailyMissionJson` advertised non-zero DragStyle / lure-rig weights even for fish
that are only catchable with bait — so the DM generator could pick an impossible "catch by lure"
condition, leaving the mission uncompletable.

The work splits into two parts:
- **Part 1 (r16078)** — fix the generator function `GetFishDailyMissionJson` so it zeroes the
  DragStyle pool and the non-bait rig pool for bait-only fish, plus the re-pour of affected fish
  into prod. Not merged (generator function — see Investigation Journal).
- **Part 2 (r16080)** — fix the NRE that occurs when completing a daily mission task via WebAdmin.
  Merged to Content (LBM). Proper reward-delivery for daily missions tracked in follow-up FP-43757.

## Scope

### MFT (Code)
- **r16078** — Zero DragStyle/non-bait rig pools in DailyMissionJson for bait-only fish
  - SQL function `GetFishDailyMissionJson`: adds `@suppressNonBaitConditions` bait-only detection; clears `@FishDragAttraction`, zeroes `TrollingExpMultiplier`, keeps only bait rigs in `@RigCompatibility`
- **r16080** — Fix NRE on completing a daily mission task via WebAdmin
  - `MissionHelper`: branch on `missionId < 0` (daily) before the `GetMission` call that NRE'd; mark `DailyMission.IsCompleted`, log warning, skip reward; add `?.` on the regular-mission path
  - `Missions.cshtml`: confirm-dialog note for daily missions (reward not granted here)

### LBM (Content, merged)
- **r16087** — Merge of MFT r16080 (byte-identical; clean)

## Investigation Journal

- VCS audit (`svn log | grep`) confirmed r16078 + r16080 on MFT (yuriy.burda), r16087 merge on LBM — matches JIRA comment exactly. Executor field empty in JIRA (hygiene warning, non-blocking).
- Branch-copy inheritance: MFT20260325 forked from LBM20251201 at r15942. r16080 > r15942, so LBM does not inherit via copy — explicit merge r16087 required and present. Merge diff verified byte-identical to r16080.
- r16078 touches the SQL *function* `GetFishDailyMissionJson`, not an "internal tool" as the JIRA comment phrases it. Verified it has no runtime caller: only `WebAdmin/Models/DailyMissions/GeneratorModel.cs` (admin "Generate*" buttons) invokes the wrapping procedure `GenerateFishDailyMissionJson` via `SqlMissionProvider`. Runtime reads the pre-generated `Fish.DailyMissionJson` column. So the prod remedy is the data re-pour; "no need to merge" is defensible for the data fix — but see F-1 for the durability caveat.
- Hypothesis (main concern): the bait-only detection's single-level parent check (`ic.CategoryId <> 10 AND ISNULL(ic.ParentCategoryId,-1) <> 10`) could misclassify fish whose bait categories/items are nested deeper than one level under the Baits root. **DISPROVEN by DB:** the `Baits(10)` subtree is exactly 2 levels — root 10 plus 6 direct children {34,42,43,44,184,188}, no grandchildren. Category check therefore covers the whole bait subtree. Schema check: `DailyMissionFishBaitCategorySettings.FishId` is NOT NULL (no category-level rows → `bcs.FishId = @fishId` needs no fallback); `DailyMissionFishBaitSettings.FishId` is nullable (handled by `FishId IS NULL OR FishId = @fishId`). Predicates correct. (Local dev DB's settings tables are empty, so only structural/schema validation was possible.)
- SQL zeroing verified end-to-end: all 9 DragStyle entries reach weight 0 via the `Match IS NULL → 0` conversion in `RulesNumbered` (non-Trolling via empty `@FishDragAttraction`, Trolling via `@Fish.TrollingExpMultiplier = 0`); non-bait rigs zero via `ISNULL(..., 0)`. The recursive regex replacer substitutes values inside existing JSON objects, so structure stays valid and there is no divide-by-zero / empty-required-pool risk. Cross-checked by an independent code-reviewer agent (same conclusion).
- NRE fix verified: `missionId < 0` daily-mission discriminator is an established convention in the same file (`StartMission` case). Started/completed bookkeeping (`CompletedMissions`, `OnceCompletedMissions`, stats) is updated before the `< 0` sub-branch, so it runs for daily missions too. No double-grant, no new NRE path.

## Findings

### F-1: generator-function fix (r16078) lives only on MFT [Info]

**Description:** `GetFishDailyMissionJson` is a DB-resident function (Main DB) invokable in prod via
the WebAdmin "Generate Fish JSON" admin buttons, so "internal tool" slightly understates it. The fix
lives only on MFT (Code) and is intentionally not merged. The prod remedy is the data re-pour
(`Fish.DailyMissionJson` column, which the runtime reads), so the fix is effective now. A residual
durability edge exists only if the prod function were redeployed from a branch lacking r16078 *and*
an admin then clicked "Generate" — a narrow, deliberate operator sequence.

**Investigation:** Confirmed no runtime caller (only `GeneratorModel.cs` admin actions); runtime reads
the pre-generated column. Deployment source for Main DB functions is not determinable from the diff.

**Resolution:** Accepted — executor's documented "no need to merge" decision rests on the deployment
model (executor's context, not visible in the diff); realistic regression risk is low. No action.

**Discovered by:** skill recon.

### F-2: `dailyMission.IsCompleted = true` is redundant [Info]

**Description:** In `MissionHelper`, the daily-mission branch sets `dailyMission.IsCompleted = true`.
`DailyMissionAdapter` re-derives `IsCompleted` from `MissionsContext.CompletedMissions` at next-day
generation, and the mission's `Code` is already added to `CompletedMissions` unconditionally just
above. The assignment is harmless (and arguably useful for same-session reads) but is not the source
of truth for the flag.

**Investigation:** Surfaced by the code-reviewer agent; consistent with the surrounding bookkeeping.

**Resolution:** Accepted as-is — harmless, no action.

**Discovered by:** code-reviewer agent.

## Verdict

**Approve.** All three commits are correct. The SQL zeroing logic is structurally sound and produces
valid JSON; the bait-only detection predicates are correct given the category-tree shape and table
schemas (main correctness hypothesis disproven by DB verification); the NRE fix is complete and uses
the established `missionId < 0` convention. The cross-branch merge (r16087) is clean.

No blocking issues and nothing to raise in JIRA. F-1 (generator function lives only on MFT) accepted per
the executor's documented "no need to merge" decision; F-2 (redundant `IsCompleted` assignment) is a
harmless info note.
