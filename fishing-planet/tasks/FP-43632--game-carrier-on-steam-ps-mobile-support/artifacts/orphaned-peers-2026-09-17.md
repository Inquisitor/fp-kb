# Orphaned peer objects on GameCarrier nodes — trace comparison, September 2026

Taken while evaluating the Mobile pilot, then widened to Nintendo and Xbox for comparison. The verdict on the
pilot is in the task journal; this file holds the measurement and the defect it uncovered.

Tracing is off by default in production: a node writes `TracePeers-<App>.log` only while the flag file
`Flags/TracePeers` exists in the application directory, and the flag is checked once a minute. It was enabled
by hand on the Mobile pilot node and is permanently on for Nintendo and Xbox. The log does not grow without
bound: the three traces below were taken whole, yet they span nearly the same two and a half days while
ranging from half a gigabyte to two — so something rotates them. Leaving the flag on is established practice
rather than an oversight; the mechanism has not been identified.

## Method

One snapshot per minute, each listing every peer with its protocol, transport, age and recent activity. A peer
was counted as orphaned when it had existed for over an hour and had never recorded a single request. Every
peer line in every trace parsed without exception.

| Trace | Window | Snapshots |
|-------|--------|-----------|
| Mobile pilot, Game node | 14 Sep 22:37 – 16 Sep 20:22 | 2745 |
| Nintendo, Game node | 14 Sep 22:33 – 17 Sep 06:44 | 3371 |
| Nintendo, Master node | 14 Sep 22:33 – 17 Sep 06:44 | 3371 |
| Xbox, Game node | 14 Sep 22:19 – 17 Sep 06:50 | 3391 |

## Result

Exactly one combination accumulates orphans: **the Game application over TCP**. The same TCP on a Master node
is clean, and the same Game application over WSS and QUIC is clean.

| Application + transport | Platform | Orphans |
|---|---|---|
| Game + **TCP** | Mobile, Nintendo | accumulate and never clear |
| Game + WSS | Xbox | appear, then close within hours |
| Game + QUIC | Mobile, Nintendo, Xbox | none observed |
| Master + TCP | Nintendo | none observed |

Detail per trace:

- **Mobile pilot** — 24 orphans in the final snapshot, 20 of them present from the first; four appeared during
  16 September, roughly one per three hours. None closed. The oldest dated back to node startup. Meanwhile no
  GameCarrier connection was ever orphaned, under the full load of the platform: the busiest snapshot held 526
  concurrent connections, about 490 of them on GameCarrier.
- **Nintendo Game** — 121 orphans, the oldest 5289 hours, that is 220 days: it has survived since the node was
  started and shows the accumulation has no ceiling. `Photon + TCP` sits flat at 188–191 regardless of time of
  day, while live QUIC traffic swings between 72 and 215 over the daily cycle — the TCP figure is mostly
  sediment, not players.
- **Nintendo Master** — no orphans at all. Long-lived connections exist there, up to 210 days, but they are
  alive: authenticated, with pings seconds old. Consoles holding a session for months is normal behaviour.
- **Xbox Game** — no orphans in the final snapshot. Seven appeared across the whole window, on both
  `Photon + WSS` and `GameCarrier + WSS`, and each closed after one to three hours. Xbox binds no client TCP at
  all, because MS certification forbids the plaintext wire protocol.

## The sockets are already gone

On the pilot node the GameCarrier counter `Tcp.Network.Client.Connections.Current` read 3, steady — minimum,
maximum and average alike — while the trace showed 26 client peers on `Photon + TCP`. The transport carries
PHOTON over TCP only, so the two describe the same set and disagree by an order of magnitude.

So the orphans are not open sockets. The transport closed them; the peer objects stayed behind in the
application. This also fits what the orphans look like: no authenticated user and no request ever recorded —
connections that dropped before authentication.

Caveat: the counter reading and the trace are from different moments, a few hours apart. The orphan set is
stable over days, so the conclusion holds, but a simultaneous reading has not been taken.

## What was ruled out

An earlier explanation — that the GameCarrier configs lack the `InactivityTimeout` that the Photon TCP
listener carries — does not survive the data. The counter shows there is no idle socket left to time out, and
the Nintendo Master node runs the same timeout-free config over the same transport without accumulating
anything.

## Open

Why this one combination. The question belongs to GC dev, and the matrix above is the evidence to put in front
of them. A related symptom worth raising together: the server has failed to stop cleanly before, with lws named
as the blocker — both look like the same question of when a GameCarrier transport actually releases a
connection.

Counters exist only on the Mobile pilot node; Nintendo and Xbox get them with this release. Once Nintendo has
them, comparing its counter against the 189 `Photon + TCP` peers in its trace will either confirm the
sockets-versus-objects reading at a hundredfold gap, or refute it.

## Bearing on the migration

This is not a regression introduced by the migration: it has been running on Nintendo for 220 days and was
simply never measured. It clears on any node restart, so a deployment resets it.

Mobile, PlayStation and Steam keep a client TCP port after migrating, for clients still on the old protocol, so
they will accumulate the way Nintendo does — on the pilot's rate, on the order of a hundred objects over a
month between deployments. Xbox is spared only because certification left it without client TCP.
