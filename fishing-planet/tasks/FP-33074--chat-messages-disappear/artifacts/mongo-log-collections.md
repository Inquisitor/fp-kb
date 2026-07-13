---
jira: FP-33074
title: 'Mongo log collections - inventory + forensic facts'
type: artifact
note: promotion candidate to a proper KB reference (KB currently lacks a full description of Mongo log collections)
---

# Mongo log collections (per-user game logs)

DB: `main2` on PROD (`main` exists but is empty on prod), `main` on local-dev.
Canonical channel list is in code: `Dal/Dal.Log/Logs/LogCollection.cs`. Collection
name = `ToCollectionName(channel)` = `"<channel>Log"` (`LogBase.cs:118`).

## Channel -> collection map (from LogCollection.cs)

`chat->chatLog, trade->tradeLog, fishing->fishingLog, achievement->achievementLog,
travel->travelLog, friends->friendsLog, tournament->tournamentLog, club->clubLog,
inventory->inventoryLog, security->securityLog, cheat->cheatLog,
Telemetry->TelemetryLog, license->licenseLog, mission->missionLog, sys->sysLog,
ban->banLog, push->pushLog, league->leagueLog, exp->expLog, cd->cdLog (ClientDebug),
ad->adLog, fortune->fortuneLog, together->togetherLog, leaderboard->leaderboardLog,
conversion->conversionLog`

## Prod `main2` inventory (XB, verified 2026-06-25)

- **Uniform `LogBase` schema** `{_id, UserId, Message, RequestId, Timestamp}`:
  `sysLog, travelLog, securityLog, friendsLog, inventoryLog, achievementLog,
  licenseLog, missionLog, pushLog, leagueLog, expLog, adLog, fortuneLog,
  leaderboardLog, conversionLog, tradeLog`
- **Special schema:** `chatLog, clubLog, tournamentLog, togetherLog, cheatLog,
  banLog, cdLog, adminActionLog`
- **Client diagnostics (`MongoDiagProvider`):** `diagErrLog, diagFpsLog, diagIpLog,
  diagSysInfoLog`
- **Other:** `gstmtLog, sstmtLog` (gold/silver statements), `oc` (online cash),
  `abuseReport, abuseAutoReport`
- **Absent:** no `TelemetryLog` here (Telemetry channel is written elsewhere).

## RequestId semantics (verified)

`RequestId` on a log row is the **client-assigned per-operation id**: the client
sends it as `ParameterCode.RequestId` (131) on each op; the server stores it
(`GameClientPeer.ReceiveRequest` -> `RequestContext.RequestId`, `GameClientPeerExtensions.cs:128-139`)
and `LogBase.Log` writes it into every row (`RequestId = RequestContext.RequestId`).
- Use it to **order events within a single connection** and to **correlate all log
  rows produced by one operation across collections**.
- It **resets on reconnect** (new connection, client counter restarts) -> only
  monotonic within one session; combine with `Timestamp` across sessions.

## DebugUsersCache (how to enable chat-server MiniLog for a user)

`Photon/.../Common/DebugUsersCache.cs`: reads a plain text file **`DebugUsers.lst`**
located at `..\..\DebugUsers.lst` relative to each Photon app's bin dir
(`DebugUsersFileName`). Whitespace/newline-separated **lowercase** user ids;
matched case-insensitively. **Hot-reloaded every 10s** (no restart, no DB).
Each Photon application (Game/Chat/Club/Master) reads its own copy; the chat-server
copy is what gates `MiniLog.Join/Leave/Sent` (which write to chat-server **log
files**, not Mongo). To capture the reorder live: add the player's (and a test
user's) lowercase id to the chat server's `DebugUsers.lst`, reproduce, read the
chat-server log files.

## For FP-33074 forensics

Pull for the player over the incident window: `sysLog` (join/leave/expire),
`travelLog` (what client action triggers each leave/join), `securityLog`
(reconnect/auth/relog), `togetherLog` (FT/co-op), `chatLog` (club6777). Optional
client-side: `cdLog`, `diagErrLog`. Merge by `Timestamp`; within a connection also
order/group by `RequestId`. Goal: millisecond reconstruction of why the client
issues the Leave+reJoin (and Pond->Globe double-Leave) and how tightly the ops
arrive (the race window).
