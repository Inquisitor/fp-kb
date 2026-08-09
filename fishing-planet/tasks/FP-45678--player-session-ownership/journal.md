---
jira: https://fishingplanet.atlassian.net/browse/FP-45678
title: "Player Session Ownership (Server)"
status: planning
executor: Stanislav Samoilov
created: 2026-08-10
type: epic
---
# FP-45678: Player Session Ownership (Server)

## Status
Epic filed and scoped; no implementation task exists yet. Reconnaissance of the peer, the
disconnect path and the client login flow is done and recorded in
[peer-ownership-audit](artifacts/peer-ownership-audit.md). Next step is turning D1 into a task —
the epic currently holds only the three defects found while scoping.

## Summary
`GameClientPeer` is created on socket connect, before authentication, so its lifetime equals the
lifetime of a TCP connection rather than of a player session. Everything loaded for the player hangs
off it and dies with the socket. The profile itself is not lost — it is written to the database on
both the graceful and the abnormal disconnect path — but it is discarded and read back from that
same database on the next connect, once on Master and once on Game.

The epic moves loaded state onto a session entity that outlives the connection, leaving the peer as
a transport endpoint, so a returning player attaches to live state instead of paying for a full
reload. The win in the baseline is entirely server-side: the client keeps downloading the profile as
it does today.

## Design decisions
- **Reattach is transparent to the client.** The client has no reconnect logic — any dropped
  connection tears everything down and restarts the full login flow — so the win must come from the
  server recognising a returning user, not from the client asking to resume. A seamless client-side
  reconnect is a separate client task and is out of scope.
- **Duplicate login becomes a handoff.** Today both authenticators kill the previous peer before the
  new one finishes authenticating, and the outgoing peer's save is skipped if its session was already
  invalidated. The session model replaces the kill with a transfer of ownership, which is why
  FP-45679 is filed here rather than patched in place.
- **Routing must address the Photon application instance, not the host.** A single Photon process
  runs several `GameApplication` instances (`GameServer1`, `GameServer2` in the deploy config) that
  share no state, so "same machine" does not imply "same session store".
- **Profile checksums are out of scope.** Considered and dropped: the client re-downloads the
  profile on every connect in the baseline, so a "download only if changed" mechanism is a separate
  effort with its own protocol work. The design only keeps the door open by versioning session state.

## Scope boundaries
- FP-38395 removes the Master-side profile load — the saving on every first login; this epic removes
  the Game-side reload on reconnect. They compose rather than overlap.
- FP-44798 decides where the session record physically lives (Mongo `oc` out of the critical path);
  this epic depends on that decision instead of making its own.
- Live fight state (`MultiRodGameProcessor` / `GameProcessor`) belongs to FP-45122.

## Plan / next steps
Epic plan is D1 as-is documentation → D2 ownership analysis → D3 session design → D4 transport
facade → D5 ownership split → D6 reattach. See the JIRA epic for the authoritative wording and
[backlog](backlog.md) for what to file next.

## Milestones
- 2026-08-10: Epic filed as FP-45678 (Epic, Scrum Team Tech Debt, component Server), linked
  `Relates` to FP-38395, FP-44798, FP-45122 and FP-38709. Reconnaissance run across the peer's state
  ownership, the disconnect/reconnect path and the client login flow; results in
  [peer-ownership-audit](artifacts/peer-ownership-audit.md). Three defects found while scoping were
  filed as children: FP-45679 (profile save skipped on the duplicate-login race), FP-45680 (profile
  event subscriptions never unsubscribed), FP-45681 (dead MultiRods partial). Client reconnaissance
  posted as a comment on FP-38395, since it establishes that the client has no structural dependency
  on receiving the profile from Master. Profile-checksum idea raised and deliberately dropped from
  scope.
