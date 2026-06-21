---
status: in-discussion
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-42677
confluence: https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/5428281345/Competitive+rating+abuse+prevention+proposal
related: FP-43631, FP-43625, FP-43717, FP-41746, FP-26788, FP-24873
---
# FP-42677: [Matchmaking&Leaderboards] GD proposal for rating-abuse prevention

## Status
Underlying JIRA closed 2026-03-19 with the GD-proposal document delivered (Confluence page 5428281345 — "Competitive rating abuse prevention proposal", authored by Vitaliy Belenok / GD-FO). KB tracks the follow-up design discussion (2026-06) that **extends the proposal's scope**: from rating-drop abuse (which FP-43625 MaxWins-gate addresses structurally and FP-43631 closed reactively) to also cover **group padding via "dead souls"** — the second-order abuse exposed once the matchmaking system shipped. No implementation; iteration is conceptual, with key forks pending FO answers (see Open Questions).

## Summary
Two-layer abuse against the new matchmaking:

- **Abuse №1 — rating drop ("переливал").** Skilled players tank competitive rating to drop into the Newbies bracket and farm weak opponents. Reactive containment: FP-43631 (surgical leaderboard ban, 29 + 185). Structural fix: FP-43625 (MaxWins gate via lifetime podium counters — immutable signal). Assumed solved going forward.
- **Abuse №2 — group padding ("мёртвые души").** Groups nominally have 20+ members but most are no-show or zero-score registrants; the real competitive field inside a group is tiny → someone wins a "group of 20" by catching one fish and idling. Amplified *naturally* on high-level / night ponds where Newbie registrations are mostly clueless newbies who don't show (real case 366857: 71 registered, ~10 real). Can also be done deliberately with alts as warm-body filler.

Three solution paths under consideration:

- **Path A — late grouping** (FO proposal): run the same matchmaking algorithm at *window-close* on real participants only (excluding no-shows; optionally also zero-scores in a later phase). Cross-bracket pull then operates on the post-exclusion field. Pre-result rating snapshot is used. Argued via timing: at start the real field is unknowable, at close it is 100% known.
- **Path B — settlement-time reward scaling** (independently produced by Codex GPT-5.5 in a blind first-principles consult): keep grouping at start. At finalization, scale reward value by *effective field size* (qualified competitors, smooth multiplier, not cliffs). Add par-floor for premium podium (e.g. 20th percentile of trusted historical sessions for the event archetype). Refundable entry bond, lost on no-show. Trust-weight alt accounts down for *reward activation*, not ranking. Clean decomposition: Roster / Qualified competitive field / Reward activation.
- **Path C — combined**: A as the contest-realness layer (handles *innocent* sparsity by pulling real opponents into thin brackets), B as the un-fabricatable economic/status gate for the *malicious* tail (alt-stuffing).

**Load-bearing concept** both lines converge on: *price trusted competitive opposition (not nominal bodies), and gate ALL value by it — prize + rank + rating + medals — not only the prize.*

Adversarial Codex verdict on A vs B (round 2): "B dominates A as the first ship. A is accounting cleanup, not an abuse fix." Caveat (our pushback): Codex calibrated to the worst-case alt-farm attacker and underweighted that the *dominant* problem in production is innocent sparsity, where A is genuinely effective and B's heavier machinery (par-floor, trust-weight) is least reliable. A also delivers what B does not — an actual contest experience (FO's "хотя бы буде компетишен"). The choice is therefore not "ship A xor B" but how much status-gating to add to B and whether A is justified later on player-experience grounds.

## Open Questions (for FO Vitaliy)
1. **Phase 2 of late grouping** — does "поймал ноль" forfeit competitive placement entirely? If yes, do we preserve participation-tied credit (dailies, achievements) separately so legit zero-finishers are not double-hit?
2. **Cross-bracket pull determinism** — keep weakest-first donor selection (gameable by donor-end stuffing) or randomize / obfuscate?
3. **Status gating under Path B (or C)** — gate not just prize value but also rank / rating / medal counters by effective field size? Hard no-contest threshold or smooth confidence weight?
4. **Par-floor on rare archetypes** (high-level / night ponds) — historical percentile is least reliable exactly there. Designer minimums for rare formats?
5. **Entry bond calibration** — currency and amount that bites farmers but does not suppress legit newbie participation?

## Plan
TBD. Decision pending FO answers above. Implementation discussion is premature; current phase is design exploration and adversarial validation. Once the path is chosen, code-side mapping work is bounded (settlement reward computation in `UpdateCompetitiveLeaderboards` / reward-push pipeline for B; `ProcessGrouping` invocation point + finalization sequencing for A).

## Artifacts
- [codex-round1-blind.md](artifacts/codex-round1-blind.md) — blind first-principles consult (our solutions withheld); Codex independently landed on Path B without reaching late grouping.
- [codex-round2-critique.md](artifacts/codex-round2-critique.md) — adversarial critique of Path A with our five pitfalls; Codex verdict and seven new pitfalls beyond the five.

## Milestones

- 2026-06-10: Mapped the two-layer abuse against new matchmaking. Distinguished rating drop (FP-42677 original scope, structural fix via FP-43625) from group padding via dead souls (new surface, no ticket yet). FP-43631 detector + surgical bans recorded as reactive containment of rating drop. Real case 366857 anchored the *innocent* nature of the dominant dead-soul population (61 of 71 in newbie bracket on a high-level pond).
- 2026-06-21: FO proposed Path A — late grouping. Move `ProcessGrouping` from competition start to window-close, on real participants only; no-show keeps rating penalty but does not pad. Phased: phase 1 excludes no-show; phase 2 (uncertain) also excludes zero-score. Side benefit for abuse №1: a tanker can no longer register for many comps and sleep — they must actually log in to each, which costs time and is ~2× slower at rating drain (ZeroScorePenalty ≈ NoShowPenalty / 2).
- 2026-06-21: Pitfall pass on Path A. Five concerns recorded: (1) cross-competition rating coupling if grouping uses live-at-close rating → freeze snapshot (FP-43816 becomes load-bearing for correctness, not just analytics); (2) exclusion-threshold arms race (no-show → zero-score → one-fish): exclusion thresholds raise the cost of malicious padding but never structurally eliminate it; (3) donor-end stuffing on deterministic weakest-first cross-bracket pull; (4) degenerate tiny fields (1 real player) still need a density floor; (5) operational load shifts into the finalization critical path and clusters at window-close times.
- 2026-06-21: Blind Codex consult (gpt-5.5, high reasoning). Codex did NOT reach late grouping; independently converged on Path B with the clean Roster / Qualified field / Reward activation decomposition. Validates that late grouping is genuinely non-obvious; Path B is the "obvious to a strong reasoner" answer. Codex added: smooth reward multiplier (anti-sniping), par-floor poisoning as a new vector against historical benchmarks, event-scheduling transparency as a second-order benefit.
- 2026-06-21: Adversarial Codex consult on Path A with our five pitfalls. Verdict: "B dominates A as the first ship; A is accounting cleanup, not an abuse fix". Codex called pitfall #2 the *fatal flaw* of A and rated #3 also serious. Added beyond the five: better timing lever for attackers near close; withholding as a weapon (choose between private fake quorum vs forced cross-pull); A still counts above-threshold fake opponents as real unless trust-weighted; post-hoc placement feels arbitrary; bracket meaning eroded in sparse populations; collusion surfaces around bracket boundaries; canonical "one farmer + many compliant alts" not solved by A. Confirmed the criticism of B: yes, B is incomplete if it only scales prize value — must gate rank / rating / medal counters too.
- 2026-06-21: Synthesis recorded. Load-bearing concept: *price trusted competitive opposition, gate all value by it.* Path B-extended is the first-ship candidate (smaller change — does not move grouping timing, avoids pitfalls #1 and #5 entirely). Path A optional later, justified by the player-experience goal of "real contest" (not by anti-abuse), and only if cross-bracket pull determinism is also de-risked.
