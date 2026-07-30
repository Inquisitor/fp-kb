---
name: Server Release Checklist Steps field
description: customfield_11323 = "Server Release Checklist Steps" (multi-select) in FP — vocabulary of release actions, option->template-step mapping, the SQL-sweep blind-zone cross-check, the env-var/A/B-test rollout audit method, the mandatory closure/review field gate, and a release-mechanics cheat-sheet (DataPump denylist, profile conversions, env-var create-vs-enable, destructive regenerate)
type: reference
---
JIRA field that tags a task with the release actions it requires. It is the canonical vocabulary of
"what can happen on a server release", and the primary tool for assembling the branch-specific part of
a Server Release checklist (template page `4395597825`, under SERVER RELEASE CHECKLISTS page `60097315`).

- **Field ID:** `customfield_11323`
- **Type:** `com.atlassian.jira.plugin.system.customfieldtypes:multiselect`
- **Display name:** `Server Release Checklist Steps`
- **How to read:** request explicitly in `getJiraIssue` `fields` (custom fields are dropped by the
  default markdown view). Bulk: JQL `cf[11323] is not EMPTY`.

**Why it exists (the non-obvious part):** on a big release the structural steps (DB Migrations, NoSQL,
DataPump) run anyway. The field's real value is as a **reminder for small hotfix releases** (Fix
Version `X.Y.Z.W`, stop-swap-start, sometimes rolling node-by-node without a full farm stop). A
structural DB change **incompatible with the old binaries** forbids a rolling restart -> you need a
full stop + DB apply after stop. The tag is what stops that from being forgotten.

## Options (12) -> template step

| Option                     | Meaning                                                                                            | Template step                                   |
|----------------------------|----------------------------------------------------------------------------------------------------|-------------------------------------------------|
| DB Migrations              | `SQLCheck` applies `<project>/SQL/Patches`                                                         | Apply structural changes                        |
| NoSQL scripts              | Mongo structural changes (`<project>/NoSql`); usually only indexes                                 | Apply structural changes / Create Mongo indexes |
| DataPump                   | Important world data transfer via `DataPump` (e. g. email templates, other content rows)           | Transfer data updates from QA                   |
| Environment Variables      | enable/disable decision on a `EnvironmentVariables` row (see below)                                | Environment Variables and AB Tests              |
| A/B Tests                  | activate/deactivate an A/B test (see below)                                                        | Environment Variables and AB Tests              |
| Webhooks Service           | deploy if the `WebHooks` project changed                                                           | Deploy Webhooks Service                         |
| Twitch Service             | deploy if `TwitchAccountLinking` changed                                                           | Deploy the Twitch Service                       |
| Post-Release Checks        | task-specific post-release action (often a backfill); task usually in Resolved/waiting-for-release | Post release checks                             |
| Offline Profile Conversion | heavy conversion prepped on a Profiles copy ahead of release (see below)                           | Setup/Start/Perform offline converter           |
| Online Profile Conversion  | lighter conversion of the live Profiles table / auto-on-login (see below)                          | (movable) Auto profile conversions step         |
| Server Configuration       | OS/software/hardware/infra reconfig                                                                | **no fixed place** - add by hand each release   |
| Custom DB scripts          | task-specific one-off scripts in `<project>/SQL/Releases`, NOT auto-run by `SQLCheck`              | **no fixed place** - add by hand each release   |

**Invariant:** every option should map to a template step, **or** be deliberately placeless (Custom DB
scripts, Server Configuration — added by hand, position varies). An option with neither = a template gap.

## Blind-zone cross-check (do not trust the field alone)

The field is set on only a fraction of release-relevant tasks (frequently a minority). Always cross-check
against what actually changed in the Code branch since it forked:

1. `svn log --stop-on-copy` on the branch -> unique `FP-XXXXX` keys.
2. JQL `key in (...) AND cf[11323] is not EMPTY` -> the tagged subset.
3. `svn diff --summarize -r <forkRev>:HEAD` over `SQL/`, `NoSql/`, the WebHooks project, the Twitch
   project -> release-relevant changes from tasks that never set the field.

The sweep is what catches untagged env-vars, profile conversions, and custom scripts. Fork revisions:
`_index.md` -> Server Branch Ancestry.

## Release mechanics cheat-sheet

**DataPump** (`<project>/Photon/tools/DataPump`): driven by an **allowlist** script file (`select ... from
<table>` lines; the operator's "Pump Data From QA.cmd" passes it; in-repo `Patches/*.txt` are only
historical samples). A **forbiddenTables denylist** is applied on top — `EnvironmentVariables`, `AbTests`,
`Users*`, `Profiles*`, `Transactions`, `Rooms`, `Tournaments*`, all `*RatingsCurrent`/`*RatingHistory`/
`*LeaderboardStatus` are never pumped. This is why **env vars / A/B tests must be set by hand**. Per-table
**structure-match**: source and target `INFORMATION_SCHEMA.COLUMNS` must match or the table is skipped ->
the column-adding patch must run **before** DataPump (checklist order already does this).

**Environment Variables** (`EnvironmentVariables` table, read by the game): **creating** a var in its
default (usually OFF) state is a **DB Migration** (auto via SQLCheck patch); the **decision to enable/
disable** it is the **Environment Variables** step — set by hand per stream, not carried by DataPump, and
may have **no task/code** (a GD/producer/live-ops decision).

**A/B Tests** semantics: `IsActive=false` + `DefaultValue=false` -> feature OFF for all; `IsActive=false`
+ `DefaultValue=true` -> ON for all (global override); `IsActive=true` -> real split. Like env vars, may
be a stakeholder decision with no task.

**Profile conversions** — "offline/online" names the state of the **Profiles table**, not the process:
- *Offline*: changes incompatible with current binaries/DB, millions of rows, hours. Prepped days ahead on
  a Profiles **copy** (e.g. `ProfilesConv`), re-converting profiles touched after the run; in downtime only
  the last-hour stragglers are converted, then the copy is swapped in. Multi-day prep; remove the steps if
  no such conversion ships.
- *Online / auto-on-login*: compatible changes (corrupted-data fixes, compensations, deprecations). Codes
  registered as enabled rows in `dbo.ProfileConversions` via SQL patches; the runtime `ProfileConversionRunner`
  applies them **lazily on each player's next login**. Optional **proactive sweep** (so the base converts in
  hours, not weeks): `ReleaseTool.exe --finalize-conversion --code <Code> [--retry]`
  (`<project>/Photon/tools/ReleaseTool`, `ProfileConversionFinalizer`). It processes profiles with no
  `ProfileConversionUserStatus` row for that conversion, **offline only** (`SmartOfflineProfileUpdater`),
  backs up each changed profile, idempotent. `--retry` re-includes only previously-errored profiles
  (`HasError=1`). The arg is the `Code` (`SELECT ConversionId, Code FROM dbo.ProfileConversions WHERE
  IsEnabled = 1`; unique via `UQ_ProfileConversions_Code`), **not** the numeric `ConversionId` — that id is
  a per-database `IDENTITY`, so identical numbering across streams is not guaranteed (in practice it has
  matched: the rows are inserted by the same patches in the same order). Switched from the id to the code by
  FP-44701 (MFT r16375, NPN r16376); branches that predate it still take the positional numeric id.

  A conversion that finds nothing to do still records a `ProfileConversionUserStatus` row (the logon path
  commits on `Unchanged`, not only on `Changed`), and both the logon path and the finalizer skip any player
  who has one — `--retry` re-opens only `HasError=1`. So enabling a conversion before the data it repairs
  exists on that platform burns each player's single pass; `IProfileConversionProvider.ResetConversion` is
  the way back.

**Regenerate future competitive activities** (WebAdmin Tools): "Regenerate future tournaments / competitions"
are **destructive by design** (`TournamentSchedulingAdapter.RegenerateFutureCompetitions` ->
`RemoveFutureCompetitiveActivities` beyond the next spawn boundary, then `RandomizeCompetitions`). Run on
**every** release on purpose: the schedule grid is generated ~2 weeks ahead, so any release that adds/removes
templates invalidates it. "Refresh FUTURE Competition Configs" is the **non-destructive** in-place ConfigJson
patch layered on top (it superseded the old per-release fix-up SQL).

## Env-var / A/B-test rollout audit

Env vars and A/B tests are the dangerous part of a release: not carried by DataPump, set by hand, and
sometimes decided by stakeholders with no task or code. Audit them every release:

1. **Enumerate** the rows the release adds/changes — from patches tagged in the filename
   (`<project>/SQL/Patches/*[EnvironmentVariables]*.sql`, `*[ABTests]*.sql`) cross-referenced to JIRA.
2. **Desired prod value** per row — from the GDD, the release checklist, or the stakeholder decision.
3. **Classify the action** at release: *auto* (created in its default state, no step), *flip* (feature
   flags are typically inserted `N`/`false` and must be set `Y`/`true` at launch), *verify* (TBD —
   confirm with the owner).
4. **Compare QA vs PROD** to read intent and catch drift: a flag already at the launch value on QA
   signals it ships that way; patch-default on QA suggests leave inactive. QA may legitimately differ
   from PROD (content-sync timing, etc.).
5. **Scope:** only `EnvironmentVariables` and `AbTests` need manual rollout entries. `GlobalVariables`
   and `JsonVariables` are fully replaced by the QA->PROD DataPump at release (final prod state ≡ QA),
   so they carry via the "Transfer data from QA" step — no manual flip.

**Naming gotcha (`RemovePrefix`):** the `EnvironmentVariables` and `GlobalVariables` caches strip one
dotted prefix from the DB key — `Prefix.Name` resolves to code-side `Name`, so `Prefix.Name` and bare
`Name` collide on the same lookup. A name with **two or more dots throws** (`InvalidOperationException`)
at cache load (`EnvironmentVariableCache.RemovePrefix` / `GlobalVariablesCache.RemovePrefix`). Keep DB
variable names to at most one dot.

## Closure / review gate (mandatory)

When closing a task (`kb-close-task`) or finalizing an approving review (`jira-review-close`), the
agent is responsible for ensuring release-relevant work is tagged -- not merely flagging it. The
SQL-sweep at release time is a backstop, not a substitute: an untagged task is a release-day miss.

1. Derive the required options from the change's commits (the reviewed diff for review; `svn log` /
   `svn diff --summarize` on the task's revs for close):
   - `SQL/Patches/**`            -> DB Migrations
   - `SQL/Releases/**`           -> Custom DB scripts
   - `NoSql/**`                  -> NoSQL scripts
   - patch tagged `[EnvironmentVariables]` -> candidate Environment Variables (creation-in-default is
     only a DB Migration; an enable/disable decision is the EV tag -- user decides)
   - patch tagged `[ABTests]`    -> candidate A/B Tests (same: user decides)
   - profile-conversion code / `dbo.ProfileConversions` row -> Online Profile Conversion
     (or Offline for a copy-table conversion)
   - WebHooks project -> Webhooks Service; Twitch project -> Twitch Service
   - content rows for QA->PROD   -> DataPump
   - a resolved / waiting-for-release post-release action -> Post-Release Checks
2. Read `customfield_11323` explicitly (custom fields are dropped by the default view).
3. If the field misses any derived option, this BLOCKS closure. The agent must:
   - Convey the release impact concretely: name the artifact (patch / script / value / service), what
     runs at release (auto SQLCheck / manual script / hand-set value / service deploy), and which
     option is missing.
   - Drive it to set:
     - Mechanical options (DB Migrations, NoSQL scripts, Custom DB scripts, Webhooks/Twitch Service,
       Profile Conversion, DataPump): propose the exact value; on user approval set it via
       `editJiraIssue` (`customfield_11323` = array of option ids below) and verify, or have the user
       set it.
     - Judgment options (Environment Variables, A/B Tests, Post-Release Checks, Server Configuration):
       present the candidate; the agent cannot decide enable/scope -- require the user's explicit
       confirmation before it goes in.
   - The only way past an unset field is an explicit user waiver with a stated reason (recorded in the
     close / review).
4. Mandatory, not advisory. Closure is not complete until the field reflects the change's release
   steps or the user has explicitly waived.

Why here and not in `jira-review-open`: open finalizes nothing (it drafts a local verdict, writes no
JIRA, runs no merge), so an enforcing gate there would block a consequence-free step. The gate sits at
the points of consequence -- the JIRA post / merge (close) and the task resolve (kb-close-task).

Option IDs (for `editJiraIssue` `customfield_11323`): DB Migrations `10526`, Environment Variables
`10527`, A/B Tests `10528`, Custom DB scripts `10529`, DataPump `10530`, NoSQL scripts `10531`,
Post-Release Checks `10532`, Offline Profile Conversion `10533`, Online Profile Conversion `10534`,
Webhooks Service `10535`, Twitch Service `10536`, Server Configuration `10559`.

## Related

- [JIRA Executor field](jira_executor_field.md) — same "request custom fields explicitly" caveat
- Worked example of the env-var/A/B audit on a real release: `tasks/FP-41595--leaderboards-release-support/` artifacts
