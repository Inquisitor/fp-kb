# FP-44478 club-donation-redelivery — backlog

## Done
- [x] Damage recon Q1-Q4 on all 5 F2P prod Mongo + cross-validation (`damage-recon/SUMMARY.md`)
- [x] Vet top dupers vs `Main.Profiles` — all token dupers are anti-cheat-flagged bots (`damage-recon/account-vetting.md`)
- [x] Retention incident design + plan (`artifacts/`)
- [x] B - retro-mark `IsImportant=true` on transfer rows, all 5 platforms (`main2`), verified 0 unprotected
- [x] Weekly re-mark reminder routine (`trig_01BvHYNUAuHviTq5e18mxH9M`, Tue 09:00 UTC, until code fix ships)

## Pending
- [ ] **A - backup FIRST:** `mongodump --db main2 --collection clubLog` on all 5 F2P prod Mongo to cold storage
- [ ] **C - code fix release:** build + `dotnet test` + commit + ship the `isImportant: true` transfer-log change
- [ ] Until C ships: weekly re-run of `artifacts/retro-mark-important.js` (reminder handles the nudge)
- [ ] **After C is deployed to ALL platforms: cancel the weekly re-mark reminder** routine `trig_01BvHYNUAuHviTq5e18mxH9M` (https://claude.ai/code/routines)
- [ ] Re-scope this work into its own JIRA Story + move this folder to the new key (in progress)

## Reports (promised in the Story description)
- [ ] Produce the damage reports (per-platform numbers, per-account breakdown) and **attach them to the JIRA Story** so Support has them — the description says "Detailed figures will be attached as reports"

## Full picture / remediation
- [ ] Reconstruct full token (CT) history from SQL `Stmt` (currency ledger, retained since 2017) — clubLog's ~60-day window massively undercounts; at least one account is known to have farmed 230k+ club tokens via this exploit
- [ ] Remediation (incl. claw-back) — DECIDE after the full picture is in; not settled (the 60-day numbers are a lower bound). Investigate when/how the farming happened

## Think about later (after the main work)
- [ ] Tooling idea: a player money-supply graph / sharp-spike detector built on the currency statement logs (`Stmt`, increment + resulting balance, since 2017) — surfaces abnormal currency accumulation (this exploit and others)
