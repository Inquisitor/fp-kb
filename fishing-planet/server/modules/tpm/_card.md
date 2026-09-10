---
module: tpm
system: fishing
status: stub
---

# TPM (third-person mode relay)
> Other players' avatars: the client sends a binary frame about itself every 200 ms as a Photon event flagged unreliable, but over a TCP connection, so it arrives in order in practice; the server relays it to the room without reading the bytes. Cosmetic channel — nothing in gameplay depends on it. Known-wrong content model (first-person rod bend replayed on a third-person rig) and a rewrite epic TPMv3 exist. Explicitly OUT of the FP-45122 Fish Fight Protocol v2 scope, sequenced after it.

## Entry Points
- `Game.PublishEvent` (`GameServer/Game.cs`) — for `EventCode.CharacterEvent` filters recipients to peers that are neither paused nor TPM-disabled, then delegates to Lite's room broadcast; the payload is never deserialized on the server
- `GameClientPeer.TryToggleTPM` (`GameServer/GameClientPeer.cs`) — the only server-side lever: bad-ping detection (`DisableTpmPingThresholdMs`, `DisableTpmTriggerDelayMs`, `BadPingDetector`) flips `IsTpmDisabled`; every flip is logged via `SaveBadPingTpmToggle`
- Client side (per the client team's Fish Fight Protocol v2 spec, pin r57335, 2026-09-08 — NOT verified locally): `PlayerController` builds the frame → `CharacterInfo.ToHashtable` → `ThirdPersonData.SerializeToStream` (format version 36, own serializer); cadence `TPMDataCache.DATA_FRACTION_DELAY = 0.2`; receiver `TPMCharactersController.OnPlayerModelUpdate`; not sent in tournaments; a special frame while paused

## Key Facts
- Wire: `OpRaiseEvent(EventCode.CharacterEvent)` with `sendReliable = false`, one frame per message, Hashtable {event type, userId, byte[] frame}, ~55 bytes without lists and boat. The flag is nominal: the game connection is TCP on every platform except Xbox (WSS) — `StaticUserData.ServerConnectionProtocol`, port 4530 — and GameCarrier runs over QUIC/WSS/TCP, so frames are delivered in order; "unreliable" in the client team's documents describes the flag, not the behaviour (verified 2026-09-09). Frame: position, rotation, boat, shown fish and items, rods and rod pods, 22 animation parameters, timestamped actions
- Everything other players see is the sender's unverified statement; the server holds no avatar state, so no interest management (distance, rate, field detail) is possible today beyond the ping toggle
- Player position leaves the client three ways: the fight wire (`pP`/`pR` in Move/Walk), the mission position operation (see [missions backlog](../missions/backlog.md)), the TPM frame. Only the first two are read on the server
- Content-model defect (server lead's account of a conversation with the TPM implementer, ~spring 2026; UNVERIFIED in code): the frame carries first-person rod-bend data that the third-person rig cannot reproduce (fewer degrees of freedom) → rods bend the wrong way, the line leaves the tip sideways. The fix is a different content model, not a faster transport
- Scope decision 2026-09-08/09 (server lead): TPM is NOT part of FP-45122 v2 — not even "types only" in the v2 schema; the v2 wire does not touch it; the client side's option "A: leave as is" holds until TPMv3

## Deep Dives
- [TPMv3 design intent](tpmv3-design-intent.md) — server-owned avatar model, interest management by distance, presence-bit deltas; assessment of the 2025-10 TDD; sequencing after v2

## Dependencies
→ Lite room broadcast (`PublishEvent`), per-peer flags (`IsGamePaused`, `IsTpmDisabled`), analytics (`SaveBadPingTpmToggle`)
← [fish-fight](../fish-fight/_card.md) (the avatar-traffic bypass behind `IsRequestFiberEnabled`, its log 2026-08-02), [missions](../missions/_card.md) (position paths)

## Related Tasks
- TPMv3 (tickets of 2025-10-22, all To Do): client FP-40378, FP-40379, FP-40380, FP-40381; server FP-40383 (store and track TPM state), FP-40384 (distance-based sending), FP-40385 (RnD: more players per room)
- FP-39149 — the original ordering bug and its TDD (Verified); Confluence "TPM protocol optimization TDD" (page 5003771920) under "Third Person Mode (TPM)" (page 2392129537)
- FP-45122 — scope boundary: TPM excluded from Fish Fight Protocol v2; TPMv3 consumes v2's server-owned state and tooling

See also: [backlog](backlog.md) | [log](log.md)
