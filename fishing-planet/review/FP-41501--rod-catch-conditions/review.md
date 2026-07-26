---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16285, merged to NPN20260602 @ r16286
jira: https://fishingplanet.atlassian.net/browse/FP-41501
---

# Review: FP-41501 — Add RodCategoryId into CatchFishCondition

## Summary

New optional filter fields `RodId`, `RodIds`, `RodCategoryId`, `RodCategoryIds` added to `CatchFishCondition` (and, per the executor, "as a bonus" to `RoomCatchFishCondition`) so catch conditions can filter by the rod item or rod category used for the catch. Requested by GD for Anniversary 2026 mission content; GD (Mary Key) already moved rod-category usage into catch conditions in content (JIRA comment 2026-07-13).

## Scope

- **MFT20260325 r16285** — Add RodId/RodCategoryId filters to catch conditions
  - New fields `RodId`, `RodIds`, `RodCategoryId`, `RodCategoryIds` (all `[JsonProperty]`, nullable/array) in `CatchFishCondition` and `RoomCatchFishCondition` (`FishConditions.cs`) with fail-closed checks in `CheckAdditional`
  - `CaughtFish` carrier fields `RodId`, `RodCategoryId` (`FishCageContents.cs`), populated in `GameProcessor` from `rodConfig.Rod.ItemId` / `(int)rodConfig.Rod.ItemSubType`
  - Unit tests for the new `CatchFishCondition` filters (match/non-match, scalar/array)
- **NPN20260602 r16286** — Merge of r16285

## Investigation Journal

- VCS audit: `svn log | grep FP-41501` over KNW/LBM/MFT/NPN found r16285 on **MFT20260325** (not KNW as the JIRA comment claims) and merge r16286 on NPN (its message confirms source `branches/MFT20260325`). Executor-quality note: JIRA comment mislabels the source branch as KNW.
- Merge-gap hypothesis from intake disproven: the change is on MFT (Content, ships FPA) and merged up to NPN (Code) — coverage complete, no LBM/KNW merge required (upward-only rule).
- WC freshness: WC at r16351 ≥ r16285; local modifications do not intersect the diff's file list — disk reads trustworthy.
- NRE hypothesis on `rodConfig.Rod.ItemId` (new unguarded dereference, unlike sibling `Hook?.ItemId ?? 0`) disproven: pre-existing `line.ItemId` in the same initializer already requires `line != null`, and `line` is only populated in `RefillTackle()` under `rod?.InstanceId != null` (which also sets `rodConfig.Rod = rod`) — the invariant `line != null ⇒ rodConfig.Rod != null` covers all four `GetCaughtFish()` call sites (strike, catch, take-fish, saved-state restore); the catch path additionally dereferences `Rod.ItemId` in `SaveCatch` since before this commit.
- RodCategoryId semantics verified three ways: (a) local Main DB — rod items in `InventoryItems` carry `CategoryId` values 23/24/25/26/27/28/129/130/168/174/175/176/197 (per-category rod subtypes), none carry first-level `Rod=2`; (b) `ItemFactory.cs` maps `result.ItemSubType = (ItemSubTypes)item.Category.CategoryId` — so `(int)ItemSubType` equals the catalog CategoryId GD sees; (c) `AssembleRodCondition` already exposes `RodCategoryId`/`RodCategoryIds` with identical semantics (`(int)r.Rod.ItemSubType == RodCategoryId`) — the new fields reuse an established content-facing name and meaning. Same-class precedent: `LureCategoryId`/`BaitCategoryId` in `CaughtFish` are `(int)ItemSubType` too.
- RoomCaughtFish data flow traced: the single production construction site `GetCaughtFish()` (GameProcessor) feeds both `context.CaughtFish` and `peer.Profile.MissionsContext.RoomCaughtFish` with the same object; cross-server propagation serializes it to JSON (FtgFishCaught broadcast, `sendToClient: false`) and `GameClientPeer_Travel` deserializes into `RoomCaughtFish` — plain int fields survive the round-trip.
- Client-mirror check (Shared/ObjectModel touched): client tree has NO `CatchFishCondition`/`FishConditions.cs` copy at all (condition evaluation is server-only), and the client's `CaughtFish` copy is an intentionally reduced subset that already omits sibling carrier fields (`LureCategoryId`, `BaitCategoryId`, `HookId`, ...) — no mirror needed; extra JSON fields on the wire are the pre-existing status quo.
- Tests executed locally at WC r16351 (`dotnet test --no-build`): `CatchFishConditionTests` 29/29 passed (includes the commit's new rod-filter tests), `RoomCatchFishConditionTests` 4/4 passed.
- Delegated blind hunts (code-reviewer agent + Codex) ran in parallel, no recon findings pre-loaded. Agent: one finding (Room test gap), corroborated recon's null-safety / serialization / call-site conclusions; misattributed the room-broadcast deserialization site to `GameClientPeer_Missions.cs` (actual: `GameClientPeer_Travel.cs`, grep-verified) — not decision-affecting. Codex: leaf-vs-parent category finding (F-1) + test-gap additions (folded into F-2), corroborated restore-path safety via `MultiRodGameProcessor.SetupGameProcessor` assigning `processor.Rod` before `RestoreFish`.
- Re-verified agent's test-gap claim with own instruments: r16285 file list has no `RoomCatchFishConditionTests.cs`; grep for `RodId|RodCategoryId` in that file returns 0 matches. Re-verified `FishCageJson` dedicated persistence column (SqlProfileProvider).
- Re-verified Codex's F-1 claims: `AssembleRodCondition.CheckItem` matches `(int)item.ItemSubType == categoryId || (int)item.ItemType == categoryId` (parent-level supported); same class's `GetAssemblingSlot` is leaf-only (`(int)r.Rod.ItemSubType == RodCategoryId`) — the API is internally inconsistent already. `BaitLureCategoryId` in the same `CheckAdditional` resolves parents via `ResolveInventoryCategory(id).ParentCategoryId`. New rod filters are leaf-only.
- Codex unresolved hypothesis (mixed-version room broadcast mis-evaluation during rolling deploy) recorded as considered, unresolved, not relied upon: FishingTogether room peers are served by one GameServer node (same binary), making the mixed-version scenario implausible, but deployment topology was not verified with a capable instrument.
- Content-usage verification (from GD screenshot, dev WebAdmin): mission `Anniversary15_SanJoaq` (id 3968), Task_4, condition `{ type: 'CatchFishCondition', FishIds: [711, 712], RodCategoryIds: [23, 24], ... }`. Values 23/24 = `TelescopicRod`/`MatchRod` (leaf `ItemSubTypes`), not parent `Rod=2` — empirically confirms F-1's leaf-only semantics are exactly what content configures, and confirms `RodCategoryIds` (array form) is live-consumed by Anniversary content. GD comment "перенесла род категорию в кечкондишн" = migrated rod-category filtering into `CatchFishCondition` using the new field.
- Room-side rod-filter tests authored within this review (mirror of the committed `CatchFishCondition` set, using realistic `ItemSubTypes.SpinningRod/CastingRod/MatchRod/FeederRod` values): built (exit 0) and ran green — `RoomCatchFishConditionTests` 12/12.
- The r16358 test commit was carried to NPN as **r16359** via a **file-level** `svn merge` (chosen to sidestep a mixed-revision WC) — this introduced svn:mergeinfo creep; see the deferred cleanup section below. An earlier claim here that the file carried pre-existing subtree mergeinfo was **wrong** and is superseded by the forensics in that section.

## Findings

### F-1: RodCategoryId filters are leaf-only — parent-level category (2 = Rod) silently never matches [Low]

**Description:** The new `RodCategoryId`/`RodCategoryIds` checks in `CatchFishCondition.CheckAdditional` and `RoomCatchFishCondition.CheckAdditional` (`FishConditions.cs`) compare against `CaughtFish.RodCategoryId`, which `GameProcessor.GetCaughtFish` populates with the leaf `(int)rodConfig.Rod.ItemSubType` only. Sibling category APIs honor parent-level values: `AssembleRodCondition.CheckItem` falls back to `(int)item.ItemType == categoryId`, and `BaitLureCategoryId` in the same `CheckAdditional` resolves parents via `ResolveInventoryCategory(...).ParentCategoryId`. A content author who writes `RodCategoryId: 2` ("any rod", by analogy with `AssembleRodCondition`) gets a condition that never matches instead of a no-op. Practical impact is narrow: for rods the only parent is `Rod=2`, semantically equivalent to omitting the filter; the catalog and admin UI surface leaf values (23–197), and `AssembleRodCondition.GetAssemblingSlot` is itself leaf-only.

Severity-justifying: no practical reason exists to configure a parent-level rod filter ("the rod is a rod"), so the divergence is a latent semantic trap, not a live defect.

**Investigation:**
- Read `CheckItem` (AssembleRodCondition.cs) — target: parent-level match claim; instrument: file read; observed `(int)item.ItemSubType == categoryId || (int)item.ItemType == categoryId`; conclusion: parent-level supported there.
- Read `GetAssemblingSlot` (same file) — observed leaf-only `(int)r.Rod.ItemSubType == RodCategoryId`; conclusion: the precedent API is internally inconsistent, leaf-only comparison has in-class precedent.
- Read `CheckAdditional` fish-bait-lure block (FishConditions.cs) — observed `fishBaitLures` set built with `ParentCategoryId` resolution; conclusion: parent resolution exists in the same method for bait/lure categories.
- Local Main DB query on `InventoryItems` — rod items carry leaf `CategoryId` values (23/24/25/26/27/28/129/130/168/174/175/176/197), none carry `2`; conclusion: leaf values are what content sees in the catalog.
- Live-content confirmation (GD screenshot, dev WebAdmin, mission 3968 Task_4): the shipped condition uses `RodCategoryIds: [23, 24]` (`TelescopicRod`/`MatchRod`, leaf), never the parent `2`; conclusion: the leaf-only limitation cannot bite this content — no live defect.

**Resolution:** Accepted — leaf-only semantics match the nearest precedent (`GetAssemblingSlot`), a parent-level rod filter is semantically vacuous ("the rod is a rod"), and live Anniversary content confirms leaf values are what GD actually configures.

**Discovered by:** Codex.

### F-2: New filter logic in RoomCatchFishCondition has zero test coverage; new tests use unrealistic category values [Low]

**Description:** r16285 duplicates the four rod-filter checks into `RoomCatchFishCondition.CheckAdditional` (copy-pasted, not shared with `CatchFishCondition`), but the new tests cover only `CatchFishCondition`; `RoomCatchFishConditionTests.cs` was not touched (0 `RodId|RodCategoryId` matches). A copy-paste slip in the room variant would go uncaught. Additionally the new tests exercise category value `12` (= `ItemSubTypes.JigBait`, not a rod category) — semantically neutral for int equality but unrealistic — and no test covers the `GetCaughtFish` population side (tests construct `CaughtFish` directly).

**Investigation:**
- r16285 changed-file list (`svn log -v`) — no `RoomCatchFishConditionTests.cs`; conclusion: no room-side tests added.
- Grep `RodId|RodCategoryId` in `RoomCatchFishConditionTests.cs` — 0 matches; conclusion: gap confirmed at HEAD.
- Executed `RoomCatchFishConditionTests` (4/4 green) — existing DragStyle-only coverage unaffected.
- Diff read — room checks are idiom-identical to the tested `CatchFishCondition` ones; risk is future divergence, not present defect.
- Fix authored within this review: added mirror rod-filter tests to `RoomCatchFishConditionTests.cs` (RodId/RodIds/RodCategoryId/RodCategoryIds × match/mismatch), using realistic `ItemSubTypes` (SpinningRod/CastingRod/MatchRod/FeederRod) instead of the `12` (JigBait) placeholder used by the committed CatchFishCondition tests. Built (exit 0), ran green (12/12).

**Resolution:** Room-gap — `Resolved → r16358` (mirror tests authored and committed in this cycle). Unrealistic-value note — addressed in the new room tests; committed `CatchFishCondition` tests left as-is (int equality is value-agnostic). Population-side `GetCaughtFish` coverage — `Pre-existing` / not addressed: requires extracting the equipment-snapshot mapping into a testable helper (out of scope for a test backfill); bubble to `game-processor` module backlog (pending user confirmation).

**Discovered by:** code-reviewer agent (room test gap); Codex (unrealistic values, population-side gap).

## Verdict

**Approve.** The change is a clean, idiom-consistent extension: new rod/rod-category filters mirror the existing scalar/array tackle-filter pattern, fail-closed, no NRE risk on any `GetCaughtFish` call path, JSON round-trip and fish-cage persistence backward-compatible. F-1 (leaf-only category) accepted and empirically confirmed by live Anniversary content (`RodCategoryIds: [23, 24]`). F-2 room-side test gap closed within this review (r16358 → merged NPN r16359); population-side `GetCaughtFish` coverage routed to `game-processor` backlog. LGTM posted 2026-07-26.

Verification scope: patch correctness verified statically + via unit tests (`CatchFishConditionTests` 29/29, `RoomCatchFishConditionTests` 12/12) and live content usage; no runtime/production-telemetry claim was required (feature addition, not a bugfix).

## Notes

- Executor's JIRA comment labels the source branch as KNW; the commit is on MFT20260325 (merge r16286 message and MFT log both confirm). Merge coverage is nevertheless complete for the FPA release (MFT → NPN).
- JIRA status left at `In Review` (resolution already `Done`); no workflow transition performed by the review — team process owns the status move.

## Mergeinfo cleanup (self-inflicted) — resolved r16362

The review's own r16359 merge introduced svn:mergeinfo creep on NPN; fixed in **r16362**.

**What happened.** To carry the r16358 test commit MFT→NPN, a **file-level** `svn merge -c 16358 <MFT-file> <NPN-file>` was used (to dodge a mixed-revision WC error on the root merge). It committed as **r16359** and stamped a 47-line svn:mergeinfo property onto `RoomCatchFishConditionTests.cs`.

**Forensics (who/when/how).**
- `svn propget svn:mergeinfo` at `NPN@16290` (pre-merge) = none; at `NPN@16359` (post-merge) = 47 lines. The MFT **source** file has no explicit mergeinfo at `@16289`/`@16358`/`@HEAD`.
- Origin = **r16359, `stas.samoilov`, 2026-07-23** (this review). No ancient/inherited subtree mergeinfo existed on this file on any branch.
- Mechanism: merging a **single file** whose source only *inherits* root-level mergeinfo causes SVN to materialize that inherited mergeinfo as **explicit subtree mergeinfo** on the target (plus the merged rev). The 47 lines = the MFT branch-root mergeinfo path-rewritten to the file + `16358`.
- Cross-check: the file-vs-root comparison (`cmp_mi.py`) found exactly one file-only rev — `16358` — confirming the other 46 lines are just the root mergeinfo copied down.

**Fix applied (r16362).** After a full `svn update` (once FP-33074 WIP was cleared from the NPN WC):
- `svn merge --record-only --depth empty -c 16358 <MFT-URL> .` — record `16358` on the branch **root only**.
- `svn propdel svn:mergeinfo <file>` — remove the subtree property.
- Committed path-scoped (`<file> . --depth empty`). Verified at HEAD: root mergeinfo carries `16358`, file has no svn:mergeinfo, the room rod tests remain intact.

**Lesson learned:**
- Never carry a commit cross-branch with a **file-level** `svn merge` — always root-level (`svn merge -c <rev> <branch-URL> <branch-WC-root>`). A file/subtree merge materializes the source's inherited root mergeinfo onto the target node as subtree mergeinfo (split-brain). If the root WC is mixed-revision, `svn update` the root first rather than dropping to a file-level merge.
- Even a **root-level** `--record-only` merge WITHOUT `--depth empty` stamps every subtree that *already* carries mergeinfo (observed here on `SQL/Patches`, `InitialSpawnHelper.cs`, and siblings — pre-existing creep on those paths). Use `--record-only --depth empty` to touch the root node only. (First attempt hit this; reverted and redone.)
- Candidate for a `jira-review-close` Step-3 guard.
