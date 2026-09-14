# Fish Fight Protocol v2 — cost of the current wire encoding, measured

Input for the evaluation letter (due 2026-09-22). The frame letter `96be4ad` §2 calls the current encoding fat,
memory-hungry and allocating on every message; this note replaces the expectation with numbers.

## Method

- Test: `FightFishCodecCostTests.cs` (this folder), an MSTest run once in `LoadBalancing.Tests` of the server
  branch `NPN20260602` (WC r16497, SDK binaries from `lib/`), then removed from the SVN working copy — Fish Fight
  Protocol v2 work never lives in SVN. Run log: `2026-09-10-codec-cost-test-run.log`.
- Message: one `FightFish` in the full form — the sixteen catalogued fields plus the three keys every message
  carries (`sN`, `fC`, `iPt`), positions as the registered custom type `V` (`RawCustomValue`, twelve bytes).
  Today the client omits bool keys that are false, so the full form is the upper bound of the current wire.
- Encoding A: the protocol the game server speaks today — `Protocol.GpBinaryV162` from the Photon SDK,
  `SerializeOperationRequest` / `TryParseOperationRequest` with `AllowRawCustomValues = true`, exactly the path
  `GameActionAdapter` reads from (`(Hashtable)request.Parameters[185]`).
- Encoding B: the same content as a packed fixed-layout DTO — opcode, slot, cycle, one flag byte for the eight
  bools, six floats, reel speed, two positions — written into a caller-owned buffer and read back into a struct.
- Allocations: `AppDomain.MonitoringTotalAllocatedMemorySize` around 20 000 calls, divided by the call count.

## Result

| Encoding                    | Wire bytes | Serialize / write, B per message | Parse / read, B per message |
|-----------------------------|-----------:|---------------------------------:|----------------------------:|
| Photon GpBinaryV162 (today) |        204 |                            5 168 |                       5 729 |
| Packed DTO                  |         56 |                          385 (*) |                           0 |

(*) The 385 bytes come from `VectorSerializationHelper.Serialize(float, byte[], ref int)`, which allocates a
temporary array per float (twelve floats per message); a non-allocating float write brings the packed write to 0.
The packed layout carries no envelope; the v2 envelope adds a few tens of bytes to either encoding equally.

## Reading

- On the wire the current encoding is about 3.6 times the packed size for the same content: every value carries its
  two-letter key and a type marker, and the dictionary itself is framed.
- On the server every parsed fight message allocates about 5.7 KB (the Hashtable, boxed values, key strings, the
  raw custom values and their arrays). At the fight cadence of five messages per second that is roughly 29 KB/s of
  garbage per fighting slot from parsing alone, before responses and events are serialized (5.2 KB each). The
  client pays the mirror image on its side.
- The letter's claim holds: the encoding is fat and allocates on every message. What remains a design choice, not a
  measurement, is the replacement's layout; the packed figures above are a floor, not a proposal.

## Load model

Message rates from prod, three game nodes, 60 s windows after `stats reset` (`2026-09-10-prod-stats-peer-snapshots.txt`).
Fight loop = `Game.Move` + `Game.FightFish`, the stream Fish Fight Protocol v2 replaces. The other game actions in the
top twenty (`Game.Walk`, `Game.TravelByBoat`, `Game.UnHitch`, `Game.UpdateFeedings`) ride the same codec but are out of
scope; together they add about 0.45 message per online player per second.

| Node (online)          | Fight loop, msg/s | per online player | `Move` : `FightFish` | Third-person frames, msg/s | Mission position op, msg/s |
|------------------------|------------------:|------------------:|---------------------:|---------------------------:|---------------------------:|
| 25 (about 764)         |             3 156 |               4.1 |                5.6:1 |                      2 563 |                         80 |
| 2 (about 683)          |             3 388 |               5.0 |                8.2:1 |                      2 556 |                         71 |
| 86 (about 677)         |             2 817 |               4.2 |                5.8:1 |                      2 366 |                         53 |

The counts are consistent with about one stream per online player at the 200 ms cadence (4.4 messages per player
per second on average). The mission position operation is about 0.1 message per player per second; its retirement
is about cleanliness, not load. Third-person frames arrive at about 3.5 per player per second inbound; their
outbound cost is the room fan-out and belongs to TPMv3, not here.

| Scenario, 1000 online on a node                                | Fight msgs/s | Inbound wire, today's codec (*) | Server garbage, today's codec (parse + response) | Inbound wire, packed | Server garbage, packed |
|----------------------------------------------------------------|-------------:|--------------------------------:|-------------------------------------------------:|---------------------:|-----------------------:|
| Today's mix (4.4 msg/s per player)                              |        4 400 |                        0.9 MB/s |                                          48 MB/s |            0.25 MB/s |             about zero |
| Ceiling: five slots per player at 200 ms, everyone fishing      |       25 000 |           5.1 MB/s (41 Mbit/s) |                                         272 MB/s |             1.4 MB/s |             about zero |

(*) 204 bytes per message is the full-form `FightFish`; a `Move` carries fewer keys, so the inbound figures for today's
codec are upper bounds. Garbage per message = 5 729 B parse + 5 168 B response, the measured figures above. The ceiling
assumes pods send at the hands' cadence; in Fish Fight Protocol v2 the pod group's interval is a server-set variable,
so the ceiling is a policy choice, not a property of the protocol.

Side observation, not evidence: on nodes 25 and 86 `Game.Move` shows a handful of calls over half a second within the
minute (max 1.5 s); at 30–40 MB/s of garbage per node, collector pauses are one candidate, worth a look with GC
counters before the evaluation.

Relates: FP-45122 (encoding is the server side's layer, slated for replacement — frame letter `96be4ad` §2).
