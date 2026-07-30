---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16161, r16368
jira: https://fishingplanet.atlassian.net/browse/FP-41593
---

# Review: FP-41593 — Restricted-country global chat routing

## Summary

Temporary server-side workaround for global chat in restricted countries: a restricted sender's message is redirected from the selected language channel (g2, g3, ...) to Misc/g0; the originally selected channel is stored per peer and restored when delivering messages back to the client, so the client keeps seeing the channel it selected. Covered by integration tests. A proper fix (client join logic) is deferred to FP-41809 — the client optimistically joins its chosen channel, so the server cannot place it into another channel.

> **Correction (2026-07-29):** the round-1 "twins on both release branches" reading was WRONG. r16158 on MFT was **reverted by r16159** (`"Revert r16158: committed to wrong branch instead of NPN20260602"`); the executor re-committed the fix on NPN as r16161. So the fix lives **only on NPN**, and MFT HEAD is in **pre-fix** state (old broken 3-arg `ReplaceChatChannelLanguageWithMisc(channel, Profile.LanguageId, 0)` still in place). The intake audit `svn log | grep FP-41593` missed r16159 because its message names the reverted revision, not the JIRA id. See the Round-2 correction entry in the journal.

### MFT20260325 (fix NOT present)
- **r16158** — Fix committed here by mistake, then **reverted by r16159**. Net: no FP-41593 fix on MFT. HEAD carries the pre-fix broken redirect.

### NPN20260602 (fix lives here)
- **r16161** — the actual fix (independent re-commit after the MFT revert, not a merge). 5 files: `GameClientPeer_Messaging.cs` (Misc redirect via new local `ReplaceChatChannelLanguageWithMisc()`, `_restrictedChannelMap` store/remove on Join/Leave, `GetOriginalChannel()`), `OutgoingChatServerPeer.cs` (outbound `Channel = peer.GetOriginalChannel(...)`), `ChatChannelController.cs` (log-wording only), `ChatTest.cs` (3 integration tests, `[DoNotParallelize]`, env var via DalFactory), `ClientExtensions.cs` (`TryWaitForChatMessage()` helper)

### Round 2 — test hardening (F-6/F-7 rework)
- **NPN r16368** — Harden restricted-country chat tests against replayed-history false positives (`ChatTest.cs` only)
  - Unique per-run payloads (`$"... {Guid.NewGuid()}"`) + `SentBy(m, client)` sender assertion in every wait predicate — closes F-6
  - `ClassCleanup` mirrors ClassInit's `RunOnGameServer(ForceCachesRefresh)` + `Sleep(1500)` — closes F-7

### Round 2 — test hardening (F-6/F-7 rework)
- **NPN r16368** — Harden restricted-country chat tests against replayed-history false positives (`ChatTest.cs` only)
  - Unique per-run payloads (`$"... {Guid.NewGuid()}"`) + `SentBy(m, client)` sender assertion in every wait predicate — closes F-6
  - `ClassCleanup` mirrors ClassInit's `RunOnGameServer(ForceCachesRefresh)` + `Sleep(1500)` — closes F-7
  - **No MFT twin** (round 1 had twins on both release branches) — see Round 2 journal

## Investigation Journal

- Intake: commit list taken from the executor's JIRA comment at face value (single commit, NPN)
- VCS audit (round 1): `svn log | grep FP-41593` found MFT r16158 and NPN r16161; diffs content-identical; concluded "twins on both branches, no merge needed". **This conclusion was wrong** — see the 2026-07-29 correction below; the grep missed the MFT revert r16159 whose message carries no JIRA id.
- WC freshness: NPN @ 16350, MFT @ 16351 — both ≥ reviewed revs; disk reads authoritative
- HEAD check: later commits on touched files (r16192–r16194 = FP-42124 bans, r16337 = FP-33074 room fencing) do not rework the workaround; `GetOriginalChannel` call present at HEAD (Read of `OutgoingChatServerPeer.cs`)
- Hypothesis disproven (race on `_restrictedChannelMap`): map writes run in `HandleChatMessageOperation` ← `ProcessOperationRequest` ← `OnOperationRequest` → `ExecutionFiber.Enqueue` (`GameClientPeer.cs`); map reads run in the delivery lambda enqueued via `EnqueueSafeAction` → `ExecutionFiber.EnqueueWithStats` (`GameClientPeer_System.cs`). Same per-peer fiber (falls back to `RequestFiber` for both when `executionFiber == null`) — access serialized
- Old `ChatChannelNamingUtils.ReplaceChatChannelLanguageWithMisc(channel, Profile.LanguageId, 0)` (`Shared/Photon.Interfaces/Chat.cs`) verified broken: replaces suffix only when it textually equals profile language ("g7" with profile lang 3 → unchanged; "g13" with lang 3 → "g10"). New local method replaces any language with 0 — explains "fixed replacing chat channel" in the commit message
- Delivery single-point verified: `ChannelPopulation` sets `ctx.Send = true` and flows through the same outbound `ChatMessageEvent` construction (restored); `HandleGetChatMessages` is private-chat only (no channels); `HandleGetChatPlayersCount` is room peer count
- `RejoinAllChannels()` coherence verified: `chatChannelController.ProcessMessage(request)` is called inside `SendMessageUsingChatServer` — i.e. after the redirect — so `channelsJoined` stores the post-redirect channel (g0); rejoin re-sends g0 bypassing the redirect block, map untouched → restore mapping stays valid
- `EnvironmentVariableCache.ChatChannelRestrictedCountries` is `string[]` (`GetStringArrayValue`) — exact-element `Contains`, null country safe, no substring false-positives
- `Shared/Photon.Interfaces` untouched by the diff — no client DLL update forced (executor's stated intent verified); old util left as stub with removal TODO tied to FP-41809
- `AuthorizeChannelMessage` (read method body) gates club channels only — authorize-before-redirect ordering in `HandleChatMessageOperation` is harmless
- Cache-refresh mechanics (`CacheRefreshHelper.RunUpdateLoop`): DB signal polled every 60s (15s dev); `ForceCachesRefresh()` nulls `NextCheck` → pickup within the 100ms loop sleep. ClassInitialize (signal + force + 1.5s sleep) is sound; ClassCleanup signals only → up to one poll interval of residual "ID" restriction on the test game server after the class ends
- Executor claims sweep (Phase 3): redirect+map store — verified (diff); restore via `GetOriginalChannel` — verified (file read + delivery trace); "ChatChannelController.cs supporting changes for the channel map logic" — REFUTED (log wording only); 3 test scenarios — verified statically; env-var set/restore via DalFactory — verified (diff); `[DoNotParallelize]` — verified (diff); "NPN @ r16161" — verified, MFT r16158 omitted; "client optimistically joins its chosen channel" — unresolved (instrument: client repo; context-only, supports no finding); "fixed replacing chat channel" — verified (old util suffix-match bug)
- Unresolved: integration tests not executed in this review (Integrated category requires running game+chat server stack locally; run not attempted). Test code inspected statically only
- Delegation (Step 7): code-reviewer agent — no confirmed findings, 3 sub-threshold observations (malformed water-channel fallthrough; chat-ban/unban rejoin bypass [pre-existing]; env-var mutation in tests safe only while parallelization is off); Codex — 7 findings (5 Medium, 2 Low). Both independently confirmed the fiber-serialization no-race conclusion and the single-delivery-point conclusion
- Delegate re-verification: Codex#6 (tests can pass on replayed history) mechanism CONFIRMED — `ChatChannel.ProcessMessage` Join branch returns all stored channel messages ("return all messages on join"); tests 1 and 2 share the literal payload "hello from restricted", so test 2's echo wait can consume test 1's replayed g0 message (restored to g3 by the map) within the same run
- Delegate re-verification: Codex#3 / agent obs#2 (chat-banned Join tracked raw → unban `RejoinAllChannels` joins the real language channel bypassing redirect) mechanism CONFIRMED statically: `HandleChatMessageOperation` early-returns on `Profile.IsChatBanned` at the top — `chatChannelController.ProcessMessage(messageRequest)` records the PRE-redirect channel; `BanInChat(false)` → `RejoinAllChannels` → direct `SendMessageUsingChatServer` (no redirect block). Pre-existing: the ban early-return sat above the redirect block before r16161 too (visible in the diff's unchanged context)
- Client-side questions (F1 join/leave ordering, unjoined-channel message handling, F4 leak impact, executor's optimistic-join claim) dispatched to an Explore agent over the paired client checkout
- Client verification (Explore over MainClient checkout): `ChatController.ChangeLanguage` sends Leave(old) before Join(new) back-to-back; pond travel leaves before scene switch; `_currentChannels` holds one channel per `MessageChatType`; `ChatController.Enqueue` drops (with warning log) any message whose channel differs from `_currentChannels[type]` — no fall-back display; no restricted-country logic exists client-side (searched). Consequences: Codex#1 unreachable via legitimate client; Codex#4 impact = invisible drop; executor's optimistic-join claim substantiated
- FP-33074 connection (user pointer during findings discussion): the redirect collapses a restricted language switch into a same-channel adjacent Leave+Join pair on g0 — the FP-33074 racy shape; folded into F-1 and cross-noted into that task's backlog (fence-fix coverage + QA STR)
- Findings routing (discussion round with user): F-1 Accepted + FP-33074 backlog cross-note; F-2 Pre-existing (by-design: settings affect new sessions); F-3 Filed → FP-45153; F-4 Accepted; F-5 Skipped; F-6/F-7 Reopened non-blocking (test-hardening follow-up); F-8 Accepted + comment-accuracy remark
- Close: recorded a `--record-only` merge of r16158 into NPN @ r16356 to "close mergeinfo debt". **In hindsight this was based on the wrong twin model** — r16158 was reverted on MFT (r16159) and r16161 is an independent commit, not a merge of r16158, so marking r16158 as merged-into-NPN records provenance for a revision that no longer effectively exists on the source. Harmless (property-only, r16356) but semantically misleading; left in place, flagged here.

### Round 2 (2026-07-28)
- Intake: executor comment 132768 posts only **NPN r16368**; VCS audit (`svn log -r16357:HEAD | grep FP-41593` on both branches) confirms r16368 exists only on NPN — no MFT twin this round. (Round-1 was believed twinned on both at the time; the 2026-07-29 correction below shows MFT never actually carried the fix.) Same executor-quality pattern as round 1. Also present on NPN: an FP-45153 commit (the separately-filed ban/unban bug — out of this review's scope)
- WC freshness: NPN @ 16373 ≥ 16368 — disk authoritative
- F-6 verified: diff read — every `const string` payload → `$"... {Guid.NewGuid()}"`; every wait predicate gains `&& SentBy(m, cN)`; `SentBy` compares `m.Sender` to `client.UserId` (OrdinalIgnoreCase). Sender binding checked per assertion across all 3 tests — each ties to the correct sender (received-from-P1 → c1, received-from-P2 → c2, echoes → own). Negative test (test 2) not weakened: the per-run GUID already makes the text unique, so the added `SentBy` is belt-and-suspenders, not a filter that could mask a real delivery
- F-7 verified: `ClassCleanup` now calls `RunOnGameServer(c => c.ForceCachesRefresh())` + `Thread.Sleep(1500)` (ChatTest.cs:64), mirroring ClassInit (:53)
- env-var deletion (F-7 optional "prefer removing over ''"): executor declined, scope — verified prior art `PushNotificationTests.cs:66-67` (`SharedLib.Tests`) uses `SetEnvironmentVariable(.., null)`. Note: that precedent actually shows `null` could have been passed to drop the `?? ""` materialization without a new DAL method; functionally a no-op (`GetStringArrayValue` treats "", null, absent identically), so not a defect — just a slightly cleaner path than the one kept
- Open question (MFT twin) surfaced to user — believed at the time to be a tests-only divergence (MFT thought to carry the round-1 fix + weaker tests). User's call then: keep hardening on NPN only. **Superseded by the 2026-07-29 correction below** — MFT carries neither the fix nor the tests.

### Round 2 correction (2026-07-29) — MFT never carried the fix; merge attempted then reverted, task pulled from FPA
- Trigger: executor (Yevhenii Shust) messaged that r16158 was reverted and asked for an NPN→MFT merge. Verified by full file history: MFT `GameClientPeer_Messaging.cs` shows r16158 (add) → **r16159 revert** (`"committed to wrong branch"`) → nothing since; MFT HEAD `svn cat` still has the broken 3-arg `ReplaceChatChannelLanguageWithMisc(channel, Profile.LanguageId, 0)`. So the entire round-1 "twin on MFT" premise was false — the fix lives only on NPN (r16161 + r16368 tests).
- Impact on prior conclusions: the round-1 verdict's "both release-hosting branches covered", the close-phase "no merge needed", and the reply to the user that "FP-41593 ships from MFT tomorrow" were all wrong. Root cause of the miss: intake `svn log | grep FP-41593` cannot see a revert commit whose message references the reverted revision, not the JIRA id (logged in `review-process-observations`).
- Action attempted: cherry-pick merge r16161 + r16368 (NPN→MFT), skipping r16367 (FP-45153, separate task) and r16192-16194 (FP-42124). Merge applied cleanly in the MFT WC (5 files + root mergeinfo, no conflicts; fix and hardened tests verified present) — then the user cancelled before commit and it was `svn revert`-ed out of the WC. Nothing committed to MFT; MFT baseline untouched.
- Release decision (user): **FP-41593 is not shipping with FPA.** The fix stays on NPN (rides 2026.6 Australia); a server patch may carry it earlier. MFT deliberately left in pre-fix state. No merge performed.

## Findings

### F-1: Single-key `_restrictedChannelMap` collapses all logical language channels onto one misc key [Low]

**Description:** In `GameClientPeer_Messaging`, the map holds one original channel per redirected (misc) key, and a redirected Leave both removes the mapping and drops the peer's only physical membership. A Join-new-before-Leave-old sequence would orphan the client's channel silently. Additionally, the collapse turns a restricted player's language switch (client: Leave g3 + Join g2 — safely different channels) into an adjacent same-channel pair on the chat server (Leave g0 + Join g0) — exactly the racy adjacent-op shape whose apply-order inversion is documented in FP-33074 (live-confirmed on busy prod); an ordinary player's language switch never produces such a pair. Severity-justifying: unreachable via legitimate client ordering alone; the FP-33074-shape exposure is rare (language switch), restricted-audience-only, self-healing (next join + history replay), and any FP-33074 ordering/fence fix covers it.

**Investigation:** `ChatChannel.ProcessMessage` (chat server) read — participants is a Contains-guarded set: double Join idempotent, one Leave removes membership entirely. Client checkout (MainClient) verified via Explore agent: `ChatController.ChangeLanguage` always sends Leave(old) then Join(new) back-to-back; `_currentChannels` allows one channel per type — the failure ordering cannot be produced by the shipped client. A modified client gains nothing (g0 is legitimately joinable by restricted users). FP-33074 root-cause read (user pointer): same-channel adjacent Leave+Join apply-order inversion live-confirmed on busy Steam prod (F5 cycle #3, J-before-L → removed from participants) — the redirect newly subjects restricted language switches to that mechanism; cross-noted into the [FP-33074 backlog](../../tasks/FP-33074--chat-messages-disappear/backlog.md) so the fence/ordering fix accounts for this op source.

**Resolution:** Accepted — documented design limit of the temporary workaround; FP-33074-shape exposure delegated to that task's fence/ordering fix (backlog cross-note); superseded entirely by the FP-41809 proper fix.

**Discovered by:** Codex; FP-33074 connection — user pointer + skill recon.

### F-2: Mid-session restricted-list flips leave chat-server membership and the map unreconciled [Low]

**Description:** `ChatChannelRestrictedCountries` is evaluated per operation, but a flip never migrates existing subscriptions or rebuilds `_restrictedChannelMap`: newly-restricted users keep their real-language subscription while sends go to g0 (no echo); newly-unrestricted users keep g0 membership with a stale mapping (Misc traffic relabeled) until relogin/channel switch.

**Investigation:** Send-path and join-path read in `HandleChatMessageOperation`; pre-fix code verified (diff context) to have the same non-migration — the fix actually improves the restricted→unrestricted direction (traffic stays visible instead of being dropped). Client verified to drop unmatched-channel messages from view — impact is missed messages, no corruption.

**Resolution:** Pre-existing — inherent to the workaround approach; confirmed by design intent (restriction-list changes are expected to affect new sessions only). No separate FP-41809 note — the whole redirect logic is superseded there anyway.

**Discovered by:** Codex; skill recon (independently).

### F-3: Chat-ban → unban rejoin bypasses the restricted-country redirect [Medium]

**Description:** In `HandleChatMessageOperation` the `Profile.IsChatBanned` early-return sits above the redirect block yet still records the Join via `chatChannelController.ProcessMessage(messageRequest)` with the PRE-redirect channel; on unban, `BanInChat(false)` → `RejoinAllChannels()` sends that raw channel directly through `SendMessageUsingChatServer`, bypassing redirect and map population. A restricted player banned at Join time and unbanned mid-session ends up subscribed to the real language channel (reads it; own sends still go to g0) — the compliance goal is defeated for that session. Severity-justifying: compliance-defeating, but narrow trigger and pre-existing.

**Investigation:** Control flow traced: early-return at the top of `HandleChatMessageOperation` (file read); `RejoinAllChannels` → direct `SendMessageUsingChatServer` overload (file read); `BanInChat` unban branch calls `RejoinAllChannels` (`GameClientPeer.cs`, file read). Pre-existing: the ban early-return sat above the (old) redirect block before r16161 too — visible in the unchanged diff context. Both delegates surfaced it independently.

**Resolution:** Filed → FP-45153 (Bug, parent FP-41583, assigned to the executor; linked Relates to FP-41593 and FP-41809). Pre-existing, so filed separately rather than blocking this review or riding FP-41809.

**Discovered by:** Codex; code-reviewer agent (independently).

### F-4: In-flight message delivered after Leave arrives with the physical (misc) channel label [Info]

**Description:** A redirected Leave removes the mapping on the game server before the chat server processes the leave; a message already fanned out to the old membership can then be delivered with `Channel = "g0"` (no mapping to restore).

**Investigation:** Queue-ordering reasoning over the shared peer fiber (delivery actions and operation processing interleave in enqueue order); client behavior verified via Explore agent — a message whose channel is not in `_currentChannels` is silently dropped from view (warning log, cache only). Transient and invisible to the user who just left the channel.

**Resolution:** Accepted.

**Discovered by:** Codex.

### F-5: Prefix-only channel recognition aliases malformed names into real misc channels [Low]

**Description:** `IsGlobalChannelName`/`IsWaterBodyChannelName` are `StartsWith("g")`/`StartsWith("w")` and `AuthorizeChannelMessage` validates only club channels, so a restricted user's malformed channel string ("garbage", "g2_extra") aliases into the real g0 (and can overwrite/remove a live map entry). Old code no-op'd malformed names instead of aliasing them.

**Investigation:** `ReplaceChatChannelLanguageWithMisc` (new, file read) maps any `g*` to `GetGlobalChannelName()`; `AuthorizeChannelMessage` body read (club-only). Requires a modified client; grants nothing beyond legitimately-joinable Misc; map pollution is self-inflicted. Both delegates surfaced it; agent kept it sub-threshold for the same reachability reason.

**Resolution:** Skipped — protocol-abuse hardening out of scope for a temporary workaround.

**Discovered by:** Codex; code-reviewer agent (independently).

### F-6: Integration tests can false-pass on join-time channel-history replay [Medium]

**Description:** `ChatChannel.ProcessMessage` returns the full stored message list on Join ("return all messages on join"), delivered to the joiner through the same patched path. Tests 1 and 2 in `ChatTest.cs` share the literal payload "hello from restricted" and wait predicates match `Message` text only — test 2's echo wait can consume test 1's replayed g0 message (restored to g3 by the map), and any test can consume a previous run's message while the server process persists. The declared regression coverage can pass without the code under test working.

**Investigation:** Replay mechanism verified by reading `ChatChannel.ProcessMessage` Join branch; payload sharing and text-only predicates verified in the diff; delivery path of replayed content to the joiner confirmed (same `HandleIncomingMessage` → outbound construction). Not executed at runtime (unresolved above).

**Resolution:** Reopened (non-blocking) — returned to the executor for test hardening: unique per-run payloads (e.g. GUID suffix) + sender assertion in wait predicates. Does not block the fix itself (ship-and-reopen).

**Discovered by:** Codex; mechanism verified by skill recon.

### F-7: Test `ClassCleanup` restores the DB value but not the live server cache [Low]

**Description:** `ClassInitialize` does signal + `RunOnGameServer(ForceCachesRefresh)` + 1.5s sleep; `ClassCleanup` only signals — the shared test game server keeps `ChatChannelRestrictedCountries = "ID"` for up to one poll interval (60s, 15s dev) after the class ends, and `_savedRestrictedCountries ?? ""` materializes the variable where it may have been absent.

**Investigation:** Poll mechanics verified in `CacheRefreshHelper.RunUpdateLoop` (`refreshSignalCheckTimeout` 60/15s; `ForceCachesRefresh` nulls `NextCheck` → pickup within the 100ms loop sleep). Impact bounded: only affects tests creating players with Country="ID" in that window. All three reviewers surfaced it independently.

**Resolution:** Reopened (non-blocking) — same follow-up as F-6: mirror the init sequence in cleanup (signal + force refresh); prefer removing the variable over writing "" if the provider supports it.

**Discovered by:** skill recon; Codex; code-reviewer agent (independently).

### F-8: Commit bundles unrelated log-wording polish misdescribed in the JIRA comment [Info]

**Description:** The `ChatChannelController.cs` hunk is purely chat log-message wording (join/leave/expire lines); the JIRA comment calls it "supporting changes for the channel map logic", which it is not. Harmless content, inaccurate description.

**Investigation:** Diff hunk read in full — only `Sys.Log` string changes; no channel-map-related code present. Claim refuted in the Phase 3 sweep.

**Resolution:** Accepted — note to executor about comment accuracy.

**Discovered by:** skill recon.

## Notes

- MFT r16158 and its revert r16159 are not posted in the JIRA comment (only NPN r16161); `ClientExtensions.cs` is absent from the comment's file list. This is the executor-quality gap that hid the revert: had the revert been linked to the task, the round-1 "twin" misread would not have happened (the executor acknowledged this on 2026-07-29).
- Executor's "client optimistically joins the channel of its choice" claim is substantiated by the client-repo check (no restricted-country logic client-side; view filtered by `_currentChannels`).
- Release note: **fix present only on NPN** (r16161 + r16368 tests); MFT is pre-fix (r16158 reverted by r16159). LBM (Stable) has no FP-41593 commits. Per the 2026-07-29 decision FP-41593 does not ship with FPA — it rides 2026.6 (NPN) or an earlier server patch; a NPN→MFT merge would be required to put it in an MFT-hosted release. *(Original round-1 note claimed "present on both release-hosting branches" — wrong, see correction.)*

## Verdict

**Approve (ship-and-reopen).** The fix is mechanically sound and ships as-is; the task returns to the executor for non-blocking test hardening (F-6, F-7).

Basis:
- No data race on `_restrictedChannelMap`: writes (operation path) and reads (chat-server delivery path) are serialized on the same per-peer `ExecutionFiber` — traced, and independently confirmed by both delegated reviewers
- Single delivery point: every channel-carrying event to the client (messages, join-time history replay, `ChannelPopulation`) flows through the one patched outbound construction; private-chat history and player-count paths carry no channels
- Root cause of the original symptom confirmed: the old `ChatChannelNamingUtils.ReplaceChatChannelLanguageWithMisc` silently no-op'd when the channel's language suffix didn't textually match `Profile.LanguageId`; the new shape-based replacement fixes that class of failure
- Client-side contract verified in the client repo: strict Leave-before-Join ordering, one channel per type, unmatched-channel events dropped from view, no restricted-country logic client-side (substantiates the workaround's premise and FP-41809's necessity)
- The fix is on NPN (r16161). `Shared/Photon.Interfaces` untouched — no client DLL update forced. *(Round-1 recorded "twin commits on both release branches, no merge needed" — WRONG: r16158 was reverted on MFT (r16159); MFT carries no fix. See the 2026-07-29 correction in the journal. The technical soundness above stands — it was verified against the NPN code — but the branch-coverage claim did not.)*
- All Medium-and-below concerns resolved: F-3 filed as FP-45153 (pre-existing), F-1 cross-noted into the FP-33074 fence-fix backlog, the rest accepted/skipped as documented per finding

Reopen scope (non-blocking): unique per-run test payloads + sender assertions (F-6); mirror the init cache-refresh sequence in `ClassCleanup` (F-7).

Executor remarks for the closing JIRA comment: MFT r16158 not posted in the task comment; `ClientExtensions.cs` absent from the comment's file list; `ChatChannelController.cs` hunk is log-wording polish, not "channel map logic" (F-8).

**Verification scope:** static code inspection (server repo at the reviewed revisions and HEAD) plus cross-repo client-source verification; the three new integration tests were read but not executed (running them requires the local game+chat server stack). The claim "tests pass" remains the executor's; the review verified test *logic* (and found the F-6 replay weakness), not test *runs*.

## Round 2 verdict (2026-07-28) — Approve, resolved

The reopen items are closed correctly (NPN r16368, `ChatTest.cs`):
- **F-6** — every payload is now per-run unique (`$"... {Guid.NewGuid()}"`) and every wait predicate adds a `SentBy(m, client)` sender match; the replayed-history false-positive path is closed. Sender binding verified correct per assertion across all three tests; the negative test is not weakened.
- **F-7** — `ClassCleanup` mirrors ClassInit's forced cache refresh. The optional env-var *removal* was declined with a verified precedent (`PushNotificationTests` uses `SetEnvironmentVariable(.., null)`); functionally a no-op, accepted.

Divergence discussed with the user (believed then to be tests-only). **Superseded by the 2026-07-29 correction:** MFT carries neither the fix nor the tests; the whole of FP-41593 is NPN-only, and the task was pulled from FPA. The round-2 rework itself (r16368) is correct as reviewed above — this note only corrects where the code lives.

**Verification scope (unchanged from round 1):** static review of the diff at r16368 against the surrounding test code; the integration tests were read, not executed.
