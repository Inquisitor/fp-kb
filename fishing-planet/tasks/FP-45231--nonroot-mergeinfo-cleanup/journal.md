---
jira: https://fishingplanet.atlassian.net/browse/FP-45231
title: Remove non-root svn:mergeinfo from branches
status: in-progress
executor: Stanislav Samoilov
created: 2026-07-27
type: story
---

## Status

Server-side cleanup done: MFT (r16365) and NPN (r16366) now carry `svn:mergeinfo` only on the branch root — verified. The forensic comment is posted on JIRA. Remaining: the client-side `Assets/Scripts/` cleanup (separate follow-up, after the server side). Pre-MFT branches are left as-is by decision.

## Summary

Several active branches carried `svn:mergeinfo` on sub-paths (individual files and subdirectories), not only on the branch root — a split-brain condition that fragments merge tracking, can cause future merges to silently skip or re-apply revisions, and grows without bound through branch-copy inheritance. This task removes non-root mergeinfo from the active branches (MFT and newer) and establishes the root-only invariant going forward. Surfaced during the [FP-41501 review](../../review/FP-41501--rod-catch-conditions/review.md).

## Key facts / decisions

- **Invariant** (codified in [`feedback/mergeinfo_root_only.md`](../../../feedback/mergeinfo_root_only.md)): `svn:mergeinfo` lives only on a branch's root; carry commits cross-branch with a root-level `svn merge` only. A file/subtree-level merge materializes the source's inherited root mergeinfo onto the touched node — the mechanism behind the whole mess.
- **Origin** (forensic in the same feedback file): r6966 (`ivan`, 2019-09-19, branch `Ugc20190620`, "Merged revision(s) 6896-6961 from branches/Retail20190522") first stamped subtree mergeinfo on `SQL/Patches` plus a malformed `/branches/Retail20190522:6908` entry; inherited by every branch copy for ~7 years; materialized onto the ProfileConversions files by r16160 (FP-44159, a file-level `svn copy`).
- **Scope:** MFT and newer only. Pre-MFT branches (LBM/KNW/IMV) are retiring and left as-is; the residual re-contamination risk via a future LBM->MFT hotfix merge is accepted (noted in the JIRA body).
- **Method:** per subtree path, confirm its recorded revs are a subset of the branch-root mergeinfo (then `propdel` is behaviorally neutral); investigate any subtree-only rev before removing. Record the MFT->NPN merge (r16365 -> r16366) so merge tracking stays consistent rather than diverging.

## Backlog / next

See [backlog.md](backlog.md).

## Milestones

- 2026-07-27 — KB invariant codified: `feedback/mergeinfo_root_only.md` + Feedback Rules / Branch Roles references in `CLAUDE.md` (commit `857961b`; 2019 origin appendix `5c194b1`).
- 2026-07-27 — MFT `SQL/Patches` subtree mergeinfo removed (`r16365`).
- 2026-07-27 — NPN cleaned — `SQL/Patches` + the r16160-materialized ProfileConversions file nodes — and the MFT cleanup merged up (`r16366` records r16365 on NPN root). Both branches verified root-only.
- 2026-07-27 — Forensic comment posted on FP-45231 (origin r6966, inheritance chain, r16160 materialization, cleanup commits r16365/r16366).
