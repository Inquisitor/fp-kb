# FP-45231 — Backlog

- [ ] Post the forensic comment on FP-45231 (origin r6966 / ivan / 2019 Retail->Ugc merge, the ~7-year inheritance chain, the r16160 materialization, and the cleanup commits r16365 / r16366). Drafted and approved; deferred by decision to a separate comment.
- [ ] Client side: check the client repo for non-root `svn:mergeinfo` (e.g. on `Assets/Scripts/`) and, once the server side is clean, propose the same cleanup to the client team.

## Decisions (not TODOs)

- Pre-MFT branches (LBM / KNW / IMV) are left as-is — retiring; out of scope. Residual re-contamination via a future LBM->MFT hotfix merge is accepted and noted in the JIRA body.
