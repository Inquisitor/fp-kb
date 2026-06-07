---
status: in-progress
executor: Yuriy Burda
branch: LBM @ r15653 (server), CodeBranch @ r51708 (client)
jira: https://fishingplanet.atlassian.net/browse/FP-41377
---

# Review: FP-41377 — [PO] Error claiming free PO issued through chat on QA environment

## Summary

On test/QA environments, issuing a Premium Offer (PO) to oneself via the Game Master chat command `.po [id po ads] [language] [id po design]` (e.g. `.po 80650 2 66100`) and then attempting to claim it produced an error — the PO product was not received. Production was unaffected. The fix changes how custom product overrides are mapped during PO testing: **index-based (order) instead of by product ID**, avoiding new models purely for testing.

**Root cause:** the old server code assigned synthetic decrementing IDs (`--lastAssignedProductId` from `int.MaxValue`) to `design.ProductId`, with a broken dedup (lookup keyed by original `productId`, stored under the synthetic id → reuse branch never hit), and a flattened override list not aligned to ads. The client matched product↔slide by `ProductId`; with synthetic / duplicate IDs `FirstOrDefault` mismatched → product not found → claim error.

## Scope

- **LBM r15653** (server) — Index-based custom product override mapping in `ForceShowTargetedAds` (`TargetedAdsManager_ReceiveEvent.cs`)
  - `customProducts` changed from `Dictionary<int,Dictionary<int,StoreProduct>>` to `List<StoreProduct>`, one entry per shown ad (null for non-PO)
  - Stops mutating `design.ProductId`; sends real product DTOs
  - Doc comment added on `TargetedAdNotificationOptions.OverrideProductList` (`Shared/ObjectModel/Monetization/TargetedAd.cs`)
- **CodeBranch r51708** (client) — `SetPersonalOfferSlides` (`PhotonServerConnection_Monetization.cs`): slide↔product mapping changed from `products.FirstOrDefault(p => p.ProductId == s.ProductId)` to index-based `products[i]` with bounds-check

**Branch propagation:** LBM r15653 ≤ MFT copy-source r15942 → already inherited in MFT (Content) and NPN (Code) via branch copy; **no server merge needed** (verified: r15653 appears in MFT history for the touched file; no explicit FP-41377 commits on MFT/NPN). Client r51708 is on `Unity_Fishing_CodeBranch` (Code role) — top of the client merge chain, nothing to merge upward.

## Findings

### F-1: Override product and rendered design are selected independently — desync for multi-design PO [Medium — Blocking]

**Description:** The override product (server, `ForceShowTargetedAds`) and the rendered design (`MakeSlideFromAd`) pick a design by **unrelated** rules. With no `designId`, `Designs` is not reduced; the inner `foreach` overwrites `customProduct` each iteration → keeps the **last** design's product. `MakeSlideFromAd` renders `Designs[0]` (or `Designs[DesignIndex]` when the PO is in `Context.PersonalOffers`). So the test popup shows one design paired with a different design's product — silently. For a preview tool whose entire purpose is accurate display, a silent wrong result on a supported input is a functional defect, not cosmetics.

**Investigation:** Read `ForceShowTargetedAds` (producer) and `MakeSlideFromAd` (`_SendEvent.cs:380-401`, design defaults to `Designs[0]`, deviates only via `Context.PersonalOffers` DesignIndex). Checked `TargetedAdCommand.Execute()`: `designId` is **optional** (`HasArgument(AdDesignId)`, defaults to null); when omitted on a multi-design PO the command prints the design list as a hint (lines 124-131) but still calls `ForceShowTargetedAds(designId=null)` (line 139) — a supported path. Reassessed initial `break`-after-first-with-product suggestion: **insufficient** — if `Designs[0]` has no `ProductId` but a later design does, "first with product" still mismatches `Designs[0]`. Correct fix must mirror `MakeSlideFromAd`'s design choice. Independent code-reviewer agent confirmed the producer-side mechanism; reopen severity is the system author's (Stanislav's) call, grounded in real tester usage of the no-`designId` form.

**Resolution:** Blocking — reopened. Fix direction: select the override product from the same design `MakeSlideFromAd` will render (`Designs[0]`, or `Designs[DesignIndex]` when tracked), not the last design in the loop.

**Discovered by:** skill recon + code-reviewer agent; severity escalated by system author.

### F-2: `MakeSlideFromAd` can throw IndexOutOfRange for a force-shown PO also tracked with DesignIndex>0 [Low — Non-blocking]

**Description:** If a force-shown PO (whose `Designs` was reduced to one entry by `designId`) is simultaneously present in `Context.PersonalOffers` with `DesignIndex > 0`, `ad.Config.Designs[personalOffer.DesignIndex]` indexes past the single-element array. The interaction is exposed by the force path; the unbounded index access pre-exists in `MakeSlideFromAd`.

**Investigation:** Read `MakeSlideFromAd` (`_SendEvent.cs:383-401`). The `?.Design` null-check guards a missing design but not the array index access that precedes it.

**Resolution:** Non-blocking — flagged in the reopen comment as worth guarding while in the area (force path could bypass the `Context` lookup, or `MakeSlideFromAd` could bound-check).

**Discovered by:** code-reviewer agent.

## Notes

- **Index-alignment invariant** (`adsShown` ↔ `customProducts`): holds structurally — both `.Add` unconditionally together at the bottom of the `if (null != shownAd)` block; the only other path throws. `MakeSlideFromAd` is a 1:1 order-preserving transform → `slides[i]` ↔ `products[i]` on the client. Verified.
- **Production safety:** `OverrideProductList` is set only in `ForceShowTargetedAds`, whose sole caller is `TargetedAdCommand.cs` (the `.po` chat command). `NotifyClientAboutTargetedAds` serializes `ParameterCode.Products` only when `OverrideProductList != null`. All production PO call sites pass `options = null` → `products` empty on the client → both old and new client mapping yield null → **production behavior unchanged**. Verified.
- **Null entries** in `customProducts` (non-PO ads) serialize fine (Newtonsoft → JSON `null`); client already handled null products in the old code, so no new NRE risk introduced.

## Verdict

**REOPEN** (1 blocking). The index-based mapping correctly resolves the original claim error for the single-design / `designId`-specified flow, and is production-neutral by construction (verified). But F-1 leaves the product↔design selection desynced for the supported no-`designId` multi-design path, so the preview tool silently shows the wrong product — blocking for a tool whose purpose is accurate preview. F-2 flagged as related non-blocking. No merge performed (branch-copy inheritance + reject verdict). Reopen comment posted to JIRA (comment 123415, 2026-06-07); JIRA status transition handled by author.

## Investigation Journal

- Intake: JIRA read; executor = Yuriy Burda (commit author per comment 99269). `customfield_11224` (Executor) empty — surfaced nudge, not blocking.
- VCS audit: `svn log | grep FP-41377` on LBM r15396:HEAD → single server commit r15653. Client commit located at `Unity_Fishing_CodeBranch` r51708 (CLN repo path differs from JIRA "CodeBranch" label).
- Inheritance verified: r15653 present in MFT history for `TargetedAdsManager_ReceiveEvent.cs` (≤ fork r15942); no explicit FP-41377 commits on MFT/NPN → no server merge.
- Root-cause hypothesis (old synthetic-ID + broken dedup) confirmed by reading the r15653 diff against the post-fix file.
- Production-neutrality verified by tracing `ForceShowTargetedAds` sole caller (`TargetedAdCommand.cs`) and the `OverrideProductList != null` gate in `NotifyClientAboutTargetedAds`.
- Delegated independent review to code-reviewer agent (user chose deep delegation) → confirmed mechanism, surfaced F-2, refined F-1.
- Verified `designId` optional in `TargetedAdCommand` and the no-`designId` branch proceeds (lines 124-131, 139) → F-1 reachable on a supported path.
- Verdict shifted APPROVE→REOPEN: system author (Stanislav) escalated F-1 to blocking on the grounds that silent wrong-product output defeats a preview tool's purpose. Re-examined `break`-after-first fix → insufficient; correct fix mirrors `MakeSlideFromAd` design selection. Card kept `in-progress`, stays in Active Reviews.
