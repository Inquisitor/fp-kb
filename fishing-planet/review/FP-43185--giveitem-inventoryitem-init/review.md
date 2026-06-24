---
status: resolved
executor: Yevhenii Shust
branch: NPN @ r16183 (Round 2 fix), merged to MFT @ r16232; MFT @ r16048 (Round 1, superseded)
jira: https://fishingplanet.atlassian.net/browse/FP-43185
---

# FP-43185: Selling price of an item issued individually from Web Admin is higher than the same item issued in a product pack

## Summary

Bug fix: an item granted individually via Web Admin (or ProfileUpdater) computed a sell price ~100x higher than the same item granted inside a product pack. Root cause: the individual-grant paths set `item.Count = 1` on a stockable-by-amount line, breaking the `Length/Count` ratio that drives `Line.SellPrice`. The fix replaces the inline init block in two individual-grant paths with a call to the new helper `ObjectModel.Inventory.Multiply(item, n)`.

## Scope

- **MFT r16048** — Fixed InventoryItem initialization in GiveItem for WebAdmin and ProfileUpdater
  - `ProfileUpdater.GiveItem` — inline `if (IsStockableByAmount) { Count=1; Amount*=... } else Count=...` replaced with `Inventory.Multiply(item, count ?? 1)`
  - `ToolsModel_Give.GiveItem` (WebAdmin) — same block replaced with `Inventory.Multiply(item, ItemCount ?? item.Count)`
  - `InventoryItemInteractions.GiveItemInteraction` — NOT changed; only a `// TODO FP-43540` comment added (inline block kept)

## Mechanism (verified)

- `Line` (stockable-by-amount): `Count` = catalog spool length, `Amount`/`Length` = current length, `Init()` does `Length = Count`. `SellPrice = Price * Length/Count * Durability/MaxDurability * ratio` -> a full fresh spool has `Length/Count == 1`.
- Old individual path: `Count = 1`, `Length` stays at catalog value (e.g. 100) -> `Length/Count = 100` -> sell price 100x inflated. **This was the bug.**
- New individual path via `Inventory.Multiply`: `Amount *= n` then `Init()` resets `Length = Count` -> `Count` untouched (catalog), `Length = Count` -> ratio 1 -> correct sell price.
- Product/pack path (`MonetizationHelper.FromDto`): sets `Count = productItem.Count`, then `Init()` -> `Length = Count` -> ratio 1. **Same end state as the fixed individual path -> price parity achieved for Lines.**

## Findings

### F-1: For Lines, `Multiply`'s amount multiplication is nullified by `Init()` [Low]

**Description:** In `Inventory.Multiply`, for `IsStockableByAmount` items it does `item.Amount *= itemCount` and then calls `item.Init()`. For `Line`, `Init()` unconditionally executes `Length = Count`, discarding the multiplication. Granting count>1 of a line via the individual paths therefore yields the same result as count=1. Not a regression (old code was also wrong for count>1, but inflated instead of clamped), and the reported single-grant case is correct. The product path normalizes the same way, so a "line is always a full catalog spool" is the consistent system behavior.

**Investigation:** Read `Line.Init()`, `Inventory.Multiply`, `Line.SellPrice`. Confirmed `Init()` has no guard. ProfileUpdater call site passes `count ?? 1` so for its single known call (count=1) the multiplication is a visible no-op anyway.

**Resolution:** Accepted (low practical impact; grant-multiple-lines is not a real workflow).

**Discovered by:** skill recon.

### F-2: `Inventory.Multiply` regresses individual grants of count-stackable consumables [High]

**Description:** The old individual code used **absolute assignment** for the count branch (`item.Count = ItemCount ?? item.Count`). The new helper uses **multiplication** (`item.Count *= itemCount`). For items that stack by Count and are NOT `IsStockableByAmount` (Bait, Hook, Lure, Leader — base `Init()` is a no-op), the catalog `Count` is frequently > 1: a DB scan of `Main.dbo.InventoryItems` shows hundreds of non-Length items with `Count` = 5 (508 items), 10, 500 (129), 1000 (132), 2500 (69), 3000 (47), etc. Consequences in `ToolsModel_Give.GiveItem` (`Multiply(item, ItemCount ?? item.Count)`):
- Admin leaves the count field empty (`ItemCount` is `int?`, plain textbox -> null; historically "give one default pack") -> `Count = base * base` (e.g. 1000 -> 1,000,000).
- Admin enters N -> `Count = base * N` instead of N.
`ProfileUpdater.GiveItem` (`Multiply(item, count ?? 1)`) is milder but still wrong: a bait with base 1000 and count=1 yields `Count = 1000` where the old code yielded `Count = 1`.
This reintroduces the same class of defect the ticket was about (wrong delivered quantity), in a different item category, and the empty-count case is catastrophic.

**Investigation:**
- Confirmed only `Line`, `BoatFuel`, `Chum` override `IsStockableByAmount = true`; `Bait`/`Hook`/`Lure`/`Leader` use base (false) -> hit the `Count *= itemCount` branch.
- Confirmed base `InventoryItem.Count` has no `[JsonConfig]`; `ItemFactory.GetTypedItem` deserializes via `JsonConvert.DeserializeObject(ConfigJson, type)` with DEFAULT settings, so the `"Count"` key in ConfigJson IS bound -> base Count = catalog value (e.g. 1000). Cross-checked: the old `Count = ItemCount ?? item.Count` only ever worked because base Count was the catalog value.
- DB scan (read-only, NOLOCK) confirmed wide prevalence of base Count > 1 among non-Length items.
- `InventoryItemDto` has no Count column -> Count comes only from ConfigJson.
- Verified WebAdmin UI exposes `ItemCount` as a nullable textbox -> null path reachable.
- Residual hop (gift serialize -> message bus -> receive-side) now RESOLVED by QA reproduction: granting item 294 (base Count 50) via WebAdmin with an empty count field delivered 2500 in the player's in-game inventory (= 50^2), confirming no receive-side clamping and the regression end-to-end.

**Blast radius:** Admin-triggered only. The two sites changed by r16048 are `ToolsModel_Give.GiveItem` (WebAdmin, admin-auth) and `ProfileUpdater.GiveItem` (ReleaseTool). Players cannot trigger them. `Inventory.Multiply` is pre-existing (r8336) and is also called from two PRODUCTION player-facing sites NOT touched by this commit — `GameClientPeer_Shop` (purchase) and `RewardManager` (mission/daily rewards) — both of which use it correctly (always a concrete `itemCount`, `IsUnstockable` forced to 1). The shop is the canonical-correct caller: `profileItem = CreateProfileItem(...)` (base Count = catalog pack size), `int packSize = profileItem.Count`, then `Multiply(profileItem, itemCount)` -> `packSize * packsBought`. So no player self-service exploit is introduced. However, the effect still lands in a real player's production inventory (admin grants e.g. 1,000,000 baits the player can use/sell) — same trigger/effect shape as the original bug. The executor copied the shop's multiply semantics into the admin give path but (a) kept the old `ItemCount ?? item.Count` fallback, which under multiply means "multiply by the pack size" -> base^2 when empty; and (b) silently changed the historical admin-field meaning (old `Count = ItemCount` was absolute units; new is a pack multiplier). The shop avoids both because null never reaches it and unstockable is clamped to 1.

**Resolution:** Blocking. `Inventory.Multiply` (multiply semantics) is correct for the shop but is the wrong primitive for the admin individual-grant path, which historically used absolute-set and must match the product path's `inventoryItem.Count = productItem.Count`. Suggested directions: (a) for the non-amount branch set `Count = itemCount` rather than `*=`; or (b) route individual grants through an absolute-set helper and reserve `Multiply` for true multiplier scenarios; or (c) special-case so only `IsStockableByAmount` items multiply Amount while count-stackable items assign Count. At minimum the `?? item.Count` fallback must not feed the pack size in as a multiplier.

**Discovered by:** skill recon + DB verification (refines code-reviewer agent, which assumed base Count = 0 and rated this latent/inert).

### F-3: Price parity for Lines is actually achieved [Info]

**Description:** The ticket's Expected Result (individual sell price == pack sell price for Gold/Cash lines) IS met by the fix. Both the fixed individual path and the product/pack path (`MonetizationHelper.FromDto`) end with `Init()` setting `Length = Count` -> `Length/Count = 1` -> identical `Line.SellPrice`.

**Investigation:** Traced the real pack-grant path (`ToolsModel_Products.GiveProduct` -> `ProductDeliveryService` -> `MonetizationHelper.FromDto`), not the mission `GiveItemInteraction` reward path. An independent code-reviewer agent initially flagged this Critical by tracing `GiveItemInteraction` (Count=1, Length=100 -> ratio 100); that is the wrong comparison path (mission reward, not product delivery) — refuted. Decisive tell: pre-fix the inline block was identical in all three sites, yet the bug existed, so the pack the ticket compares against must use a fourth path (it does: `FromDto`).

**Resolution:** Accepted — fix correctly resolves the reported defect.

**Discovered by:** skill recon (corrected code-reviewer agent finding).

## Verdict

**REJECT / REOPEN — returned to executor.** The reported line-price bug is correctly fixed and parity is verified (F-3). However, the refactor to `Inventory.Multiply` introduces a High-severity regression (F-2): individual Web Admin / ProfileUpdater grants of count-stackable consumables (baits, hooks, lures — hundreds of catalog items with base Count > 1) deliver inflated quantities, with the common "empty count" Web Admin action yielding `base^2`. F-2 reproduced in-game (item 294, base 50 -> 2500). F-1 accepted (low impact); F-3 confirms the core fix is sound.

JIRA rejection comment posted 2026-06-09 (comment 123690). Status transition back to In Progress handled by reviewer outside this workflow.

## Investigation Journal

- Phase 1 intake: Executor field (`customfield_11224`) = Yevhenii Shust, matches commit author in JIRA comment id:117081. Hygiene check OK.
- Phase 2 VCS audit: `svn log | grep FP-43185` on MFT confirmed r16048 (author yevhenii.shust) as the sole commit; matches JIRA. No commit-posting discrepancy.
- Initial hypothesis "pack path = `GiveItemInteraction`" proven wrong — pre-fix the inline init block was byte-identical across ProfileUpdater / ToolsModel_Give / InventoryItemInteractions, so an identical-logic path cannot explain an individual-vs-pack discrepancy. Real pack path is `MonetizationHelper.FromDto` (product delivery).
- Spawned code-reviewer agent; it rated F-3 Critical (fix fails) by tracing the mission reward path, and rated F-2 latent (assumed base Count=0). Both corrected here: F-3 refuted via the correct product path; F-2 escalated to High via DB scan proving base Count > 1 is widespread.
- F-2 verified through the full chain: ConfigJson Count key -> default JSON deserialization in `GetTypedItem` -> `Multiply` multiply-vs-assign semantics -> nullable `ItemCount` UI. One residual hop (gift receive-side re-clamping) left unverified, noted in the finding.
- Findings routing: F-1 accepted inline; F-2 blocking (verdict reject/reopen); F-3 info.

---

# Round 2 — rework after reopen (NPN r16183)

> Everything above is Round 1 (MFT r16048, rejected for the F-2 regression). This round reviews the executor's rework.

## Round 2 Scope

- **NPN r16183** — Reworked: split `IsStockableByAmount` handling in both WebAdmin and ReleaseTool grant paths — `Multiply` (with `Init`) for amount-stackable items to preserve sell-price parity with the pack path, absolute `Count` assignment for count-stackable to fix the quantity regression. `GiveItemInteraction` inline block left as-is (deferred to FP-43540).
  - (intent per JIRA comment id:124465 — diff to be audited in Phase 2)

## Round 2 Investigation

- Phase 1 intake: re-review on existing card; executor still Yevhenii Shust; status In Review.
- **Branch change between rounds:** Round 1 landed on MFT (Content) as r16048; Round 2 rework is on NPN (Code) as r16183. Per `_index.md` ancestry, NPN was branched from MFT:16130, so r16048 is inherited into NPN; r16183 reworks on top. The rework direction (Multiply for amount-stackable, absolute Count for count-stackable) matches the rejection comment's suggested fix.
- **Backport (resolved in close phase):** r16183 backported NPN -> MFT as r16232 (clean merge). r16048 exists only on MFT + NPN (NPN inherited it via branch copy, reworked by r16183; MFT now superseded by r16232) — no other active branch carries it.
- VCS audit on NPN: `svn log | grep FP-43185` returned r16183 only for FP-43185. r16184 is a FP-43540 commit (tech-debt) that touches the same paths — extracts `Inventory.ApplyCount` and routes all three sites through it; behavior-identical to r16183 for the two grant paths. NPN WC at r16227 (ahead of both) — disk reads trustworthy; verified HEAD matches diffs.
- Spawned code-reviewer agent. It confirmed F-2 fixed, F-3 preserved, ApplyCount behavior-identical, and (correctly) flagged that r16184 fixes the same line-price bug in the `GiveItemInteraction` reward path. It raised ONE false alarm: a claimed count-stackable regression in `GiveItemInteraction` ("catalog Count -> 1, needs mission-config check"). REFUTED — the agent misread the old `item.Count = Count` (assignment from the interaction's `int Count` field) as `item.Count = item.Count` (no-op). Verified `InventoryItemInteraction.Count` is non-nullable `int`, so `ApplyCount`'s `Count ?? item.Count` == `Count` == old behavior. No mission-config check needed. (Recurring pattern: delegated agent confident misread — third instance, see review-process-observations.)

## Round 2 Findings

### F-2 (Round 1 blocker): RESOLVED

Both grant paths now use `Inventory.ApplyCount(item, count)` which assigns `item.Count = count ?? item.Count` (absolute) for count-stackable items. WebAdmin giving a base-50 bait with an empty count field now yields Count=50 (was 2500); explicit N yields N. Restores the correct pre-bug (pre-r16048) behavior. Verified by recon + code-reviewer agent.

### F-3 (line price parity): PRESERVED

Amount-stockable items go through `Multiply(item, count ?? 1)` -> `Init()` -> for Line `Length = Count` -> ratio 1. Parity with the product path holds. Bonus: the amount-branch fallback changed from r16048's `?? item.Count` to `?? 1`, which also fixes the `BoatFuel`/`Chum` Weight/Capacity inflation that r16048 would have caused on an empty count field (e.g. Capacity 100 -> 10000). Net improvement over both the original buggy state and the rejected r16048.

### F-1 (amount-stockable count>1 nullified by Init): UNCHANGED [Low / Accepted]

Still present and now uniform across all three sites via `ApplyCount`. Low impact; consistent with the product path; not a real workflow. Accepted.

### Note (FP-43540 scope, not FP-43185): GiveItemInteraction re-routing

r16184 routed the player-facing `GiveItemInteraction` reward path through `ApplyCount` too. Effect: count-stackable rewards unchanged (`item.Count = Count`, identical); amount-stockable rewards (Line/Chum/BoatFuel) now normalize via `Multiply`+`Init`, which fixes the same inflated-sell-price bug in that path (old: `Count=1` + no `Init` -> ratio = catalog). This is a genuine improvement but belongs to FP-43540's review, not this card.

## Round 2 Verdict

**APPROVE.** The rework correctly resolves the Round-1 blocker (F-2) via absolute `Count` assignment for count-stackable items, preserves line price parity (F-3), additionally fixes the `BoatFuel`/`Chum` amount-inflation latent in r16048, and resolves the Round-1 call-site inconsistency. The `Inventory.ApplyCount` extraction (r16184/FP-43540) is behavior-identical to r16183's inline fix for the two grant paths. The fix direction matches the Round-1 rejection guidance exactly.

Cross-branch: the rework lives on NPN (Code) as r16183 (executor commit). Backported down to MFT (Content) as r16232 (`svn merge -c 16183`, clean — the GiveItem block was untouched by MFT's later r16134/r16201). r16184/FP-43540 (ApplyCount extraction) intentionally NOT backported — separate ticket. Approve comment posted (125988). Closed resolved.

> Note: r16048 (Round 1 regression) is inherited into NPN via branch copy but reworked there by r16183; on MFT it is superseded by the r16232 backport. No other active branch carries r16048 (LBM/KNW/IMV predate it).

