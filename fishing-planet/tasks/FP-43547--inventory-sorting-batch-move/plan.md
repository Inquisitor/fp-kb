# FP-43547 — Implementation Plan

Branch: `MFT20260325` (Code role). Decisions are in [journal.md](journal.md#decisions-resolved-2026-05-13-with-task-assignee).

## Build sequence

### 1. Wire layer

#### 1.1 `Shared/Photon.Interfaces/InventoryOperationCode.cs`

- Place new `MoveItems = 42` next to `MoveItem`/`SubordinateItem`/`SplitItem`/`CombineItem`/`ReplaceItem`
  (semantic group).
- Move the trailing-position arrow comment `// <--------` from `RecolorBuoy = 41` to the new `MoveItems = 42`
  line, same form.

#### 1.2 `Shared/Photon.Interfaces/Inventory/InventoryParameterCode.cs`

- Append `ItemIds = 19` and `MoveResults = 20` after `ItemColor = 18`. No arrow (sequential, no semantic
  grouping in this enum).

#### 1.3 `Shared/Photon.Interfaces/InventoryErrorCode.cs`

- Append `ItemNotFound = 89` at the tail. Move the trailing arrow `// <-----------------------` from
  `NoMorePlaceToEquip = 88` to `ItemNotFound = 89`, same form.

### 2. Domain — pre-flight check

#### 2.1 `Shared/ObjectModel/Inventory/Inventory_Can.cs`

Add a batch overload:

```csharp
public Dictionary<Guid, InventoryErrorCode> CanMove(
    IReadOnlyList<InventoryItem> items,
    StoragePlaces storage,
    bool checkCapacity = true)
```

Algorithm (greedy):

1. Build result dict pre-filled with `Ok` per `item.InstanceId`.
2. For each item, run the existing single-item `CanMove(item, parent: null, storage, checkCapacity: false)` —
   note we suppress its built-in capacity check; aggregate capacity is handled in step 3. Record the
   error code into the dict if the call failed.
3. If `checkCapacity == true`, walk items in input order tracking a running `freeSlots` counter (initialized
   from current state of the target storage). An item consumes a slot only when:
   - The op resolves to a pure move (not combine — call `CheckMoveIsCombine(item, parent: null, storage)`),
   - AND `item.IsOccupyInventorySpace`,
   - AND the item is currently in a different storage (i.e. the move actually adds load to the target).

   When `freeSlots` hits zero, every subsequent slot-consuming item gets `CantMoveIntoOverloadedStorage`
   in the dict.
4. Return the dict. Items with `Ok` would succeed; non-`Ok` would fail with the captured reason.

Notes:
- Do not flip the existing `Error`/`ErrorDetails` fields based on batch outcome — those remain bound to the
  single-item API to keep `LastVerificationError` behavior stable for legacy callers.
- The new method must be deterministic in item order — iteration order from caller (`IReadOnlyList`) is
  preserved.

### 3. Domain — action

#### 3.1 `Shared/ObjectModel/Inventory/Inventory_Does.cs`

Add a batch method:

```csharp
public Dictionary<Guid, InventoryErrorCode> MoveOrCombineItems(
    IReadOnlyList<InventoryItem> items,
    StoragePlaces storage,
    bool moveRelatedItems = true)
```

Algorithm:

1. Result dict keyed by `item.InstanceId`, default `Ok`.
2. For each item: call the existing single-item `MoveOrCombineItem(item, parent: null, storage, moveRelatedItems)`.
   - On success: leave dict entry at `Ok`. The internal `InventoryChanges` pipeline accumulates the Add/Del/Upd
     diff as today.
   - On thrown/rejected move: capture `Error` from the inventory state and write it into the dict.
3. Return the dict.

No new event/log surfaces — existing per-move side effects fire per call.

### 4. Server handler

#### 4.1 `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Inventory.cs`

- Add `case InventoryOperationCode.MoveItems: MoveInventoryItems(request); break;` in the switch.
- New `private void MoveInventoryItems(OperationRequest request)`:
  - Read `(byte)InventoryParameterCode.ItemIds` → string array. For each raw id:
    - Parse `Guid`. On parse failure: log
      `"!INVENTORY-UNSYNC! Batch MoveItems: malformed instance id[[ raw: " + raw + "]]"`
      via `DalFactory.GetLogger().Inventory.Log(UserId, ...)` and skip (no dict entry — we don't have a
      parseable key).
    - Resolve via `profile.Inventory.GetItem(guid)`. If null: log
      `"!INVENTORY-UNSYNC! Batch MoveItems: non-existent item requested[[ instance id: " + guid + "]]"`
      and write `results[guid] = InventoryErrorCode.ItemNotFound`. Skip.
    - Otherwise add to `resolvedItems`.
  - Read `storage` (Equipment or Storage only -- reject otherwise). No `parent` on the wire; the batch is
    scoped to Backpack/Home Storage moves.
  - Call `profile.Inventory.MoveOrCombineItems(resolvedItems, ...)`; merge its result dict into `results`
    (so `ItemNotFound` entries survive).
  - Build response: existing `InventoryChanges` flushed under `(byte)InventoryParameterCode.Changes`
    (same pipeline as `MoveItem`); add `(byte)InventoryParameterCode.MoveResults` = compressed-JSON
    serialization of `results` (mirror the `CompressHelper`/`SerializationHelper.JsonSerializerSettings`
    pair used for `Changes`).

**Logging convention**: stable prefix `!INVENTORY-UNSYNC!` is the grouping key for log aggregation; dynamic
data (raw ids, guids, indices) goes inside `[[ ... ]]` so it doesn't fragment the bucket. Reference: existing
`PerformanceAdapter.cs` "LongRequest" messages, `ProfileAdapter.cs` "Can't save profile" messages.

### 5. Client-side response routing + manual-test call site (owned by us this round)

**Pre-step — DLL/source distribution to client:**

- Build `Shared/Photon.Interfaces` in Release on MFT, then run `Shared/Photon.Interfaces/Refresh.cmd`. The script
  copies `bin/Release/Photon.Interfaces.dll` to `%SvnClient%/Assets/Plugins/PhotonServer/`. This is how the new
  enum values (`OC.MoveItems`, `ParameterCode.ItemIds`, `ParameterCode.MoveResults`, `InventoryErrorCode.ItemNotFound`)
  reach the client. Commit the updated DLL into the client SVN as part of the client edit.
- `ObjectModel` is **not** distributed as a DLL — its source is duplicated into the client tree (with sensitive
  parts like anti-cheat stripped). The new batch `CanMove(items, …)` overload must be mirrored manually into
  the client copy of `ObjectModel/Inventory/Inventory.cs` (in `Assets/Photon Server Networking/ObjectModel/Inventory/`)
  so client-side pre-flight before sending matches the server's check. `MoveOrCombineItems` is server-only — no
  client mirror.

**Then in `Win64_CodeBranch`:**

- `PhotonServerConnection_Inventory.HandleInventoryOperationResponse` — add `OC.MoveItems` to the
  `suppressInventoryMove` predicate AND the same `case` block as `OC.MoveItem` so the `Changes` patch applies
  identically. **In the same place**: deserialize the new `(byte)InventoryParameterCode.MoveResults` parameter
  (compressed JSON → `Dictionary<Guid, InventoryErrorCode>`) and raise a new
  `event Action<Dictionary<Guid, InventoryErrorCode>> OnInventoryMoveBatchResult` so the UI can show per-item
  outcomes in the V02 modal. We own this — we're already in the file and parsing is one line away from the
  routing entry; splitting the work would just create a coordination tax for Sergii.
- Wire a call site so we can manually exercise the new operation through the UI. The `InventorySRIA.Move(...)`
  method already has the marked TODO at the
  `// <-- call server move <-- ` allItems`` comment (`InventorySRIA.cs:1404`); replace it with a call to a new
  `PhotonConnectionFactory.Instance.MoveItemsOrCombine(allItems, ...)` facade — i.e. the batch sibling of
  `MoveItemOrCombine` in `PhotonServerConnection_InventoryShop.cs`.

### 6. Tests

`Photon/src-server/LoadBalancing.Tests/Inventory/`:

- Add cases to the existing inventory test fixture (look for the place where single-item `MoveItem` and
  `CombineItem` are exercised; mirror the pattern):
  - Happy path: 5 items, all fit, all `Ok`, target storage gains 5 stacks.
  - Partial capacity: 5 items, target has 3 free slots → first 3 `Ok`, last 2 `CantMoveIntoOverloadedStorage`.
  - Mixed reasons: one item rented, one broken, two fit, one overflow → dict reports each distinct reason.
  - Combine interaction: items whose target stack exists in destination → don't consume slots, surface as
    `Ok` regardless of capacity.

Domain-only tests (no Photon op handler) — exercise `MoveOrCombineItems` directly on `Inventory`.

## Open implementation notes

- The client also has its own `ObjectModel.Inventory.CanMove`. Sergii will likely mirror the new batch
  overload on the client to drive the modal pre-flight; we own the server-side mirror but the client copy is
  his responsibility.

## Out of scope

- Confluence V02 items (1) Search and (2) All Items collapse — pure client features.
- New `InventoryErrorCode` values — existing set covers expected failures (capacity, rent, brokenness, equip
  constraints, etc.).
- Localization keys for new modal text (`AllItems`, `QuestionMoveToOk/Warning`, `СollapseExpandAllItems`) —
  already added by client (FP-43492).

## Commit shape (preview)

Single commit on MFT once the four edits land + tests pass:

```
FP-43547: [Inventory] Batch MoveOrCombineItems with per-item result map
+ InventoryOperationCode.MoveItems and InventoryParameterCode.ItemIds/MoveResults
+ Inventory.CanMove(items, ...) returning Dictionary<Guid, InventoryErrorCode>
+ Inventory.MoveOrCombineItems(items, ...) with greedy per-item outcome
+ GameClientPeer_Inventory handler MoveInventoryItems
+ Tests covering happy path, partial capacity, mixed reasons, combine interaction
(Story: Inventory Sorting. UI Server - Implement Additional functional for Subgroup Tab)
https://fishingplanet.atlassian.net/browse/FP-43547
```
