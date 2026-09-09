# tpm — Backlog

- [ ] Verify the content-model defect in client code: which rod-bend data the frame carries (`ThirdPersonData`, rod
  points / transforms) and how the third-person rig applies it; confirm the degrees-of-freedom mismatch before any
  TPMv3 design work (read via `svn cat` at HEAD — local client checkouts are stale)
- [ ] TPMv3 design document to replace the 2025-10 TDD: server-owned avatar model, content model (tackle position and
  rod transform instead of first-person bend), reliability choice (reliable state sync vs unreliable plus keyframes),
  distance tiers with the server lead's numbers, presence-bit deltas, allocation-free serialization. Reuse v2's
  schema/codegen and transport layer; start only after FP-45122 v2 lands its server-owned state
- [ ] Answer the client side's open question ("does the server know it relays the frame blind, is that the norm"):
  yes, by design for a cosmetic channel — goes into the FP-45122 scope letter, not into a TPM change
- [ ] When TPMv3 starts: retire the mission position operation first (missions backlog), so position reaches the
  server by one path only
