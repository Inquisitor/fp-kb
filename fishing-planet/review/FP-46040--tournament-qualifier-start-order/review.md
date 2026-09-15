---
status: resolved
executor: Yuriy Burda
branch: NPN20260602 @ r16495, merged to MFT20260325 @ r16545
jira: https://fishingplanet.atlassian.net/browse/FP-46040
---

# Review: FP-46040 — [Competitions][Gars&Glory] Incorrect order of the tournament qualifiers starts

## Summary

QA reported on TEST that the Gars&Glory tournament qualifiers start in the wrong order: the first
qualifier starts last. Expected order is qualifier 1, then 2, then 3.

The serie is laid out by the WebAdmin "Create Test Tournament" tool, which walks the serie's
templates and hands each one the next time slot. It took them in whatever order
`GetTournamentTemplatesBySerie` returned, and that query orders by `StageTypeId` alone — so the
three qualifiers, all `StageTypeId = 1`, had no order at all.

r16495 sorts the stages before laying them out, using the schedule the production tournament
generator itself would apply, and adds unit tests for the new comparer.

## Scope

- **NPN20260602 r16495** — Create test tournament stages in the order the tournament generator schedules them.
  - `CreateTestTournament()` now runs its stages through a new `OrderStagesByScheduledStart()`:
    `StageTypeId` (nulls last), then the stage's scheduled start, then `TemplateId`
  - `GetScheduledStart()` projects a template's schedule onto the current calendar year (anchored at
    1 January) by reusing the generator's own day enumeration, `DateTime.MaxValue` for a schedule it
    cannot read
  - Extracted `GenerateStartDays()` / `GetStartDate()` / `IsSportTournament()` out of
    `GenerateByTemplate()` so the ordering can reuse them
  - Renamed `TournmanetGenData` -> `TournamentGenData`; fixed "teplate", "futher", "pons",
    `tournamenKindId` typos
  - New `SharedLib.Tests/Tournaments/TournamentSchedulingAdapterTests.cs`: 8 active tests, 2
    `[Ignore]`d ones documenting known limitations
- **MFT20260325 r16545** — Merge of r16495, user-directed downward cherry-pick
  - Conflicted against FP-43758 (MFT r16134), which had independently renamed the same identifiers;
    resolved as a union, see the Investigation Journal

## Investigation Journal

- Intake took the commit list from the JIRA comment at face value; the VCS audit then confirmed
  r16495 is the only FP-46040 commit on NPN20260602 and that nothing cites it afterwards (no revert
  or follow-up). Nothing on MFT20260325.
- Working copy was at r16477, behind the reviewed r16495 — the diff and the post-fix source were
  read via `svn diff -c 16495` / `svn cat -r 16495`, not from disk. WC later updated to r16497 with
  the user's approval, for the test run only.
- **Root cause verified against data, not inferred.** `GetTournamentTemplatesBySerie`
  (`Dal/Sql.MsSql/Tournaments/SqlTournamentProvider.cs`) ends with `ORDER BY StageTypeId` and no
  tiebreak. Query on the local dev-copy `Main` for SerieId 12 (Gars&Glory Cup) returns five stages,
  all in October: templates 276 (Oct 7), 277 (Oct 8), 11892 (Oct 6) as qualifiers, 278 SemiFinal
  (Oct 10), 279 Final (Oct 11). Qualifier 1 is template **11892** — re-authored long after 276/277,
  so it carries the highest id and took the **last** qualifier slot. That is exactly the reported
  symptom. Under the new comparer it takes slot 1.
  Cross-checked against the source document rather than the database alone: the designer's 2026
  calendar puts Gars & Glory Cup registration on 5 October and its three qualifiers on the 6th, 7th
  and 8th, semi-final 10th, final 11th — matching the stored templates to the day, and confirming
  that the intended first qualifier is the 6 October stage, i.e. template 11892.
  Scope caveat: the local `Main` is one branch's dev copy, not the TEST snapshot QA used; it binds
  to the current content, and new content can change exposure without any code change.
- **Content-exposure sweep** over the whole serie-stage population (88 stages / 19 series, single
  aggregate row; control marker `SerieId = 12` present and non-zero, so the probe sees the reported
  serie). An earlier grouped form of this query was silently truncated at 10 rows and had missed
  Gars&Glory entirely — the totals below come from the untruncated aggregate.
  - 2 of 18 yearly series are affected by the defect: Gars&Glory Cup and Independence Trout Open
    (templates 171/172/173 = Jul 30 / Jul 1 / Jul 2 — same author-order-vs-schedule inversion).
  - `StageTypeId IS NULL`: 0 stages. `ScheduleType` = W/D/M: 0 stages (87 yearly, 1 unusable `'-'`).
  - Series spanning the year edge: 0; every serie's stages sit in a single month.
  - All 88 stages are `KindId = 1` (Sport).
  These zeros make the three latent gaps below latent in fact, not just in theory.
- **Both `[Ignore]` justifications checked, not taken on trust.**
  - Weekly: `thisWeekStart = firstDay.AddDays(1 - (int)firstDay.DayOfWeek)`. For 2026 (1 Jan =
    Thursday) it lands on 29 Dec 2025, `DaysOfWeek="5"` yields 2 Jan and `DaysOfWeek="2"` falls
    before 1 Jan and is pushed to 6 Jan — the test's expected order inverts. For 2028 (1 Jan =
    Saturday) it would pass. The stated "rotates with the weekday 1 January lands on" is correct.
  - Year edge: `GetTournamentSeriesBasicInfo` ranks a stage by `Month*44640 + Day*1440 + ...`, so a
    January stage always ranks below a December one and becomes `InitialTemplateId`.
    `AssignSerieInstanceIds` only starts collecting at that template, so on a September-dated run a
    Dec/Jan serie never reaches `StagesCount`, `SerieInstanceId` stays null, and
    `ScheduleTournements` skips creation
    (`if (tournamentDto.SerieId != null && tournamentDto.SerieInstanceId == null) continue;`).
    **Hypothesis disproven in part:** this trace was run for a September date and generalised to
    "no instance is ever created", which is what the executor's `[Ignore]` also claims. Codex
    checked a January-dated run and broke the generalisation — see F-1. The outcome is run-date
    dependent, and on 1-2 January an instance *is* created, spanning ~12 months.
- **Considered and rejected — NULL `StageTypeId` ordering flip.** Both delegates raised it
  independently: SQL Server's `ORDER BY StageTypeId` sorts NULLs first, the new
  `OrderBy(t => t.StageTypeId ?? int.MaxValue)` sorts them last, so an untyped stage moves from the
  first test slot to the last. Rejected on two independent grounds. Data: the aggregate over all 88
  serie stages returns 0 rows with a NULL `StageTypeId`. Code: `TournamentEndAdapter`
  `ManageTournamentSerieStages` short-circuits on `tournament.StageTypeId == null` and logs
  "is not a tournament, finding next stage skipped", so serie progression never advances past such a
  stage regardless of where it sits in the layout. Not a defect.
- **Refactor equivalence** checked branch by branch against the pre-fix source. The kept-instance
  predicate `isSport || StartDate > now` became `if (!isSport && startDate <= now) continue;` in the
  caller — same set. `d`/`generationEndDate` map to `firstDay`/`lastDay` with identical arithmetic in
  all four `ScheduleType` branches. The original sampled `DateTime.UtcNow` twice (once for `.Date`,
  once for the comparison), the new code samples once and derives both, which removes a midnight
  straddle rather than adding one. Both callers checked: `ScheduleTournements` re-filters on
  `StartDate > now` itself, `ScheduleCompetitions` does not — so the moved predicate is load-bearing
  for competitions and is preserved there.
- **Hypothesis disproven — how much of `GenerateStartDays` is live.** A `ScheduleType` x `KindId`
  census showed 132 daily Competition templates against 87 yearly Sport ones, and the recon
  concluded the daily branch was the busier path. Tracing the callers refuted it: the nightly
  `CompetitionSchedulingJob` calls `RandomizeCompetitions`, which walks its own two-hour-slot
  timeline and never enters `GenerateStartDays`. The only caller that does reach the daily branch is
  `ScheduleCompetitions`, and its sole call site is one manual WebAdmin button. So the only branch
  running automatically is `"Y"`; `"D"` is a manual alternative mode and `"W"`/`"M"` have no
  templates at all. This narrows the blast radius of the refactor rather than widening it, and the
  corrected picture is written up in
  [content calendar](../../server/modules/tournaments/content-calendar.md).
- **Executable evidence.** `SharedLib.Tests` builds clean at r16497 (only pre-existing
  `LocalPriceCalculator` obsolete warnings). `dotnet test --filter
  FullyQualifiedName~TournamentSchedulingAdapterTests`: **8 passed, 2 skipped, 0 failed**.
- Step 6 cross-repo client mirror: not triggered. The diff touches `Shared/SharedLib` and
  `Shared/SharedLib.Tests` only — not `Shared/ObjectModel` — and changes no user-facing option set.
- Step 5 branch-copy inheritance: NPN20260602 was copied from MFT20260325:16130, so r16495 is not
  inherited anywhere. Merged down to MFT at the reviewer's direction — the role table produces no
  targets for a Code-branch source, and the Fix Version is a rolling sprint bug bucket
  (renamed in place from "17 August - 31 August" to "31 August - 14 September" between intake and
  close), so it names no release and the target could not be derived. MFT was confirmed to carry the
  defect by content, not by task grep: its HEAD still had the pre-fix
  `GetTournamentTemplatesBySerie(serieId, ...).ToList()` loop and no `OrderStagesByScheduledStart`.
- **The merge conflicted, and the conflict list understated the work.** Five text conflicts, all
  from FP-43758 (MFT r16134) having independently renamed the same identifiers — it had already
  fixed `TournmanetGenData` -> `TournamentGenData` and additionally renamed the `Action<string>`
  parameter `logFailure` -> `warnLogger`. Resolution is not uniform: block 1
  (`AssignSerieInstanceIds` signature) takes MFT's `warnLogger`, because that method's body calls
  `warnLogger`; blocks 2-5 take r16495's `logFailure` plus the "template" typo fix, because r16495
  moves those lines into the new `GenerateStartDays`, whose own parameter is `logFailure`.
  Critically, a sixth site needed a hand fix that SVN never flagged: r16495's new call
  `GenerateStartDays(template, logFailure, now)` applied cleanly inside `GenerateByTemplate`, whose
  MFT parameter is `warnLogger` — so `logFailure` was not in scope and the file would not compile.
  New text with no counterpart on the target side does not raise a conflict, so resolving only the
  marked blocks would have committed a broken build. Verified by building `SharedLib.Tests` on MFT
  (exit 0) and rerunning the tests there: 8 passed, 2 skipped, 0 failed.
- Merge commit scoped explicitly (`<two paths> . --depth empty`) rather than at the WC root: the
  shared MFT working copy carried another task's eight modifications plus a scheduled add, which a
  root commit would have swept into the merge. Verified after commit that r16545 contains only the
  root mergeinfo, the adapter and the new test, and that those local changes remain uncommitted.
- **Delegation outcome.** The `code-reviewer` agent returned no defects at its confidence bar and
  independently reproduced the refactor-equivalence trace and both `[Ignore]` checks; Codex returned
  six items plus two test defects. The two do not contradict each other — the agent's bar filtered
  out everything that needed content evidence to bound. Every Codex item was re-verified here before
  acceptance: one rejected outright (NULL `StageTypeId`, above), the rest confirmed but bounded to
  latency by the content sweep. No defect introduced by r16495 was found by any of the three passes.

## Findings

### F-1: The year-edge `[Ignore]` justification states a generator mechanism that holds only on some run dates [Info]

**Description:** The `[Ignore]` reason on `OrderStagesByScheduledStart_orders_qualifiers_that_span_the_year_edge`
tells the next implementer that for a serie spanning the year edge the generator "never completes a
run, and no instance is created at all". That is the outcome on most run dates but not all: on a run
in the first days of January the generator does complete and creates an instance whose stages sit
roughly twelve months apart.

**Investigation:**
- Read the `[Ignore]` text and its test in the file added by r16495 (`svn cat -r 16495`) — the claim
  carries no run-date qualifier.
- Traced `AssignSerieInstanceIds` (post-fix source at r16495) against a two-stage serie of 3 January
  and 28 December, stepping the `serieContent` accumulation for both stream orders. December-first:
  the January stage is `InitialTemplateId`, arrives second, `serieContent` stops at 1 of
  `StagesCount` 2, `SerieInstanceId` stays null, creation is skipped — the documented outcome.
  January-first: the January stage is added, the December stage then passes both
  `serieContent.Any(...)` guards and is added, `serieContent.Count == StagesCount`, an instance is
  assigned.
- Established which run dates produce the January-first stream from the "Y" branch of
  `GenerateStartDays`: `new DateTime(firstDay.Year, Month, day)` rolls a passed date into the next
  year, so 3 January precedes 28 December only for a run on 1-2 January (and again on 29-31
  December). `TournamentSchedulingJob` is `JobFrequancy.Daily` at 00:01, so the 1 January run happens
  every year.
- Severity bounded by content: the serie-stage aggregate returns 0 series with stages in both
  December and January, and `MAX(MonthSpan) = 0` — every serie sits inside one month.
- Severity bounded further by authoring practice, which is the stronger bound because it shows
  intent rather than a snapshot. The tournament designer's calendars for 2024, 2025 and 2026 close
  the December serie before Christmas (final on the 21st-22nd, 20th-21st and 19th-20th
  respectively) and open the January serie after the New Year holidays (registration on the 15th,
  13th and 12th), filling the three-week gap with Events rather than serie stages. Written up in
  [content calendar](../../server/modules/tournaments/content-calendar.md).

**Resolution:** Accepted — recorded here rather than returned to the executor. The comment guides a
follow-up for a case the authoring practice excludes, so the round-trip does not pay for itself; the
accurate mechanism is now on record both here and in the module backlog. The underlying generator
defect is filed at
[tournaments backlog](../../server/modules/tournaments/backlog.md).

**Discovered by:** Codex (corrected skill recon, which had verified the executor's claim from a
September-dated trace and generalised it).

### F-2: Two tests assert opposite orders for structurally identical input [Info]

**Description:** The active `OrderStagesByScheduledStart_orders_stages_by_their_place_in_the_year_not_by_the_next_occurrence`
supplies a December and a January yearly Qualification stage and asserts January first. The
`[Ignore]`d `OrderStagesByScheduledStart_orders_qualifiers_that_span_the_year_edge` supplies a
January and a December yearly Qualification stage and asserts December first. Nothing in
`TournamentTemplateDto` distinguishes "two independent stages" from "one serie that wraps the year",
so the comparer cannot satisfy both. The suite encodes a contradiction: fixing the year-edge case
forces deleting or rewriting a currently-green test, and the green test will read as a regression
when that happens.

**Investigation:**
- Compared the two test bodies in the file added by r16495: stage factories, `StageTypeId`
  (`Qualification` by default in both), `ScheduleType` (`"Y"` in both), and the asserted orders.
  The only difference is which month carries the lower `TemplateId`, which the comparer consults
  only as the last tie-break and which does not fire here because the projected dates differ.
- Confirmed the active test is not redundant: its name targets the anchor choice, and anchoring at
  today instead of 1 January would flip it — so it does guard a real design decision while
  simultaneously locking in the ordering the ignored test calls wrong.

**Resolution:** Accepted — recorded here rather than returned to the executor, on the same
arithmetic as F-1: the collision only materialises if someone implements year-edge support, which
the authoring practice makes unlikely. Noted for whoever does: the cheapest fix is not deleting the
active test but a line in it saying its input is also the unsupported year-edge shape, so the
expectation flips if that case is ever supported.

There is a fair counter-argument for the executor, recorded because it is the reason this stays
Info rather than a defect: the two tests are aimed at different properties. The active one pins the
*anchor choice* — anchoring at today instead of 1 January would project a January stage into next
year and flip it against a December one — and December/January data is the only shape that
distinguishes the two anchors. The `[Ignore]`d one pins a *missing capability*. They collide only
because a test fixes behaviour, not intent.

**Discovered by:** Codex.

### F-3: `..._puts_a_stage_whose_schedule_cannot_be_parsed_last` exercises no parse failure [Info]

**Description:** The test sets `Month = 2` and `DaysOfMonth = "31"`. `int.TryParse("31")` succeeds,
so the `FormatException` path the test is named for is never taken; the stage lands last because
`new DateTime(year, 2, 31)` throws `ArgumentOutOfRangeException` further down. The name misdescribes
what is covered, and no active test reaches the `FormatException` arm of the catch filter that a
non-numeric `DaysOfMonth`/`DaysOfWeek` would trigger.

**Investigation:**
- Read the test body and `GenerateStartDays`'s "Y" branch at r16495: the branch runs
  `int.TryParse(template.DaysOfMonth, out dayOfMonth)` and only `logFailure`s + `yield break`s on
  failure — it never throws `FormatException` for a yearly stage at all. The `FormatException` sites
  are the `int.Parse` calls in the weekly and monthly branches, which the test never reaches.
- Checked the remaining seven active tests for a non-numeric schedule field: none supply one.
- Mapped the catch filter's three arms onto their reachable throw sites:
  `ArgumentOutOfRangeException` from the "Y" `new DateTime` and the "M" `AddDays`, covered by this
  test; `FormatException` from the `int.Parse` calls in the "W" and "M" branches, uncovered;
  `OverflowException` from the "M" `int.Parse`, uncovered. The sibling
  `..._puts_a_stage_with_an_unusable_schedule_last` sets `ScheduleType = "X"`, falls through the
  switch and covers the empty-enumeration path via `DefaultIfEmpty`, which is not an exception path.
- Bounded the gap by which branches content reaches: a `ScheduleType` x `KindId` census of all 278
  templates returns 132 daily (Competition, 103 active), 87 yearly (Sport, all of them the serie
  stages), 58 user-generated with a blank or "-" type, and **0 weekly, 0 monthly**. The two
  uncovered arms are therefore reachable only from branches no template uses. See
  [content calendar](../../server/modules/tournaments/content-calendar.md).

**Resolution:** Accepted — the untested `FormatException` and `OverflowException` arms are reachable
only from the weekly and monthly branches, which carry zero templates, so adding coverage would pin
dead code. The name remains inaccurate and is recorded here rather than returned to the executor.

**Discovered by:** Codex.

### F-4: One template with an impossible Month/Day aborts the entire nightly generation run [Low]

**Description:** In the "Y" branch of `GenerateStartDays`, `new DateTime(firstDay.Year, Month.Value,
dayOfMonth)` is unguarded on the production path `GenerateByTemplate` -> `ScheduleTournements`. A
template whose month/day pair cannot form a date in the current year — 29 February outside a leap
year is the reachable case — throws `ArgumentOutOfRangeException` out of the iterator.
`TournamentSchedulingJob.DoExecute` catches at the top of the job, so the exception does not crash
the process but does abandon the rest of that night's templates, logged as a single error. r16495
added exactly this guard for the ordering path in `GetScheduledStart` and left the production path
as it was.

**Investigation:**
- Read `TournamentSchedulingJob.DoExecute`: a single `try`/`catch (Exception ex)` wraps the whole
  `ScheduleTournements` call, so the failure granularity is the run, not the template.
- Confirmed pre-existing, not introduced: the pre-fix source in the r16495 diff carries the identical
  construct (`var nDate = new DateTime(d.Year, template.Month.Value, day);`).
- Exposure query over all 87 yearly templates: 0 with `Month = 2 AND DaysOfMonth = 29`, 0 with any
  day outside 1-31, 0 with a day exceeding its month's length, 0 with a NULL or out-of-range month.
  A second query over all 278 templates returns 0 weekly and 0 monthly templates, so the
  `AddDays`-normalisation variant of the same gap is unreachable too. Unlike F-3 the yearly branch
  itself is live — 87 templates, 60 active — so the bound here is clean data, not dead code.
- Checked whether anything keeps the data clean. In `WebAdmin/Models/Entities.cs` the schedule
  fields are declared `String ScheduleType`, `String DaysOfWeek`, `String DaysOfMonth` with no
  `UIHint`, `[Range]` or `[RegularExpression]`, and `Month` as a bare `Int32?`. Nothing rejects
  month 2 day 30 on save.
- Checked the diagnostic that should catch it: `TournamentTemplateBreaksModel` is the admin page
  reporting broken templates (missing pond weather, start/end not on one in-game day, inconsistent
  registration dates within a serie). It computes
  `new DateTime(2019, t.Month.Value, int.Parse(t.DaysOfMonth))` over every yearly template — the
  same unguarded construction, plus an unguarded `int.Parse`, against a hardcoded non-leap year. It
  would throw on the template it exists to report, and can never handle a 29 February one.
- Operational bound, supplied by the reviewer from outside the repo: every yearly template is
  re-validated annually when the next calendar is laid out, and a dedicated game designer watches
  generation. Recorded in
  [content calendar](../../server/modules/tournaments/content-calendar.md) along with the caveat
  that the failure is partial, so the symptom is missing tournaments rather than stopped generation.

**Resolution:** Pre-existing -> [tournaments backlog](../../server/modules/tournaments/backlog.md),
citing this review. Kept at Low rather than Info, unlike F-1 to F-3: those are bounded by design
intent, this one by data that happens to be clean plus human process, with no validation behind it.
No JIRA — the operational controls make it a cleanup, not a scheduled fix.

The adjacent `StagesCount` gap found while tracing this one is filed in the same backlog:
`GetTournamentSeriesBasicInfo` counts a serie's stages with no `IsActive` filter while
`ScheduleTournements` streams only active ones, so a serie mixing the two never completes and
silently produces nothing. Currently 13 series fully active, 6 fully inactive, none mixed.

**Discovered by:** code-reviewer agent (leap-day hypothesis) and Codex independently; the
run-abandonment consequence established by skill recon.

### F-5: `GetScheduledStart` inherits the kind-dependent generation horizon [Info]

**Description:** `GenerateStartDays` picks `GenerationHorizonCompetitions = 7` days whenever
`IsSportTournament` is false. `GetScheduledStart` anchors that enumeration at 1 January, so for a
non-Sport serie stage the ranking window is 1-8 January: any such stage scheduled later in the year
yields no days, falls to `DateTime.MaxValue`, and the ordering degenerates to `TemplateId` — the
behaviour the fix exists to replace. The horizon switch is the wrong knob here because the method is
ranking a stage inside a year, not generating instances.

**Investigation:**
- Read `GenerateStartDays`'s horizon selection and `GetScheduledStart`'s anchor at r16495.
- Exposure query: all 88 serie stages carry `KindId = 1`, and `TournamentKinds.Sport = 1`, so no
  non-Sport stage currently belongs to a serie. `GetTournamentTemplatesBySerie` filters on `SerieId`
  only and would admit one.
- Bounded by design rather than by the snapshot: the two kinds are different content shapes —
  Sport is a monthly multi-stage tournament serie, Competition is a continuous chain of two-hour
  slots twelve a day, with no stages and none planned. The census agrees: 0 of the 132 Competition
  templates carries a `SerieId`. Reaching this code therefore requires giving a competition a
  `SerieId`, which would be a data error rather than a configuration. Written up in
  [content calendar](../../server/modules/tournaments/content-calendar.md).

**Resolution:** Accepted. The precondition is excluded by the content model, not merely absent from
current data. If the method is ever touched, pass an explicit full-year horizon rather than
inheriting the kind switch — it ranks a stage inside a year, so the generation horizon is the wrong
knob for it either way.

**Discovered by:** skill recon.

### F-6: `GetScheduledStart` re-samples the anchor year on every sort-key evaluation [Info]

**Description:** `var yearStart = new DateTime(DT.Helper.UtcNow.Year, 1, 1);` sits inside the key
selector, so `ThenBy` re-reads the clock once per element rather than fixing the anchor for the
sort. A sort straddling New Year — or a test that moves `DT.Helper.Now` mid-sort — can key some
stages to one year and others to the next, which is not an ordering the comparer's contract admits.
The weakest of the findings here: closer to code hygiene than to risk, kept because the anchor is
semantically an input to the ordering and computing it per element hides that.

**Investigation:**
- Read `OrderStagesByScheduledStart` and `GetScheduledStart` at r16495, and `Shared/DT/Helper.cs`,
  where `Now` is a mutable `static Func<DateTime>` and `UtcNow` invokes it per call.
- Bounded the evaluation count rather than assuming it: LINQ-to-Objects computes ordering keys once
  per element (`EnumerableSorter.ComputeKeys` fills a `TKey[]` in a single pass), so the selector is
  not re-entered for the same element. The inconsistency window is therefore between elements of one
  sort — microseconds for a five-stage serie — not within one.
- Checked the new test file: no test freezes or resets that clock, so the inconsistency is not
  currently observable in the suite either.

**Resolution:** Accepted. Cheap cleanup if touched: compute `yearStart` once in
`OrderStagesByScheduledStart` and pass it into `GetScheduledStart`, which also makes the anchor
explicit at the call site.

**Discovered by:** Codex.

### F-7: Two independent notions of a stage's scheduled start now coexist [Info]

**Description:** Production decides a serie's first stage with the SQL rank in
`GetTournamentSeriesBasicInfo` (`Month*44640 + Day*1440 + StartHour*60 + StartMinute`, with weekly
and monthly variants); the admin tool now decides it with `GetScheduledStart` in C#. They disagree on
inputs neither currently receives: for monthly the SQL takes the first entry of `DaysOfMonth` while
the C# takes the minimum (`"25,3"` ranks as 25 vs 3), for weekly the SQL takes only the first digit
of `DaysOfWeek`, and for 29 February the SQL ranks it between January and March while the C# sends it
last in non-leap years. A serie could therefore be laid out by the tool in an order the generator
would not reproduce.

A fourth divergence sits in the SQL `ELSE` arm: an unrecognised `ScheduleType` still yields a finite
rank (`StartHour*60 + StartMinute`), while `GenerateStartDays` falls through its switch, yields
nothing, and lands on `DateTime.MaxValue`.

**Investigation:**
- Read the `GetTournamentSeriesBasicInfo` CTE in `SqlTournamentProvider` and compared its per-branch
  expressions against `GenerateStartDays` at r16495, branch by branch.
- Checked agreement on the one branch that is live rather than assuming it. For `"Y"` the SQL rank
  is a correct lexicographic encoding of the same ordering: `44640 = 31 * 1440`, so with
  `Day` in 1..31 and the time term under 1440 the encoding stays injective and monotonic in
  (`Month`, `Day`, `StartHour`, `StartMinute`). Worked the boundary: `Month 1, Day 31, 23:59` ranks
  90719 against `Month 2, Day 1, 00:00` at 90720 — no collision. The two notions therefore produce
  the same order for every yearly stage.
- Exposure of the divergences: 0 weekly and 0 monthly templates exist at all (278 templates), no
  yearly template carries 29 February, and the only template with an unrecognised `"-"` type is the
  single-stage `_Sample Serie`, where order is meaningless.

**Resolution:** Accepted, recorded for context. The two notions agree on everything real content
produces and diverge only on inputs the content model excludes. Not proposing unification —
reworking a production ranking query the generator depends on does not pay for a divergence on
unreachable inputs.

**Discovered by:** skill recon.

## Verdict

**Approve.** Nothing blocking, nothing returned to the executor.

The fix is minimal and aimed at the actual cause rather than the symptom. `GetTournamentTemplatesBySerie`
orders by `StageTypeId` alone, so the three qualifiers of a serie had no order at all and
`CreateTestTournament` handed out its sequential slots in whatever order the query returned. Sorting
the stages by the schedule the generator itself would apply fixes that at the point where the order
is decided. The supporting refactor is not gratuitous: extracting `GenerateStartDays` is what lets
the ordering reuse the generator's own day enumeration instead of becoming a second, divergent
notion of when a stage runs — and on the one branch that is live, the existing SQL rank and the new
comparer were checked to agree (F-7).

**Verification scope.** Root cause established, not just symptom coverage: the ordering inversion
was reproduced from stored templates and cross-checked against the tournament designer's 2026
calendar, which matches the stored content to the day and confirms the intended first qualifier is
the 6 October stage, template 11892 — the highest-numbered and previously last-placed one. Behaviour
preservation of the refactor was traced branch by branch against the pre-fix source by three
independent passes (skill recon, `code-reviewer` agent, Codex), which agreed. Build is clean and the
new tests run 8 passed / 2 skipped / 0 failed at r16497.

Not verified: behaviour on the TEST environment itself. All content evidence comes from a local
dev copy of `Main`, and every severity bound below rests on the current content snapshot plus
authoring practice, neither of which is enforced by code.

**Findings.** Seven, none blocking: F-4 Low, the rest Info. Two are recorded corrections to the new
test file's own commentary (F-1, F-2), one is a test-name/coverage inaccuracy (F-3), three are
latent mechanism gaps (F-5, F-6, F-7), and F-4 is a pre-existing production gap. None was returned
to the executor: F-1 to F-3 concern a follow-up that the authoring practice makes unlikely or
branches no template uses, so the round-trip does not pay for itself.

**Filed:** two entries in [tournaments backlog](../../server/modules/tournaments/backlog.md) —
the year-edge generator defect and the unguarded date construction, plus the `StagesCount`/`IsActive`
mismatch found alongside it. Tournament domain knowledge that this review depended on and that is
not derivable from code is written up in
[content calendar](../../server/modules/tournaments/content-calendar.md).

**Merge:** merged down to MFT20260325 at r16545 on the reviewer's direction. The merged content is
not byte-identical to r16495 — five conflicts against FP-43758's independent rename were resolved as
a union, and one uncontested line needed a hand fix to compile. Build and tests green on MFT.

## Notes

- Executor field (`customfield_11224`) was empty at intake; set to `Yuriy Burda` at close.
- `customfield_11323` (Server Release Checklist Steps) left empty, correctly: the diff touches only
  `Shared/SharedLib` and a test, so the closure gate derives no options.
