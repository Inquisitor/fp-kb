---
module: chat-server
system: chat
---

# Chat Server
> Photon Chat app: relays player chat (global / club / UGC / FTG / private) via game nodes, holds channel membership, fans messages out to recipients, persists to Mongo. Membership delivery is the fragile part (FP-33074).

## Entry Points
- `ChatApplication` — `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/ChatApplication.cs` (wires `GameServers`, `OnlinePlayers`, `ChannelMemoryCache`, `ChatProcessor`)
- `IncomingGameServerPeer` — `ChatServer/GameServer/` (`HandleIncommingMessage` = chat ops, `HandleUpdateGameState` = presence)
- `ChatProcessor` — `ChatServer/Processing/ChatProcessor.cs` (queues, dispatch `Executor`, delivery state machine `ProcessChatMessage`)
- `OutgoingChatServerPeer` — `GameServer/OutgoingChatServerPeer.cs` (game-node side relaying client chat)

## Key Types
- `ChatChannel.participants` — delivery membership (WHO is in a channel); **unfenced** `List<string>` tied to the channel object's life — the FP-33074 fault line
- `PlayerCache2` — routing presence (WHERE: user→node); **fenced** (newest-join-wins, gameId-matched leave)
- `ChannelMemoryCache` / `ChatChannel` — channel registry; persistent (global + waterbody) vs evictable (club / UGC / FTG)
- `IncomingQueue` (single FIFO thread) + `Executor` (`UseThreadPoolExecutor` on prod) — the dispatch that reorders adjacent ops

## Dependencies
→ DAL: `IChatLogger` (Mongo `chatLog`) + offline-message persister
~ `ChatMessageEvent` / `UpdateGameEvent` (ServerToServer) shared with GameServer
← GameServer: `OutgoingChatServerPeer` relays client chat + presence
← Leaderboards / rewards: delivered as offline `ChatMessageBase`; ClubServer: club events as channel messages

## Deep Dives
- [Lifecycle and membership](lifecycle-and-membership.md) — inbound pipeline + ThreadPool reorder, the two membership stores, channel eviction, fan-out, both FP-33074 root causes, gotchas
- [MiniLog format decoder](minilog-format.md) — how to read `Chat.log`

## Related Tasks
- FP-33074 — club chat messages disappear: reorder + eviction root causes + fix design
- FP-36219 — clubmate online/offline activity not delivered to small club chat (same delivery family)
- FP-25995 — introduced the ThreadPool dispatch enabling the reorder (~2023-05)

See also: [backlog](backlog.md) | [log](log.md)
