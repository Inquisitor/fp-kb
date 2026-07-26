---
name: svn:mergeinfo lives only on the branch root
description: svn:mergeinfo must exist only on a branch's root directory; any mergeinfo on a sub-path (file/subdir) is a split-brain defect. Cross-branch carries must be root-level merges; record-only only after content verification
type: feedback
---
Invariant: `svn:mergeinfo` exists ONLY on a branch's root directory. `svn:mergeinfo` on any
sub-path (a file or a subdirectory) is a defect (split-brain) and must be removed.

**Cause:** a file- or subtree-level `svn merge` materializes the source's *inherited* root
mergeinfo onto the target node as explicit subtree mergeinfo (plus the merged rev). One such
merge is enough to pollute a path.

**How to apply:**
- **Cross-branch carry:** always root-level - `svn merge -c <rev> <branch-URL> <branch-WC-root>`.
  Never merge a single file/subtree. If the WC root is mixed-revision, `svn update` the root
  first - do NOT drop to a file-level merge to dodge the mixed-revision error.
- **record-only** asserts "merged" without applying the diff. Use it ONLY after verifying the
  change's content is actually present in the target code (`svn cat` / diff) - otherwise it
  falsely suppresses a needed merge. Scope it with `--depth empty` so it writes on the root only
  (a bare `--record-only` still stamps every subtree that already carries mergeinfo).
- **Cleaning existing subtree mergeinfo:** compare the subtree's recorded revs against the root's.
  - subtree revs are a subset of root -> deletion is behaviorally neutral; `svn propdel` freely.
  - subtree-only revs (not on root) -> per rev, verify the actual diff is present in the code;
    if present, record it on the root (record-only, verified) then delete; if absent, it is a
    false record - do a real merge, do not silently delete.
