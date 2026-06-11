---
status: reopened
executor: Yevhenii Shust
branch: MFT20260325 @ r16113, Unity_Fishing_CodeBranch @ r54483 (merged to MainClient @ r54572)
jira: https://fishingplanet.atlassian.net/browse/FP-43756
---

# FP-43756: [Competitions] Cancel scheduled competitions overlapping release downtime

## Summary

Extends the WebAdmin Upcoming Release page to surface scheduled competitions (`TournamentKinds.Competition`, `KindId = 3`) that overlap a planned reboot/downtime window, and adds a cancel action mirroring the existing UGC (`KindId = 4`) cancellation flow. Previously only UGC competitions could be cancelled for upcoming-release reasons; scheduled competitions had no cancellation path and would run in a degraded state through downtime (see FP-43553 Steam prod incident, tournament 318866).

Server change refactors the tournament start/cancel flow so scheduled competitions are also cancellable when affected by farm reboot. Adds tournament cancellation-reason model support. Client follow-up (localization of cancellation reasons) tracked separately.

## Scope

> Audited: `svn log -r 15943:HEAD | grep FP-43756` → single commit r16113. Comment text `r16111` was a typo (hyperlink correctly pointed to r16113).

- **MFT20260325 r16113** — `[WebAdmin][Competitions] Add scheduled competitions cancellation to upcoming release flow`
  - DAL: new `GetScheduledTournamentsByKindAndDate(languageId, kindId, start, end)` overload
  - WebAdmin: new "Regular Competitions overlapped with Farm Reboot" section + cancel/view actions; UGC `CancelCompetition` model method renamed to `CancelUGC`, new generic `CancelCompetition`; page layout/styles reworked
  - ObjectModel: file rename `TournamentCancelationInfo` → `TournamentCancellationInfo` (typo fix) + new `Reason` field; new enum `TournamentCancellationReason`
  - SharedLib: `TournamentStartAdapter` refactor — extracted `CanStart(out reasons)`, `CancelTournamentInternal`, auto-cancel of KindId=3 on farm-reboot overlap; cancellation notification switched to JSON payload
  - GameServer: `NotifyClientAboutTournamentCancelled` event reshaped to a single compressed JSON blob
  - ReleaseTool: `OfflineMessagesUpdater`/`TournamentHelper` updated for the rename + unified cancel call
  - Branch-copy: NPN20260602 (Code) forked from MFT20260325:16130; r16113 <= 16130 -> already inherited, no merge to Code needed
- **Unity_Fishing_CodeBranch r54483** (client) — corresponding client-side changes; MERGED AT MainClient r54572 (per Kyrylo Rovnyi comment)

## Findings

### F-1: UGC "Cancel" button mis-wired to the generic competition handler [High]

**Description:** In `UpcomingRelease.cshtml`, the UGC-section "Cancel" ActionLink `onclick` calls JS `cancelCompetition(...)`, which sets the form `Action` to `"cancelCompetition"`. `ToolsController` routes that to `UpcomingReleaseModel.CancelCompetition()` — the new GENERIC scheduled-competition handler — instead of `CancelUGC()`. The newly added `cancelUGC` JS function, the `"cancelUGC"` controller case, and `CancelUGC()` are unreachable from the UI. Result: cancelling a UGC from this page runs `TournamentStartAdapter.CancelTournamentInternal` (generic) rather than `UGCProcess.CancelCompetition`, bypassing UGC-specific state handling (`UserCompetition.Cancel`), sending a `TournamentCancellationInfo` message instead of `UserCompetitionCancellationMessage`, using the wrong reason enum, and logging `AdminAction.CancelCompetition` instead of `AdminAction.UserCompetitionCancel`.

**Investigation:** Read `.cshtml` (both Cancel onclicks point at `cancelCompetition`), `ToolsController` dispatch, `UpcomingReleaseModel.CancelUGC`/`CancelCompetition`. Verified the entrance-fee refund itself likely survives: `GetTournamentForCache` selects `t.*` (EntranceFee populated) and the generic chat message triggers `GameClientPeer.ProcessTournamentCancellation` → `BalanceHelper.IncrementBalanceAsync`. Checked `UGCProcess.CancelCompetition` (`UGCProcess_08_PublishStart.cs`): its own balance-refund lines are commented out and it refunds via `Send_CompetitionCancellation`; **no explicit host-fee refund found there** — so the code-reviewer agent's "host entry fee not refunded" claim is NOT substantiated and was downgraded. Real impact is wrong message type/reason/audit + bypassed UGC state transition, not confirmed money loss.

**Resolution:** Recommend trivial pre-release hotfix — change the UGC row `onclick` from `cancelCompetition(...)` to `cancelUGC(...)`. Not a server-runtime crit (admin-only path), but a regression in an existing money-adjacent admin action.

**Discovered by:** skill recon; confirmed + impact-scoped by code-reviewer agent (agent overstatement on host fee corrected on re-verification).

### F-2: Unguarded `InGameStartHour.Value` can crash the Upcoming Release page [Low]

**Description:** The new Regular Competitions table renders `new TimeSpan(c.InGameStartHour.Value, ...)`. `TournamentBase.InGameStartHour` is `int?`; a null value throws `InvalidOperationException` and fails the whole page render.

**Investigation:** Confirmed nullability in `TournamentBase`. Probed **Steam Prod Main** (DataGrip `[F2P] STEAM PROD MAIN`): `KindId=3` → 0/132 templates and 0/144 active tournaments have null `InGameStartHour` (NOLOCK). Local `Main` agreed (0/132, 0/818). So generators conventionally always set it; the crash does not fire on current prod data. Latent fragility, not triggered in practice on Steam. (Other F2P prod platforms PS/XB/MOB/NX not swept; Retail out of scope.)

**Resolution:** Should-fix (guard with `HasValue`), not a release blocker. Low — generation source always sets the value; the null path is unreachable on real data.

**Discovered by:** skill recon; code-reviewer agent rated High — downgraded to Low (Steam-prod probe: 0 null rows; all platforms generate from one base).

### F-3: `GetScheduledTournamentsByKindAndDate` silently ignores its `kindId`/`languageId` params [Medium]

**Description:** The new DAL overload (`SqlTournamentProvider.cs:1804`) accepts `kindId` and `languageId` but the SQL hardcodes `WHERE KindId = 3` and `pt.LanguageId = 3`; the bound `@KindId`/`@LanguageId` are never referenced. Broken method contract: a future call with `kindId=4` (UGC) returns KindId=3 rows, and any non-default language returns language 3 — silent wrong results. Works today only because the single caller passes `Competition`(3)/`DefaultLanguageId`(3). The name invites reuse, so this is a latent correctness trap, not just a smell. No SQL error (sp_executesql tolerates declared-but-unused params).

**Investigation:** Read the method; confirmed hardcoded literals and unused params. Overlap predicate `t.StartDate <= @End AND t.EndDate > @Start` is a correct interval-overlap test.

**Resolution:** Fix in reopen — reference `@KindId`/`@LanguageId` in the SQL (values identical today, zero behavior change, makes the contract honest).

### F-4: Regular-section Cancel confirm uses `c.NameCustom` (null for scheduled) [Low]

**Description:** The regular competition Cancel `onclick` passes `c.NameCustom`, which is a UGC concept and is null for scheduled competitions; the confirm dialog shows an empty name. The name column itself correctly uses `c.Name`.

**Resolution:** Cosmetic; fix alongside F-1.

### F-5: Duplicate `id="overlap"` on two section headers [Low]

**Description:** Both section `<h2>` headers (`UpcomingRelease.cshtml:148` and `:194`) use `id="overlap"` — invalid HTML; the `#overlap` anchor only ever reaches the first. (Unused CSS classes also exist in the view's `<style>`, but the admin's styling is broadly dead/legacy and not attributable to this change — not raised against the executor.)

**Resolution:** Trivial — rename one anchor; bundle if convenient.

### F-6: Tournament-cancelled realtime event reshaped — client/server contract [Medium / Question]

**Description:** `NotifyClientAboutTournamentCancelled` changed from discrete event params (`TournamentId`/`Name`/`EntranceFee`/`Currency`/`Kind`) to a single compressed JSON blob (`TournamentParameterCode.Json`). This affects ALL tournament cancellations, not just scheduled. A client that still reads the discrete codes would show a blank cancellation popup (name empty, 0 fee), though the balance refund still executes server-side in `ProcessTournamentCancellation`. Client commit `Unity_Fishing_CodeBranch r54483` (merged MainClient r54572) exists; the chat/offline message path stays JSON-consistent and the added `Reason` field is deserialization-compatible.

**Investigation:** Confirmed new event shape at HEAD in `GameClientPeer_Tournaments` and the old discrete-param shape in the r16113 diff. Verified offline-message path (`OfflineMessagesUpdater` CSV fallback + `ProcessTournamentCancellation` JSON) is internally consistent. Inspected client WC `Unity_Fishing_MainClient` @ r55298 (>= merge r54572): `PhotonServerConnection_IPhotonPeerListener` handles `EventCode.TournamentCancelled` by reading `TournamentParameterCode.Json` and deserializing `TournamentCancellationInfo` — exactly the new server format. Contract synced.

**Resolution:** Accepted — client (MainClient r55298) reads the new JSON event shape; client and server are in sync for the release.

### F-7: Auto-cancel of scheduled competitions on farm-reboot overlap [Info]

**Description:** `CanStart` now adds `CanceledUpcomingRelease` for KindId=3 when `GetFarmReboot(StartDate, EndDate)` returns an overlapping reboot, so an affected competition auto-cancels at start time (any non-zero overlap). This is the intended mitigation (JIRA GD open question #3 resolved as "cancel on any overlap"). `GetFarmReboot` is a correct overlap query and returns null (no exception) when none matches.

**Resolution:** Accepted — intended behavior; confirm GD signed off on "any overlap" threshold.

### F-8: Free competitions cancelled without participant notification [Low / Info]

**Description:** `NotifyPlayersAboutTournamentCancelled` early-returns when `tournament.EntranceFee == null`, so a fee-less competition is cancelled with no participant chat notification (admin sees "0 participants notified"). Pre-existing behavior of the shared method, now also reached by the scheduled-competition path; mildly counter to the "notify participants" goal.

**Investigation:** Steam Prod Main, active `KindId=3`: 143 Positive entrance fee, 0 NULL, 0 Zero. The `== null` short-circuit never triggers for current scheduled competitions — all are paid-entry, so notifications are sent. Non-issue in practice.

**Resolution:** Info only — no practical impact (0 null-fee scheduled competitions on prod).

## Verdict (draft — not yet published)

**REOPEN.** No rollback of r16113 needed (the release ships; the scheduled-competition feature and the automatic production path work, F-6 client contract is in sync), but **F-1 is a confirmed regression in the existing UGC cancel path** and must be hotfixed with a new WebAdmin build ASAP — the Upcoming Release cancel flow is load-bearing for the next major release. (F-1 is bypassable via console in the interim.)

**Reopen hotfix scope:**
- **F-1 [blocking]** — `UpcomingRelease.cshtml:187` onclick `cancelCompetition(...)` → `cancelUGC(...)` (UGC Cancel mis-routed to the generic handler).
- **F-3 [Medium]** — `SqlTournamentProvider.cs:1804` reference `@KindId`/`@LanguageId` in the SQL instead of hardcoded `3`/`3` (broken method contract; zero behavior change today).
- **F-4 [Low]** — `UpcomingRelease.cshtml:236` confirm name `c.NameCustom` → `c.Name` (empty name for scheduled).
- **F-2 [Low]** — `UpcomingRelease.cshtml:224` guard `InGameStartHour.HasValue` (latent NRE, unreachable on real data, same file — cheap).
- **F-5 [Low]** — `UpcomingRelease.cshtml:148/194` rename one `id="overlap"` (bundle if convenient).

**Question to GD (not code):** F-7 — confirm "cancel on any non-zero overlap" matches the GD decision on JIRA open question #3.

**Closed / non-issues:** F-6 (client synced), F-8 (all prod scheduled competitions are paid-entry → notification fires).

## Investigation Journal

- Intake: executor = Yevhenii Shust (confirmed via `customfield_11224` and commit-author comment; matches JIRA Executor field).
- Commit audit: `svn log -r 15943:HEAD | grep FP-43756` → single r16113. Comment text `r16111` was a typo (link pointed to r16113). WC at r16168 (ahead) — disk trustworthy; but `TournamentStartAdapter.cs` and `GameClientPeer_Tournaments.cs` were further changed by UNRELATED commits (r16114/FP-43817, r16134/FP-43758, r16137/FP-35682) — used `svn diff -c 16113` as source of truth for those two.
- Branch-copy: r16113 <= MFT-copy-source 16130 → already inherited in NPN (Code); no merge to Code.
- Hypothesis verification: F-1 routing confirmed by reading .cshtml/controller/model; refund-survival hypothesis verified via `GetTournamentForCache` (`t.*`) + `ProcessTournamentCancellation`. Agent's "host fee lost" claim re-checked against `UGCProcess.CancelCompetition` and NOT substantiated → finding downgraded.
- F-2: code-reviewer rated High; DB probe (local `Main`, 0/818 active + 0/132 templates null) → downgraded to Medium latent.
- Both agent over-ratings (F-1 host fee, F-2 probability) caught by independent re-verification — recorded as a reminder that agent severities need grounding before adoption.
