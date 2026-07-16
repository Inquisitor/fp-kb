---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16299, merged to MFT20260325 @ r16328
jira: https://fishingplanet.atlassian.net/browse/FP-41925
---

# Review: FP-41925 — UI Re-design. Client - Put Hats to Backpack

## Summary

Allow `Hat` items to be stored in the backpack (`Equipment`), occupying Misc slots the same way `Glasses` do. Since hats carry backpack-expansion slots, swapping/unequipping the worn hat changes tackle capacity: on a pond, the swap/unequip is blocked when the reduced capacity cannot hold the currently equipped tackle (new error codes `CantReplaceNotEnoughEquipmentCapacity` / `CantUnequipNotEnoughEquipmentCapacity`); on the globe the existing flow is unchanged (excess spills to home `Storage`). Client mirrors the constraint and message wiring; localization for the two new message keys requested from GD.

## Scope

### NPN20260602
- **r16299** — Store Hat in backpack; guard pond hat swap/unequip against tackle overflow
  - Hat storable in `Equipment` (backpack) on a Misc slot, mirroring `Glasses`
  - Blocks swapping/unequipping the worn hat on a pond when reduced tackle capacity can't hold the equipped tackle (new `CantReplaceNotEnoughEquipmentCapacity` / `CantUnequipNotEnoughEquipmentCapacity` error codes); globe behavior unchanged, excess spills to home `Storage`
  - Unit tests in `InventoryConstraintTest.cs`

### Unity_Fishing_CodeBranch
- **r56336** — Mirror hat swap/unequip capacity guard; refreshed `Photon.Interfaces.dll`
  - JIRA comment link URL points at r56237 while the text says r56336 — verify actual revision in Phase 2
- **r56063** — prior-round client-side work by Sergii Karchavets ("At revision: 56063 - code"), posted before the task was reassigned; predates the server change

### MFT20260325 (merged)
- **r16328** — Merge of r16299 + r16326 (downward, release-directed: FPA ships from MFT)

### Unity_Fishing_MainClient (merged)
- **r56432** — Merge of r56336; `Photon.Interfaces.dll` rebuilt from MFT sources instead of carrying the CodeBranch binary (DLL is branch-paired). r56063 was already present via an earlier bulk merge.

## Investigation Journal

- Intake: Executor field (`customfield_11224`) empty in JIRA — expected Yevhenii Shust per commit comments (detect-only, surfaced to user).
- Intake: client commit comment has display text r56336 but the embedded link URL targets r56237 — flagged for Phase 2 verification against `svn log`.
- VCS audit: `svn log | grep` over NPN20260602 (r16131:HEAD), MFT20260325 (r15943:HEAD), client CodeBranch (r56000:HEAD) — commits match JIRA exactly (r16299 server; r56063 + r56336 client); nothing on MFT (merge deferred to release, per JIRA "awaits merges" comment). Actual client revision is r56336 — the r56237 in the comment URL is a link typo.
- WC freshness: server WC at r16307 ≥ r16299 → disk reads trusted; client WC at r55929 < r56336 AND dirty (locally added Unity-generated files) → client changed files read only via `svn diff -c` / `svn cat -r 56336`; stale-WC warning propagated into delegated reviewers' prompts.
- Verified `IsStorageAvailable()` = `profile.PondId == null` (`Inventory_Does.cs`) → new guards are pond-only, globe flow untouched, as spec requires.
- Verified the synthetic-Hook free-slot probe: all terminal-tackle subtype keys in `BasicEquipmentConstraints` map to the single `basicTerminalTackleConstraint` (counting via its ItemTypes array); `CloneConstraints` clones per key but clones stay numerically identical (same base count, same `TackleKitCount` increments in `InitEquipConstraintCache`) → probing via Hook equals the shared pool state. Hats are `ItemTypes.Outfit` → do not count into the tackle pool themselves.
- Verified `InvalidateConstraints` already resets `equipConstraintsCache` on `item is Hat` (pre-existing) — no stale-capacity issue after swap.
- Hypothesis under verification (F-candidate): the deficit count never reaches user-visible text on the client — `MessageController.ShowCanNotMove` (checked at r56336 via `svn cat`) uses the no-args `ShowMessage(id)` overload; all callers pass `Inventory.Error` only; `Inventory.ErrorDetails` is unread by UI code. A formatting overload `ShowMessage(id, params object[])` exists but is unused on this path. Spec requires the exact count in the message. Handed to a targeted delegate to trace the server-rejection path before drafting the finding.
- Prior-round note: client r56063 (Karchavets) enabled hat-to-backpack UI + client constraint a week before the server constraint existed (r16299) — transient CodeBranch-only desync, unreleased; context, not a finding.
- Delegation (Step 6): blind hunt — code-reviewer agent + Codex (gpt-5.6-sol) over both diffs with stale-WC warnings; targeted — general-purpose agent tracing ErrorDetails delivery (local precheck + server rejection paths).
- Delegation results re-verified against code before acceptance. Disagreements resolved by reading, not majority:
  - Subordinate bypass: agent claimed "not a viable vector", Codex claimed High bypass → read `CanSubordinate` + `SubordinateItem` + `GameClientPeer_Inventory.SubordinateInventoryItem` — Codex correct (worn Doll hat + Equipment hat pass all checks; no deficit guard; no `InvalidateConstraints` in the op path, unlike `ReplaceItem`). Became pond-reachable only because r16299 made hats storable in Equipment.
  - Skirt probe (Codex Medium, agent clean): `basicTerminalTackleConstraint.AltTypes` counting (`GetConstraintItemsQuery`) matches `i.ItemType` against the array; skirt items carry `ItemTypes.SaltwaterSkirtHead`/`SaltwaterSkirt` (confirmed via test fixtures + `Inventory_Operations` switch), which the array lacks → skirts are never counted in the pool for anyone, including themselves. Pre-existing counting gap; the new Hook probe is internally consistent with actual counting → not an r16299 defect. Both delegates partially wrong.
  - Destroy/sell route (Codex High): `CanDestroyItem` blocks only `MissionItem`; destroying a worn hat leaves the pool over-capacity with no spill. Verified — but the pattern is pre-existing (identical for worn LuresBox; none of these files touched by r16299) → severity collapses to pre-existing observation.
  - Car/Lodge bypass (both delegates High): fully confirmed — `CheckItemAvailability` allows `CarEquipment` (car travel) / `LodgeEquipment` (lodge is pond-only) on pond; `CanMove` has no constraint check for those destinations and the new guard requires `storage == Equipment`; `MoveRelatedItems` Hat branch unconditionally spills `TackleOutOfStorage` to home `Storage`. Spill route itself pre-existed for hats; the new pond-block semantic just does not cover it.
- Targeted delegate verdict on ErrorDetails: CONFIRMED — count reaches no user-visible surface on any path (local precheck → no-args `ShowMessage`; connection-layer precheck → log-only `RaiseValidationFailedEvent`; server rejection → parameterless `OnInventoryMoveFailure` + generic `InventoryOperationFailed` toast; a `{0}` placeholder in localization would render literally — `Localize` never calls `string.Format`).
- Close-phase paired-client verification (content tokens, not mergeinfo): r56063 present in MainClient HEAD; r56336 absent → both halves merged at close, user-directed per the Releases mapping (FPA ships from MFT). `Photon.Interfaces.dll` for MainClient rebuilt from MFT sources — the binary is branch-paired and is never carried across pairs by merge.
- Sequencing incident at close: the server half (MFT r16328) was committed before the client pair was smoke-tested — corrected by the user's end-to-end smoke test (build+run server, build client, login) followed immediately by the client commit; the pairing rule was generalized beyond protocol increments in `reference/release_versions_and_process.md` and `reference/photon_interfaces_dll_distribution.md`.

## Findings

### F-1: Pond capacity guard bypassed via Doll → CarEquipment / LodgeEquipment; excess tackle silently spills to unavailable home Storage [Low]

**Description:** The new unequip guard in `Inventory_Can.CanMove` fires only for `storage == StoragePlaces.Equipment`. On a pond, `CheckItemAvailability` still admits `CarEquipment` (player travelled by car) and `LodgeEquipment` (lodge exists only at ponds); `CanMove` applies no per-type constraints to either destination, so the worn hat moves freely and `MoveRelatedItems` (Hat branch, `Inventory_Does.cs`) unconditionally moves `TackleOutOfStorage` into home `Storage`. Severity downgraded from Medium: per product knowledge (reviewer), Car/Lodge Equipment storage is vestigial — not used and not reachable by players through the shipped UI (client `ToCar()` handlers and context-menu checks exist but are dead wiring). Remaining vector is a modified client, and the outcome is self-inflicted tackle relocation with no economic gain.

**Investigation:** Read `CanMove` full body (guard placement, absent Car/Lodge constraint checks); read `CheckItemAvailability` (pond admission rules for Car/Lodge); read `MoveRelatedItems` Hat branch (unconditional `MoveItem(i, null, Storage)`, no `IsStorageAvailable` re-check); noted the spill route pre-existed for hats before r16299. Initial "reachable through normal UI" claim was an unverified inference from server-side availability checks — corrected after user input; client grep found only vestigial handlers (`InventoryItemComponent.ToCar()`, `ShowContextMenuInStorage`), UI reachability denied by product knowledge.

**Resolution:** Skipped — vestigial storage, no player-reachable route, self-inflicted consequence only. Cleanup of Car/Lodge Equipment (server support + client dead wiring) routed to `equipment-rules` module backlog, citing this review.

**Discovered by:** code-reviewer agent + Codex independently; verified by skill recon; downgraded per user product knowledge.

### F-2: SubordinateItem operation swaps hats without the deficit guard and without constraint-cache invalidation [Medium]

**Description:** `CanSubordinate` accepts currentParent on Doll and newParent in Equipment with matching subtype — a worn-hat/backpack-hat pair passes with no `GetHatSwapTackleDeficit` check. `Inventory_Operations.SubordinateItem` swaps the two items' storages directly and, unlike `ReplaceItem`, never calls `InvalidateConstraints`, leaving `equipConstraintsCache` stale (old hat's capacity in effect) until an unrelated invalidation. Client-callable via `InventoryOperationCode.SubordinateItem` → `GameClientPeer_Inventory.SubordinateInventoryItem`. No known legit-UI path issues Subordinate for hats (rod flows use it), but the server op accepts it — an authority gap opened by r16299 (before it, hats could not legally sit in Equipment, and the Storage-sourced variant is blocked on pond by `CheckItemAvailability`).

**Investigation:** Read `CanSubordinate` (storage/type admission, no capacity logic); read `SubordinateItem` (direct storage swap, no `MoveRelatedItems`, no `InvalidateConstraints`); read `GameClientPeer_Inventory.SubordinateInventoryItem` (op wiring, `CanSubordinate` as the only gate); resolved delegate disagreement (agent "not viable" vs Codex "High") in Codex's favor.

**Resolution:** Filed → FP-45033 (bundled with F-3: capacity guard for Hat pairs in `CanSubordinate` + `InvalidateConstraints` in `SubordinateItem`); task itself ships.

**Discovered by:** Codex; refuted code-reviewer agent's "not a viable vector" claim.

### F-3: The exact deficit count never reaches the player, contrary to the spec requirement [Medium]

**Description:** Spec: the warning must state the exact number of slots to free ("Вказувати точну кількість слотів"). Server and client mirror both compute the number into `ErrorDetails`, but no display path consumes it: `MessageController.ShowCanNotMove` uses the no-args `ShowMessage(id)` overload (a `params object[]` formatting overload exists unused); the connection-layer precheck logs `LastVerificationError` and raises a parameterless failure event; the server-rejection path ends in a generic `InventoryOperationFailed` toast. If GD authors localization with `{0}`, it renders literally (`MessageData.Localize` → `ScriptLocalization.Get`, no `string.Format`). The executor's JIRA claim "display wiring already in place, just needs text in all languages" holds only for a static, countless message.

**Investigation:** Recon traced `ShowCanNotMove` → `ShowMessage(id)` at r56336 via `svn cat` (stale-WC fallback); grepped all `ShowCanNotMove` callers (pass `Inventory.Error` only); targeted delegate independently traced all paths (local precheck, connection precheck, server rejection, batch move) and the `{0}` rendering behavior — verdict CONFIRMED.

**Resolution:** Filed → FP-45033 (bundled with F-2: pass `ErrorDetails` into `ShowCanNotMove` → formatting `ShowMessage`/`LocalizeFormat` path). Immediate mitigation: closing JIRA comment carries a warning panel for GD — localization texts for the two keys must stay static (no numbers, no `{0}` placeholders) until the follow-up lands.

**Discovered by:** skill recon; independently confirmed by Codex and the targeted delegate.

### F-4: Saltwater skirts are not counted in the terminal-tackle pool at all [Info]

**Description:** `basicTerminalTackleConstraint.AltTypes` lacks `ItemTypes.SaltwaterSkirtHead` (187) and `ItemTypes.SaltwaterSkirt` (14) while skirt items carry exactly those types and `InitEquipConstraintCache` still increments their subtype-keyed clones. Effect: skirts occupy no tackle capacity anywhere (adding them is capped only by other tackle's count), and per-subtype clones are not all numerically identical as the pool design implies. Pre-existing gap untouched by r16299; the new Hook probe is consistent with actual counting, so the guard is not weakened by it.

**Investigation:** Read `GetConstraintItemsQuery` (AltTypes matching by `i.ItemType`); confirmed skirt `ItemType` values via `InventoryEnums.cs`, test fixtures (`MissionsTest_AssembleRodCondition.cs`), and the `Inventory_Operations` type switch; reclassified Codex's Medium (probe defect) → pre-existing counting gap.

**Resolution:** Filed → FP-45034 (separate: different area; fix per the ticket as edited by the reviewer = add the two types to the constraint list).

**Discovered by:** Codex (as probe defect); reclassified by skill verification.

### F-5: Destroying/selling the worn hat leaves the tackle pool over-capacity silently [Info]

**Description:** `CanDestroyItem` rejects only `MissionItem`; destroying (and by the same pattern selling) a worn capacity-granting hat on a pond removes the capacity without spilling or blocking, leaving Equipment over-cap (tolerated state: only future adds are gated). Pre-existing pattern identical for worn LuresBox (200 slots); none of the involved files changed in r16299.

**Investigation:** Read `CanDestroyItem`; checked r16299 changed-paths list (destroy/sell files untouched); severity collapsed per pre-release + pre-existing rules.

**Resolution:** Pre-existing — routed to `equipment-rules` module backlog (together with the F-1 Car/Lodge cleanup item), citing this review.

**Discovered by:** Codex; pre-existingness established by skill verification.

### F-6: `NoMorePlaceToEquip` shadows the deficit error when the backpack Hat allowance is full [Info]

**Description:** In `CanMove`, `IsBreakingEquipmentConstraints` runs before the new deficit guard, so with a full Misc-Hat allowance and a deficit both present the player sees `NoMorePlaceToEquip` first. Arguably correct priority — the hat physically cannot be placed regardless of tackle; the deficit error surfaces on the next attempt after freeing a Misc slot.

**Investigation:** Guard placement read in `CanMove`; both delegates noted the ordering, assessments diverged (agent: sensible; Codex: Low defect) — treated as intentional priority.

**Resolution:** Accepted — the ordering is correct priority (the hat must physically fit before capacity semantics matter); the deficit error surfaces on the next attempt after freeing a Misc slot.

**Discovered by:** code-reviewer agent + Codex.

### F-7: JIRA commit comment permalink targets r56237 instead of r56336 [Info]

**Description:** The client-commit comment's display text says r56336 (correct, per `svn log`) but the embedded link URL points at r56237 — a broken permalink in the review trail. Executor-quality observation.

**Investigation:** `svn log` audit of client CodeBranch confirmed r56336 as the actual revision.

**Resolution:** Skipped — mentioned in passing in the closing JIRA comment (correct revision r56336 stated there).

**Discovered by:** skill recon (intake cross-check).

### F-8: Enum tail marker not moved in `InventoryErrorCode.cs` [Low]

**Description:** `ItemNotFound = 89` carries the `// <-----------------------` tail marker that by convention points at the last error code; the new 90/91 codes were appended below it without moving the marker, so it now lies. Comment-only fix, no IL/protocol impact.

**Investigation:** File inspection (`InventoryErrorCode.cs` at HEAD on NPN); marker semantics confirmed by position (last code before the addition).

**Resolution:** Fixed inline by the reviewer — NPN20260602 @ r16326 (comment-only, no IL/protocol impact); mentioned as a nit in the closing comment.

**Discovered by:** manual scan (reviewer).

## Verdict

**Approve — merge as is; gaps tracked separately.** Core mechanics are sound and well-tested (deficit math, pond-only gating, Misc-slot independence, globe spill flow; mirror discipline on the client). None of the findings touches anything the merge would freeze: the protocol part (codes 90/91, refreshed DLL) is correct; F-3 is client display code, F-2 is server validation logic, F-8 is a comment — all can land after the merge.

Shipping actions:
1. Single follow-up ticket FP-45033 (executor): F-3 deficit-count display wiring (client) + F-2 `Subordinate` hardening (server). F-8 marker fixed inline by the reviewer instead — NPN r16326 (nit in the closing comment).
2. Separate ticket FP-45034: F-4 skirt counting gap (pre-existing, balance-relevant).
3. Closing JIRA comment leads with LGTM and carries a warning panel for GD: localization for the two new keys must stay static — no numbers, no `{0}` — until the follow-up lands (a `{0}` would render literally; the exact-count spec point is not implemented yet).
4. `equipment-rules` module backlog: Car/Lodge vestigial storage cleanup (F-1), worn-hat destroy/sell over-cap note (F-5).
