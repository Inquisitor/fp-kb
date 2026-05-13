---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16065, r16079; CodeBranch @ r53771
jira: https://fishingplanet.atlassian.net/browse/FP-43507
---

# FP-43507: FTUE. UI Re-design. Server — Shop and Inventory Rod/Tackle Match Information

## Summary

Server-side support for the FTUE shop/inventory redesign that surfaces, per item, which rod types a reel/lure fits and which reel types a rod accepts. Implemented as a new `TackleCompatibilityCache` (replicated to client via `ClientCacheOperationCode.GetTackleCompatibility = 13`) with per-`ItemId` lookups. Client renders the list (mapping `ItemSubTypes` enum → localized strings via `I2.Loc`).

## Scope

### MFT20260325 (Code branch — server)
- **r16065** — Add `TackleCompatibility` cache and client-cache op for per-item rod/reel
  - DTO `TackleCompatibility { CompatibleRodTypes, CompatibleReelTypes }` — `ItemSubTypes[]`, string-enum serialization, `NullValueHandling.Ignore`
  - `TackleCompatibilityCache` singleton with double-checked init + `CachedEntity<Dictionary<int, TackleCompatibility>>`
  - `RodTemplates.DeriveCompatibleRodTypes/ReelTypes/RodReelCombos` + `IsLikelyTackleType` + `NonTackleItemTypes` denylist
  - Inventory_Groups `AllReels` constant (5 reels — `FlyReel`/`LineRunningReel` excluded)
  - GameApplication wiring (after InventoryItems); GameClientPeer opcode + handler
  - VW_AllCaches catalog row
  - Unit tests (16 rod-type tests) + integration test
- **r16079** — Include compatible reel types for rod items in `TackleCompatibility` and minor cleanup
  - **Functional fix** in `TackleCompatibilityCache.LoadByItemId`: reel-branch condition `!= Rod && != Reel` → `!= Reel` (rods now get `CompatibleReelTypes`)
  - `DeriveCompatibleReelTypes`: rod path uses `FindTemplatesForRod(item.ItemSubType)` instead of `Templates.Where(Validate(item))`
  - `DeriveCompatibleRodReelCombos` removed from production; moved to test-local (research probe only)
  - +4 reel tests (FlyRod empty, TelescopicRod/CarpRod → narrow, SpinningRod → broad)

### CodeBranch (Code branch — client)
- **r53771** — Add `TackleCompatibility` cache and lookup helpers for per-item rod/reel
  - Out of server-review scope

## Investigation Journal

- Executor field (`customfield_11224`) empty in JIRA — executor identified via commit comments as Yuriy Burda. Hygiene finding (F-9).
- Branch-copy inheritance: MFT created from LBM @ r15942; r16065/r16079 (>15942) are MFT-only, no merge propagation expected. No cross-branch merge required for this review.
- Code-reviewer agent spawned for independent check; 7 findings returned, verified per below.
  - F-6 rejected as false positive — agent misread `VW_AllCaches` column semantics. Verified: 3rd column `[CachesList]` is `nameof(CachedEntity)` not source-tables; 4th column `[TablesList]` (`InventoryItems`) carries the source-tables role.
  - F-1, F-2 verified as pre-existing convention by reading `InventorySortingGroupsCache.cs` — identical pattern (`private bool initialized = false;` without `volatile`, no null-guard in `GetAll`). Not introduced by this PR; routed as Info, not blocking.
  - F-3 verified: `Grep FlyReel|LineRunningReel` in `Shared/ObjectModel/Inventory/TerminalTackle/` returned no matches — these subtypes are referenced only in `InventoryEnums.cs` and `Inventory_Groups.cs`. Confirms intentional exclusion of fly-fishing/trolling reels (no rod template references them).

## Findings

### F-1: `initialized` flag not `volatile` in double-checked lock [Info]

**Description:** `TackleCompatibilityCache.Init()` uses an outer non-locked `if (initialized) return;` over `private bool initialized;`. Under the .NET memory model the outer read is theoretically racy — `volatile` is the canonical fix. In practice the path runs once at server startup before client traffic, so a real race is essentially zero.

**Investigation:** Compared against peer cache `InventorySortingGroupsCache.cs::Init()` (lines 27, 44-61) — identical pattern (`private bool initialized = false;` without `volatile`). Established codebase convention.

**Resolution:** Skipped — pre-existing pattern. Out of scope for this PR.

**Discovered by:** code-reviewer agent.

### F-2: `GetAll()` / `GetByItemId()` dereference `byItemId` without null guard — NRE if called pre-`Init` [Info]

**Description:** `instance.byItemId.Cache` is dereferenced unconditionally; if `InitDefaults()` was not called, NRE rather than a descriptive `InvalidOperationException`. Production path (GameApplication startup) always inits first; tests use `ClassInitialize`.

**Investigation:** Peer cache `InventorySortingGroupsCache.GetAll()` has same gap (line 102-105). Pre-existing convention.

**Resolution:** Skipped — pre-existing pattern.

**Discovered by:** code-reviewer agent.

### F-3: `AllReels` excludes `FlyReel` and `LineRunningReel` without inline rationale [Info]

**Description:** `Inventory.SubTypes.AllReels` has 5 entries; full `Reels` has 7. `FlyReel` and `LineRunningReel` are silently absent. This is intentional — fly fishing uses a separate rig system, and no `RodTemplate` references these subtypes — but the diff doesn't say so. A future maintainer adding a fly/trolling template might "fix" `AllReels` and accidentally widen compatibility.

**Investigation:** `Grep FlyReel|LineRunningReel` in `Shared/ObjectModel/Inventory/TerminalTackle/` — no matches. Confirms zero template references. `DeriveCompatibleReelTypes_FlyRod_not_in_any_template_should_be_empty` (r16079) already tests the rod side of this asymmetry.

**Resolution:** Accepted — would benefit from a one-line comment above `AllReels` ("excludes FlyReel/LineRunningReel — no current template uses these"), but not blocking. Sample test on the reel-item side (FlyReel item → empty `CompatibleRodTypes`) would mirror the existing FlyRod test; optional.

**Discovered by:** code-reviewer agent.

### F-4: `Templates.Compatible(item)` covers `Templates[]` only — `TemplatesPartial` intentionally excluded, not documented [Info]

**Description:** `DeriveCompatibleRodTypes` operates on complete templates (`Templates`), not partial ones (`TemplatesPartial`). Correct for catalog purposes — partial templates model in-progress equipping, not catalog relationships — but the "ever compatible" docstring doesn't note the partial-template exclusion.

**Investigation:** File inspection of `RodTemplates.cs` confirmed `Compatible(...)` is an extension on `IEnumerable<RodTemplateDesc>` called only on `Templates`. `TemplatesPartial` exists as a separate array.

**Resolution:** Accepted — minor documentation gap. Suggested one-line addition to XML docstring.

**Discovered by:** code-reviewer agent.

### F-5: Hardcoded `ItemId = 469` (Corn) in unit test [Low]

**Description:** `DeriveCompatibleRodTypes_CommonBait_with_carp_ItemId_should_include_carp_rod` uses `Init(new Bait { ..., ItemId = 469 })` to exercise the `IsCarpBait` predicate path. The number is explained by an inline comment but is fragile against any future re-ID of Corn in the DB. The `ObjectModel.Tests` project is DB-free, but `IsCarpBait` itself reads from a hardcoded set/list internally — if that list changes, the test breaks. Self-documenting only via comment.

**Investigation:** File inspection. Did not chase down `IsCarpBait` definition — assuming agent's read is correct.

**Resolution:** Accepted — extract `const int CornItemId = 469;` for self-documentation; or document via lookup-by-predicate if practical. Not blocking.

**Discovered by:** code-reviewer agent.

### F-6: VW_AllCaches column reading misinterpreted [Rejected]

**Description:** Agent flagged the `'TackleCompatibilityCache'` value in the 3rd column as "data-source naming the class instead of the table". Verified false: the 3rd column is `[CachesList]` (= names of `CachedEntity` instances within the class, per `nameof(...)` in `Caches.Instance.NewCachedEntity(...)`); the 4th column `[TablesList]` is `'InventoryItems'` — the actual source-tables column, and it's correct.

**Investigation:** Read the VW_AllCaches CREATE statement header (`'-' AS [Group],'-' AS [ClassName],'-' AS [CachesList],'-' AS [TablesList]`). Compared against peer rows.

**Resolution:** Rejected — false positive.

**Discovered by:** code-reviewer agent.

### F-7: Integration test does not assert that rod items receive `CompatibleReelTypes` after r16079 [Low]

**Description:** `TackleCompatibilityCache_GetAll_and_GetByItemId_should_match_per_item_helpers` updates `expectedReels` gating in r16079 to mirror the new behavior, but only logs `checkedRods` / `checkedReels` counters via `Console.WriteLine`. There is no assertion that the cache actually contains rod items with non-null `CompatibleReelTypes`. If the rod→reel mapping silently regressed (e.g. someone re-introduced the `&& != Rod` guard), the test would pass.

**Investigation:** File inspection of the diff. The counters are computed but never compared.

**Resolution:** Accepted — add `Assert.IsTrue(checkedReels > 0)` qualified by rod-item counter, or a focused single-item check (e.g. find a `SpinningRod` in `ItemCache`, assert `CompatibleReelTypes != null`). Low — the unit tests for `DeriveCompatibleReelTypes` already cover the logic; this is integration-level belt-and-suspenders. Not blocking.

**Discovered by:** code-reviewer agent.

### F-8: Architectural choice — separate cache vs. embedding in Shop/Inventory item responses [Info]

**Description:** JIRA description says the new field should appear "у відповідях API для Shop та Inventory" / "включено у відповідь при запиті деталей айтема". The implemented design instead exposes the compatibility map as an independent replicated cache (`ClientCacheOperationCode.GetTackleCompatibility`) — the client looks up by `ItemId` locally, no embedded field on item DTOs. Functionally equivalent (the data reaches the client), but a different shape from what the description literally asks.

**Investigation:** Confirmed via JIRA comment (executor) and `GetByItemId`/`GetCompatibleRodTypeNames` helpers on the client side that this design was coordinated with the client team — not a unilateral deviation. The separation is reasonable: compatibility data is item-catalog-wide and best replicated once, not embedded per response (avoids duplication across Shop + Inventory responses, easier to keep client cache consistent).

**Resolution:** Accepted — coordinated decision, documented in JIRA. Worth noting in the review for traceability but no action.

**Discovered by:** skill recon.

### F-9: JIRA `Executor` field (`customfield_11224`) empty [Info]

**Description:** Executor field unset in JIRA; executor identified via commit comments as Yuriy Burda. Process hygiene only.

**Investigation:** `jq '.fields.customfield_11224'` returned `null`.

**Resolution:** Surface in JIRA review comment (executor hygiene reminder); no code action.

**Discovered by:** skill recon (executor hygiene check, Phase 1).

## Verdict

**Approve.** No blocking findings. The implementation is well-structured: clear separation between catalog-derivation logic (`RodTemplates.Derive*`), the cache layer (`TackleCompatibilityCache`), and the wire transport (`ClientCacheOperationCode`); per-item denylist short-circuits non-tackle items at load time; both unit and integration tests are present; r16079 corrects the rod-reel coverage gap introduced in r16065.

Minor suggestions (none blocking): F-3 inline-comment for `AllReels` exclusions, F-7 add an explicit assertion on the rod→reel path, F-5 extract the magic ItemId. F-1/F-2 are pre-existing patterns (consistent with `InventorySortingGroupsCache`) and out of scope.
