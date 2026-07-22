---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16310, merged to NPN20260602 @ r16311
jira: https://fishingplanet.atlassian.net/browse/FP-44985
---

# Review: FP-44985 — Add Distance parameters to HookFishCondition and CatchFishCondition

## Summary

Mission fish conditions gain distance-based constraints: new fields `MinHookDistance`, `MaxHookDistance`, `MinGenerationDistance`, `MaxGenerationDistance` on Hook/Catch fish conditions, so missions can require fish hooked (or generated) at a specified casting distance. Requested for ANNIVERSARY 2026 content (parent epic FP-41670). QA verified on test server r16350 ("GHENT-TERNEUZEN — Casting Marathon" mission, fish counted correctly from the specified distance).

## Scope

<!-- Intake: commits as listed in JIRA comment 130190, at face value. VCS audit pending (Phase 2). -->

- **MFT20260325 r16310** — Add hook/generation Distance to fish conditions
  - New fields for Catch/Hook conditions: `MinHookDistance`, `MaxHookDistance`, `MinGenerationDistance`, `MaxGenerationDistance`
- **NPN20260602 r16311** — Merge from MFT20260325 r16310

## Investigation Journal

- Intake 2026-07-22: single commit + merge per JIRA comment; executor = Yuriy Burda (Executor field filled, matches commit-comment author). Branch per comment: MFT (Content role, hosts FTUE + 2026.5 Anniversary releases), merged by executor to NPN (Code role).
- Content-ops note in JIRA (comment 131722): with the fix, mission tasks 15741, 15742, 15743, 15744 must be taken from dev — content-side action, not server code scope.
- VCS audit: `svn log 15943:HEAD` on MFT + `16131:HEAD` on NPN grepped for FP-44985 — exactly r16310 (MFT) and r16311 (NPN merge), matches JIRA. No unposted commits. WC at r16351 ≥ r16310 — disk trustworthy, files read directly.
- Metric consistency: generation site sets `GenerationDistance = playerPosition.Distance(terminalTacklePosition)` (`GameProcessor` fish-generation block); hook site sets `HookDistance = distance` where `distance = playerPosition.Distance(terminalTacklePosition)` computed in `HandleAttackFinished` — identical expression, same metric as the pre-existing `SaveFishGenerated`/`SaveFishHooked` stats args. Verified by reading both hunks in context.
- Write-site completeness: grep `\.(GenerationDepth|HookDepth|GenerationDistance|HookDistance)\s*=` over all `*.cs` in the branch — Depth twins are written ONLY at the same GameProcessor sites where the new Distance fields are now written, plus `CopyFishingCycleProperties` (both copied there too). No alternate generation/hook path exists that fills Depth but leaves Distance at default 0.
- Fish replacement on hook: `fish = GenerateHookingFor*(...).CopyFishingCycleProperties(fish)` — extension signature is `(this Fish destination, Fish source)`, so the new fish receives old fish's `GenerationDistance`; `HookDistance` then set on the new fish before `context.Fish = fish` — mission monitoring sees populated values. Verified by reading `HandleAttackFinished` and `FishExtensions`.
- Serialization: `Fish` is `[JsonObject(MemberSerialization.OptOut)]`, new fields carry no `[JsonSkip]` — serialized exactly like the Depth twins (cage persistence, wire). Condition classes are `OptIn` + `[JsonProperty]` on the new fields — configurable from mission JSON like the twins. Verified by reading `Fish.cs` and `FishConditions.cs`.
- `ReleaseFishFromCageInteraction : BaseMissionInteraction, IFishCondition` implements the interface directly — the four new members were compile-forced there; its checks route through the shared `ConditionExtensions.MatchFishPredicate(IFishCondition, Fish)`, which now includes the distance guards. No per-class check logic needed.
- Class hierarchy claim (JIRA title names Hook/CatchFishCondition, diff edits `BaseFishCondition`): grep confirms `HookFishCondition : BaseFishCondition` and `CatchFishCondition : BaseFishCondition` — both inherit the fields and route through `MatchFishPredicate`.
- Client-mirror check (Step 6): client copy `Win64_MainClient/Assets/Photon Server Networking/ObjectModel` has NO `FishConditions.cs` / `ReleaseFishFromCageInteraction.cs` (mission conditions not mirrored at all), and client `Fish.cs` lacks even the Depth twins (grep for `HookDepth|GenerationDepth|HookDistance|GenerationDistance` — no matches). Per-cycle predicate fields are established as server-only; Newtonsoft ignores unknown members (proven by Depth twins living in server OptOut JSON for years without client counterpart). No client mirror needed. Client svn log (last 200 revs) has no FP-44985 paired commit — consistent.
- Admin/test surface: grep `Min/MaxGenerationDepth` over the branch — referenced only in the two condition files touched by the diff; no WebAdmin editor or test enumerates condition fields. Nothing else to update.
- Merge fidelity: `svn diff -c 16311` on NPN — identical file set and hunk structure as r16310 plus root mergeinfo. Faithful merge.
- QA (JIRA comment 131760): verified on Steam qa branch 56582 + test server r16350, mission "GHENT-TERNEUZEN — Casting Marathon" counts fish from the specified distance.
- Delegated blind reviews (code-reviewer agent + Codex, parallel, no recon pre-load): both converged on the restore-path gap (F-1); Codex additionally surfaced legacy-persisted-fish semantics (F-2) and test coverage (F-3). No high-confidence defect in the normal generate→hook→catch→cage flow from either delegate.
- Delegate contradiction resolved: agent claimed `[NoClone]` on `Fish` is inert (no `MakeCloneOf` caller); Codex claimed `TranslateFishCage` relies on it. Verified: `ProfileHelper.TranslateFishCage` runs `c.Fish.MakeCloneOf(templateFish)` over cage / tournament / FishingTogether / restore cages, and `SerializationHelper.MakeCloneOf` skips `[NoClone]` properties — the attribute actively protects instance data from template overwrite. Agent's claim disproven; executor's `[NoClone]` on the new fields is functionally required, not just stylistic symmetry.
- Codex 3D-metric hypothesis (designers may expect gameplay `DistanceToTackle`, not 3D Euclidean): verified `Point3.Distance` = full XYZ Euclidean (`Point3.cs`); the identical expression/value feeds `SaveFishHooked` stats and `FishExperienceCalculator.SetHookingDistance` (XP distance bonus, `CpBonusMinHookingDistance`) — the new fields reuse the game's canonical hooking-distance semantic. Designer-expectation residual empirically settled for the shipped mission by QA (fish counted at the specified distance). Not promoted to a finding.
- Fish replacement coverage: grep `CopyFishingCycleProperties` callers — all four replacement sites (3× `GenerateHookingFor*`, 1× `GenerateCatch`) route through the updated copy method.
- Cage-surface check for F-2: `IFishCondition` implementors are exactly `BaseFishCondition` + `ReleaseFishFromCageInteraction` (grep); `FishCageCondition : BaseFishCondition`, `ReleaseFishFromCageCondition : BaseFishCondition` — cage-evaluating conditions do see the distance fields. Buoy conditions are `IFishBasicPredicate`-only (no distance) — unaffected.
- F-1 routing revised in discussion: reviewer pointed to the known globally-broken relogin restore (fish effectively not restored; area owned by the FP-45122 rework) — resolution changed from backlog-routing to Skipped.

## Findings

### F-1: Reconnect-restored fish reaches distance conditions with default-0 values [Low]

**Description:** `GameProcessor.RestoreFish` → `FishGenerator.RestoreFish(fishId, fishInstanceId, fishWeight, source)` rebuilds a mid-fight fish after session restore with none of the per-cycle predicate data — all four of `HookDepth`/`GenerationDepth`/`HookDistance`/`GenerationDistance` stay 0. A mission gating on `Min*Distance` falsely rejects such a fish; a Max-only condition falsely accepts it. Pre-existing gap: the Depth twins behaved identically before r16310; the commit extends the same semantics symmetrically without worsening the restore path.

**Investigation:**
- Branch-wide grep of Depth/Distance assignments: no write sites in the restore path — restored fish provably carries defaults for all four fields; `FishGenerator.RestoreFish` signature confirms no predicate data even reaches it.
- Both delegates surfaced this independently (agent traced `MultiRodGameProcessor.CollectPersistedData` → `RodState` → restore; Codex the same chain). Severity disagreement (agent: below-threshold pre-existing; Codex: Major) resolved by the symmetry evidence: the gap predates r16310 and the commit adds no asymmetry — reviewer severity Low.

**Resolution:** Skipped — the relogin-mid-fight restore path is a known globally broken area (the fighting fish is effectively not restored at all, so the "restored fish with default-0 distances reaches a condition" scenario does not materialize in practice); the whole fishing save/restore area is slated for rewrite under the FP-45122 fish-fight-protocol epic. Confirmed by reviewer during the FP-44536 review; no backlog entry — the rework epic owns the area.

**Discovered by:** code-reviewer agent + Codex (independently).

### F-2: Fish persisted before r16310 evaluate distance conditions as Distance=0 while Depth holds real data [Low]

**Description:** Cage fish JSON written pre-r16310 (profile cage, tournament `SavedFishCage`, FishingTogether `SavedFishCage`) lacks the new properties; Newtonsoft defaults them to 0 on load. Distance-gated cage conditions (`FishCageCondition`, `ReleaseFishFromCageCondition`, `ReleaseFishFromCageInteraction`) then falsely reject legacy fish on Min-bounds (falsely accept on Max-only). One-time rollout semantics inherent to adding any predicate field to persisted `Fish` — the Depth twins went through the same on introduction; `TranslateFishCage` cannot backfill (its `MakeCloneOf` correctly skips `[NoClone]` instance fields).

**Investigation:**
- `Fish` `MemberSerialization.OptOut` + no `[JsonSkip]` on new fields → serialized going forward; absent in legacy JSON → CLR default 0 (Newtonsoft missing-member semantics).
- Cage evaluators inherit `BaseFishCondition` / implement `IFishCondition` (grep) — distance guards apply to cage fish.
- `SerializationHelper.MakeCloneOf` skips `[NoClone]` (read) — template overlay preserves, not repairs, instance data.

**Resolution:** Accepted — matches the established rollout pattern for predicate fields; distance-gated content is new and targets freshly-caught fish (QA-verified end-to-end); "unknown distance fails Min-conditions" is a defensible semantic for legacy fish. The original distance is unrecoverable, so no backfill is possible even in principle.

**Discovered by:** Codex.

### F-3: No test coverage for the new condition fields [Info]

**Description:** No tests reference the four new condition fields or the two `Fish` properties — but none reference the Depth twins either (both appear exclusively in the two condition source files). The commit matches the existing (zero) coverage level for `MatchFishPredicate` bound fields.

**Investigation:** Branch-wide grep of `Min/MaxHookDistance|Min/MaxGenerationDistance` → 2 source files only; same grep for `Min/MaxGenerationDepth` → same 2 files. No test project references either group.

**Resolution:** Skipped — consistent with existing condition-field coverage; a `MatchFishPredicate` test suite is a broader initiative than this review, and the fishing-gameplay area is slated for the FP-45122 rewrite, reducing the value of testing the current implementation.

**Discovered by:** Codex.

## Verdict

**Approve.** The commit is a disciplined clone of the established `Min/MaxGenerationDepth` pattern along every axis: write sites (the only Depth write sites in the branch, now writing Distance too), metric (`Point3.Distance` 3D Euclidean — same value feeding hooked-fish stats and XP distance bonus), copy path (`CopyFishingCycleProperties`, all four fish-replacement sites), serialization (`Fish` OptOut + `[NoClone]` protecting instance data through `TranslateFishCage`; conditions OptIn + `[JsonProperty]`), interface implementors (compile-forced completeness), client (predicate fields established as non-mirrored), admin/test surface (nothing to update). Merge to NPN r16311 verified faithful. No blocking findings: F-1 Skipped (known-broken restore area, owned by FP-45122), F-2 Accepted (inherent one-time rollout semantics of any new persisted predicate field), F-3 Skipped (matches existing zero coverage of condition bound fields).

Verification scope: full static verification of the fish lifecycle (generate → hook → catch → cage → release) at r16310, merge fidelity to NPN, and client-mirror non-requirement; runtime behavior verified empirically by QA (test server r16350, "GHENT-TERNEUZEN — Casting Marathon"). No unit tests exist for the new fields (F-3).
