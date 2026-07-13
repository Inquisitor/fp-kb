---
jira: FP-33074
title: 'Fix design - unified fenced membership store (chat-server)'
type: artifact
status: design-locked
related:
  - root-cause.md
  - ../../../server/modules/chat-server/minilog-format.md
---

# FP-33074 - Fix design: unified fenced membership store

Living design doc. Status markers: **[LOCKED]** = agreed, **[DRAFT]** = proposed/under discussion,
**[OPEN]** = needs a decision or code verification.

Reviewed adversarially by an external model (Codex, 2026-07-01) + self-review; all findings folded in
(see Decisions log). Key outcome: the fence moved from `nodeId` to **room-primary with node fallback**,
and the inline-mutation / pooled-fan-out split gained explicit snapshot/token/locking requirements.

## Goal

Eliminate both confirmed root causes of "club chat messages disappear":

- **#1 reorder** - adjacent Leave/Join of `ChatChannel.participants` apply in ThreadPool order, not
  arrival order -> a member is removed (see [root-cause.md](root-cause.md), mechanism #1; JIRA #126557).
- **#2 eviction** - non-persistent club/UGC/FTG channels are evicted after inactivity and recreated with
  empty `participants`, silently dropping every member (mechanism #2; JIRA #126623).

## Shared root

Both are the same defect: channel membership is an **unfenced, in-memory `List<string>`** (`ChatChannel.participants`),
keyed on the bare `Sender`, and tied to the **lifetime of the channel object**. No room/node identity,
no ordering, and it dies when the channel is evicted.

## Approach: one fenced, durable membership store the delivery loop reads

Four pillars. Pillar 1 fixes the *fencing/ordering* (#1); Pillar 2 fixes the *lifetime* (#2); Pillar 3 keeps the
combination from leaking; Pillar 4 adds a membership-age canary to catch regressions. Pillars 1 and 3 extend the
**proven** fence/presence pattern already in `PlayerCache2` (routing is fenced) to the *delivery* membership.

---

## Pillar 1 - fence + ordered apply  **[LOCKED]**

### Membership entry

Replace `List<string> participants` with a fenced entry per member:

```
participant: userId -> { roomId, nodeId, peerGen, seq, joinedAt }
```

- `roomId` = the game **room** the op was issued from (`ChatMessageEvent.Room`). Same domain as presence:
  presence `UpdateGameEvent.GameId = Game.Name` (`Game.cs` `BuildUpdateGameEvent` sites) and the client-op path
  sets `Room = RoomReference.Room.Name` (`GameClientPeer_Messaging.SendMessageUsingChatServer(ChatMessageRequest)`).
- `nodeId` = source game node (`IncomingGameServerPeer.ServerId`) - fallback fence for ops without a room.
- `peerGen` = source peer generation (`IncomingGameServerPeer.ConnectionId`) - tiebreak for a node that
  reconnects and re-registers with the same `ServerId` (old-peer stragglers must not match the new peer's entries).
- `seq` = monotonic stamp capturing arrival order (insurance).
- `joinedAt` = UtcNow of the most recent (re)Join; reset on newest-wins overwrite. Powers Pillar 4 and the
  Pillar 3 reconcile grace window.

### Apply rules (hybrid fence, mirrors `PlayerCache2.OnLeft`)

- **Join** = newest-wins upsert; a **null-room Join must NOT erase a known `roomId`** (updates `nodeId`/`peerGen`/
  `seq`/`joinedAt`, preserves the room) - else a room-less rejoin downgrades the fence for a later stale leave.
- **Leave** = remove only if it comes from the same ownership context as the recorded Join:
  1. both rooms known -> remove iff `leave.roomId == entry.roomId` (the precise fence; catches same-node room moves);
  2. **room-less Leave is WEAK**: it may remove only a room-less entry (with `nodeId` + `peerGen` matching) -
     it can never remove an entry that has a known room. Rationale: a late `TearDown` leave (fires from
     `PreviewDisconnect`, `GameClientPeer.cs` - which can run tens of seconds late, "No PreviewDisconnect arrived")
     would otherwise kill a fresh same-node re-join; even a room fence would not help on a reconnect into the
     SAME room. Cleanup after a real quit is delegated to the Pillar 3 reconcile (the player is offline anyway;
     lingers <= sweep + grace).
  3. mismatch -> stale cross-room/cross-node leave -> **ignore** (log, like "Outdated leave request detected").
- **seq** (`MembershipSeq`) = stamped **once** on first FIFO dequeue and **preserved through requeue/retry**
  (`Reenqueue`, exception-retry) - a retry must not acquire a fresher seq. Reject any membership op older than
  the entry's recorded seq. Membership ops must never enter the delayed/offline lanes (assert + log if one would).
- **No identity at all** (`ServerId` null AND `Room` null): **reject the membership op** - `IncomingGameServerPeer.OnEvent`
  deliberately admits `SendChatMessage` from unregistered peers, so `ServerId` is NOT guaranteed. Never store a
  null-identity entry. Emit a counter + log on rejects (watch for a legitimate producer appearing, e.g. master-side;
  add a test asserting master sends no channel membership). (Plain messages from unregistered peers stay allowed.)

### Why hybrid (room primary, node fallback)

- **room fence** is the only one that catches a **same-node room move**: travel A -> B on one node, Join(B) applies
  before the late Leave(A) - `nodeId` matches (same node!), only `roomId` differs. This is the residual
  client Join-before-Leave shape (STR 80245), so node-only fencing would leave a real hole. (Codex finding #1.)
- **node fallback** is needed because some legitimate ops carry no room:
  - server-generated Join/Leave (`ChatChannelController.RejoinAllChannels` / `TearDown`, the r13569 machinery) go
    through the **static** `GameClientPeer_Messaging.SendMessageUsingChatServer(...)` overload, which builds
    `ChatMessageRequest` **without `Room`** and bypasses the instance path that sets it (verified);
  - a teardown Leave fires at disconnect, when `RoomReference` may already be gone - it *cannot* carry a room.
  - The fallback still kills the classic cross-node stale teardown-Leave: old node != entry's node -> ignored.
- Game-side change (**required**, small): populate `Room` in the static overload where a room exists
  (`RejoinAllChannels` runs with a live `RoomReference`), so rejoin ops are room-fenced. Without it, every rejoin
  is a null-room Join and the weak-leave/merge rules carry all the weight. The hybrid rule stays regardless
  (teardown can't be fixed that way - at disconnect the room may be gone).

Correctness across arrival orders (rooms A -> B; N1/N2 = nodes, may be equal):

| Scenario                                                                                              | Apply order                  | Fence outcome                                 | Net         |
|-------------------------------------------------------------------------------------------------------|------------------------------|-----------------------------------------------|-------------|
| travel, late leave (cross- OR same-node)                                                              | Join(B) then Leave(A)        | `A != B` room mismatch -> leave ignored       | member on B |
| travel, ordered                                                                                       | Leave(A) then Join(B)        | remove, then re-add with room B               | member on B |
| rapid same-room leave+join (debug trigger)                                                            | in arrival order (FIFO)      | inline apply, no reorder arises               | member      |
| teardown leave from dead old node                                                                     | after new node's Join        | room null -> node fallback: N1 != N2          | member on B |
| late teardown, SAME node (delayed `PreviewDisconnect`, crash/sleep re-join - even into the same room) | after the new session's Join | weak leave: entry has a room -> cannot remove | member      |
| node reconnects, same ServerId, stale leave                                                           | after re-join on new peer    | `peerGen` mismatch -> ignored                 | member      |

### Execution model - serialize the ordering-sensitive part

The reorder is born at one line: the single-threaded FIFO `IncomingQueue` calls `ChatProcessor.ProcessMessage`,
which immediately hands work to the ThreadPool (`Executor` = `UseThreadPoolExecutor` on prod).

- **Membership ops (Join/Leave/Expire) are handled inline on the FIFO thread** - not dispatched to the pool -
  so same-connection order is preserved at the source. Regular messages stay pooled (throughput unchanged).
- **Split mutation from side-effects:** only the participant mutation runs inline; backlog replay,
  `ChannelPopulation`, and delivery fan-out go to the pool - under the split-safety rules below.

### Split-safety requirements (from adversarial review - MUST hold, else the split creates new races)

1. **Atomic snapshot out of the mutation.** The inline mutation returns, from inside the channel lock, everything
   its pooled side-effects will use: participants snapshot, participant count, backlog (`channelContent`),
   `firstMessage`, and the membership token `(userId, seq)`. Pooled tasks operate ONLY on the snapshot - never
   re-enumerate live state (today `ProcessChannelMessage` re-reads `channel.Participants` after the mutation;
   count and recipients can describe different states).
2. **Token recheck before deferred join side-effects.** A pooled backlog-replay task must recheck that the joining
   user's entry still carries the captured `seq` before delivering - an inline Leave may have applied in between
   (otherwise: replay delivered to a player who already left).
3. **Lock order `channelsLock` -> `channelOpLock`, and get/create+mutate atomic vs removal.** Channel removal
   (sweep) must not race an inline join holding a reference to the channel object being removed - else the join
   mutates an orphan and the next message recreates an empty channel (silent drop again). One `Apply(channelId, op)`
   style entry point on `ChannelMemoryCache`, or a strict lock protocol shared by join/leave/reconcile/removal.
4. **Cold-create must not block the FIFO thread on Mongo.** `GetOrCreateChannel` loads history from DAL under
   `channelsLock` for long-living channels. Inline stage: create the channel entry + apply membership only (cheap,
   no DAL). History hydration moves to a pooled task with an explicit **hydration state**
   (`NotStarted / InProgress / Done`), **single-flight** (concurrent joins must not start duplicate hydrations).
   Note the interaction with rule 1: on a cold channel the inline mutation CANNOT return a backlog snapshot
   (history not loaded yet) - the pooled join task, after hydration completes, **re-enters the channel lock,
   re-checks the membership token, and takes a fresh backlog snapshot** before replaying. Hydration merges via
   `AddMessage` (dedups by Id, inserts by Timestamp), so messages arriving mid-hydration order correctly.

### Sourcing

- **seq:** monotonic counter stamped on the FIFO dequeue stage (before any dispatch), `long`, `Interlocked`.
  Monotonic by construction - that stage is single-threaded FIFO.
- **roomId:** `ChatMessageEvent.Room` - carried by the game relay today (`OutgoingChatServerPeerBase.DoSendMessage`
  copies `Room`), **dropped** by the `ChatMessage(messageEvent)` ctor - carry it through.
- **nodeId / peerGen:** `IncomingGameServerPeer.ServerId` / `ConnectionId` at `HandleIncommingMessage` - attach to
  the membership op chat-side.

### Code touch points

- `ChatChannel.participants` -> fenced store `{ roomId, nodeId, peerGen, seq, joinedAt }`; Join/Leave apply the hybrid fence.
- `ChatProcessor.ProcessMessage` - branch membership ops inline; stamp `seq`; split per split-safety rules.
- `ChatProcessor.ProcessChannelMessage` - decompose into inline mutation + pooled side-effects on snapshot.
- `ChannelMemoryCache` - atomic apply/remove protocol (`channelsLock` -> `channelOpLock`); hydration out of the lock.
- `IncomingGameServerPeer.HandleIncommingMessage` - attach `nodeId`/`peerGen`; reject identity-less membership ops.
- `ChatMessage(ChatMessageEvent)` ctor - carry `Room` (and the attached identity) through.
- Game-side (recommended, small): static `GameClientPeer_Messaging.SendMessageUsingChatServer(...)` overload -
  populate `Room` where available (`RejoinAllChannels` path).
- Model: `PlayerCache2.OnJoined`/`OnLeft` (the fence being mirrored and extended).

---

## Pillar 2 - decouple membership from message-cache lifetime  **[LOCKED]**

Eviction is **not** a pure band-aid: club/UGC/FTG channels are unbounded in count (the persistent set -
`g*` + waterbody - is fixed, created once in `ChannelMemoryCache.CreatePersistentChannels`), so some
reclaim is required. The band-aid is that the inactivity sweep throws away **membership** (not rebuildable)
together with the **message cache** (bounded + Mongo-backed, rebuilt by `GetOrCreateChannel`).

Provenance (verified): the channel machinery + 30-min expiry were designed for **UGC competition sessions**
(FP-13221, r5610, 2019-01) where session lifetime is correct; `persistent` was added later for pond/global
(FP-17330, r7648, 2020-04); club channels inherited the UGC session default unrevisited. Removing the timer
breaks no design intent - it removes a misfit inherited default.

**Resolved (Option A): channel lifetime becomes purely membership-driven; the inactivity timer is removed.**

- Remove the `ChannelInactivityTimeout` / `ExpireDate` machinery - the blind timer was the direct source of #2.
- The sweep removes a non-persistent channel only when its **membership is empty** (atomically, per split-safety #3).
  Persistent channels (`g*` + waterbody) are never removed, as today.
- The message cache lives and dies with the occupied channel. Memory is bounded by the **working set**:
  membership entries <= **online users x channels-per-user** (not "<= presence size" - the bound is per
  (channel, user); channels-per-user is small in practice: club + UGC/FTG + globals, and the client leaves all
  channels on every scene change). Hardening: enforce a **per-user channel cap** in the store (reject + log past
  the cap) so a misbehaving/hacked client joining arbitrary channel names cannot inflate the store -
  `AuthorizeChannelMessage` today gates only club channels.
- Membership is emptied by genuine (fenced) Leaves + presence reconcile (Pillar 3).
- **Explicit `Expire` command - retired [LOCKED]**. Provenance verified: FP-13595 "UGC: chat integration -
  absolute expiration" (2019-03, r6093/r6094, dk) - the UGC caller never materialized. Dead end-to-end: zero
  production senders server-side, zero client call sites for `ExpireChatChannel` (both client branches), and
  PhotonTool (`Photon/tools/PhotonHelper`) has no channel-close command (reads + generic `e` eval only). Its only
  reachable effect today would be a silent member drop (= failure mode #2). Retirement: server treats the op as
  no-op + log; `AbsoluteExpireDate` removed together with the timer machinery; unit test updated; dead client
  method removed on occasion. Safe because channel lifetime is membership-driven and leaves are guaranteed
  (fenced Leave + Pillar 3 reconcile) - a forced close has nothing left to do. If a future feature needs
  channel close, design it then with visible-close semantics.
  **Naming guard:** this retires only the `ChatChannelsCommands.Expire` *close command*. The live
  `ChatRequests.ChannelExpiration` event (join-time backlog-horizon notification, consumed by
  `ClubAdapter.___ReceiveClubChannelExpiration`) is a different thing and **stays**.
- **Backstop TTL - rejected [LOCKED]**. A presence-checked TTL is identical to the Pillar 3 reconcile (which
  already runs every sweep) - dead code. An unconditional TTL would silently drop genuine marathon sessions
  (`joinedAt` resets only on re-Join) - reintroducing failure mode #2 for exactly the long-session cohort that
  reported this bug. Memory stays bounded without it: a phantom must be presence-listed (else the reconcile
  removes it), so membership <= presence size; a presence leak is visible via the Pillar 4 canary AND the
  existing players-in-cache perf counter - fix the presence bug when seen instead of masking it.

(Option B - drop the cold message cache while keeping membership, reload-on-join from Mongo - rejected:
leaner memory but adds rehydrate edge cases; Option A's working-set bound is acceptable and simpler.)

## Pillar 3 - reconcile membership against presence  **[LOCKED]**

Safety net so "keep occupied channels" cannot leak: a member who never sends a Leave (hard crash) must still
eventually leave the channel. `PlayerCache2` is the authority on "still online anywhere".

**Resolved: periodic reconcile in the existing sweep** (`ChatProcessor.ThreadFunction` cadence), hardened per review:

- For each member: `PlayersCache.LookupPlayer` **at prune time** (never a pre-collected `AllPlayers` snapshot -
  it goes stale during the sweep). Absent from presence -> drop the member; emptied channel -> remove (atomically,
  split-safety #3).
- **Grace window:** skip entries younger than a threshold (via `joinedAt`) - a chat Join can legitimately
  arrive before the presence `UpdateGameState.NewUsers` for the same player; without grace the reconcile would
  evict a mid-join member (TOCTOU). The threshold is **configurable and derived from the real lag bound**: not
  an `UpdateGameState` cadence (those send immediately, `Game.UpdateGameStateOnChat`) but the game-node's chat
  S2S **reconnect + offline-queue flush** window (`OutgoingChatServerPeerBase` reconnect path). Log the count of
  skipped-young entries per sweep - a growing number flags the grace being load-bearing. **Post-release check**
  (not part of the implementation): watch this counter on prod and tune the grace - tracked in the task backlog
  ("Post-release" section); candidate for waiting-for-release on the JIRA task.
- A lost Leave (crash) lingers at most one sweep interval + grace - harmless, the member is offline.
- No reverse index; an event-driven `PlayerCache2.OnLeft` hook stays an optional later optimization.

**Sub-fix required (verified gap):** node-disconnect does NOT purge presence today - `GameServers.OnDisconnect`
only drops the peer from its dict; `PlayerCache2` is untouched. A hard node crash (no final `RemovedUsers`)
leaks that node's players in presence, defeating the reconcile. Add e.g.
`PlayerCache2.OnGameServerDisconnected(peer)`: remove entries whose `Game.GameServer` **is that peer object**
(reference comparison - NOT by `ServerId`, or a stale disconnect of the old peer would purge players already
re-registered under the replacement peer with the same `ServerId`). Fixes a pre-existing presence leak too.

## Pillar 4 - membership-age observability  **[LOCKED]**

A canary for the fix itself: with the fence + reconcile working, membership churns (travel/relog within a day),
so few entries should be long-resident. A growing population of long-resident members signals a regression / new leak.

- Each entry carries `joinedAt`, reset on every (re)Join, so it measures **continuous** residency - a phantom
  that never re-joins accumulates age; an active traveller stays "young".
- An hourly sweep logs the **count** of members resident longer than a threshold (default 24h) - total plus the
  few top channels. Mechanics: this is a plain `AGE` line in the chat-server `Chat.log` (no external monitoring
  dependency); reviewing it = reading that log. Drill-down when the count grows: `FENCE` log entries for the
  affected users + live inspection via PhotonTool (`e ctx.Channels.ToArray()` - members with ages). Post-release
  check shares the task-backlog "Post-release" item with the reconcile young-skip counter. If the MiniLog
  structured-JSON follow-up lands, these become filterable fields for log shipping.
- Cross-reference with presence: long-resident **and** absent from `PlayerCache2` = a leak Pillar 3 should have
  caught; long-resident **and** present = a genuine long session (informational).
- Emit as a structured record (ties into the MiniLog restructure follow-up task).

## Delivery

The fan-out loop (`ChatProcessor.ProcessChannelMessage` / `SendMessage`) enumerates the fenced store's snapshot
(split-safety #1) instead of the bare list. Store = WHO is in the channel (fenced); `PlayerCache2` = WHERE to
route (already fenced). A member leaving between snapshot and delivery may still receive that in-flight message -
pre-existing, cosmetic, unchanged.

## Cross-cutting

- "Durable" = survives channel-object eviction, **in-memory** **[LOCKED]**: on a chat-server restart the game
  nodes reconnect and `ChatChannelController.RejoinAllChannels` re-sends joins, rebuilding membership; presence
  rebuilds via `Reinitialize`/`CurrentUsers` game updates. DB persistence adds nothing but staleness.
- Framework-independent: the fix is entirely in the Chat app (+ the small game-side `Room` population);
  the classic-Photon and GameCarrier builds share this code (framework difference only - platform assignments
  to frameworks vary and more platforms are moving to GC, so the design does not pin frameworks to platforms).
- Client fix (skip redundant Leave+reJoin) becomes an optimization, not a correctness requirement.

## Delivery and activation order  **[LOCKED]**

**One code delivery.** The whole fix (all pillars) is implemented and shipped together - pillars are NOT
independently shippable (Pillar 2 without Pillar 3 leaks channels; Pillar 1 alone does not fix the dominant
cause #2), and no partial state goes to prod. The "stages" below are two different things, neither of which
splits the release:

- **Commit ordering discipline (in-branch, SVN):** the implementation lands as a sequence of branch-green
  commits (each builds, passes tests, changes no runtime behavior) - teammates can build/release the branch at
  any intermediate point safely. This orders COMMITS, not releases.
- **Activation sequence (on prod, post-release, config-only):** the two settings ship default-OFF, so after the
  single delivery the fix can be activated without redeploys: observe FENCE shadow telemetry -> flip
  `MembershipFenceEnforce` -> flip `MembershipDrivenChannelLifetime`. The observation window is at the
  operator's discretion (can be minutes; the flags exist as an instant-rollback lever, not as a phased rollout
  requirement). Presence purge and the canary are always-on from the delivery.

## Decisions log

- 2026-06-30 - Scope: single fenced, durable membership store (over targeted patches) - "cleaner and more honest".
- 2026-06-30 - Pillar 1 execution: (1b) handle membership ops inline on the FIFO thread + identity fence; **[LOCKED]**.
- 2026-06-30 - Pillar 1 seq: stamp and keep as insurance. **[LOCKED]**.
- 2026-06-30 - Pillar 2: Option A - channel lifetime purely membership-driven, inactivity timer removed; message cache lives with the occupied channel. **[LOCKED]**.
- 2026-06-30 - Pillar 3: periodic reconcile against presence in the existing sweep; no reverse index. **[LOCKED]**.
- 2026-06-30 - Pillar 4: membership-age (`joinedAt`) canary - hourly log of members resident > 24h. **[LOCKED]**.
- 2026-06-30 - ~~Verified: room-`gameId` unavailable on inbound channel ops -> fence on `nodeId`~~ **RETRACTED 2026-07-07**:
  the claim was wrong - `ChatMessageEvent.Room` IS carried by the game relay (`OutgoingChatServerPeerBase.DoSendMessage`)
  and dropped only by the `ChatMessage` ctor. Caught by the Codex adversarial review.
- 2026-06-30 - Verified: presence not purged on node-disconnect (pre-existing leak) -> purge sub-fix in Pillar 3. **[LOCKED]**.
- 2026-07-07 - Codex review folded in. Fence = **hybrid room-primary / node-fallback + peerGen + seq** (room catches
  same-node room moves that node-only missed; fallback covers legitimately room-less ops - rejoin/teardown paths).
  Membership ops from identity-less senders rejected (`OnEvent` admits unregistered `SendChatMessage`). Split-safety
  requirements added (atomic snapshot, token recheck, lock order + atomic remove, hydration off the FIFO thread).
  Pillar 3 hardened (prune-time `LookupPlayer`, `joinedAt` grace, purge by peer object). **[LOCKED]**.
- ~~2026-07-07 - Expire = explicit close through the store. [DRAFT]~~ superseded same week: history check showed
  the command is dead end-to-end (FP-13595 UGC-era, caller never shipped) - designing semantics for it is wasted work.
- 2026-07-07 - **Expire retired** (no-op + log; `AbsoluteExpireDate` removed with the timer). Safe: membership-driven
  lifetime + guaranteed leave make forced close unnecessary. **[LOCKED]**.
- ~~2026-07-07 - Backstop TTL (member-notifying, ~24h) as memory hedge. [OPEN]~~ **rejected 2026-07-07**:
  presence-checked variant duplicates the reconcile; unconditional variant silently drops marathon sessions
  (mechanism #2 redux for the reporting cohort). Membership is bounded by presence size by construction;
  canary + players-in-cache counter give detection. **[LOCKED]**.
- 2026-07-07 - Second Codex pass (over the revised design) folded in; its two residual HIGH holes closed:
  (a) **weak room-less Leave** - a room-less leave can only remove a room-less entry; kills the late-`TearDown`
  same-node (even same-room) re-join wipe, with quit-cleanup delegated to the reconcile (verified against our own
  repro sysLog: "No PreviewDisconnect arrived" fired 43s after the re-join); (b) **null-room Join preserves a known
  `roomId`** + game-side `Room` population on the rejoin path upgraded from recommended to REQUIRED. Also:
  `MembershipSeq` stamped once and preserved through requeue (membership ops barred from delayed/offline lanes);
  hydration state machine (single-flight, post-hydration re-lock + fresh snapshot); memory bound reworded to
  online x channels-per-user + per-user channel cap hardening; reconcile grace made configurable/derived + young-skip
  logging; Expire naming guard (`ChannelExpiration` event stays); reject-metric for identity-less membership ops;
  staged rollout order (shadow-log first). **[LOCKED]**.
