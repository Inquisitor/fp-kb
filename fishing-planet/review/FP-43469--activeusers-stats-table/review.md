---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16089; r16177 merged to NPN @ r16178
jira: https://fishingplanet.atlassian.net/browse/FP-43469
---

# Review: FP-43469 — [WebAdmin][Stats] Create ActiveUsers (PlayerDailyActivity) stats table

## Summary

Customer request (Mary Key): a long-lived fact table recording each player's daily login
to the game, per calendar date, with min/max level reached that day, covering all years
since 2017. Motivation: `StatsFact` retains only the last year, so cohort/monetization
analyses (active-users-per-period split by level cohorts, AI-fed datasets) require digging
through other tables. Requested shape: `ActiveUsers [Userid, Timestamp as date, MinLevel,
MaxLevel]`. `GameSessions` exists but lacks level data.

Executor implemented this as a `PlayerDailyActivity` stats table with live hooks + backfill,
plus a bonus WebAdmin feature (player leveling history). On release: backfill from local
StatsFact + from backup tables on prods with truncated StatsFact.

## Scope

- **MFT r16089** — Add PlayerDailyActivity stats table with live hooks and backfill (+ bonus feature - player leveling history in WebAdmin)
  - DAL: `IPlayerDailyActivityProvider` / `PlayerDailyActivityDto` / `SqlPlayerDailyActivityProvider` (`SqlAnalyticsConnectionString`), registered in `DalFactory`; DB-integration tests
  - GameLogic: `DailyActivityManager` (Start/Update, in-memory `lastEventAt`), exception-swallowing writes
  - Hooks: login -> `Start` (`GameClientPeer_Travel`, gated by `IsJustLoggedIn`, beside `LogStartPlay`); level/rank-up -> `Update` (`GameClientPeer_Game.IncrementExperience`, only when `newGains` non-empty); disconnect -> `Update` (`GameClientPeer`, beside `FinalizeGameSession`)
  - SQL [Stats]: table `PlayerDailyActivity` (patch `MFT.S.2026.05.13-001`), SP `RegisterPlayerDailyActivity` (intermediate-day backfill + today row, MIN/MAX merge), fn `FindStatsFactIdByTimestamp` (binary search), one-time `Backfill_PlayerDailyActivity_From_StatsFact.sql`
  - WebAdmin: `PlayerController.DailyActivity`, model/row/chart-point, `DailyActivity.cshtml`, tools-partial link, csproj

> Branch-copy inheritance: NPN20260602 (Code) copied from MFT20260325:16130; r16089 <= 16130 -> already inherited in Code. Verified: r16089 appears in NPN history for `DailyActivityManager.cs`. No merge to Code required. Content does not merge down to Stable.

## Investigation Journal

- Intake: single commit per JIRA comment (MFT r16089). Executor field (`customfield_11224`) = Yuriy Burda, matches commit author — no hygiene issue.
- VCS audit: `svn log | grep FP-43469` over MFT confirms exactly one commit (r16089). WC at r16168 > r16089 — disk trustworthy, read files directly.
- Inheritance verified via `svn log` on NPN URL for `DailyActivityManager.cs` — r16089 present (branch-copy inheritance). Close phase skips Code merge.
- Hypothesis "provider writes to wrong DB" (table in [Stats], provider uses `SqlAnalyticsConnectionString`) — DISPROVEN: all sibling Stats providers (GameSession/FishingSession/FishStats) use `SqlAnalyticsConnectionString`; convention-consistent.
- Hypothesis "write amplification — Update fires on every XP gain/catch" — DISPROVEN: hook sits in `IncrementExperience`, gated by `newGains.Any(g => g != null)`; `newGains` = level/rank-up events from `LevelingManager`, not per-catch. Fires only on actual level/rank up.
- Disconnect hook placement verified: inside `saveProfile` + `ValidateSession` block beside `FinalizeGameSession`; fires regardless of `isMove`, but `Update` is idempotent (MIN/MAX merge) so harmless on travel.
- Compile sanity: `DalFactory.GetService<T>` exists; `WithDateCategoryAxis(DateTime?,DateTime?,ChartAxisBaseUnit,int)` 4-arg overload exists in `KendoChartExtensions`.
- SP logic walked against the 6 DB tests (continuous multi-day session backfill, level-up carry-forward, rank progression) — semantics match. Design records "logged-in on calendar date" via Start (login) + Update (level-up/disconnect); between-session gaps correctly NOT filled (per-session in-memory `lastEventAt`).
- code-reviewer agent (deep delegation) ran: confirmed SP MERGE/CTE/HOLDLOCK correctness, FindStatsFactIdByTimestamp half-open boundary semantics, Step 2 transaction-rollback retry safety, csproj wildcard + Content include. Raised 4 items; F-1 confirmed material, F-2 downgraded to Info (invariant holds), F-3/F-4 minor.
- F-1 routing: initially weighed as fix-under-FP-43469, then (per user) the release backfill had already been run and failed hard. Backfill scope (script fix + cross-platform historical data assembly) split into a dedicated Story FP-44568 (relates to FP-43469 + FP-44337), assignee Yuriy Burda. FP-43469 verdict therefore stays APPROVE on the code; backfill no longer gates it.

## Findings

### F-1: Backfill Step 1 — plain INSERT into intermediate table can hit PK collision across day boundaries [Medium]

**Description:** `SQL/Backfill_PlayerDailyActivity_From_StatsFact.sql` Step 1 loops day-by-day over EntityId ranges and does `INSERT INTO Temp... SELECT ... GROUP BY UserId, CAST(Timestamp AS date)` into a table with clustered PK `(UserId, ActivityDate)`. Adjacent day ranges are EntityId-contiguous, but the GROUP BY keys on the actual `Timestamp`, not on the iteration day. EntityId is only *roughly* monotonic with Timestamp (acknowledged in the script header — IDENTITY-vs-datetime race under concurrent inserts near midnight). A row whose EntityId falls in day N's range but whose Timestamp is on day N±1 produces a row keyed `(User, N±1)`; if that same `(User, N±1)` is also produced by the adjacent iteration (the normal case), the second `INSERT` violates the intermediate PK. Over a 2017-onward backfill of a billion-row StatsFact, at least one midnight-boundary collision is near-certain. No `IGNORE_DUP_KEY`, no `TRY/CATCH` — the job can abort mid-run (and re-runs drop/recreate the temp table, hitting the same collision again). Impact is on the one-time ops backfill, not shipped code.

**Investigation:** Confirmed from diff + structural analysis, then **empirically verified against [F2P] STEAM PROD STATS** (read-only, NOLOCK). Findings on `dbo.StatsFact` (~14.8B EntityId span):
- EntityId is strongly NON-monotonic with Timestamp at row granularity: in the most recent 20M rows, 21.6% of adjacent rows go backward in time, max backward jump ~41 min (2453 s).
- At *date* granularity the partition is usually clean, but NOT always. Per-date `[minId..maxId]` overlap probe (`maxId(D) - minId(D+1)`; −1 = clean, ≥1 = interleave):
  - recent 4 boundaries (2026-06-07..11) and q25 (2024-05): −1 (clean)
  - **q50 (2024-12-29/30): +1**, **q75 (2025-09-03..05): +2** — date ranges interleave.
- An interleave means a date-D row carries a higher EntityId than a date-(D+1) row, so no contiguous EntityId cut isolates the date; the strayed row is bucketed in the neighbouring day's iteration, grouped as `(user, D)`, and collides with the in-range `(user, D)` from day D's iteration -> PK violation. 2 of 3 historical anchors interleave; across ~3200 midnights since 2017 at least one collision is near-certain, and a 2627 error with no TRY/CATCH aborts Step 1 (re-run drops/recreates the temp table and re-hits the same boundary).
The half-open `FindStatsFactIdByTimestamp` boundaries make the *range scan* tolerant of this fuzziness (harmless edge include/exclude), but the per-day GROUP-BY against the intermediate table's strict PK is not. Step 2 already MIN/MAX-MERGEs into the main table; Step 1 does not apply the same pattern to its own intermediate table.

**Resolution:** `Filed → FP-44568`. The failed release run confirmed the defect live ("сильно навернулось"). Scope outgrew a one-line script fix — the historical backfill now also requires cross-platform data archaeology (PS pre-2026-06 StatsFact dropped in FP-44337 cutover, lives only in pre-drop backup/archive; Steam 2022-2024 on a separate .107 Stats server; XB/MOB/NX partially wiped). Split into a dedicated Story **FP-44568** (assignee Yuriy Burda, resumes after vacation). Fix = Step 1 `MERGE` with MIN/MAX (as Step 2) or `IGNORE_DUP_KEY` + clean the failed run's residue (preserve correct post-release live rows). Not urgent: live hooks capture forward data correctly. Code merged/inherited — not a code blocker for FP-43469.

**Update (2026-06-20):** the script fix actually landed under FP-43469 on 2026-06-11 — MFT r16177, merged to NPN (Code) r16178 — applying the recommended option (a): Step 1 now `MERGE`s with MIN/MAX into the intermediate table, so EntityId↔Timestamp skew folds in instead of aborting on a duplicate key (verified correct; non-NULL src makes the absent NULL-guard safe; `OPTION (LOOP JOIN, MAXDOP 1)` for plan stability). FP-44568 thus retains only the residue cleanup + cross-platform historical data assembly.

**Discovered by:** code-reviewer agent; empirically confirmed by skill against Steam prod Stats.

### F-2: FindStatsFactIdByTimestamp — `@midTs` not reset before per-iteration SELECT [Info]

**Description:** The binary-search loop assigns `@midTs` via `SELECT TOP 1 ... WHERE EntityId >= @mid`; T-SQL leaves `@midTs` stale if the SELECT returns no rows. Not a live defect: `@mid <= @hi <= MAX(EntityId)` always holds, so a row is always found; the stale path is unreachable. Append-only StatsFact rules out the concurrent-delete edge the agent raised.

**Investigation:** Invariant verified by hand. Agent's confidence (82) over-rated; downgraded to Info.

**Resolution:** Accepted as-is. Optional defensive hardening: `SET @midTs = NULL;` before the SELECT (zero cost, future-proofs against edits that break the invariant). Not required.

**Discovered by:** code-reviewer agent.

### F-3: GetActivity has no ORDER BY; row order guaranteed only client-side [Low]

**Description:** `SqlPlayerDailyActivityProvider.GetActivity` returns rows in non-deterministic order; `PlayerDailyActivityModel.Fill` compensates with `.OrderBy(ActivityDate)`. Works correctly, but the ordering contract is invisible to future callers of the provider.

**Resolution:** Skipped (works). Optional: add `ORDER BY ActivityDate ASC` to the SQL.

**Discovered by:** code-reviewer agent.

### F-4: WebAdmin "Days" column counts recorded rows, not calendar span [Low]

**Description:** In `PlayerDailyActivityModel.Extend`, `Days` increments per merged DB row. With `MergeWithinDays = 7`, a displayed range can span more calendar days than `Days` shows (e.g. "2026-01-01 → 2026-01-10 | 3 Days" = 3 active days). The value (active days within the span) is reasonable, but the label "Days" is ambiguous against the date range. Cosmetic, bonus WebAdmin feature.

**Resolution:** Skipped. Optional: rename column header to "Active days" in `DailyActivity.cshtml`.

**Discovered by:** code-reviewer agent.

## Verdict

**APPROVE.** Shipped code is sound: the table, the `RegisterPlayerDailyActivity` SP (CTE/dual-MERGE/HOLDLOCK/MIN-MAX idempotency verified against tests), the binary-search boundary function, the `DailyActivityManager` and its three hook sites, and the WebAdmin UI all check out. Conventions followed (NOLOCK on append-only StatsFact, BOM, csproj includes, `SqlAnalyticsConnectionString`). Defensive design: stat writes swallow exceptions and never break gameplay. Already inherited in Code branch (NPN) via branch copy — no merge needed.

**F-1** (Medium) — the backfill script defect — is descoped into **FP-44568** (filed; assignee Yuriy Burda): empirically confirmed when the release backfill run failed, and the historical reconstruction needs cross-platform data assembly beyond a script fix. F-2/F-3/F-4 are optional polish. FP-43469's own deliverable (table + SP + hooks + WebAdmin + live capture) is complete and correct → approve.

---

## Round 2 — r16177 backfill duplicate-key fix (re-review)

Re-review of the F-1 fix. The script fix landed under FP-43469 (not FP-44568) on 2026-06-11, before FP-44568 was filed; the task was already Closed at Round-1 close. Triggered by spotting r16177 a week later.

**Executor:** Yuriy Burda — JIRA comment 124172 (2026-06-11): MFT r16177, merged to NPN r16178.

### Scope (Round 2)

- **MFT r16177** — FP-43469 Fix duplicate-key abort in the StatsFact PlayerDailyActivity backfill
  - Step 1: plain `INSERT ... GROUP BY date` into the intermediate table replaced with a `MERGE` (MIN/MAX on MATCHED, INSERT on NOT MATCHED) — the recommended option (a) from F-1
  - `OPTION (LOOP JOIN, MAXDOP 1)` + comment on plan stability; `SYSUTCDATETIME()` timestamps added to PRINTs
- **NPN r16178** — merge of r16177 into Code branch (by executor)

### Investigation (Round 2)

- Intake: fix posted as JIRA comment 124172 with merge note; executor field matches commit author. Task status = Closed (closed at Round-1 close 2026-06-18).
- VCS audit (WC at r16168 < r16177 — stale, read via `svn diff -c`/`svn cat`, not disk): MFT has exactly one FP-43469 commit after r16089 (r16177); NPN r16178 is a clean TortoiseSVN merge of r16177 (mergeinfo + the one file). `svn cat -r16177` (MFT) and `svn cat -r16178` (NPN) are **byte-identical** — merge faithful.
- Fix resolves F-1: a strayed `(UserId, ActivityDate)` from an adjacent EntityId-range iteration now hits `WHEN MATCHED` -> MIN/MAX UPDATE instead of a duplicate-key INSERT. No 2627, no abort.
- Data-faithful, not just collision-avoiding: MIN/MAX are associative, so folding partial per-iteration MIN/MAX across iterations yields the correct global MIN/MAX for the split `(user, date)`. Strictly better than `IGNORE_DUP_KEY` (which would drop the strayed row's contribution).
- Safety checks: (a) absent NULL-guard on MATCHED is safe — src is always non-NULL (`MIN(Level)` under `Level IS NOT NULL`, rank via `COALESCE`), and the intermediate is written only by this MERGE, so tgt is never NULL; (b) no "MERGE source duplicate key" error — join key `(UserId, ActivityDate)` equals the `GROUP BY`, src keys unique; (c) HOLDLOCK correctly omitted (private freshly-created intermediate, no concurrent writers — unlike Step 2 on the live table); (d) `LOOP JOIN`/`MAXDOP 1` are plan hints, results unaffected.
- Step 2 and the DROP/CREATE-intermediate block are untouched; full re-run idempotency preserved.
- code-reviewer agent (independent, stale-WC warned + given `svn diff`/`svn cat` + the dumped fixed file) confirmed all 7 checks with no material findings: 2627 eliminated; MIN/MAX fold associatively correct; NULL-guard asymmetry justified (scratch table, src non-NULL); no source-dup/HOLDLOCK/trigger hazard; LOOP JOIN/MAXDOP appropriate; Step 2 + idempotency intact; `@@ROWCOUNT` shift benign (now counts insert+update — an improvement). Matched skill recon.

### Findings (Round 2)

None. The fix is correct, data-faithful, and applies exactly the recommended approach (option a).

### Verdict (Round 2)

**APPROVE.** r16177 resolves F-1's script defect: Step 1 `INSERT`->`MERGE` (MIN/MAX) eliminates the duplicate-key abort and folds EntityId↔Timestamp-skewed rows correctly rather than dropping them. Merge to Code (NPN r16178) already done by the executor and verified byte-identical — close phase has no merge to perform. F-1 (Round 1) is now resolved in code; FP-44568 retains only the residue cleanup + cross-platform historical data assembly.

No JIRA comment posted for Round 2: the task is already Closed, the fix carries the executor's own commit/merge note (124172), and the Round-1 LGTM (125074) is already on the thread — a third comment on a closed ticket would be noise. The Round-2 sign-off lives here in KB.
