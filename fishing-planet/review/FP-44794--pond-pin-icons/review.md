---
status: in-progress
executor: Yevhenii Shust
branch: NPN20260602 @ r16339-16346
jira: https://fishingplanet.atlassian.net/browse/FP-44794
---

# Review: FP-44794 — ANNIVERSARY 2026: Server.UI — New Pond Event's Icons

## Summary

New event icons ("pond pins") displayed next to ponds on the global map. Server side: `PondPinIcons` catalog + `PondPinIconsSchedule` tables with WebAdmin editing pages, `Events.PondPinIconId` column + FK with admin dropdown, DAL reads, `PondPinIconsCache`, `PondPinIconsResolver` (Event/Tournament/Competition/Ugc/FishingTogether/Scheduled icon types), `GetPondPinIcons` operation (opcode 102). Client consumes the flat response contract; actual globe-pin rendering left to the client team per agreed scope split.

## Scope

### NPN20260602
- **r16339** — PondPinIcons catalog + PondPinIconsSchedule tables, wire DTO models, WebAdmin editing pages for both
- **r16340** — Events.PondPinIconId column + FK, admin dropdown to assign a globe pin icon per event
- **r16341** — DAL reads, PondPinIconsCache, PondPinIconsResolver (server-side resolution covering Event/Tournament/Competition/Ugc/FishingTogether/Scheduled icon types), GetPondPinIcons operation (opcode 102), unit tests
- **r16342** — Fixed SQL-patch name; fixed Events.PondPinIcon grid column width
- **r16346** — Include pond pin icon views in project file (NOT posted in JIRA commit comment)

### Unity_Fishing_CodeBranch
- **r56517** — GlobePinIcon response contract (flat, one row per pond+icon, pre-sorted), Photon.Interfaces opcode 102
- **r56521** — GetPondPinIcons request/response handling

## Investigation Journal

- Commit list taken from JIRA comment (Yevhenii Shust, 2026-07-21) at face value; SVN audit pending (Phase 2).
- Release context (user-stated): the task must ship with the FPA release, which releases from MFT20260325 (Content). Commits are on NPN20260602 (Code), branched from MFT20260325@16130 — r16339+ are after the branch point, so NOT inherited by MFT. Hypothesis for Phase 2: NPN→MFT merge is required and not yet recorded in JIRA. Verify ancestry and merge state via svn.
- VCS audit (`svn log -r 16131:HEAD <NPN-URL> | grep FP-44794`): five commits found — r16339-r16342 as posted, plus **r16346** (csproj Content Include fix) NOT posted in JIRA. Same grep over MFT20260325: zero commits → no merge to MFT yet; merge is required for the FPA release (close phase, user-directed downward merge Code→Content).
- WC freshness: NPN WC was at r16327 < r16339; `svn status` near-clean (only ignore-on-commit Nintendo.csproj); user approved `svn update` → r16350. Disk reads trustworthy from here on.
- r16342 verified as `svn move` (svn log -v shows `A ... (from ...16-028...:16341)`) — file history preserved. Patch seq NPN.M -026/-027/-028 unique across all NPN patches (ls SQL/Patches). r16340's file name (07.16-028) vs inner PatchName (07.21-028) mismatch existed for ~1h; r16342 renamed the file to match — the applied PatchName was consistent (07.21-028) in both revisions, so no double-apply risk.
- `TableEditModel.Create` hypothesis (project gotcha: missing case → ArgumentNullException) DISPROVEN: read the factory switch in `TableEditModel.cs` — a `default:` branch builds `TableEditModel<T>` generically via `GetType(tableName)` + `Activator.CreateInstance`; `PondPinIcons` (attribute-only entity) is covered; `PondPinIconsSchedule` has an explicit case for its custom validation model.
- Event icon data-path verified end-to-end: `SqlMonetizationProvider.GetCurrentEvent` (`SELECT Top 1 * FROM Events`) → `RestoreFromReader` (reflection by column name, DBNull-safe per `RestoreFieldByName`) → `EventCache.FromDto` → `MakeEqualTo` (SerializationHelper: copies same-name props, `int?`→`int?` type-equal) — `PondPinIconId` reaches `MarketingEvent`. `EventCache` change-detection extended with `PondPinIconId` (r16341) so icon reassignment triggers ActiveEvent refresh.
- Opcode 102 availability in MFT verified: grep `= 102|= 103` over MFT `OperationCode.cs` — only `ClientDisconnect = 103` (with the next-free marker); 102 is unused in MFT → no conflict on merge.
- Data patch glyph claim ("copied verbatim from client InitPondPin.StateIcons") verified against client repo (Win64_CodeBranch, `InitPondPin.cs`): all 11 glyph values match verbatim incl. empty NewPond (client glyph commented out) and empty Competition (absent on client — new, as the patch comment states). Enum-description claim (Helloween→Halloween, StPartick→StPatrick) verified against `MarketingEventHoliday` enum.
- Event pin rule port verified: client `SetPondsOnGlobalMap.UpdateEvents` requires `Config.PondIds != null` and `Start <= now < Finish` — server resolver reproduces both (initial "null PondIds might mean all-ponds" hypothesis disproven: old client behavior was identical).
- UGC pin rule port verified verbatim: client `TournamentManager.Instance_OnGetUserCompetitions` filter (IsRegistered && (Approved || !IsSponsored) && !IsDisqualified && !IsDone) == server `IsUserCompetitionPinWorthy`; source claim ("mirrors UGCGetUserCompetitions") verified — same providers (`GetCompetitionsOfHost` + `GetVisibleCompetitions.FilterPaidPonds` + TournamentId dedup), minus ShowEnded/pagination/obfuscation branches not applicable to pins.
- Tournament pin rule port DIVERGES (→ F-1): client pins only statuses {Signed, RegAndStarting, ScoreSet, Registration} via `TournamentHelper.GetCompetitionStatus`; for an active (started) tournament the client requires IsRegistered && IsApproved (else NotRegAndStarting → no pin), while server `IsTournamentPinWorthy` (`IsActive && IsRegistered || RegistrationStart < now`) also pins active tournaments for unregistered/unapproved players via the `RegistrationStart < now` arm.
- "Canceled tournament has IsEnded == 1" claim verified: `SqlTournamentProvider` cancel paths (both pre-start and started variants) run `SET ... IsEnded = 1, IsCanceled = 1`.
- Client contract mirror (r56517/r56521, Win64_CodeBranch) verified: `GlobePinIcon`/`IconPosition` field-identical to server; `IPhotonServerConnection` extended alongside the partial (interface-sync rule respected); `SetPondsOnGlobalMap` calls `GetPondPinIcons()` on globe entry, `OnGotPondPinIcons` intentionally unconsumed (scope split). Client commits live on Unity_Fishing_CodeBranch — the FPA client releases from MainClient, so the client call must NOT reach MainClient before the server merge lands in MFT (unknown opcode 102 otherwise); reverse order is safe (server-first adds an operation nobody calls).
- Test-count claim (22 unit tests, no live DB) verified by counting [TestMethod] in the r16341 diff: 9 (cache) + 13 (resolver), all on Moq/`ITravelProvider` fakes.
- UnicodeCode storage-convention claim ("same as InventorySortingGroups.Icon") settled at schema level: `InventorySortingGroups.Icon` is `varchar(10)` — physically cannot hold a PUA glyph character, so it stores the ASCII `\uXXXX` text; `PondPinIcons.UnicodeCode VARCHAR(16)` + CHAR(92) seed follows the same convention. (Local-DB row probe attempted via DataGrip MCP — timed out awaiting manual confirmation in autonomous mode; schema argument suffices.)
- Protocol note: new opcode only — old clients never send 102, server merge is backward-compatible; no F2PProtocolVersion increment needed for the server-side merge alone.
- WebAdmin cache-refresh integration verified: page button posts `refreshServerCache` + tableName → `ToolsModel_Caches.RefreshServerCache` → `CacheRefreshHelper.GetCachesToRefreshByTable` (reads `Caches.Configuration` from the VW_AllCaches-backed config) → refresh signal with cache names `PondPinIcons,PondPinIconsSchedule`, matching the `nameof()` registrations in `PondPinIconsCache.Init`. WebAdmin does not need its own `PondPinIconsCache.InitDefaults` (Global.asax.cs untouched — correct; game-server `GameApplication` got the init in r16341).
- Delegated independent review (Step 7): code-reviewer agent + Codex, both blind. Agent returned 1 finding (Scheduled duplicate rows → F-2) + strong clean-checks; Codex returned 4 Medium + 5 Low + hypotheses. Re-verification of every delegated claim:
  - Codex "canceled tournaments keep pinning" REJECTED: every cancel path (ReleaseTool, WebAdmin `UpcomingReleaseModel`, UGC `UGCProcess_08_PublishStart`) funnels into `TournamentStartAdapter` → `SqlTournamentProvider.CancelTournament`, which always sets `IsEnded = 1, IsCanceled = 1` (both variants); the UGC delete path (`IsDeleted=1, IsCanceled=1`, no IsEnded) is filtered upstream (`GetUserCompetitionsVisible/OfHost` filter `IsCanceled=0 AND IsEnded=0`, per agent's SQL check). Executor's comment and test are accurate.
  - Codex "seed all-or-nothing" REJECTED: table is created by patch -026 in the same series; partial population between -026 and -027 impossible in a normal deploy.
  - Codex "tournament boundary inconsistency (`EndDate < now`, `RegistrationStart < now`)" REJECTED: comparisons are verbatim identical to client `TournamentHelper.GetCompetitionStatus` — "fixing" them would break the port fidelity the feature aims for.
  - Codex "non-atomic two-entity cache refresh" and "DCL without volatile" REJECTED as project-convention: same pattern as pre-existing caches (agent verified `TackleCompatibilityCache`, `ProductComponentGroupsCache`); init happens at startup before traffic.
  - Codex "Kendo nullable FK posts 0 instead of null" REJECTED by precedent: `Int32?` + `[ForeignKey]` columns (Ponds.RegionId/CountryId/StateId, RewardId, WeatherPrecipitationTypeId, ...) have shipped for years on the same grid machinery.
  - Codex "UTC serialization ambiguity" set aside as not-new-risk: `GlobePinIcon.Start/Finish` go through the same `SerializationHelper.JsonSerializerSettings` + DB datetime source as the long-standing `ActiveEvent` push the client already consumes.
  - Codex "INFORMATION_SCHEMA unqualified" and "GetCurrentEvent TOP 1 without ORDER BY" — pre-existing project-wide patterns, latter untouched by this task.
  - Codex "empty-glyph Competition/NewPond seed" DOWNGRADED to Info (F-5): intentional and documented in the patch comment (verbatim preservation of current client behavior).
  - Codex "empty PondIds bypasses save validation" CONFIRMED (F-3): `TableEditModel.ValidateAllJsonProperties` does `IsNullOrWhiteSpace(json) → continue`, so `PondPinIconsScheduleModel.ValidateJsonProperty` never runs for an empty cell; `EndTime > StartTime` is checked nowhere. Mitigated by cache-refresh warning for empty PondIds; inverted window saves silently dead.
  - Codex "FK doesn't enforce icon type" CONFIRMED as fact, kept Info (F-4): UI-filter-only integrity, consistent with the codebase's CSV-without-FK spirit; cross-type reference is silently inert in the resolver.
  - Agent "Scheduled branch emits duplicate (pond, icon) rows on overlapping same-icon windows" CONFIRMED (F-2) by direct code read: `SelectMany` without per-pond grouping, `Emit` never dedups, contract doc says "one row per (pond, active icon)".
  - Agent hypothesis "per-call DB load" noted, not a finding: called once per globe entry (client `SetPondsOnGlobalMap`), same stored procedures the globe screen already invokes for tournaments/UGC.
  - Own recon hypothesis "Competition kind missing from TournamentsCache" DISPROVEN: `GetTournamentsForCache` runs two SELECTs — KindId=1 (±45d horizon) and KindId=3 (±14d horizon) — both yielded into the static cache; the resolver's Competition branch is reachable.

## Findings

### F-1: Tournament pin rule diverges from the client logic it claims to port [Medium]

**Description:** `PondPinIconsResolver.IsTournamentPinWorthy` (`Shared/SharedLib/Config/PondPinIconsResolver.cs`) is documented and tested as "Sport pin rule, ported from the client globe logic", but for an active (started) tournament it diverges: the client (`SetPondsOnGlobalMap` + `TournamentHelper.GetCompetitionStatus`, pin statuses {Signed, RegAndStarting, ScoreSet, Registration}) removes the pin for players who are not registered (or registered but not approved) — `NotRegAndStarting` is not a pinned status — while the server rule `IsActive && IsRegistered || RegistrationStart < now` keeps pinning via the `RegistrationStart < now` arm. Every active Sport/Competition tournament will show a pin to all players, where the old client showed it only to approved participants; player-visible behavior change hidden behind a "port" label.

**Investigation:** Client rule read from `Win64_CodeBranch` `SetPondsOnGlobalMap.cs` (`_tournamentStates`, `PhotonServerOnGotOpenTournaments`) and `TournamentHelper.GetCompetitionStatus`; server rule from the r16341 diff and `PondPinIconsResolverTests`. Case table built: (IsActive, !IsRegistered) → client no-pin / server pin; (IsActive, IsRegistered, !IsApproved) → client no-pin / server pin; all other branches match (incl. ScoreSet via `RegistrationStart < now`, Finished via IsEnded/EndDate). Boundary comparisons (`<` vs `<=`) verified identical to the client — not part of the divergence.

**Resolution:** Author clarification, decision-affecting — if the widening is intentional (arguably better UX: advertise joinable/watchable tournaments), Accept with the comment reworded away from "ported"; if not, tighten the rule to the client's status set. Does not block the merge for the FPA release.

**Discovered by:** skill recon.

### F-2: Scheduled branch emits duplicate (pond, icon) rows on overlapping same-icon windows [Low]

**Description:** In `PondPinIconsResolver.ResolveIcons`, the `Scheduled` case flattens active schedule entries with `SelectMany` and `Emit` appends every hit without grouping — unlike `BuildTournamentHits`/`BuildUgcHits`, which group by pond. Two overlapping `PondPinIconsSchedule` rows for the same icon and pond (a state the system deliberately allows — overlap validation only warns) produce two identical-glyph `GlobePinIcon` rows differing only in window, violating the class doc's "one row per (pond, active icon)" contract the client is told to apply as-is.

**Investigation:** Resolver code read directly (r16341 diff + disk at r16350); `FindScheduleOverlaps` confirmed warn-only ("Overlaps are allowed" comment); `Emit` confirmed dedup-free; test `Scheduled_entries_with_different_windows_stay_separate_rows` covers different ponds, not same-pond same-icon overlap.

**Resolution:** Author clarification, no blocking consequence — either merge per pond in the Scheduled branch (Min start / Max-or-null end, mirroring the tournament path) or declare duplicates acceptable for the client renderer and adjust the contract doc. Admin misconfiguration remains visible via the overlap warning either way.

**Discovered by:** code-reviewer agent.

### F-3: Empty or inverted schedule rows save silently in WebAdmin [Low]

**Description:** `TableEditModel.ValidateAllJsonProperties` (`WebAdmin/Models/DataEditingModels.cs`) skips validation for empty/whitespace values, so `PondPinIconsScheduleModel.ValidateJsonProperty` never fires for an empty `PondIds` cell — the row saves and only surfaces later as a cache-refresh warning, never producing a pin. `EndTime > StartTime` is validated nowhere (model, cache, schema), so an inverted window saves silently and is permanently inactive.

**Investigation:** `ValidateAllJsonProperties` read on disk — `if (string.IsNullOrWhiteSpace(json)) continue;` confirmed; `PondPinIconsScheduleModel`, `ValidateSchedule`, and patch -026 checked for an EndTime/StartTime invariant — none present; empty-PondIds path confirmed covered by the `ValidateSchedule` "no valid pond ids" warning at refresh time.

**Resolution:** Filed as admin-tooling polish → suggest to executor alongside F-2 (add empty/inverted checks in `PondPinIconsScheduleModel.ValidateJsonProperty` or `ValidateSchedule`); not blocking — admin-only surface with partial diagnostics.

**Discovered by:** Codex.

### F-4: Icon-type integrity is UI-filter-only [Info]

**Description:** `PondPinIconsSchedule.PondPinIconId` (dropdown filter `IconType == 6`) and `Events.PondPinIconId` (filter `IconType == 5`) are constrained only in the WebAdmin UI; the DB FKs reference `PondPinIcons(Id)` without type. A cross-type reference written via SQL or future code is silently inert (resolver matches schedule rows only in the Scheduled branch and events only by `PondPinIconId == icon.Id` under the Event branch).

**Investigation:** FK definitions read in patches -026/-028; `ForeignTableFilterExpression` semantics confirmed as client-side grid filtering (`Entities.cs`); resolver branch dispatch re-read to confirm silent no-op rather than mis-render.

**Resolution:** Accepted — consistent with existing schema patterns (CSV pond lists without FK, UI-level filters elsewhere); silent-inert failure mode is benign.

**Discovered by:** Codex.

### F-5: Competition and NewPond seeded with empty glyphs [Info]

**Description:** Seed patch -027 leaves `UnicodeCode = ''` for Competition and NewPond; the resolver emits Competition rows with an empty glyph once eligible tournaments exist (the catalog row does exist, so the branch fires). Documented in the patch as intentional verbatim preservation: the current client renders no glyph for New and does not pin Competition-kind at all.

**Investigation:** Patch comment cross-checked against client `InitPondPin.StateIcons` (New's glyph commented out; no Competition entry) — preservation claim holds. Resolver emits rows whose glyph is empty (no skip for empty `UnicodeCode`).

**Resolution:** Skipped — behavior-preserving by design; whether the future client UI hides empty-glyph rows is part of the deferred client wiring. Optional polish (skip empty-glyph icons server-side) left to the executor's judgment.

**Discovered by:** Codex (severity re-assessed).

### F-6: r16339 omitted csproj Content Includes for the new views [Info]

**Description:** r16339 added `PondPinIcons.cshtml`/`PondPinIconsSchedule.cshtml` but registered only the model in `WebAdmin.csproj`; without `<Content Include>` the views would not deploy (project gotcha). Fixed by the executor in r16346 before this review started.

**Investigation:** r16339 diff tail shows only the `<Compile>` entry; r16346 diff adds both `<Content Include>` lines; commit timeline shows r16346 landed after the ticket moved to In Review.

**Resolution:** Skipped — superseded by r16346.

**Discovered by:** skill recon.

## Notes

- r16346 is not posted in the JIRA commit comment (and its commit message carries a different story summary line, "Configurable pond pin icons on the globe travel screen"). The merge to MFT must include it.
- Client interface doc for `GetPondPinIcons` in `IPhotonServerConnection.cs` (r56521) says "Test request ..." — leftover draft wording, client-repo cosmetic.
- Executor field in JIRA is filled (Yevhenii Shust) and matches the commit author.
- Per-call cost note: `GetPondPinIcons` triggers `GetTournamentsDynamic` + two UGC stored procedures per invocation; called once per globe entry by the client, same procedures the globe screen already calls — comparable added load.

## Verdict (draft)

**Approve** (pending F-1 clarification with the executor; non-blocking).

The implementation is solid: idempotent patches with correct QUOTED_IDENTIFIER handling, verbatim glyph/rule ports verified against the client repo, correct cache/refresh integration, clean opcode routing, meaningful unit coverage (22 tests). F-1 needs an explicit intentional/unintentional answer from the executor; F-2/F-3 are optional polish suggestions; F-4/F-5/F-6 recorded only.

**Release path:** RESOLVED 2026-07-22 — the task was moved from the FPA release (MFT) to the 2026.6 Australian release, which ships from NPN20260602 (user-stated). All five server commits are already on NPN → **no cross-branch merge needed** (source = Code, no upward targets; the earlier downward NPN→MFT plan is void). Earlier same day the user had first directed that merge (to unblock the client dev, Sergii Karchavets), then held it before execution — MFT WC was svn-updated to r16351 but no merge applied; the release move explains the hold.

Compatibility assessment (recorded during the merge deliberation, still valid for the 2026.6 path): fully additive change — `F2PProtocolVersion` untouched, opcode 102 unknown to old clients (never sent), `MarketingEvent.PondPinIconId` is `[JsonIgnore]`-shielded from the existing ActiveEvent push, old client pin logic untouched in the client commits. Old client vs new server: fully compatible. New client vs old server: `HandleInvalidOperation` returns `ErrorCode.OperationInvalid` — soft no-op (verified in `OperationHelper`). Client half for MainClient will arrive via the client team's normal CodeBranch→MainClient flow for 2026.6; DLL for MainClient must then be rebuilt from the release server branch per photon_interfaces_dll_distribution. Opcode 102 verified free in MFT. Client commits (r56517, r56521) live on Unity_Fishing_CodeBranch; their arrival into MainClient must not precede the server merge into MFT (a MainClient build calling opcode 102 against an MFT server without the merge gets errors on globe entry); server-first is safe. No F2PProtocolVersion increment needed for the server side alone.

**Verification scope:** static code review + executor's unit tests + cross-repo source comparison (client Win64_CodeBranch); no runtime/DB-integration execution — the operation path (Photon routing → resolver → JSON response) and WebAdmin pages were not exercised live.
