---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16125; CodeBranch @ r54677
jira: https://fishingplanet.atlassian.net/browse/FP-43676
---

# FP-43676: FTUE. New Tutorial. Client — After changing the language at the beginning of the tutorial, it does not return to the starting location in 3D

## Summary

New-tutorial player who reloads at the very start of the tutorial (e.g. after going to change the language, or just restarting) lands in 2D on the local-map screen instead of being placed back in 3D at the starting location.

Root cause is the lifetime of `PersistentData.IsIn3D`, the server-authoritative auto-spawn flag introduced in [FP-43535](FP-43535--ftue-spawn-after-reload/review.md). That flag was cleared on **first successful pond arrival** (one-shot). A player who reloads while still in the early-tutorial pond has already had the flag cleared, so on the next entry `SHOULD_BE_SPAWNED_TO_3D` is false and the client routes through the 2D local map.

Fix (per author note, decided with GD): keep `IsIn3D` set until the player **leaves the pond to the globe** (world map) for the first time, rather than clearing it on pond arrival. This broadens the flag's effective lifetime to "player is still in their first 3D session" — consistent with the "resume directly in 3D" semantics anticipated in FP-43535.

The companion client commit trims the XML `<remarks>` on `PersistentData.IsIn3D` (added during FP-43535 review at CodeBranch r54417) so the documented one-shot/"cleared on pond arrival" lifetime no longer drifts from the new server behavior.

## Scope

> Audited via `svn log | grep "FP-43676"` on both branches — list matches JIRA intake, no additional commits.

- **MFT20260325 r16125** — Keep IsIn3D set until player leaves pond to globe
  - `GameClientPeer_Travel.cs` — removed the `IsIn3D = false` clear in the pond-arrival path (`HandleArriveToPond`)
  - `Shared/ObjectModel/Profile/PersistentData.cs` — XML `<remarks>` rewritten: lifetime now "reset together with `PersistentData` on leaving pond to globe"
- **CodeBranch r54677** — Trim PersistentData.IsIn3D doc to avoid drift with actual server behavior
  - `Assets/.../ObjectModel/Profile/PersistentData.cs` — client mirror of the doc trim

## Investigation Journal

- Direct follow-up to FP-43535 (same flag `PersistentData.IsIn3D`, same FTUE area, same executor). Prior review established: flag set on profile creation with `Position`/`Rotation`; cleared on first pond arrival in `GameClientPeer_Travel.cs`; client gates auto-spawn via `StaticUserData.SHOULD_BE_SPAWNED_TO_3D`. FP-43535 Investigation Journal already anticipated extending the flag to a "should resume directly in 3D" marker — this task realizes part of that.
- FP-43535 added XML `<remarks>` documenting the one-shot lifetime (server MFT r16109, client CodeBranch r54417); CodeBranch r54677 here edits that same doc — explains why the client change touches a comment we authored.
- JIRA Executor field (`customfield_11224`) empty — executor identified via commit comment as Yuriy Burda.
- Mary Key's 21.05 comment (Esc → local map → "Go Fishing" teleports to wrong point) is a *separate* case — explicitly scoped out by Karchavets ("don't pile everything into one heap"). Not part of this fix.
- **Correctness verification (r16125):** confirmed the removed pond-arrival clear is subsumed by an existing reset. `GameClientPeer_Travel.cs::InternalHandleArriveToBase` does `Profile.PersistentData = null` ("Reset on ArriveToBase"), and the `Profile.PersistentData` getter lazily recreates with `IsIn3D = false`. So leaving the pond to the globe already clears the flag. The change purely extends the flag's lifetime from "until pond arrival" to "until base arrival".
- **No server-side reads of `IsIn3D`:** grep of the MFT server tree shows `IsIn3D` is only *written* (`NewPlayerProfileFactory`, and the now-removed clear). The sole consumer is the client (`StaticUserData.SHOULD_BE_SPAWNED_TO_3D`). Extending the flag's lifetime therefore has no server-side logic side effects.
- **Branch-copy / merge:** MFT created from LBM @ r15942; r16125 > 15942 → MFT-only. FTUE feature exists only on the Code branch; merge direction is Content → Code. Nothing to merge down. No merge action.
- Code-reviewer agent delegation declined (recon sufficient for a 4-line removal + doc edit).
- **Semantic conflict surfaced in discussion (→ F-1).** `IsIn3D` was designed (as part of Save Player State, epic FP-21057) as a *live snapshot* of the player's 3D/2D state for reconnect resume. That live tracking is unimplemented — the flag is force-set `true` only at profile creation and used as a one-shot bootstrap to auto-spawn new players into 3D. The fix entrenches the bootstrap meaning. Architectural debt filed: **FP-44054** (relates to FP-43535, FP-43676).
- Executor field was empty at review time; assignee set it during review. No standalone finding.

## Findings

### F-1: `IsIn3D` conflates a one-shot bootstrap with the intended live snapshot; doc describes the unbuilt behavior as current [Low]

**Description:** The flag carries two roles that collide for a new player at t=0: a server *snapshot* ("is the player in 3D" — must be `false` before first entry) and a client *trigger* (`SHOULD_BE_SPAWNED_TO_3D` — must be `true` to auto-spawn into 3D). The tutorial works only because `IsIn3D` is force-set `true` at creation and written nowhere else; this fix extends that bootstrap lifetime. The rewritten server `<remarks>` (`PersistentData.cs`) states *"Companion `Position`/`Rotation` hold the **live** 3D spot to resume to"* — but `Position`/`Rotation` are written exactly once (`NewPlayerProfileFactory`, from `TutorialInitialSpawnPoint`) and never updated during the session (`GameProcessor` only reads them). So the doc documents the *intended* live-snapshot behavior as if it were current — the same kind of drift the commit claimed to remove (commit msg: "avoid drift with actual server behavior"). Client doc (r54677) says "the 3D spot" (no "live") — server/client wordings also diverge.

**Investigation:** Grepped MFT server tree (@ r16125, verified work-tree `Last Changed Rev`): `IsIn3D` write only at `NewPlayerProfileFactory:37`, no server read, no explicit `= false` (cleared only via whole-object `PersistentData = null` reset on `ArriveToBase`). `Position`/`Rotation` write only at `NewPlayerProfileFactory:35-36`, read-only at `GameProcessor:420-423`. Confirmed the t=0 trigger-vs-snapshot circular dependency in discussion with executor.

**Resolution:** `Filed → FP-44054` for the architectural split (separate one-shot bootstrap marker from live `IsIn3D` snapshot; track `Position` live; lift LoneStar hardcode — FP-43535 F-4). Interim, non-blocking: suggest the server `<remarks>` drop "live" / mark live tracking as planned, so it stops describing unbuilt behavior as current. Bugfix itself is correct and ships as-is.

**Discovered by:** review + executor discussion.

### F-2: Client commit message typo — "to to avoid drift" [Info]

**Description:** CodeBranch r54677 message reads "Trim PersistentData.IsIn3D doc to **to** avoid drift". Cosmetic, commit message only.

**Investigation:** `svn log | grep` output.

**Resolution:** Skip — immutable commit message, no value in acting.

**Discovered by:** skill recon.

## Verdict

**Approve.** No blocking findings. The fix is correct and minimal: it removes the early `IsIn3D` clear on pond arrival and relies on the pre-existing `PersistentData` reset on return to base/globe, which extends the flag's lifetime to cover the whole first 3D session — exactly closing the reload-during-tutorial → 2D-map gap. The change is destination-agnostic on the server and has no server-side read dependencies. The companion client commit correctly re-syncs the shared doc.

F-1 (semantic conflict + doc describing unbuilt live behavior as current) is real but pre-existing architectural debt entrenched, not introduced, by this fix — filed as **FP-44054** under the Save Player State epic. Interim non-blocking suggestion: trim "live" from the server `<remarks>`. F-2 informational.
