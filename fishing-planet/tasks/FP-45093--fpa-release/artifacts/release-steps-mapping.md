# 2026.5 Anniversary — Release Checklist Steps Mapping

Branch-specific release steps for the 2026.5 Anniversary release, derived by mapping JIRA
`Server Release Checklist Steps` (`customfield_11323`) over MFT commits **and** cross-checking with an
`SQL/` / `NoSql/` / service-tree sweep to cover the field's blind zone (only 4 of 20 tasks in the
window have the field set).

Checklist: page `5803934180`. Template: page `4395597825`. Method/vocabulary:
[release checklist field](../../../../reference/release_checklist_field.md). Prior worked example:
`tasks/FP-44389--ftue-release/artifacts/release-steps-mapping.md`.

## Sweep window

MFT hosts two consecutive releases, so the window is **not** the branch fork (that was 2026.4's
window) — it starts at the last shipped boundary:

| Rev | Boundary |
|-----|----------|
| r15967 | major 1124.0 -> 1125.0 — branch enters the FTUE phase |
| r16171 | minor after 2026.4 FTUE (Steam) |
| r16281 | minor after 2026.4.2 FTUE (Consoles) — **last shipped** |
| r16321 | major 1125.2 -> 1126.0 — branch enters the 2026.5 phase |

**Window used: r16281 -> HEAD (r16380).** Rationale: the checklist covers what this deployment
carries, not what carries the `fixVersion`. The 1125->1126 increment (r16321) marks the phase start,
not the scope start — much Anniversary-tagged work was committed before it and physically shipped in
the Consoles build (mission-system code ships early; the Anniversary content activates at the event).

Method: (1) `svn log -r 16282:HEAD` -> 20 unique keys; (2) JQL `key in (...) AND cf[11323] is not
EMPTY` -> 4 tagged; (3) `svn diff --summarize -r 16281:HEAD` over `SQL/`, `NoSql/`, WebHooks, Twitch,
tools.

## 2026.5 instances per category

| Category | 2026.5 instance | Checklist action |
|----------|-----------------|------------------|
| DB Migrations | `MFT.M.2026.07.23-027 [ProfileConversions]`, `NPN.M.2026.07.15-025 [ProfileConversions] [Data]` (merged from NPN) | auto SQLCheck |
| NoSQL scripts | none (`NoSql/` unchanged in window) | routine `indexes.js` only |
| DataPump | no new content tables found | routine sync; confirm no script change needed |
| Environment Variables | none — no `[EnvironmentVariables]` patch in window, none requested by GD/liveops | delete the placeholder block |
| A/B Tests | none requested | delete the placeholder block |
| Webhooks Service | no changes | mark "no changes" |
| Twitch Service | no changes | mark "no changes" |
| Post-Release Checks | FP-44701, FP-44889 (both tagged) | keep step; conversions sweep covers the action |
| Offline Profile Conversion | none | **delete the 3 offline-converter steps** |
| Online Profile Conversion | `FixCreaturesMissionRename` (FP-44701), `BackfillTournamentTrophies` (FP-44889) | fill the proactive-sweep step (below) |
| Server Configuration | none found | confirm none needed |
| Custom DB scripts | `R202607-RemovePhantomDlcTransactions-XBox-Main.sql` + `-Stats.sql` (FP-44943) | add row as **Xbox-only placeholder — already executed on Xbox prod 2026-07-20** |

## Tagged tasks (4 of 20)

- **FP-44701** — DB Migrations + Online Profile Conversion + Post-Release Checks -> `FixCreaturesMissionRename`
- **FP-44889** — DB Migrations + Online Profile Conversion + Post-Release Checks -> `BackfillTournamentTrophies`
- **FP-44943** — Custom DB scripts -> the two `R202607-RemovePhantomDlcTransactions-XBox-*` scripts
- **FP-41614** — DB Migrations, but its in-window commit (r16300) touches only
  `WebAdmin/Models/PondWeatherSettingsModel.cs`; the tagged patch predates the window (already
  shipped). fixVersion Internal/Async. **No DB step for this release** — WebAdmin code only.

## Blind-zone catches (sweep, not surfaced by the field)

- **`ReleaseTool` argument change (FP-44701, MFT r16375):** `--finalize-conversion` now takes a
  **named** `--code <Code>` option — verified at HEAD in `EntryPoint.cs`:
  `ReleaseTool.exe --finalize-conversion --code <Code> [--retry]`. The template still says
  `--finalize-conversion <id>` and tells the operator to read `ConversionId` — both wrong for this
  branch. Codes are unique (`UQ_ProfileConversions_Code`); ids are per-database IDENTITY.
- **`ReleaseTool` gained a BuoyBackup module** (FP-44598, `--export-buoys`, In Progress; fixVersion
  2026.4.2 Consoles / Mobile+Nintendo). Ships with the ReleaseTool update; no 2026.5 step.
- **Stats synchronization:** no new Stats tables in the window -> "Include new data into Stats
  Synchronization" = none this release.

## Paste-ready content

### Auto profile conversions: proactive sweep

```
Conversions are enabled in dbo.ProfileConversions and run automatically on each player's next login -
not required for correctness. This sweep applies them up front to still-offline profiles so the base
converts in hours instead of waiting for players to log in. Offline-only; done profiles skipped;
changed profiles backed up; idempotent.

FixCreaturesMissionRename - repair profiles affected by the mission code rename (FP-44701)
  ReleaseTool.exe --finalize-conversion --code FixCreaturesMissionRename

BackfillTournamentTrophies - backfill TourWon/Tour2nd/Tour3rd counters from historical Sport finals (FP-44889)
  ReleaseTool.exe --finalize-conversion --code BackfillTournamentTrophies

Re-run with --retry to reprocess only profiles that errored on the first pass.
```

Verify the enabled set on the target DB before running:
`SELECT ConversionId, Code FROM dbo.ProfileConversions WHERE IsEnabled = 1;`

### Custom DB scripts row (Xbox only)

```
Step: Remove phantom DLC transactions (FP-44943) - XBOX ONLY
Scripts: \SQL\Releases\R202607-RemovePhantomDlcTransactions-XBox-Main.sql
         \SQL\Releases\R202607-RemovePhantomDlcTransactions-XBox-Stats.sql
Status: already executed on Xbox prod 2026-07-20 - placeholder kept for the record.
Both Main and Stats must be corrected together (revenue lives in both).
```

### Environment Variables and AB Tests

```
Environment Variables: none this release.
Ab Tests: none this release.
```

### Steps to delete from this checklist

- "Setup offline profile converter"
- "Start preliminary profile conversion"
- "Perform final profile conversion"

(no Offline Profile Conversion ships; the online/auto sweep step replaces them)

## Template (recurring) fixes

1. Auto-profile-conversion step: change `ReleaseTool.exe --finalize-conversion <id>` to
   `--finalize-conversion --code <Code>`, and drop "Get the IDs from the target DB" in favour of the
   Code (the numeric id is per-database and does not match across servers). Applies to every branch
   that carries FP-44701 (MFT r16375 / NPN r16376) onward.
2. Carried over from 2026.4 and still worth checking: the "Take all players offline" step references
   `\SQL\Patches\_DataPrepare.sql` (correct); the `0-` variant lives only in `Patches\OldRetail`.

## Open items

- Confirm no Server Configuration change is required for this release.
- Confirm the DataPump sync script needs no new table (no new content tables found in the window).
- FP-45166 (protocol compatibility enforcement) is Reopened and ships via Next Server Hotfix, not
  with this release - it carries an online-flag-sticking tail. Not a checklist step here.
