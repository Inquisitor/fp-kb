---
jira: FP-44389
title: Prepare and release 2026.4 FTUE rework
status: in-progress
executor: Stanislav Samoilov
created: 2026-06-10
type: story
platforms: [Steam, PS, XB, MOB, NX]
---
# FP-44389: Prepare and release 2026.4 FTUE rework

## Status
Release-prep complete (2026-06-21). The 2026.4 FTUE/Old Ponds Rework checklist (page 5551947777)
and its template (page 4395597825) are fully validated; every branch-specific release step was
collected (JIRA field + SQL-sweep), applied, and verified; the release-step field gate was codified
into the close skills. Remaining deliverable is the release execution itself (per the checklist).
Buoy export/backup tooling that briefly lived under this folder is being split to a dedicated task.
Post-release **server patch 2026.4.2.1 FTUE Server Hotfix** (id 16439, renamed 2026-07-01 from
2026.4.1.1) is assembled and **bundled into the 2026.4.2 console release** (co-tagged 16240) — recon
in [patch-2026.4.2.1-recon.md](artifacts/patch-2026.4.2.1-recon.md).

## Summary
Drive the 2026.4 FTUE release: build the executable checklist from the template, validate every
template step against this branch, and fill in the branch-specific steps. Two parallel goals:
(1) finalize the current checklist; (2) fix recurring defects in the TEMPLATE as they surface.

Branch-specific steps are sourced two ways, because neither alone is complete:
- JIRA `Server Release Checklist Steps` field (`customfield_11323`) over MFT commits — only
  23/107 tasks tagged, so it has blind zones.
- `SQL/` / `NoSql/` / service-tree sweep since the fork — catches release-relevant changes from
  untagged tasks (it found the env var and the profile conversions the field missed).

Full breakdown in [release-steps-mapping.md](artifacts/release-steps-mapping.md).

## Plan
No formal multi-phase plan — driven by the checklist. All directions complete:
- Template validation: `_DataPrepare.sql` path fixed; movable Online Profile Conversion step added;
  conversion-step panel/description split. DONE.
- Collect branch-specific steps: JIRA-field sweep (23/107) + `SQL/`/`NoSql/`/service sweep. DONE.
- Fill current checklist: Env Vars (FP-43884), Online Conversion (3 codes + IDs), Custom-script row
  (FP-43816), removed 3 Offline steps, Webhooks/Twitch "no changes", AB #10 OFF/OFF. DONE.
- Verifications: A/B #10 origin (liveops), DataPump coverage (FP-43334/43400), Server Config (none). DONE.
- Process: codified the field check into kb-close-task / jira-review-close; authored
  [`reference/release_checklist_field.md`](../../../reference/release_checklist_field.md). DONE.
- Process (added 2026-07-30 from the 2026.5 Anniversary release): the procedure for *editing* a checklist
  page is now [`reference/release_checklist_editing.md`](../../../reference/release_checklist_editing.md)
  — confirmation gate per edit, template instructions are never deleted, 🚧 is cleared only by the user,
  no stale "no changes" notes, panels only for exceptions. Read it before touching a checklist page.

## Milestones
- 2026-06-10: Task started; KB card created. Read checklist (5551947777) vs template (4395597825);
  identified branch-specific deltas (Xbox UWP, AB #10, PlayerDailyActivity) and two template
  divergences (reworked Regenerate step E; removed Fix-generated-competitions step F, superseded
  by the "Refresh FUTURE Competition Configs" button).
- 2026-06-10: Decoded `customfield_11323` (12 options) and its semantics with the owner (create-vs-
  enable env var distinction; offline/online = profiles TABLE state; profile-conversion mechanics;
  DataPump exceptions; hotfix-reminder rationale). Mapped all 12 options to template steps; found
  two genuine template gaps were by-design (Custom DB scripts, Server Configuration) and one real
  (Online Profile Conversion).
- 2026-06-10: Field sweep (23 tagged) + `SQL/` sweep closed the blind zone. Key catches: env var
  `IgnoreWrongStrikeWhileHookPendingOnFloat` (FP-43884, enable Y after release); three online
  ProfileConversions (RemoveDeprecatedBuoys, FixDepletedItems, ResetLevel1SpawnPoint); FP-43816
  custom backfill script needs its own row; `_DataPrepare.sql` path bug in the template; Webhooks/
  Twitch/NoSql unchanged; R202604 Leaderboards + FP-39539 KWD confirmed out of scope.
- 2026-06-10: Verifications resolved. **#7 DataPump** — FP-43400 (GV `Fishing.StaminaLoseMultiplierOnRodStand`)
  and FP-43334 (buoy GV + `Ponds.UnlimitedBuoyRecolors`) both map to non-forbidden standard content
  tables; routine QA->PROD sync covers them, new column auto-carried by column-match (patch before
  pump). **#6 A/B #10** — origin = liveops request, no task/code (expected blind spot). **#3 FP-43816**
  — review Approved (MFT r16149 -> NPN r16150); backfill goes Post-Release, dry-run-first, idempotent.
- 2026-06-11: Checklist (v16) fully validated — all template markers removed, infra-step paths verified,
  AB #10 confirmed OFF/OFF by liveops. Template `_DataPrepare` fixed + Online Conversion step added.
- 2026-06-11: Template conversion step finalized — author-facing info-panel (lookup query + 🚧) split
  from the operator-facing description; duplication resolved. Template fully validated.
- 2026-06-21: Field gate codified (#10) — mandatory "Closure / review gate" in
  `reference/release_checklist_field.md` (committed `93c7596`) wired into kb-close-task Step 9 +
  jira-review-close Step 2b; deliberately NOT in jira-review-open (it finalizes nothing). Committed `41f9f5c`.
- 2026-06-21: Card scoped to release-prep; buoy export/backup work split out to a dedicated task
  **FP-44598** (`tasks/FP-44598--buoy-backup-restore/`); `buoy-backup-restore-design.md` and
  `buoy-export-plan.md` relocated there. `release-steps-mapping.md` stays here (release work).
- 2026-06-24: Started the post-release **server patch** prep. Boundary = MFT r16171 (minor protocol
  increment after the 2026.4 Steam release). Recon of r16172..HEAD: classified 14 post-release tasks
  transfer-vs-add, confirmed client-decoupled (only FP-43192 client-coupled -> stays consoles 2026.4.2).
  Created version `2026.4.1.1 FTUE Server Hotfix` (id 16439); assembled 13 in-MFT tasks into it
  (transfer/add applied + verified). Owner re-tagged the 5 commitless 2026.4.1 server tasks to where
  their code shipped. Captured the FP release-versions/process model in
  [`reference/release_versions_and_process.md`](../../../reference/release_versions_and_process.md).
  Recon + assembled set: [patch-2026.4.2.1-recon.md](artifacts/patch-2026.4.2.1-recon.md). NEXT: groom
  the 11 Next-Server-Hotfix tasks not yet in MFT.
- 2026-06-30: Next-Hotfix grooming + console bundle. Re-scanned MFT (HEAD still r16232, no new
  boundary): 16 post-boundary tasks. Groomed Next Server Hotfix — only FP-44396 was a real patch
  addition (back-port MFT r16228, now on 16439+16240); the rest already shipped or have no code, and
  no merges into MFT were needed. Since tomorrow's 2026.4.2 console release ships from the same MFT
  HEAD, bundled the patch into it: added `2026.4.2 FTUE Consoles Release` (16240) to the 13 patch
  tasks lacking it + FP-42918 (14 edits, verified — all 16 post-boundary tasks now on 16240).
  FP-42918 stays off 16439: its post-boundary commit r16172 is ReleaseTool-only (not a binary fix),
  upfront conversion unfinished -> Internal/Async; skip the ReleaseTool upfront step for consoles
  (login path covers console players).
- 2026-07-01: NSH reconciliation + version rename. Renamed 16439 `2026.4.1.1` -> `2026.4.2.1 FTUE
  Server Hotfix` (consoles ship first; the hotfix follows). Reconciled the old NSH-stuck tasks (shipped
  to prod pre-review): set **honest** platform versions and dropped NSH on 10 tasks — WebAdmin Dec'25
  (FP-41067/41455/41468/41498/41532) -> `2026.3 Leaderboards` + `FTUE M/N`; line/torch Feb'26
  (FP-41958/41962/42033) -> `Norway Consoles` + `2026.3 Leaderboards` + `FTUE M/N`; FP-43750/43817 ->
  `2026.4 FTUE Steam` + `2026.4.2 Consoles` + `FTUE M/N` (all verified). M/N catch-up is the single
  `2026 FTUE Mobile + Nintendo` (16241) — no separate Norway/Leaderboards M/N release exists.
  FP-43756 merged/closed/versioned by owner (reviewed separately). FP-41407/44395/44464/44701 have no
  code, stay in NSH. Renamed recon artifact -> patch-2026.4.2.1-recon.md.
- 2026-07-06: Release-cleanup task sweep. Stanislav + Anna Vorona moved a batch of Resolved/In-Review
  tasks off Stanislav's plate. Captured the ones that closed or reassigned away (may have shipped
  without his review) for review-triage in
  [2026-07-06-moved-tasks-review-triage.md](artifacts/2026-07-06-moved-tasks-review-triage.md);
  fixVersion-only moves left untracked (still on him, non-critical).
