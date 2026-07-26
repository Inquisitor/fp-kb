---
title: FP-43631 — Rating-drop abuse detection & ban methodology
purpose: Self-contained operational playbook for the weekly FP-43631 cycle. Hand-off ready.
status: stable (calibrated through weeks 5-10, in production since week-3)
jira: https://fishingplanet.atlassian.net/browse/FP-43631
example_cycle: week-10 (2026-07-12) — file references point to that cycle; week-7 walkthrough kept below as historical illustration
---

# FP-43631 — Rating-drop abuse detection & ban methodology

## Overview

Players exploit the matchmaking system (launched 2026-04-29) by registering for Competition-kind
tournaments and not showing up, accruing `NoShowRatingPenalty` to deflate their `CompetitionRating`
(PCR) and dropping into the easier **NOOBS bracket [PCR 0-100]** where they farm low-difficulty
prizes. The MIDDLES bracket is **[101-1000]**, TOPS/MASTERS is **[1001+]**.

The task runs as a **weekly operational loop**: a Sunday sweep across three platform PROD databases
identifies abusers from the past week's tournament data, an adversarial trial filters and
classifies the cohort, surgical Profile-bans land via WebAdmin-equivalent SQL, three persistence
layers get verified, and the Community/Support team gets a handoff sheet of the same cohort for
durable account-ban decisions on their side.

## Domain glossary

- **PCR** — `Profiles.CompetitionRating` (int). The deflated value is the exploit lever.
- **Bracket** — NOOBS (PCR 0-100), MIDDLES (101-1000), TOPS / MASTERS (1001+). Bracket assignment
  is per tournament, snapped at registration time.
- **No-show** — `TournamentParticipants.IsStarted = 0`. Player registered, did not start. Penalty
  is applied to PCR regardless.
- **Batched-flush group** — multiple `Tournament reward Competition #X added CompetitionRating`
  ledger entries logged at the same exact second timestamp. Mechanically this is the server
  reconciling queued offline penalties on next login. Useful signature when paired with intent
  evidence (climb-then-flush, NOOBS-bracket prize concentration).
- **Climb-then-flush** — PLAYED entry pushes PCR into MIDDLES, followed within hours by NO-SHOW
  entries dropping it back below 100. The classic bracket-farming move.
- **MIDDLES → NOOBS drop** — single no-show entry where `pcr_before >= 100 AND pcr_after < 100`.
- **Stale flag** — `IsCompetitionsBanned = true` with `BanEndDate` in the past OR NULL. The
  canonical game-engine check `ProfileLogic.IsCompetitionsBannedNow()` is the AND of
  `IsCompetitionsBanned = true` AND `BanEndDate > now` — null/past BanEnd means **not effectively
  banned**. See `<memory>/feedback_competitions_banned_semantic.md`.

## The weekly cycle — step by step

The cycle runs Sundays. Window is the prior Mon-Sun (e.g. week-7 sweep on 2026-06-21 covered
2026-06-15 → 2026-06-21). Ban effective date is Monday-aligned.

### 1. Detection SQL — wide gate

Run `artifacts/week3-cs-report.sql` on each platform PROD MAIN with `@WindowStart` set to the
window's Monday. Gate:

- `NoShows >= 6` (raw count of registered-but-not-started competitions)
- `NoShowSharePct >= 30` (share of registrations that were no-shows)
- `RatingFromNoShow_DQ <= -90` (rating lost specifically to no-shows + DQs)
- `TotalPrizes > 3` (the prize gate — players who only no-show without cashing prizes are not the
  enforcement target)

Output columns are documented in the SQL header. The script is parameterized by `@WindowStart`
only; the four threshold values have stayed unchanged since week-3.

**Three connections**: `[F2P] STEAM PROD MAIN`, `[F2P] PS PROD MAIN`, `[F2P] XB PROD MAIN`. Run
the same SQL on each; cohort size at this stage is typically 15-30.

**Example (week-7)**: 26 total — 9 Steam, 15 PS, 2 Xbox.

### 2. Sample triage — manual pre-trial categorization

Before the adversarial trial, eyeball the SQL output and tag each row mentally:

- **Pure NOOBS-farmer** — prizes 4N+ with 0M and 0T, no-show share >= 40%. Strong BAN candidate.
- **Watchlist holdover** — UserId matches a prior-cycle watchlist entry. Check for flavor change
  to NOOBS prizes; if yes, the standing watchlist-to-ban rule fires without further deliberation.
- **REPEAT** — `IsBanned=true` and `BanEnd <= GETUTCDATE()`. Likely 4W candidate under the
  recidivism rule.
- **Already Support-actioned** — `IsBanned=true` and `BanEnd > GETUTCDATE()`. Note the BanEnd; do
  not re-ban (the Step 5 SQL WHERE clause will skip them anyway).
- **MIDDLES-only veteran** — prizes 0N+(M)+0, lifetime prizes 50+. Different flavor; trial
  typically gives WATCH.
- **TOP/MASTERS-tier sandbagging** — PCR > 800, prizes concentrated in upper brackets. Same
  flavor mismatch; usually WATCH.
- **Mixed N+M with NET POSITIVE PCR** — borderline. Trial discriminates by whether the climbs
  are followed by climb-then-flush cycles into NOOBS prize-zone (BAN) or genuine MIDDLES
  competition (WATCH).
- **Fresh-lifetime in LB top-10** — surface-level suspicious. Trial requires the joint test
  (fresh + 3+ wins + net-negative PCR + MIDDLES exposure) before BAN.

The triage is informal and only used to brief the trial; the trial itself decides.

### 3. Trajectory dump — Mongo Tournament-log

Each candidate gets a 3-week Tournament-log slice from `tournamentLog` collection (schema
`main2`, not `main` which is stale). The 3-week window gives ~2 weeks of pre-context plus the
detection window.

**One consolidated aggregate** (introduced week-7) runs once per platform Mongo PROD with all
UserIds in `$in: [...]`. The query is in `artifacts/pcr-trajectory-queries-<date>.js`. UserIds
are globally unique FP GUIDs — each platform's Mongo returns only its own candidates.

Output rows: `<UserId>\t<ISO timestamp>\t<verbatim Message>`. Save as three per-platform .tsv
files in `artifacts/pcr-log-trajectories-<date>/` (typical sizes: Steam 3-7 MB, PS 8-15 MB,
Xbox 0.5-2 MB).

Then split into per-candidate .tsv via `grep "^\"<uid>"` + `sed` to strip the UserId column.
Bash template:

```bash
declare -A SLUG=( ["<uid>"]="<slug>" ... )
for uid in "${!SLUG[@]}"; do
  slug="${SLUG[$uid]}"
  {
    echo "line"
    cat steam-dump.tsv ps-dump.tsv xb-dump.tsv \
      | grep -F "\"$uid" \
      | sed -E 's/^"[0-9a-f-]{36}\t/"/'
  } > "${uid}-${slug}.tsv"
done
```

The 3 platform-level dumps are transient buffer — they get deleted after split, only the
per-candidate files survive.

**Slug rules**: lowercase, kebab-case, underscores → dashes, collapse multiple dashes. Example
mappings: `IIGot-_-Smoked` → `iigot-smoked`, `M4R5H_57_` → `m4r5h-57`, `LEBOOGIEEEE` → `leboogieeee`.

### 4. Parser agent — distill raw .tsv into trajectory cards

A general-purpose subagent reads the 24 (or however many) per-candidate raw .tsv files and emits
one `<uid>-<slug>.md` trajectory card per input. The agent recognises five event types via regex
anchors:

- **PCR ledger entry**: `Tournament reward Competition #(\d+) '(.*)' added CompetitionRating (-?\d+) \((-?\d+) -> (-?\d+)\)` — the spine.
- **Played-confirmation**: `Player started scoring time for Competition #(\d+)` — PLAYED iff
  present for the comp, NO-SHOW iff absent for a comp with a reward entry.
- **Registration**: `Player registered for Competition #(\d+)` and `Registration for tournament Competition #(\d+) ... failed`.
- **Process marker** (skip): `About to process tournament Competition #`.
- **Cheat trigger** (count + capture notable): `CHEAT: ...`.

Everything else (`Fish caught`, `Fish accounted`, `Fish is not scored`, scoring listings, `Update overall`, `Player finished`, `Competitive activity`, etc.) is IGNORED for the card.

The card's frontmatter computes:
- `pcr_range` / `pcr_at_start` / `pcr_at_end` / `net_delta`
- `batched_flush_groups` — same-second clusters of size >= 2 with at least one NO-SHOW
- `longest_no_show_streak_hours` — longest run of >= 5 consecutive no-shows
- `middles_to_noobs_drops` — counter of pcr_before>=100 AND pcr_after<100 AND status=NO-SHOW
- `cheat_triggers` count
- `notable[]` — up to 8 short verbatim-style descriptions of significant events

The body is the full chronological PCR ledger as a markdown table (`Timestamp | Comp ID | Comp name | Status | Δ | PCR`).

The agent prompt is the same shape every cycle — the only variables are: input directory, output
directory, SQL sanity-check table, player → platform map. **CRITICAL** instruction in the
prompt: do NOT invent data; if a file is empty, return empty; if a regex doesn't match, leave the
field blank. The week-5 first attempt was thrown away because the agent hallucinated synthetic
data; the current prompt explicitly forbids this.

### 4.5 Evidence completeness gate (post-Codex refinement)

Before dispatching the cohort to trial, cross-check parser-reported NO-SHOW counts against the
Step 1 SQL numbers per candidate. If a candidate's parser NO-SHOW count differs from SQL by more
than 20% OR by more than 5 absolute events (whichever is larger), flag the card with
`evidence_completeness: degraded` and include the SQL/parser diff in the pre-trial context. The
judge should downgrade confidence and prefer WATCH on degraded evidence unless the trajectory
signature is independently overwhelming (Da Sneaky Snake week-10 is an example where completeness
would be flagged but severity is sufficient to sustain BAN anyway).

Observed cases: Gustyn112 week-9 (parser 10 vs SQL 15, diff −5), alphaBiTsoop16 week-10 (parser
26 vs SQL 50, diff −24). Both remained BAN because signature severity dominated, but recurring
disagreement is a data-integrity signal that warrants investigation (possible Support pre-action
redaction of tail ledger entries, tail entries appearing post-parser-run, or parser regex
missing a variant).

### 5. Adversarial trial — workflow with prosecutor / defense / judge per case

A `Workflow` script (using the `Workflow` MCP tool) runs three subagents per candidate in a
`pipeline()`:

- **Prosecutor** (parallel with Defense): reads the trajectory card, argues BAN with severity
  score 1-10, cites specific evidence (timestamps, batched-flush events, climb-then-flush
  cycles, MIDDLES drops), proposes duration `2W-NEW` or `4W-REPEAT`.
- **Defense** (parallel with Prosecutor): reads the same card, argues `EXONERATE` / `WATCH` /
  `CONCEDE` with doubt score and alternative explanations (server-flush artifact, skill-cap
  oscillation, MIDDLES-only / TOP-only flavor mismatch with NOOBS-farming methodology,
  sample-size objection on a fresh-lifetime candidate, etc.).
- **Judge** (sequential after both arguments): reads both arguments, may consult the case file
  for verification, renders `finalVerdict` (BAN / WATCH / EXONERATE), `banDuration`, `reasoning`,
  `prosecutorResponse`, `defenseResponse`, `confidence` 1-10.

Schemas (`PROSECUTOR_SCHEMA`, `DEFENSE_SCHEMA`, `JUDGE_SCHEMA`) are typed via JSON Schema so the
subagent's StructuredOutput is forced and parseable. The whole workflow is ~3N agent calls
(N = cohort size); ~5-7 minutes for 24 cases.

**Pre-trial context** per case is mandatory — the `context` field on each `CASES[]` entry must
flag: `status` (NEW / REPEAT / Support-pre-actioned / stale-flag), watchlist holdover with the
prior-cycle flavor, the relevant SQL summary line, and any methodology refinement that applies.
Without this the trial loses calibration.

**Standing rules the judge prompt enforces:**

1. BAN is for clear NOOBS-bracket-farming via deliberate no-show deflation. Not for absence
   alone; not for MIDDLES-only or TOP-only sandbagging (different mechanism).
2. REPEAT status alone is not automatic BAN if the trajectory pattern is weak. When status is
   REPEAT and prize flavor is TOP/MIDDLES not NOOBS, WATCH applies just like NEW.
3. Sample-size objections deserve weight on first-cycle NEW candidates.
4. Watchlist players escalating to NOOBS flavor (NOOBS prizes appear OR MIDDLES->NOOBS drops
   appear) trigger automatic BAN without further deliberation.
5. (week-7 Kacumi refinement) Net-positive PCR alone does NOT defeat the bracket-farming
   hypothesis when the climbs are followed by no-show flushes and re-engagement at
   NOOBS-bracket competitions. The climb is the up-arc of a climb-and-cash cycle, not climber
   behavior. Only use net-positive as defense when there is NO climb-then-flush signature.
6. (week-8 KingYakO2 refinement, reframed post-Codex) NEW first-cycle candidates with a
   **novice competition profile** warrant WATCH with a one-cycle clock. Novice profile means:
   TotalPrizes < 10 (KingYakO2 baseline threshold) OR combination of (a) low lifetime volume,
   (b) structural counter-evidence (recovery-climb, continuous absence block, scheduler-artifact
   batches), (c) low leaderboard extraction (rank far outside top-100 or Wins <= 2). Does NOT
   apply to veterans whose flavor has changed to NOOBS -- those are BAN under rule 1/4.
7. (week-8 TR-dennisfb refinement + week-10 closure) High-PCR sandbagging WATCH (PCR >= 800
   OR Lifetime TOPS >= 5) carries a one-cycle clock. **Direction 1**: if NOOBS shift appears
   next cycle, rule 4 fires (BAN). **Direction 2** (post-Codex closure): if the candidate
   remains in the wide cohort for 3+ consecutive cycles with unchanged TOP-flavor and 0 NOOBS
   shift (VM_Vigor / Panonski_Alas pattern), close the case as "not FP-43631 target" and stop
   re-listing on the watchlist -- separate anti-abuse framework should own it if needed.
8. (week-9 CreekSamurai refinement / week-10 validation) Novice-deference WATCH from rule 6
   comes with a persistence check. Rule 4 auto-BAN fires next cycle if ANY of: (a) at least
   one additional MIDDLES->NOOBS drop compared to prior cycle, (b) NOOBS prize count grew by
   >= 2, (c) NoShowSharePct maintained above 30% on a >= 20% larger sample (Registrations grew
   materially without proportional Played growth). Validated week-10: CreekSamurai returned
   with 8 M->N drops (up from 3) satisfying condition (a) with margin -- Support pre-actioned
   at the exact 2W duration our rule would have applied.
9. (week-10 sandaljepitt refinement) **Within-bracket detector** for cases entirely inside the
   NOOBS bracket [0..100] where rules 1/4/6 miss because no MIDDLES->NOOBS drops and no
   climb-then-flush arcs are possible. Rule 9 fires on ALL of: (a) NoShowSharePct >= 40 (higher
   than the wide-gate 30%), (b) Prizes_NMT >= 4N with 0M and 0T (pure NOOBS flavor),
   (c) max PCR across the trajectory window < 100 (never climbs into MIDDLES), (d) at least
   10 Registrations in the sweep window (avoid tiny-sample false positives). Judge should
   accept "within-bracket abuse" as a load-bearing BAN argument even without cross-bracket
   evidence; defense counters remain novice-deference (rule 6, if TotalPrizes < 10) and
   sample-size (rule 3, if <10 played). Discovered from sandaljepitt week-10 dissent -- Support
   pre-actioned 2W (rating-drop duration; cheat bans are permanent on FP), trial WATCH under
   rule 6, alignment counter 27/28.

Output is `{ trials: [{ name, platform, status, prosArg, defArg, verdict }] }` — extract
verdicts via:

```python
import json
with open('<task-output>') as f:
    data = json.load(f)
for t in data['result']['trials']:
    v = t.get('verdict', {})
    print(t['name'], v.get('finalVerdict'), v.get('banDuration'), v.get('confidence'))
```

### 6. Ban execution — three layers

Trial-confirmed BAN verdicts (minus any already-Support-actioned with future BanEnd) go into
three persistence layers, atomic per layer.

**Layer 1: Profile ban** — `artifacts/bans-<date>.sql`. Atomic `SET XACT_ABORT ON` + `BEGIN TRAN`,
ends with manual COMMIT/ROLLBACK after the verify SELECT. Run on each platform PROD MAIN. WHERE
clause is the canonical not-effectively-banned check:

```sql
WHERE NOT (ISNULL(p.IsCompetitionsBanned, 0) = 1
       AND p.CompetitionsBanEndDate IS NOT NULL
       AND p.CompetitionsBanEndDate > GETUTCDATE())
```

This mirrors `ProfileLogic.IsCompetitionsBannedNow()` and covers stale-flag-with-NULL-date rows
correctly. **The older form** `ISNULL(IsCompetitionsBanned, 0) = 0 OR (BanEnd IS NOT NULL AND BanEnd <= GETUTCDATE())` **misses stale-flag rows with NULL BanEnd** — discovered week-6, fixed
week-7. See `<memory>/feedback_competitions_banned_semantic.md`.

Other things the SQL sets per row: `CompetitionsBanEndDate = b.BanUntil`, `AdminComment` audit
note appended (existing comment preserved), `IsInfluencer = 0` if it was 1.

**`AdminComment` carries the reason and the duration — nothing else.** It is a production player
record, so it must not describe how the case was decided: no mention of the review mechanism, no
internal role names, no tooling. Shape to keep:

```
Auto-ban by Stan via FP-43631 follow-up <date> - rating-drop abuse (week-<n>) (<NEW|REPEAT> until <date>)
```

Cycles 6-12 leaked an internal review description into this field and it reached 52 profiles
across the three platforms; `artifacts/fix-admincomment-2026-07-27.sql` is the idempotent
remediation. When building the next cycle's ban script by copying the previous one, check this
line first — that copy step is exactly how the wording propagated for seven cycles. See
`<kb>/feedback/no_kb_refs_in_code.md`.

**Layer 2: Leaderboard ban** — `artifacts/leaderboard-ban-sync.sql` (shared script, not
date-specific). Propagates active Profile bans to `CompetitiveRatingsCurrent.IsBanned = 1`
across Weekly/Monthly/Yearly periods. Must be COMMITted separately — the gotcha that caused
week-3/4/6 incidents was forgetting the COMMIT here. Verify SELECT shows `RowsExpectedToFlip` /
`RowsActuallyFlipped` so a mismatch is visible.

**Layer 3: Mongo banLog** — `artifacts/ban-log-backfill-<date>.js`. Mimics WebAdmin
`BanSource.WebAdmin` format with author "Stanislav Samoilov", reason
`'FP-43631 follow-up - rating-drop abuse (week-<n>)'` for NEW or
`'... (week-<n>, recidivism)'` for REPEAT, until clause matches the BanUntil. Three sections
(Steam / PS / Xbox), each `insertMany([...])` against the matching Mongo PROD.

**Ship the script with the `insertMany([...])` blocks ACTIVE (not `//`-commented).** The
operator selects each section together with the `var TS/MSG_NEW/MSG_REPEAT` assignments in one
highlight before running — having the inserts pre-commented breaks that selection workflow and
forces uncommenting per-section, which is error-prone. After running a section, the operator
comments out the executed block in their local copy to make accidental re-runs harmless; this is
a per-execution side effect, not the canonical shipped state.

**Date conventions**:
- NEW BanUntil = next-next Monday from sweep day (2W). Example: sweep on Sun 2026-06-21 → next
  Mon is 06-22 → next-next Mon is 07-06.
- REPEAT BanUntil = 4 weeks (Monday-aligned). Same example: 07-06 + 14d = 07-20.

### 7. Verification — 3-layer post-ban check

Run `artifacts/verify-bans-<date>.sql` on each platform PROD MAIN. The script lists every banned
UserId with expected platform + BanEnd, joins to `Profiles`, `Users`, and an aggregated
`CompetitiveRatingsCurrent` (counts of Wk/Mo/Yr banned vs not-banned). It outputs `Prof_Status`
and `LB_Status` columns reading `OK` / `not on this DB` (expected for off-platform UserIds) /
`FAIL: ...` (investigate).

Plus a Mongo banLog check via MCP DataGrip — three aggregate queries (one per platform Mongo)
with `$match: { Message: /week-N/, UserId: { $in: [...] } }` confirming all expected rows are
present with the right NEW/REPEAT flag.

The standing rule from week-3/4 incidents (Xbox LB sync forgotten, Steam profile not COMMITted,
Mongo backfill ran on wrong connection): **verify all three layers per platform individually,
every cycle**.

### 8. Community/Support handoff

`artifacts/cs-report-<date>.md` plus three per-platform TSVs:
- `cs-report-<date>-steam.tsv`
- `cs-report-<date>-ps.tsv`
- `cs-report-<date>-xb.tsv`

The TSVs are the actual data Support pastes into the shared Google Sheet (new tab per cycle).
Verdict column is normalized to two values for cleanness: **BANNED** (banned by us this cycle
OR pre-actioned by Support before our sweep) and **WATCH** (reviewed, not banning under our
methodology). Internal sub-categories (which BANNED rows are ours vs Support's, which WATCH is
which flavor) get explained in the `cs-report-<date>.md` Reading notes — not in the TSV.

The TSV column order is documented in `cs-report-<date>.md` and matches the SQL output 1:1.
Per-bracket cells use `N / M / T` with spaces (`8 / 12 / 0`) on purpose because Google Sheets
auto-parses `8/12/0` as a date.

**Two-phase TSV write**: pre-ban the TSV captures the snapshot at sweep time (used to brief the
md report); post-ban the SQL is re-run and the BANNED rows' `IsBanned` / `BanEnd` columns get
refreshed to reflect the just-set ban. If the post-ban refresh lands right after the same-session
commit, **use `git commit --amend --no-edit`** to fold it into the ban-pack commit rather than a
separate refresh commit. See `<memory>/feedback_post_ban_tsv_amend.md`.

### 9. Slack handoff to CS lead

A conversational Russian-language prose message to the CS team lead summarizing the cycle:
total banned, recidivism notes, watchlist escalators, support cross-check, watchlist that
remains. Draft saved transiently as `artifacts/slack-cs-<date>.md` during the session, sent by
the human, then deleted before commit.

Register is **conversational colleague**, not commits/JIRA-style technical. Specific rules from
`<memory>/feedback_slack_cs_register.md`:

- Open with a standalone courtesy paragraph for off-hours sends: "Это отложенное сообщение."
- Use colloquial substitutes: `нубики` / `нубы` / `сидение в нубах` / `метагейм` / `банвейв` /
  `WATCH-лист` (capslock + dash for the last, mirrors the TSV Verdict column)
- Frame lists as cross-cycle comparison material, not delegated work
- Subject is the player, not the tool: "научились играть аккуратнее, чтобы обойти фильтры"
  beats "обходить наш фильтр"
- Prose paragraphs, not bullets
- Names sparingly
- Close: `Если что — пиши.`
- Minimal markdown overall

### 10. JIRA comment

`https://fishingplanet.atlassian.net/browse/FP-43631`. Posted via Atlassian MCP. Register is
**impersonal/passive — no `we`/`our`/`us`**. See `<memory>/feedback_jira_impersonal_register.md`.

Replace patterns:
- `we didn't re-ban any of them` → `none of the four were re-banned`
- `our 2W standard` → `the 2W standard`
- `our review` → `the trial review`
- `our week-4 ban` → `the FP-43631 week-4 ban`
- `banned by us 4 → 17` → `banned this cycle 4 → 17`

Structure mirrors weeks 5-7:
1. **Bold opener**: `**Week-N follow-up complete.**`
2. **Bans paragraph** with all banned player names as webadmin links:
   - Steam: `https://steam-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
   - PS: `https://ps-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
   - Xbox: `https://xb-webadmin.fishingplanet.com/Player/PlayerCard?userId=<lowercase-uuid>`
3. **REPEAT paragraph** with concrete recidivism details (which week's ban expired when, how
   fast they came back)
4. **Most decisive cases** highlighted by name
5. **Support cross-check** paragraph — list pre-actioned with their wide-cohort presence, note
   trial-Support alignment count
6. **Watchlist escalators** paragraph if any fired
7. **Watchlist remaining** paragraph with brief reason per row
8. **Leaderboard sanity check**: `period <YYYYMMDD>` top-10 by Wins, count how many of cohort
   appear, list the names with rank
9. **Funnel vs prior cycle**: `wide no-show cohort A → B, tight farm-gated A → B, banned this cycle A → B`

ASCII rules from the global config DON'T apply here — JIRA accepts and renders `—` / `→` /
smart quotes / etc. natively. ASCII-only is **commits and code** only.

### 11. KB commit

Single commit per cycle covering: SQL ban script, JS banLog backfill, verify SQL, ban execution
md, CS report md + 3 TSVs, trajectory queries JS, trajectory cards directory, journal
milestones append.

Commit message describes **what changed in the KB**, not the contents of the artefacts. The
weekly ban-pack is the same shape every cycle (SQL ban script, JS banLog backfill, verify SQL,
ban execution md, CS report md + TSVs, trajectory queries JS, trajectory cards, journal
milestones) — collapse it to one bullet. Add a separate bullet only when something durable
beyond the weekly artefact set landed (new playbook file, new shared script, methodology rule
change, etc.).

Template:

```
FP-43631: [RatingDropAbuse] Week-N report[; <extra change if any>]
+ Week-N ban-pack and CS handoff
+ <durable addition not part of the weekly artefacts, if any>
= <durable change to existing KB file, if any>
(Story: [Server][Community] Find players dropping Competitive Rating to exploit new Matchmaking)
https://fishingplanet.atlassian.net/browse/FP-43631
```

Bullet rules from the global commit-message spec:
- `+` for additions, `=` for changes
- One bullet per file/change; don't restate what's in the file
- ASCII-only (`—` → `--`, `→` → `->`, smart quotes → ASCII)
- Backticks via single-quoted heredoc `cat <<'EOF'` — **do NOT escape backticks with `\`** or
  they ship as `\token\` in the log. See `<memory>/feedback_heredoc_backticks.md`.

The raw Mongo dump TSVs (the 3 per-platform files at step 3, and the 24 per-candidate raw .tsv
files post-split) are **NOT committed** — they're transient parser-agent buffer. Only the
distilled `<uid>-<slug>.md` cards are kept (~100-200 KB total instead of 15+ MB).

The trajectory queries JS file (`pcr-trajectory-queries-<date>.js`) IS committed — it's the
recipe to regenerate the dumps if ever needed.

A transient `_parse.py` script written by the parser agent may end up in the directory; it's
small (~15 KB) and reusable, so leave it in or remove based on cleanliness preference (week-6
removed it, week-7 kept it).

If the post-ban TSV refresh happens right after the ban-pack commit, **amend instead of a
separate commit** — see `<memory>/feedback_post_ban_tsv_amend.md`.

## Per-cycle artifact naming

Date in filenames is the **sweep date** (Sunday), not the ban date (Monday). E.g. week-7 sweep
on 2026-06-21 → all files dated `2026-06-21`, ban date is 2026-06-22.

```
artifacts/
├── bans-<sweep-date>.sql                           # Profile ban + audit
├── bans-<sweep-date>.md                            # execution record + trial verdicts table
├── ban-log-backfill-<sweep-date>.js                # Mongo banLog inserts
├── verify-bans-<sweep-date>.sql                    # 3-layer post-ban check
├── cs-report-<sweep-date>.md                       # CS handoff narrative
├── cs-report-<sweep-date>-{steam,ps,xb}.tsv        # CS handoff data
├── pcr-trajectory-queries-<sweep-date>.js          # Mongo aggregate (recipe)
└── pcr-log-trajectories-<sweep-date>/
    ├── <uid>-<slug>.md   × N                       # distilled trajectory cards (kept)
    └── _parse.py                                   # optional helper from parser agent
```

Static shared artifacts (not per-cycle):
- `artifacts/week3-cs-report.sql` — the canonical detection query (only `@WindowStart` ever
  changes; despite the "week3" name, the query is the same for every cycle 3+)
- `artifacts/leaderboard-ban-sync.sql` — LB sync, idempotent, safe to re-run

## Key concepts that distinguish BAN from WATCH

The trial's discriminator over weeks 3-10 has stabilized to:

**BAN if all four hold:**
1. Net-negative PCR over the trajectory window
2. PCR demonstrably crosses bracket boundaries downward via no-shows (MIDDLES → NOOBS drops
   present, OR sustained dwell below 100 after a drain)
3. NOOBS-bracket prize concentration this cycle (`Prizes_NMT` 4N+ with 0M)
4. Lifetime profile doesn't structurally exclude NOOBS-farming (fresh accounts pass trivially;
   long-tenured MIDDLES/TOPS veterans require flavor change to NOOBS prizes)

**WATCH if any of these dominate:**
- MIDDLES-only or TOP-only prize signature regardless of no-show share (different mechanism);
  under rule 7, high-PCR sandbagging WATCH also carries a one-cycle clock for NOOBS-flavor shift
- Net-positive PCR across the window with PCR ending in MIDDLES — but **only** if the climbs
  are not climb-then-flush cycles; if they are, BAN per the week-7 Kacumi rule 5
- Sample size too thin (< 10 played events) on a first-cycle candidate
- Sandbagging-within-MASTERS (PCR > 1000 throughout, prizes in 0N+kM+0T pattern)
- Novice-deference: NEW first-cycle with TotalPrizes < 10 AND structural counter-evidence
  (recovery-climb, continuous absence block, scheduler-artifact batches) — WATCH with
  one-cycle clock per rule 6 / rule 8 ladder

**Within-bracket abuse pattern** (post-week-10 sandaljepitt, rule 9 formalized): a player
farming NOOBS prizes entirely below PCR 100 (never climbs into MIDDLES, no MIDDLES->NOOBS
drops possible) satisfies rules 1 and 3 but fails rule 2 by absence-of-signal. Rule 9 (see
Standing rules section) closes this gap: high NoShowSharePct + pure NOOBS flavor + max PCR
below 100 across the window + >= 10 Registrations. Judges should accept within-bracket abuse
as load-bearing BAN evidence even without cross-bracket signature.

**Watchlist escalation rule** (rule 4): a player carried over from a prior cycle's watchlist
who shows flavor change to pure NOOBS this cycle is BAN without further deliberation. Fired
cleanly across cycles:
- Week-7: `rabolio41100` (from week-6), `maminapokorny83` (from week-5)
- Week-8: `MonsterFish_fuark` (from week-6), `Matiamo_PL` (from week-7)
- Week-10: `CreekSamurai` (from week-9 novice-deference WATCH — validation of rule 6/8 ladder)

**FarantirPL non-return** (week-9 novice-deference WATCH → did not appear in week-10 cohort) is
the parallel data point confirming rule 6 correctly declined to BAN on cycle 1. Rule 6 -> rule
4/8 escalation ladder demonstrated both directions in the same follow-up cycle (week-10).

## Trial-Support alignment

Cross-checking the wide cohort against Mongo banLog `Competition ban` entries reveals which
players Support had already actioned before the sweep. These get logged in the bans-md under
`support_pre_actioned_trial_confirmed` and are NOT re-banned (their Support BanEnd typically
runs past the 2W standard; the Step 6 SQL WHERE clause skips them automatically).

Running alignment counter — independently confirmed BAN verdicts on Support-actioned candidates
at the rating-drop vector:

| Cycle   | Support pre-actioned | Trial verdict alignment | Cumulative |
|---------|---------------------:|-------------------------|-----------:|
| Week-6  | 0 in rating-drop domain (`VM_NPWP` was anti-cheat-orthogonal) | n/a       | 0/0        |
| Week-7  | 4 (Kacumi, poink, A-J-Rimmer-BSC, nowa_zajawka)              | 4 conf 9-10/10 BAN | 18/18 |
| Week-8  | 2 (Adlerblut-Slayer, TR-dennisfb)                             | 2 conf 10/10 BAN   | 20/20 |
| Week-9  | 2 (ArTeM209, Gustyn112)                                       | 2 conf 9-10/10 BAN | 22/22 |
| Week-10 | 7 (JFF_Gothyka, LaccFarro, CreekSamurai, MLG720YOLO, Da Sneaky Snake, CraddiePoosta, **sandaljepitt**) | 6 confirmed BAN + **1 dissent (sandaljepitt: trial WATCH conf 7)** | **27/28** |
| Week-11 | 5 (yevhen331, sen1a, evgeniy3311, Ricky27sampei, **LZ23J7KS**) | 4 confirmed BAN + **1 dissent (LZ23J7KS: trial WATCH conf 7 under rule 7 direction 2)** | **32/34** |
| Week-12 | 3 (KondaFlk, VGB_N4rkos060905, rascof molotov) | 3 confirmed BAN, conf 9-10, all defense CONCEDE | **35/37** |

**Interpretation caveat (post-Codex)**: the alignment counter is a sanity check, not a
validation metric. Independence is weak because Support-pre-actioned status is included in the
pre-trial context field (methodology Step 5), so the judge is not blind to Support's action
when rendering the verdict. Kept for operational awareness; a real validation would require
blind replay of prior weeks (strip labels/status/history, mix in non-cohort negatives, score
against later observed persistence + leaderboard extraction).

**sandaljepitt (first dissent)**: Support pre-actioned at 2W for rating-drop (cheat bans on FP
are permanent -- the 2W duration confirms the vector). Trial gave WATCH under rule 6
novice-deference (Lifetime 5) with load-bearing structural argument: PCR range 0..69 entirely
inside NOOBS bracket, 0 MIDDLES->NOOBS drops -- no cross-bracket signature. Support saw enough;
trial framework did not. This is the within-bracket blind spot rule 9 candidate would address
(see Standing rules section).

## Methodology refinements over cycles

Each new refinement is documented in the bans-<date>.md `methodology_refinement` frontmatter
section the cycle it's discovered, then carried forward via memory rules.

| Cycle | Refinement | Memory rule |
|---|---|---|
| week-3 | Mongo Tournament-log batched-flush as intent evidence | (in journal) |
| week-4 | Three-layer verify per platform individually (post-incidents) | (in journal) |
| week-5 | Adversarial trial introduced; one-cycle WATCH downgrade pattern (Lay_D14S) | (in journal) |
| week-5 | Slack CS register: conversational, no bullets, "нубики" | `feedback_slack_cs_register.md` |
| week-6 | Verdict column reduced to BANNED/WATCH for cleaner CS sheet | (in journal) |
| week-6 | Fresh-lifetime + 3+ wins needs joint test (net-negative + MIDDLES exposure) | (in journal) |
| week-6 | Watchlist-to-ban escalation requires flavor change to NOOBS prizes | (in journal) |
| week-6 | `IsCompetitionsBannedNow()` canonical semantic; SQL WHERE clause gotcha | `feedback_competitions_banned_semantic.md` |
| week-6 | Heredoc backticks: do NOT escape with `\` in single-quoted heredocs | `feedback_heredoc_backticks.md` |
| week-7 | Net-positive PCR alone doesn't defeat bracket-farming (Kacumi calibration) | (in journal) |
| week-7 | Slack register: standalone courtesy opener, метагейм/банвейв/WATCH-лист | `feedback_slack_cs_register.md` (updated) |
| week-7 | JIRA register: impersonal/passive, no we/our/us | `feedback_jira_impersonal_register.md` |
| week-7 | Mongo trajectory: one consolidated `$in` aggregate per platform, not N queries | (in journal) |
| week-7 | Post-ban TSV refresh: amend ban-pack commit, not separate commit | `feedback_post_ban_tsv_amend.md` |
| week-7 | Re-ban WHERE clause adopts canonical form | (in `bans-2026-06-21.sql`) |
| week-8 | Novice-deference rule 6: NEW first-cycle + TotalPrizes < 10 → WATCH with week+1 escalation bias | (in `bans-2026-06-28.md` KingYakO2 case) |
| week-8 | High-PCR sandbagging rule 7: one-cycle clock on WATCH; NOOBS shift → BAN under rule 4 | (in `bans-2026-06-28.md` TR-dennisfb case) |
| week-8 | Mongo banLog backfill ships with active `insertMany([...])` blocks (no `//` prefix) | (in Step 11 above) |
| week-8 | Post-ban TSV refresh: `git commit --amend --no-edit` on the ban-pack commit | `feedback_post_ban_tsv_amend.md` |
| week-8 | Monthly leaderboard sanity check added to the cycle (period 20260601 top-50 across 3 platforms) | (in `bans-2026-06-28.md`) |
| week-9 | Rule 8 novice-deference ladder: WATCH once, auto-BAN on pattern persistence (validated week-10 CreekSamurai) | (in `bans-2026-07-05.md`) |
| week-9 | June monthly LB back-fill script: `monthly-lb-ban-june-2026.sql` (kept for future cycles; June run was no-op) | (in `bans-2026-07-05.md`) |
| week-9 | Commit-message rule: describe what changed in KB, not artefact contents; weekly ban-pack collapses to one bullet | (in Step 11 above) |
| week-10 | Sink-comp repeat targeting: same competition ID NO-SHOWed twice by same UserId is smoking-gun intent evidence that overrides sample-size defense | (in `bans-2026-07-12.md` Miron_33 case) |
| week-10 | First Trial-Support dissent on rating-drop (sandaljepitt): rule 9 candidate for within-bracket detector | (in `bans-2026-07-12.md` and standing rules above) |
| week-10 | LaccFarro operational case: our week-6 REPEAT trial-confirmed but Support already covered him at 5W; WHERE clause correctly skipped Profile update, Mongo banLog audit entry inserted (record of intent) | (in `bans-2026-07-12.md`) |
| week-10 | Codex consultation deferred followups: (a) methodology.md stale — this update addresses it; (b) two-phase blind→informed verdict architecture; (c) alignment counter is sanity check not validation, real falsification needs blind replay; (d) blind spots list — boundary camouflage (sandaljepitt), start-but-throw pivot (ZeroScore column unused), data-source SQL/Mongo reconciliation gate | (in `bans-2026-07-12.md`) |
| week-11 | Rule 7 direction 2 EMPIRICALLY VALIDATED for closure: LZ23J7KS (2nd Trial-Support dissent) confirms TOP-flavor MASTERS sandbagger family (LZ23J7KS/JIALIN0720/Bas_di08/VM_Vigor/Panonski_Alas) exits FP-43631 scope. Support scope broader; our methodology targets NOOBS-farming only | (in `bans-2026-07-19.md`) |
| week-11 | Rule 6 → rule 4/8 ladder VALIDATED SECOND TIME: evgeniy3311 (was W10 WATCH conf 7 Lifetime 10) escalated +11 NOOBS prizes → Support pre-actioned at 2W matching rule 4 auto-BAN. First was CreekSamurai w9→w10. Off-ramp works | (in `bans-2026-07-19.md`) |
| week-11 | Rule 6 in-window vs lifetime ambiguity flag: La_Iena_River_ (Lifetime 54, in-window TotalPrizes 6) triggered rule 6 novice-deference. On the standard wide-cohort where TotalPrizes gates are 4-11, rule 6 fires broadly. **Recommend clarifying: "Lifetime prizes < 10" is the KingYakO2-intent threshold; in-window prizes are a separate factor** | (in `bans-2026-07-19.md`) |
| week-11 | Rule 9 vs rule 6 collision flag: TurboBandz6351 hit ALL rule 9 gates (NS 46%, pure 5N, max PCR 81 < 100, Reg 29 >= 10) AND rule 6 novice-deference (Lifetime 5). Judge resolved via rule 6 override + rule 8 persistence clock. **Formalize precedence: rule 6 wins on first-cycle NEW, rule 8 carries the escalation** | (in `bans-2026-07-19.md`) |
| week-11 | Cheat-vector orthogonality precedent: Belion019 (Xbox) had 88 CHEAT triggers active (Undriven boat / Fish catch distance / Line high extension) alongside a clean rating-drop pattern (4 Kacumi + 6 batched flushes + 1 M→N). Trial BAN 2W on rating-drop grounds only, cheat vector orthogonal (AntiCheat framework separate scope). No methodology change; rules fire independently | (in `bans-2026-07-19.md`) |
| week-12 | **PCR-floor evidence gap, code-verified** — the rating is clamped at zero and the ledger write is conditional on it changing, so a penalty landing on an already-zero rating emits NO ledger line. Volume must come from SQL, the card is authoritative only for shape, and a sparse card for a floored candidate is an artifact rather than exculpatory. Also: the printed Delta is the assessed penalty while the parenthetical is the clamped movement. Retroactively explains the parser-vs-SQL divergence open since week-9 | `<kb>/fishing-planet/server/modules/matchmaking/rating-application.md` |
| week-12 | Ledger gap has TWO causes and must not be read as one metric: floor absorption (above) vs queued application (assessed but player not reconnected — the batched-flush signature). Discriminator: presence of any `-> 0)` line in the window. Exact per-candidate `floor_shots` needs a comp-id level join — deferred | (in `bans-2026-07-26.md`) |
| week-12 | **Boundary-targeting discriminator** emerged independently across judges: deliberate deflation should cluster near the bracket boundary, since shedding rating deep inside NOOBS buys nothing. Used to decline rule 1 on four candidates. **Operator partially rejects it** — a player who wins inside NOOBS accrues rating that must be shed continuously, so deep-bracket no-shows are ceiling maintenance and the equilibrium is the signal. Useful as corroboration; its absence should not alone defeat rule 1. To settle with the CS lead | (in `bans-2026-07-26.md`) |
| week-12 | **First operator override of a verdict** (dreadloc). Criterion: presence in the platform weekly Won leaderboard top-10, scoped to NOOBS-flavor extraction. Rationale: top-10 is where prizes are actually taken, so deferring on a player converting a suppressed rating into rewards defers past the payout. Canonical ranking per `<kb>/.../leaderboards/data-model.md`. Deliberately NOT applied to X1aoDouYa / autoteo78 (MIDDLES-bracket wins) nor La_Iena_River_ (qualifies on flavor but trend is upward — held, re-check next cycle) | (in `bans-2026-07-26.md`) |
| week-12 | Rule 7 direction 2 produced its **first actual closure**: Panonski_Alas EXONERATEd and exits tracking rather than rolling forward on another WATCH. Family remainder: X1aoDouYa, EsseDouble, autoteo78 | (in `bans-2026-07-26.md`) |
| week-12 | Briefing defect caught by a judge: same-second batched groups are **flush moments**, not proof of contemporaneous presence. Future briefs must state this explicitly so prosecutors stop arguing "he was online while burning parallel registrations" | (in `bans-2026-07-26.md`) |
| week-12 | Rule 6 wording corrected in the brief to **LIFETIME** prizes < 10 (the KingYakO2 intent), resolving the w11 in-window/lifetime ambiguity. Rule 9 precedence made explicit: rule 6 outranks rule 9 on a first-cycle NEW candidate, but not on a returning one — which is what carried TurboBandz6351 to BAN | (in `bans-2026-07-26.md`) |

## Example: week-7 walkthrough (2026-06-22 ban date)

Detection: `week3-cs-report.sql @WindowStart='2026-06-15'` × 3 PROD MAIN → 26 candidates.

Trajectory dump: single aggregate over 26 UserIds × 3 Mongo PROD → 3 per-platform .tsv (15 MB
total), split via grep+cut → 26 per-candidate .tsv (~7 MB), parser agent → 26 .md cards
(~200 KB).

Adversarial trial: 78-agent workflow (26 × 3 roles), ~6 minutes, returned 21 BAN + 5 WATCH + 0
EXONERATE.

Support cross-check: 4 candidates already actioned by Support before sweep (Kacumi, poink,
A-J-Rimmer-BSC, nowa_zajawka). Trial confirmed BAN for all 4 at confidence 9-10/10. Not
re-banned.

Bans applied: 17 (12 NEW × 2W → 2026-07-06, 5 REPEAT × 4W → 2026-07-20) across Steam 7, PS 8,
Xbox 2.

Verification: 3-layer clean on all three platforms, zero incidents this cycle.

Handoff: `cs-report-2026-06-21.md` + 3 TSVs (9/15/2 rows) to shared sheet; Slack to CS lead in
conversational register; JIRA comment 125330 in impersonal register; KB git commit `fe13c4c`
(37 files, amended with post-ban TSV refresh).

Methodology refinement caught: net-positive PCR alone doesn't defeat bracket-farming hypothesis
(Kacumi case — week-6 WATCH became Support-banned, week-7 trajectory confirmed the signature
was always real).

## File references for hand-off

This document is the entry point. Concrete recent examples for every step are in:

- `artifacts/week3-cs-report.sql` — detection query
- `artifacts/bans-2026-07-12.sql` — most recent ban execution
- `artifacts/bans-2026-07-12.md` — most recent execution record with full trial verdicts + refinements ledger
- `artifacts/ban-log-backfill-2026-07-12.js` — Mongo banLog backfill
- `artifacts/verify-bans-2026-07-12.sql` — 3-layer verify
- `artifacts/leaderboard-ban-sync.sql` — LB sync (shared, not date-specific)
- `artifacts/monthly-lb-ban-june-2026.sql` + `-verify.sql` — one-shot LB back-fill scripts (kept for future cycles when Steam patch actually unbans on Profile expiry; the June run was a no-op)
- `artifacts/cs-report-2026-06-21.md` — most recent CS handoff narrative
- `artifacts/cs-report-2026-06-21-{steam,ps,xb}.tsv` — most recent TSVs
- `artifacts/pcr-trajectory-queries-2026-06-21.js` — consolidated trajectory query
- `artifacts/pcr-log-trajectories-2026-06-21/<26 .md cards>` — distilled trajectory cards

Memory rules accessed via `<memory>/MEMORY.md` SQL Conventions / VCS / JIRA sections:

- `feedback_competitions_banned_semantic.md` — IsCompetitionsBanned semantic + SQL gotcha
- `feedback_slack_cs_register.md` — Slack CS register rules
- `feedback_jira_impersonal_register.md` — JIRA passive voice rule
- `feedback_jira_post_preview.md` — paste final text inline before posting
- `feedback_heredoc_backticks.md` — single-quoted heredoc backtick literal
- `feedback_post_ban_tsv_amend.md` — amend ban-pack for post-ban TSV refresh
- `feedback_sql_nolock_session.md` — WITH (NOLOCK) on every read in this task

Journal `<task>/journal.md` is append-only and carries the cycle-by-cycle history.
`<task>/backlog.md` tracks deferred items.

## Deferred architectural refinements (post-Codex, not yet implemented)

Documented for future work. Each item is a real improvement identified in the Codex
consultation post-week-10; not blocking for the weekly cycle but worth acting on.

- **Two-phase blind→informed verdict.** Split the judge into two calls: (1) blind pattern
  verdict reading only the trajectory card (no status, no watchlist history, no Support
  action) — output one of `NOOBS-farm / non-target sandbagging / novice-uncertain / insufficient`;
  (2) informed duration/escalation decision reading blind verdict + pre-trial context (status,
  Support action, watchlist holdover, recidivism). Reduces the correlated-reasoning bias where
  the current single-phase judge sees Support-pre-actioned status in the context field before
  rendering its BAN/WATCH call, undermining the alignment counter's independence. Implementation:
  modify the workflow script in `.claude/…/workflows/scripts/fp43631-*-adversarial-review-*.js`
  to add a blind-pattern agent before the judge.
- **ZeroScore column as second detection path.** The current gate treats `IsStarted=1 AND
  Score=0` (zero-score) as a legitimate play. A farmer who starts a comp and immediately
  disconnects/idles achieves the same NOOBS-drain outcome as a no-show without triggering the
  `IsStarted=0` signature. `week3-cs-report.sql` already emits `ZeroScore` per candidate; add
  a second-path detection query `zero-score-abuse.sql` that gates on `ZeroScore >= 6` AND
  `NoShowSharePct < 30` (i.e. the population no-show gate misses) AND `TotalPrizes > 3`. Run
  alongside the no-show gate; merge cohorts for the trial.
- **Blind falsification test.** The alignment counter is a sanity check, not validation
  (Codex critique). A real falsification would replay 1-2 prior weeks blind: strip Support
  pre-action flags, watchlist history, and prior verdict labels from the pre-trial context;
  add non-cohort negatives (Support-Competition-banned players NOT in the wide cohort;
  cheat-vector bans; random high-no-show players with 0 prizes). Score blind verdict against
  later observed persistence, leaderboard extraction, and independent Support action. Not
  worth doing weekly, but a good end-of-quarter check.
- **Rule 8 numerical persistence formalized above** (concrete thresholds added in-line at rule
  8). This item retained as a followup for tightening the thresholds after more validation
  cycles.
- **Persistent high-PCR sandbagger auto-close** (rule 7 direction 2 above): once formalized,
  add a "3-cycle sandbagger" auto-close bookkeeping check to the sample triage step (Step 2)
  so operators don't manually re-list VM_Vigor / Panonski_Alas indefinitely.
