---
jira: FP-33074
title: 'Implementation plan - unified fenced membership store (chat-server)'
type: plan
status: draft
spec: artifacts/fix-design.md
---

# FP-33074 Fenced Membership Store - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Subagent-driven execution is NOT recommended here: builds and commits go through the user (see Global Constraints).

**Goal:** Eliminate both FP-33074 root causes (ThreadPool reorder of Join/Leave; inactivity eviction of occupied club channels) by replacing `ChatChannel.participants` with a fenced membership store, per the locked spec [`artifacts/fix-design.md`](artifacts/fix-design.md).

**Architecture:** Membership ops apply INLINE on the FIFO `IncomingQueue` thread with a hybrid room-primary/node-fallback fence (`{roomId, nodeId, peerGen, seq, joinedAt}`); heavy side-effects (backlog replay, ChannelPopulation) stay pooled on atomic snapshots with token recheck. Channel lifetime becomes membership-driven (flag-gated), reconciled against `PlayerCache2` presence; a membership-age canary watches for regressions. Two runtime flags map to the spec's staged rollout: fence enforcement and membership-driven lifetime, both default OFF (shadow).

**Tech Stack:** C# 9 / .NET Framework 4.7.2, Photon Server (classic + GC), MSTest (`LoadBalancing.Tests`), SVN.

## Global Constraints

- **Working tree = the Code branch: `D:\FishingPlanet\src\server\svn\branches\NPN20260602`.** ALL file paths in this plan are relative to that checkout; all edits, builds, tests and commits happen there. (The investigation ran in `MFT20260325`, now the Content branch - its working copy still holds the UNCOMMITTED repro edits: TEMP timeout consts + the EVICT keeper logging. Those are NOT part of this work; discard them in MFT when convenient. The EVICT logging is ported into NPN by Task 2.) NPN divergence from the analyzed code was verified 2026-07-13: only FP-41809 (restricted-country channel redirect in `GameClientPeer_Messaging`, targets misc = "all" channels which are in the persistent set - no interaction with the fence/lifetime work) and sysLog wording in `ChatChannelController`; all plan anchors intact.
- **Builds:** CLI builds do NOT work in this environment. After code changes, ASK THE USER to build `Photon\src-server\Loadbalancing\LoadBalancing.sln`. Never run `msbuild`/`dotnet build` yourself.
- **Tests:** after the user builds - `dotnet test --no-build --filter "<filter>" Photon\src-server\LoadBalancing.Tests\LoadBalancing.Tests.csproj`.
- **VCS = SVN.** "Commit" steps mean: stage nothing, PROVIDE the commit message text and STOP; the user commits. Full message format (per the project commit reference - summary, bullets, task-type line, JIRA link):

  ```
  FP-33074: [Chat] <summary>
  <+ / - / = / * bullets, ASCII-only, no counts>
  (bug: [Chat] messages disappear after awhile fishing)
  https://fishingplanet.atlassian.net/browse/FP-33074
  ```

  Every commit message in this plan ends with those two trailer lines - they are written out in each task.
- **Code comment style:** keep the why-oriented tone across ALL new and touched code (short XML-doc `<summary>` on new public types/members; explain intent and invariants, never restate what the code says). Hard rules: NO task IDs in comments (blame carries them), NO plan/spec cross-references ("Task 6", "split-safety rule 2"), NO historical/"unlike before" phrasing ("replaces...", "no longer...", "stays...") - comments describe the current nature, not the diff.
- **New `.cs` files:** UTF-8 **with BOM**, **CRLF** line endings (convert after Write/Edit: regex `(?<!\r)\n` -> `\r\n`, `Set-Content -Encoding utf8BOM`). `LoadBalancing.csproj` is SDK-style - no `<Compile Include>` needed.
- **Code comments/docs: English.** No KB references in code comments.
- `HashCode.Combine` unavailable (net472). Allman braces, accessibility modifiers, readonly where possible, `var` OK.
- `InternalsVisibleTo("LoadBalancing.Tests")` already present (`Properties/AssemblyInternals.cs`) - internals are testable.
- Runtime flags follow the existing static-property pattern (`ChatChannel.ChannelPopulationRefreshTimeout` set from app startup), NOT direct `ChatServerSettings` reads in domain classes - keeps tests hermetic.
- The NPN tree is pristine (no TEMP repro consts - verified: `ChannelInactivityTimeout = 30`, `ChannelsReleaseTimeout = 10`) and has NO `MiniLog.ChannelEvicted` yet - Task 2 ports that keeper logging (the legacy sweep path in Task 7 uses it).
- Spec cross-reference: Task 1-2 = Pillar 1 fence; Task 3 = game-side Room; Task 4 = fence wiring (shadow); Task 5-6 = inline lane + split-safety; Task 7 = Pillar 2; Task 8 = Pillar 3; Task 9 = Pillar 4. **One code delivery** - the whole plan is implemented and ships together; the flags (`MembershipFenceEnforce`, `MembershipDrivenChannelLifetime`, default OFF) are a post-release config-only activation/rollback lever, NOT a phased-release mechanism.
- **Branch-green invariant (SVN - every commit is immediately visible to the team):** each commit must build, pass tests, AND leave runtime behavior unchanged until the flags are flipped in config. Consequences baked into the tasks: the identity-less reject in Task 2 is log-only until `MembershipFenceEnforce` is on; Tasks 5 and 6 are separate tasks but land as ONE commit (without Task 6 a cold-channel join would briefly block the FIFO thread on Mongo - no such intermediate state may be committed). 9 commits total (incl. the Task 0 rename).
- **Flags are temporary:** after the fix is confirmed on prod, a follow-up cleanup removes both flags, the legacy timer path (`ChannelInactivityTimeout`/`ExpireDate`/`AbsoluteExpireDate` machinery) and the shadow-only branches - tracked in the task backlog "Post-release" section, NOT part of this plan.

---

### Task 0: rename the `Incomming` typo (mechanical, separate commit)

**Files:**
- Modify: every file under `Photon/src-server/` containing the `Incomming` typo (grep first)

- [ ] **Step 1:** `grep -rn "Incomming" Photon/src-server --include="*.cs"` - expect `IncomingGameServerPeer.HandleIncommingMessage`, `HandleIncommingConfirmation`, and possibly siblings in the Club/Master server peers. Rename all occurrences to `Incoming...` (methods are server-internal virtuals/overrides - rename definitions and call sites together; no protocol impact).
- [ ] **Step 2:** ask the user to build; run the full chat test filter (no behavior change expected).
- [ ] **Step 3: Commit** - message:

```
FP-33074: [Chat] Rename Incomming -> Incoming (typo cleanup)
= Mechanical rename of `HandleIncommingMessage()`/`HandleIncommingConfirmation()` and sibling occurrences across server peers; no behavior change
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

(Later tasks reference the corrected `HandleIncomingMessage` name.)

---

### Task 1: `ChannelMembership` fenced store (pure logic, TDD)

**Files:**
- Create: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMembership.cs`
- Test: `Photon/src-server/LoadBalancing.Tests/ChannelMembershipTest.cs`

**Interfaces:**
- Produces: `MembershipToken` (readonly struct: `string RoomId, Guid? NodeId, int PeerGen, long Seq`; `bool HasIdentity`), `MemberEntry` (`RoomId, NodeId, PeerGen, Seq, JoinedAt`), `LeaveVerdict` enum (`Removed, NotMember, IgnoredRoomMismatch, IgnoredWeakRoomless, IgnoredNodeMismatch, IgnoredStaleSeq`), `ChannelMembership` (`bool ApplyJoin(string userId, MembershipToken t, DateTime now)`, `LeaveVerdict ApplyLeave(string userId, MembershipToken t, bool enforceFence)`, `LeaveVerdict EvaluateLeave(...)`, `string[] SnapshotUserIds()`, `KeyValuePair<string, MemberEntry>[] SnapshotEntries()`, `int Count`, `long? GetSeq(string userId)`, `bool RemoveExact(string userId, long seq)`). NOT thread-safe - callers hold the channel op lock.

- [ ] **Step 1: Write the store**

```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace Photon.LoadBalancing.ChatServer.Channeling
{
    // Identity of a channel-membership op source. Captured chat-side at HandleIncommingMessage
    // (nodeId/peerGen) and relayed by the game node (roomId); seq is stamped once on the FIFO stage.
    public readonly struct MembershipToken
    {
        public readonly string RoomId;   // room the op was issued from; null for teardown/legacy rejoin ops
        public readonly Guid? NodeId;    // source game node ServerId; null if the peer never registered
        public readonly int PeerGen;     // source peer ConnectionId - generation tiebreak for same-ServerId reconnects
        public readonly long Seq;        // FIFO arrival-order stamp (stamp-once, preserved through requeue)

        public MembershipToken(string roomId, Guid? nodeId, int peerGen, long seq)
        {
            RoomId = roomId;
            NodeId = nodeId;
            PeerGen = peerGen;
            Seq = seq;
        }

        public bool HasIdentity => RoomId != null || NodeId != null;
    }

    public class MemberEntry
    {
        public string RoomId;
        public Guid? NodeId;
        public int PeerGen;
        public long Seq;
        public DateTime JoinedAt;
    }

    public enum LeaveVerdict
    {
        Removed,
        NotMember,
        IgnoredRoomMismatch,   // stale cross-room leave (rooms known, differ)
        IgnoredWeakRoomless,   // room-less leave cannot remove a room-fenced entry
        IgnoredNodeMismatch,   // room-less leave from a different node / peer generation
        IgnoredStaleSeq,       // op older than the entry (requeue/retry straggler)
    }

    // Fenced per-channel membership (FP-33074). Replaces the bare participants List<string>.
    // NOT thread-safe: every call must run under the owning channel's op lock.
    public class ChannelMembership
    {
        private readonly Dictionary<string, MemberEntry> entries = new Dictionary<string, MemberEntry>();

        public int Count => entries.Count;

        // Join = newest-wins upsert. A null-room join must NOT erase a known room
        // (a room-less rejoin would otherwise downgrade the fence for a later stale leave).
        public bool ApplyJoin(string userId, MembershipToken token, DateTime now)
        {
            if (entries.TryGetValue(userId, out var entry))
            {
                if (token.Seq < entry.Seq)
                    return false; // stale straggler (insurance)

                if (token.RoomId != null)
                    entry.RoomId = token.RoomId;
                entry.NodeId = token.NodeId;
                entry.PeerGen = token.PeerGen;
                entry.Seq = token.Seq;
                entry.JoinedAt = now;
                return true;
            }

            entries[userId] = new MemberEntry
            {
                RoomId = token.RoomId,
                NodeId = token.NodeId,
                PeerGen = token.PeerGen,
                Seq = token.Seq,
                JoinedAt = now,
            };
            return true;
        }

        // Hybrid fence: room primary, node fallback, room-less leave is weak.
        public LeaveVerdict EvaluateLeave(string userId, MembershipToken token)
        {
            if (!entries.TryGetValue(userId, out var entry))
                return LeaveVerdict.NotMember;

            if (token.Seq < entry.Seq)
                return LeaveVerdict.IgnoredStaleSeq;

            if (token.RoomId != null && entry.RoomId != null)
                return token.RoomId == entry.RoomId ? LeaveVerdict.Removed : LeaveVerdict.IgnoredRoomMismatch;

            // Room-less leave is WEAK: it may remove only a room-less entry.
            // A late teardown leave must never kill a fresh room-fenced (re)join.
            if (entry.RoomId != null)
                return LeaveVerdict.IgnoredWeakRoomless;

            if (entry.NodeId != null && token.NodeId != null)
            {
                if (entry.NodeId != token.NodeId)
                    return LeaveVerdict.IgnoredNodeMismatch;
                if (entry.PeerGen != 0 && token.PeerGen != 0 && entry.PeerGen != token.PeerGen)
                    return LeaveVerdict.IgnoredNodeMismatch;
                return LeaveVerdict.Removed;
            }

            // No common identity to compare - a weak leave cannot remove.
            return LeaveVerdict.IgnoredWeakRoomless;
        }

        // enforceFence=false (shadow mode): the removal applies regardless of the verdict,
        // the verdict is only reported for logging. enforceFence=true: the fence gates the removal.
        public LeaveVerdict ApplyLeave(string userId, MembershipToken token, bool enforceFence)
        {
            var verdict = EvaluateLeave(userId, token);
            bool remove = verdict == LeaveVerdict.Removed || (!enforceFence && verdict != LeaveVerdict.NotMember);
            if (remove)
                entries.Remove(userId);
            return verdict;
        }

        public string[] SnapshotUserIds() => entries.Keys.ToArray();

        public KeyValuePair<string, MemberEntry>[] SnapshotEntries() => entries.ToArray();

        public long? GetSeq(string userId) => entries.TryGetValue(userId, out var entry) ? entry.Seq : (long?)null;

        // Reconcile-safe removal: drop the entry only if it was not re-joined since inspection.
        public bool RemoveExact(string userId, long seq)
        {
            if (entries.TryGetValue(userId, out var entry) && entry.Seq == seq)
            {
                entries.Remove(userId);
                return true;
            }
            return false;
        }
    }
}
```

- [ ] **Step 2: Write the tests** (`ChannelMembershipTest.cs`, `[TestCategory("Unit")]`, namespace `Photon.LoadBalancing.UnitTests`)

Cover every fence scenario from the spec table. Helper: `private static MembershipToken T(string room, string node, int gen, long seq) => new MembershipToken(room, node == null ? (Guid?)null : GuidFromName(node), gen, seq);` where `GuidFromName` maps "N1"/"N2" to fixed Guids.

```csharp
[TestMethod] [TestCategory("Unit")]
public void Join_Then_LateCrossRoomLeave_IsIgnored()          // travel A->B, late Leave(A): room mismatch
{
    var m = new ChannelMembership();
    m.ApplyJoin("u", T("B", "N2", 1, 10), DateTime.UtcNow);
    var v = m.ApplyLeave("u", T("A", "N1", 2, 11), enforceFence: true);
    Assert.AreEqual(LeaveVerdict.IgnoredRoomMismatch, v);
    Assert.AreEqual(1, m.Count);
}

[TestMethod] public void OrderedLeaveThenJoin_NetMember() { /* Leave(A) removes, Join(B) re-adds -> Count==1, RoomId=="B" */ }
[TestMethod] public void SameNode_CrossRoom_LateLeave_Ignored() { /* entry room B node N1; leave room A node N1 -> IgnoredRoomMismatch (the case nodeId-only missed) */ }
[TestMethod] public void RoomlessLeave_CannotRemove_RoomedEntry() { /* entry has room; leave(null room, same node+gen) -> IgnoredWeakRoomless (late TearDown case) */ }
[TestMethod] public void RoomlessLeave_Removes_RoomlessEntry_SameNodeGen() { /* both room-less, node+gen match -> Removed */ }
[TestMethod] public void RoomlessLeave_NodeMismatch_Ignored() { /* both room-less, different node -> IgnoredNodeMismatch */ }
[TestMethod] public void RoomlessLeave_PeerGenMismatch_Ignored() { /* same node, gen 1 vs 2 -> IgnoredNodeMismatch */ }
[TestMethod] public void StaleSeq_LeaveRejected() { /* entry seq 10; leave seq 5 -> IgnoredStaleSeq */ }
[TestMethod] public void StaleSeq_JoinRejected() { /* join seq 5 onto entry seq 10 -> ApplyJoin returns false, entry unchanged */ }
[TestMethod] public void NullRoomJoin_PreservesKnownRoom() { /* entry room B; join(null room, seq 11) -> RoomId still "B", Seq==11 */ }
[TestMethod] public void ShadowLeave_RemovesButReportsVerdict() { /* enforceFence:false, room mismatch -> removed anyway, verdict==IgnoredRoomMismatch */ }
[TestMethod] public void RemoveExact_OnlyWhenSeqUnchanged() { /* RemoveExact with old seq after re-join -> false, still member */ }
[TestMethod] public void JoinResets_JoinedAt() { /* re-join updates JoinedAt */ }
```

Write each body out fully in the file (the sketches above define arrange/act/assert - expand them literally).

- [ ] **Step 3: Normalize new files** - CRLF + UTF-8 BOM (both files).
- [ ] **Step 4: Ask the user to build** `LoadBalancing.sln`.
- [ ] **Step 5: Run tests** - `dotnet test --no-build --filter "FullyQualifiedName~ChannelMembershipTest" Photon\src-server\LoadBalancing.Tests\LoadBalancing.Tests.csproj`. Expected: all PASS.
- [ ] **Step 6: Commit** - provide message:

```
FP-33074: [Chat] Add fenced per-channel membership store (room-primary/node-fallback fence)
+ `ChannelMembership` with `MembershipToken` {roomId, nodeId, peerGen, seq} and newest-wins Join / fenced Leave semantics: room fence primary, node+peerGen fallback, weak room-less leave, stale-seq rejection
+ Unit tests covering the full fence scenario matrix
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 2: identity plumbing - `ChatMessage` fields, stamping, identity-less rejection

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Messages/ChatMessage.cs` (ctor + new members)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/GameServer/IncomingGameServerPeer.cs` (`HandleIncomingMessage` - post-Task-0 name)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Processing/ChatProcessor.cs` (seq stamp in `ProcessMessage`)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/MiniLog.cs` (FENCE logger)
- Test: `Photon/src-server/LoadBalancing.Tests/ChatMembershipIdentityTest.cs` (new)

**Interfaces:**
- Consumes: `MembershipToken` (Task 1).
- Produces: `ChatMessage.Room` (string), `ChatMessage.SourceNodeId` (Guid?), `ChatMessage.SourcePeerGen` (int), `ChatMessage.MembershipSeq` (long), `ChatMessage.IsChannelMembershipOp` (bool), `ChatMessage.GetMembershipToken()`; `ChatProcessor.StampMembershipSeq(ChatMessage)` (internal static); `MiniLog.FenceReject(ChatMessage, string reason)`, `MiniLog.Fence(ChatMessage, string verdict)`.

- [ ] **Step 1: `ChatMessage` additions** (inside the class; `using Newtonsoft.Json;` is already imported):

```csharp
// --- FP-33074 membership identity (chat-server-side; not part of the client payload) ---

[JsonIgnore] public string Room { get; set; }              // room the op was issued from (game relay's ChatMessageEvent.Room)
[JsonIgnore] public Guid? SourceNodeId { get; set; }       // IncomingGameServerPeer.ServerId of the source node
[JsonIgnore] public int SourcePeerGen { get; set; }        // IncomingGameServerPeer.ConnectionId (peer generation)
[JsonIgnore] public long MembershipSeq { get; set; }       // FIFO arrival stamp; 0 = not stamped yet (stamp-once)

// Channel membership op = join/leave/expire addressed to a dynamic channel (same condition
// ProcessChatMessage uses to route channel processing).
[JsonIgnore]
public bool IsChannelMembershipOp =>
    (Data == ChatChannelsCommands.Join || Data == ChatChannelsCommands.Leave || Data == ChatChannelsCommands.Expire)
    && !string.IsNullOrEmpty(Channel)
    && !StaticChatChannels.IsStatic(Channel)
    && string.IsNullOrWhiteSpace(Recepient);

public Channeling.MembershipToken GetMembershipToken() =>
    new Channeling.MembershipToken(Room, SourceNodeId, SourcePeerGen, MembershipSeq);
```

In the `ChatMessage(ChatMessageEvent messageEvent)` ctor add `Room = messageEvent.Room;` next to the `Channel = messageEvent.Channel;` line. Check `StaticChatChannels`' namespace is already usable from this file (it is used in `ChatProcessor`; add `using Photon.LoadBalancing.ChatServer.Processing;` if the compiler asks - `StaticChatChannels` lives there).

- [ ] **Step 2: MiniLog FENCE logger + port the EVICT keeper** (NPN has neither yet; EVICT was authored during the investigation and lives only in the MFT working copy):

```csharp
private static readonly ILogger FenceLog = LogManager.GetLogger("FENCE");
private static readonly ILogger ChannelEvictLog = LogManager.GetLogger("EVICT");
```

```csharp
// Logs eviction of a channel that still had participants - the signal that members were silently
// dropped (no per-user Leave is emitted on eviction). Empty-channel evictions are normal and not
// logged; any debug users among the dropped participants are listed.
public static void ChannelEvicted(string channelId, string[] participants, int cachedMessagesCount)
{
    if (participants == null || participants.Length == 0)
    {
        return;
    }

    var debugParticipants = participants.Where(p => DebugUsersCache.IsDebugUser(p)).ToArray();
    var debugSuffix = debugParticipants.Length > 0
        ? $"; dropped debug user(s): {string.Join(", ", debugParticipants)}"
        : string.Empty;
    ChannelEvictLog.Info($"Channel {channelId} evicted with {participants.Length} participant(s) still joined, {cachedMessagesCount} cached message(s){debugSuffix}");
}
```

(`using System.Linq;` at the top of `MiniLog.cs`.)

```csharp
// Fence anomalies are rare (stale/foreign membership ops) - log them unconditionally,
// they are the shadow-stage telemetry that validates the fence before enforcement.
public static void FenceReject(ChatMessage message, string reason)
{
    FenceLog.Info($"REJECT {reason} {message.Brief()}");
}

public static void Fence(ChatMessage message, string verdict)
{
    FenceLog.Info($"{verdict} room={message.Room ?? "-"} node={message.SourceNodeId?.ToString() ?? "-"} gen={message.SourcePeerGen} seq={message.MembershipSeq} {message.Brief()}");
}
```

- [ ] **Step 3: stamp identity at `HandleIncomingMessage`** - after `var message = new ChatMessage(messageEvent);` and before `MiniLog.New(message);`:

```csharp
if (message.IsChannelMembershipOp)
{
    message.SourceNodeId = ServerId;
    message.SourcePeerGen = ConnectionId;

    // Membership ops need an identity for the fence, and unregistered peers may send
    // chat messages, so ServerId is not guaranteed here. Log always; drop only when the
    // fence is enforced - a legitimate identity-less producer we might have missed must
    // keep working until enforcement is switched on.
    if (!ServerId.HasValue && string.IsNullOrEmpty(message.Room))
    {
        MiniLog.FenceReject(message, Channeling.ChatChannel.MembershipFenceEnforce ? "no-identity DROPPED" : "no-identity (would drop)");
        Log.Warn($"Identity-less channel membership op: {message}");
        if (Channeling.ChatChannel.MembershipFenceEnforce)
            return;
    }
}
```

(The join/leave/expire early-`return` that skips persistence sits AFTER `EnqueueChatMessage` today - the reject above must run BEFORE `application.EnqueueChatMessage(message);`. `ChatChannel.MembershipFenceEnforce` is introduced in Task 4 - in THIS task reference it as a forward dependency by adding the static property to `ChatChannel` here (3 lines, default false), and Task 4 only wires it to the setting.)

- [ ] **Step 4: stamp-once seq in `ChatProcessor`** - add field + helper, call at the top of `ProcessMessage`:

```csharp
private static long membershipSeqCounter;

// Stamp arrival order once, on the FIFO IncomingQueue thread. A requeued/retried op
// keeps its original stamp - a retry must not acquire a fresher seq.
internal static void StampMembershipSeq(ChatMessage message)
{
    if (message.IsChannelMembershipOp && message.MembershipSeq == 0)
        message.MembershipSeq = System.Threading.Interlocked.Increment(ref membershipSeqCounter);
}
```

```csharp
public void ProcessMessage(ChatMessage message)
{
    StampMembershipSeq(message);
    Executor(() => ProcessMessageSync(message));        // in ProcessMessage
}
```

- [ ] **Step 5: tests** (`ChatMembershipIdentityTest.cs`) - construct `ChatMessage` directly (the 15-arg ctor used by `ChatChannelsCacheTest`) plus event-ctor cases:

```csharp
[TestMethod] public void EventCtor_CopiesRoom() { var e = new ChatMessageEvent { Timestamp = DateTime.UtcNow.Ticks, Sender = "s", SenderName = "n", SenderLevel = 1, SenderRank = 1, Room = "room1", Channel = "club1", Data = ChatChannelsCommands.Join }; var m = new ChatMessage(e); Assert.AreEqual("room1", m.Room); }
[TestMethod] public void IsChannelMembershipOp_TrueForJoinToDynamicChannel() { /* data=join, channel="club1", recepient empty -> true */ }
[TestMethod] public void IsChannelMembershipOp_FalseForPlainMessage_AndForStaticChannel() { /* data=null -> false; channel=StaticChatChannels.Local + join -> false */ }
[TestMethod] public void StampMembershipSeq_StampsOnce_AndOnlyMembershipOps()
{
    var join = MakeJoin("club1");                       // helper building a join ChatMessage
    ChatProcessor.StampMembershipSeq(join);
    var first = join.MembershipSeq;
    Assert.AreNotEqual(0, first);
    ChatProcessor.StampMembershipSeq(join);             // requeue path - must keep the stamp
    Assert.AreEqual(first, join.MembershipSeq);
    var plain = MakeText("club1");
    ChatProcessor.StampMembershipSeq(plain);
    Assert.AreEqual(0, plain.MembershipSeq);
}
[TestMethod] public void GetMembershipToken_CarriesAllFields() { /* set Room/SourceNodeId/SourcePeerGen/MembershipSeq -> token fields equal */ }
```

- [ ] **Step 6: CRLF+BOM on the new test file; ask the user to build; run** `dotnet test --no-build --filter "FullyQualifiedName~ChatMembershipIdentityTest" ...` Expected: PASS. Also re-run `ChannelMembershipTest` (no regressions).
- [ ] **Step 7: Commit** - message:

```
FP-33074: [Chat] Carry membership-op identity to the chat server and stamp arrival order
+ `ChatMessage`: `Room` (copied from the relay event), `SourceNodeId`/`SourcePeerGen` (source peer), `MembershipSeq` (stamp-once FIFO order), `IsChannelMembershipOp`, `GetMembershipToken()`
+ `HandleIncomingMessage()`: attach node identity to membership ops; log identity-less ones (drop deferred to fence enforcement)
+ `MiniLog`: FENCE logger for fence verdicts/rejects
= `ChatProcessor.ProcessMessage()`: stamp `MembershipSeq` on the FIFO thread before pool dispatch
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 3: game-side `Room` population on server-generated channel ops

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/GameServer/GameClientPeer_Messaging.cs` (static overload + both instance callers)

**Interfaces:**
- Consumes: `ChatMessageRequest.Room` (exists).
- Produces: rejoin/teardown-path ops carry `Room` whenever a room is known (spec: REQUIRED - without it every rejoin is a null-room Join).

- [ ] **Step 1:** add a `room` parameter to the **static** builder and set it:

```csharp
private static ChatMessageRequest SendMessageUsingChatServer(
    string sender, string senderName, int level, int rank, string externalId, string clubName,
    string recepient, string group,
    string message, string data, bool isOffline, DateTime expiration,
    bool isOneTime = false, string channel = null, string oneTimeData = null,
    string room = null)
{
    var messageRequest = new ChatMessageRequest
    {
        // ... existing initializers unchanged ...
        Group = group,
        Room = room,
    };
    // ... rest unchanged ...
}
```

- [ ] **Step 2:** the instance profile-overload (`public void SendMessageUsingChatServer(Profile profile, ...)`, currently forwarding at its `var messageRequest = SendMessageUsingChatServer(...)` call) passes the current room:

```csharp
var messageRequest = SendMessageUsingChatServer(
    profile.UserId.ToString(), profile.Name, profile.Level, profile.Rank, profile.ExternalId, profile.ClubContext.Club?.Name,
    recepient, group,
    message, data, isOffline, expiration,
    isOneTime, channel, oneTimeData,
    room: RoomReference?.Room?.Name);
```

`SendLocalMessageOrUsingChatServer` forwards the same way (`room: RoomReference?.Room?.Name`).

- [ ] **Step 3:** ask the user to build (compile check). No unit test - the builder is static/private and wired to `ApplicationBase.Instance`; verification is Task 4's FENCE shadow log on the local repro (rejoin ops must show `room=<name>`, teardown ops `room=-`).
- [ ] **Step 4: Commit** - message:

```
FP-33074: [Chat] Populate Room on server-generated chat channel ops
= Static `SendMessageUsingChatServer()` builder gains a `room` parameter; instance callers pass `RoomReference?.Room?.Name`, so `RejoinAllChannels()` joins are room-fenced (teardown leaves are room-less by nature)
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 4: `ChatChannel` on the fenced store (shadow flag), `Expire` retirement, TEMP revert #1

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChatChannel.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/ChatApplication.cs` (flag init)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/ChatServerSettings.settings` + `.Designer.cs` (new setting)
- Modify: `Photon/src-server/LoadBalancing.Tests/ChatChannelsCacheTest.cs` (Expire test)
- Test: `Photon/src-server/LoadBalancing.Tests/ChatChannelFenceTest.cs` (new)

**Interfaces:**
- Consumes: `ChannelMembership` (T1), `ChatMessage` identity members (T2).
- Produces: `ChatChannel.MembershipFenceEnforce` (public static bool, default false); `ChatChannel.Membership` (internal `ChannelMembership` accessor for cache/reconcile/tests); `Participants`/`ParticipantsCount` unchanged in shape.

- [ ] **Step 1:** replace the list with the store inside `ChatChannel`:

```csharp
// Fenced channel membership - the store the delivery fan-out enumerates. All access under channelOpLock.
private readonly ChannelMembership membership = new ChannelMembership();
internal ChannelMembership Membership { get { return membership; } }

// False = shadow mode: ops apply unfenced, fence verdicts are only logged.
public static bool MembershipFenceEnforce { get; set; }

public string[] Participants { get { lock (channelOpLock) return membership.SnapshotUserIds(); } }
public int ParticipantsCount { get { lock (channelOpLock) return membership.Count; } }
```

`ProcessMessage` cases:

```csharp
case ChatChannelsCommands.Join:
    membership.ApplyJoin(message.Sender, message.GetMembershipToken(), DT.Helper.UtcNow);
    // ... existing backlog computation (channelContent / firstMessage) unchanged ...
    MiniLog.Join(message.Sender, Id, channelContent.Length);
    break;

case ChatChannelsCommands.Leave:
    var verdict = membership.ApplyLeave(message.Sender, message.GetMembershipToken(), MembershipFenceEnforce);
    if (verdict != LeaveVerdict.Removed && verdict != LeaveVerdict.NotMember)
        MiniLog.Fence(message, (MembershipFenceEnforce ? "IGNORED " : "WOULD-IGNORE ") + verdict);
    channelContent = new ChatMessage[] { };
    MiniLog.Leave(message.Sender, Id);
    break;

case ChatChannelsCommands.Expire:
    // The 'expire' close command is retired: it never had a shipped caller, and honoring it
    // would silently unsubscribe every member of an occupied channel. Channel lifetime is
    // membership-driven; a channel dies when its last member leaves.
    MiniLog.Fence(message, "EXPIRE-IGNORED");
    break;
```

Delete the `AbsoluteExpireDate` assignment; keep the property itself until Task 7 removes the timer machinery (`AbsoluteExpireDate` stays null from here on).

- [ ] **Step 2:** verify `ChannelInactivityTimeout` is the pristine `30` in the NPN tree (it is - the TEMP repro edit lived only in the MFT working copy; nothing to change here).
- [ ] **Step 3:** setting + flag init. `ChatServerSettings.settings` - add `MembershipFenceEnforce` (bool, Application scope, default `False`); mirror the generated block in `ChatServerSettings.Designer.cs` (copy the `IsDevServer` block shape, rename, `DefaultSettingValue("False")`). In `ChatApplication` where the processor/caches are set up (`Setup`, next to the `UseThreadPoolExecutor` wiring), add:

```csharp
ChatChannel.MembershipFenceEnforce = ChatServerSettings.Default.MembershipFenceEnforce;
```

- [ ] **Step 4:** update `ChatChannelsCacheTest` - the test sending `data: ChatChannelsCommands.Expire` now expects NO expiration effect (channel keeps its `ExpireDate`; `AbsoluteExpireDate` stays null). Adjust asserts accordingly.
- [ ] **Step 5:** new `ChatChannelFenceTest.cs` - end-to-end through `ChatChannel.ProcessMessage` with the 15-arg ctor + identity fields set manually:

```csharp
private static ChatMessage Op(string data, string room, Guid? node, int gen, long seq, string channel = "club1", string user = "u1")
{
    var m = new ChatMessage(userId: user, sender: user, senderName: "U", level: 1, rank: 1, externalId: null, clubName: null,
        recepient: null, group: null, message: null, data: data, isOffline: false,
        expiration: DateTime.UtcNow.AddMinutes(10), isOneTime: false, channel: channel, oneTimeData: null);
    m.Room = room; m.SourceNodeId = node; m.SourcePeerGen = gen; m.MembershipSeq = seq;
    return m;
}

[TestMethod] public void Enforce_LateCrossRoomLeave_KeepsMember()
{
    ChatChannel.MembershipFenceEnforce = true;
    try
    {
        var ch = new ChatChannel("club1", persistent: false);
        ch.ProcessMessage(Op(ChatChannelsCommands.Join, "B", NodeB, 1, 10), out _, out _, out _, out _);
        ch.ProcessMessage(Op(ChatChannelsCommands.Leave, "A", NodeA, 1, 11), out _, out _, out _, out _);
        Assert.AreEqual(1, ch.ParticipantsCount);   // stale travel leave ignored
    }
    finally { ChatChannel.MembershipFenceEnforce = false; }
}

[TestMethod] public void Shadow_LateCrossRoomLeave_StillRemoves_LegacyBehavior() { /* enforce=false -> Count==0 */ }
[TestMethod] public void Enforce_RoomlessTeardownLeave_CannotRemoveRoomedEntry() { /* join room B; leave room=null same node -> member stays */ }
[TestMethod] public void Enforce_OrderedLeaveJoin_Works() { /* leave(B) seq11 after join(B) seq10 -> removed; join(B) seq12 -> member */ }
[TestMethod] public void Expire_IsNoOp() { /* Expire op -> AbsoluteExpireDate stays null */ }
```

(Every test that flips the static flag must restore it in `finally` - MSTest shares statics.)

- [ ] **Step 6:** CRLF+BOM; user builds; run `dotnet test --no-build --filter "FullyQualifiedName~ChatChannelFenceTest|FullyQualifiedName~ChatChannelsCacheTest" ...` Expected: PASS.
- [ ] **Step 7:** local smoke (manual, with the user): start the local chat server, run the **rapid leave+join debug trigger** (the client-side editor hotkey that sends back-to-back leave+join of the club channel programmatically - historically referred to as "F5" in this task's logs) + travel in club chat with the debug user; grep `Chat.log` for `FENCE` lines - rejoin ops must carry `room=`, verdicts only `WOULD-IGNORE` (flag off). This is the shadow telemetry working.
- [ ] **Step 8: Commit** - message:

```
FP-33074: [Chat] Switch channel membership to the fenced store (shadow mode) and retire the dead Expire command
= `ChatChannel.participants` List<string> replaced by `ChannelMembership`; Join/Leave apply through the hybrid fence, gated by `MembershipFenceEnforce` (default off = legacy apply + WOULD-IGNORE fence logging)
- `Expire` channel command no longer sets `AbsoluteExpireDate` (dead since FP-13595 - no caller ever shipped; honoring it silently dropped occupied channels); logged and ignored
+ `MembershipFenceEnforce` chat-server setting, pushed to `ChatChannel` at startup
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 5: inline membership lane + pooled side-effects on snapshots (warm channels)

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Processing/ChatProcessor.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMemoryCache.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChatChannel.cs`
- Create: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/MembershipOpResult.cs`
- Test: `Photon/src-server/LoadBalancing.Tests/MembershipInlineLaneTest.cs` (new)

**Interfaces:**
- Consumes: T1/T2/T4 artifacts.
- Produces: `ChannelMemoryCache.ApplyMembershipOp(ChatMessage) -> MembershipOpResult` (atomic get/create-without-hydration + mutate under `channelsLock` -> `channelOpLock`); `ChatChannel.ApplyMembershipOp(ChatMessage) -> MembershipOpResult`; `MembershipOpResult` (`Channel, Message, ParticipantsSnapshot, ParticipantCount, BacklogSnapshot, FirstMessage, MemberSeq`); `ChatProcessor` routes membership ops inline.

- [ ] **Step 1:** `MembershipOpResult.cs`:

```csharp
using Photon.LoadBalancing.ChatServer.Messages;

namespace Photon.LoadBalancing.ChatServer.Channeling
{
    // Atomic snapshot taken inside the membership mutation (under the channel op lock).
    // Pooled side-effects must use ONLY this snapshot - never re-enumerate live channel state.
    public class MembershipOpResult
    {
        public ChatChannel Channel;
        public ChatMessage Message;
        public string[] ParticipantsSnapshot;
        public int ParticipantCount = -1;      // -1 = do not broadcast ChannelPopulation
        public ChatMessage[] BacklogSnapshot;  // join only; null while the channel history is still hydrating
        public ChatMessage FirstMessage;
        public long MemberSeq;                 // membership token for the pre-replay recheck
    }
}
```

- [ ] **Step 2:** `ChatChannel.ApplyMembershipOp` - the membership cases of `ProcessMessage`, snapshot-returning (reuse the existing backlog/lastId code by extracting it into `private ChatMessage[] ComputeBacklogNoLock(string lastMessageId)`):

```csharp
public MembershipOpResult ApplyMembershipOp(ChatMessage message)
{
    lock (channelOpLock)
    {
        var result = new MembershipOpResult { Channel = this, Message = message };

        switch (message.Data)
        {
            case ChatChannelsCommands.Join:
                membership.ApplyJoin(message.Sender, message.GetMembershipToken(), DT.Helper.UtcNow);
                result.BacklogSnapshot = ComputeBacklogNoLock(message.Message);
                result.FirstMessage = messages.FirstOrDefault();
                MiniLog.Join(message.Sender, Id, result.BacklogSnapshot.Length);
                break;

            case ChatChannelsCommands.Leave:
                var verdict = membership.ApplyLeave(message.Sender, message.GetMembershipToken(), MembershipFenceEnforce);
                if (verdict != LeaveVerdict.Removed && verdict != LeaveVerdict.NotMember)
                    MiniLog.Fence(message, (MembershipFenceEnforce ? "IGNORED " : "WOULD-IGNORE ") + verdict);
                result.BacklogSnapshot = new ChatMessage[] { };
                MiniLog.Leave(message.Sender, Id);
                break;

            case ChatChannelsCommands.Expire:
                MiniLog.Fence(message, "EXPIRE-IGNORED");
                return result;
        }

        if (!Persistent) RefreshExpireDate();

        result.ParticipantsSnapshot = membership.SnapshotUserIds();
        result.MemberSeq = membership.GetSeq(message.Sender) ?? 0;

        var now = DT.Helper.UtcNow;
        if (!ChatChannelNamingUtils.IsHugeChannel(Id) ||
            now.Subtract(channelPopulationRefreshTime) > ChannelPopulationRefreshTimeout)
        {
            result.ParticipantCount = membership.Count;
            channelPopulationRefreshTime = now;
        }

        return result;
    }
}
```

`ChatChannel.ProcessMessage`'s Join/Leave/Expire cases now delegate: `var r = ApplyMembershipOp(message); channelContent = r.BacklogSnapshot; firstMessage = r.FirstMessage; channelParticipantCount = r.ParticipantCount;` - wait, `ApplyMembershipOp` takes `channelOpLock` and `ProcessMessage` already holds it. Make the lock **reentrant-safe by construction**: extract `ApplyMembershipOpNoLock(message)` (the body above without the `lock`), have `ApplyMembershipOp` = `lock (channelOpLock) return ApplyMembershipOpNoLock(message);`, and let `ProcessMessage` call the NoLock variant from within its own lock. (C# `lock` is reentrant, but keep the NoLock convention this file already uses for clarity.)

- [ ] **Step 3:** `ChannelMemoryCache.ApplyMembershipOp` - atomic get/create+mutate (no DAL under the lock; hydration deferred - until Task 6, warm-create only, so pass `loadHistory: true` semantics through a split of `GetOrCreateChannel`):

```csharp
// Membership ops enter here from the FIFO thread. Get/create + mutate is atomic
// with respect to channel removal (lock order: channelsLock -> channelOpLock).
public MembershipOpResult ApplyMembershipOp(ChatMessage message)
{
    lock (channelsLock)
    {
        var channel = GetOrCreateChannelNoLock(message.Channel, message.Sender, persistent: false);
        return channel.ApplyMembershipOp(message);
    }
}
```

Refactor: `GetOrCreateChannel(...)` keeps its public signature and behavior (locks `channelsLock`, calls `GetOrCreateChannelNoLock`); the body moves to `private ChatChannel GetOrCreateChannelNoLock(...)`. (Task 6 removes the DAL load from this inline path; until then a cold club channel loads history under the lock exactly as today - no behavior change.)

- [ ] **Step 4:** `ChatProcessor` - inline lane + pooled side-effects:

```csharp
public void ProcessMessage(ChatMessage message)
{
    StampMembershipSeq(message);

    // Membership ops apply inline on this (single, FIFO) thread: join/leave correctness
    // depends on arrival order, which ThreadPool scheduling would not preserve.
    if (message.IsChannelMembershipOp)
    {
        ProcessMembershipOpInline(message);
        return;
    }

    Executor(() => ProcessMessageSync(message));        // in ProcessMessage
}

private void ProcessMembershipOpInline(ChatMessage message)
{
    try
    {
        var result = Channels.ApplyMembershipOp(message);
        MiniLog.Processed(message);
        if (Processed != null) Processed(message, MessageProcessingStatus.Processed);
        Executor(() => ProcessMembershipSideEffects(result));   // fan-out is not order-sensitive and must not stall the FIFO lane
    }
    catch (Exception ex)
    {
        Log.Error("Exception in ProcessMembershipOpInline", ex);
        OnException(ex);
    }
    finally
    {
        ChatWinPerfCouterHelper.RecordProcessedMessage();
    }
}

private void ProcessMembershipSideEffects(MembershipOpResult r)
{
    var message = r.Message;

    // 1. Backlog replay to the joiner - with a membership recheck: an inline Leave may have
    //    superseded this join while the task waited for a pool thread; replaying then would
    //    deliver history to a player who already left.
    if (r.BacklogSnapshot != null && r.BacklogSnapshot.Length > 0)
    {
        if (r.Channel.IsMemberWithSeq(message.Sender, r.MemberSeq))
        {
            foreach (var chatMessage in r.BacklogSnapshot)
            {
                var newMessage = chatMessage.Clone(preserveTimestamp: true);
                newMessage.Recepient = message.Sender;
                newMessage.IsOffline = false;
                newMessage.ProcessingSource = MessageProcessingSource.ChannelJoin;
                ProcessMessageSync(newMessage);
            }

            if ((ChatChannelNamingUtils.IsClubChatChannelName(r.Channel.Id) || ChatChannelNamingUtils.IsFtgChatChannelName(r.Channel.Id)) && r.FirstMessage != null)
            {
                foreach (var participant in r.ParticipantsSnapshot)
                {
                    var newMessage = message.Clone(preserveTimestamp: true);
                    newMessage.Sender = Guid.Empty.ToString();
                    newMessage.SenderName = string.Empty;
                    newMessage.Recepient = participant;
                    newMessage.Data = ChatRequests.ChannelExpiration;
                    newMessage.Message = r.FirstMessage.Timestamp.Ticks.ToString();
                    newMessage.IsOffline = false;
                    newMessage.IsOneTime = true;
                    newMessage.ProcessingSource = MessageProcessingSource.ChannelExpiration;
                    ProcessMessageSync(newMessage);
                }
            }
        }
        else
            MiniLog.Fence(message, "REPLAY-SKIP superseded");
    }

    // 2. ChannelPopulation - from the atomic snapshot (count and recipients from the SAME state).
    if (r.ParticipantCount >= 0)
    {
        foreach (var participant in r.ParticipantsSnapshot)
        {
            var newMessage = message.Clone(preserveTimestamp: true);
            newMessage.Sender = Guid.Empty.ToString();
            newMessage.SenderName = string.Empty;
            newMessage.Recepient = participant;
            newMessage.Data = ChatRequests.ChannelPopulation;
            newMessage.Message = r.ParticipantCount.ToString();
            newMessage.IsOffline = false;
            newMessage.IsOneTime = true;
            newMessage.ProcessingSource = MessageProcessingSource.ChannelPopulation;
            Enqueue(newMessage);                // ProcessMembershipSideEffects - ChannelPopulation
        }
    }
}
```

`ChatChannel.IsMemberWithSeq`:

```csharp
public bool IsMemberWithSeq(string userId, long seq)
{
    lock (channelOpLock) return membership.GetSeq(userId) == seq;
}
```

`ProcessChatMessage` keeps its channel branch for REGULAR messages only - membership ops never reach it anymore (intercepted in `ProcessMessage`), but leave the routing condition as-is (harmless defense; a membership op arriving via `ProcessMessageSync` from a replay clone has `Recepient` set, so it does not re-enter channel processing).

- [ ] **Step 5:** tests (`MembershipInlineLaneTest.cs`; construct `ChatProcessor` like existing tests do - `DalFactory.InitContainer(new TestParametersProvider()); var processor = new ChatProcessor(DalFactory.GetOfflineMessagePersister(), new PlayerCache2(), cache);` with `UseSyncExecutor()`):

```csharp
[TestMethod] public void MembershipOps_ApplyInArrivalOrder_LeaveThenJoin() { /* ProcessMessage(leave seq auto), ProcessMessage(join) -> member present */ }
[TestMethod] public void MembershipOps_JoinThenLeave_NotMember() { /* reversed -> absent (same room) */ }
[TestMethod] public void ReplaySkipped_WhenLeaveSupersedesJoin()
{
    // join (backlog non-empty via pre-seeded messages), then leave BEFORE side effects run:
    // use UseCustomExecutor capture: replace Executor with a list-collecting executor to defer side effects,
    // apply the leave inline, then run the deferred side-effect action; assert no ChannelJoin replay was produced.
    // (Processed event or TestChatServerListener-style capture - see existing tests for the capture pattern.)
}
[TestMethod] public void PopulationSnapshot_CountMatchesRecipients() { /* 2 joins; snapshot from 2nd join has Count==2 and 2 recipients */ }
```

For executor capture add `internal ChatProcessor UseCollectingExecutor(List<Action> sink)` (3 lines, next to `UseSyncExecutor`) - actions collected, test runs them explicitly.

- [ ] **Step 6:** CRLF+BOM; user builds; `dotnet test --no-build --filter "FullyQualifiedName~MembershipInlineLaneTest|FullyQualifiedName~ChatChannel|FullyQualifiedName~ChannelMembership" ...` Expected: PASS (incl. all prior chat tests - `ChatChannelsCacheTest` exercises the legacy `ProcessMessage` path that now delegates).
- [ ] **Step 7: NO COMMIT YET** - branch-green invariant: without Task 6 a cold-channel join loads Mongo history on the FIFO thread. Proceed straight to Task 6; the two tasks land as one commit (message at the end of Task 6).

---

### Task 6: cold-channel hydration state machine

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChatChannel.cs` (hydration state, pending replays, `Hydrate`)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMemoryCache.cs` (inline path creates without DAL)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Processing/ChatProcessor.cs` (side-effects hydrate-then-replay)
- Test: `Photon/src-server/LoadBalancing.Tests/ChannelHydrationTest.cs` (new)

**Interfaces:**
- Produces: `ChatChannel.HydrationState` (internal enum `NotStarted/InProgress/Done`), `ChatChannel.TryBeginHydration()`, `ChatChannel.CompleteHydration(List<ChatMessage>)`, `ChatChannel.AddPendingReplay(string userId, long seq, string lastId)`, `ChatChannel.TakePendingReplays()`, `ChatChannel.ComputeBacklogFor(string lastId)` (locked snapshot).

- [ ] **Step 1:** `ChatChannel` hydration members:

```csharp
internal enum ChannelHydration { NotStarted, InProgress, Done }

private ChannelHydration hydration;
private readonly List<(string UserId, long Seq, string LastId)> pendingReplays = new List<(string, long, string)>();

// Hydration applies to channels whose message history persists in Mongo (club/UGC/FTG -
// the code calls these "long-living": the LOGICAL channel outlives its in-memory object,
// so a freshly created object must load its history back). Global/waterbody channel
// objects are permanent residents - they never lose state and never need a reload.
public ChatChannel(string channelId, bool persistent) : this(channelId, persistent, hydrated: true) { }

internal ChatChannel(string channelId, bool persistent, bool hydrated)
{
    Id = channelId;
    Persistent = persistent;
    hydration = hydrated ? ChannelHydration.Done : ChannelHydration.NotStarted;
    if (!persistent) RefreshExpireDate();
}

internal bool TryBeginHydration()
{
    lock (channelOpLock)
    {
        if (hydration != ChannelHydration.NotStarted) return false;
        hydration = ChannelHydration.InProgress;
        return true;
    }
}

internal void CompleteHydration(List<ChatMessage> history)
{
    lock (channelOpLock)
    {
        if (history != null)
            foreach (var m in history) AddMessageNoLock(m);   // dedup by Id, insert by Timestamp
        EnsureChannelSizeNoLock();
        hydration = ChannelHydration.Done;
    }
}

internal bool IsHydrated { get { lock (channelOpLock) return hydration == ChannelHydration.Done; } }

internal void AddPendingReplay(string userId, long seq, string lastId)
{
    lock (channelOpLock) pendingReplays.Add((userId, seq, lastId));
}

internal (string UserId, long Seq, string LastId)[] TakePendingReplays()
{
    lock (channelOpLock)
    {
        var r = pendingReplays.ToArray();
        pendingReplays.Clear();
        return r;
    }
}

// Fresh locked snapshot for a deferred replay (post-hydration) - split-safety rule 4.
internal ChatMessage[] ComputeBacklogFor(string lastId)
{
    lock (channelOpLock) return ComputeBacklogNoLock(lastId);
}
```

(`AddMessage`/`EnsureChannelSize` get `...NoLock` cores, public wrappers keep locking - same refactor style as Step 2 of Task 5.)

- [ ] **Step 2:** `ApplyMembershipOpNoLock` Join case becomes hydration-aware:

```csharp
case ChatChannelsCommands.Join:
    membership.ApplyJoin(message.Sender, message.GetMembershipToken(), DT.Helper.UtcNow);
    if (hydration == ChannelHydration.Done)
    {
        result.BacklogSnapshot = ComputeBacklogNoLock(message.Message);
        result.FirstMessage = messages.FirstOrDefault();
    }
    else
    {
        pendingReplays.Add((message.Sender, membership.GetSeq(message.Sender) ?? 0, message.Message));
        result.BacklogSnapshot = null;   // replay deferred until hydration completes
    }
    MiniLog.Join(message.Sender, Id, result.BacklogSnapshot?.Length ?? -1);
    break;
```

- [ ] **Step 3:** inline create without DAL: `ChannelMemoryCache.ApplyMembershipOp` uses a no-hydration create:

```csharp
lock (channelsLock)
{
    ChatChannel channel;
    if (!channelsCache.TryGetValue(message.Channel, out channel))
    {
        // Never touch the DAL under channelsLock on the FIFO thread. Channels with
        // Mongo-persisted history (club/UGC/FTG) start un-hydrated - a pooled task
        // loads the history and only then replays backlogs.
        bool needsHistory = ChatChannelNamingUtils.IsLongLivingChannelName(message.Channel);
        channel = new ChatChannel(message.Channel, persistent: false, hydrated: !needsHistory);
        channelsCache[message.Channel] = channel;
        ChatWinPerfCouterHelper.SetChatChannelsInCacheCount(channelsCache.Count);
    }
    return channel.ApplyMembershipOp(message);
}
```

The legacy `GetOrCreateChannelNoLock` (pooled path, regular messages) keeps loading history inline as today, but must respect hydration: if the channel exists and is un-hydrated it just returns it (the pooled hydration task owns the load; `AddMessage` merges either way).

- [ ] **Step 4:** `ProcessMembershipSideEffects` grows the hydration step at the top:

```csharp
// 0. Cold channel: single-flight hydration, then flush all deferred replays.
if (!r.Channel.IsHydrated && r.Channel.TryBeginHydration())
{
    List<ChatMessage> history = null;
    if (ChatChannelNamingUtils.IsLongLivingChannelName(r.Channel.Id))
    {
        int maxSize = ChatChannel.GetMaxChannelSize(r.Channel.Id);
        history = DalFactory.GetChatLogger().FindByChannel(r.Channel.Id, limit: maxSize)
            .Select(MapDtoToChatMessage).ToList();   // extract today's dto->ChatMessage mapping from GetOrCreateChannel into a helper
    }
    r.Channel.CompleteHydration(history);

    foreach (var pending in r.Channel.TakePendingReplays())
    {
        if (!r.Channel.IsMemberWithSeq(pending.UserId, pending.Seq)) { continue; }   // token recheck
        var backlog = r.Channel.ComputeBacklogFor(pending.LastId);                    // fresh post-hydration snapshot
        foreach (var chatMessage in backlog)
        {
            var newMessage = chatMessage.Clone(preserveTimestamp: true);
            newMessage.Recepient = pending.UserId;
            newMessage.IsOffline = false;
            newMessage.ProcessingSource = MessageProcessingSource.ChannelJoin;
            ProcessMessageSync(newMessage);
        }
    }
}
```

(The warm-join replay block from Task 5 stays for `BacklogSnapshot != null`.)

- [ ] **Step 5:** tests (`ChannelHydrationTest.cs`): single-flight (`TryBeginHydration` true once); `CompleteHydration` merges + dedups (pre-seed a live message with the same Id as a history message - one copy survives); pending replays flushed with recheck (pending for a user who left -> skipped); un-hydrated join defers (BacklogSnapshot null, pending recorded); non-long-living channel creates hydrated. Use channel ids like `"club777"` (matches `IsLongLivingChannelName`) and plain Guids for the non-long-living case.
- [ ] **Step 6:** CRLF+BOM; user builds; `dotnet test --no-build --filter "FullyQualifiedName~ChannelHydrationTest|FullyQualifiedName~Membership|FullyQualifiedName~ChatChannel|FullyQualifiedName~MembershipInlineLaneTest" ...` Expected: PASS.
- [ ] **Step 7: Commit (Tasks 5+6 together)** - message:

```
FP-33074: [Chat] Apply membership ops inline on the FIFO thread; pooled side-effects on atomic snapshots
* Join/Leave no longer race on the ThreadPool: the participant mutation happens on the IncomingQueue thread in arrival order (root cause #1), only backlog replay / ChannelPopulation fan-out stay pooled
+ `ChannelMemoryCache.ApplyMembershipOp()` - atomic get/create+mutate under channelsLock -> channelOpLock (no removal race); `MembershipOpResult` snapshot (participants, count, backlog, first message, member seq)
* Backlog replay rechecks the membership token before delivering - a superseding Leave cancels the replay
* ChannelPopulation recipients and count now come from the same locked snapshot
+ Cold-channel hydration state machine: channels created by the inline lane start un-hydrated, a single-flight pooled task loads history off the FIFO thread and flushes deferred replays with a fresh post-hydration snapshot and membership recheck
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 7: membership-driven channel lifetime (flag) + atomic removal + TEMP revert #2

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMemoryCache.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/ChatApplication.cs` + `ChatServerSettings.settings`/`.Designer.cs`
- Test: `Photon/src-server/LoadBalancing.Tests/ChannelLifetimeTest.cs` (new)

**Interfaces:**
- Produces: `ChannelMemoryCache.MembershipDrivenLifetime` (public static bool, default false); `TryRemoveUnusedChannels` honoring the flag; internal `ChatChannel.OpLock` for the atomic empty-check.

- [ ] **Step 1:** verify `ChannelsReleaseTimeout` is the pristine `10` in the NPN tree (it is - the TEMP repro edit lived only in the MFT working copy; nothing to change here).
- [ ] **Step 2:** expose the op lock internally on `ChatChannel`: `internal object OpLock => channelOpLock;`
- [ ] **Step 3:** sweep with the flag (inside the existing `TryRemoveUnusedChannels(DateTime now)` loop):

```csharp
foreach (var i in channelsCache.ToArray())
{
    if (i.Value.Persistent) continue;

    if (MembershipDrivenLifetime)
    {
        // A channel lives exactly as long as it has members - an occupied channel is
        // never reclaimed (an idle-timer eviction would silently unsubscribe its members).
        // Atomic empty-check under the channel op lock (lock order: channelsLock -> channelOpLock)
        // so an inline join cannot race the removal into an orphan channel.
        lock (i.Value.OpLock)
        {
            if (i.Value.ParticipantsCount == 0)
                channelsCache.Remove(i.Key);
        }
    }
    else if (now > (i.Value.AbsoluteExpireDate ?? i.Value.ExpireDate))
    {
        MiniLog.ChannelEvicted(i.Key, i.Value.Participants, i.Value.MessagesCount);  // legacy path tripwire stays
        channelsCache.Remove(i.Key);
    }
}
```

(`ParticipantsCount` re-locks the same lock - C# locks are reentrant; or read `i.Value.Membership.Count` directly since we hold the op lock. Use the latter: `if (i.Value.Membership.Count == 0)`.)

- [ ] **Step 4:** setting `MembershipDrivenChannelLifetime` (bool, `False`) in settings + Designer; push in `ChatApplication` startup: `ChannelMemoryCache.MembershipDrivenLifetime = ChatServerSettings.Default.MembershipDrivenChannelLifetime;`
- [ ] **Step 5:** tests (`ChannelLifetimeTest.cs`; drive time via the `TryRemoveUnusedChannels(DateTime now)` overload with far-future `now`): flag ON - occupied non-persistent channel survives any idle time; empty one is removed; persistent always survives. Flag OFF - legacy timer still evicts (existing behavior; keeps stage-1 deploy honest). Restore the static flag in `finally`.
- [ ] **Step 6:** CRLF+BOM; user builds; `dotnet test --no-build --filter "FullyQualifiedName~ChannelLifetimeTest" ...` + full chat filter re-run. Expected: PASS.
- [ ] **Step 7: Commit** - message:

```
FP-33074: [Chat] Membership-driven channel lifetime behind a setting (root cause #2)
+ `MembershipDrivenChannelLifetime` setting: when on, a non-persistent channel is removed only when its membership is empty - the blind 30-minute inactivity eviction that silently dropped joined members is gone; when off, legacy timer behavior is unchanged
* Channel removal is atomic vs the inline membership lane (channelsLock -> channelOpLock), closing the remove-vs-join orphan race
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 8: Pillar 3 - presence purge on node disconnect + membership reconcile

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/PlayerCache2.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/GameServer/IncomingGameServerPeer.cs` (`RemoveGameServerPeerFromChatServer`)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMemoryCache.cs` (reconcile)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Processing/ChatProcessor.cs` (sweep wiring) + settings (`MembershipReconcileGraceSeconds`, int, `60`)
- Test: `Photon/src-server/LoadBalancing.Tests/PresenceReconcileTest.cs` (new)

**Interfaces:**
- Produces: `PlayerCache2.OnGameServerDisconnected(IncomingGameServerPeer peer)`; `ChannelMemoryCache.ReconcileMembership(PlayerCache2 presence, TimeSpan grace, DateTime now)`.

- [ ] **Step 1:** presence purge - **by peer object reference**, not ServerId (a replacement peer may carry the same ServerId):

```csharp
// A hard node crash sends no final RemovedUsers - purge that node's players
// so presence (and everything reconciled against it) cannot leak.
public void OnGameServerDisconnected(GameServer.IncomingGameServerPeer peer)
{
    lock (cacheLock)
    {
        var stale = cache.Where(p => ReferenceEquals(p.Value.Game.GameServer, peer)).Select(p => p.Key).ToList();
        foreach (var playerId in stale)
        {
            cache.Remove(playerId);
            MiniLog.RemovePlayer(playerId);
        }
        if (stale.Count > 0)
            Log.InfoFormat("Purged {0} player(s) of disconnected game server peer (conId={1})", stale.Count, peer.ConnectionId);
    }
}
```

`GameState` must expose the peer: it already has `public IncomingGameServerPeer GameServer` (used by `ChatProcessor.SendMessage`) - verify the property name at implementation time and adjust.

Wire in `IncomingGameServerPeer.RemoveGameServerPeerFromChatServer`:

```csharp
if (ServerId.HasValue)
{
    application.GameServers.OnDisconnect(this);
    application.OnlinePlayers.OnGameServerDisconnected(this);
}
```

- [ ] **Step 2:** reconcile in `ChannelMemoryCache`:

```csharp
// Safety net for lost Leaves (crash paths): drop members no longer online anywhere.
// LookupPlayer at prune time; the joinedAt grace covers a chat join legitimately
// arriving before its presence update.
public void ReconcileMembership(PlayerCache2 presence, TimeSpan grace, DateTime now)
{
    if (!MembershipDrivenLifetime) return;

    int dropped = 0, skippedYoung = 0;
    lock (channelsLock)
    {
        foreach (var i in channelsCache.ToArray())
        {
            if (i.Value.Persistent) continue;
            lock (i.Value.OpLock)
            {
                foreach (var entry in i.Value.Membership.SnapshotEntries())
                {
                    if (now.Subtract(entry.Value.JoinedAt) < grace) { skippedYoung++; continue; }
                    if (presence.LookupPlayer(entry.Key, out _)) continue;
                    if (i.Value.Membership.RemoveExact(entry.Key, entry.Value.Seq))
                        dropped++;
                }
                if (i.Value.Membership.Count == 0)
                    channelsCache.Remove(i.Key);
            }
        }
    }
    if (dropped > 0 || skippedYoung > 0)
        Log.InfoFormat("Membership reconcile: dropped={0}, skippedYoung={1}", dropped, skippedYoung);
}
```

Lock-order note for the implementer: `PlayerCache2.LookupPlayer` takes `cacheLock` while we hold `channelsLock`+`OpLock` - `PlayerCache2` never takes channel locks (verified: it only touches its own dictionary), so the order is acyclic.

- [ ] **Step 3:** wire into the existing sweep cadence in `ChatProcessor.ThreadFunction`, right after `Channels.TryRemoveUnusedChannels();`:

```csharp
Channels.ReconcileMembership(PlayersCache, TimeSpan.FromSeconds(ChatServerSettings.Default.MembershipReconcileGraceSeconds), DT.Helper.UtcNow);
```

- [ ] **Step 4:** tests: purge removes exactly the disconnected peer's players (two `PlayerState`s on different peer objects; purge one peer; the other player survives - construct `IncomingGameServerPeer` is heavy, so make `OnGameServerDisconnected` take the peer and match `ReferenceEquals` on `GameState.GameServer`; in tests build `GameState` with a null-init peer? If `IncomingGameServerPeer` cannot be constructed in tests, extract the match into `internal static bool BelongsTo(PlayerState s, object peer) => ReferenceEquals(s.Game.GameServer, peer);` and unit-test `ReconcileMembership` instead with a real `PlayerCache2` filled via `OnJoined(users, new GameState("room", null))`). Reconcile tests: absent+old -> dropped; absent+young -> kept (grace); present+old -> kept; emptied channel removed; flag OFF -> no-op.
- [ ] **Step 5:** CRLF+BOM; user builds; `dotnet test --no-build --filter "FullyQualifiedName~PresenceReconcileTest" ...` + full chat filter. Expected: PASS.
- [ ] **Step 6: Commit** - message:

```
FP-33074: [Chat] Presence purge on node disconnect + membership reconcile against presence
* `PlayerCache2` now purges a disconnected game node's players by peer reference - a hard node crash no longer leaks presence (pre-existing leak, would defeat the reconcile)
+ `ReconcileMembership()`: periodic sweep drops channel members absent from presence (prune-time lookup, joinedAt grace window, seq-exact removal) and removes emptied channels
+ `MembershipReconcileGraceSeconds` setting
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 9: Pillar 4 - membership-age canary

**Files:**
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Channeling/ChannelMemoryCache.cs`
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/Processing/ChatProcessor.cs` (hourly cadence) + settings (`MembershipAgeCanaryHours`, int, `24`)
- Modify: `Photon/src-server/Loadbalancing/LoadBalancing/ChatServer/MiniLog.cs` (AGE logger)
- Test: `Photon/src-server/LoadBalancing.Tests/MembershipAgeCanaryTest.cs` (new)

**Interfaces:**
- Produces: `ChannelMemoryCache.CollectMembershipAges(PlayerCache2, TimeSpan threshold, DateTime now) -> MembershipAgeReport` (`internal class MembershipAgeReport { public int LongResident; public int LongResidentOffline; public List<(string Channel, int Count)> TopChannels; }`); `MiniLog.MembershipAge(report)`.

- [ ] **Step 1:** collector (read-only walk, same locking as reconcile) counting entries with `now - JoinedAt > threshold`, split by presence (`LookupPlayer`), top-5 channels by long-resident count. `MiniLog` AGE logger:

```csharp
private static readonly ILogger AgeLog = LogManager.GetLogger("AGE");

public static void MembershipAge(int longResident, int longResidentOffline, string topChannels)
{
    AgeLog.Info($"Members resident > threshold: {longResident} ({longResidentOffline} of them offline = leak suspects); top: {topChannels}");
}
```

- [ ] **Step 2:** hourly cadence in `ThreadFunction` (own `nextAgeLogTime`, `AddHours(1)`), threshold from `ChatServerSettings.Default.MembershipAgeCanaryHours`. Runs regardless of flags (the canary is telemetry).
- [ ] **Step 3:** tests: entries older/younger than threshold counted correctly; offline split (absent from a `PlayerCache2` fixture); top-channel ordering.
- [ ] **Step 4:** CRLF+BOM; user builds; run new filter + FULL chat suite: `dotnet test --no-build --filter "FullyQualifiedName~Chat|FullyQualifiedName~Membership|FullyQualifiedName~Channel|FullyQualifiedName~PresenceReconcile" ...` Expected: PASS.
- [ ] **Step 5: Commit** - message:

```
FP-33074: [Chat] Membership-age canary
+ Hourly AGE log: count of members continuously resident past the threshold (default 24h), split by presence (offline long-residents = leak suspects), top channels - regression tripwire for the membership fix
+ `MembershipAgeCanaryHours` setting
(bug: [Chat] messages disappear after awhile fishing)
https://fishingplanet.atlassian.net/browse/FP-33074
```

---

### Task 10: local end-to-end verification + KB/journal wrap-up

**Files:**
- Modify: `D:\kb\fishing-planet\tasks\FP-33074--chat-messages-disappear\journal.md` (milestone), `D:\kb\fishing-planet\server\modules\chat-server\log.md` (+implementation entry), module `backlog.md` (tick items)

- [ ] **Step 1:** with the user - local deploy, flags ON (`MembershipFenceEnforce=True`, `MembershipDrivenChannelLifetime=True` in the local config), debug user in `DebugUsers.lst`. Re-run both historical repros:
  - **Eviction repro (mechanism #2):** join club chat, send one message, idle past 30+ min (or temporarily shrink the timeout in local config only - NOT in code) -> messages must keep delivering (no EVICT of an occupied channel, self-echo `T` present).
  - **Rapid leave+join repro (mechanism #1):** spam the rapid leave+join debug trigger while sending messages -> membership must survive every cycle (`FENCE` lines show `IGNORED` verdicts on stale ops; self-echo `T` never disappears).
- [ ] **Step 2:** verify canary + reconcile logs appear (`AGE`, "Membership reconcile:") and shadow logs are quiet on healthy flow.
- [ ] **Step 3:** journal milestone (append-only, bottom); module `log.md` entry: implementation landed, fence semantics live; tick the fix items in module `backlog.md`.
- [ ] **Step 4:** hand off to the user: single delivery to prod; post-release activation via config (observe FENCE shadow -> flip enforce -> flip lifetime, window at the operator's discretion); post-release telemetry check per the task backlog "Post-release" item (reconcile young-skips, AGE canary, FENCE volume) - candidate for waiting-for-release on the JIRA task. JIRA comment about the fix drafted separately (jira-post-preview applies).

---

## Self-Review (done at plan time)

- **Spec coverage:** P1 fence (T1/T2/T4), inline+split-safety incl. token recheck, atomic snapshot, lock order, hydration (T5/T6), P2 lifetime + Expire retirement + TEMP reverts (T4/T7), P3 purge+reconcile+grace (T8), P4 canary (T9), rollout stages via two flags (T4/T7 defaults OFF = shadow), shadow telemetry (FENCE logs, T2/T4), identity-less rejection + metric-log (T2), per-user channel cap - **deliberately deferred**: not implemented in this pass; noted in module backlog as hardening (spec lists it as hardening, not a root-cause fix). Naming guard honored: `ChatRequests.ChannelExpiration` untouched (T5 still emits it).
- **Type consistency:** `MembershipToken`/`MemberEntry`/`LeaveVerdict`/`ChannelMembership` (T1) consumed by T2 (`GetMembershipToken`), T4 (`ApplyJoin/ApplyLeave`), T5 (`MembershipOpResult.MemberSeq`, `IsMemberWithSeq`), T6 (`RemoveExact`... T6 uses pending tuples), T8 (`SnapshotEntries`, `RemoveExact`). `MembershipDrivenLifetime` static (T7) guards reconcile (T8).
- **Placeholders:** test sketches in T1/T4/T5/T8/T9 name arrange/act/assert precisely and must be expanded literally at implementation - acceptable plan granularity; no TBD/TODO items remain.
