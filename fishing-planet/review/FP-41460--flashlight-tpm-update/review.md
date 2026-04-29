---
status: resolved
executor: Yuriy Burda
branch: LBM20251201 @ r15688, r15690
jira: https://fishingplanet.atlassian.net/browse/FP-41460
---

# FP-41460: [3D][3rd person view] Equipping or removing the flashlight in 3D does not affect the character's state

## Summary

In multiplayer 3D rooms other players did not observe a remote player's flashlight equip/unequip/replace — TPM state was not refreshed because flashlights were not classified as TPM items, and the `ReplaceInventoryItem` path did not broadcast TPM changes at all.

## Scope

- **LBM r15688** — Add flashlights to be included into TPM Items
  - `IsTPMItem` extended to recognise `IST.Flashlight` directly (the previous `IT.Outfit` check missed standalone Flashlight items, whose DB `ItemType` is `Misc` rather than `Outfit` despite the C# `Flashlight : OutfitItem` hierarchy).
- **LBM r15690** — Add TPM-update on item replace
  - In `ReplaceInventoryItem`, after `UpdateRodInGameEngine`, broadcast `PublishPropertiesChangedEvent` when the involved item, replacement, or either parent sits on `StoragePlaces.Doll` and the original `item.IsTPMItem()`.

> Both revisions are already inherited in MFT (Code) via branch copy: MFT base = LBM r15942, and r15688/r15690 ≤ r15942. No merge required.
> `Executor` field (customfield_11224) was empty in JIRA — should be set to Yuriy Burda by the executor next time.

## Findings

### F-1: `SplitAndReplaceInventoryItem*` paths lack the TPM broadcast [Info — Pre-existing]

**Description:** `SplitAndReplaceInventoryItemCount` (~line 799) and `SplitAndReplaceInventoryItemAmount` (~line 911) end with `UpdateRodInGameEngine` but do not publish `PublishPropertiesChangedEvent`. Mirrors the gap that r15690 closes for plain `ReplaceInventoryItem`. In practice flashlights are non-stackable (`Count = 1`, not `IsStockableByAmount`) so the client uses the plain replace operation, not split-and-replace; no current TPM item traverses these paths. Captured for completeness.

**Investigation:** Compared method tails of `MoveInventoryItem` (already broadcasts at lines 228–231), the patched `ReplaceInventoryItem` (684–687), and the two split-and-replace counterparts. Independent agent verified that no TPM-eligible item is realistically routed through `SplitAndReplace` given existing constraints.

**Resolution:** Skipped — defensive completion of the pattern, not a fix this task should grow into.

### F-2: `replacementItem.IsTPMItem()` not checked, only `item.IsTPMItem()` [Info]

**Description:** The new guard reads asymmetrically — broadcasts only when the *outgoing* item is TPM. Checked whether a non-TPM item could be replaced by a TPM item on the Doll (which would silently miss the broadcast). It cannot: `CanReplace` requires `ItemType` parity, and `BasicDollConstraints` admits exactly one Misc-typed entry (`IST.Flashlight`). Any item on the Doll replaceable by a Flashlight is itself a Flashlight, so `item.IsTPMItem()` is already true.

**Resolution:** Accepted — structurally constrained away by Doll/CanReplace rules.

## Investigation Journal

- Verified `Flashlight` items have DB `ItemType = Misc` (CategoryId=153, ParentCategoryId=16), confirming why the previous `item.Is(IT.Outfit)` check missed them despite `Flashlight : OutfitItem`.
- Independent code-reviewer agent corroborated both the diagnosis (r15688) and the structural safety of the asymmetric guard (r15690), and surfaced the split-and-replace pattern gap (F-1).
- Branch-copy inheritance check: LBM r15688/r15690 ≤ MFT base r15942 → MFT already carries the fix; close phase will skip the merge step.

## Verdict

Approve. The fix correctly addresses the reported symptom and is already present in the Code branch via inheritance.
