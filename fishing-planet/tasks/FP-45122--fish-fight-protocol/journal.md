---
jira: FP-45122
title: Fish Fight Sync Contract (Server)
status: in-progress
executor: Stanislav
created: 2026-07-22
type: epic
---

## Status
Answer round complete; the shadow/pre-contract fork is CLOSED — straight v2 only, owner confirmed 2026-08-05.
Next: execute D1 (refusal table, generated FSM diagram, as-is with corrected P-3; the client's wire-key registry as
input); unhitch redesign enters observation phase after GD picks parameters.

## Summary
Server half of the client player-core campaign (FP-44583 phase 5, fish-fight). Rework the fishing sync layer properly instead of re-patching: as-is documentation → authority/interruption analysis → joint target design with the client team → implementation. Ships in a single release with a protocol version bump and forced update — no backward compatibility, no feature flags.

## Design decisions
- Plan restructured from contract-first (S0–S6 draft) to understand-first (D1–D3 → I1–I3): this campaign is the chance to design the system properly, not to codify the patched status quo.
- Protocol v2: message schema as the single source of truth → typed DTOs, binary serialization, auto-generated readable debug log (schema-driven pretty-printer on both sides — hand-rolled binary without a schema would reproduce the `iR`/`iF` problem in bytes).
- Terminology: D3 produces a fight/FSM/protocol section of the KB glossary; new naming mandatory for new code and the protocol boundary; legacy renames deferred to I3 and scoped to the fish-fight zone (no server-wide mass renames).
- Current-FSM diagram is generated from the transition tables (`StateTransitions`/`TransitionTargets`/`StateTransitionsIgnore`) — regenerable, cannot drift from code; rendered to SVG for Confluence.
- Model pins (I1) freeze gameplay outcome models only (stamina, escapes, breaks, wear) — the transport is deliberately replaced, not pinned.
- Shadow fields / pre-contract path CANCELLED (2026-08-05, owner + server side aligned): the wire is not touched by a single key until the v2 flip; pre-flip measurements come from server logging; the client writes its receiver directly against v2. Document addressing convention: revision + symbol name, no bare line numbers.

## Plan
| Step                                    | JIRA     | Status |
|-----------------------------------------|----------|--------|
| D1 as-is docs + generated FSM diagram   | FP-45137 | To Do  |
| D2 authority/interruption analysis      | FP-45138 | To Do  |
| D3 target design (with the client team) | TBD      |        |
| I1 gameplay-model pins                  | TBD      |        |
| I2 implementation (protocol v2 + FSM)   | TBD      |        |
| I3 cleanup (crutches, renames, docs)    | TBD      |        |

Related: module cards [game-processor](../../server/modules/game-processor/_card.md) (incl. [unsync-tolerance](../../server/modules/game-processor/unsync-tolerance.md)) and [fish-fight](../../server/modules/fish-fight/_card.md) — the canonical record of both studies.

## Milestones
- 2026-07-21 — Preparation: client phase-5 slides studied; FP-38709 epic fully swept (49 children → taxonomy + shipped-mechanism inventory); full code map of `GameProcessor` / `MultiRodGameProcessor` / FSM tables / `GameActionAdapter`; KB module `game-processor` created.
- 2026-07-22 — Epic FP-45122 created (Tech Debt, High) with ADF description (issue mentions as inline cards); plan restructured to D/I after discussion (single-release forced-update rollout, understand-first order, schema-driven binary protocol, glossary-driven terminology, generated diagrams); children FP-45137 (D1) and FP-45138 (D2) created and linked.
- 2026-07-31 — Fish-fight study (D1 core): three client-team documents of 07-30 digested (codebase verdict, dormant machinery fate, FP-45194 blocker-2 deck) + comment 133151 in the epic; full code sweep of the fight on both sides (server NPN20260602, client Win64_CodeBranch r56789); every client-team claim verified and confirmed, several amplified; Q1-Q14 answers drafted. KB module `fish-fight` created (card + fight-tick + transport-contract + defect-register deep dives). Key new findings beyond the client docs: dead strong-fish escape throttle; no-escape returns suppressing tooth cutters; duplicate-"success" echoing the client's own request; cycle 0 on post-reconnect events; rod-on-pod event drain commented out on the client.
- 2026-08-01..05 — Answer round: Q1-Q14 + follow-up questions answered in writing to the client team; the four 133151 findings verified and answered in JIRA (comment 133365). Two corrections after cross-checks: Q11 (the "1 of 6" number belongs to fish GENERATION — `FishSelector.TryToGenerateFish` steps counter, not the fight path) and Q4/P-3 (cycle-0 events are ACCEPTED unchecked by the client filter, not dropped). `IsNetworkThreadEnabled` swept across all prod/test/QA/CERT/DEV DBs — off everywhere; `PondAustralia` provenance resolved (uncommitted Australia-campaign tail in a dev working copy; DLL commits to carry source revision going forward). Shadow/pre-contract fork CLOSED: straight v2, measurements via server logs. Client team delivered protocol-v2 input accepted as D1/D3 material: seven schema requirements (absence != zero, server-issued persistent cycle, dense per-slot event numbering, timestamps + evaluation-clock decoupling, refusal taxonomy, authority matrix, idempotency), wire-key registry (86 keys; `iF`/`iR` collisions, three case-pair hazards, dual-meaning `hTf`), three design proposals (server-derived unhitch slack, rod-replace hold via event, pod identity in the same bump) and client-side constraints for the format choice (IL2CPP/AOT, five stands, above-ITransport, schema-generated debug log). Unhitch redesign assessed and accepted as direction with two caveats (the `"l"` flag stays client-owned; C-7 latch leaks require flag-quality measurement in the observation phase).
- 2026-08-06..10 — D1 server half shipped and the exchange moved to Git. Contracts repo
  `fishing-planet/server/r-n-d/protocol-docs` created on the company GitLab (private, master append-only, client lead
  as Developer); the old exchange folder stays only as an inbox for out-of-repo drops. Delivered: generated server FSM
  (SVG + per-state tables, regenerable from the transition tables), `server-refusals.md` (three parts: operation
  envelope, FSM refusal layer with the provenance-annotated rollback table, per-opcode pass) with answers to the six
  client questions, and `server-fight-path.md` (tick pipeline, clock/pause coverage, escape and break trees, identity,
  threading) plus two counter-questions. `IsNetworkThreadEnabled` removed on both sides (client r56884 FP-45638,
  server SRV r16407 FP-45657 + patch NPN.M.2026.08.06-032). Answered all seven questions of the client's
  `state-map.md` §6: phase map confirmed with two corrections and a fourth async window; full wire-vocabulary
  inventory; the D2 divergence framework (ownership, reaction classes A–D, commit points, debuffs, generated
  divergence matrix — server side to produce the skeleton); inventory mutations bypassing the fight FSM (new defects
  D-14..D-19); and the fight-timeout question, whose premise proved wrong — `ImitateSynchronizationBroken` was a
  debug imitation whose call was commented out in the very commit that introduced it, so nothing was ever designed and
  cancelled. Every outgoing document passed two adversarial review rounds before publication; four of our own claims
  were refuted and fixed pre-send (Hitch free-escape, exception direction in `AttackFinished`, `SwapRods` coverage,
  `RodCaster` ownership). Glossary elevated to a checked artifact (`tools/check-glossary.py`: structure, closed status
  set, doc-link and live-identifier existence with comments stripped). Client side meanwhile answered our two
  questions (`FightFishOnPod` is an adapter method, not a wire opcode; only `b` is dead on arrival) and FIXED `lTf`
  after ten years — which changes the unhitch roll inputs and leaves a GD/threshold decision open on our side.
- 2026-08-10 (late) — Client team answered both server questions and shipped a `lTf` fix of their own; server
  response sent the same evening. Decisions: the client fix is not reverted (it rides with v2); the server takes on
  three commitments for the new branch — move `LowHitchForce`/`HighHitchForce`/`MinHitchTime` from compile-time
  constants into `GlobalVariables` (today the thresholds are not tunable at all, only the probability is), add
  observation logging to `HandleUnhitch` so the "how much rarer" question is answered with numbers before the v2
  ship, and pin current unhitch behaviour with a test under I1. Threshold calibration goes to GD together with those
  numbers, not before. Server concern about `FightFishOnPod` withdrawn — it is an adapter method name, not a wire
  opcode; instead two client defects surfaced (no `CanSendGameActions` guard on the pod path, three arguments
  hardcoded to `false`), which also means the `wLn` third state collapses on the pod path and `isPoolingOrStriking`
  never reaches anti-cheat from a rod on a stand. Of the server-written response keys only `b` proved dead on
  arrival — it will not be carried into the v2 schema.