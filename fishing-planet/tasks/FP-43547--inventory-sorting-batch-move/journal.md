---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43547
related:
  - FP-43492  # client side, Sergii Karchavets (On Hold, waiting for server)
  - FP-41865  # previous iteration "Inventory Sorting. UI - Additional functional for Subgroup Tab" (Closed)
confluence: https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5302550529/Inventory+Sorting+Improvement+V02
---

# FP-43547: Inventory Sorting V02 — Server side for batch "Move to" subcategory

## Status

Complete. Server committed at r16093 (feature) + r16094 (helpers refactor) on MFT. Client committed at
r54197 on CodeBranch. JIRA comment posted (id 119835) notifying Sergii Karchavets (original requester)
and requesting client-side review from Kyrylo Rovnyi.

## Summary

### Goal

Support client's "Move to" button in the V02 Subgroup Tab UI: move an entire subcategory between Backpack
(`StoragePlaces.Equipment`) and Home Storage (`StoragePlaces.Storage`) in a single Photon round-trip, with
per-instance success/failure feedback for the client modal.

### Source / dependencies

- Spec: Confluence "Inventory Sorting Improvement V02" (page id `5302550529`), item (3) "Переніс між Рюкзаком
  і Домашнім сховищем підкатегорії".
- Client-side counterpart: FP-43492 (On Hold). Sergii Karchavets already committed UI scaffolding
  (r53555/r53733/r53738 in Code-client) and posted the API ask in the FP-43547 comment thread:
  > Need `PhotonConnectionFactory.Instance.MoveItemsOrCombine(items, parent, storage, moveRelatedItems)` +
  > batch `CanMove` returning per-instance reason instead of plain `bool`.
- Out of scope (pure client): Search field (Confluence item 1), All Items collapse/expand (item 2).

### Design

Three layers, mirroring the existing single-item `MoveItem` path:

1. **Domain (`Shared/ObjectModel/Inventory/`)**
   - `Inventory_Can.CanMove(IReadOnlyList<InventoryItem> items, InventoryItem parent, StoragePlaces storage,
     bool checkCapacity = true)` → `Dictionary<Guid, InventoryErrorCode>`.
     - Per-item delegates to existing single-item `CanMove` for non-capacity reasons (rent/broken/equip
       constraints/etc.). Result map keyed by `item.InstanceId`; `Ok` means «would succeed».
     - **Aggregate capacity (explicit, greedy)**: existing `CheckStorageCapacity` is binary on `IsStorageFull`
       — non-aware of "this batch consumes N slots". So we compute `freeSlots` against the target storage and,
       walking items in enumeration order, mark items beyond the available slot count with
       `CantMoveIntoOverloadedStorage`. Items that are combines (target stack found) or non-occupying
       (`!IsOccupyInventorySpace`) don't consume a slot in the count.
   - `Inventory_Does.MoveOrCombineItems(IReadOnlyList<InventoryItem> items, InventoryItem parent,
     StoragePlaces storage, bool moveRelatedItems = true)` → `Dictionary<Guid, InventoryErrorCode>` (per-instance
     outcome; `Ok` for moved items, error code for skipped ones).
     - **Greedy by construction.** Process items one by one via existing `MoveOrCombineItem`. As the target
       storage fills, the next call's single-item `CheckStorageCapacity` flips and the item gets
       `CantMoveIntoOverloadedStorage` in the dict. Combine-target items continue passing.
     - Existing inventory-changes pipeline (`InventoryChanges` Add/Del/Upd) collects the diff transparently
       across all per-item moves — no new code path required for the response patch.

2. **Photon wire (`Shared/Photon.Interfaces/`)**
   - `InventoryOperationCode.MoveItems = 42` — placed semantically next to `MoveItem/SplitItem/CombineItem`
     group, so the numeric value is out-of-sequence in that section → arrow `// <--------` moves from
     `RecolorBuoy = 41` to the new `MoveItems = 42`.
   - New `InventoryParameterCode.ItemIds = 19` and `MoveResults = 20` — appended in numeric order at the end of
     the enum. No semantic grouping and no out-of-sequence placement, so no arrow needed.

3. **Server handler (`Photon/.../GameServer/GameClientPeer_Inventory.cs`)**
   - New `case InventoryOperationCode.MoveItems: MoveInventoryItems(request); break;` in the `switch`.
   - New `private void MoveInventoryItems(OperationRequest request)`:
     - Parse `ItemIds`, parent, storage, `moveRelatedItems`.
     - Call `MoveOrCombineItems`; existing `InventoryChanges` patch pipeline produces the `Changes` parameter.
     - Attach `MoveResults` parameter to the response (always — even when all `Ok`).

### Client expectations (FP-43492, for context — done by Sergii)

- `PhotonServerConnection_InventoryShop.MoveItemsOrCombine(items, parent, storage, moveRelatedItems)`.
- `HandleInventoryOperationResponse` switch entry for `OC.MoveItems` — apply `Changes` as today, optionally
  raise a `OnInventoryMoveBatchResult(Dictionary<Guid, InventoryErrorCode>)` event.
- Sergii has stated: "minimum viable is just receive the inventory update" → fallback path if we ship without
  the dictionary still works.

### Decisions (resolved 2026-05-13 with task assignee)

| # | Question                                             | Resolution                                                                                                                                                                                                                                                                                                                                          |
|---|------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 1 | Wire format for batch IDs                            | New `InventoryParameterCode.ItemIds` (own code; byte space ample)                                                                                                                                                                                                                                                                                   |
| 2 | Capacity failure granularity                         | **Greedy**: fit as many as possible; overflow tail gets `CantMoveIntoOverloadedStorage`. Per-item dict is the entire point — strict-fail would defeat it                                                                                                                                                                                            |
| 3 | `MoveResults` payload                                | Compressed JSON `Dictionary<Guid, InventoryErrorCode>`, same shape/path as `Changes`                                                                                                                                                                                                                                                                |
| 4 | Send `MoveResults` always or only on partial-failure | **Always.** Simpler client contract, payload is tiny                                                                                                                                                                                                                                                                                                |
| 5 | Arrow law                                            | Move `// <--------` from `RecolorBuoy = 41` to new `MoveItems = 42` in `InventoryOperationCode` (group placement, out-of-sequence value). `InventoryParameterCode` is sequentially-ordered without semantic groups, so no arrow there for the new codes                                                                                             |
| 6 | Unresolved `InstanceId` from client                  | New `InventoryErrorCode.ItemNotFound` value (tail of enum, move `// <-----------------------` from `NoMorePlaceToEquip = 88` to it). Server logs an `!INVENTORY-UNSYNC!` line for each miss via `DalFactory.GetLogger().Inventory.Log` with `[[ ... ]]` wrapping the dynamic instance id. Per-item entry in `MoveResults` dict carries the new code |
| 7 | Client-side opcode routing                           | We commit both — server (this task) and the small client edit in `Win64_CodeBranch` to wire `OC.MoveItems` into `HandleInventoryOperationResponse` and add a call-site for manual testing. Coordinated with Sergii via JIRA comment                                                                                                                 |

### Plan

See [plan.md](plan.md).

## Milestones

- 2026-05-13: Task opened. Spec and client comment read; client call-sites surveyed; server entry points
  located (`Inventory_Does.MoveOrCombineItem`, `Inventory_Can.CanMove`, `GameClientPeer_Inventory.MoveInventoryItem`).
- 2026-05-13: Step 1 (wire layer) done — added `InventoryOperationCode.MoveItems = 42` (arrow moved from
  `RecolorBuoy`), `InventoryParameterCode.ItemIds = 19` and `MoveResults = 20`, `InventoryErrorCode.ItemNotFound = 89`
  (arrow moved from `NoMorePlaceToEquip`).
- 2026-05-13: Step 2 (domain pre-flight) done — added `Inventory.CanMove(IReadOnlyList<InventoryItem>, …)`
  overload in `Inventory_Can.cs`. Two-pass: per-item delegates to existing single-item `CanMove`; aggregate
  Home-Storage slot pass marks overflow tail with `CantMoveIntoOverloadedStorage` (combine targets and
  non-occupying items don't consume slots). Equipment-side per-subtype limits remain handled by the
  existing `IsBreakingEquipmentConstraints` path inside per-item calls.
- 2026-05-13: Step 3 (domain action) done — added `Inventory.MoveOrCombineItems(IReadOnlyList<InventoryItem>, …)`
  overload in `Inventory_Does.cs`. Greedy: per-item `CanMove` against running state, then `MoveOrCombineItem`
  on success. Failures (including overflow once destination fills mid-loop) land in the per-instance dict.
  Added `using Photon.Interfaces` to file for `InventoryErrorCode` access.
- 2026-05-13: Step 4 (server handler) done — added `case InventoryOperationCode.MoveItems` and the
  `MoveInventoryItems(OperationRequest, OperationResponse)` method in `GameClientPeer_Inventory.cs`. Parses
  `ItemIds`, resolves each GUID, logs `!INVENTORY-UNSYNC!` for malformed/missing items with the `[[ ... ]]`
  grouping convention, calls batch domain method under `transactionLock`, attaches `MoveResults` (compressed
  JSON `Dictionary<Guid, InventoryErrorCode>` via `InventoryTracking.Serialize`) to the response. `Changes`
  parameter is auto-populated by the existing `SendOperationResponse` → `Profile.PopulateParameters` path.
- 2026-05-13: Step 5 (tests) done — added `Shared/ObjectModel.Tests/InventoryBatchMoveTests.cs`. Covers
  happy-path batch `CanMove`, greedy storage-overflow in pre-flight `CanMove`, greedy action
  `MoveOrCombineItems` (only fitting items physically move), and mixed reasons (Ok + CantModifyRentedItem).
  Domain-only tests, `[TestCategory("Unit")]`, mirroring the `InventoryExtensionsTests` fixture pattern.
- 2026-05-13: Documentation pass — added XML `<summary>`/`<param>`/`<returns>`/`<remarks>` on both new
  domain methods, header block comment on the server handler explaining the two failure layers and the
  auto-populated `Changes` parameter, class-level XML summary on the test fixture, and inline comments at
  non-obvious decision points (greedy capacity passes, shared `Error` reset, dict merge).
- 2026-05-13: ASCII cleanup — replaced Unicode em-dashes and arrows with ASCII (`--`, `->`) across all
  modified source files. Promoted the rule to [ascii_only_in_code](../../../feedback/ascii_only_in_code.md);
  KB pages are exempt (they're prose, and example tables need to show Unicode characters to be useful).
- 2026-05-13: Step 6 (client edits) done in `Win64_CodeBranch`. Mirrored the batch `CanMove(items, ...)`
  overload into client `ObjectModel/Inventory/Inventory.cs`. Added `MoveItemsOrCombine` facade and a new
  `OnInventoryMoveBatchResult` event in `PhotonServerConnection_InventoryShop.cs`. Wired `OC.MoveItems`
  routing in `PhotonServerConnection_Inventory.HandleInventoryOperationResponse` (suppression + case +
  `MoveResults` deserialization + event raise). Replaced the `// <-- call server move` TODO in
  `InventorySRIA.Move` with a call to the new facade. Required `using Photon.Interfaces;` added to
  `PhotonServerConnection_Inventory.cs` for `InventoryErrorCode` access. Also added `MoveItemsOrCombine`
  method and `OnInventoryMoveBatchResult` event declarations to `IPhotonServerConnection` interface (the
  factory exposes the interface type, not the concrete class). ASCII-clean.
- 2026-05-13: Dropped vestigial `parent` parameter from the batch API across all 7 touch points (domain
  `CanMove`/`MoveOrCombineItems`, server handler, client mirror, client facade, interface, call-site,
  tests). The batch is V02-scoped to Backpack/Home Storage moves where parent is always null;
  subordinate moves remain single-item only. Underlying single-item calls keep getting `null` as parent.
  Tests and plan.md updated for the new signatures.
- 2026-05-13: Post-review hardening pass (4 findings from deep review acknowledged):
  - Added `Photon.Interfaces.MoveResults : Dictionary<Guid, InventoryErrorCode>` (new file, distributed
    via Photon.Interfaces.dll). Replaced raw `Dictionary<...>` with `MoveResults` on both server and
    client domain/handler/event signatures. Delegate `InventoryMoveBatchResultHandler` declared
    client-side in `PhotonMessage.cs` next to other inventory delegates -- it's only the type of a
    client-only event, server doesn't reference it.
  - Added hard-validate of destination in batch `CanMove`, `MoveOrCombineItems`, and client facade
    `MoveItemsOrCombine`: throws `ArgumentException` for anything other than Equipment/Storage.
  - Implemented Pass 2 for Equipment destination (per-`ItemSubTypes` running counter against
    `EquipConstraintsCache` + `GetCurrentItemsCount`). Overflow tail marked with `NoMorePlaceToEquip`
    (the correct code -- previously the review confused it with `EquipmentRulesBreached`).
  - Extracted `ConsumesDestinationSlot` helper for the predicate shared by both Pass 2 branches.
  - Tests: added `BatchCanMove_EquipmentOverflow_TailGetsNoMorePlaceToEquip` (Hook basic
    `TerminalTackleCount = 10`, pre-fill 8, queue 5, expect 2 Ok + 3 NoMorePlaceToEquip);
    `BatchCanMove_RejectsNonInventoryDestination` and `BatchMove_RejectsNonInventoryDestination`
    (covers Doll/ParentItem/Hands rejection).
  - Promoted `<kb>/feedback/new_csharp_file_bom.md` (Write tool doesn't add BOM; .editorconfig mandates).
- 2026-05-13: Post-review live-test bugs caught and fixed: (a) `CanMove(items, ...)` was resetting the shared
  `Error` field at exit, which killed `LastVerificationError` for the facade -- facade now reads the reason
  from the result dict directly; (b) Pass 2 Equipment branch missed the subtype fallback that
  `IsBreakingConstraints` performs, so `SimpleHook` (or any granular subtype) looked up as missing key and
  marked everything `NoMorePlaceToEquip`; fixed to fall back to `ToSubtype(item.ItemType)`; (c) Pass 2
  keyed its counter by `ItemSubType`, but post-`CloneConstraints` each cache entry is an independent
  clone, so shared pools (terminal tackle) would have separate counters per subtype -- switched key to
  constraint reference (correct for the V02 single-subtype contract; noted limitation for mixed-subtype
  batches in XML doc); (d) `EquipConstraintsCache` is a property on server but a method on client --
  client mirror needed parentheses.
- 2026-05-13: V02 references purged from code comments; replaced with descriptive language pointing at the
  inventory UI's "Move to" button. Added combine-target test (`BatchCanMove_CombineTargetsDoNotConsumeSlots`).
  Hardened GUID parsing in handler with `Guid.TryParse` (was `new Guid(raw)` which threw on null).
  `OnInventoryMoved` firing alongside `OnInventoryMoveBatchResult` is intentional and verified safe in live
  smoke-test -- existing subscribers (UI refresh, etc.) still get notified once per batch response.
- 2026-05-13: Two-track deep review (code + docs) pass. Applied findings:
  - Code: added `UpdateFishCage`/`UpdateBoatColorInMissionsContext`/`UpdateActorDataInventoryItems` calls
    in batch handler after `MoveOrCombineItems` (mirroring single-item pattern; each helper early-returns
    on non-matching item types). Added test `BatchCanMove_Pass1FailureNotOverwrittenByCapacityPass` for
    the missing branch where a rented item must not get its `CantModifyRentedItem` downgraded to
    `CantMoveIntoOverloadedStorage` by Pass 2.
  - Docs: fixed factually-wrong inline claim ("subtypes sharing a pool draw from the same bucket" -- post
    CloneConstraints they don't) in both server and client Pass 2 Equipment block. Unified `<returns>`
    wording between server and client batch `CanMove`. Trimmed `MoveOrCombineItems` `<returns>` of
    redundant parenthetical about internal `Error` field. Clarified `OnInventoryMoveBatchResult` event
    docs (server + client + interface) that "skipped" includes `ItemNotFound`. Added wire-format pointer
    (gzip+JSON via `InventoryTracking.Serialize`/`CompressHelper.DecompressString`) to `MoveResults`
    remarks.
  - Pre-existing UI bug in `InventorySRIA.Move` Storage free-slot count (uses raw `Count(x => x.Storage
    == Storage)` instead of `AvailableInventoryCapacity`, missing `IsOccupyInventorySpace` filter) added
    to deferred backlog -- adjacent to V02 but not introduced by this task.
- 2026-05-16: Final polish round. Pattern-match refactor (`is not { } itemInstanceId`) replacing `!.Value`
  in production code; renamed all batch-loop locals to `itemInstanceId` for consistency. Extracted Pass 2
  predicate as local function `ConsumesSlot` inside batch `CanMove` (was private method). Switched server
  handler to `SharedLib.Helpers` parameter helpers (`GetParameterEnum`, `TryGetValue<string[]>`,
  `SetParameterJsonCompressed`); client handler uses `GetParameterJsonCompressed`. Brace style aligned
  with server `.editorconfig` on both sides. ASCII cleanup pass.
- 2026-05-16: Shipped. r16093 (MFT, feature) + r16094 (MFT, helpers refactor polish) + r54197
  (CodeBranch, client). JIRA comment 119835 posted with @-mentions for Sergii Karchavets (original
  requester, can resume FP-43492) and Kyrylo Rovnyi (client-side review request). User transitions JIRA
  state separately.
