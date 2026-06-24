---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16215, merged to NPN @ r16216
jira: https://fishingplanet.atlassian.net/browse/FP-44478
---

# Review: FP-44478 — [Prod bugs] The player receives the requested item from a clubmate twice

## Summary

Prod bug: a player who requested an item in club chat, received it from a clubmate, and claimed it, gets the same item re-delivered on the next login. Per the executor's analysis the root cause is club-chat channel message ordering: when two or more chat messages share an identical timestamp (down to the millisecond — e.g. a bundle/offline grant delivering several products at the same instant), message ordering breaks, old-message cleanup runs incorrectly, and the per-profile record of "bait already delivered" is lost. The lost record re-triggers item delivery on next entry, and the same ordering bug can also manifest as disappearing chat history.

Fix is expected to close both symptoms: chat-history loss on equal-timestamp messages, and the premature cleanup of the delivered-bait list.

## Scope

- **MFT r16215** — Fix chat channel message ordering (club bait re-delivery + chat history loss)
  - `ChatChannel.AddMessage` — out-of-order insert index `SkipWhile` → `TakeWhile` (the core ordering bug)
  - `ClubAdapter_ClubEvents.___ReceiveClubChannelExpiration` — clamp client-reported expiration horizon to the canonical TTL horizon (`now - MessageLifetime.ClubChannel - 1h`)
  - `ChatChannelsCacheTest` — regression test `AddMessage_out_of_order_timestamps_firstMessage_stays_oldest` (+ helpers)
  - `Club.cshtml` (WebAdmin) — "Open channel chat" link to `/Player/Chat?channel=club{id}&showTech=True`
- **NPN r16216** — Merge from MFT r16215 (identical content, verified via `svn diff -c 16216`)

## Investigation Journal

- Phase 1 intake: JIRA read, card created. Executor = Yuriy Burda (author of r16215, per JIRA comment), `customfield_11224` confirms. Assignee = reviewer (Stanislav).
- Branch context: r16215 is on MFT (Content). NPN (Code) was copied at MFT:16130; 16215 > 16130, so the fix is NOT inherited by Code — explicit merge already done by executor at NPN r16216 (verified: merge diff matches the fix across all four files). **Close phase will NOT need a merge.**
- WC freshness: WC at r16227 ≥ 16215/16216 — disk reflects post-fix state, files read directly.
- Root-cause verification of `SkipWhile`→`TakeWhile`: `messages` is kept ascending-sorted by `Timestamp` (oldest at index 0). Correct insert index for an out-of-order message = count of elements strictly `<` it = `TakeWhile(...).Count()`. Old `SkipWhile(...).Count()` returned the count of elements `>=` it (the complementary partition), placing the message at a reversed position and corrupting the sort. Hand-traced the test's 5-message sequence under both old and new code: old → `firstMessage` = newest (day9), new → oldest (day0). Invariant holds by induction from empty regardless of arrival order (append branch only fires on a strict new max).
- `firstMessage` chain: `ProcessMessage(Join)` returns `messages.FirstOrDefault()` (index 0). Feeds the client channel-expiration horizon reported back via `___ReceiveClubChannelExpiration`. A mis-sorted list (old bug) made `firstMessage` newer than the true oldest → horizon too new → `RemoveExpiredClubEvents` (removes `Timestamp < horizon`) purged still-live BaitRequest/Response events → donation re-delivered on rejoin.
- Clamp correctness: `RemoveExpiredClubEvents` deletes `Timestamp < chatHorizon`; clamp sets `horizon = min(timestamp-1h, now - 14d - 1h)` so it can only shrink (remove fewer), never over-purge. `MessageLifetime.ClubChannel = 14` (days); clamp horizon matches the canonical horizon already used in `___ReceiveClubEvent`/`EnsureClubEvents`. Clamp is independently necessary: channel trimming (`EnsureChannelSize`, club cap 500) can drop the truly-oldest message, so even with correct ordering `firstMessage` may be newer than 14d — the clamp prevents premature purge in that case too.
- WebAdmin link: plain `<a href>` in `Club.cshtml` (not a Kendo `ClientTemplate`) — Kendo `+`-encoding gotcha N/A; `&amp;` correctly entity-encoded; modifies an existing compiled `.cshtml`, so no `WebAdmin.csproj` `Content` entry needed.
- Scope check: bug and fix are server + WebAdmin only; no client-side counterpart referenced in JIRA.
- Reentrancy check (via code-reviewer agent): `ProcessMessage` holds `channelOpLock` then calls `AddMessage`, which re-takes the same lock. C# `lock`/`Monitor` is reentrant on the same thread — no deadlock. `maxMessageTimestamp` only mutated inside `AddMessage`, always under the lock. Thread-safe.
- Independent code-reviewer agent: all checked points CONFIRMED-CORRECT (insertion-index fix, firstMessage→horizon chain, clamp direction + independent necessity, locking, no other `SkipWhile` insertion-index sites in chat/club code, WebAdmin link, regression test discriminates old vs new). No issues at confidence ≥ 80.
- Post-review damage recon (separate from verdict): re-deliveries are traceable in `clubLog` as byte-identical `Received bait #…`/`Received ClubToken …` lines repeated for one `(UserId, requestId)`. Signal, window (purge path from r10273, retention-bounded lower bound), platform scope and runnable Mongo aggregations captured in [`damage-recon.md`](damage-recon.md) + [`damage-recon-queries.js`](damage-recon-queries.js). Queries syntax-validated on local Mongo 4.4.13; prod runs pending (manual, per-platform, timeout risk).

## Findings

No blocking or actionable findings. The fix is correct and complete; both reported symptoms (donation re-delivery, chat-history loss on equal-timestamp messages) trace to the corrected ordering.

### F-1: Tie-order within an identical millisecond is arrival-dependent [Info]

**Description:** With `TakeWhile(m => m.Timestamp < message.Timestamp)`, a new message whose `Timestamp` equals existing entries is inserted *before* them. For newest-first arrival (the persistence-load pattern) this reverses intra-tie order (in the regression test, `jun01-dup` lands at index 0, ahead of `jun01`). Only sub-millisecond display order is affected.

**Investigation:** Hand-traced + confirmed by code-reviewer agent. `firstMessage` is `messages[0].Timestamp`; for tied messages that value is identical regardless of which tie member is first, so the expiration horizon and dedup purge are unaffected.

**Resolution:** Accepted — zero functional impact. Noted only for completeness.

**Discovered by:** code-reviewer agent.

## Verdict

**Approve.** The `SkipWhile`→`TakeWhile` change is the correct insertion-index fix and restores the ascending-sort invariant of the channel message list, so `firstMessage` is again the true oldest message; the horizon clamp in `___ReceiveClubChannelExpiration` is correct in direction (can only under-remove) and independently necessary for the channel-trim (500-cap) path. Regression test is valid (fails on old code, passes on new). Merge to Code (NPN r16216) already landed and matches the fix. No merge action required at close.
