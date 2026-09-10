# tpm — Decision Log

2026-09-09 [NPN] Module created during FP-45122, when the client side's Fish Fight Protocol v2 spec (2026-09-08) pulled the
third-person channel into the fight-protocol epic. Sources: server relay path read in NPN20260602 (`Game.PublishEvent`,
`GameClientPeer.TryToggleTPM`); client internals from the client team's spec (pin r57335), not verified locally; JIRA
FP-39149 and the TPMv3 tickets; Confluence TDD page 5003771920 v11; the server lead's account.

2026-09-09 Decision (server lead, 2026-09-08/09): TPM is outside FP-45122. Not in the v2 schema even as types; the v2
wire does not touch the frame; the client side's option "A: leave as is" holds. The rewrite is TPMv3, sequenced after
v2 because it reuses v2's server-owned state, schema/codegen and transport layer. Intent and rationale:
[tpmv3-design-intent.md](tpmv3-design-intent.md).

2026-09-09 Finding (UNVERIFIED in code; server lead's account of a conversation with the TPM implementer): the frame
carries first-person rod-bend data replayed on a third-person rig with fewer degrees of freedom, so rods bend in the
wrong direction. Verify item in the backlog.

2026-09-09 Finding (verified, NPN20260602): `IsTpmDisabled` is not a player setting but server-side bad-ping detection
(`TryToggleTPM`, thresholds `DisableTpmPingThresholdMs` / `DisableTpmTriggerDelayMs`), logged to analytics via
`SaveBadPingTpmToggle`. Besides pause it is the only recipient filter the relay has.

2026-09-09 Assessment (verified against Confluence 5003771920 v11): the 2025-10 TDD is sound on delta mechanics but
optimizes the wrong content model, contradicts itself on whether the server knows the frame layout, and ignores
reliability and ordering. Details in the deep dive. Not to be used as the TPMv3 design as it stands.

2026-09-09 Finding (verified, NPN20260602; belongs to missions and recorded there): the mission position operation can
be retired only with two source substitutions — `Walk` does not write the missions context (only fight-wire opcodes and
boat travel do), and the rotation it carries feeds the photo analytics. The aim point falls back to the throw target,
but only after the cast. See the missions backlog, "Position Operation Cleanup".

2026-09-09 Correction (user; verified in the client checkout): the TPM event is raised with `sendReliable = false`, but the
game connection is TCP on every platform except Xbox (WSS) — `StaticUserData.ServerConnectionProtocol`, port 4530 — and
GameCarrier runs over QUIC/WSS/TCP, so the frames arrive reliably and in order. The card and the design-intent note had
called the channel "unreliable" after the client team's documents; both now say the flag is nominal. Lesson: a Photon
reliability flag says nothing until the transport is known.
