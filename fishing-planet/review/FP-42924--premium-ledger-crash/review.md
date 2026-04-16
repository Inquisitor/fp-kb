---
status: resolved
executor: Yevhenii Shust
branch: LBM @ r16001, merged to MFT @ r16014
jira: https://fishingplanet.atlassian.net/browse/FP-42924
---

# Review: FP-42924 — PremiumLedger crash when product missing from cache

## Summary

WebAdmin Premium Subscription Ledger page crashed with `NullReferenceException` when `MonetizationCache.GetProductBrief()` returned null for a product ID not in cache. The view accessed `.Name` on the null result directly.

### Files modified (2)

- `WebAdmin/WebAdmin/Views/Player/PremiumLedger.cshtml`
- `Shared/SharedLib/Config/MonetizationCache.cs`

### What changed

1. `PremiumLedger.cshtml` — separated product lookup from rendering. Added null check: if product found, show link with name; if not, show red `#ProductId - PRODUCT NOT FOUND` diagnostic message.
2. `MonetizationCache.GetProductName()` — replaced `ContainsKey` + indexer with `TryGetValue` (eliminates double-lookup). Renamed lambda variable `f` → `p`.
3. `MonetizationCache.GetProductBrief()` — inlined `cachedProduct` variable, return directly.

## Checklist

- [x] Fix correctness — null check prevents the NRE. Error message includes ProductId for diagnostics. **Correct.**
- [x] Consistent with codebase — `RewardUtils.cs`, `FortuneCache.cs` use same lookup-then-null-check pattern. **Consistent.**
- [x] `MonetizationCache` changes — cosmetic only, no behavior change. `TryGetValue` is strictly better than `ContainsKey` + indexer. **Correct.**

## Notes

### 1. Tech debt claim — SharedLib DLL reference (incorrect)

Executor noted that WebAdmin references SharedLib via DLL path instead of project reference. Verified: `WebAdmin.csproj` line 1854 has a proper `ProjectReference` to `SharedLib.csproj`. Same in MFT. Likely an IDE cache issue, not a project setup problem. Communicated in JIRA comment.
