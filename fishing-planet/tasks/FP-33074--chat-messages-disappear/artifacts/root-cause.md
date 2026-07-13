---
jira: FP-33074
title: 'Root cause - chat-server reorders adjacent Join/Leave (ThreadPool dispatch)'
type: artifact
branch: MFT20260325 (Content); shared client/chat code
---

# FP-33074 - Root cause

## ★ LIVE CONFIRMATION (2026-06-27, Steam prod)

Reproduced and captured on **Steam prod**, `club2176`, debug user `db431443-dee8-4606-8731-21fa5db3a923`. STR: send club messages while spamming **F5** (client `PhotonDispatcher` debug trigger = Leave+Join the club channel each frame). Symptom hit exactly: messages 1/2/3 delivered, then it **stopped** from message 4. Chat-server `Chat.log` (JSON layout, UTC) — snapshot `dump/steam-repro-2026-06-27.log`, window `02:23:03`-`02:23:22`:

| UTC time | event | applied order | net membership | self-echo `T`? |
|---|---|---|---|---|
| 23:03.467 | msg 1 | - | participant | **yes** `T db431443->db431443 …Ok` |
| 23:07.716 | F5 #1 | `L`(t203) -> `J`(t86) | joined | `ChannelPop=1` |
| 23:10.436 | msg 2 | - | participant | **yes** |
| 23:12.343 | F5 #2 | `L`(t157) -> `J`(t234) | joined | `ChannelPop=1` |
| 23:14.124 | msg 3 | - | participant | **yes** |
| **23:15.624** | **F5 #3** | **`J`(t38) -> `L`(t203) INVERTED** | **removed** | `ChannelPop=1` (client misled) |
| 23:17.249 | msg 4 | - | **not participant** | **no** (`N`+`P` only) |
| 23:21.280 | msg 5 | - | **not participant** | **no** (`N`+`P` only) |
| 23:22.623 | msg 6 | - | **not participant** | **no** (`N`+`P` only) |
| **32:22.515** | **F5 recovery** | **`L`(t248) -> `J`(t284) correct** | **re-joined** `[3]` | **3x `T` backlog replay** (msgs 4/5/6) + `ChannelExp` |
| 32:36.124 | msg 7 | - | participant | **yes** (live `T`+`S`) |

The recovery row is the model proven from the other side: the correct-order cycle re-adds him to `participants`, and because the client's join `lastId` (`d06f439d`) had not advanced during the dead window (it received nothing), the on-join history replay resends the missed 4/5/6. Matches "changing location frees them up **and** you see what you missed".

Logger legend: `N` op received, `J` join applied to `participants`, `L` leave applied (removal), `T` delivery to a recipient, `S` sent, `P` processed/persisted.

What it proves, point by point:
- **The reorder is real and load-dependent.** Two F5 cycles applied `L`->`J` (net joined); cycle #3 applied `J`->`L` (net removed). Same client intent (leave-then-join) every cycle; only the order in which the two ThreadPool work items won the per-channel `channelOpLock` differed. Never triggered on the idle test box (same-connection F5 probe, 06-27) - fired on the **first** try on busy prod.
- **The corrupted store is `ChatChannel.participants`** (the **unfenced** membership), not routing/`PlayerCache2`.
- **Accept/persist are NOT membership-gated:** messages 4/5/6 have `N`+`P` (received and saved) - they exist in `chatLog`, invisible to him.
- **Delivery IS gated on `participants`:** messages 4/5/6 have **no `T`** back to him -> he sees nothing, including his own text.
- **The client is misled:** every cycle (incl. #3) returned `ChannelPop=1` (join ACK), so the client believes it is subscribed while the server has dropped it. Explains "looks connected, just no messages".
- **Recovery:** any later cycle where `L` precedes `J`, or a relog / travel, re-adds him - matches "changing location frees them up".

Hypothesis -> **confirmed**. Remaining work is fix design, not diagnosis.

## Statement

The chat server processes each incoming message on a **ThreadPool** work item with
**no ordering guarantee between messages**. The game client routinely sends a
**Leave immediately followed by a re-Join** of the **club channel** on travel
(and a *double* Leave on Pond->Globe, per STR comment 80245). When the re-Join's
work item runs **before** the Leave's, the per-channel list ends up with the user
**removed** (`Join` adds idempotently, then `Leave` removes). The player then:

- stays connected (global `g3` keeps working - its Join isn't adjacent to a Leave in the racy window),
- can still **send** to the club channel (send is authorized by club membership, not by channel subscription),
- but **receives nothing** and **doesn't even see his own messages** (delivery enumerates `participants`, which includes the sender - "deliver to all participants including sender"),

until a later Join (next travel / relog) re-adds him without a racing adjacent Leave.

This is **one** residual defect, shared across platforms (client code + chat server
code are shared; client SVN revisions are cross-platform/sequential). It is **not**
the [[FP-44478]] ordering bug and **not** a missing client Join.

## Code chain (file:line)

1. Incoming chat op from the game server →
   `ChatServer/GameServer/IncomingGameServerPeer.cs:201` `HandleIncommingMessage` → `application.EnqueueChatMessage(message)`.
2. `ChatServer/ChatApplication.cs:195` `EnqueueChatMessage` → `processor.Enqueue(message)`.
3. `ChatServer/Processing/ChatProcessor.cs:411` `Enqueue`: non-offline messages (Join/Leave/normal channel msgs) go **directly** to `incomingQueue.Enqueue(message)` (line 420) - **order preserved into the queue**.
4. `ChatServer/Processing/IncomingQueue.cs`: a **single** dedicated thread (`ThreadFunction`, line 94) dequeues a `ConcurrentQueue` strictly **FIFO** (`queue.TryDequeue`, line 102) and calls `Processor.ProcessMessage(message)` (line 106) - **still in order, but it does NOT wait for processing**; it loops to the next dequeue immediately.
5. `ChatProcessor.cs:429` `ProcessMessage` → `Executor(() => ProcessMessageSync(message))` (line 431). In prod `Executor` = **`ThreadPool.QueueUserWorkItem`** (`UseThreadPoolExecutor`, `ChatProcessor.cs:147`; wired at `ChatApplication.cs:174`). **Here ordering is lost** - each message becomes an independent pool work item.
6. `ChatProcessor.cs:762` `ProcessChannelMessage` → `channel.ProcessMessage(...)`.
7. `ChatServer/Channeling/ChatChannel.cs:55` `ProcessMessage` under per-channel `channelOpLock`: `Join` adds the sender id if absent (lines 67-68), `Leave` removes it (lines 88-89). The lock prevents list corruption but **does not impose order** on which work item acquires it first.

Net: steps 1-4 keep order; step 5 destroys it for adjacent messages. `participants`
is a `List<string>` of user ids (`ChatChannel.cs:36`); delivery enumerates it
(`ChatChannel.cs:103`) and resolves each id to the current peer. A user absent from
`participants` is simply skipped.

## Decisive finding - the chat server already fences this race in ONE place, not the other

There are **two** per-user membership stores on the chat server, fed by **two
different** game-node event streams, and only one of them is protected against the
cross-node stale-Leave:

| Store | What it decides | Updated by | Carries source node? | Stale-Leave guard? |
|-------|-----------------|------------|----------------------|--------------------|
| `PlayerCache2` (`OnlinePlayers`) | **WHERE** to deliver (which game node a user is on) | presence stream: `IncomingGameServerPeer.cs:181/184` `OnJoined(NewUsers, new GameState(GameId, this))` / `OnLeft(RemovedUsers, GameId)` from `UpdateGameEvent` | **yes** (`GameId`) | **YES** |
| `ChatChannel.participants` | **WHO** is a channel member (gets messages, incl. own echo) | message stream: `IncomingGameServerPeer.cs:201` `EnqueueChatMessage` -> queue -> ThreadPool -> `channel.ProcessMessage` | **no** (only `message.Sender`) | **NO** |

`PlayerCache2.OnLeft` (`PlayerCache2.cs:74-98`) removes a player **only if the
leave's `gameId` matches the currently-cached node**; otherwise it logs
`"Outdated leave request detected ... player remains in cache"` and keeps him.
`OnJoined` (`43-62`) always does `Remove`+`Add` with the new `GameState`, i.e. the
newest node wins. So even if the presence Join(nodeB) and Leave(nodeA) arrive out of
order, the routing cache stays correct - **the team already recognised and fenced the
cross-node stale-Leave hazard here**.

`ChatChannel.ProcessMessage` (`ChatChannel.cs:55-117`) has **no such guard**: `Join`
adds `message.Sender` (67-68), `Leave` removes `message.Sender` (88-89), both keyed on
the bare user id with no node id and no sequence. The same cross-node reorder that
`PlayerCache2` survives drops the user from `participants`. The membership the *delivery
loop enumerates* is exactly the unprotected one.

This both **confirms** the mechanism (the reorder is real enough that the codebase
defends against it one layer up) and **points the fix**: mirror the `OnLeft`
node-fence onto channel membership. It is **not** a one-liner: the source node is known
at `HandleIncommingMessage` (`this` peer) but is **not** propagated into `ChatMessage`,
and `participants` is a bare `List<string>` with no per-entry node/seq to compare
against. The fix has to thread the source node (or a monotonic op sequence) into the
channel Join/Leave and store it per participant.

## Delivery model (who vs where)

`ChatProcessor.cs:268` delivers a channel message via
`playerState.Game.GameServer.SendEvent(...)`, where `playerState` comes from
`PlayersCache.LookupPlayer`. So: **`participants` selects the recipients; `PlayerCache2`
selects the node each recipient is delivered to.** Because `PlayerCache2` is fenced,
the *routing* is correct - which is why this is not a "delivered to a dead/old node"
bug. The user is dropped at the *recipient-selection* step (absent from `participants`),
so the correct routing never gets a chance to run for him.

Why **club** and not **global**: the client auto-Joins the club channel on entering
a location, and on travel issues Leave+reJoin (and a double-Leave on Pond->Globe) -
adjacent ops that race. The global channel Join is triggered separately (on opening
chat) and isn't paired with an adjacent Leave in the same window, so it survives.

Server-side mitigations that did **not** fix it (and why): r13569 "leave channels on
reconnect" and r13578 "remove peers in PreviewDisconnect on Master" address peer
*cleanup*, not the Join/Leave **reorder**; and channels live on the Chat server while
r13578 acts on Master. The client fix r46485 (2025-04) addressed client-side Join/Leave
STR but not the server reorder, so the bug survived on patched clients (Steam reopen
2025-05; Xbox 2026-06).

## Prod-log reconstruction (Waz 10000 `a0fe2188-...`, club6777, 2026-06-24/25)

Source: `main2.sysLog` (game-side channel events) + `main2.chatLog` (persisted messages), XB PROD.

sysLog channel events (06-24):
```
13:07:51  join 'club6777'            (enter club UI; empty = full history)
13:09:08  leave 'club6777'           \  travel into location:
13:09:11  join 'club6777' 3137025d    /  Leave + reJoin 3s apart  <-- racy pair
   ... sysLog shows him JOINED continuously, no leave until 16:10:05 ...
16:10:05  leave 'club6777'
16:10:33  join 'club6777'            (changed location -> fresh Join -> chat recovers)
```
chatLog (same channel), messages the player sent **while game-side shows him joined**:
```
16:04:00  Waz 10000 | "mornin"                              <- the report's "morning greeting"
16:08:02  Waz 10000 | "Excellent. Broken again. ..."        <- report screenshot
```
Both are **persisted in chatLog** yet the player reported they "failed to appear" to
him. Per the code, the sender only sees his own channel message if he is in
`participants`. So at 16:04-16:08 he was **not** in `participants` on the chat server,
even though the game server believed he was joined (single Join at 13:09:11, no Leave
until 16:10:05). That is the desync: it can only have arisen on the chat-server side -
the 13:09:08 Leave / 13:09:11 Join pair was applied out of order (Join then Leave =
removed).

Corroboration:
- 06-25 13:08:42 `leave` + 13:08:45 `leave` (a **double Leave**, exactly STR 80245's Pond->Globe behaviour) + 13:08:48 `join`, then rapid leave/join thrash 13:09-13:10 = the player relocating/relogging to force delivery.
- Gonzo1964 `38aeb767-...` (president, same account as the 2024-10-23 report): 06-24 18:28:54 "yeah, broken lol HAd to change locations to even see ya typed anything".
- Full channel-event dump for both players ([`dump/sysLog-channel-events-waz-gonzo.json`](dump/sysLog-channel-events-waz-gonzo.json), 348 events ~2 weeks): **double-Leave is routine** - Waz 2x, Gonzo 8x (mostly `g3`, also `club6777`); leaves (191) outnumber joins (157). The racy adjacent-op trigger fires constantly, which is why the bug is chronic and "happens to everyone at some point".

## Refinement - full multi-log overlay (2026-06-24: sys+travel+security+chat)

The trigger is the **Local Map (lobby) <-> 3D room change**, which is a **full
game-server reconnect** - usually to a *different* game node. The club-channel Leave
is relayed from the OLD node's connection, the Join from the NEW node's, ~2-3s apart,
over **two different game-node -> chat connections** (no ordering across them at all;
the old node is tearing the peer down as it relays its Leave). Broken session:

```
13:07:49 -> GAME .62 (lobby)  -> 13:07:51 join 'club6777'   (node .62)
13:09:08 leave 'club6777' (.62) -> disconnect .62 -> 13:09:10 -> GAME .129 (3D) -> 13:09:11 join 'club6777' (.129)
stays on .129 to 16:10 (quit); 16:04/16:08 own messages persist in chatLog but are NOT
echoed to him -> not in participants on .129 -> the .129 Join did not take effect.
```

**Race proven (identical input, opposite output):** the SAME pattern in the working
session succeeded - 02:36:52 leave (node .62) / 02:36:55 join (node .141), chat worked
(Waz at 02:39: "it's working as it's supposed to right now"). Same lobby->3D node
change, opposite outcome -> a timing/load-dependent **race**, not a deterministic
client bug. Every session repeats this leave(old-node)+join(new-node) on each
lobby<->3D transition; it loses the race intermittently ("sometimes you get lucky").
Pauses / day-rollover / AFK do NOT cause leave/join (no reconnect) - only room changes
do; the `diagErr` "PondStayFinished / Game is paused" entries are the day-rollover
dialog, unrelated to chat. Client build observed: UWP 2.9.14 (patched, post-r46485).

## STR (race - non-deterministic)

1. Be a club member; spawn on the Local Map (lobby) of any pond -> client joins the
   club channel on game node A.
2. Enter 3D (start fishing) -> client reconnects to game node B -> sends Leave(club)
   from A and Join(club) from B (~2-3s apart, different connections).
3. When the chat server applies Join(B) before Leave(A), the user is dropped from the
   club channel's participants. (Repeat lobby<->3D to re-roll the race.)
4. Symptom: club chat dies - own messages don't echo, others' don't arrive; global +
   local private still work. Fixed by a full relog (or a later room change whose Join
   wins). No FT or sleep-mode needed - plain enter-pond reproduces it.

## What is proven vs. what needs live confirmation

**Proven:**
- The desync exists on prod (game-side joined, chat-side not delivering, own messages persisted-but-unseen).
- The reorder race is *possible* in prod by construction: FIFO dequeue followed by per-message ThreadPool dispatch (`ProcessMessage` -> `Executor`), `UseThreadPoolExecutor` active.
- Every reported symptom (club-only, own-messages-fail, intermittent "sometimes you get lucky", fixed by travel/relog, years-long, cross-platform) is explained by this mechanism and by no other single cause found.

**Needs live confirmation (definitive):**
- The chat-server-side application order is logged only via `MiniLog.Join/Leave`
  (`ChatServer/MiniLog.cs:99,104`), which writes to **chat-server log files** and only
  `if (DebugUsersCache.IsDebugUser(player))`. It is **not** in Mongo and not available
  historically. To capture the reorder live: flag the reporting player (or a test pair)
  as a **debug user**, reproduce (FT + travel, or guest sleep/reconnect), and read the
  chat-server MiniLog - expect `Leave` applied after `Join` (net removed). This is the
  plan the team set in 2025 (HFH r13569 added the logging for exactly this).

**Capture mechanics (where/how to read, and is it safe):** the MiniLog letter-loggers
(`A`/`U`/`R` cache, `N` incoming, `J`/`L` channel Join/Leave, `T` delivery - `MiniLog.cs`)
are **not** separate appenders; they inherit `<root>` and all land in the **single** chat
app rolling log file (`%Photon:ApplicationLogPath%\{LogFileName}.log`), already
time-ordered (`%utcdate ... %c [requestId]`), so grep by logger letter - no cross-file
merge. The appender is `RollingFileAppender`, `RollingStyle=Size`, `MaximumFileSize=250MB`,
`MaxSizeRollBackups=1`, **`LockingModel=MinimalLock`** (verified in
`LoadBalancing/log4net.config`, `Config/gctest/log4net.config`, deploy
`Photon.local.log4net`). MinimalLock = log4net opens/writes/closes per entry (doesn't hold
the handle), so reading the file over SMB is safe: reading is read-only, can't corrupt; and
logging is decoupled from delivery (and `IsDebugUser` gates only logging). Only real
caveats: mount the share **read-only**, prefer **copy-then-read** (robocopy/Copy-Item) over
holding the live file open (the only collision is a rename at a 250MB roll, which at worst
drops a log line - never crashes the server or affects chat). The smoking gun: `N` shows
incoming order `leave`->`join`, but `J`/`L` timestamps show `Join` applied before `Leave`.

## History of the parallelism (svn blame/log)

Asked: who added the ThreadPool dispatch, why, and when. All of it is **dmytro.kurylovych**:

- The `IncomingQueue` + `Executor` indirection + `UseThreadPoolExecutor()` were introduced
  under **FP-25995 "Chat Server: improve queuing"** across r10290..r10331 (2023-05-02..08).
  The intent was a **throughput** rewrite of the queuing path; the per-message ThreadPool
  fan-out is what loses ordering. `UseThreadPoolExecutor()` is wired into `ChatApplication`
  in r10756 (2023-08-31, "fix concurrent access to internal variable").
- This same path was later touched under **FP-31695 "investigate chat hang on Mobile"**
  (r12224 2024-05, exception catch/log in the thread functions; r12441 2024-06,
  `ChatMessage.ProcessingSource` for logging) - i.e. the team was already debugging this
  exact async path for a related symptom but did not catch the membership reorder.
- **Attribution caveat:** FP-25995 is literally an *"improve"* of a **pre-existing**
  queue, and FP-33074 player reports predate May 2023 - the original Slack thread quotes
  "more then a year if it isn't two years" (mid-2022..mid-2023) and "вже декілька років".
  So FP-25995 did not necessarily *introduce* the reorder; the prior queuing may have had
  the same async hazard, or the rewrite reshaped it (Pete Whear: "seemed to get better for
  a while"). A pre-r10290 blame would be needed to attribute the original cause; the
  *current* mechanism is the FP-25995 ThreadPool dispatch.

## Live debug capture (2026-06-26, debug ON ~13:00 UTC) - bug did NOT reproduce; hypothesis NOT yet confirmed

Debug users (Waz `a0fe2188`, Gonzo `38aeb767`, own `caa03b10`) flagged ~13:00 UTC;
own account was invited into **club6777** and joined at 18:53. Pulled the live chat-server
log (`Chat.log`, JSON `SerializedLayout` on GC prod - not the PatternLayout in the repo
config) for 13:00-19:47. **The capture pipeline works** (full `N`/`J`/`L`/`T`/`S`/`P`/`A`/`U`/`R`
for all three on club6777), but in this window:

- **Net membership healthy:** every debug user's last club6777 op is a `J` (Waz joined since
  18:36:32, Gonzo 19:44:50, own 19:02:54). No un-recovered drop.
- **Delivery 100% OK:** 434 `T` (transfer) lines on club6777, **all status `Ok`**; `S`
  surpressions are only `TTLc` (645 - TTL cache-replay suppressed on join, by-design) and
  `Sent` (434 - the paired pre-send log for each `Ok` transfer). Zero failures.
- **Delivery model confirmed live:** own message at 18:52:59 was delivered (`T ... Ok`) to
  Waz at node `192.40.222.141` and to another member at `.130`.
- **Club chat is persisted as a `Data:"ClubEvent"` envelope with an inner `"Type"`** (e.g.
  `"Type":"Text"` for human chat, with a `"Text"` field holding the message; catches/other
  club activity use other inner Type values). So the human conversation is NOT a top-level
  `Data:"Text"` row - filtering by `Data:"Text"` / `Data != "ClubEvent"` wrongly excludes it.
  Match the inner type instead (`Message: /"Type":"Text"/`). On 06-26 the players DID converse
  in club6777 (verified: Inquisitor7533/own + Gonzo, 20:47-21:02) and it delivered fine - i.e.
  **chat worked, no repro**. (Earlier "no text in club6777" was this filter mistake, corrected.)

So **the reorder/membership-drop was NOT observed** in ~7h of heavy club6777 leave/join churn
with full instrumentation. This does not refute the hypothesis (the bug is intermittent and
nobody reported a break during the window), but it means it is **not yet live-confirmed**, and
the confidence stated above must be read with that caveat.

**Methodology caveat (important):** the log `date` resolution is the Windows ~15.6 ms timer
tick (visible as adjacent events sharing a timestamp, e.g. `...8122861`->`...8278656` = 15.6 ms),
so apply-order inversion **cannot** be proven sub-millisecond from `date`. The real
discriminator at the symptom moment is therefore **net state**, not timestamp order:

- If, when a user reports "broken now", his last club6777 op is **`L` with no recovering `J`**
  -> membership drop (lost/redundant Leave or reorder) -> the participants hypothesis holds.
- If his last op is **`J` (net joined) yet club messages produce no `T ...->him... Ok`** (and
  his own sends don't echo back to him) -> the defect is **delivery/routing**, not membership
  -> the participants hypothesis is wrong and the cause is elsewhere (peer/connection resolution).

Prod error-rate corroboration (from the same `Chat.log`, 05-07..06-26): the presence
stream's `PlayerCache2.OnLeft` logs **`"Player state to remove not found"` 1345 times** -
a Leave arriving for a player **not in** the presence cache (duplicate / late / cross-node
Leave). (`"Outdated leave request detected"` = 0, because that branch is `Log.DebugFormat`
and the `PlayerCache2` logger runs at INFO on prod, so the fence-success case is invisible;
only the error branch shows.) This is direct prod evidence that out-of-order / duplicate
Leaves in the game-node->chat streams are **frequent**, which is the precondition the
channel-membership defect needs - even though the routing cache absorbs them and the channel
list has no equivalent guard. Note this is the *presence* (UpdateGame) stream, a different
stream from the channel Join/Leave, so it corroborates the conditions, not the channel reorder itself.

**Gap analysis (06-26 eve, 3 players) - weakens the reorder hypothesis.** Measured
leave->join gaps (Mongo `sysLog`, [`queries/repro-live.js`](queries/repro-live.js) q1):
own `caa03b10` (slow PC/net) median 6.4s / min 4.4s; Waz min 2.71s; Gonzo min 2.38s. Each
transition is a real GAME reconnect, often to a different node (own path that evening:
.62->.129->.130->.140->.131->.129->.62->.129x3->.140->.141), so the cross-node leave/join
IS being produced - just not breaking. Crucially: Gonzo reconnects in **2.4s** and does not
trigger it, while the **06-24 broken session's leave->join gap was ~2.45s** (13:09:08.9 ->
13:09:11.4) AND its join registered game-side - i.e. membership almost certainly applied
in order, yet chat was dead for 3h. **If 2.4s does not break but 2.45s did, gap size is not
the determinant and the failure is not a membership-ordering race.** Combined with Gonzo's
live description ("I see them only if I leave the lake, then it frees them up" = messages
retained, not lost, released on re-join's channel-cache replay), the evidence now points to
the **delivery / node->client hop** (participant present, `PlayerCache2` route correct,
`T ... Ok` to the node, but the game node does not push to the client while he is in 3D),
NOT to `ChatChannel.participants`. The membership-reorder section above remains documented
but is **downgraded**; confirm/refute at the next repro by reading the `T` target node+status
(and likely game-server logs for the node->client hop), and via a programmatic leave+join
(ms apart) test - if ms-apart membership does NOT drop, the reorder hypothesis is dead.

**Programmatic test result (06-27, YellowTest, F5 trigger, same-connection):** the F5 trigger
fires `LeaveChatChannel(Club)`+`JoinChatChannel(Club)` back-to-back over the **one existing game
connection** (no reconnect). Test-server `Chat.log` (DEBUG level): each pair arrived ~**2 ms** apart
at receive (leave then join), and **every pair applied in order** (`L` then `J`) - even though the
two were processed on different ThreadPool threads - so membership stayed **JOINED** every time, and
the user's own "18" chat message echoed back (`T cc54009a->cc54009a club747 ... Ok`). **No reorder in
~20-30 pairs.** Pair ids are distinct chat-message GUIDs (e.g. leave `#37ffb1b0`, join `#6353264e`);
the join carries the catch-up `lastMessageId`. Two caveats on why this is a weak test: (1) it exercises
only the **same-connection** path (FIFO `IncomingQueue` gives the leave a head start; the real bug's
strong case is **cross-node** - leave over the OLD game connection, join over the NEW one, with **no
ordering between the two connections at all**); (2) the test server is **idle** (one user), so
ThreadPool contention is near zero and the head start always wins - the suspected reorder is
**load-dependent**, so an idle box is biased against reproducing it. => same-connection server reorder
looks unlikely; the live leads remain **cross-node server reorder** and **client mode-1**
(Start-before-OnDestroy), the latter being load-independent and the most promising to chase next.

The live logs will cleanly decide between these the moment the symptom co-occurs with a capture.
Plan: wait for Waz's "broken now" ping (timestamp), or self-repro by cycling lobby<->3D in
club6777, then zoom to that minute and read {net membership, `T` delivery to the user, own echo}.

## Send vs receive: club chat is NOT gated by the sender's membership (theory survives this test)

Question tested: in the bug state messages are accepted + persisted - if a dropped membership
also blocked *accept/save/broadcast-to-others*, the membership theory would be wrong. Code says
it does NOT block those, so the theory survives and in fact predicts the exact asymmetry.

- **Accept + persist:** unconditional w.r.t. `participants` (`IncomingGameServerPeer.cs:211-237`,
  persists `if IsMessagePersisted(channel)`; no sender-participant check).
- **Add to channel + broadcast to others:** `ChatChannel.ProcessMessage` default case
  (`ChatChannel.cs:98-104`) does `AddMessage` + `participants.ToArray()` with no sender check -
  the sender being absent does not remove the *other* participants, so others receive & reply.
- **Delivery TO the dropped player:** gated by HIS membership - the broadcast enumerates
  `participants`; absent => skipped, including his own echo (`ChatChannel.cs:102` "deliver to all
  participants including sender").
- **Client keeps sending** because game-side `ChatChannelController.channelsJoined` is decoupled
  from chat-server `participants`; the client/node never learns it was dropped.

Routing confirms club chat uses the **channel/participants** path, not the group path:
`ProcessChatMessage` (`ChatProcessor.cs`) routes `Group`-set messages to `ProcessGroupMessage`
-> `GetClubMembers` from DB (`574-579`, `724-728`, membership-independent), but a message with
`Channel` set and empty `Recepient` to `ProcessChannelMessage` -> `participants` (`582-587`).
club6777 chat is the latter (has Channel, no Group/Recepient; confirmed by live J/L + Channel-style
T deliveries). **So membership genuinely gates club-chat delivery.**

**Fork that could still kill the theory:** if part of the disappearing content (esp. catch
notifications) is sent via the **Group** path (`GetClubMembers`), a dropped participant would still
receive it. The symptom covers both chat and catches, so either both are channel-based (theory
holds) or some is group-based (partial break). Observed: `Clubmates:+/-` online/offline appear to
be delivered per-member (likely Group); text/ClubEvent via channel. Worth confirming which path the
*missed* content takes.

**Still-open cause:** the drop need not be a timing reorder - a late/duplicate Leave arriving
*after* the Join removes membership with no race (stray leaves are common on prod: 1345
"state to remove not found"; leaves outnumber joins). Competing "node->client hop" theory fits the
same symptom. Discriminator at the symptom moment: presence of `T ...->him... club6777 Ok`
(present => participant intact, blame node->client; absent => dropped from participants).

## Client-side leave/rejoin (06-27 stack traces) - a SECOND, client-only path to LEFT

Client logs (MainClient, `Assets/Scripts/UI/2D/Chat/`) show the leave and the rejoin come from
**two independent Unity lifecycle callbacks**, not one coordinated sequence:
- **Leave:** `ChatListener.OnDestroy` (`ChatListener.cs:104`) -> `ChatController.LeaveFromAllChatChannels`
  (`ChatController.cs:160`) -> `LeaveChatChannel(mType)`.
- **Join:** `ToggleChatController.Start` -> `AddClubChat` -> tab activate -> `NewChatInGameController
  .OnTabActive`/`InitChatChannel` -> `ChatController.JoinChatChannel(mType)`.

`ChatController` keeps client-side state `_currentChannels` (which channels it thinks it's in), with
two guards:
- **Join is state-guarded** (`ChatController.cs:96-106`): the network join is sent only if
  `!_currentChannels.ContainsKey(mType)` (line 101). If the client still thinks it's in the channel,
  **Join is a silent no-op** (never reaches the network send at line 130).
- **Leave is connection-guarded** (`133-146`): removes from `_currentChannels` and sends the network
  Leave only `if IsAuthenticated && IsConnectedToGame` (line 142); otherwise clears only locally.

**Failure mode (client-only, no server reorder needed):** Unity does not guarantee old-object
`OnDestroy` runs before new-object `Start`. If `Start`(Join) runs **before** `OnDestroy`(Leave):
1. Join: `_currentChannels` still has Club -> guard fails -> **no network Join**.
2. OnDestroy -> Leave: Club still present -> removed + **network Leave sent** (if connected).
3. Net: only a Leave reaches the server -> user **LEFT**, no compensating Join. Recovers only on the
   next clean transition (by then `_currentChannels` is clear, so Join actually fires) - matching
   "had to change locations / relog to fix". (If not connected at OnDestroy, the Leave isn't sent and
   the server stays joined - so net-LEFT needs Start-before-OnDestroy **and** connected-at-OnDestroy.)

**Log signature to catch it:** `[ChatDebug] JoinChatChannel(MessageChatType mType = Club)` (logged at
`ChatController.cs:98`, before the guard) **without** a following `JoinChatChannel(string channelId =
'club747', ...)` (logged at line 110, after the guard) = the join was swallowed by the guard = a Leave
with no Join. The user's 06-27 trace showed the SAFE order (Leave 02:06:52.567 -> Join 02:06:55.429),
but the ordering is not guaranteed.

**Why this matters / fix direction:** channel subscription is bound to **UI lifecycle** (per-scene
destroy/create) rather than to the connection/club. Traveling within the **same club** should not
leave+rejoin the club channel at all. Cleanest fix is client-side: skip the leave+rejoin when the club
is unchanged (or bind the subscription to the connection, not to the UI object). This is an independent
(and possibly the primary) source of the LEFT state, separate from the server ThreadPool/cross-node
reorder - and it reproduces even on a single-node test.

**Why club >> global (editor-log evidence, 06-27).** Network-level `[ChatDebug]` sends
(`PhotonServerConnection_Chat.cs:400/406`, channelId form) over one session, from the Unity Editor.log:
**club747 = 21 join / 20 leave, g3 = 1 join / 1 leave.** Leave is symmetric - both come from
`ChatListener.OnDestroy` -> `LeaveFromAllChatChannels` (leaves *all* channels each scene teardown). The
asymmetry is on **join**: the club channel is **re-joined every scene automatically** -
`ToggleChatController.Start` -> `AddClubChat` auto-activates the club tab -> `OnTabActive(Club)` ->
`InitChatChannel` -> join; whereas the **global** channel is joined **only when the Global tab is
manually activated** (`OnTabActive(GlobalMap)` -> `InitChatChannel` -> `ChatController.ChangeLanguage`
[`cs:196`, global name is language-scoped] -> join g3). So club is thrashed on every room change while
g3 is (re)joined rarely. This **unifies the symptom**: the same defect hits both channels; global is
just far less often inside the race window, which is exactly why players see it "sometimes" on global
and constantly on club. (To exercise g3 deliberately: add `Leave/JoinChatChannel(MessageChatType
.GlobalMap)` to the F5 trigger; `GetChannelName(GlobalMap)` resolves to g3.)

## Fix directions (design later - not in scope yet)

- **Mirror the existing node-fence onto channel membership (preferred):** the chat server
  already ignores an outdated cross-node Leave in `PlayerCache2.OnLeft` (drops only when
  `gameId` matches the cached node). Do the same for `ChatChannel` membership - thread the
  source node id (known at `IncomingGameServerPeer.HandleIncommingMessage` as `this`, but
  not currently propagated into `ChatMessage`) into Join/Leave, store it per participant,
  and ignore a Leave whose node no longer matches. This reuses a pattern already proven in
  the same codebase.
- **Order-preserving processing for channel-membership ops:** don't fan Join/Leave to
  the ThreadPool out of order. Options: process channel ops synchronously on the
  IncomingQueue thread; or shard pool dispatch by channel id so same-channel ops run on
  one worker in arrival order; or a per-(user,channel) serialization gate.
- **Idempotent reconcile:** stamp Join/Leave with a monotonic sequence/timestamp and
  have `ChatChannel.ProcessMessage` ignore an older op that arrives after a newer one.
- **Shrink the race window (mitigation, client):** remove the redundant Leave+reJoin and
  the Pond->Globe double-Leave (STR 80245) so adjacent membership ops stop colliding.
- Note `ChatChannel.cs:102` "deliver to all participants including sender" - keep, but
  it is why the sender's own messages vanish when he's dropped (useful diagnostic, not a bug).
