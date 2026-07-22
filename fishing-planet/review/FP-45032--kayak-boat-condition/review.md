---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16333, merged to NPN20260602 @ r16334
jira: https://fishingplanet.atlassian.net/browse/FP-45032
---

# Review: FP-45032 — Mission task 15857 'Get into a Paddle Kayak' completes when you board a boat instead of kayak

## Summary

Bug (High, 2026.5 Anniversary): the Anniversary event mission task 15857 'Get into a Paddle Kayak' completed when the player boarded **any** boat, despite the config carrying a 'kayak' condition. Executor's fix (per JIRA comment): "Fix boat condition ItemSubType and IsRentBoat being ignored" — the boat-condition check ignored `ItemSubType` and `IsRentBoat` fields of the condition.

## Scope

### MFT20260325
- **r16333** — Fix boat condition ItemSubType and IsRentBoat being ignored
- **r16353** — Add test coverage for IsRentBoat enforcement in boat condition matching (review follow-up, F-1)

### NPN20260602 (merged)
- **r16334** — Merge of r16333
- **r16354** — Merge of r16353

## Investigation Journal

- Intake from JIRA comment (id 131349): single fix commit on MFT (Content branch), already merged to NPN (Code branch) by the executor. NPN base is MFT:16130 < r16333, so the explicit merge was required (not inherited via branch copy).
- ⚠ Executor field (customfield_11224) empty in JIRA; executor identified as Yuriy Burda from the commit comment.
- VCS audit: `svn log -r 16130:HEAD` on MFT and `-r 16131:HEAD` on NPN, grep FP-45032 — exactly r16333 (fix) + r16334 (merge), matches intake. WC at r16351 ≥ r16333 — disk reads trustworthy.
- Defect mechanism verified in `BoatConditions.cs` @ HEAD: `BaseBoatCondition` is `[JsonObject(MemberSerialization.OptIn)]`; pre-fix `ItemSubType` carried only `[JsonConverter]` and `IsRentBoat` no attributes, so OptIn deserialization silently dropped both; `ConditionExtensions.Match` treats null filters as pass-through → any boat matched. Array form `ItemSubTypes[]` already had `[JsonProperty(ItemConverterType=...)]` and worked.
- Genesis verified in data: local Main DB `MissionTasks.TaskId = 15857` (mission 3983 `Anniversary24_AmazonianMaze`) ConfigJson uses the scalar form `{ type: 'IsOnBoatCondition', ItemSubType: 'Kayak' }` — exactly the dropped property. (Local DB is a copy; QA repro on test confirms the same config shape.)
- Serialization side effect checked: the only place condition objects are serialized is `MissionTask.ClientTrackedConditions` → `ConfigJson` of `MissionTaskTrackedOnClient`; it serializes `ClientCondition.ConfigCondition`, which is populated solely via the typed `AssembleRodCondition` JsonProperty setter (`ClientConditions.cs`) — boat conditions cannot reach the client payload. Mission task configs are deserialize-only server-side (grep: MissionCache load, WebAdmin validation, tests — no SerializeTask exists).
- Client mirror check (diff touches Shared/ObjectModel): client copy `Assets/Photon Server Networking/ObjectModel/Mission/ConditionsGame/` contains only AssembleRodCondition + InventoryCondition — `BoatConditions.cs` is not source-duplicated to the client; boat conditions are server-only. No mirror required.
- Per-site audit of `ConditionsGame/*.cs` (script: public auto-properties without `[JsonProperty]` inside OptIn classes): single candidate `BaseFishCondition.Achieved` — verified intentional runtime counter (`IMissionCounter`/`IMissionResourceSingleValue.ResetValue`), not a config field. No sibling defects. (Script limitation: auto-properties only; computed/multi-line properties not scanned.)
- Tests: `dotnet test` ObjectModel.Tests filter ParseBoatCondition — 2/2 passed (build clean).
- NPN merge content verified: `svn diff -c 16334` on NPN identical to the MFT fix (both files, full transfer).
- Delegated blind hunt #1 (code-reviewer agent) returned: 1 finding (tests never exercise IsRentBoat's effect on `Match` — both Rent branches dead in tests) — re-verified against the diff, confirmed (F-1); 2 unresolved hypotheses (blast radius over existing configs; in-flight progress at deploy) — both closed by data below; clean-list consistent with own recon (sibling classes, serialization paths, client DTOs — agent additionally traced `StartedMission` flat progress DTO and `MissionClientUtils.ConvertToMissionOnClient`, confirming conditions never leave the server).
- Blast radius closed via local Main DB scan of `MissionTasks.ConfigJson` (boat conditions + ItemSubType/IsRentBoat): all historical content uses the array form `ItemSubTypes: [...]` (unaffected by the fix); scalar `ItemSubType` appears only in tasks 15857/15858 (both `Anniversary24_AmazonianMaze` — the fix's intent) and 14486 (`Thanksgiving_TruePilgrim`: `ItemId: 30521, ItemSubType: 'Kayak'` — item 30521 has CategoryId 98 = Kayak per `InventoryItems`, so the newly-active subtype filter is consistent with the already-working ItemId filter; no behavior change, and no false completions happened while it was live since ItemId already constrained it). `IsRentBoat` appears in no config. Scope caveat: local DB is a single-platform copy; mission content is shared cross-platform, full prod sweep not performed.
- In-flight/stale-progress hypothesis closed: FPA (2026.5 Anniversary) not yet released — Anniversary missions are not live on prod, false completions exist only on the QA test environment; server deploy restarts rebuild MissionCache.
- Delegated blind hunt #2 (Codex, gpt-5.6-sol) returned: 2 findings (WebAdmin accepts silently-ignored config keys — re-verified, promoted to F-2; test-coverage gaps — merged into F-1 with extra detail), 4 hypotheses. Hypothesis "empty arrays are wildcards used as match-none" — closed by the same DB scan (no empty arrays in any boat-condition config). Hypothesis "Fishing Together guest boat lacks host's RentProps, so IsRentBoat semantics on guest boats unverified" — left explicitly UNRESOLVED: instrument would be a runtime/product test of guest boarding; not run; static trace (Codex: `GameClientPeer.GetBoat` resolves guest boat from item cache, no RentProps propagation path found) is not conclusive for runtime behavior; impact today is nil since no config uses `IsRentBoat` (DB scan). Not used to support any finding. Hypothesis "out-of-repo serializers may observe the expanded contract" — unobservable from this repo; all in-repo serialization paths traced clean by three independent passes (recon, agent, Codex).
- F-2 verification: Read `MissionsSerializationUtils.DeserializeTask` (settings: NullValueHandling.Ignore + TypeNameHandling.Auto, no MissingMemberHandling.Error — unknown members silently dropped), `JsonKeyValidator.AreAllKeysValid` (regex `^[@$A-Za-z0-9_]+$` on key names only — no contract-membership check), `MissionTasksModel.PreprocessJson` (parses for validation, returns `"{}"`, original text is what gets stored). All three links confirmed by direct file inspection.

## Findings

### F-1: Added tests do not exercise IsRentBoat's effect on Match [Low]

**Description:** The new tests in `MissionsTest.cs` prove `IsRentBoat` deserializes (would catch a regression of the original silent-drop bug) but never verify `ConditionExtensions.Match` enforces it: every test `InventoryItem` leaves `Rent` null while the condition has `IsRentBoat: false`, so both Rent branches of `Match` are inactive in all assertions. A regression that breaks the Rent enforcement logic would pass the suite. Secondary gaps (Codex): `ParseBoatConditionSubTypeList` covers the array form that already worked pre-fix (regression guard, not a fix test); the `BoardCondition.Check` event path from the bug report is not exercised.

**Investigation:**
- Recon: noted while reading the r16333 diff that no test constructs an `InventoryItem` with non-null `Rent`.
- code-reviewer agent (blind) independently reported the same; Codex (blind) likewise, adding the secondary gaps.
- Re-verified against the diff text: `ParseBoatConditionFilters` asserts `AreEqual(false, condition.IsRentBoat)` (deserialization proof) and three `Match` calls with `Rent`-less boats — with `IsRentBoat == false` and `boat.Rent == null`, neither `Match` Rent branch affects the outcome. Confirmed.
- Mitigating context: local Main DB scan shows no config uses `IsRentBoat` at all — the untested enforcement path has no live consumers today.

**Resolution:** Resolved → r16353 — reviewer added `ParseBoatConditionRentFilter` (full 2×2 rented/owned × IsRentBoat matrix, each assert decided by exactly one Rent branch of `Match`); merged to NPN @ r16354; 3/3 ParseBoatCondition tests pass.

**Discovered by:** skill recon + code-reviewer agent + Codex (independently).

### F-2: WebAdmin mission-config validation cannot catch silently-ignored keys — the failure class behind FP-45032 [Medium]

**Description:** The WebAdmin save path for mission tasks (`MissionTasksModel.PreprocessJson` → `ParseTask` → `MissionsSerializationUtils.DeserializeTask` + `JsonKeyValidator.AreAllKeysValid`) validates only parse-ability and key-name characters. `DeserializeTask` runs without `MissingMemberHandling.Error`, `JsonKeyValidator` checks key spelling against `^[@$A-Za-z0-9_]+$` only, and the stored value is the submitted raw JSON (validation returns `"{}"`). A typo (`ItemSubTypo: 'Kayak'`) or any future property lacking `[JsonProperty]` in an OptIn condition class saves cleanly and silently produces an unfiltered condition — exactly how the FP-45032 config defect reached runtime undetected. Pre-existing tooling gap, not introduced by r16333.

**Investigation:**
- Codex (blind hunt) raised it; re-verified each link by direct file inspection: `DeserializeTask` settings (`MissionsSerializationUtils.cs`) — NullValueHandling.Ignore + TypeNameHandling.Auto, no MissingMemberHandling; `JsonKeyValidator.cs` — regex on key names only, no contract check; `MissionTasksModel.PreprocessJson` — parses, discards, returns `"{}"`; original JSON text persists.
- Note: naive `MissingMemberHandling.Error` may not be directly applicable — mission JSON legitimately carries preprocessor constructs (`@resources`, predicate strings, hint objects); a contract-aware validation would need to run post-preprocessing. Recorded as design consideration for the follow-up, not explored further in this review.

**Resolution:** Pre-existing → recorded in `<kb>/fishing-planet/server/modules/missions/backlog.md` (Config Validation) citing this review.

**Discovered by:** Codex.

## Notes

- Executor field (customfield_11224) was empty at intake; filled (Yuriy Burda) by close time — no action needed.
- Release-step field (customfield_11323) empty and correctly so: code-only diff derives no release-checklist options.

## Verdict

**approve**

- Root cause fully verified end-to-end: `MemberSerialization.OptIn` silently dropped un-annotated `ItemSubType`/`IsRentBoat` during config deserialization; task 15857 config uses exactly the dropped scalar form; null filters pass any boat in `Match`. Not symptom-level — mechanism, data, and regression tests all line up.
- Fix is minimal and complete: base-class annotation covers all four `BaseBoatCondition` descendants; three independent passes (recon, code-reviewer agent, Codex) found no sibling condition class with the same defect shape.
- No side effects: condition objects never leave the server (client DTOs carry no conditions; the only condition-serializing path is AssembleRodCondition-only); `BoatConditions.cs` is not source-duplicated to the client — no mirror needed.
- Blast radius over existing content: nil — all historical configs use the always-working array form; the two other scalar-form configs are consistent with the fix's intent (15858) or already item-constrained (14486); `IsRentBoat` unused in content.
- F-1 (Rent-enforcement test gap) resolved within the review cycle @ r16353 (merged NPN r16354); F-2 (WebAdmin validation gap, pre-existing) routed to missions backlog.
- Merges complete for the release pair: MFT (Content, ships FPA) → NPN (Code) for both the fix and the follow-up test.
