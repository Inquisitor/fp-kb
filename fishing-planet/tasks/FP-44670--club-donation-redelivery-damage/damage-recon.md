# FP-44478 — Damage recon (club donation re-delivery)

Post-review forensics: quantify how many extra items the re-delivery bug handed out on prod. Runnable queries: [`damage-recon-queries.js`](damage-recon-queries.js).

## Signal in the data

Each successful delivery in `__ReceiveBait` / `__ReceiveClubToken` writes one `clubLog` line:

- bait — `Received bait #{itemId} count {count} for request '{requestId}' from {name} '{guid}'`
- token — `Received ClubToken count {count} for request '{requestId}' from {name} '{guid}'`
- every accept also writes `Accepted event Type={Type}, InstanceId='{guid}', ...`

`requestId` is the donation's `InstanceId` (a GUID, unique per donation). A re-delivery re-emits a **byte-identical** line (same itemId/count/requestId/donor) — only `Timestamp` differs. Two different legit donations can never collide (different GUID → different text). So:

- duplicate donation = identical `(UserId, Message)` with occurrence count `n > 1`
- surplus deliveries for that donation = `n − 1`
- surplus items = `count × (n − 1)`

`clubLog` lives in the `main` Mongo DB; document fields `UserId` (lowercase), `ClubId`, `Message`, `Timestamp` (UTC).

## Blast radius

- **Bait + Club tokens** — auto re-delivered via the `___ReceiveClubEvent` switch on channel replay. Primary damage.
- **Buoys** — `BuoyResponse` is *not* in the auto-switch; re-delivery needs a manual re-accept (`AcceptBuoy`). Possible but marginal; surfaced by the Q4 type cross-check (`BuoyResponse`).

## Window

- **Theoretical start:** r10273 (2023-04-27, "Clubs: fix duplicated donates") — introduced `___ReceiveClubChannelExpiration` + `RemoveExpiredClubEvents`, i.e. the client-horizon purge path the bug rides. (Ironically the very change meant to stop duplicate donates.)
- **Practical start:** bounded by `clubLog` retention — historically pruned aggressively, so old delivery lines are already gone. Q1 reveals the real surviving span per platform. **All figures are a lower bound.**
- **End:** ongoing on prod until the fix (MFT r16215) ships on the Content release; bug is live now.

## Platform scope

F2P only, team order: Steam/EGS, PlayStation, Xbox, Mobile, Nintendo. Retail excluded (not patched, separate economy). One Mongo per platform.

## How to read the results

- **Q1 / Q1b** — retention span and scan size; run first to gauge timeout risk.
- **Q2** — headline: affected donations, total surplus deliveries, distinct affected users.
- **Q3** — per-donation export; parse `#itemId count N` offline to get surplus items per bait type and per-user lists for any remediation.
- **Q4** — independent cross-check by event Type (catches bait + token + buoy); `*Response` rows are the auto re-deliveries.

## Status

Queries validated locally (Mongo 4.4.13, `main.clubLog`) for syntax; local copy has no delivery lines, so numbers come from prod runs (executed manually — large data, timeout risk). Awaiting prod results to size the damage and decide remediation.
