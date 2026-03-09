# Matchmaking — Plan for Aligning Documentation and Code

> **Date:** 2026-02-16 \
> **Updated:** 2026-03-06 \
> **Branch:** LBM20251201 \
> **Related:**
> - [Matchmaking-System-Current-State.md](archived/Matchmaking-System-Current-State.md)
> - [MatchMaking-System-1st-Iteration-GDD.md](archived/MatchMaking-System-1st-Iteration-GDD.md) | [Confluence](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4067721271/MatchMaking+System+-+1st+Iteration+GDD)
> - [New-Tournament-Ratings-TDD.md](archived/New-Tournament-Ratings-TDD.md) | [Confluence](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4009033759)

---

## Summary: Execution Order

### Phase 1 — Bug Fixes (High Priority) — DONE

| ID      | Description                                 | Status | Details                                                                  |
|---------|---------------------------------------------|--------|--------------------------------------------------------------------------|
| ALG-004 | Fix Phase B "farthest vs nearest" bug       | DONE   | [details](archived/subtasks/ALG-004--phase-b-farthest-vs-nearest-bug.md) |
| ALG-005 | Add empty bucket skip in Phase B            | DONE   | [details](archived/subtasks/ALG-005--phase-b-skip-empty-buckets.md)      |
| ALG-006 | Add RefreshGroup() call after Phase B merge | DONE   | [details](archived/subtasks/ALG-006--phase-b-refresh-after-merge.md)     |

### Phase 2 — Terminology Unification (High Priority) — PARTIAL

| ID      | Description                                                         | Status                                        | Details                                                          |
|---------|---------------------------------------------------------------------|-----------------------------------------------|------------------------------------------------------------------|
| TRM-001 | Unify terminology in TDD + code XML doc comments                    | GDD=N/A, TDD=TODO, Code=Superseded by TRM-002 |
| TRM-002 | Rename code identifiers to unified Bracket/Bucket/Group terminology | DONE                                          | [details](archived/subtasks/TRM-002--rename-code-identifiers.md) |

### Phase 3 — Test Fixes (High Priority) — DONE

| ID      | Description                                               | Status | Details                                                               |
|---------|-----------------------------------------------------------|--------|-----------------------------------------------------------------------|
| TST-001 | Recalculate and enable all "potentially false" test cases | DONE   | [details](archived/subtasks/TST-001--fix-3-bracket-test-cases.md)     |
| TST-002 | Uncomment, recalculate and enable 4-group test cases      | DONE   | [details](archived/subtasks/TST-002--fix-4-bracket-test-cases.md)     |
| TST-003 | Review stale LowRatingProtection test — rename or delete  | DONE   | [details](archived/subtasks/TST-003--rename-stale-protection-test.md) |

### Phase 4 — Dead Code & Obsolete Fields Removal — DONE

| ID      | Description                                                 | Status    | Details                                                            |
|---------|-------------------------------------------------------------|-----------|--------------------------------------------------------------------|
| DCD-001 | Remove TournamentGroup.IsNotRated + DB cleanup              | DONE      | [details](archived/subtasks/DCD-001--remove-is-not-rated-group.md) |
| DCD-002 | Remove TournamentGroup.IsCanceled + DB cleanup              | DONE      | [details](archived/subtasks/DCD-002--remove-is-canceled-group.md)  |
| DCD-003 | Remove FindFirstAdjacentIncompleteGroupsCombination         | DONE      | [details](archived/subtasks/DCD-003--remove-dead-find-adjacent.md) |
| DCD-004 | Remove TournamentGroupParticipant.IsNotRated + DB cleanup   | DONE      | → Phase 8                                                          |
| DCD-005 | Remove TournamentGroupParticipant.IsCanceled + DB cleanup   | DONE      | → Phase 8                                                          |
| CFG-003 | Investigate IsRated DB columns (alongside DCD-001, DCD-004) | DONE      | → Phase 8                                                          |

### Phase 5 — Code Refactoring — DEFERRED

| ID      | Description                                                       | Status   |
|---------|-------------------------------------------------------------------|----------|
| CFG-007 | Remove MaxRating from spec, compute bracket boundaries on the fly | DEFERRED |
| VAL-001 | Revisit validations in TDD and code (depends on CFG-007)          | DEFERRED |

### Phase 6 — Feature Implementation (FP-41833) — DONE (code), TODO (docs)

| ID      | Description                                                        | Status                  | Details                                                                |
|---------|--------------------------------------------------------------------|-------------------------|------------------------------------------------------------------------|
| CFG-005 | Implement MaxGroupCount                                            | Code=DONE, GDD/TDD=TODO |
| CFG-006 | Implement MaxGroupSize (rework GDD description)                    | Code=DONE, GDD/TDD=TODO |
| TST-004 | Recalculate expected test outputs for MaxGroupCount / MaxGroupSize | DONE                    | [details](archived/subtasks/TST-004--recalculate-new-param-outputs.md) |
| SUB-001 | Implement new group parameters, update docs                        | Code=DONE, GDD/TDD=TODO |

### Phase 7 — Documentation Cleanup — TODO

| ID      | Description                                                        |
|---------|--------------------------------------------------------------------|
| CFG-001 | Remove CrossMovesAllowed from GDD + TDD                            |
| CFG-002 | Remove CanceledIfIncomplete from TDD                               |
| CFG-003 | Remove NotRatedIfIncomplete from TDD                               |
| CFG-004 | Remove IsLowRatingGroupProtectionOn from TDD                       |
| ALG-001 | Update GDD: ping-pong traversal instead of semantic priority       |
| ALG-002 | Update GDD: "any bucket can donate" instead of "Middles as filler" |
| ALG-003 | Add Phase B brief note to GDD                                      |
| ALG-007 | Remove "MinSize*2 single group" statement from GDD                 |
| FTR-001 | Add multipliers note to TDD                                        |
| DOC-001 | Fix typo in TDD validation rules (wrong array index)               |
| DOC-003 | Proofread GDD and TDD — fix spelling errors                        |

### Phase 8 — DB + Code Rename — DONE

| ID      | Description                                                 | Status | Details                                                         |
|---------|-------------------------------------------------------------|--------|-----------------------------------------------------------------|
| TRM-003 | Full DB rename `GroupId` → `BracketId` + code rename P6-P14 | DONE   | [design](TRM-003-DB-Rename-Design.md)                           |
| DCD-004 | Remove `IsRated` from DB + code (alongside TRM-003)         | DONE   | [design](TRM-003-DB-Rename-Design.md#dcd-004-remove-israted)    |
| DCD-005 | Remove participant `IsCanceled` chain from DB + code        | DONE   | [design](TRM-003-DB-Rename-Design.md#dcd-005-remove-iscanceled) |

### Phase 9 — Final Documentation (after all code changes)

| ID      | Description                                                  |
|---------|--------------------------------------------------------------|
| DOC-002 | Recreate Matchmaking-System-Current-State.md from final code |

### Phase 10 — Test Case Analysis (after all test fixes)

| ID      | Description                                                                              |
|---------|------------------------------------------------------------------------------------------|
| RES-001 | Analyze and categorize 4-bracket test cases (TST-002), compare with 3-bracket categories |
| RES-002 | Investigate if additional edge-case categories exist beyond the 5 identified in TST-001  |

### No Action Required

| ID      | Description                                           | Details                                                                 |
|---------|-------------------------------------------------------|-------------------------------------------------------------------------|
| ALG-008 | Minimum participants check — no discrepancy           | [details](archived/subtasks/ALG-008--min-participants-outside-logic.md) |
| DOC-004 | Fix TournamentGroup.Participants XML doc              | [details](archived/subtasks/DOC-004--fix-participants-xml-doc.md)       |
| DOC-005 | Rename TournamentBucket.UpdateRatings parameter       | [details](archived/subtasks/DOC-005--rename-update-ratings-param.md)    |
| FTR-002 | Friends/club splitting — already documented as future | [details](archived/subtasks/FTR-002--friends-splitting-no-action.md)    |

---

## How to Use This Document

Each discrepancy is a numbered item with description, action table (GDD/TDD/Code), and priority.
Item IDs use section prefix + sequential number (e.g. `ALG-001`).
Statuses: `TODO`, `N/A`, `DONE`, `DEFERRED`.

Completed items are collapsed to one-liners in the Summary above, with full details in
`archived/subtasks/<ID>--<slug>.md`. Only active (TODO/partially-done) items appear in full below.

**Rule:** After any GDD/TDD edit on Confluence, update the corresponding local `.md` copy to keep them in sync.

---

## 1. Terminology

### TRM-001. Terminology mismatch across all documents

| Concept                | GDD     | TDD            | Code                      |
|------------------------|---------|----------------|---------------------------|
| Rating range config    | Bracket | (rating range) | `TournamentGroupSettings` |
| Rating-based container | Bucket  | Group          | `TournamentGroup`         |
| Final competition unit | Group   | Subgroup       | `TournamentSubgroup`      |

**Decision:** Adopt unified terminology **Bracket / Bucket / Group** (from GDD).

| Action                                                                                                                                                                      | Status                                   |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------|
| **GDD:** Already uses Bracket/Bucket/Group. No changes needed.                                                                                                              | N/A                                      |
| **TDD:** Replace "Group" with "Bucket" and "Subgroup" with "Group" throughout the matchmaking section.                                                                      | TODO                                     |
| **Code:** Code identifiers (`TournamentGroup`, `TournamentSubgroup`) stay as-is to avoid massive refactoring. Add XML doc comments explaining the mapping to unified terms. | Superseded by TRM-002 (full code rename) |

**Priority:** High (blocks clear communication on everything else)

---

### TRM-003. Rename deferred DTO properties (P6-P14)

- **Code:** Nine classes still use `GroupId` instead of `BracketId`:
    - **DTO (P9-P12):** `ParticipantItemDto`, `TournamentIndividualResultsDto`,
      `TournamentParticipantDto`, `TournamentSecondaryResultDto`.
    - **Model (P6-P8):** `PlayerFinalResult`, `TournamentIndividualResults`,
      `TournamentSecondaryResult`.
    - **Runtime (P13-P14):** `ProfileTournament`, `ParticipantItem` (WebAdmin).
- **Blocker (DTOs P9-P12):** The custom DAL mapper `RestoreObjectFromReader` in `DtoExtensions.cs` maps
  DB column names to C# property names by **exact name match** via reflection. It does not support any
  mapping attributes. Renaming properties without enhancing the mapper would break all DAL reads.
- **Blocker (models P6-P8, P13-P14):** Populated from DTOs via `MakeCloneOf` / `MakeEqualTo`, which also
  use reflection with exact name matching. Renaming model properties without renaming DTOs would silently
  break the copy.
- **`GroupName` note:** All P6-P14 classes also have `GroupName`. Despite the name, it stores the **group
  name** (not the bracket name). `GroupName` does NOT need to be renamed to `BracketName` — it is already
  correct in the unified terminology.
- **Boundary analysis:** All 13 boundary points where `BracketId` (renamed) meets `GroupId` (deferred) have
  been validated as safe. See [Terminology-Rename-Plan.md](Terminology-Rename-Plan.md) §Implications.
- **Depends on:** TRM-002 (DONE).

**Decision (revised 2026-03-08):** Rename DB columns directly instead of enhancing the DAL mapper.
Feature is deployed but disabled — columns contain no data. Atomic deployment with downtime.
Also removes `IsRated` (DCD-004) and participant `IsCanceled` chain (DCD-005) from DB.

| Action                                                                                          | Status |
|-------------------------------------------------------------------------------------------------|--------|
| **DB:** `sp_rename` `[GroupId]` → `[BracketId]` in 6 tables + update 18+ stored procedures.     | TODO   |
| **DB:** `REPLACE()` ConfigJson in `Tournaments`, `TournamentTemplates`, `ArchiveTournaments`.   | TODO   |
| **Code:** Rename `GroupId` → `BracketId` in P6-P14 classes. Remove `[JsonProperty]` attributes. | TODO   |

Full design: [TRM-003-DB-Rename-Design.md](TRM-003-DB-Rename-Design.md)

**Priority:** Medium (unblocked by DB rename approach)

---

## 2. Configuration Parameters

### CFG-001. `CrossMovesAllowed` — documented but not in code model

- **GDD:** Described. Says "always true, because we always form groups and run competition if possible."
- **TDD:** Described. Says "deprecated, will be removed."
- **Code:** Not in `TournamentGroupingRule`. Algorithm always allows cross-moves.

**Decision:** Remove from documentation entirely. Feature not released — no need to keep history.

| Action                                                       | Status                                                    |
|--------------------------------------------------------------|-----------------------------------------------------------|
| **GDD:** Remove all mentions of `CrossMovesAllowed`.         | DONE (removed in Confluence, local .md synced 2026-02-17) |
| **TDD:** Remove all mentions of `CrossMovesAllowed`.         | TODO                                                      |
| **Code:** No changes needed — parameter was already removed. | N/A                                                       |

**Priority:** Low

---

### CFG-002. `CanceledIfIncomplete` — in TDD, not in code

- **TDD:** `bool, default true` — "if the group still has less members than MinSize, competitive activity is canceled
  for players in the group."
- **Code:** `TournamentGroup.IsCanceled` (was `TournamentSubgroup.IsCanceled`) exists (marked `[Obsolete]`), but no
  logic ever sets it to `true`. `TournamentGroupParticipant.IsCanceled` also exists, unused.

**Decision:** Feature not released. Remove from TDD and remove obsolete fields from code.

| Action                                                  | Status |
|---------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                       | N/A    |
| **TDD:** Remove all mentions of `CanceledIfIncomplete`. | TODO   |
| **Code:** See DCD-002, DCD-005.                         | N/A    |

**Priority:** Low (documentation cleanup)

---

### CFG-003. `NotRatedIfIncomplete` — in TDD, not in code

- **TDD:** `bool, default false` — "if the group still has less members than MinSize, rating is not calculated for this
  group."
- **Code:** `TournamentGroup.IsNotRated` (was `TournamentSubgroup.IsNotRated`) exists (marked `[Obsolete]`), but no
  logic ever sets it to `true`. `TournamentGroupParticipant.IsNotRated` also exists, unused.

**Decision:** Feature not released. Remove from TDD and remove obsolete fields from code. Investigate `IsRated` columns
in DB tables `TournamentParticipant*` — may keep as groundwork for future.

| Action                                                                                                                                       | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                                                                                                            | N/A    |
| **TDD:** Remove all mentions of `NotRatedIfIncomplete`.                                                                                      | TODO   |
| **Code:** Investigate `IsRated` columns in `TournamentParticipant*` DB tables — decide: keep or remove. Field removal: see DCD-001, DCD-004. | TODO   |

**Priority:** Medium (DB investigation + documentation cleanup)

---

### CFG-004. `IsLowRatingGroupProtectionOn` — in TDD, removed from code

- **TDD:** `bool, default true` — "players from upper buckets are protected from joining lower buckets."
- **Code:** Flag removed from codebase. Only referenced in a stale test name
  `CreateGroups_LowRatingProtectionIsOn_AddsMinimalPossiblePlayers` (was `CreateSubgroups_...`).

**Decision:** Feature not released. Remove from TDD. Stale test — see TST-003.

| Action                                                          | Status |
|-----------------------------------------------------------------|--------|
| **GDD:** No mention — no changes.                               | N/A    |
| **TDD:** Remove all mentions of `IsLowRatingGroupProtectionOn`. | TODO   |
| **Code:** See TST-003.                                          | DONE   |

**Priority:** Medium

---

### CFG-005. `MaxGroupCount` — in GDD, not in code

- **GDD:** "Maximum number of groups the algorithm can split the quorum into." Example: `"GroupCount": 5`. Use case: "if
  500 newbies registered, split into 3 newbie groups instead of one."
- **Code:** Not in `TournamentGroupingRule`. Not implemented.

**Decision:** Implement per FP-41833. Update documentation to match implementation.

| Action                                                                                             | Status |
|----------------------------------------------------------------------------------------------------|--------|
| **GDD:** Update description to match final implementation.                                         | TODO   |
| **TDD:** Add `MaxGroupCount` parameter description with implementation details.                    | TODO   |
| **Code:** Implement `MaxGroupCount` in `TournamentGroupingRule` and `MatchmakingLogic` (FP-41833). | DONE   |

**Priority:** Medium (feature implementation)

---

### CFG-006. `MaxGroupSize` — in GDD, not in code

- **GDD:** "Desired max number of players per group. Unlike TargetSize which splits into many small subgroups, this
  splits into fewer large groups."
- **Code:** Not in `TournamentGroupingRule`. Not implemented.

**Decision:** Implement per FP-41833. Rework GDD description — current wording unclear. Update documentation to match
implementation.

| Action                                                                                            | Status |
|---------------------------------------------------------------------------------------------------|--------|
| **GDD:** Rework description (current wording unclear). Align with final implementation.           | TODO   |
| **TDD:** Add `MaxGroupSize` parameter description with implementation details.                    | TODO   |
| **Code:** Implement `MaxGroupSize` in `TournamentGroupingRule` and `MatchmakingLogic` (FP-41833). | DONE   |

**Priority:** Medium (feature implementation)

---

### CFG-007. `MaxRating` — TDD says explicitly per-bracket, code auto-calculates

- **TDD:** `MaxRating` is explicitly specified per bracket in JSON config. Validation checks that brackets are
  continuous (group[i-1].MaxRating == group[i].MinRating - 1).
- **GDD:** Only `MinRating` shown in JSON examples. `MaxRating` is implied ("MinRating of group 2 is effectively
  MaxRating of group 1 plus 1 point").
- **Code:** `MaxRating` exists in `TournamentBracket` (was `TournamentGroupSettings`) but `InitializeGrouping()`
  auto-fills it from `MinRating` values. Works with `MaxRating = 0` or absent.

**Decision:** Remove `MaxRating` from spec. Rework code: eliminate `InitializeGrouping()` call, compute bracket
boundaries on the fly from `MinRating` values. `MaxRating` should not be a persisted/configured field.

| Action                                                                                                                                                                                                   | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Already consistent (only shows MinRating). No changes.                                                                                                                                          | N/A    |
| **TDD:** Remove `MaxRating` from parameter spec. Describe that brackets are defined by `MinRating` only; upper bound is derived on the fly (next bracket's MinRating - 1).                               | TODO   |
| **Code:** Remove `InitializeGrouping()`. Compute bracket boundaries on the fly from sorted `MinRating` values. Remove or deprecate `MaxRating` from `TournamentBracket` (was `TournamentGroupSettings`). | TODO   |

**Priority:** Medium (code refactoring)

---

## 3. Algorithm Discrepancies

### ALG-001. Bucket fill priority — GDD semantic vs. Code positional

- **GDD:** "Priority: fill Newbies first, then Tops, then Middles last."
- **TDD:** Ping-pong traversal described in detail. First bucket, last, second, second-to-last, etc.
- **Code:** `PingPongTraversalIterator` — positional ping-pong. For 3 groups (Newbies=1, Middles=2, Tops=3) the result
  is 1,3,2 — matches GDD's semantic description.

**Decision:** No conflict for the standard 3-group setup. For N groups, the code is more precise. Update GDD to describe
the positional ping-pong pattern instead of semantic names. Keep 3-group case as example.

| Action                                                                                                                                                                 | Status |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Rewrite "Group Creation Logic (for N groups)" to describe ping-pong traversal pattern instead of semantic priority. Keep 3-group example showing equivalence. | TODO   |
| **TDD:** Already correct. No changes.                                                                                                                                  | N/A    |
| **Code:** No changes needed.                                                                                                                                           | N/A    |

**Priority:** Medium

---

### ALG-002. Merging direction — GDD says "Middles as filler"

- **GDD:** "Players from bracket B (Middles) serve as filler for other buckets."
- **Code:** Any bucket can serve as a donor. The ping-pong algorithm pulls from adjacent **unvisited** buckets
  regardless of semantic role.

**Decision:** Code behavior is correct and more general. Update GDD.

| Action                                                                                                                                                                                                                                                                 | Status |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Replace "Middles serve as filler" with: "Players are pulled from adjacent unvisited buckets. The middle bucket(s) are naturally the last to be visited, so they serve as the primary donor — but any bucket can donate players to an adjacent one if needed." | TODO   |
| **TDD:** Already correct. No changes.                                                                                                                                                                                                                                  | N/A    |
| **Code:** No changes needed.                                                                                                                                                                                                                                           | N/A    |

**Priority:** Medium

---

### ALG-003. Incomplete bucket merge (Phase B) — not described in GDD

- **GDD:** Does not describe what happens if a bucket remains incomplete after balancing.
- **TDD:** "Prioritizes merging into a stronger group. Fallback: nearest weaker group."
- **Code:** Merges upward (stronger), fallback to weaker. **BUG: finds farthest, not nearest** (see ALG-004).

**Decision:** Add Phase B description to GDD. Fix bug in code (ALG-004).

| Action                                                                                                                                                                                                                                                                                | Status |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Add a brief note describing Phase B: after ping-pong traversal, if a bucket is still below MinSize, it merges into the nearest stronger bucket; fallback — nearest weaker bucket. Include the 5 scenario categories from TST-001 as typical examples for the 3-bracket case. | TODO   |
| **TDD:** Already describes correct ("nearest") behavior. No changes needed.                                                                                                                                                                                                           | N/A    |
| **Code:** See ALG-004 for bug fix.                                                                                                                                                                                                                                                    | N/A    |

**Priority:** Medium

---

### ALG-007. "MinSize*2 single group" threshold — GDD describes, code doesn't enforce

- **GDD:** "If total players < MinSize*2 — run competition as single group, no splitting."
- **Code:** No explicit check for `MinSize*2` in `MatchmakingLogic`. The algorithm naturally produces one group if there
  aren't enough players for two, but there's no explicit guard.

**Decision:** Trivial — algorithm handles this naturally, no explicit check needed. Remove from GDD to avoid clutter.

| Action                                                                      | Status |
|-----------------------------------------------------------------------------|--------|
| **GDD:** Remove the "MinSize*2 single group" statement — it's self-evident. | TODO   |
| **TDD:** N/A                                                                | N/A    |
| **Code:** No changes needed.                                                | N/A    |

**Priority:** Low

---

## 4. Validation

### VAL-001. TDD describes extensive validation, code has minimal

- **TDD:** Lists these validation checks:
    - `MinSize < TargetSize < MaxSize`
    - `CanceledIfIncomplete` and `NotRatedIfIncomplete` can't both be true
    - `TargetSize` and `MaxSize` both null or both not null
    - Rating overlap checks (continuous brackets)
- **Code:** Only `TargetSize` range validation exists (`CreateGroups` (was `CreateSubgroups`) throws
  `ArgumentException` if `TargetSize < MinSize` or `TargetSize > MaxSize`). No rating overlap validation.

**Decision:** Remove validations for deleted parameters from TDD. Remaining validations (TargetSize, rating ranges,
code-side checks) to be revisited after CFG-007 refactoring.

| Action                                                                                                                                       | Status |
|----------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** N/A                                                                                                                                 | N/A    |
| **TDD:** Remove validation rules for `CanceledIfIncomplete`/`NotRatedIfIncomplete`. Revisit remaining validations after CFG-007.             | TODO   |
| **Code:** Revisit code-side validations after CFG-007 (existing checks have issues). Consider adding `MinSize > 0`, `Groups.Count > 0`, etc. | TODO   |

**Priority:** Medium (depends on CFG-007)

---

## 5. Group Formation (formerly, "subgroups")

### SUB-001. TDD says "[TBD]"; code fully implements group creation

- **TDD:** "Creating subgroups — [TBD]"
- **Code:** `CreateGroups` (was `CreateSubgroups`) fully implemented with TargetSize-based splitting, group count
  selection (projected/increased/decreased), even distribution.
- **GDD:** "Logic for creating subgroups" section describes the concept and says "in first iteration TargetSize won't be
  used."

**Decision:** Implement new group parameters per FP-41833. Update documentation everywhere to describe final algorithm.

| Action                                                                                                                      | Status |
|-----------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Update group creation section to describe final algorithm with new parameters (FP-41833).                          | TODO   |
| **TDD:** Replace "[TBD]" with full group creation algorithm description matching final implementation.                      | TODO   |
| **Code:** Implement new group parameters per FP-41833. Update `CreateGroups` (was `CreateSubgroups`) in `MatchmakingLogic`. | DONE   |

**Priority:** Medium (feature implementation, FP-41833)

---

## 6. Obsolete / Dead Code

### DCD-004. `TournamentGroupParticipant.IsNotRated` — unused

- **Code:** Property exists but is never set or checked in `MatchmakingLogic`.
- Related to CFG-003.

**Decision:** Remove entirely — feature never released. Part of CFG-003 cleanup.

| Action                                                                                                                       | Status |
|------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsNotRated` from `TournamentGroupParticipant`. Scan full codebase and DB stored procedures for references. | TODO   |

**Priority:** Medium

---

### DCD-005. `TournamentGroupParticipant.IsCanceled` — unused

- **Code:** Property exists but is never set or checked in `MatchmakingLogic`.
- Related to CFG-002.

**Decision:** Remove entirely — feature never released. Part of CFG-002 cleanup.

| Action                                                                                                                       | Status |
|------------------------------------------------------------------------------------------------------------------------------|--------|
| **Code:** Remove `IsCanceled` from `TournamentGroupParticipant`. Scan full codebase and DB stored procedures for references. | TODO   |

**Priority:** Medium

---

## 7. Documentation Errors

### DOC-001. Typo in TDD validation rules — wrong array index

- **TDD:** In "Competetive Activity Breaks" validation section, the rating overlap check reads:
  `group[i-1].MaxRating == group[i-1].MinRating - 1`
  Should be:
  `group[i-1].MaxRating == group[i].MinRating - 1`
  (right-hand side must reference the **next** group's MinRating, not the same group)
- **Confluence page:** Same typo (page ID 4009033759, last modified 11 Jan 2026).

**Decision:** Fix in TDD on Confluence. May become moot if validation section is rewritten per CFG-007.

| Action                                                                                        | Status |
|-----------------------------------------------------------------------------------------------|--------|
| **GDD:** N/A                                                                                  | N/A    |
| **TDD:** Fix `group[i-1].MinRating` → `group[i].MinRating` in validation rules on Confluence. | TODO   |
| **Code:** N/A                                                                                 | N/A    |

**Priority:** Low (documentation typo; may be superseded by CFG-007)

---

### DOC-002. Recreate `Matchmaking-System-Current-State.md`

- **Doc:** The current-state architecture document was created as an analysis artifact before this plan. After all code
  and documentation changes are complete, it will be outdated (bugs fixed, dead code removed, features added).

**Decision:** Recreate from scratch after all phases are done to reflect the final state.

| Action                                                                                     | Status |
|--------------------------------------------------------------------------------------------|--------|
| Regenerate `Matchmaking-System-Current-State.md` from final code after all fixes are done. | TODO   |

**Priority:** Low (final step)

---

### DOC-003. Proofreading — fix typos in GDD and TDD

- **GDD + TDD:** Multiple spelling errors across both documents, e.g. "Competetive" → "Competitive", and similar.

**Decision:** Do a full proofreading pass on both GDD and TDD on Confluence. Sync local `.md` copies afterward.

| Action                                                                 | Status |
|------------------------------------------------------------------------|--------|
| **GDD:** Proofread and fix typos on Confluence. Sync local `.md` copy. | TODO   |
| **TDD:** Proofread and fix typos on Confluence. Sync local `.md` copy. | TODO   |

**Priority:** Low (documentation cleanup)

---

## 8. Features Planned but Not Implemented

### FTR-001. Separate rewards per group

- **GDD:** "In next iterations, rewards of different value per group."
- **Code:** `RatingMultiplier` and `RewardMultiplier` exist in `TournamentGroupSettings` but are not applied in
  matchmaking (applied during reward distribution separately).

**Decision:** No action needed now. Document status.

| Action                                                                                                                                          | Status |
|-------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| **GDD:** Already marked as future iteration. No changes.                                                                                        | N/A    |
| **TDD:** Add note: "RatingMultiplier and RewardMultiplier are stored in config and applied during reward distribution, not during matchmaking." | TODO   |
| **Code:** No changes needed.                                                                                                                    | N/A    |

**Priority:** Low (documentation only)

---

## 9. Test Case Analysis

### RES-001. Categorize 4-bracket test cases

- After TST-002 (uncomment and fix 4-bracket test cases), analyze all test cases and categorize them into
  scenario types — similar to the 5 categories identified for 3 brackets in TST-001.
- Compare: do the same 5 categories cover 4 brackets, or do new patterns emerge (e.g. multi-hop pulls across
  3+ adjacents, multiple Phase B merges)?
- **Depends on:** TST-002 (DONE).

| Action                                                                                   | Status |
|------------------------------------------------------------------------------------------|--------|
| Categorize all 4-bracket test cases. Document categories and compare with 3-bracket set. | TODO   |

**Priority:** Low (research — useful for GDD documentation)

---

### RES-002. Investigate additional edge-case categories

- After RES-001, review if the combined 3-bracket + 4-bracket category list is exhaustive.
- Consider: are there scenarios only possible with 5+ brackets? Degenerate inputs (all zeros, all equal,
  exactly MinSize)? Can we derive a general category taxonomy independent of bracket count?
- **Depends on:** RES-001.

| Action                                                                                                   | Status |
|----------------------------------------------------------------------------------------------------------|--------|
| Research if more scenario categories exist beyond those found in TST-001 and RES-001. Document findings. | TODO   |

**Priority:** Low (research)
