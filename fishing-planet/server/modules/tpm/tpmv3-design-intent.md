---
module: tpm
title: 'TPM - TPMv3 design intent and assessment of the 2025-10 TDD'
status: draft
---

# TPMv3 — design intent and assessment of the 2025-10 TDD

Why this doc exists: the intent for the third-person rewrite lives in the server lead's head, a half-finished spreadsheet and seven To Do tickets; the only written design (the client-side TDD of 2025-10) optimizes the wrong thing. This captures the intent so that the FP-45122 scope boundary ("TPM after v2, not inside it") has a reference, and so that the rewrite starts from the model, not from the encoding.

> **Draft.** Sources: the server lead (in conversation, 2026-09-08/09; his illustration for the TPM implementer, 2025-10); JIRA FP-39149 and the TPMv3 tickets; Confluence "TPM protocol optimization TDD" (page 5003771920, v11 of 2025-10-22); server code NPN20260602 for the relay path. Client internals are cited from the client team's Fish Fight Protocol v2 spec (2026-09-08) and NOT verified locally.

## What is wrong today (the model, not the transport)
- The frame transfers the first-person rod simulation (rod points, transforms, line points) and the third-person rig replays it literally. The rig has fewer degrees of freedom (rod towards/away from the body only, no tilt to either shoulder), so when a first-person player turns sideways to a pulling fish, the third-person rod bends the wrong way and the line leaves the tip sideways. The implementer's stated reason: there was no task to work it out. The natural model runs the other way: send the tackle position and the rod transform, let the receiving client bend the rod towards the tackle with any smooth curve joining the two vectors
- Everything is broadcast to everyone in the room at 5 Hz regardless of distance. Ponds reach 20 km across; a player in the far corner still receives another player's rod-bend updates at full rate. The only lever today is `GameClientPeer.TryToggleTPM`, which stops delivery to a peer on bad ping

## Intent (server lead)
1. **Server-owned avatar model.** The client sends what is necessary and sufficient; the server keeps the model per player and broadcasts to interested recipients. This is the same architectural move as Fish Fight Protocol v2's server-owned fight state (ticket FP-40383)
2. **Interest management by distance** (FP-40384). Near: full rate, 5 Hz. Around 100 m: about 1 Hz, coarse rotation. Beyond about 200 m: coordinates every ~10 s and a compass heading for the map markers, no tackle updates at all. Head and rod detail are invisible at that range anyway
3. **Deltas with presence bits.** Send only changed fields. A periodic full sync only if the channel stays unreliable; with reliable state sync the periodic snapshot is redundant, and reliable sync is itself the path to sending less
4. **Encoding sketch** (server lead's spreadsheet, mirrored in the TDD's packet table): header byte = category + slot (rods 101–107, fish 111–117, rod pods 121–125, boat 130, …), then change masks (3–4 bytes), then the data of the flagged fields. Encoding is the transport layer's business; DTOs in, DTOs out — the same boundary as Fish Fight Protocol v2
5. **Allocation-free serialization** (flatbuffers as a candidate): the current serializer allocates heavily
6. **Sequencing.** After FP-45122 v2 lands its server-owned state, schema/codegen and transport layer; TPMv3 reuses them. Finishing TPM inside v2 or before it is "a shot in the foot" (server lead, 2026-09-08); cutting things out of the current TPM is fine

## Assessment of the TDD (Confluence 5003771920, v11)
Sound, and partly the server lead's own input (its "additional optimization" section credits a conversation with him): static vs dynamic data, server keeps per-object state, full data to newcomers and deltas to everyone else, a bitmask of changed fields per category. Gaps that make it unusable as the design:
- It optimizes the transport of the wrong content: dynamic rod data stays rod points plus transforms (~239 bytes per rod by its own count); the model question above is never raised
- It contradicts itself: the server "need not know the client's serialization" and stores two opaque byte arrays, yet must "patch" deltas and later trim fields by distance — both require knowing the layout. Either an opaque relay or a server model, not both
- Nothing on baselines and ordering: the event carries the unreliable flag, but the game connection is TCP (WSS on Xbox; QUIC/WSS/TCP on GameCarrier), so loss in flight is not the issue; what the TDD leaves open is the baseline for a late joiner or a reconnect (no keyframes) and the ordering problem that started FP-39149
- The client lead asked in the ticket for a survey of current systems; the page has none. Frequency is stated as 10 Hz; code says 5 Hz (`DATA_FRACTION_DELAY = 0.2`)

## Relation to Fish Fight Protocol v2 (FP-45122)
- The client side's v2 spec (2026-09-08, redaction 2) proposed describing the TPM frame in the v2 schema at step 1 ("types only, format and frequency unchanged") and choosing later between A (leave as is), B (server verifies the frame against the fight state) and C (server broadcasts from its own state). Server lead's decision: A now and nothing of TPM in the v2 schema; B/C belong to TPMv3 and are framed as bandwidth, allocations and visual correctness, not as anti-cheat — a cosmetic channel needs none
- Relates: FP-45122 (scope boundary; v2 provides the server-owned position that TPMv3's interest management needs)
