# Backlog — FP-44965

- [x] Decide fate of upcoming grouped tournament 11251 (NX, start 2026-07-25 06:00 UTC) — stripped `Grouping` manually (chosen over `RegenerateFutureCompetitions`, which would wipe/regenerate 140 future comps to fix one)
- [x] Strip `$.Grouping` from template 168 `ConfigJson` on NX prod so future generations stop grouping — done manually (single row, not via SQL script)
- [x] Find and close the ingress channel — handed to QA (Nintendo content pours are QA-owned); QA comment posted on FP-44965 and ticket moved to QA. Check window 2026-01-01 → early March 2026
- [x] Side issue: 5 NX competition templates with invalid JSON (`ISJSON = 0`, FinishPoint unquoted keys) — not fixed here; they normalize when the LBM binary/content lands on NX (deferred to the LBM rollout)
- [x] Finalize investigation write-up and post to JIRA — posted to FP-44965 (comment 129978)
- [x] Correct the FP-43625 premise ("Nintendo has not launched matchmaking") — dropped: the statement holds for the new system (not deployed on NX); the old content-gated grouping leak and its fix are captured in `matchmaking/log.md` (2026-07-14) and the module card Related Tasks, so no separate FP-43625 edit is warranted
