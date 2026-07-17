# Backlog — Client

- [ ] Map client project structure
- [ ] Identify key client modules for navigation cards
- [ ] **Remove stale subtree `svn:mergeinfo` on `Assets/Scripts` (and sweep for other smeared subtrees) in MainClient**
  - **Symptom:** `Assets/Scripts` carries its own `svn:mergeinfo` (grown to ~35 branch lines). Every root-level merge into MainClient re-touches this subtree property, and it is inherited into every client branch copy — a recurring diff-noise / merge-hygiene drag.
  - **Origin:** created by `sk` in **CLN r17041** (2018-10-09), commit `FP-11753, FP-11754 - bugs fixed(Competition)` — a merge targeted at the `Assets/Scripts` subtree instead of the branch root. Inherited since through old MainClient -> CodeBranch@26818 (2020) -> current MainClient@37953 (2023).
  - **Fix:** the subtree ranges are redundant with root (verified for `Unity_Fishing_CodeBranch`: 0 revs on the subtree that root does not already cover). Cleanup = for **every** branch line, confirm subtree ranges (path suffix `/Assets/Scripts` stripped) are a subset of root's ranges, then `svn propdel svn:mergeinfo` on the redundant subtree(s), one dedicated commit. Root mergeinfo continues to cover them.
  - **Caveat:** propdel is only safe when root is a strict superset for *all* branch lines; one uncovered range would be lost and later re-merged. Sweep MainClient for other subtree-mergeinfo locations, not just `Assets/Scripts`, before deleting.
  - Surfaced during FP-44889 client merge (root-level merge of r56379); the task commit itself does not touch `Assets/Scripts`.
