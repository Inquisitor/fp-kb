---
jira: FP-45122
title: Fish Fight Sync Contract (Server)
status: in-progress
executor: Stanislav
created: 2026-07-22
type: epic
---

## Status
Epic created with first children FP-45137 (D1 as-is docs) and FP-45138 (D2 authority/interruption analysis). Next: start D1.

## Summary
Server half of the client player-core campaign (FP-44583 phase 5, fish-fight). Rework the fishing sync layer properly instead of re-patching: as-is documentation → authority/interruption analysis → joint target design with the client team → implementation. Ships in a single release with a protocol version bump and forced update — no backward compatibility, no feature flags.

## Design decisions
- Plan restructured from contract-first (S0–S6 draft) to understand-first (D1–D3 → I1–I3): this campaign is the chance to design the system properly, not to codify the patched status quo.
- Protocol v2: message schema as the single source of truth → typed DTOs, binary serialization, auto-generated readable debug log (schema-driven pretty-printer on both sides — hand-rolled binary without a schema would reproduce the `iR`/`iF` problem in bytes).
- Terminology: D3 produces a fight/FSM/protocol section of the KB glossary; new naming mandatory for new code and the protocol boundary; legacy renames deferred to I3 and scoped to the fish-fight zone (no server-wide mass renames).
- Current-FSM diagram is generated from the transition tables (`StateTransitions`/`TransitionTargets`/`StateTransitionsIgnore`) — regenerable, cannot drift from code; rendered to SVG for Confluence.
- Model pins (I1) freeze gameplay outcome models only (stamina, escapes, breaks, wear) — the transport is deliberately replaced, not pinned.

## Plan
| Step                                    | JIRA     | Status |
|-----------------------------------------|----------|--------|
| D1 as-is docs + generated FSM diagram   | FP-45137 | To Do  |
| D2 authority/interruption analysis      | FP-45138 | To Do  |
| D3 target design (with the client team) | TBD      |        |
| I1 gameplay-model pins                  | TBD      |        |
| I2 implementation (protocol v2 + FSM)   | TBD      |        |
| I3 cleanup (crutches, renames, docs)    | TBD      |        |

Related: module card [game-processor](../../server/modules/game-processor/_card.md) (incl. [unsync-tolerance](../../server/modules/game-processor/unsync-tolerance.md) deep dive). Working slide decks (ours + client's) live in `D:\FishingPlanet\Dima\` (`2026-07-21-server-gameprocessor-slides.pdf` + editable HTML source).

## Milestones
- 2026-07-21 — Preparation: client phase-5 slides studied; FP-38709 epic fully swept (49 children → taxonomy + shipped-mechanism inventory); full code map of `GameProcessor` / `MultiRodGameProcessor` / FSM tables / `GameActionAdapter`; architecture slide deck (15 slides) delivered alongside the client decks; KB module `game-processor` created.
- 2026-07-22 — Epic FP-45122 created (Tech Debt, High) with ADF description (issue mentions as inline cards); plan restructured to D/I after discussion (single-release forced-update rollout, understand-first order, schema-driven binary protocol, glossary-driven terminology, generated diagrams); children FP-45137 (D1) and FP-45138 (D2) created and linked; slide deck updated to match.
