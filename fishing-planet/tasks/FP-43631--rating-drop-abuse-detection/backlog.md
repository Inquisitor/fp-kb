# FP-43631 — Backlog

## Done
- [x] Discovery SQL drafted, validated against ground-truth (Steam 3 + later `bafa56a3`)
- [x] Threshold calibrated: NoShows ≥ 10, NoShowSharePct ≥ 30, RatingFromNoShow_DQ ≤ -150
- [x] Cohort scan on Steam / PS / Xbox
- [x] Pre-finalization surgical leaderboard ban: 29 abusers (STEAM 13, PS 6, XB 10) → `bans-2026-05-11.md`
- [x] JIRA comment with column reference posted on FP-43631
- [x] **Post-finalize verification** (Query G on `CompetitiveRatingWeeklyHistory` across STEAM/PS/XB): 100% ban success — none of the 29 reached the reward list.
- [x] **Durable account ban** — handed off to Community/Support; they applied `Profiles.IsCompetitionsBanned` with their standard policy. Out of our hands from here.
- [x] **Residual scan** — Query B re-run with relaxed threshold `NoShowSharePct ≥ 30` across STEAM/PS/XB yielded 107 candidates total. Full list shared with Support via the same Google Sheet; ban actions applied by them.

## Immediate
(none — operational scope of FP-43631 delivered)

## Open questions / Deferred
- [x] **Zero-score policy** — handed off to Community team monitoring; they will raise a separate ticket if abuse pivots from no-show to zero-score.
- [x] **Future no-shows** — Community monitors abuse manually; no proactive detection on our side. Planned mitigations are out-of-scope here:
  - Server-side "consecutive no-show penalty" (idea, no ticket yet) — Community will spawn a ticket if recidivism becomes a pattern.
  - GDD-level: per-bracket prize caps (MaxWins / Max2nd / Max3rd) — natural progression pushes successful tankers out of NOOBS, removing the incentive entirely.
  - Twink/multi-account detection by IP / MAC — separate planned ticket.
- [x] **Mobile / Nintendo passes** — no action until matchmaking ships on those platforms. If structural mitigations (per-bracket prize caps, twink detection) land first, this may never be needed. Otherwise: re-use `discovery-sql.sql` + `weekly-leaderboard-ban.sql` from this task with the appropriate `@WindowStart` per platform launch date.
- [x] **Threshold drift** — Community monitors complaint volume; they will spawn a new ticket (or reopen this one) if the 30% gate stops separating signal from noise.

## Out of scope (separate task / GDD work)
- The structural fix (MaxWins / MaxMedals cap per bracket so no-show abuse becomes pointless) is a GDD-level change — separate ticket. This task delivered the *detection + reactive ban* loop only.
