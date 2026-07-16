---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16229, merged to MFT20260325 @ r16323
jira: https://fishingplanet.atlassian.net/browse/FP-44537
---

# Review: FP-44537 — [Steam][Inventory] Repairing a rod does not repair the attached quiver

## Summary

Bug: repairing a feeder rod did not clear the broken state of a quiver tip that was not the currently active one. Root cause (per executor's comment): `InventoryItemChange` carried a single `QuiverIsBroken` flag tied to the active `QuiverId`, so the client never received the broken-state change for non-active quivers. Fix replaces the flag with a per-quiver `QuiverState[] Quivers` array (`QuiverId` + `IsBroken`), projected for every quiver tip in `CopyChanges`; the client applies each entry to the matching tip. Unit tests added in `ObjectModel.Tests`.

Coupling: change DTO field renamed `QuiverIsBroken` → `Quivers` — client and server must ship together; protocol version increment required (reviewer's JIRA comment). The client commit was REVERTED from the client Code branch @ r55915 (revert not inherited in the client Decomposition branch; fix presence to be re-checked after that branch merges back).

## Scope

*(audited: `svn log | grep` on NPN and MFT, client CodeBranch log — matches JIRA comments exactly)*

### NPN20260602
- **r16229** — Fix the condition of all quiver tips for the Feeder Rod
  - `InventoryItemChange`: `QuiverIsBroken` flag → `QuiverState[] Quivers` array (+ new `QuiverState` class)
  - Server projects all quiver tip states in `CopyChanges` (FeederRod case)
  - Test-client mirror updated in `NUnitClient_Inventory.ApplyTo` (per-quiver apply loop)
  - New unit tests `Shared/ObjectModel.Tests/InventoryTrackingTests.cs` (tracking, sibling-field isolation, JSON round-trip)

### CodeBranch (client)
- **r55712** — Apply broken state of all quiver tips from inventory changes (`PhotonServerConnection_Inventory.cs`, mirror of server DTO + apply loop)
- **r55915** — REVERT of r55712 (posted by reviewer, not executor; `[CODE BRANCH ONLY]`, client/server ship-together coupling)

No FP-44537 commits on MFT (correct — protocol-coupled fix belongs to Code branch only).

## Investigation Journal

- Executor field (`customfield_11224`) filled: Yevhenii Shust — matches commit-comment author.
- Server branch per JIRA comment: NPN = current server Code branch (per `_index.md` Branch Roles at review time).
- WC freshness: NPN WC at r16307 ≥ r16229 — disk reads trustworthy; no stale-WC fallback needed.
- Verified executor's root-cause claim: `FeederRod.RepairItem` (pre-existing, untouched) already repairs the active quiver then ALL quiver tips within the `damageRestored` budget — server state was correct, only client sync was missing. Claim accurate.
- Verified "mirrored on client and server": client r55712 diff is mechanically identical (DTO field swap + per-quiver apply loop).
- `InventoryItemChange` is a wire-only DTO: built via `InventoryTracking.CopyChanges`/`ToChanges`, compressed-JSON-pushed over Photon (`GameClientPeerExtensions.SendItemsUpdatedToClient`, `GameClientPeer_Missions`); not persisted to Mongo/SQL. `IChange.Apply`/`ToChangesDictionary` path does NOT build `InventoryItemChange` (it is not `IChange`) — so `Quivers` is always populated server-side for FeederRod changes; null only under client/server version skew.
- Protocol version check: `SharedConsts.F2PProtocolVersion` = 1125 on BOTH NPN and MFT — the increment required by reviewer's JIRA comment is not yet done on NPN (expected at NPN release prep; comment records the constraint).
- Release-checklist field (`customfield_11323`): no option in the vocabulary covers protocol increment; diff derives no mechanical options (no SQL/NoSQL/service changes) — nothing to tag for this task.
- Leftover `QuiverIsBroken` references: `FeederRod.SetProperty` (data-driven domain setter, active-quiver-only, pre-existing) and the change-label string in `NUnitClient_Inventory.ApplyTo` (consumed via `.ToHashSet()` — duplicate labels collapse, harmless).
- `ObjectModel.Tests.csproj` is SDK-style — new test file auto-included, no `<Compile Include>` needed.
- JIRA Expected sub-asks №1 (WebAdmin shows broken quiver status) and №2 (REPAIRED log mentions quiver) are NOT addressed by r16229 (no WebAdmin changes; `Inventory_Logging` REPAIRED line unchanged: `$"REPAIRED {change.Item.InfoWithDurability}"`).
- Delegated independent reviews (blind): code-reviewer agent + Codex, both scoped to r16229 with client r55712 for contract cross-check.
- Delegation disagreement resolved by diff, not majority: agent (no shell access in its toolset, could not read the diff) inferred the null-`QuiverTips` dereference was a High-severity regression ("old code only touched QuiverTips when QuiverId.HasValue"); the actual r16229 diff shows the old code dereferenced `fr.QuiverTips.FirstOrDefault(...)` just as unconditionally — identical exposure, parity. Codex independently reached the same parity conclusion.
- Codex cross-checked client CodeBranch HEAD (r55929): `PhotonServerConnection_Inventory.cs` last-changed r55915, `QuiverIsBroken` present again — the revert really removed the fix from client CodeBranch; reviewer's JIRA note matches reality.
- Protocol gate mechanism verified: `MasterClientPeer.HandleGetProtocolVersion` (op allowed pre-auth) returns `SharedConsts.F2PProtocolVersion`; client compares against its compiled-in version — increment closes both skew directions. (Codex's "no version gate found" was a miss — it only inspected `GameAuthenticator`.)
- CORRECTION to the r55929 client check: that WC was stale. At repo HEAD the Decomposition merge-back **r56307** (2026-07-13, "Auto-Merged ... from branches/Unity_Fishing_CodeBranch_Decomposition") reintroduced the fix — `svn cat -r HEAD` shows `Quivers` apply loop present, `QuiverIsBroken` gone. The revert r55915 did not survive the merge-back; client CodeBranch now carries the fix, which makes the protocol increment a live precondition for the next client-CodeBranch-based build.
- F-1 discussion (user input, 2026-07-16): protocol increment planned NOW on BOTH MFT and NPN (1125→1126, same value; NPN separated later with its own further increment). Reason: FPA (2026.5 Anniversary) releases from MFT — the branch transitions FTUE→FPA, and the increment is the in-branch release boundary (recorded in project memory `fpa-release-from-mft-protocol-split` for post-Git-migration tagging). DLL propagation confirmed per `<kb>/reference/photon_interfaces_dll_distribution.md`: `Photon.Interfaces.dll` is rebuilt per server branch and committed into the paired client branch (NPN → client CodeBranch, MFT → client MainClient).
- fixVersion question resolved by user: r16229 WILL be merged into MFT for FPA — fixVersion 2026.5 Anniversary is correct. Derived hard pairing condition added to F-1 Resolution (client apply-fix must reach client MainClient with the FPA build). Sequencing decision: findings round F-2…F-4 first, protocol increment right after.
- Course correction (user): the increment is NOT two independent edits — it commits once on MFT and reaches NPN via the standard Content→Code `svn merge`; clients receive it only through per-branch `Photon.Interfaces.dll` rebuilds (MainClient ← MFT build, CodeBranch ← NPN build after the merge). The client apply-fix reaches MainClient as a client-source port (not via DLL).
- Protocol increment COMMITTED 2026-07-16: server MFT **r16321** (1125.2 → 1126.0, minor reset), client MainClient DLL **r56424**, server NPN **r16322** (1125.0 → 1126.0, own branch-local commit). Commit messages follow the team convention captured in `<kb>/reference/release_versions_and_process.md` → Increment commit convention.
- Convention correction (user): increment commits are NEVER merged between branches — the `[<BRANCH>]` prefix marks them branch-local; my earlier "commit on MFT, merge MFT→NPN" framing was wrong. Each branch commits its own increment.
- Sequencing incident: NPN server increment r16322 was committed while the paired CodeBranch DLL was not yet built — protocol gate diverged for developers on the NPN↔CodeBranch pair until the DLL landed (r56425). Rule captured in `<kb>/reference/release_versions_and_process.md`: server increment and paired client DLL commits land together, same minute; never commit the server side before the DLL is built and tested.
- Increment chain committed: MFT r16321 + MainClient DLL r56424; NPN r16322 + CodeBranch DLL r56425. Both committed DLLs verified via reflection to carry F2P=1126/Minor=0 (rules out wrong-branch/stale-source build). Runtime smoke test of the CodeBranch DLL still pending on the user (committed untested to close the protocol-gate gap fast).
- FPA merges executed 2026-07-16 as a same-minute pair: server r16229 → MFT @ **r16323** (3 files + root mergeinfo, clean); client r55712 content → MainClient @ **r56426**. No Photon.Interfaces rebuild needed for the merge — r16229 touches ObjectModel + tests only; the wire-DTO change travels as source.
- Client cherry-pick gotcha hit: MainClient root mergeinfo blanket-covers CodeBranch `37953-56303`, so `svn merge -c 55712` silently no-oped (mergeinfo-only, zero file changes — the file still had `QuiverIsBroken`). Force-applied with `--ignore-ancestry`, content verified by grep before commit. Gotcha recorded in project memory (`mainclient-cherry-pick-mergeinfo`).
- MFT-side mergeinfo verified post-commit: `/branches/NPN20260602:...,16229` recorded as a precise per-revision list (no blanket ranges — the silent-no-op trap does not exist on the server side).

## Findings

### F-1: Wire-DTO rename ships without the protocol increment it depends on (increment pending on NPN) [Medium]

**Description:** r16229 renames the JSON wire field `QuiverIsBroken` → `Quivers` in `InventoryItemChange`, making server and client mutually incompatible across versions: new client + old server → `Quivers` deserializes null and the unguarded `foreach (var q in src.Quivers)` in the client apply path throws, aborting the inventory-change application; old client + new server → absent `QuiverIsBroken` defaults to false, so a genuinely broken active quiver renders as intact (display regression beyond the original bug). The sole mitigation is the protocol version gate (`MasterClientPeer.HandleGetProtocolVersion` / `SharedConsts.F2PProtocolVersion`), and the increment is NOT yet done on NPN (1125 == MFT 1125). Additionally the client-side fix currently lives only in the client Decomposition branch — client CodeBranch reverted it @ r55915 (verified at HEAD r55929).

**Investigation:** protocol constants compared NPN vs MFT; gate mechanism traced to `HandleGetProtocolVersion`; client HEAD state verified by Codex; both skew directions derived from the diffs (server `CopyChanges`, client `ApplyTo`).

**Resolution:** Accepted (user-confirmed 2026-07-16). The fix SHIPS WITH FPA: r16229 to be merged NPN → MFT (fixVersion 2026.5 Anniversary is correct). Actions spawned: (1) increment `F2PProtocolVersion` 1125→1126 on BOTH MFT and NPN (+ rebuild/commit `Photon.Interfaces.dll` into MainClient and CodeBranch respectively); (2) HARD PAIRING: port the client apply-fix into client MainClient before/with the FPA client build — an FPA server with r16229 talking to an FPA client without the apply loop shows a genuinely broken active quiver as intact on every FeederRod change (worse than the original bug; the 1126 gate only blocks FTUE-era clients, not a fix-less FPA client); (3) NPN gets a further increment when separated for its own release. Client-fix presence in client CodeBranch — VERIFIED at repo HEAD (Decomposition merge-back r56307 reintroduced it over the r55915 revert).

**Discovered by:** skill recon + Codex (High) + code-reviewer agent (Info) — convergent.

### F-2: No test exercises the actual repro path end-to-end [Low]

**Description:** The three added tests pin the `CopyChanges` projection and a JSON round-trip, but nothing drives repair → diff → client apply: `RepairItem_m` in the NUnit test client has zero callers with a FeederRod; none of the tests invokes the modified `ApplyTo`; the round-trip test uses default `JsonConvert` settings rather than the production `InventoryTracking.Serialize` / `SerializationHelper.JsonSerializerSettings` path. A regression in `FeederRod.RepairItem` or in the apply loop would pass all added tests. (Executor's JIRA test claim itself is accurate about what the tests cover.)

**Investigation:** grep `RepairItem_m` callers (definition only); test fixture read from the diff; production settings compared (`InventoryTracking.settings` vs `SerializationHelper.JsonSerializerSettings` — matching shape, verified by agent).

**Resolution:** Skipped (user-confirmed 2026-07-16) — non-blocking; a soft suggestion (integration test driving repair → diff → `ApplyTo` via the NUnit test client) goes into the verdict's JIRA comment, no reopen.

**Discovered by:** code-reviewer agent + Codex — convergent.

### F-3: Pre-existing NPE exposure on null `QuiverTips` in `CopyChanges` [Low]

**Description:** `CopyChanges` (FeederRod case) dereferences `fr.QuiverTips` unconditionally while null is a first-class state elsewhere in the domain (`Inventory_Does.GetRodTemplate`, `Inventory_Can.CanSetQuiverIndex`, `FeederRod.MakeCloneOfItem` all guard it); `InventoryTracking.ToChanges`/`PopulateParameters` have no exception handling, so one such item would abort the whole inventory-diff batch. Exposure is byte-for-byte pre-existing (old code: unconditional `fr.QuiverTips.FirstOrDefault(...)`) — NOT introduced by r16229.

**Investigation:** actual r16229 diff read (old vs new dereference); null-handling call sites verified; agent's "regression" framing disproven (see journal); Codex concurred with parity.

**Resolution:** Pre-existing (user-confirmed 2026-07-16) — card only, no module-backlog entry (delete-test borderline: years in prod without incidents, trivially re-discoverable from code).

**Discovered by:** code-reviewer agent (severity/framing corrected by diff evidence).

### F-4: JIRA Expected sub-asks №1 and №2 not addressed, descope not recorded [Low]

**Description:** The ticket's Expected section carries two numbered QA asks beyond the core fix: (1) show broken-quiver status in WebAdmin → Player → Inventory, (2) enrich the `REPAIRED` inventory-log line with quiver info. Neither commit touches WebAdmin or `Inventory_Logging` (`REPAIRED {change.Item.InfoWithDurability}` unchanged); the executor's JIRA comment does not mention descoping them.

**Investigation:** diff file list; `Inventory_Logging.LogInventoryChange` read on HEAD.

**Resolution:** Filed → FP-45023 (user-confirmed 2026-07-16) — single combined follow-up (Story, WebAdmin+Server, Tech Debt, assignee = reviewer, Relates-linked): per-quiver broken-state display in Admin → Player → Inventory + quiver info in the REPAIRED log line. Non-blocking for the core fix.

**Discovered by:** skill recon.

## Verdict *(posted to JIRA 2026-07-16, comment 130482)*

**Approve.** r16229 correctly fixes the sync gap: server-side repair already repaired every quiver tip (`FeederRod.RepairItem`); the commit makes `InventoryItemChange` project all per-quiver states (`QuiverState[] Quivers`) instead of the single active-quiver flag, and the client applies them per-tip. Root cause, fix mechanics, and test claims in the executor's comment all verified accurate.

Ship conditions (release-gate) — ALL SATISFIED 2026-07-16:
1. ✅ `F2PProtocolVersion` 1125 → 1126: branch-local increments MFT r16321 + NPN r16322, paired client DLLs MainClient r56424 + CodeBranch r56425 (increment commits are never merged between branches).
2. ✅ r16229 merged NPN → MFT @ r16323, paired same-minute with the client apply-fix port into MainClient @ r56426.
3. ✅ Client CodeBranch carries the client fix (Decomposition merge-back r56307 overrode the r55915 revert) — verified at repo HEAD.

Residual: runtime smoke of the rebuilt CodeBranch DLL pending on the reviewer (constants verified via reflection); NPN gets a further increment when separated for its own release.

Non-blocking suggestion for the JIRA comment: an integration test driving repair → diff → client apply via the NUnit test client (`RepairItem_m` currently has no FeederRod callers) would pin the end-to-end scenario; the added unit tests cover the projection only.

Follow-up filed: FP-45023 (admin inventory quiver-state display + REPAIRED log enrichment).
