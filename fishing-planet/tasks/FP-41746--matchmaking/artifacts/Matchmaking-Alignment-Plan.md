# Matchmaking — Plan for Aligning Documentation and Code

> **Date:** 2026-02-16 \
> **Updated:** 2026-04-14 \
> **Branch:** LBM20251201 \
> **Related:**
> - [Matchmaking-System-Current-State.md](archived/Matchmaking-System-Current-State.md)
> - [MatchMaking-System-1st-Iteration-GDD.md](archived/MatchMaking-System-1st-Iteration-GDD.md) | [Confluence](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4067721271/MatchMaking+System+-+1st+Iteration+GDD)
> - [New-Tournament-Ratings-TDD.md](archived/New-Tournament-Ratings-TDD.md) | [Confluence](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4009033759)

---

## Summary: Execution Order

### Phase 1 — Bug Fixes (High Priority) — DONE

| ID      | Description                                 | Status | Details                                                                            |
|---------|---------------------------------------------|--------|------------------------------------------------------------------------------------|
| ALG-004 | Fix Phase B "farthest vs nearest" bug       | DONE   | [details](archived/subtasks/FP-41746--ALG-004--phase-b-farthest-vs-nearest-bug.md) |
| ALG-005 | Add empty bucket skip in Phase B            | DONE   | [details](archived/subtasks/FP-41746--ALG-005--phase-b-skip-empty-buckets.md)      |
| ALG-006 | Add RefreshGroup() call after Phase B merge | DONE   | [details](archived/subtasks/FP-41746--ALG-006--phase-b-refresh-after-merge.md)     |

### Phase 2 — Terminology Unification (High Priority) — DONE

| ID      | Description                                                         | Status | Details                                                                    |
|---------|---------------------------------------------------------------------|--------|----------------------------------------------------------------------------|
| TRM-001 | Unify terminology in TDD + code XML doc comments                    | DONE   | [details](archived/subtasks/FP-41746--TRM-001--terminology-tdd.md)         |
| TRM-002 | Rename code identifiers to unified Bracket/Bucket/Group terminology | DONE   | [details](archived/subtasks/FP-41746--TRM-002--rename-code-identifiers.md) |

### Phase 3 — Test Fixes (High Priority) — DONE

| ID      | Description                                               | Status | Details                                                                         |
|---------|-----------------------------------------------------------|--------|---------------------------------------------------------------------------------|
| TST-001 | Recalculate and enable all "potentially false" test cases | DONE   | [details](archived/subtasks/FP-41746--TST-001--fix-3-bracket-test-cases.md)     |
| TST-002 | Uncomment, recalculate and enable 4-group test cases      | DONE   | [details](archived/subtasks/FP-41746--TST-002--fix-4-bracket-test-cases.md)     |
| TST-003 | Review stale LowRatingProtection test — rename or delete  | DONE   | [details](archived/subtasks/FP-41746--TST-003--rename-stale-protection-test.md) |

### Phase 4 — Dead Code & Obsolete Fields Removal — DONE

| ID      | Description                                                 | Status | Details                                                                      |
|---------|-------------------------------------------------------------|--------|------------------------------------------------------------------------------|
| DCD-001 | Remove TournamentGroup.IsNotRated + DB cleanup              | DONE   | [details](archived/subtasks/FP-41746--DCD-001--remove-is-not-rated-group.md) |
| DCD-002 | Remove TournamentGroup.IsCanceled + DB cleanup              | DONE   | [details](archived/subtasks/FP-41746--DCD-002--remove-is-canceled-group.md)  |
| DCD-003 | Remove FindFirstAdjacentIncompleteGroupsCombination         | DONE   | [details](archived/subtasks/FP-41746--DCD-003--remove-dead-find-adjacent.md) |
| DCD-004 | Remove TournamentGroupParticipant.IsNotRated + DB cleanup   | DONE   | → Phase 8                                                                    |
| DCD-005 | Remove TournamentGroupParticipant.IsCanceled + DB cleanup   | DONE   | → Phase 8                                                                    |
| CFG-003 | Investigate IsRated DB columns (alongside DCD-001, DCD-004) | DONE   | → Phase 8                                                                    |

### Phase 5 — Code Refactoring — MOVED OUT

| ID      | Description                                                       | Status                                                                          | Details                                                                 |
|---------|-------------------------------------------------------------------|---------------------------------------------------------------------------------|-------------------------------------------------------------------------|
| CFG-007 | Remove MaxRating from spec, compute bracket boundaries on the fly | Moved to [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717)        | [details](archived/subtasks/FP-41746--CFG-007--remove-maxrating.md)     |
| VAL-001 | Revisit validations in TDD and code (depends on CFG-007)          | Folded into [FP-43717](https://fishingplanet.atlassian.net/browse/FP-43717) ACs | [details](archived/subtasks/FP-41746--VAL-001--revisit-validations.md)  |

### Phase 6 — Feature Implementation (FP-41833) — DONE

| ID      | Description                                                        | Status | Details                                                                          |
|---------|--------------------------------------------------------------------|--------|----------------------------------------------------------------------------------|
| CFG-005 | Implement MaxGroupCount                                            | DONE   | [details](archived/subtasks/FP-41746--CFG-005--maxgroupcount.md)                 |
| CFG-006 | Implement MaxGroupSize (rework GDD description)                    | DONE   | [details](archived/subtasks/FP-41746--CFG-006--maxsize.md)                       |
| TST-004 | Recalculate expected test outputs for MaxGroupCount / MaxGroupSize | DONE   | [details](archived/subtasks/FP-41746--TST-004--recalculate-new-param-outputs.md) |
| SUB-001 | Implement new group parameters, update docs                        | DONE   | [details](archived/subtasks/FP-41746--SUB-001--group-creation-algorithm.md)      |

### Phase 7 — Documentation Cleanup — DONE

| ID      | Description                                                        | Status | Details                                                                                                                                                       |
|---------|--------------------------------------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| CFG-001 | Remove CrossMovesAllowed from GDD + TDD                            | DONE   | [details](archived/subtasks/FP-41746--CFG-001--remove-crossmovesallowed.md)                                                                                   |
| CFG-002 | Remove CanceledIfIncomplete from TDD                               | DONE   | [details](archived/subtasks/FP-41746--CFG-002--remove-canceledifincomplete.md)                                                                                |
| CFG-003 | Remove NotRatedIfIncomplete from TDD                               | DONE   | [details](archived/subtasks/FP-41746--CFG-003--remove-notratedifincomplete.md)                                                                                |
| CFG-004 | Remove IsLowRatingGroupProtectionOn from TDD                       | DONE   | [details](archived/subtasks/FP-41746--CFG-004--remove-islowratinggroupprotectionon.md)                                                                        |
| ALG-001 | Update GDD: ping-pong traversal instead of semantic priority       | DONE   | [details](archived/subtasks/FP-41746--ALG-001--gdd-ping-pong-traversal.md), → Правка 8 in [editing instructions](GDD-Editing-Instructions.md)                 |
| ALG-002 | Update GDD: "any bucket can donate" instead of "Middles as filler" | DONE   | [details](archived/subtasks/FP-41746--ALG-002--gdd-donor-principle.md), → Правка 9 in [editing instructions](GDD-Editing-Instructions.md)                     |
| ALG-003 | Update GDD: Phase B brief note                                     | DONE   | [details](archived/subtasks/FP-41746--ALG-003--gdd-phase-b-merge.md), → Правка 8 in [editing instructions](GDD-Editing-Instructions.md) (merged with ALG-001) |
| ALG-007 | Remove "MinSize*2 single group" statement from GDD                 | DONE   | [details](archived/subtasks/FP-41746--ALG-007--gdd-minsize-collapse.md), → Правка 10 in [editing instructions](GDD-Editing-Instructions.md)                   |
| FTR-001 | Add multipliers note to TDD                                        | DONE   | [details](archived/subtasks/FP-41746--FTR-001--multipliers-note.md)                                                                                           |
| DOC-001 | Fix typo in TDD validation rules (wrong array index)               | DONE   | [details](archived/subtasks/FP-41746--DOC-001--validation-rule-typo.md)                                                                                       |
| DOC-003 | Proofread GDD and TDD — fix spelling errors                        | DONE   | [details](archived/subtasks/FP-41746--DOC-003--proofreading.md)                                                                                               |

### Phase 8 — DB + Code Rename — DONE

| ID      | Description                                                 | Status | Details                                                                                                                                           |
|---------|-------------------------------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------------------------------|
| TRM-003 | Full DB rename `GroupId` → `BracketId` + code rename P6-P14 | DONE   | [details](archived/subtasks/FP-41746--TRM-003--db-rename.md), [design](TRM-003-DB-Rename-Design.md)                                               |
| DCD-004 | Remove `IsRated` from DB + code (alongside TRM-003)         | DONE   | [details](archived/subtasks/FP-41746--DCD-004--remove-participant-isnotrated.md), [design](TRM-003-DB-Rename-Design.md#dcd-004-remove-israted)    |
| DCD-005 | Remove participant `IsCanceled` chain from DB + code        | DONE   | [details](archived/subtasks/FP-41746--DCD-005--remove-participant-iscanceled.md), [design](TRM-003-DB-Rename-Design.md#dcd-005-remove-iscanceled) |

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

| ID      | Description                                           | Details                                                                           |
|---------|-------------------------------------------------------|-----------------------------------------------------------------------------------|
| ALG-008 | Minimum participants check — no discrepancy           | [details](archived/subtasks/FP-41746--ALG-008--min-participants-outside-logic.md) |
| DOC-004 | Fix TournamentGroup.Participants XML doc              | [details](archived/subtasks/FP-41746--DOC-004--fix-participants-xml-doc.md)       |
| DOC-005 | Rename TournamentBucket.UpdateRatings parameter       | [details](archived/subtasks/FP-41746--DOC-005--rename-update-ratings-param.md)    |
| FTR-002 | Friends/club splitting — already documented as future | [details](archived/subtasks/FP-41746--FTR-002--friends-splitting-no-action.md)    |

---

## How to Use This Document

Each discrepancy is a numbered item with description, action table (GDD/TDD/Code), and priority.
Item IDs use section prefix + sequential number (e.g. `ALG-001`).
Statuses: `TODO`, `N/A`, `DONE`, `DRAFTED` (edit instructions ready, not yet on Confluence), `DEFERRED`.

Completed items are collapsed to one-liners in the Summary above, with full details in
`archived/subtasks/<ID>--<slug>.md`. Only active (TODO/partially-done) items appear in full below.

**Rule:** After any GDD/TDD edit on Confluence, update the corresponding local `.md` copy to keep them in sync.

---

## Active items

### DOC-002. Recreate `Matchmaking-System-Current-State.md`

- **Doc:** The current-state architecture document was created as an analysis artifact before this plan. After all code
  and documentation changes are complete, it will be outdated (bugs fixed, dead code removed, features added).

**Decision:** Recreate from scratch after all phases are done to reflect the final state.

| Action                                                                                     | Status |
|--------------------------------------------------------------------------------------------|--------|
| Regenerate `Matchmaking-System-Current-State.md` from final code after all fixes are done. | TODO   |

**Priority:** Low (final step)

---

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
