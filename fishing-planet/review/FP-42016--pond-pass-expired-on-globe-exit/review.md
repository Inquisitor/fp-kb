---
status: in-progress
executor: Yuriy Burda
branch: LBM @ r15935, MFT @ r16112
jira: https://fishingplanet.atlassian.net/browse/FP-42016
---

# FP-42016: [PondPass] Expired Pond Pass record stays in player profile after exit to Globe

## Summary

When a player is on a pond and their Pond Pass expires while still in the local map, exiting to the Globe leaves the (now-expired) Pond Pass record in **Active Level Unlocks** in the WebAdmin profile view. Other paths (re-login, pond switch, certain other exits) cleaned up — only the menu exit-to-Globe path missed cleanup.

The fix has two parts:
1. **Imperative cleanup** at `InternalHandleArriveToBase` — calls `Profile.OutdateLockRemovalAndLog()` which mutates `LevelLockRemovals`, removing entries where `EndDate < UtcNow`. This is what closes the reported admin-display bug (admin reads `LevelLockRemovals` directly via `LevelLockRemovalsModel.Init`).
2. **Defensive read-side filter** in `Profile.UnlockedPonds` getter — skips entries where `EndDate <= UtcNow`. Affects `UnlockedPonds` consumers (mission conditions, targeted ads, unlock checks). Not needed for the admin view fix; an unrelated correctness improvement.

## Reopen (2026-04-30)

QA (Dmytro Sova) reopened: the originally-reported scenario still reproduces. When the Pond Pass expires *while the client stays open* and the player returns to the Globe **without closing the client**, the expired record still shows in **Active Level Unlocks**. The first fix (r15935) cleaned up server-side `LevelLockRemovals` on specific exit paths, but did not cover this in-session case — the same exit-path-coverage problem my F-1 question raised.

New approach — **MFT r16112**: rather than chasing every exit path to force server-side cleanup, filter expired unlocks at the WebAdmin display layer (Active Level Unlocks page). This makes the admin view correct regardless of which exit path ran. Findings/verdict for the reopen fix are below under "reopen (r16112)".

## Scope

- **LBM r15935** — Fix expired pond pass records not removed from profile on exit to Globe
- **MFT r16112** — Hide expired unlocks from WebAdmin Active Level Unlocks page (reopen fix; diff bullets pending Phase 2)

> Branch-copy inheritance: MFT (Code) was created at r15943 from LBM:15942. r15935 ≤ 15942 → already inherited in MFT. No merge to MFT needed.
> Stable / OldStable: not in scope. Bug originally reported on test/qa with client r52059 (above Stable's r52058 pin) — Content-level fix.
> r16112 was committed directly on MFT (Code) — Code receives merges but does not merge down; cross-branch reach for the reopen fix to assess in close phase.

## Findings — first review (r15935)

### F-1: Second pond-exit path misses cleanup [Medium]

**Description:** `GameClientPeer.RequestMissionResult` handler (`Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer.cs`, around the `case ProfileSubOperationCode.RequestMissionResult` block, lines ~1951-1990) sets `Profile.PondId = null` and persists the profile via `SaveProfileWithLog("RequestMissionResult")` under `transactionLock` — but does NOT call `Profile.OutdateLockRemovalAndLog()`. If a Pond Pass expires during a mission/day and the player ends the mission via the EOM flow, the same observable admin-display bug reproduces. The fix at `InternalHandleArriveToBase` covers only the menu exit-to-Globe path.

**Investigation:**
- Recon scan of `OutdateLockRemovalAndLog` callers ran; missing call at `RequestMissionResult` not initially noticed.
- code-reviewer agent flagged the gap; verified independently by reading `GameClientPeer.cs:1951-1990`. The save runs under `transactionLock` with `Profile.PondId = null` at line 1977 — no `OutdateLockRemovalAndLog` call before save.
- Mission-end is a plausible user flow when the Pond Pass expiration coincides with day-end; reproducibility depends on client routing the EOM via `RequestMissionResult` rather than `MoveToPond`.

**Resolution:** Question to executor — was `RequestMissionResult` considered? If intentional, accept; otherwise extend the fix with a single `Profile.OutdateLockRemovalAndLog()` next to `Profile.PondId = null`. Reopen-pending until clarified.

**Discovered by:** code-reviewer agent, verified manually.

### F-2: No tests added [Low]

**Description:** The fix lands without test coverage. `Shared/ObjectModel.Tests/LevelLockRemovalTests.cs` is the natural home — already tests `LevelLockRemoval` with `EndDate` boundary cases (unlimited / limited / outdated). Two tests would lock in both halves: `UnlockedPonds` filter behavior (skip expired, keep `EndDate == null`, keep future) and `OutdateLockRemoval` removal (expired entries removed, others kept).

**Investigation:** Read `LevelLockRemovalTests.cs:1-80` — fixture setup is light, no DB; adding tests is ~5-10 min.

**Resolution:** Skipped — note as observation; project does not enforce test-coverage gate for bug fixes. If module backlog desired, can be filed against `LevelLockRemoval` area.

**Discovered by:** code-reviewer agent.

### F-3: Two unrelated changes in one commit [Info]

**Description:** Part 1 (imperative cleanup at exit) fixes the reported admin-display bug. Part 2 (read-side filter on `UnlockedPonds`) is an unrelated correctness improvement for game-logic consumers (`MissionsContext`, `TargetedAdsManager_*`, `HasUnlockCondition`). The two could have been split.

**Resolution:** Accepted — process note only. Bundled scope is small, both changes share the underlying "expired LevelLockRemovals shouldn't be active" theme.

## Notes

- ⚠ JIRA `customfield_11224` (Executor) is empty — expected: Yuriy Burda (commit author of r15935).
- Boundary `EndDate == UtcNow`: `OutdateLockRemoval` keeps it (`<` predicate), `UnlockedPonds` skips it (`>` predicate). Tick-level inconsistency, no practical impact.
- `PaidLockRemoval` has no `EndDate` field (`Shared/ObjectModel/Profile/PaidLockRemoval.cs`) — paid unlocks are permanent; no symmetric filter needed in `UnlockedPonds`. Not a missed case.
- Read-side filter (Part 2) does not regress any consumer — all checked use sites treat absence in `UnlockedPonds` as "not unlocked", which is correct semantics for expired.

## Verdict — first review (r15935)

**Approve with question.** The reported bug is closed correctly along the menu exit path. F-1 (RequestMissionResult gap) is a related-surface concern requiring author confirmation: extend the fix or document why that path is unaffected. F-2/F-3 are observations.

## Findings — reopen (r16112)

r16112 is a one-line change in `WebAdmin/Models/Players/LevelLockRemovalsModel.cs` (`Init`): the `unlocks` collection is filtered before building display models —
`unlocks.Where(u => u.EndDate == null || u.EndDate > DT.Helper.UtcNow)`. Keeps unlimited (`EndDate == null`) and still-active; hides expired.

**Correctness — verified clean.** The predicate is byte-identical to the canonical `Profile.UnlockedPonds` getter (added in r15935): `removal.EndDate == null || removal.EndDate > DT.Helper.UtcNow`, same `DT.Helper.UtcNow` source. So the admin "Active Level Unlocks" page now shows exactly what game logic treats as an active unlock — and does so universally, independent of which exit path ran. This also closes the F-1 (`RequestMissionResult`) gap for the admin-display symptom: the display filters regardless of whether server-side cleanup fired on a given path. `LevelLockRemoval.EndDate` is `DateTime?` (verified) — filter is type-safe; `using System.Linq` already present (`.ToList()` in same method).

### F-4: Expired Pond Passes no longer reachable for changeDate / deletePass [Low]

**Description:** `Views/Player/Unlocks.cshtml` renders the `Change end date...` / `Delete Pond Pass...` buttons per displayed row, gated on Pond Pass rows (`m.EndDate != null && m.Ponds.Length == 1`). The POST handler `PlayerController.Unlocks` resolves the target via `profile.LevelLockRemovals.First(... Ponds[0] == pondId)` — the raw profile data, not the filtered model — but the action can only be triggered from a rendered row. With expired entries now filtered out, an admin can no longer change-date or delete an *expired* Pond Pass from this page.

**Investigation:** Read `Unlocks.cshtml` (action buttons rendered per row, gated on Pond Pass shape) and `PlayerController.Unlocks` POST (`changeDate` / `deletePass` look up by `pondId` in raw `profile.LevelLockRemovals`). Confirmed actions are reachable only through rendered rows.

**Resolution:** Accepted — the page is named "Active Level Unlocks"; an expired pass is already game-inactive (`UnlockedPonds` ignores it) and is purged by server-side `OutdateLockRemovalAndLog`. No evidenced support workflow acts on expired entries here. Note for executor: if support ever extended/revived a just-expired pass from this page, that path is now gone — confirm acceptable.

**Discovered by:** skill recon, verified manually.

### F-5: Reopen fix lives on Code (MFT) only; original on Content (LBM) [Medium]

**Description:** r16112 (WebAdmin display filter) is committed on MFT (Code) only. The original r15935 is on LBM (Content) and inherited up to Code via branch copy. Merge direction is Content → Code (upward); Code does not merge down. So on Content (LBM) — and Stable/OldStable — the WebAdmin "Active Level Unlocks" page still lists expired entries; the reopened symptom persists on those branches' WebAdmin builds. Impact depends on which branch builds the deployed admin portal QA/prod use.

**Investigation:** `svn log -r .. | Select-String FP-42016` on MFT → only r16112; on LBM → only r15935. Confirmed r16112 absent from Content. Branch roles/ancestry per `<kb>/_index.md`. WebAdmin deployment branch not verified here (authoritative: Confluence "Environment and branch status" page 68616199, or executor).

**Resolution:** Accepted — per maintainer, MFT (Code) only by intent; no merge to Content/Stable. WebAdmin display fix is deliberately Code-only.

**Discovered by:** skill recon.

### F-6: Filter masks the live profile's real state in a diagnostic tool [Medium — reopen]

**Description:** r16112 hides expired unlocks at the WebAdmin display layer regardless of what is actually in the profile/DB. WebAdmin is a diagnostic tool used by tech staff (not a marketing report) — it should reflect the real state of the profile. The expired-pass record genuinely persists in the live server profile / DB during the open-client window (see F-7); forcibly hiding it removes the technician's ability to see that the profile is in a dirty state. QA's desire not to see expired passes is valid, but it should be opt-in, not imposed on every consumer.

**Investigation:** Read the diff (`LevelLockRemovalsModel.Init` unconditional filter) and `Unlocks.cshtml` (no toggle, no expired indication). Confirmed the existing opt-in precedent in WebAdmin: `Views/Player/Payments.cshtml` uses `@Html.CheckBoxFor(model => model.HideIncompleteTransactions, ... onclick="submit();")` to hide incomplete transactions on demand rather than always.

**Resolution:** Reopen — reject the unconditional hide. Preferred: keep expired rows visible but mark them (separate `EXPIRED` column / color highlight) for at-a-glance identification, and optionally add a "hide expired" checkbox mirroring the Payments `HideIncompleteTransactions` pattern. This preserves diagnostic transparency while giving QA the convenience.

**Discovered by:** maintainer (review discussion), verified against code.

### F-7: Root cause — clean/save misalignment on pond-exit paths leaves DB dirty while client is live [Medium — reopen]

**Description:** The expired record persists in the server-side profile/DB during the open-client window because cleanup and persistence do not coincide on the two pond→globe exit paths:
- **Path A** `GameClientPeer_Travel.InternalHandleArriveToBase` (manual exit to Globe): calls `Profile.OutdateLockRemovalAndLog()` (added by r15935) but mutates **in-memory only** — the profile save is commented out (`//ProfileAdapter.SetProfile(Profile)` / `//LogProfileSave("ArriveToBase")`). DB stays dirty until a later save (disconnect).
- **Path B** `GameClientPeer.RequestMissionResult` (end of trip / end of Pond Pass stay — the likely repro; "mission" is legacy terminology for a pond trip): persists via `SaveProfileWithLog("RequestMissionResult")` but never calls `OutdateLockRemovalAndLog` (this is first-review F-1). DB persists the expired entry until a path that both cleans and saves (re-login load+clean+save, pond switch).

Either way the DB carries the expired record while the client is live — exactly matching QA ("not removed while client open; removed on exit / re-login / other pond"). Cleanup itself is otherwise plentiful (`TravelAdapter`, `TournamentAdapter`, `ProfileAdapter`, monetization, `ReleaseTool`), and `UnlockedPonds` filters by date — so gameplay is unaffected; this is a display/data-hygiene issue, not a gameplay bug.

**Investigation:** Enumerated `OutdateLockRemoval(AndLog)` call sites; read `InternalHandleArriveToBase` (cleanup at line 953, save commented at ~1020-1021) and `GameClientPeer.RequestMissionResult` (`SaveProfileWithLog` without cleanup). Behavior corroborated by QA's observed lifecycle.

**Resolution:** Reopen note (informational root cause). Optional source-side fix: add `Profile.OutdateLockRemovalAndLog()` immediately before `SaveProfileWithLog("RequestMissionResult")` so the end-of-trip exit persists a cleaned profile. Not a blocker on its own (getters already filter expired); priority call for the team. Captured so the reopen explains *why* the record lingers, not just *that* it does.

**Discovered by:** maintainer prompt, verified manually.

## Verdict — reopen (r16112)

**Reopen — require rework.** The fix is technically correct (predicate mirrors `Profile.UnlockedPonds`) and harmless to gameplay, but it **masks** rather than addresses the symptom: it unconditionally hides expired unlocks in a diagnostic admin tool, removing tech staff's view of the profile's real (dirty) state during the open-client window (F-6, root cause F-7). Asked instead: keep expired rows visible with an `EXPIRED` marker (separate column / color), and optionally a "hide expired" checkbox mirroring the Payments `HideIncompleteTransactions` toggle. First-review F-1 (`RequestMissionResult` cleanup gap) is now understood as part of the root cause (F-7).

**Correction to first review:** the first-review verdict claimed r15935 "closes the reported admin-display bug." That was wrong — r15935's cleanup at `InternalHandleArriveToBase` is in-memory only (save commented out) and the admin reads the DB, so the symptom survived on this path. This is why QA reopened. Lesson: verify that an in-memory mutation is actually persisted before crediting it with fixing a DB-backed admin view.

## Draft reopen comment (for close phase — not yet posted)

> Reopening. The fix hides expired unlocks at the WebAdmin display layer, but the record is genuinely still present in the live profile on the server (the expired Pond Pass persists in the profile/DB until the client disconnects or the player re-logs / switches pond). WebAdmin is a diagnostic tool, so it should show the real profile state, not hide it. Please instead mark expired passes (a separate `EXPIRED` column / color highlight) so they're identifiable at a glance, and optionally add a "hide expired" checkbox like `HideIncompleteTransactions` on the Payments page.
>
> It would also be worth assessing how problematic this dirty state actually is on a live game server — the natural place to clean expired passes is the profile-save paths themselves, where the processing belongs. The end-of-trip path (`RequestMissionResult`) currently saves the profile without running the cleanup, and the arrive-to-base path used to persist the profile (`ProfileAdapter.SetProfile`) but that call is now commented out — worth understanding why before settling for display-only filtering. Game logic is unaffected (expired passes are already filtered by date), so this is about admin visibility and data hygiene, not gameplay.

## Investigation Journal

- 2026-04-28 — Card created (Phase 1). Source branch confirmed via JIRA comment; ancestry check shows r15935 already inherited in MFT.
- 2026-04-28 — Phase 2 audit: `svn log | grep` confirmed r15935 is the only FP-42016 commit on LBM; same r15935 visible in MFT via branch-copy. No discrepancy with JIRA.
- 2026-04-28 — Diff read; recon scan over `OutdateLockRemovalAndLog` callers, `UnlockedPonds` consumers, `LevelLockRemovals` admin-side reads. Verified WebAdmin reads `LevelLockRemovals` directly (not `UnlockedPonds`); confirmed `PaidLockRemoval` has no `EndDate`.
- 2026-04-28 — Delegated to code-reviewer agent. Agent identified `RequestMissionResult` as a second pond-exit path missing cleanup → recorded as F-1. Agent's tests-missing observation → F-2. Agent's split-commit observation → F-3.
- 2026-05-26 — Reopen intake. QA (Dmytro Sova) reopened 2026-04-30: in-session expiry + return to Globe without client restart still shows expired record in admin. Executor delivered new fix MFT r16112 (WebAdmin display-layer filter, different approach from r15935 server cleanup). Executor field now filled (Yuriy Burda) — was empty at first review. Card reopened; scope extended with r16112; first-review Findings/Verdict relabeled.
- 2026-05-26 — Phase 2 audit: `svn log | Select-String` confirmed r16112 is the only FP-42016 commit on MFT and r15935 the only one on LBM — WebAdmin fix is Code-only (→ F-5). Diff read: one-line `Where` filter in `LevelLockRemovalsModel.Init`. Verified predicate is byte-identical to `Profile.UnlockedPonds` getter and `LevelLockRemoval.EndDate` is `DateTime?`. Recon over `Unlocks.cshtml` + `PlayerController.Unlocks` POST showed `changeDate`/`deletePass` are reachable only via rendered rows → F-4. code-reviewer delegation declined (one-line change, recon conclusive).
- 2026-05-26 — Maintainer raised the masking concern. Investigated root cause: enumerated `OutdateLockRemoval(AndLog)` call sites (cleanup is plentiful, not absent), then found the clean/save misalignment — `InternalHandleArriveToBase` cleans in-memory but its profile save is commented out; `RequestMissionResult` saves without cleanup. This explains the open-client-window persistence and matches QA's lifecycle → F-7. Reframed verdict from "approve" to **reopen**: r16112 masks a live-profile dirty state in a diagnostic tool → F-6. Confirmed the opt-in precedent (`Payments.cshtml` `HideIncompleteTransactions` checkbox). F-5 resolved (MFT-only by maintainer). Recorded correction: first-review credit to r15935 for closing the admin symptom was wrong (in-memory-only, admin reads DB). Draft reopen comment added for close phase.
