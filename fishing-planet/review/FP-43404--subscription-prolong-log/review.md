---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16056
jira: https://fishingplanet.atlassian.net/browse/FP-43404
---

# Review: FP-43404 — [Steam][AdminLogs] Misleading "Subscription end date was prolonged ... to (NULL)" on repeated paid-pack delivery

## Summary

When a player who already owns a subscription-bearing pack (e.g. Valkyrie Saga Pack with 60d subscription) is granted the same pack again via Admin -> Player -> Tools, no subscription is actually re-delivered (per FP-31345 guard). The Inventory/License MergedLog, however, still recorded "Subscription end date was prolonged on 60 days to (NULL) by Product #...", which is misleading. The fix makes product-delivery logging respect the same subscription-delivery guard so that a meaningful "Subscription was not prolonged..." message is logged instead.

## Scope

- **MFT r16056** — Fixed misleading subscription log for repeated paid pack delivery from WebAdmin
  - Product delivery logging now uses the same subscription-delivery guard as `PutProductToProfile`
  - When a Steam/PS starter-pack subscription was already delivered and is skipped, MergedLogs writes "Subscription was not prolonged..." instead of "... prolonged ... to (NULL)"

## Findings

### F-1: Double space (and trailing whitespace) in new "not prolonged" log message [Low]

**Description:** `LogSubscriptionNotProlonged` (ProductHelper.cs) builds `"...already delivered " + By(source)`. `By()` returns `" by " + source` (leading space), so the rendered log line is "...already delivered  by ..." — a double space. Sibling log messages in the same file do not have this trailing space. Additionally the new branch in `PutProductToProfileAndLog` has trailing whitespace after the opening braces (`{     ` and `{ `), against `.editorconfig` (trim trailing whitespace). Logging-text only; no functional impact.

**Investigation:** Read `By()`/`FormatDate()` in `FormatExtensions.cs` (By prepends " by "); confirmed by code-reviewer agent (Item 4/6). All other messages in the file omit the trailing space.

**Resolution:** Skipped — non-blocking cosmetic. Recommend executor drop the trailing space and brace whitespace opportunistically (no reopen warranted for a log-string nit).

**Discovered by:** skill recon, confirmed by code-reviewer agent.

### F-2: `FormatDate(expireDate)` -> `FormatDate(profile.SubscriptionEndDate)` touches a shared method beyond AdminLogs scope [Info]

**Description:** The HasValue branch of `LogSubscriptionUpdated` was changed to log the profile's actual `SubscriptionEndDate` instead of the requested `expireDate`. This shared method is also called from the PS/console path (`GameClientPeer_Monetization.cs` ~306/350). The commit message frames the fix as scoped to AdminLogs and states other areas were "left unchanged", yet this is a real edit to a shared method. Also, the call site changed from passing `null` to `expireDate`.

**Investigation:** Grepped all `LogSubscriptionUpdated` callers; traced `UpdateSubscriptionEndDate` -> `UpdatePremiumSubscriptionEndDate` (assigns `SubscriptionEndDate = newEndDate = expireDate.Value`, no clamping/term-addition). Code-reviewer agent (Item 3) confirmed: for both GameClientPeer callers `profile.SubscriptionEndDate == expireDate.Value` after delivery, so the rendered output is identical -> the `FormatDate` change is a no-op for existing callers. The only behavioral effect of `null`->`expireDate` at the admin call site is that an admin grant carrying an explicit expireDate now logs "changed to ..." instead of "prolonged on N days to ..." — an improvement, consistent with the fix intent.

**Resolution:** Accepted — verified benign; arguably more correct (logs actual end date). Noted only because it slightly exceeds the stated commit scope.

**Discovered by:** skill recon, confirmed by code-reviewer agent.

### F-3: Fix covers only the direct delivery path; tracked path stays silent on the skip [Low]

**Description:** Product delivery routes through `ProductDeliveryService.DeliverProduct`, which switches on the `UseTrackedDelivery` env flag between the direct path (`PutProductToProfileAndLog`, where r16056 lives) and the tracked path (`TrackedProductDelivery.DeliverProduct`). In the tracked path, the StarterKit/single-DLC guard (`TrackedProductDelivery.cs`, the `IsStarterKit && SingleDlcDelivery && already-given` check) does an early `return` BEFORE the subscription log line — so on a repeated pack the tracked path logs nothing at all (neither the old "(NULL)" nor the new "not prolonged"). The tracked path never had the misleading-"(NULL)" bug, but it also does not emit the ticket's "expected" informative message. So the fix only takes effect when `UseTrackedDelivery` is off.

**Investigation:** Traced `ProductDeliveryService.DeliverProduct` (direct vs tracked branch); read `TrackedProductDelivery` subscription-delivery method (guard returns before the LogLicense call). Confirmed `PremiumLedger` (`UpdatePremiumSubscriptionEndDate` -> `SaveToPremiumLedger`) is a write/display-only audit sink — `GetPremiumLedger` is read only by the WebAdmin `PlayerPremiumLedgerModel`, no read-back-and-redeliver — so double-delivery cannot originate there; the no-double-delivery behavior is enforced by the single-DLC guards in both paths (FP-31345), not by this commit. Prod confirmed running direct delivery (`UseTrackedDelivery` off) by the reviewer, so r16056 is effective on prod today; the gap is latent, surfacing only if/when prod migrates to tracked delivery.

**Resolution:** Accepted (non-blocking) — fix is effective on prod (direct). Recommend the executor add the parity "not prolonged" log to `TrackedProductDelivery` as part of the tracked-delivery migration so the message survives the switch. Candidate for the monetization/delivery module backlog rather than blocking this ticket.

**Discovered by:** reviewer's question on PremiumLedger / double-delivery, traced during review.

## Verdict

**Approve.** The fix is correct and safe to ship.

- `ShouldDeliverSubscription` extraction is logically identical to the original inline guard; the pre-computed value in `PutProductToProfileAndLog` always matches the guard used inside `PutProductToProfile` (nothing mutates `StartersGivenAll`/`product`/`singleDlcDelivery` between the two evaluations).
- The "not prolonged" branch fires exactly when product has a subscription, is a StarterKit, on a single-DLC platform, and was already delivered — the message text accurately describes that condition, resolving the misleading "...prolonged ... to (NULL)" log.
- F-1 (cosmetic double space) is the only actionable item, non-blocking.
- Prod runs direct delivery (`UseTrackedDelivery` off), so the fix is effective on prod. F-3 (tracked path stays silent on the skip) is a latent parity gap, non-blocking, to be addressed with the tracked-delivery migration.
- r16056 does not touch delivery; the no-double-delivery behavior is enforced by the single-DLC guards (FP-31345), and `PremiumLedger` is an audit/display-only sink (not a re-delivery driver).

Already present in Code branch (NPN) via branch copy from MFT@16130; no explicit merge required.

## Investigation Journal

- Intake: JIRA executor field (`customfield_11224`) = Yevhenii Shust, matches commit author of r16056. No hygiene warning.
- No existing review folder for FP-43404 -> new review (not a re-review).
- Branch-copy inheritance: MFT = Content; Code = NPN20260602 created from MFT20260325:16130. r16056 <= 16130 -> fix inherited in Code via branch copy. Verified: `svn cat` of `ProductHelper.cs` on NPN URL contains `LogSubscriptionNotProlonged`; `svn log --stop-on-copy` confirms NPN `from /branches/MFT20260325:16130`. No explicit merge to Code required.
- WC at r16227 (>= r16056) and changed files not in dirty list -> disk reflects post-fix state; read from disk directly.
- F-2 PS-path concern resolved via code-reviewer agent: traced `UpdateSubscriptionEndDate`/`UpdatePremiumSubscriptionEndDate` -> `FormatDate` change is a no-op for existing GameClientPeer callers.
- Reviewer raised double-delivery / PremiumLedger hypothesis. Traced delivery routing (`ProductDeliveryService` direct vs tracked) and PremiumLedger usage (write/display-only). Conclusion: double-delivery prevented by single-DLC guards in both paths (FP-31345), ledger is not a re-delivery driver; r16056 is log-text-only. Surfaced F-3 (tracked path silent on skip). Prod = direct delivery per reviewer -> fix effective; F-3 latent.
