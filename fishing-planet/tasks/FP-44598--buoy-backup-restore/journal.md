---
jira: FP-44598
title: Buoy backup & opt-in restore for deprecated ponds
status: in-progress
executor: Stanislav Samoilov
created: 2026-06-21
type: story
platforms: [Steam, PS, XB, MOB, NX]
---
# FP-44598: Buoy backup & opt-in restore for deprecated ponds

## Status
Backup tooling (`--export-buoys`) implemented (subagent-driven) and building; pending lint/BOM pass,
final review, manual smoke on a dev/QA DB, and the single atomic SVN commit (under FP-44598). Restore
(`--import-buoys`) is deferred (lower priority). Split out of FP-44389 (release-prep) on 2026-06-21.

## Summary
The 2026.4 FTUE/Old Ponds Rework `RemoveDeprecatedBuoys` conversion strips player buoys from ponds
**119 (Lone Star), 150 (Lesni Vila), 160 (Zeekanaal)** and refunds GC for paid recolors. A pre-removal
DB backup was restored on a reserve server; we extract the buoy data now (while it exists) via a new
ReleaseTool `--export-buoys` command that writes, per pond, a JSONL payload + CSV index + meta sidecar,
for later opt-in restore.

## Design & plan
- [Design](artifacts/buoy-backup-restore-design.md) — data model, per-pond artifacts, extraction/restore flows, deferred GC/recolor policy.
- [Implementation plan](artifacts/buoy-export-plan.md) — TDD plan for `--export-buoys`.

## Code location (SVN working copy, not KB)
`Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/` — `BuoyBackupRecord`, `BuoyBackupExtractor`,
`BuoyBackupCsv`, `BuoyExportRunner`, `export-buoys.example.cmd`; `EntryPoint` `--export-buoys` case +
`GetOption`; tests in `Photon/tools/ReleaseTool.Tests/BuoyBackup/`. One-off, deletable as a unit when
the restore work is done. Committed to SVN under FP-44598 once the gates pass.

## Milestones (log)
- 2026-06-13..18: Design brainstormed (superpowers:brainstorming) and hardened through ~7 Plannotator
  review rounds — settled: capture `Buoys`/`NavBuoys`/`BuoyShareRequests` + recolor counters per pond;
  dedup/restore identity = **(PondId, Position, Fish)**, preserve original `BuoyId` best-effort
  (reassign on collision), never lose a buoy; recolor-counter restore + GC claw-back deferred; per-pond
  file sets; `.meta.json` as completion marker; per-buoy recolor **type** (not price) stored, prices
  captured from the backup's GlobalVariables. Two adversarial reviews: data completeness (nothing
  missed — `Inventory.SharedBuoys`/Accepted/Declined are `[JsonIgnore]` transient, capacity untouched)
  and mechanism correctness (load-mutate-save, `JsonSkipInventorySerializerSettings`, concurrency,
  single-threaded import).
- 2026-06-18..21: Implementation plan written (superpowers:writing-plans), per-pond; logic + tests
  kept out of `SharedLib` (in `ReleaseTool` + existing `ReleaseTool.Tests`, deletable unit). Design +
  plan synced to per-pond and committed in KB (`c56c182`); relocated to this card.
- 2026-06-21: Subagent-driven execution.
  - Group A (Record / Extractor / Csv + 6 unit tests): DONE, spec + quality reviewed. Fixes: cache
    `PondName` (no per-row reflection over the whole DB), de-quadratic CSV rows, add share-request test.
  - Group B (`BuoyExportRunner` + example cmd): DONE, build clean. Fixes: `SqlConnectionStringBuilder.DataSource`
    for meta `source` (no credential leak), encapsulate `PondSink` counters, harden `Dispose`.
  - Group C (`EntryPoint --export-buoys` + `GetOption`): implemented, builds, spec+quality reviewed.
  - Lint/format + final verification done: `.editorconfig` clean (CRLF fixed on all new files, usings,
    final newline), BOM intact, EntryPoint line-endings normalized (svn diff content-clean), **6/6 tests
    pass, build green**.
  - Remaining (needs user): manual smoke on a dev/QA DB; single atomic `svn commit` under FP-44598.
- 2026-06-23: Fix `.cmd` placement — moved `export-buoys.example.cmd` from `BuoyBackup/` to `Cmd/`
  (with the existing run scripts), matched their convention (UTF-8 BOM, `echo off`, `..\ReleaseTool.exe`),
  and added the required `<None Include="Cmd\export-buoys.example.cmd"><CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory></None>`
  to `ReleaseTool.csproj` (`.cmd` is not auto-copied — `EnableDefaultNoneItems` is off). Build confirms
  it now copies to the output `Cmd\` folder. Plan corrected accordingly.
