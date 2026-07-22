---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16315, merged to NPN20260602 @ r16316
jira: https://fishingplanet.atlassian.net/browse/FP-44994
---

# Review: FP-44994 — ANNIVERSARY 2026: Server.UI - Pond Event Icon

## Summary

Adds a new holiday kind (No. 6, Anniversary marketing event) to the legacy pond event-icon system so the new event icon can be shown next to ponds on the global map. Per-pond enablement is driven from the DB via config JSON (`{"Holiday": 6, "PondIds": [...]}`). Task is a clone of FP-44794 (pond pin icons). Client-side counterpart (icon asset + enum mapping) is handled by the client team in CodeBranch/MainClient.

## Scope

- **MFT20260325 r16315** — Add Anniversary marketing event holiday kind
- **NPN20260602 r16316** — Merge of r16315

Client commits (context, other team): CodeBranch r56388 (Yuriy Burda, holiday enum mapping), r56400 + r56414 (Sergii Karchavets, client logic + icons), merged to MainClient @ r56405, r56415.

## Investigation Journal

- Intake from JIRA comments at face value; commit list pending Phase 2 `svn log` audit.
- VCS audit (`svn log -r 16200:HEAD <branch-URL> | grep -B 6 FP-44994` over MFT and NPN): exactly r16315 (MFT) and merge r16316 (NPN) — matches JIRA, no unposted commits. WC freshness: MFT WC at r16351 ≥ r16315 → disk reads trustworthy.
- Diff read (`svn diff -c 16315`): single line — `Anniversary` appended to `MarketingEventHoliday` in `Shared/ObjectModel/Monetization/MarketingEvent.cs`. Enum has no explicit values; member position 7 counted from `Unspecified`=0 → value 6, matching the task's `{"Holiday": 6}` config.
- Server consumers of `Holiday` enumerated via grep over the WC: only `GameProcessor.UpdateXmas2017Stats` (guard `Holiday != NewYear → return`, Anniversary unaffected — read on disk). `DebugContext.ActiveEvent` is a debug expose, not a consumer. No switch/if chains needing extension.
- Client-bound data path traced: `EventCache.FromDto` deserializes `ConfigJson` (`JsonConvert.DeserializeObject<MarketingEventConfig>`; `StringEnumConverter` with default `AllowIntegerValues` accepts `"Holiday": 6`) → `ObfuscatEventClone` keeps `Holiday`+`PondIds` in the client clone (nulls `ConfigJson`/`PondScriptedFish`) → serialized to client in `MasterClientPeer` (GetCurrentEvent) and `GameApplication.NotifyClientsAboutActiveEventChanged`; `Holiday` goes out as string `"Anniversary"` due to `[JsonConverter(StringEnumConverter)]`.
- Client mirror verified on disk: `Win64_MainClient` (FPA release client, WC r56498) `Assets/Photon Server Networking/ObjectModel/Monetization/MarketingEvent.cs` has `Anniversary` at the same position (value 6), same `StringEnumConverter` attribute; file last changed by merge r56405 (carries r56388+r56400 per its TortoiseSVN message), matching JIRA client comments. Present in `Win64_CodeBranch` too.
- Old-client protocol concern settled by release boundary: `SharedConsts.F2PProtocolVersion = 1126` already in MFT (grep) — FTUE clients (1125) are rejected after the FPA server deploy, so no connected client can receive the unknown `"Anniversary"` string once the event is enabled (event enablement is a manual post-deploy DB action per platform).
- WebAdmin entry point checked: `Events.ConfigJson` carries `[JsonValidator(typeof(MarketingEventConfig))]` (`WebAdmin/Models/Entities.cs`) — an FPA-built WebAdmin parses `"Holiday": 6`; a stale pre-FPA WebAdmin also accepts it (StringEnumConverter converts undefined integers without `Enum.IsDefined`) — soft degradation, no data-entry blocker.
- Branch-copy inheritance (Step 5): NPN20260602 based on MFT:16130; r16315 > 16130 → explicit merge required, present as r16316. Merge direction Content → Code correct; FPA ships from MFT itself, no further server targets. NPN HEAD file content verified via `svn cat` — enum identical.
- Protocol-gate hypothesis DISPROVEN (course change): initial recon assumed the F2PProtocolVersion 1125→1126 increment rejects FTUE clients at connect. Read the enforcement path: server `MasterClientPeer.HandleGetProtocolVersion` only REPORTS the version; client `PhotonServerConnection_OperationResponseHandlers.HandleGetProtocolVersion` has the comparison commented out (`ProtocolVersionCheckPassed = true;//serverVersion == ProtocolVersion`). No hard gate exists — a stale 1125 client CAN stay connected to an FPA server (grep for ForceUpdate/MinClientVersion mechanisms in client Scripts/Common found none).
- Provenance of the disabled gate (user-prompted, verified by `svn blame` on both client checkouts + `svn log -c`): commented out in CodeBranch **r53326** (2026-04-20, yuriy.burda) — a commit for **FP-42516** (premium-bonus API/stats), unrelated to protocol handling → stray debug hack shipped inside a feature commit. Reached MainClient via bulk merge **r54243** (2026-05-18, kr; merged range includes 53296-53326). Consequently every client built from MainClient ≥ r54243 — including the released FTUE client and the upcoming FPA client — performs no protocol-version check; clients older than r54243 (e.g. Stable pin r52058) still enforce it.
- Gate defect routed (user decision): Filed → **FP-45149** "Protocol version check is disabled" (Bug, epic FP-35241 "BUGS verified on PROD", assignee Yuriy Burda, fixVersion 2026.5 Anniversary, Scrum Team FPA, Component Client, High); softened wording per user. Flag comment posted in FP-42516 (comment 131781), Relates link FP-45149 ↔ FP-42516.
- Runtime probe (Windows PowerShell 5.1 / .NET Framework, the exact `packages/Newtonsoft.Json.13.0.1/lib/net45` assembly, surrogate enum pair with/without `Anniversary` + `[JsonConverter(StringEnumConverter)]` — equivalence: same converter, same assembly, same shape): `{"Holiday": 6}` → `Anniversary`; `{"Holiday": 7}` and `999` → silently accepted as undefined values; `{"Holiday":"Anniversary"}` against the old enum → `JsonSerializationException`; new-side serialize → `"Holiday":"Anniversary"` (string); old-side serialize of undefined 6 → `"Holiday":6` (number, which the new client parses back to Anniversary — pre-deploy config entry is safe end to end).
- Client-side handling of the ActiveEvent payload read in `Win64_MainClient`: both deserialization sites (`PhotonServerConnection_OperationResponseHandlers` GetCurrentEvent case, `PhotonServerConnection_IPhotonPeerListener` ServerCachesRefreshed case) have no local try/catch; `SerializationHelper.JsonSerializerSettingsClone` Error delegate logs but does not set `ErrorContext.Handled = true`, so the exception propagates out of the handler. In the push case the throw happens after `SetGlobalVariables` but before `ServerCachesRefreshed(names)` — remaining same-push subscribers are skipped. Exact behavior of an exception escaping into the Photon client dispatch loop not verified (binary); bounded to losing that one dispatch.
- Client icon application read in `SetPondsOnGlobalMap`: `UpdateEvents()` is one-shot per map-component instance (`_isSubscribed` gate), reads `EventsController.CurrentEvent`, unknown holiday silently skipped via `_eventHolidayMap.TryGetValue`; `OnCurrentEventChanged` has zero subscribers (grep over client Assets). Map component is recreated on each global-map entry, so pushes take effect on next map open — pre-existing client pattern, not introduced by this task.
- Delegated independent review (Step 7): code-reviewer agent (blind) — no findings at confidence, 2 unresolved hypotheses (1125 gate enforcement; StringEnumConverter out-of-range acceptance), clean checks incl. client consumer mapping (`_eventHolidayMap` → `PondStates.Anniversary` → glyph U+E0B5) and NPN identity. Codex (blind) — 4 findings. Re-verification of every delegated claim:
  - Codex "old clients cannot deserialize the Anniversary string" CONFIRMED (→ F-1) by own probe + client source reads above; Codex's framing "changes the wire value from numeric 6 to string" corrected: Holiday always serialized as string for defined members — what changes is that value 6 becomes a string unknown to pre-FPA clients.
  - Codex "undefined numeric holiday accepted everywhere without error" CONFIRMED (→ F-2) by own probe (7/999 accepted) + `Entities.cs` JsonValidator read + client TryGetValue read. Pre-existing, actualized by this task's manual numeric config workflow.
  - Codex "implicit enum ordinal is an untested cross-repo contract" CONFIRMED as fact (→ F-3) — enum has no explicit values on either side; only `EventsCache.ConcurrencyTest` exists (agent + Codex both searched, no enum-shape/serialization tests).
  - Codex "client applies icons one-shot and ignores pushes" CONFIRMED as fact by `SetPondsOnGlobalMap`/subscriber greps above, but it is client-team territory and a pre-existing pattern; impact softened by per-entry map recreation → Note, not a Finding (server review scope; don't track other teams' bugs in our backlog).
  - Agent's clean checks consistent with own recon on every overlapping point (consumers, mirrors, NPN, tests, WebAdmin validator path).
- Findings discussion (user, point-by-point): F-1 confirmed Accepted [Low] — with FP-45149 guaranteed to ship in FPA, exposure closes at connect time; impact note added to FP-45149 description (platform stores enforce/push updates; mismatches yield non-crash runtime glitches fixed by updating). F-2 routed to `data-editing` backlog. F-3 confirmed Skipped.
- Phase 3 executor-claims sweep: (1) "MFT @ r16315" — svn log + diff; (2) "Merged => NPN @ r16316" — svn log + svn cat content check; (3) client "CodeBranch @ r56388, merge required together with icon+enum mapping" — MainClient merge r56405 carries r56388+r56400 (merge log message), r56415 carries r56414 icons; MainClient file content verified on disk (enum member + `_eventHolidayMap` entry + `InitPondPin` glyph "") per the client-bulk-merge content-verification rule. All claims hold.

## Findings

### F-1: Active-event JSON with `"Holiday":"Anniversary"` breaks MarketingEvent deserialization on stale pre-FPA clients; the protocol gate assumed to prevent this is not enforced [Low]

**Description:** With `Anniversary` defined, an FPA server serializes the active event's `Holiday` as the string `"Anniversary"` (`[JsonConverter(StringEnumConverter)]` on `MarketingEventConfig.Holiday`) in both client paths (`MasterClientPeer` GetCurrentEvent response, `GameApplication.NotifyClientsAboutActiveEventChanged` push). A client built before the member existed throws `JsonSerializationException` on that string, losing the whole `MarketingEvent` payload — and, in the push path, skipping the remaining `ServerCachesRefreshed` processing for that dispatch. The protocol-version gate does not prevent this: the client-side comparison is commented out (`ProtocolVersionCheckPassed = true;//...`) and the server only reports its version. Severity Low because the degradation is bounded (no icon the old client couldn't show anyway + one lost dispatch + an error log), the exposure window is small (players who haven't restarted since the FPA client update), and this is the established legacy pattern — every previous holiday addition shipped the same way.

**Investigation:** Serialization path traced server-side (EventCache → ObfuscatEventClone → both send sites, read on disk at r16351); string-vs-number wire behavior and old-enum throw verified by runtime probe on the exact net45 Newtonsoft 13.0.1 assembly; client no-catch/no-Handled behavior read in `Win64_MainClient` (`PhotonServerConnection_OperationResponseHandlers`, `PhotonServerConnection_IPhotonPeerListener`, `SerializationHelper`); protocol-gate non-enforcement read in client `HandleGetProtocolVersion` + server `MasterClientPeer.HandleGetProtocolVersion`; no alternative force-update mechanism found by grep in client `Scripts/Common`.

**Resolution:** Accepted — established legacy-system behavior with bounded impact; operational mitigation (enable the event after the platform's client update is live) is the historical practice. The underlying gate defect is tracked separately as FP-45149 (fixVersion FPA) — once the check is restored, the stale-client exposure window closes at connect time. Optional future hardening for the executor's judgment: numeric serialization for `Holiday` would degrade silently on old clients (undefined int is skipped by `TryGetValue`) instead of throwing, but that is a cross-repo contract change out of this task's scope.

**Discovered by:** skill recon + Codex (independently); mechanism verified by probe.

### F-2: Undefined numeric `Holiday` values pass every validation layer silently [Low]

**Description:** `StringEnumConverter` (default `AllowIntegerValues`) accepts any integer: probe shows `{"Holiday": 7}` and `{"Holiday": 999}` deserialize without error into undefined enum values. WebAdmin's `[JsonValidator(typeof(MarketingEventConfig))]` on `Events.ConfigJson` (`WebAdmin/Models/Entities.cs`) therefore gives an admin no save-time feedback on a typo (e.g. `60` instead of `6`); the server caches and distributes it; the client's `_eventHolidayMap.TryGetValue` silently shows nothing. The task's workflow — an admin hand-typing the numeric config from the JIRA description for 27 ponds — actualizes this pre-existing gap.

**Investigation:** Probe on the exact Newtonsoft assembly (7/999 accepted, .NET Framework runtime); `Entities.cs` JsonValidator attribute read; client `SetPondsOnGlobalMap.UpdateEvents` TryGetValue skip read in `Win64_MainClient`.

**Resolution:** Pre-existing — not introduced by r16315; routed to `data-editing` module backlog (`Enum.IsDefined` candidate in the validation layer, with an audit caveat for enums that legitimately carry undefined values).

**Discovered by:** code-reviewer agent (hypothesis) + Codex (finding); confirmed by probe.

### F-3: The DB↔server↔client holiday contract rests on implicit enum order with no explicit values or contract test [Info]

**Description:** `MarketingEventHoliday` has no explicit member values on either the server or the source-duplicated client mirror; the DB config `{"Holiday": 6}` and the cross-repo equivalence hold only because both files list members in the same order. A future insertion before `Anniversary` on one side would silently remap stored configs and outbound JSON with no compile or test failure (only `EventsCache.ConcurrencyTest` exists in the area). r16315 followed the existing style — this is a property of the legacy enum, recorded as context.

**Investigation:** Both enum files read (server MFT disk r16351, client MainClient disk r56498); test coverage searched by both delegates and recon (no enum-shape/serialization tests found).

**Resolution:** Skipped — legacy-wide characteristic, not this commit's defect; explicit values would need a synchronized two-repo edit, optional suggestion for the executor.

**Discovered by:** Codex.

## Notes

- Executor field (customfield_11224) was empty at intake; filled (Yuriy Burda) by close time — matches the commit author.
- Client-side (other team, pre-existing pattern): pond-event icons are applied one-shot per global-map instance (`SetPondsOnGlobalMap.UpdateEvents` behind `_isSubscribed`); `OnCurrentEventChanged` has no subscribers, so a mid-session event start/stop shows up only on the next map open. Softened by per-entry map recreation. Flag to the client team at the user's discretion; not tracked in our backlog.
- Client-side (other team): whether glyph U+E0B5 exists in every shipping platform's TMP font asset is not verifiable from source here (r56414 "add all icons" presumably covers it); client team's territory.
- Production Events row for Anniversary not yet verifiable (event data is entered operationally closer to the 2026-07-27 release); the reviewed change is config-schema-side only.

## Verdict

**Approve.**

The server change is a minimal, correct extension of the legacy holiday enum: value 6 matches the task spec, both branches (MFT r16315, NPN r16316 merge) verified, client mirror (MainClient r56405/r56415) verified at content level including the icon mapping and glyph, all executor claims hold, and the DB→server→client data path round-trips correctly on the exact shipping serializer (runtime-probed). F-1/F-2 are accepted/pre-existing legacy characteristics with bounded impact; F-3 is context.

**Verification scope:** static source review of both repos + runtime serialization probe on the shipping Newtonsoft assembly; no live-DB or in-game verification (production event row does not exist yet; client rendering of the new glyph not exercised — client team's scope).
