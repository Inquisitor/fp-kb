---
date: 2026-08-09
purpose: Codex second opinion on the bracket-relative rewrite of rule 1, before it shipped
prompt: codex-review-prompt-2026-08-09.md
model: gpt-5.5, high reasoning effort
---

# Codex review -- bracket-relative rule 1

Verbatim answer. The raw session transcript is not kept: its tool calls echoed `methodology.md`
and `rating-application.md` in full, both of which live in this repository already.

I would not adopt the replacement exactly as written. The direction is right: the offense should be bracket-relative, not “NOOBS only.” But components 1 and 2 are currently too heuristic, and the anti-capping variant is weaker than it looks.

**1. Component 2**

Use an explicit test, but keep an effect-size rule too.

`expected >= 5` plus `observed <= expected / 2` is defensible as an operational screen, not as adjudication language. The `/2` rule is an uncalibrated effect size, and `expected >= 5` creates a bad cliff. In your own data, autoteo78 has `expected = 4.7`, `observed = 0`; that is more suspicious than the cutoff admits.

Do not use Poisson. Prize/no-prize per participation is closer to binomial. Since the lower-bracket conversion rate is estimated from the same player, prefer a one-sided two-proportion test:

`H0: p_top >= p_harvest`  
`H1: p_top < p_harvest`

For small samples, use Fisher exact or Barnard/Boschloo. Keep an effect-size requirement such as:

`p_top / p_harvest <= 0.5`

Then grade the evidence:

- strong: one-sided `p <= 0.01` and rate ratio `<= 0.5`
- supportive: `p <= 0.05` and rate ratio `<= 0.5`
- silent: insufficient top exposure or non-significant result
- never exculpatory by itself

Using a simple conditional Fisher approximation on your table:

- Panonski_Alas: `5/72` TOPS vs `37/177` MIDDLES, `p ~= 0.0045`
- Bas_di08: `0/28` TOPS vs `19/87` MIDDLES, `p ~= 0.0029`
- autoteo78: `0/14` TOPS vs `13/39` MIDDLES, `p ~= 0.0097`
- VM_Vigor: `3/37` TOPS vs `25/158` MIDDLES, `p ~= 0.17`

So the proposed rule gets Panonski and Bas right, misses autoteo78 because of the arbitrary `5`, and correctly does not corroborate VM_Vigor.

**2. Component 3**

The main honest profile is: a strong player over-registers, wins when present, and misses many events for mundane reasons. That can produce positive rating from play plus heavy no-show losses.

Benign explanations to explicitly exclude:

- real-life schedule conflict / chronic over-registration
- time-zone or event-time misunderstanding
- connection/platform outage, especially if clustered with other affected users
- queued offline penalty flush creating misleading ledger shape
- strong casual player who only likes certain lower-bracket events and occasionally samples TOPS
- returning veteran with old prize history and current inconsistent attendance
- account sharing or household play patterns causing unpredictable starts

Most do not survive all components if you also require temporal intent: positive play pushes the player toward/over the boundary, then no-shows/DQs pull him back, then prizes are collected below the boundary. Without that temporal order, component 3 is not robust enough. “Positive play + absence losses” is suspicious; “positive play, boundary-threatening rise, absence-driven drop, lower-bracket cashing” is much stronger.

**3. Anti-Capping**

The anti-capping variant does not fully close the gap.

The lifetime medal score is the weak part. A long-tenured honest veteran can easily satisfy `gold/Ng + silver/Ns + bronze/Nb >= 1` without current abuse. Pairing it with component 3 helps, but it still risks treating old skill evidence as current misplacement evidence.

Replace or supplement it with a counterfactual PCR measure:

For each lower-bracket prize, replay the player’s PCR without no-show/DQ penalties since matchmaking launch, or over a fixed recent window. If the counterfactual PCR would have placed the player in the bracket above at registration time, then the payoff was actually displacement-enabled.

That is much cleaner than lifetime medals:

`lower-bracket prize occurred while actual bracket = MIDDLES but no-absence PCR >= 1001`

For anti-capping, also require one of:

- repeated near-boundary residence, e.g. PCR 900-1000, with no-show/DQ losses preventing promotion
- climb-then-flush cycles visible in the ledger
- current-window or post-launch prize score, not lifetime score

**4. Component 1**

`60%` and `3 participations` are too arbitrary. Worse, harvest share mostly reflects exposure. X1aoDouYa has 95% of prizes below TOPS, but also 75 MIDDLES plays versus only 6 TOPS plays. That is not the same evidentiary shape as Panonski’s 72 TOPS attempts.

Reformulate component 1 as descriptive plus exposure-aware:

- define `CeilingBracket` as the highest bracket with meaningful exposure, not merely max bracket touched
- require top exposure based on expected count, e.g. `top_played * harvest_conversion >= 3` for weak evidence and `>= 5` for strong evidence
- compare prize share to play share, not only raw prize share
- let component 2 carry the real “harvest below demonstrated ceiling” burden

A better component 1:

`BelowCeilingPrizeShare >= 60% AND BelowCeilingPrizeShare - BelowCeilingPlayShare >= 15pp`

or, simpler: use component 1 only to identify the harvest bracket, not to fire enforcement.

**5. Reversing Rule 7 Direction 2 Closures**

Yes, reversing the closures is justified as a matter of methodology. The old closure was based on the wrong offense definition: “not NOOBS” was treated as “not target.” Your new evidence shows the same mechanism can exist at the MIDDLES/TOPS boundary.

But I would not treat both reversals equally.

Panonski_Alas is strong: `177M/72T`, `37M/5T` prizes, `+1822` MIDDLES play rating, `+36` TOPS play rating, `-1289` absence rating. Component 2 strongly corroborates lower-bracket harvesting. Reopen and likely action if trajectory timing confirms boundary-management.

X1aoDouYa should be reopened, not automatically banned from this table alone. `75M/6T`, `20M/1T`, `+1027` MIDDLES, `+54` TOPS, `-704` absence is suspicious, but TOPS exposure is still thin and positive. A legitimate reading remains: strong MIDDLES player, occasional TOPS participant, chronic no-shower. The deciding evidence should be trajectory timing and recurrence, not the aggregate table alone.

**6. Evasion Strategy**

The cleanest strategy that defeats all three components is anti-capping plus polluted play-rating:

Stay just below 1001, farm MIDDLES, never build meaningful TOPS exposure, and deliberately offset MIDDLES win-rating with started-but-bad results or actual played losses rather than relying mainly on no-shows. Keep enough no-shows to manipulate rating, but ensure `rating_from_play` is near zero or negative, so component 3 no longer sees “strongly positive play offset by absence.” Component 1 scores zero if the player never reaches TOPS. Component 2 is inadmissible. The anti-capping medal score may fire, but if it depends on lifetime counters and component 3 is necessary, it still misses.

A simpler evasion is staying below the wide gate: keep no-shows at 5, no-show share under 30%, or no-show rating loss above `-90`, and use started zero-score/idling events as the rating drain. Your methodology already notes that zero-score abuse is a second path; it should be part of the same bracket-displacement detector, not a follow-up someday.

The replacement I would trust is:

`chosen descent` + `counterfactual bracket displacement` + `current-window payoff below displaced bracket`

That directly tests the abuse mechanism and reduces dependence on arbitrary flavor labels.
