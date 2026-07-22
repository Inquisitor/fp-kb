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
`--export-buoys` shipped: implemented, unit-tested, and committed to MFT20260325 (r16349 feature,
r16350 `ProfileConverter` timeout fix). Run in production against the pre-release backups of every
**released** platform — **Steam, PS, Xbox** — with **zero buoys lost**; per-pond artifacts consolidated
to one `.7z` per platform on the local dumps. **Mobile and Nintendo** exports are pending their
(not-yet-shipped) releases — same tool, one clean pass each. Restore (`--import-buoys`) remains deferred
(lower priority). Split out of FP-44389 (release-prep) on 2026-06-21.

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
`BuoyBackupCsv`, `BuoyExportRunner`, `TolerantProfileReader`, `export-buoys.example.cmd`; `EntryPoint`
`--export-buoys` case + `GetOption`; tests in `Photon/tools/ReleaseTool.Tests/BuoyBackup/`. One-off,
deletable as a unit when the restore work is done. Committed to SVN under FP-44598 (r16349; `ProfileConverter`
timeout fix r16350).

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
- 2026-06-30..07-14: Production execution against the released platforms' pre-release backups (restored
  on a reserve server, one platform at a time; ReleaseTool `sql` connection points at the local `Main`).
  - **Steam** (~11.5M profiles, ~20h at Parallelizm=8): 3 profiles failed to deserialize on an enum
    value the backup's server version carries but this branch's `ObjectModel` lacks
    (`ForcePlayerToLeavePondReason.CriticalItemBroken`) — the strict reader aborts the whole profile.
    Fixes: added `TolerantProfileReader` (deserializes with the shared settings but swallows unknown
    enum/value-conversion errors, so the buoys survive) wired into `BuoyExportRunner` as a
    `catch (JsonSerializationException)` fallback; added a `--users <guids>` option for targeted
    re-runs; recovered the 3 via a scoped re-run (one marker buoy in LoneStar for one user; the other
    two had nothing in the deprecated ponds). Also raised the SQL command timeout in `ProfileConverter`
    (the full-table count/enumeration aborted at ADO.NET's 30s default on the large table). Folded the
    one recovered buoy into the main Steam LoneStar set (739586 users / 1408241 marker buoys).
  - **PS** (~12.89M, ~16h): 0 failed, 1 profile recovered **inline** — the tolerant fallback now lives
    in the main path, so unknown-enum profiles heal during the run instead of dropping; no separate
    recovery step needed. (Same holds for Xbox and every future platform.)
  - **Xbox**: 0 failed. LoneStar 517282 users / 990074 buoys, LesniVila 150368 / 286930,
    Zeekanaal 20941 / 70803.
  - Outcome: zero buoys lost across Steam/PS/Xbox. Per-pond JSONL + CSV + `.meta.json` sets consolidated
    to one archive per platform (`buoy-export-steam/ps/xbox.7z`) on the local dumps; meta `source`
    records the server only, no credentials.
- 2026-07-21: Committed to MFT20260325 — r16349 (`[BuoyBackup]` feature incl. tolerant fallback +
  `--users`), r16350 (`[ProfileConverter]` timeout). The branch had advanced (FP-44943 touched
  `EntryPoint.cs`); reconciled via `svn update` (clean `G` merge to r16348), rebuilt (`MSBUILD_EXIT=0`)
  and re-ran tests (9/9) before committing.
