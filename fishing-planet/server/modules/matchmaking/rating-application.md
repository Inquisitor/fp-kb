---
module: matchmaking
---

# Competition rating — application and logging

Why the Mongo `tournamentLog` rating ledger is **not** a complete record of rating events, and
how to read a player's rating history without being misled by it. PCR
(`Profiles.CompetitionRating`) is the matchmaking bracket input, so anything that distorts it
distorts bucket assignment.

## SQL and the ledger answer different questions

Two independent paths write rating, and they disagree by design:

| Path | Entry point | Writes | Covers |
|---|---|---|---|
| Assessment | `TournamentEndAdapter` | `TournamentIndividualResults.Rating` | every participant at tournament end, including no-shows |
| Application | `GameClientPeer_Tournaments` rating block, via `TournamentsHelper.NewProfileRating` | `Profiles.CompetitionRating` + a `tournamentLog` line | only when the player is connected, and only when the value actually moves |

**SQL is authoritative for how much penalty was assessed. The ledger is authoritative for how the
rating actually moved.** A gap between them is expected, not corruption.

## The floor swallows penalties silently

`NewProfileRating` clamps the result at zero, and the ledger write is conditional on the rating
having changed. Together:

> A no-show penalty landing on a player already at PCR 0 moves nothing, and therefore produces
> **no ledger line at all**.

The negative-rating correction branch nearby does not catch it either — the clamp runs first, so
there is no fallback record. The player simply goes silent in the ledger until something lifts
the rating off the floor.

## The printed delta is the assessed penalty, not the applied one

A ledger line reports the raw assessed value but a clamped before/after pair, so near the floor
the two disagree: `added CompetitionRating -20 (1 -> 0)` means *assessed −20, applied −1*.
**Arithmetic over the delta figure overstates the drain near zero — read the before/after pair.**

## Reading a trajectory

- **Volume** (how many no-shows) → SQL. Never the ledger.
- **Shape** (bracket crossings, batched flushes, climb-then-flush arcs) → ledger.
- A sparse ledger for a player sitting near zero is a **logging artifact, not low activity**.
- Registrations that land while PCR is already 0 cost the player nothing and achieve nothing
  except holding the floor — in abuse analysis that is an intent signal, not noise.
- A gap between assessed penalties and ledger lines has **two** causes, which must not be
  conflated: floor absorption (above), and application still queued because the player has not
  reconnected — the latter is the familiar batched-flush pattern. Discriminator: whether the
  window contains any line ending at 0.

## Example (FP-43631 week-12, at time of writing)

A PS account driven to the floor: the ledger showed the arrival at 0 on 07-18, then nothing at
all across 07-19..07-21 while SQL recorded 21 registrations with penalties assessed over those
three days, then resumed the moment a played result lifted the rating off zero.

## Known defect

The conditional write silently drops real events. Logging unconditionally — emitting the line
even when the movement is zero — would keep the ledger a faithful audit trail and remove the
need for the SQL cross-check. Tracked in [backlog](backlog.md).
