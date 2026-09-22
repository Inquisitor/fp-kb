# Orphaned peers on GameCarrier nodes — what they are and why they persist

Opened while evaluating the Mobile pilot on 17 September 2026 and settled on PlayStation on 21 September, once
nodes with performance counters and direct machine access were available. The first reading of the evidence was
wrong; the correction and how it was reached are kept here deliberately, because the wrong reading pointed at
the wrong owner.

Tracing is off by default in production: a node writes `TracePeers-<App>.log` only while the flag file
`Flags/TracePeers` exists in the application directory. The same minute loop — `ProcessFlags()` in
`OutgoingMasterServerPeer.cs` — also writes `Flags/PeerCount` and `Flags/LoadLevel`, which is where the
distributor's per-node figures come from. So the number shown against a node in the distributor is the peer
count, orphans included, not a player count.

## What an orphaned peer is

A peer that has existed for over an hour and never recorded a single request: no authenticated user, no
operation, no ping. A client opened a TCP connection, sent nothing, and went away.

They are **open sockets in `Established` state**, not objects that outlived their connection. On node143 every
orphan in the trace was matched against `Get-NetTCPConnection` output taken on the machine itself, by remote
address and creation time:

| Orphan in trace (UTC) | Socket on 4531 (machine time, EDT) | Difference |
|---|---|---|
| 180.75.232.230, 17 Sep 13:52:32 | :49879 `Established`, 09:52:32 | 1 s |
| 79.177.145.235, 17 Sep 15:33:50 | :56074 and :56073 `Established`, 11:33:50 | 1 s |
| 90.129.115.137, 18 Sep 12:09:49 | :47384 `Established`, 08:09:49 | 0 s |
| 115.135.25.151, 19 Sep 12:53:22 | :17516 `Established`, 08:53:22 | 1 s |
| 31.0.0.39, 21 Sep 15:51:06 | :4292 `Established`, 11:51:07 | 0 s |

Every orphan in the snapshot found its socket. The trace writes UTC while the machines run EDT, which accounts
for the constant four hours and had earlier made two readings look like they disagreed.

## Why they persist

The counters name the cause directly. On both PlayStation nodes, sampled 21 September:

```
tcp.api.calls.connectionsettimer.total        0
tcp.network.server.connections.total     162533   (node143)
                                         185493   (node116)
tcp.network.server.connections.current      717 / 744
```

No timer was ever set on a connection, across every connection either node has accepted. The mechanism exists
in the GameCarrier API — the counter for it is there — and the TCP transport does not use it. Without an
application timeout and without TCP keepalive, a silent `Established` socket has nothing to close it: TCP
itself will not.

This is also why QUIC is clean while carrying more traffic. An idle timeout is part of the QUIC protocol and
msquic applies it regardless of the application. TCP leaves that duty to whoever accepts the connection.

## Rate, and the Photon control

Photon leaks the same way, far more slowly. Node13 — a PlayStation Photon Game node, listening since 4 August,
so 48 days without a restart — holds sockets older than a day created 5 September, 17 September and
20 September, and nothing else above the live traffic.

| | Photon node13 | GameCarrier node143 |
|---|---|---|
| Uptime at measurement | 48 days | 4.4 days |
| Sockets older than a day | 3 | 8 |
| Peers carried | 448 | 653 |
| Accumulation | about one per fortnight | about two per day |

Load differs by roughly half, the rate by a factor of tens, so load does not explain it. Photon evidently
closes such connections almost always; GameCarrier does not close them at all.

Against throughput the leak is small — ten stuck sockets against 162 533 connections accepted in four days,
0.006%. It matters on a node that runs for months: Nintendo, never restarted, reached 121.

## What the traces cover

| Trace | Window | Snapshots | Orphans at end |
|---|---|---|---|
| PlayStation node143, Game | 20 Sep 15:19 – 21 Sep 19:44 UTC | 1705 | 10, of which 8 over a day |
| PlayStation node116, Game | 20 Sep 15:44 – 21 Sep 19:49 UTC | 1685 | 9, of which 6 over a day |
| Mobile pilot node73, Game | 14 Sep 22:37 – 16 Sep 20:22 | 2745 | 28, of which 20 over a day |
| Nintendo, Game | 14 Sep 22:33 – 17 Sep 06:44 | 3371 | 121, oldest 220 days |
| Nintendo, Master | 14 Sep 22:33 – 17 Sep 06:44 | 3371 | none |
| Xbox, Game | 14 Sep 22:19 – 17 Sep 06:50 | 3391 | none; a few appeared and closed within hours |

Two shapes recur. A batch appears when the node is introduced — the oldest orphans on both PlayStation nodes
date from 17 September, the day they entered rotation, and on the Mobile pilot the twenty oldest all date from
9–10 September and did not grow by one over five days of observation. After that a slow trickle adds roughly
one per day per node.

Only the Game application over TCP is affected. Nintendo's Master node runs the same transport and stays clean;
the Game application over QUIC and WSS stays clean, including on Mobile where QUIC carries the bulk of the load
(117 to 466 peers against a flat 22 to 30 on TCP).

## The reading that was wrong

The first pass compared the trace against `Tcp.Network.Client.Connections.Current`, which read 3 while the
trace showed 26 peers, and concluded the sockets were already closed and the objects had outlived them.

`Client` counts connections the node opens itself — its S2S links — and holds steady at 3 on every node
measured since. Accepted connections are `Server`, and that counter equals the peer count exactly: 717 against
717 `Established` sockets on node143, 744 against 744 on node116. Being equal, it also cannot serve as
independent evidence about sockets; only a reading taken outside the process can, which is what settled this.

The rejected explanation from that pass — that GameCarrier configs lack the `InactivityTimeout` carried by the
Photon TCP listener — was rejected for a reason that no longer holds, and is close to what the counters now
show. It deserves a second look when the question goes to GC dev.

## Bearing on the migration

Not a blocker, and not introduced by the migration. At about one per day per node it costs nothing a farm will
notice, and any deployment restart clears it. Mobile, PlayStation and Steam all keep a client TCP port for
clients on the old protocol, so all three will accumulate at this rate; Xbox is spared only because
certification left it without client TCP.

## For GC dev

The TCP transport never sets a connection timer — `tcp.api.calls.connectionsettimer.total` is zero across
hundreds of thousands of accepted connections. A connection that sends nothing after being established stays
`Established` indefinitely; on Nintendo such sockets reach 220 days. QUIC is unaffected because msquic applies
its own idle timeout. Either an application-level timeout on unauthenticated connections or TCP keepalive on
the socket would close them. Photon, on the same farm, keeps three such sockets over 48 days against
GameCarrier's eight over four.

Worth raising in the same conversation: the server has failed to stop cleanly before, with lws named as the
blocker. Both are the same question of when a GameCarrier transport releases a connection.
