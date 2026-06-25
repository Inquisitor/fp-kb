---
jira: FP-44670
title: "Club donation re-delivery: damage assessment + transfer-log retention fix"
status: waiting-for-release
executor: Stanislav Samoilov
created: 2026-06-24
type: story
platforms: [Steam, PS, XB, MOB, NX]
---
# FP-44670: Club donation re-delivery: damage assessment + transfer-log retention fix

> Origin bug + code review: FP-44478 (resolved). This Story (FP-44670) tracks the damage assessment and the
> log-retention fix that the investigation produced.

## Status
Spun off from the FP-44478 code review (resolved, Approve - the `SkipWhile`->`TakeWhile` + horizon-clamp fix
at MFT r16215 / NPN r16216 is correct). Grew into two strands:
1. **Damage recon** - done + cross-validated on all 5 F2P prod Mongo (`damage-recon/SUMMARY.md`): ~1,990
   re-delivered donations / ~384 accounts / ~29,873 surplus (12,569 bait + 17,304 CT), retention-bounded
   lower bound. But ~93% of token surplus is 2 relogin-loop farming accounts (one farmed 230k+ tokens via the
   exploit) per `damage-recon/account-vetting.md` - real legit-player damage is small. Full token scale still
   needs reconstruction from SQL `Stmt` (since 2017).
2. **Retention incident** - the 60-day `LogClearingJob`/`DeleteOldMessages()` deletes unimportant `clubLog`
   rows, and donation transfers are unimportant -> rolling loss of the only bait ledger. Retro-mark (B) DONE
   + verified on all 5 platforms (0 unprotected, `main2`); weekly re-mark reminder set
   (`trig_01BvHYNUAuHviTq5e18mxH9M`) until the code fix ships.

**Logs are now safe**, so the rest is unhurried. Pending: **A** mongodump `clubLog` backup x5 (`main2`) - do
first; **C** build/test/commit/release the `isImportant` code fix (applied in WC). Being re-scoped into its
own JIRA Story (this folder will move to the new key).

## Summary
The bug re-delivers a club donation (bait / club token) on rejoin when the per-profile dedup record is
purged early by `RemoveExpiredClubEvents` via a too-new client expiration horizon. Each delivery writes one
`clubLog` line; a re-delivery re-emits a byte-identical line (same itemId/count/requestId GUID/donor), so a
duplicate = identical `(UserId, Message)` with occurrence `n > 1`, surplus = `n - 1`.

- Signal, window, platform scope, interpretation: [damage-recon.md](damage-recon.md)
- Runnable Mongo queries (Q1 window/volume, Q2 headline, Q3 detail export, Q4 type cross-check):
  [damage-recon-queries.js](damage-recon-queries.js)
- Blast radius: bait + club tokens (auto re-delivery); buoys marginal (manual re-accept), caught by Q4.
- Window: purge path introduced r10273 (2023-04-27); practical start bounded by `clubLog` retention.
- End: ongoing until the fix lands on the Content release.

## Plan / next
See [backlog.md](backlog.md). First gate: run Q1 per platform to size the surviving window and volume,
then decide whether to run Q2-Q4 over the full window or narrow by date.

## Milestones (log)
- 2026-06-24: Task spun off from the resolved FP-44478 review. Damage signal nailed down (byte-identical
  `clubLog` delivery line per `(UserId, requestId)`); recon queries authored and validated on local
  Mongo 4.4.13 (`main.clubLog`); recon doc + query file relocated here from the review folder.
- 2026-06-24: Prod runs on all five F2P platforms; results under `damage-recon/<platform>/`. Cross-validated
  three ways (Q2 vs Q4 count, Q2 vs Q4 surplus, Q3 rows - exact match per platform), so detection is sound;
  fast queries explained by collection size (<2M docs), not a broken scan. Distribution is extremely
  concentrated (Steam top-2 = 89% of surplus; 2 Steam accounts = 93% of all token surplus) - looks like
  relogin-loop bot/QA accounts, not broad damage. Findings in `damage-recon/SUMMARY.md`.
- 2026-06-24: Vetted the top dupers against prod `Main.Profiles` (DataGrip point lookups, NOLOCK) -
  [damage-recon/account-vetting.md](damage-recon/account-vetting.md). The token dupers (Steam `f139316b`,
  `3b2ea48c`; PS `18760ea0`) are relogin-loop farming accounts - basis is **behaviour** (one donation
  re-delivered up to 327x in 6 days; one account farmed 230k+ tokens), NOT anti-cheat (FP anti-cheat is noisy,
  not relied on; CheatRating noted for reference only). Conclusion: real legit-player damage is far below the
  raw 60-day surplus; true token scale needs the `Stmt` reconstruction.
- 2026-06-24: Persistence/retention - CORRECTED. No Mongo TTL index on `clubLog`, but `clubLog` IS purged by
  the app-level `MongoAsyncProvider.DeleteOldMessages()`: it deletes docs older than `ClubLogStoreHorizon =
  60 days` **when `IsImportant` is false/absent**. Donation receives are logged via `UserLog(msg,
  isImportant:false)` -> unimportant -> purged at 60 days. Confirmed empirically: delivery-line `min(first)`
  is 2026-04-25 on every platform (run date - 60d). So the whole recon is a **60-day snapshot**, not the
  7-12 months implied by Q1's `minTs` (that floor is surviving *important* messages: club create/disband,
  roles, kick/leave, logo, "Reset ClubTokens"). Bug is live since 2023 -> multi-year total is gone.
  Bait/buoy have no other ledger; club tokens DO persist in SQL `Stmt` (Stats DB, `Currency='CT'`, longer
  retention) via `BalanceHelper.IncrementBalance` -> full token history recoverable there. (Earlier "not
  auto-purged" note was wrong - only checked `indexes.js`, missed the app-level cleaner; user caught it.)
  Preservation snapshot + Stmt cross-check in [preserve-queries.js](preserve-queries.js).
- 2026-06-25: Incident response. Brainstormed + spec'd + planned the retention fix (design/plan in
  `artifacts/`). Decisions: stop via retro-mark `IsImportant=true` (zero-deploy, scope = transfers only,
  user confirmed not whole clubLog); run order **B (mark) -> verify -> A (backup)** so the dump captures the
  marked state (safe because the mark is a content-free reversible boolean flip). Delivered: ops file
  `artifacts/retro-mark-important.js` (Task B); code fix C applied in SVN WC - `isImportant: true` on all six
  transfer `UserLog` calls (`ClubAdapter_ClubTokens.cs`, `ClubAdapter_BaitsBuoysFishing.cs`), `TestClubLog`
  capture + `ReceiveBait_marks_clublog_entry_important` regression test; CRLF+BOM normalized. Pending (user):
  run B+A on prod before 01:01; build + `dotnet test` C; commit C under FP-44478; then a server release.
- 2026-06-25: User ran B (retro-mark) on prod; verified via DataGrip. **Prod Mongo logs DB is `main2`, not
  `main`** (`main` is empty on prod) - my first verification hit empty `main` and read 0/0; re-ran on `main2`.
  Result on `main2`: protected (`IsImportant:true`) transfer rows = Steam 67015, PS 24230, XB 10592,
  MOB 11606, NX 4671; unprotected = 0 on Steam/PS/MOB/NX. XB had 4 unprotected - all donations from
  2026-06-24 23:54 (one bait exchange) that arrived AFTER the mark run; benign (new, ~59d from purge),
  exactly the "re-run until C ships" case. Fixed `main`->`main2` in the plan/queries. Documented the
  `main`/`main2` DB-name gotcha in the **project `CLAUDE.md` -> ## Databases** (auto-loaded, team-shared).
  User then re-marked the XB 4; re-verified XB unprotected = 0. **B (retro-mark) complete + verified on all
  five F2P platforms (0 unprotected).** Remaining: A (mongodump backup, `--db main2`) and C (build/test/
  commit/release).
- 2026-06-25: Re-scoped into its own JIRA Story **FP-44670** (umbrella for the whole thread: damage
  assessment + retention fix), under epic FP-43213 (Technical Debt - 2026 Q2), assignee/executor Stanislav,
  Scrum Team Other. Folder moved from `FP-44478--club-donation-redelivery-damage` to
  `FP-44670--club-donation-redelivery-damage`; status set `waiting-for-release` (blocked on the code-fix
  release). Weekly re-mark reminder `trig_01BvHYNUAuHviTq5e18mxH9M` runs until then. Anti-cheat framing
  dropped from the damage write-up (FP anti-cheat is noisy/unreliable) - the farming conclusion rests on
  re-delivery behaviour + the known 230k+ token case.
