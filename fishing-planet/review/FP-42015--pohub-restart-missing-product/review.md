---
status: in-progress
executor: Yuriy Burda
branch: LBM @ r15889
jira: https://fishingplanet.atlassian.net/browse/FP-42015
---

# Review: FP-42015 — PO product not shown in POHub after exiting to Globe

## Summary

Bug: an unpurchased Personal Offer (PO) product did not re-appear in the POHub window after the player exited a local map to the Globe, while a previously purchased PO did re-appear. Reproduced on test build 6.0.4 r52059. Root cause and fix attributed by executor to FP-40511, shipped as a single commit in the LBM branch (r15889). FP-42015 itself has no dedicated commit — the bug closes by virtue of the FP-40511 fix.

## Scope

- **LBM r15889** — Fix attributed via FP-40511 (per JIRA comment id 110190). No commit message references FP-42015 directly.

> Source-branch claim ("LBM") and revision ("r15889") taken at face value from JIRA — to be verified in Phase 2 via `svn log` against the LBM branch URL and against the FP-40511 commit content.

## Open questions for Phase 2

- Confirm r15889 exists on LBM and references FP-40511 (not FP-42015) in the commit message.
- Inspect r15889 diff: does it actually address the POHub re-show path for unpurchased PO after Globe transition? (i.e., is FP-42015 a true subset of FP-40511's fix, or just visually similar?)
- Cross-branch: r15889 is on LBM (Content). LBM ancestry: MFT (Code) was forked from LBM r15942 → r15889 ≤ 15942 → **already inherited in MFT via branch copy** (no merge needed). KNW (Stable) was forked from JLM r14592 — r15889 is NOT inherited. Per executor's comment id 110191: open question whether to merge to KNW (Stable) given hotfix fix-version.
- Data-transfer plan from comment id 103406 (Stanislav Rudakov, 2026-02-10): GD must reset PO "Reset Date" → QA validates → datatransfer to PROD with next ServerHotfix. Note for closure phase, not a code finding.

## Investigation Journal

- 2026-04-28 — Card opened. Executor confirmed via `customfield_11224` lookup = Yuriy Burda (matches commit-attribution comment author).
- Phase 1 — no svn/code work yet; commit list and source branch taken from JIRA at face value pending Phase 2 verification.
