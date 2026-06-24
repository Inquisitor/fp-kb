---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16227, merged to NPN @ r16234
jira: https://fishingplanet.atlassian.net/browse/FP-44331
---

# Review: FP-44331 — [FTUE][Trolling Kayak][Inventory] There is empty parameter in kayakas description

## Summary

Bug: the **Detailing:** parameter in the on-doll item description is empty for trolling Pedal Kayaks (DLC kayak and rented kayak on Lone Star). Expected display is `-`.

Root cause (per executor + Andrii Maslov feedback): `ParamsIsobar` in the item JSON is set to `-`. On other params and other boat types (e.g. Motor Boats) this renders as `-`, but on Pedal Kayaks it produces an empty string because the `ObjectModel.PedalKayak` class did not expose the `ParamsIsobar` property. Fix adds `ParamsIsobar` to `ObjectModel.PedalKayak`.

Kayak IDs in question: 32714, 32750 (Subtype: Pedal Kayaks, CategoryID = 199). Reference motor boat: ID = 2030.

## Scope

- **MFT r16227** — Fixed. Added `ParamsIsobar` to `ObjectModel.PedalKayak`
  - Executor note: client has the same `PedalKayak` class but does not need this param for item description (client parses window params differently); commit is server-branch only; client `ObjectModel.MotorBoat` likewise has no such param

## Investigation Journal

- Intake: executor = Yevhenii Shust (commit author per JIRA comment); JIRA `customfield_11224` (Executor) is empty — flagged, not auto-filled.
- Branch roles at review time: Code = NPN20260602, Content = MFT20260325 (fix lives here). Fix r16227 > NPN copy-source MFT:16130 → NOT inherited via branch copy; explicit Content→Code merge needed (close phase).
- VCS audit: `svn log -r 16130:HEAD` on MFT URL — single commit r16227 references FP-44331. No other commits. WC at r16229 (≥ r16227) → disk reads trustworthy; change present at HEAD, no later revert.
- Mechanism verified (corrected after code-reviewer agent traced the real path): item load `ItemFactory.GetTypedItem` calls `JsonConvert.DeserializeObject(item.ConfigJson, resultType)` with DEFAULT Newtonsoft settings — unknown JSON fields are silently ignored, so `ParamsIsobar: "-"` was dropped at load when the class lacked the property. Outgoing serialization to the client uses settings with `NullValueHandling.Ignore` (`SerializationHelper`), so the absent/null value emits nothing → client shows empty. `JsonConfigContractResolver` is wired ONLY into `JsonConfigSerializerSettings` (config-write path), NOT the item-load path. Implication: the property merely needing to EXIST is what fixes the client display; `[JsonConfig]` matters for the config-write path and is added for parity with `MotorBoat`/sibling props (correct, harmless). Fix is pure code; the `-` value already lives in the item config JSON (per Andrii Maslov feedback) → no data migration / SQL backfill needed. Confirmed: server never re-serializes item `ConfigJson` back to DB from the object model.
- Reference confirmed: `MotorBoat` carries the full param family (`ParamsEchoSounder`, `ParamsGps`, `ParamsIsobar`); `PedalKayak` had the first two, missing `ParamsIsobar`. New prop matches sibling shape exactly (`string`, `[JsonConfig]`, "Shop display info" XML doc).
- Per-site audit (grep `Params(EchoSounder|Gps|Isobar)` across `Shared/ObjectModel`): only `MotorBoat` and `PedalKayak` expose this echo-sounder display family; both now complete. Other boat classes (Kayak, BassBoat, Zodiak, FishingYacht) have no such params → no other class shares the gap.
- Client: VERIFIED in the Content client checkout (`Win64_MainClient/Assets/Photon Server Networking/ObjectModel/Inventory/Boats/`). `ObjectModel` reaches the client by SOURCE DUPLICATION (not DLL), so the client carries its own `ObjectModel.PedalKayak`. Comparison confirms — and strengthens — the executor's claim: client `PedalKayak` has `ParamsEchoSounder`+`ParamsGps` but NOT `ParamsIsobar`; client `MotorBoat` has NONE of the `Params*` display family (server `MotorBoat` has five). The client mirror is already intentionally divergent (also carries a `MaxSpeed` prop the server lacks). These `Params*` are server-produced shop/description strings (`InventoryParamProducer.ProduceParamsForItem` via reflection on the SERVER model) shipped to the client as finished text; the doll "Detailing:" is server output. So the client copy does not need `ParamsIsobar`, and the server-only commit is consistent with the existing pattern. Residual (non-blocking, executor's domain): if a client-side window reads "Detailing" from the client model it would be uncovered, but executor states the client parses window params differently and does not need this one.
- Independent code-reviewer agent: confirmed fix correct/sufficient, reference parity exact, per-site audit clean, no side effects, no migration. Refined the serialization mechanism (see above). Raised one non-blocking observation (test coverage, F-1).
- Codex (GPT-5, read-only second opinion): converged on the same verdict and pinned the exact display mechanism — `InventoryParamProducer.ProduceParamsForItem` (`Shared/SharedLib/Shop/InventoryParamProducer.cs`) substitutes template placeholders by REFLECTION via `SerializationHelper.GetPropertyValue`; `{ParamsIsobar}` resolved to missing/null → empty before the fix, now `-`. So the property must EXIST on the class for the reflection lookup; `[JsonConfig]` is not on the display path (confirmed independently). Additional verified points:
  - Operational: fix takes effect only after `ItemCache` reload (process restart / cache refresh); already-sent client responses stay stale until re-requested.
  - Existing owned/profile pedal kayaks are fine after cache reload — `ProfileHelper.TranslateItemsAndFillConfigProperties` clones definition fields from `ItemCache` via `MakeCloneOfItem`, and `ParamsIsobar` is not `[NoClone]`.
  - Audit-scope limit: the grep-based per-site audit covers the echo-sounder param family; the broader "ConfigJson has a key but the model lacks the property" class can only be exhaustively caught by `Photon/tools/ReleaseTool/.../InventoryItemParamsParser.cs::GenerateClassProperties` run against the live DB. Out of scope for this single-bug review.

## Findings

### F-1: No regression test for the missing-subclass-property bug class [Low]

**Description:** The fix has no unit test asserting that a `PedalKayak` `ConfigJson` carrying `"ParamsIsobar": "-"` deserializes to a `PedalKayak` with `ParamsIsobar == "-"`. The "property missing on a subclass silently drops a config value" failure mode would be caught immediately by such a round-trip test. Process gap, not a behavioral defect.

**Investigation:** Raised by the independent code-reviewer agent; existing `PedalKayak` coverage (`UgcTest.cs`) tests only tournament equip-allow logic, not item property deserialization. Adding a dedicated test per `[JsonConfig]` property is not the team's established pattern, and the fix is a one-property addition matching a working sibling.

**Resolution:** Skipped — too minor to block; not the team convention to test each property addition.

**Discovered by:** code-reviewer agent

### F-2: JIRA Executor field empty [Info]

**Description:** `customfield_11224` (Executor) was empty on FP-44331 at intake; expected value is the commit author, Yevhenii Shust.

**Investigation:** File/JIRA inspection only. Detect-only per skill; not auto-filled. Re-fetched at close — field now filled (Yevhenii Shust).

**Resolution:** Skipped — resolved organically (field populated before close).

**Discovered by:** skill recon

### F-3: ObjectModel client mirror not updated — verified inert, not a defect here [Info]

**Description:** Reviewer raised whether the source-duplication mirror rule (`<kb>/reference/photon_interfaces_dll_distribution.md`) requires mirroring `ParamsIsobar` into the client `ObjectModel.PedalKayak`, and whether skipping it warrants reopen.

**Investigation:** Verified in the Content client checkout: (a) the mirror rule is scoped to "combinatorial / non-sensitive *logic* / shared behavior", not plain data fields; (b) client `MotorBoat` already omits ALL five server `Params*` fields → mirroring these is established non-practice; (c) decisive — grep of the whole client `.cs` tree shows NO consumer of `ParamsIsobar`/`ParamsEchoSounder`/`ParamsGps`, and the client has no template-reflection param producer, so "Detailing:" is a server-produced string. Mirroring would be dead code and change no behavior; the server-only fix resolves the bug end-to-end.

**Resolution:** Accepted (no reopen). Broader concern about the manual ObjectModel mirroring model filed → `fishing-planet/server/backlog.md`.

**Discovered by:** reviewer (Stanislav)

## Verdict

**APPROVE.** The fix is correct, minimal, and matches the working `MotorBoat` reference exactly. Root cause confirmed (default-Newtonsoft load silently drops a JSON field with no matching class property). No data migration needed — the `-` value already lives in the item config JSON. Per-site audit clean — no other class shares the gap. Only non-blocking notes (F-1 test coverage, F-2 JIRA hygiene).

**Cross-branch merge:** done — r16227 (MFT, Content) merged to Code NPN20260602 @ r16234 (not inherited via branch copy; MFT:16130 < r16227, verified). Release-step field `customfield_11323`: n/a (diff is a single C# property add — no SQL/NoSql/service/env-var/AB-test/profile-conversion artifacts).

**Deploy/verify note:** takes effect only after `ItemCache` reload (process restart / cache refresh); no DB migration needed (value already in `ConfigJson`).
