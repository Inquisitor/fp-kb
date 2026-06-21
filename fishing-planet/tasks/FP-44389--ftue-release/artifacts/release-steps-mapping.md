# 2026.4 FTUE — Release Checklist Steps Mapping

Branch-specific release steps for the 2026.4 FTUE/Old Ponds Rework release, derived by
mapping JIRA `Server Release Checklist Steps` (`customfield_11323`) over MFT branch commits
**and** cross-checking with an `SQL/` / `NoSql/` / service-tree sweep to cover the field's
blind zone (only 23 of 107 MFT-committed tasks have the field set).

Checklist: page `5551947777`. Template: page `4395597825`. Field options enumerated below.

## Method

1. `svn log --stop-on-copy` on the MFT branch -> 107 unique `FP-XXXXX` keys.
2. JQL `key in (...) AND cf[11323] is not EMPTY` -> 23 tagged tasks.
3. `svn diff --summarize -r <fork>:HEAD` over `SQL/`, `NoSql/`, `WebServices/`, `Twitch/`
   to catch release-relevant changes from tasks that did **not** set the field.

The field is the canonical vocabulary of "what can happen on a release"; every option should
map to a template step **or** be by-design manual (Custom DB scripts, Server Configuration).

## Field options (customfield_11323) and meaning

| Option                     | Meaning (per owner)                                                                                                                                                                                                                                                                                                                                    |
|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| DB Migrations              | SQLCheck picks up `\SQL\Patches`. Auto on big releases; the tag is a reminder for small hotfix releases where a structural change incompatible with old binaries forbids rolling node restart                                                                                                                                                          |
| NoSQL scripts              | Structural Mongo changes (`\NoSql`); historically only indexes                                                                                                                                                                                                                                                                                         |
| DataPump                   | QA->PROD data transfer (usually the DataPump tool, can be online); flagged when a task needs data loaded (e.g. email templates)                                                                                                                                                                                                                        |
| Environment Variables      | NOT carried by DataPump; set by hand, must be controlled. **Creating** a var in default (off) state = DB Migrations; the **decision to enable/disable** = this option. May have no task/code (GD/producer/live-ops decision)                                                                                                                           |
| A/B Tests                  | Same as Env Vars — may be code-driven or a stakeholder decision with no task                                                                                                                                                                                                                                                                           |
| Webhooks Service           | Deploy if the WebHooks project changed; check for breaking changes each release                                                                                                                                                                                                                                                                        |
| Twitch Service             | Deploy if `TwitchAccountLinking` changed; same recon                                                                                                                                                                                                                                                                                                   |
| Post-Release Checks        | Task-specific post-release action; the task is usually in Resolved (waiting-for-release)                                                                                                                                                                                                                                                               |
| Offline Profile Conversion | "Offline" = the profiles TABLE (a converted copy). Heavy, millions of rows, hours; prepped on a copy days ahead (`ProfilesConv`), swapped in downtime. Big releases with binary/DB-incompatible changes. Example: `R202412_remove_akhtuba_from_profiles`                                                                                               |
| Online Profile Conversion  | "Online" = live profiles table; players must be offline (online profile lives in node memory, saved unconditionally). For fixing corrupted data / compensations, changes compatible with current binaries/DB. Auto-on-login conversion (e.g. buoys) is an even lighter variant; the release tool can background-convert offline profiles after release |
| Server Configuration       | Reconfiguring the servers themselves (OS / software / hardware), beyond app config. Added by hand, no fixed template place                                                                                                                                                                                                                             |
| Custom DB scripts          | Task-specific scripts (`\SQL\Releases`), NOT auto-run by SQLCheck. Added by hand, no fixed template place                                                                                                                                                                                                                                              |

## 2026.4 instances per category

| Category                   | 2026.4 instance                                                                                                                              | Checklist action                                                                                           |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------|
| DB Migrations              | ~30 `MFT.M.*` + merged `LBM.*` patches                                                                                                       | auto SQLCheck                                                                                              |
| NoSQL scripts              | none (NoSql unchanged since fork)                                                                                                            | routine `indexes.js` only                                                                                  |
| DataPump                   | FP-43334 Colored Buoys, FP-43400 rod-pod stamina                                                                                             | "Transfer data from QA"; both covered by routine sync (see DataPump note)                                  |
| Environment Variables      | `IgnoreWrongStrikeWhileHookPendingOnFloat = Y` (FP-43884)                                                                                    | add to Env Vars block (see paste-ready below)                                                              |
| A/B Tests                  | Platform #10 Targeted Ads (liveops request, today; no task/code)                                                                             | already in checklist (Default=false, IsActive=false => OFF for all); confirm off/off is the intended state |
| Webhooks Service           | no changes since fork                                                                                                                        | mark "no changes"                                                                                          |
| Twitch Service             | no changes since fork                                                                                                                        | mark "no changes"                                                                                          |
| Post-Release Checks        | FP-43469 PlayerDailyActivity backfill                                                                                                        | already in checklist                                                                                       |
| Offline Profile Conversion | none                                                                                                                                         | remove the 3 offline-converter steps from this checklist                                                   |
| Online Profile Conversion  | `RemoveDeprecatedBuoys`, `FixDepletedItems`, `ResetLevel1SpawnPoint`                                                                         | add movable step + codes + optional post-release background run                                            |
| Server Configuration       | none found in code                                                                                                                           | confirm none needed (OPEN)                                                                                 |
| Custom DB scripts          | `R202606-ConvertTransactionPrices-UWP-Main/Stats.sql` (FP-43192, in checklist); `R202606-TournamentParticipantRatingBackfill.sql` (FP-43816) | add row for FP-43816 -> POST-RELEASE backfill (review APPROVED, see below)                                 |

## Tagged tasks (23)

DB-Migrations-only (16): FP-40132, FP-41845, FP-42346, FP-42798, FP-42890, FP-42914,
FP-43171, FP-43176, FP-43403, FP-43415, FP-43421, FP-43422, FP-43620, FP-43705, FP-43904, FP-44159.

Non-standard (7):
- FP-43192 Custom DB scripts -> UWP price conversion (R202606-...-UWP-*) — in checklist
- FP-43816 DB Migrations + Custom DB scripts -> R202606-TournamentParticipantRatingBackfill.sql — needs row
- FP-43469 DB Migrations + Custom DB scripts + Post-Release Checks -> ActiveUsers table (renamed PlayerDailyActivity); MFT.S.2026.05.13-001 + procs RegisterPlayerDailyActivity / FindStatsFactIdByTimestamp + Backfill_PlayerDailyActivity_From_StatsFact.sql
- FP-43553 Custom DB scripts -> tournament ConfigJson fix-up; superseded by "Refresh FUTURE Competition Configs" button (template step E); old manual script was R202604-Leaderboards-Rating-Matchmaking-FixUp.sql
- FP-39539 Custom DB scripts -> KWD currency; only R202510-ConvertKwdTransactionPrices-Steam.sql (prior release 2026.x) — OUT OF SCOPE for 2026.4
- FP-43334, FP-43400 DataPump (see above)

## Blind-zone catches (SQL/ sweep, not surfaced by the field)

- `MFT.M.2026.05.20-020 [EnvironmentVariables].sql` — creates `IgnoreWrongStrikeWhileHookPendingOnFloat = 'N'` (FP-43884). Enable decision -> Env Vars block.
- ProfileConversions patches (003 create table, 004 insert, 011 +ParametersJson, 012 rename to RemoveDeprecatedBuoys, 019 FixDepletedItems, 023 ResetLevel1SpawnPoint) — Online/auto conversions, none tagged Online Profile Conversion.
- `R202604-Leaderboards-Reset.sql`, `R202604-Leaderboards-Rating-Matchmaking-FixUp.sql` — belong to the 2026.3 Leaderboards release (already run on Steam 2026-04-30), present in MFT via merge. OUT OF SCOPE for 2026.4 FTUE.

## Paste-ready content

### Environment Variables block
```
Environment Variables:
(Block early wrong-strike for float setups, FP-43884) IgnoreWrongStrikeWhileHookPendingOnFloat = Y
  -- enable on QA / CBT / PROD after release; created as N by patch MFT.M.2026.05.20-020
```
Decision source: FP-43884 comment, client lead Kyrylo Rovnyi, 2026-05-21.

### Online Profile Conversion step (movable; default post-release)
Conversions are registered as enabled `dbo.ProfileConversions` rows (via SQL patches) and apply
LAZILY: the same `ProfileConversionRunner` fires automatically the next time each player logs in,
so no action is strictly required for correctness. The checklist step is an optional PROACTIVE
SWEEP applying those conversions up front to still-offline profiles so the population converts
promptly instead of trickling in over weeks.

Per enabled conversion: `ReleaseTool.exe --finalize-conversion <ConversionId> [--retry]`
(`ProfileConversionFinalizer.Run`): selects profiles with no `ProfileConversionUserStatus` row for
that ConversionId, OFFLINE only (`SmartOfflineProfileUpdater`); online/returning players self-convert
on login via the same runner. Idempotent (per-user status row), backs up each profile first. Run
post-release with the farm up; movable into downtime only if a conversion must be fully applied
before players return.

`--retry` semantics (verified in code): first pass takes profiles with no status row; `--retry`
re-includes only profiles whose status has `HasError = 1` (successful ones stay skipped). So run
once normally, then `--retry` to drain errored profiles. Arg is a numeric `ConversionId`
(`int.TryParse`), not the Code -> look up the ID:
`SELECT ConversionId, Code FROM dbo.ProfileConversions WHERE IsEnabled = 1;`

2026.4 enabled conversions (ConversionId verified on QA Main; sequential by patch order, table is
new this release so the same across streams):
- `1` `RemoveDeprecatedBuoys` (FP-43271/FP-43291) - strips deprecated Lone Star / Lesni Vila buoys from profiles
- `2` `FixDepletedItems` (FP-43705) - removes orphan inventory items left at non-positive Count/Amount by past exploits
- `3` `ResetLevel1SpawnPoint` (FP-44159) - resets level-1 Lone Star migrants to the clean 3D start new players get

Concrete commands: `ReleaseTool.exe --finalize-conversion 1` / `2` / `3` (add `--retry` for a second
pass over errored profiles).

### Custom DB script row — FP-43816 (Post-Release)
Step: "Backfill TournamentParticipants rating snapshots (FP-43816)". Post-release, non-blocking.
Run `\SQL\Releases\R202606-TournamentParticipantRatingBackfill.sql` with `@DryRun = 1`, review,
then `@DryRun = 0`, verify. Idempotent (COALESCE fills only NULL AtReg/AtStart rating columns).
Prereq (standard, already ordered): DDL patch `MFT.M.2026.06.04-024` applied + new binaries deployed.
Review verdict: Approve (MFT r16149 -> NPN r16150); F-1 cross-kind-rating NULL on backfilled rows
is display-gated, non-blocking.

## Template (recurring) fixes
1. "Take all players offline" step references `\SQL\Patches\0-DataPrepare.sql` — file does
   not exist; correct to `_DataPrepare.sql` (the `0-` variant lives only in `Patches\OldRetail`).
2. Add a movable Online/auto Profile Conversion step.

## DataPump mechanics (Photon/tools/DataPump)

- Driven by an allowlist **script file** (`args[2]`, `File.ReadAllLines`) of `select ... from <table>`
  lines; the operator's "Pump Data From QA.cmd" passes the current sync script (desktop-side, NOT
  in repo — `Patches/*.txt` are only historical samples). A `forbiddenTables` denylist is applied
  on top: `EnvironmentVariables`, `AbTests`, `Users*`, `Profiles*`, `Transactions`, `Rooms`,
  `Tournaments*`, all `*RatingsCurrent` / `*RatingHistory` / `*LeaderboardStatus`, etc. are never
  pumped (unless `forced`). This is why Env Vars / A/B Tests must be set by hand.
- Per-table **structure match required**: DataPump compares source vs target
  `INFORMATION_SCHEMA.COLUMNS`; on column-count mismatch it skips the table. Invariant: the SQL
  patch that adds a column must run BEFORE DataPump, else the table is skipped. Checklist order
  (Apply structural changes -> Transfer data from QA) already satisfies this.

### #7 verdict (DONE)
- FP-43400 -> GV `Fishing.StaminaLoseMultiplierOnRodStand=1.0`; GlobalVariables non-forbidden,
  fully replaced by QA->PROD sync at release. Covered.
- FP-43334 -> buoy GV + `Ponds.UnlimitedBuoyRecolors` column. Ponds/GlobalVariables non-forbidden,
  standard content; new column auto-carried by column-match (patch runs first). Covered.
- No NEW table needs adding to the sync script.
- Residual manual checks (operator-side): sync script lists Ponds + GlobalVariables; QA actually
  holds the pond flag values and GV values.

## Release note: Regenerate future competitive activities (why unconditional)

The "Regenerate future tournaments" / "Regenerate future competitions" presses are destructive by
design (`TournamentSchedulingAdapter.RegenerateFutureCompetitions` -> `RemoveFutureCompetitiveActivities`
beyond the next spawn boundary, then `RandomizeCompetitions`). They are run on EVERY release on
purpose: the schedule grid is generated ~2 weeks ahead, so any release that adds/removes competition
or tournament templates invalidates the pre-generated grid -> blanket regenerate. ~10 years of
practice, no complaints. "Refresh FUTURE Competition Configs" is the non-destructive in-place
ConfigJson patch layered on top (it replaced the old per-release fix-up SQL, see FP-43553).

## Open items
- A/B Test Platform #10 (Targeted Ads): origin = liveops request today (DONE); confirm off/off is the intended ship state.
- Server Configuration: confirmed none required for 2026.4 (no config/infra changes).
