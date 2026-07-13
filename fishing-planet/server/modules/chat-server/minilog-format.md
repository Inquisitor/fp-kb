---
module: chat-server
title: 'MiniLog format decoder (how to read Chat.log)'
---

# Chat-server `Chat.log` — how to read it

The chat server writes a terse per-event log via `MiniLog` (`ChatServer/MiniLog.cs`). On GC/prod
it is serialized as **JSON** (log4net `SerializedLayout`); classic/test builds use a PatternLayout but
the same fields. Everything below is derived from code, not guessed.

## Line envelope (JSON, GC/prod)

One JSON object per line:

```json
{"date":"2026-06-27T02:23:15.624Z","thread":"38","level":"INFO","logger":"J","message":"..."}
```

- `date` — UTC (`Z`). On GC the resolution is the ~15.6 ms Windows tick, so sub-ms apply-order
  cannot be proven from timestamps alone (use the per-event evidence instead).
- `logger` — **the cryptic one-letter code** = the log4net logger name (`LogManager.GetLogger("J")` etc.).
- `message` — built by `ChatMessage.Brief()` for message events, or a fixed string for cache/channel events.

All MiniLog calls are **debug-gated**: they emit only if the message's sender/recipient (or the player,
for Join/Leave/cache) is in `DebugUsers.lst` (`DebugUsersCache.IsDebugUser`), or the message `IsPriority`.
So a quiet log for a user just means that user is not flagged — flag them to see their traffic.

## Logger letters (`MiniLog.cs`)

| Code | Logger | Meaning |
|---|---|---|
| `N` | New | A new incoming message was accepted (entry into processing). |
| `P` | Processed | Message fully processed (fanned out to per-recipient messages / persisted). |
| `T` | **Transfered** | **Actually sent** to a recipient's game node. Tail = `{nodeIP} {sendStatus}` (e.g. `Ok`). This is the real "delivered to recipient" marker. |
| `S` | **Surpress** | A message reached a **terminal disposition**, with a **reason prefix** (see below). NOT "Sent" — though one of its reasons is literally `Sent ` (delivered, no confirmation needed). |
| `C` | Confirmed | Recipient confirmed delivery. |
| `D` | Delay | Delivery deferred / scheduled for retry, with a reason prefix. |
| `O` | Offline | Recipient offline; message parked. |
| `X` | Expire | Message expired (TTL). |
| `E` | Error | Error. |
| `J` | Join | Player joined a channel: `player->channel [N]`, where **N = number of backlog messages replayed** to them (`channelContent.Length`), NOT participant count. |
| `L` | Leave | Player removed from a channel's participants: `channel->player`. |
| `A` / `U` / `R` | Add / Update / Remove | **Routing cache** (`PlayerCache2`): player's userId->node route registered / updated / removed. About *where* to send, not channel membership. |
| `G` | GameServer | Game-server-side processing status. |
| `EVICT` | ChannelEvict | (Added for FP-33074) A channel that **still had participants** was evicted (silent member drop). Empty-channel evictions are not logged. |

## Message body — `ChatMessage.Brief()` (`Messages/ChatMessage.cs:160`)

```
{Sender}->{Recepient} {Channel}:{Group} {msg10} {data10} {off} {one}        (+ for T: " {nodeIP} {status}")
```

- `Sender` — who sent (`(0..)` = empty / system zero-GUID).
- `Recepient` — the per-delivery target (set per recipient during channel fan-out).
- `Channel:Group` — channel name `:` group (club uses `Channel=club####`, Group empty).
- `msg10` — first **10 chars** of `Message`. For a normal message = payload start (`{"Instance`…);
  for a **Join** = the client's `lastId` (last message it has — drives backlog replay);
  for ChannelPop/ChannelExp = the count / expiry tick.
- `data10` — first 10 (25 if priority) chars of `Data` = the **type/envelope**:
  `ClubEvent`, `Join`, `Leave`, `ChannelPop`, `ChannelExp`, …
- `off` — IsOffline (Y/N). `one` — IsOneTime (Y/N).

## Reason prefixes (the `RNFo`/`CON`/`Sent` magic) — `ChatProcessor.cs`

These are hand-written tags prepended to the brief on the `S`/`D`/`O` loggers, telling you *why* a
message ended where it did:

| Tag | Logger | Meaning |
|---|---|---|
| `RNFo ` | D | Recipient Not Found in routing cache -> defer & retry. |
| `RNF+ ` | S | Recipient Not Found, retries exhausted -> give up (suppress). |
| `OFF ` | O | Offline, retries exhausted -> park offline. |
| `CON ` | D | Sent, waiting for Confirmation -> defer. |
| `Sent ` | S | Delivered, no confirmation needed -> done (terminal success on the suppress logger). |
| `1t ` | S | OneTime message, already tried once -> drop. |
| `Id- ` | S | Empty Id, can't await confirmation -> drop. |
| `TTL`* | S/X | Time-to-live expiry suppression. |

## Worked examples

- `N | a0fe2188->club6777: {"Instance ClubEvent N N`
  New: player a0fe2188 sent to channel club6777; payload starts `{"Instance`, type `ClubEvent`, online, not one-time.
- `T | a0fe2188->a0fe2188 club6777: {"Instance ClubEvent N N 192.40.222.141 Ok`
  Transfered: that club message delivered back to a0fe2188 himself (self-echo) via node 192.40.222.141, result Ok.
  **No such `->a0fe2188` line for a message ⇒ it was not delivered to him ⇒ he is not in the channel's participants.**
- `S | Sent a0fe2188->a0fe2188 club6777: {"Instance ClubEvent N N`
  Terminal: that delivery is done, no confirmation needed.
- `J | a0fe2188->club6777 [4]` — a0fe2188 joined club6777; 4 backlog messages replayed to him.
- `L | club6777->a0fe2188` — a0fe2188 removed from club6777 participants (explicit Leave).
- `EVICT | Channel club6777 evicted with 5 participant(s) still joined, 174 cached message(s); dropped debug user(s): a0fe2188-…`
  The channel object was dropped on inactivity while members were still in it — they are silently un-subscribed.

## Reading recipe

1. Parse each line as JSON; the **`logger`** field is the letter.
2. Filter by `logger` and/or substrings in `message` (userId, channel).
3. To decide "did user X receive message M?": look for a `T` line `…->X … Ok`. None ⇒ not delivered ⇒
   X was not enumerated as a participant. A `D`/`S` `…->X …` with `RNFo`/`RNF+` ⇒ X was a participant but unroutable.
4. To find why X stopped receiving with no `L`: suspect channel **eviction** (`EVICT`) — membership lives
   only in the in-memory `ChatChannel.participants`; eviction + recreation resets it (see root-cause.md, mechanism #2).
