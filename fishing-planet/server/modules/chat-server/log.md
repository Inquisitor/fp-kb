---
module: chat-server
---

# Chat server - decision log

Append-only. `Finding:` = observed/unverified-intent; decisions carry rationale.

- 2026-06-30 [MFT] Finding: **delivery membership is unfenced.** `ChatChannel.participants` is a bare
  `List<string>` keyed on `Sender`, with no node/session id or sequence, while the sibling routing store
  `PlayerCache2` *is* fenced (newest-join-wins, gameId-matched leave). Adjacent Leave+Join reordered by
  the ThreadPool dispatch (`UseThreadPoolExecutor`, from FP-25995) drops the member. FP-33074 mechanism #1;
  proven live on Steam prod.
- 2026-06-30 [MFT] Finding: **non-persistent club channels are evicted with their members.**
  `TryRemoveUnusedChannels` removes idle club/UGC/FTG channels on a message-activity timer; the rebuilt
  channel has empty `participants` and emits no Leave. FP-33074 mechanism #2; deterministic, the dominant
  historical cause.
- 2026-06-30 [MFT] Finding (INFERRED - confirm with team): club/UGC/FTG are non-persistent because they are
  unbounded in count (vs the fixed persistent global+waterbody set) and must be reclaimed to bound memory.
  This is the basis of the Pillar 2 fix decision - if the real reason differs, revisit.
  - **RESOLVED 2026-07-07 (svn history):** the inference was wrong as intent. The channel machinery + 30-min
    inactivity expiry were born together for **UGC competitions** (FP-13221, r5610, 2019-01) where session
    lifetime is correct; `persistent` arrived later as a pond/global exception (FP-17330, r7648, 2020-04);
    club channels inherited the UGC session default unrevisited. The memory-bounding constraint remains a
    valid engineering fact, but it was never a deliberate club-channel decision - the FP-33074 fix breaks
    no one's design intent.
- 2026-06-30 [MFT] Finding: presence (`PlayerCache2`) is **not purged on game-node disconnect** -
  `GameServerCollection.OnDisconnect` only drops the peer; a hard node crash (no final `RemovedUsers`)
  leaks that node's players in presence.
- 2026-06-30 Decision: fix both root causes with **one fenced, durable membership store** the delivery
  loop reads (inline membership ops + `nodeId` fence + `seq` insurance; membership-driven channel lifetime;
  presence reconcile; membership-age canary). Rationale + alternatives:
  [FP-33074 fix-design](../../../tasks/FP-33074--chat-messages-disappear/artifacts/fix-design.md).
- 2026-07-07 Decision (supersedes the fence shape above): after adversarial review, the fence is
  **hybrid room-primary / node-fallback** (`{roomId, nodeId, peerGen, seq, joinedAt}`) - node-only missed the
  same-node room move. Enabling Finding: `ChatMessageEvent.Room` IS relayed game->chat
  (`OutgoingChatServerPeerBase.DoSendMessage`) in the presence `GameId` domain (both = room `Name`), and is
  dropped only by the `ChatMessage` ctor; but the static `GameClientPeer_Messaging.SendMessageUsingChatServer`
  overload (used by `RejoinAllChannels`/`TearDown`) omits `Room` - hence the node fallback.
- 2026-07-07 Finding: `IncomingGameServerPeer.OnEvent` deliberately admits `SendChatMessage` from
  **unregistered** peers (`ServerId` null) - membership ops cannot assume a node identity exists; the fix
  rejects identity-less Join/Leave/Expire.
- 2026-07-07 Finding + Decision: the `Expire` chat command (`ChatChannelsCommands.Expire` -> `AbsoluteExpireDate`)
  is **dead end-to-end** - introduced for FP-13595 "UGC: chat integration - absolute expiration" (2019-03,
  r6093/r6094, dk), but the UGC caller never shipped: zero server-side production senders, zero client call
  sites for `ExpireChatChannel` (both client branches), and PhotonTool (`Photon/tools/PhotonHelper`) has no
  channel-close command (reads + generic `e` eval only). Its only reachable effect would be a silent member
  drop (FP-33074 failure mode #2). Decision: retire under the FP-33074 fix (no-op + log). Do not design
  close-channel semantics until a real consumer appears.
- 2026-07-13 [NPN] Finding: FP-41809 added a game-side **restricted-country channel redirect**
  (`GameClientPeer_Messaging`): global/waterbody joins+messages from restricted countries are rewritten to the
  **misc ("all") channel names** (`g7`->`g0`, `w130_13`->`w130_0`) with a per-peer reverse map. Misc channels are
  part of the PERSISTENT set (`CreatePersistentChannels`), so the redirect does not interact with channel
  eviction or the FP-33074 membership fence. Marked TODO-temporary in code (client to take over selection).
