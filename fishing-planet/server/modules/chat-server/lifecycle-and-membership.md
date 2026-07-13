---
module: chat-server
title: 'Chat server - lifecycle and membership'
---

# Chat server - lifecycle and membership

Why this doc exists: the chat server's failure modes (FP-33074) are invisible in the code alone -
they live in *ordering*, *object lifetime*, and a *two-store asymmetry*. This captures that context.
To read the logs themselves: [minilog-format.md](minilog-format.md).

## Apps and connections

ChatServer is a standalone Photon app (alongside Master / Game / Club). A player does not talk to it
directly - the **game node relays** chat: client -> game node (`OutgoingChatServerPeer`) -> chat node
(`IncomingGameServerPeer`).

**Invariant / gotcha:** the chat path is independent of the fishing (game) session. A game-node
reconnect (travel, sleep/resume, crash-recover) does **not** tear down chat membership - chat keeps
working across it. (FP-33074: a player kept chatting after his game session had disconnected;
membership is bound to the chat channel object, not to the game session.)

## Inbound pipeline and the reorder (root cause #1)

`HandleIncommingMessage` -> `EnqueueChatMessage` -> `IncomingQueue` (a **single** FIFO worker thread)
-> `ChatProcessor.ProcessMessage` -> `Executor`.

**Gotcha:** the single FIFO thread preserves order only *up to* `ProcessMessage`. On prod the
`Executor` is `UseThreadPoolExecutor`, so `ProcessMessage` immediately hands the real work
(`ProcessMessageSync` -> participant mutation) to the ThreadPool and returns. Adjacent ops then run
**concurrently** and apply out of order. The per-channel lock serializes the two mutations but does
not preserve their intended order - whichever pool work item wins the lock applies first.

**Why ThreadPool (offstage reason):** introduced under FP-25995 "improve chat queuing" (~2023-05) for
throughput. Do not "simplify" it away without addressing the ordering it breaks.

Result: a client's adjacent Leave + re-Join of a club channel can apply Join-then-Leave, dropping the
player from `participants` while he believes he is subscribed (he got the join ACK). His messages are
then accepted and persisted but never delivered back to him. FP-33074 mechanism #1 (proven on Steam prod).

## Two membership stores (the load-bearing asymmetry)

| Store | Question | Keyed on | Fenced? |
|---|---|---|---|
| `PlayerCache2` | WHERE to deliver (user -> node) | userId + `GameState` (gameId) | **Yes** - newest-join-wins; `OnLeft` removes only if `gameId` matches ("Outdated leave request detected") |
| `ChatChannel.participants` | WHO is in a channel | bare `Sender` (userId) | **No** - no node/session id, no sequence |

Both are fed by the game node, but by different streams: presence via `UpdateGameEvent`
(`HandleUpdateGameState`, carries `GameId`); channel ops via the chat-message queue, which carries no
node id. The source node *is* known at `HandleIncommingMessage` (the peer `ServerId`) but is dropped
when building `ChatMessage` (and `ChatMessageEvent.GameId` is not populated on the game relay's
outbound chat op). So routing was hardened against the cross-node stale-leave and delivery membership
was not - that gap is mechanism #1's home.

## Channel lifetime and eviction (root cause #2)

`ChannelMemoryCache` holds channel objects in two classes:
- **Persistent** - global (`g*`) + per-pond waterbody, created once in `CreatePersistentChannels`, never evicted.
- **Evictable** - club / UGC / FTG, created non-persistent on first use (`GetOrCreateChannel(..., persistent:false)`).

`TryRemoveUnusedChannels` removes an evictable channel once it is idle past `ExpireDate`
(= last *message* activity + `ChannelInactivityTimeout`). The expiry is refreshed by **message traffic
only**, not by membership - so an occupied-but-quiet channel still expires. The next message rebuilds
it via `GetOrCreateChannel`: history reloads from Mongo, but **`participants` is empty** and **no
per-user Leave is emitted**. Every "joined" member is silently dropped.

**Why evictable (verified from history):** the channel machinery was born for **UGC competitions**
(FP-13221, r5610, 2019-01) - already with the 30-min inactivity expiry, which is *correct* for a UGC
session channel (dies when the competition goes quiet). The `persistent` flag arrived a year later as an
exception for pond/global chat (FP-17330 "Pond Chat v.0", r7648, 2020-04). Club channels reuse the UGC
machinery and inherited its session-lifetime default, which does not fit long-lived club membership -
nobody revisited it. Separately, an engineering fact stands regardless of intent: club/UGC/FTG channels
are unbounded in count, so *some* reclaim is needed; the defect is that eviction throws away membership
(live state, not rebuildable) together with the message cache (bounded, Mongo-backed, rebuildable).

FP-33074 mechanism #2 (deterministic; the dominant historical cause - matches "messages disappear after
a while fishing", "only club chat", "no Leave in sys log yet not receiving", "changing location frees them up").

## Delivery fan-out

`ProcessChannelMessage` enumerates `participants`, clones a per-recipient copy, and routes each via
`PlayerCache2`. The sender is a participant, so he receives his own message back (self-echo).

**Gotcha:** accept + persist are NOT membership-gated - an incoming channel message is written to Mongo
`chatLog` at `HandleIncommingMessage` regardless of membership; only *delivery* enumerates `participants`.
Hence the canonical signature: **saved but not shown** (row in `chatLog`, no delivery, no self-echo).

## Persistence and reliability

- Messages on persisted channels are written to Mongo `chatLog` on inbound (`IsMessagePersisted`).
- The per-channel message cache is bounded (`EnsureChannelSize`) and reloaded from Mongo on (re)creation -
  a perf cache, not the source of truth.
- Offline / delayed / confirmation queues handle retry, offline parking, and delivery confirmation.

## Root causes and fix

Both root causes share one root: membership is an unfenced `List<string>` tied to the channel object's
lifetime. Forensics: [FP-33074 root-cause](../../../tasks/FP-33074--chat-messages-disappear/artifacts/root-cause.md).
Fix (unified fenced, durable membership store - inline membership ops + hybrid room-primary/node-fallback
fence + seq insurance, membership-driven channel lifetime, presence reconcile, membership-age canary):
[FP-33074 fix-design](../../../tasks/FP-33074--chat-messages-disappear/artifacts/fix-design.md).
