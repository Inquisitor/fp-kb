---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15653 (server), CodeBranch @ r51708 (client); reopen-fix NPN @ r16157, merged to MFT @ r16168
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

### Reopen fix (re-review round)

- **NPN r16157** (server) — Fix PO test-show override product to match rendered design
  - New `GetRenderedDesignIndex(TargetedAd)` helper (PO + tracked + `DesignIndex < Designs.Length` → `DesignIndex`, else `0`) — single source of truth
  - `ForceShowTargetedAds` collects the product from `Designs[GetRenderedDesignIndex(shownAd)]` (replaces `foreach`-overwrite-last)
  - `MakeSlideFromAd` selects the design via the same helper; validation block runs only when `designIndex == personalOffer.DesignIndex`
- **MFT r16168** (server) — back-merge of NPN r16157 (Content backport, so QA on MFT builds gets the refinement)

**Branch propagation:** initial LBM r15653 ≤ MFT copy-source r15942 → inherited in MFT (Content) and NPN (Code) via branch copy; client r51708 on `Unity_Fishing_CodeBranch` (Code) — top of client merge chain. Reopen-fix r16157 landed on NPN (Code) only; back-merged to MFT (Content) at r16168 per author request. Not in LBM (Stable) — the test-tooling refinement is left out of Stable by decision.

## Findings

### F-1: Override product and rendered design are selected independently — desync for multi-design PO [Medium — Blocking]

**Description:** The override product (server, `ForceShowTargetedAds`) and the rendered design (`MakeSlideFromAd`) pick a design by **unrelated** rules. With no `designId`, `Designs` is not reduced; the inner `foreach` overwrites `customProduct` each iteration → keeps the **last** design's product. `MakeSlideFromAd` renders `Designs[0]` (or `Designs[DesignIndex]` when the PO is in `Context.PersonalOffers`). So the test popup shows one design paired with a different design's product — silently. For a preview tool whose entire purpose is accurate display, a silent wrong result on a supported input is a functional defect, not cosmetics.

**Investigation:** Read `ForceShowTargetedAds` (producer) and `MakeSlideFromAd` (`_SendEvent.cs:380-401`, design defaults to `Designs[0]`, deviates only via `Context.PersonalOffers` DesignIndex). Checked `TargetedAdCommand.Execute()`: `designId` is **optional** (`HasArgument(AdDesignId)`, defaults to null); when omitted on a multi-design PO the command prints the design list as a hint (lines 124-131) but still calls `ForceShowTargetedAds(designId=null)` (line 139) — a supported path. Reassessed initial `break`-after-first-with-product suggestion: **insufficient** — if `Designs[0]` has no `ProductId` but a later design does, "first with product" still mismatches `Designs[0]`. Correct fix must mirror `MakeSlideFromAd`'s design choice. Independent code-reviewer agent confirmed the producer-side mechanism; reopen severity is the system author's (Stanislav's) call, grounded in real tester usage of the no-`designId` form.

**Resolution:** Resolved by NPN r16157 (merged MFT r16168). Both the product collection and the slide render now go through the shared `GetRenderedDesignIndex` on the same `shownAd` object → they pick the same design index, so they cannot desync. Verified against the r16157 diff (read from NPN, not the stale MFT WC).

**Discovered by:** skill recon + code-reviewer agent; severity escalated by system author.

### F-2: `MakeSlideFromAd` can throw IndexOutOfRange for a force-shown PO also tracked with DesignIndex>0 [Low — Non-blocking]

**Description:** If a force-shown PO (whose `Designs` was reduced to one entry by `designId`) is simultaneously present in `Context.PersonalOffers` with `DesignIndex > 0`, `ad.Config.Designs[personalOffer.DesignIndex]` indexes past the single-element array. The interaction is exposed by the force path; the unbounded index access pre-exists in `MakeSlideFromAd`.

**Investigation:** Read `MakeSlideFromAd` (`_SendEvent.cs:383-401`). The `?.Design` null-check guards a missing design but not the array index access that precedes it.

**Resolution:** Resolved by NPN r16157 (merged MFT r16168). `GetRenderedDesignIndex` adds the `personalOffer.DesignIndex < ad.Config.Designs.Length` bound-check → falls back to `0` instead of indexing out of range.

**Discovered by:** code-reviewer agent.

> **Note — production failure-mode change:** `MakeSlideFromAd` is on the production send path. Previously an out-of-bounds `DesignIndex` (stale PO state vs config) threw `IndexOutOfRange`; now it silently falls back to design `0`. Reasonable hardening (avoids crashing the popup send over stale state), but trades a loud crash for a silent fallback that could mask a data inconsistency. Accepted as a conscious trade.

## Notes

- **Index-alignment invariant** (`adsShown` ↔ `customProducts`): holds structurally — both `.Add` unconditionally together at the bottom of the `if (null != shownAd)` block; the only other path throws. `MakeSlideFromAd` is a 1:1 order-preserving transform → `slides[i]` ↔ `products[i]` on the client. Verified.
- **Production safety:** `OverrideProductList` is set only in `ForceShowTargetedAds`, whose sole caller is `TargetedAdCommand.cs` (the `.po` chat command). `NotifyClientAboutTargetedAds` serializes `ParameterCode.Products` only when `OverrideProductList != null`. All production PO call sites pass `options = null` → `products` empty on the client → both old and new client mapping yield null → **production behavior unchanged**. Verified.
- **Null entries** in `customProducts` (non-PO ads) serialize fine (Newtonsoft → JSON `null`); client already handled null products in the old code, so no new NRE risk introduced.

## Verdict

**APPROVE / resolved** (after one reopen round). Initial fix (LBM r15653 + CodeBranch r51708) switched PO-test override mapping to index-based and resolved the original claim error; production-neutral by construction (verified). Reopen round: F-1 (blocking) — product↔design desync for the no-`designId` multi-design path — and F-2 (IndexOutOfRange edge) both resolved at the root by NPN r16157 via the shared `GetRenderedDesignIndex` helper. Back-merged to MFT (Content) at r16168; left out of LBM (Stable) by decision (test-tooling refinement). LGTM posted (comment 123773, 2026-06-09).

## Investigation Journal

- Intake: JIRA read; executor = Yuriy Burda (commit author per comment 99269). `customfield_11224` (Executor) empty — surfaced nudge, not blocking.
- VCS audit: `svn log | grep FP-41377` on LBM r15396:HEAD → single server commit r15653. Client commit located at `Unity_Fishing_CodeBranch` r51708 (CLN repo path differs from JIRA "CodeBranch" label).
- Inheritance verified: r15653 present in MFT history for `TargetedAdsManager_ReceiveEvent.cs` (≤ fork r15942); no explicit FP-41377 commits on MFT/NPN → no server merge.
- Root-cause hypothesis (old synthetic-ID + broken dedup) confirmed by reading the r15653 diff against the post-fix file.
- Production-neutrality verified by tracing `ForceShowTargetedAds` sole caller (`TargetedAdCommand.cs`) and the `OverrideProductList != null` gate in `NotifyClientAboutTargetedAds`.
- Delegated independent review to code-reviewer agent (user chose deep delegation) → confirmed mechanism, surfaced F-2, refined F-1.
- Verified `designId` optional in `TargetedAdCommand` and the no-`designId` branch proceeds (lines 124-131, 139) → F-1 reachable on a supported path.
- Verdict shifted APPROVE→REOPEN: system author (Stanislav) escalated F-1 to blocking on the grounds that silent wrong-product output defeats a preview tool's purpose. Re-examined `break`-after-first fix → insufficient; correct fix mirrors `MakeSlideFromAd` design selection. Card kept `in-progress`, stays in Active Reviews.
- Re-review (2026-06-09): reopen fix NPN r16157 read from NPN URL (`svn diff`/`svn cat`), NOT the MFT WC — r16157 > NPN fork r16130 so it is not inherited there; reading disk would have shown stale pre-fix code. Confirmed both F-1 and F-2 resolved at the root via shared `GetRenderedDesignIndex`. No client change needed (client still maps by index). Production normal case unchanged; out-of-bounds DesignIndex failure-mode noted (crash → fallback-to-0).
- Back-merge NPN r16157 → MFT (Content) per author request: dry-run clean, applied, committed MFT r16168 (committed `.` mergeinfo + 2 files only; dev-local `ignore-on-commit` changelist excluded via explicit targets + `--depth empty`). First `svn commit` attempt failed (dir out of date + cmdline svn does not auto-skip `ignore-on-commit`); resolved by `svn update` to r16167 then targeted commit.
