---
artifact: codex-round2-critique
date: 2026-06-21
model: gpt-5.5 (high reasoning, read-only sandbox)
session_id: 019e5e78-ab5f-7c23-b052-4d43e2b3dbdb
purpose: Adversarial critique of Approach A (late grouping) with our five pitfalls in hand. Codex judges A vs B head-to-head and is instructed to be opinionated, not diplomatic.
---
# Codex round 2 — adversarial critique of late grouping

## Prompt

> # Adversarial design critique (reason from first principles; NOT about any codebase)
>
> You are critiquing two competing fixes for a known abuse in an online fishing game's asynchronous competitions. Be harsh and opinionated. Do NOT be diplomatic — if one approach dominates, say so and why.
>
> ## The system (recap)
> - Async competitions: players REGISTER in advance, then have a 2-hour window to play one ~30-60 min scored session whenever they like (even seconds before close).
> - Live standings hidden (an early high score can be beaten by a late entrant); final placement revealed only after close.
> - Matchmaking TODAY runs at competition START: registered players split by a hidden competitive rating into 3 brackets (Newbies/Middles/Tops); each bracket -> one group of target size ~20-80; if a bracket is too thin, weakest players from the adjacent bracket are PULLED across to fill it (designers want ~3 groups, no more). Rewards + podium placements handed out PER GROUP (top-1/2/3).
> - Groups are shown at start and not changed mid-competition.
>
> ## The abuse (THE FOCUS)
> "Group padding via dead souls": a group nominally has 20+ members but most are no-shows or zero-score registrants, so the real field is tiny -> someone wins a "group of 20" by catching one fish and idling. Amplified naturally: newbie brackets on high-level/night ponds are near-empty of real players (e.g. 71 registered, only ~10 posted any result). Can also be done deliberately with throwaway alt accounts as warm-body filler. (Assume a separate, near-ideal rating system will stop the related "tank your rating to drop into Newbies" abuse — focus only on padding.)
>
> ## Approach B (already proposed; treat as the incumbent to beat)
> Keep grouping at START. At SETTLEMENT, scale reward VALUE by "effective field size" = sum of qualification weight of valid competitors (smooth multiplier, not cliffs). Add a minimum competitive score floor (e.g. 20th percentile of trusted historical sessions for that pond/ruleset/time archetype) for premium podium rewards. Add a refundable entry bond (lost on no-show). Trust-weight alt accounts down for reward ACTIVATION (not ranking). Give participation credit / rating even when the prize pool is reduced.
>
> ## Approach A (the one I want you to attack hardest)
> Do NOT group at start. Run the SAME matchmaking algorithm at the END of the window, AFTER the play window closes, on ONLY the real participants — no-shows are simply excluded from grouping (they still get their rating penalty, just no group/placement). Optionally also exclude zero-score players in a later phase. Cross-bracket pull still happens, but now on the real (post-exclusion) field. Grouping is by rating, computed before results are tallied. Rationale: at close the field is 100% known, so dead souls can't pad anything, and the cross-bracket pull brings in REAL adjacent-bracket players to fill thin brackets.
>
> ## Pitfalls I already found in Approach A (critique these: am I right, wrong, or underestimating severity? what did I miss?)
> 1. Cross-competition rating coupling: if grouping at close uses the rating "live at close", then results of OTHER competitions that finalized between this one's registration and its close have shifted the rating used to bracket THIS one. So your bracket in comp B depends on how comp A (closing earlier) went. Fix: freeze the grouping-rating at a fixed snapshot (registration close / start) even though grouping is COMPUTED at the end.
> 2. Exclusion-threshold arms race: late grouping kills INNOCENT dead souls, but a motivated abuser just clears whatever participation bar exists (no-show -> excluded, so switch to zero-score; exclude zero-score, so switch to one-tiny-fish). If the abuser fabricates a full quorum with above-threshold alts, the cross-bracket pull never triggers and the farmer faces only alts. So exclusion thresholds raise cost but never structurally close malicious padding; only a comparison the abuser cannot fabricate (a population-derived par, or forced real pull) is robust.
> 3. Donor-end stuffing: if the cross-bracket pull selects donors deterministically (weakest-first), an abuser seats alts at the very bottom of the donor bracket so THOSE get pulled into the thin bracket instead of real players.
> 4. Degenerate tiny fields: if a bracket has 1 real player, they win uncontested -> late grouping still needs a density floor / "no contest" rule for the tail.
> 5. Operational: grouping moves into the result-computation critical path and clusters at window-close times, vs being spread across start times today.
>
> ## What I want from you
> 1. Attack Approach A hard. What breaks, what new abuse does it open, what am I underestimating? Find pitfalls beyond my 5.
> 2. Verdict: are A and B complementary, or does one dominate the other? If you could ship only ONE first, which, and why? Be decisive.
> 3. A specific claim to judge: I argue A addresses RANK/RATING inflation (winning empty groups still pumps the competitive ladder + medal counters) better than B, because A pulls in real opponents or denies the contest, whereas B scales the PRIZE but still hands out placement/rating for an empty-group win. Is that claim correct? Does B have to ALSO gate rating/rank by field size to be complete?
>
> Be concrete and decisive. I want a strong opinion, not a survey.

## Response (verbatim)

**Verdict: B dominates A as the first ship.** A is a useful accounting cleanup, not an abuse fix. If shipped alone, it mostly turns "registration padding" into "participation-set manipulation" and still needs B's core machinery: effective field size, score floor, trust weighting, no-contest gating, and rank/rating gating.

Approach A's strongest idea is simple: no-shows should not count as opponents. Correct. But that is not enough. The abuser does not need no-shows; they need controllable warm bodies. A excludes dead bodies, so the attacker graduates to barely-alive bodies.

Your five pitfalls are mostly right, and you are underestimating #2 and #3.

1. **Rating snapshot coupling:** correct. Using live-at-close rating is indefensible. Freeze the grouping rating at registration close or competition start. Otherwise unrelated competitions mutate bracket identity after the fact.

2. **Exclusion-threshold arms race:** this is the fatal flaw. A only kills accidental dead souls. It does not kill malicious padding. Any threshold that an alt can satisfy becomes the new cost of doing business. No-show, zero-score, one fish, ten fish, historical 20th percentile: if the attacker can fabricate it, they will. You need a comparison against something the attacker cannot cheaply fabricate: population-derived par, trust-weighted field size, or real-opponent density.

3. **Donor-end stuffing:** also serious. Weakest-first pull is gameable. If donor selection is deterministic and rating-local, attackers can place alts exactly where the algorithm harvests. A makes that selection more valuable because the final participant set is the grouping input.

4. **Degenerate tiny fields:** correct. Late grouping cannot conjure competition. A bracket with one real player is still one real player. Without a no-contest rule, A still manufactures medals.

5. **Operational cost:** real but secondary. This is solvable engineering. The abuse economics are the bigger problem.

What you missed:

**A gives attackers a better timing lever.**
Today, padding happens at registration/start. With A, grouping is determined by who actually posts a qualifying result by close. That means an attacker can register many accounts, observe the event ecosystem, then decide near the deadline which accounts to activate. You moved the manipulation point closer to settlement, when the attacker has more information and less uncertainty.

**A makes "withholding" a weapon.**
Alts do not merely enter; they can selectively not enter. If an attacker can influence whether a bracket is thin enough to trigger cross-pull, they can choose between "keep my private fake quorum" and "force adjacent-bracket pull" depending on which is better. That is a nasty control surface.

**A still counts fake opponents as real unless trust-weighted.**
This is the central failure. "Only real participants" sounds clean, but an alt with a token score is a real participant under A. Without trust weighting, A treats ten controlled accounts as ten competitors. That is exactly the thing B attacks.

**A can make post-hoc placement feel arbitrary.**
Players complete a session without knowing their group, then are grouped after the fact based on who else happened to participate. Even if score is not used for grouping, the contest identity is ex post. That is not automatically unfair, but it is psychologically worse and harder to explain.

**A damages bracket meaning in sparse populations.**
If newbie high-level/night ponds have few real newbies, A will either create tiny newbie contests, pull real middles downward, or merge away the intended bracket separation. None of those is a clean fix. You are redistributing scarcity, not solving it.

**A creates collusion surfaces around bracket boundaries.**
Because cross-bracket pull happens after real participation is known, attackers care intensely about the bottom of adjacent brackets. They can place accounts around boundary regions and decide which ones submit. Frozen ratings help, but do not remove boundary manipulation.

**A does not solve "one real farmer plus many compliant alts."**
That is the canonical malicious case. If the farmer controls enough above-threshold alts, A happily creates a full-looking participant group and awards the farmer. B at least says: those accounts have low activation weight, the score was below competitive floor, and the effective field was not real.

On the specific claim: **yes, your criticism of B is correct if B only scales prize value.** If B reduces rewards but still grants full medals, placement counters, rank progress, and rating gains for a fake field, then B is incomplete. Prize value is only one abuse target. Status inflation matters.

But the right conclusion is not "therefore ship A." The right conclusion is:

**B must gate rank/rating/medal activation by effective field size and competitive validity too.**

A placement in a low-effective-field group should be marked as participation or provisional placement, not a full competitive podium. Rating gain should be reduced, zeroed, or handled with very low confidence when the field lacks trusted opponents. Medal counters should distinguish "competitive podium" from "thin-field placement," or not increment at all below threshold.

So my decisive recommendation:

Ship **B first**, but extend it beyond prize value to cover **rating, rank, medal counters, and podium legitimacy**. Add A later only as hygiene: no-shows should not be displayed or counted as competitors. But A is not the abuse fix. B is the actual anti-padding framework because it prices the thing that matters: not nominal bodies, but trusted competitive opposition.

## Our verdict on this round
Codex's strongest move is the synthesis that resolves the A-vs-B tension by *extending* B rather than picking sides: **gate rank / rating / medals by effective field size too, not only prize value.** This directly answers our critique of B (that B leaves status inflation unaddressed).

Where we push back:

- Codex calibrated to the worst-case alt-farm attacker. The user's production data (case 366857: 71 registered, ~10 real) shows the *dominant* dead-soul population is **innocent** (clueless newbies who don't show), not malicious twinks. For that common case, late grouping (A) IS a real fix — it removes 61 of 71 ghosts and forces a real contest via cross-bracket pull. B's heavier machinery (par-floor, trust-weight) is least reliable exactly on rare archetypes (thin history → unreliable percentile; innocent newbies are not "low-trust"). So "A is mere hygiene" undersells A for the common case.
- A delivers what B does not: **an actual contest experience**. B leaves a hollow scaled-down "win" in the empty group. The FO's stated goal "хотя бы буде компетишен" is A's value proposition. Codex dismisses this as "psychologically worse" — but for the FO it is a design *goal*, not a side effect.
- Several of Codex's "new" pitfalls (withholding, donor-stuffing, boundary collusion) share *one* root: the deterministic cross-bracket pull operating on a now-manipulable real-participant set. De-risk the pull (randomize / obfuscate donor selection, or relax the forced-3-groups rule) and most collapse.

Synthesis we are taking forward: **load-bearing concept = price trusted competitive opposition, gate ALL value by it.** B-extended is the first-ship candidate (smaller change, avoids the rating-snapshot and operational-load pitfalls of A entirely). A optional later, on player-experience grounds, and only if the cross-bracket pull is also made non-deterministic.
