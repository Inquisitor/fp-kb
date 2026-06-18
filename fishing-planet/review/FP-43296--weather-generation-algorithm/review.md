---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16023, r16025
jira: https://fishingplanet.atlassian.net/browse/FP-43296
---

# FP-43296: FTUE. New Tutorial. Server - Weather generation algorithm for every day

## Summary

Rework of the per-waterway weather generation so that the weather distribution
respects the `PondWeatherSettings.Probability` values **within each week / month**,
not only across the full 6-month horizon. Also enforces the rule: if the same base
weather occurs 2 days in a row (by base seed), the 3rd day must be a different weather.

Executor reports a substantial refactor:
- new `WeatherGenerationService` orchestrating generation
- `WeatherBuilder` cleaned up, generation moved to a state-based flow
- continuation seed initialization from historical weather
- separated full regenerate / single-waterway regenerate / continuation generation
- historical weather preserved; only future weather deleted on explicit regenerate
- variant selection via shuffled bags
- many tuning params moved to global variables
- admin-side: date filtering added on the weather admin model (DB query still pulls full dataset)

## Scope

- **MFT r16023** — Refactor generation pipeline, seeded continuation, weather gen params to global variables
  - New `WeatherGenerationService` (Continue / RegenerateAll / RegeneratePond)
  - `WeatherBuilder` rewritten: base-weather buckets, shuffled variant bags, max-streak rule, smoothing + cumulative/gap correction
  - New DAL: `GetGenerationPeriods`, `GetRecentWeatherSeedByPond`, `GetMaxFutureWeatherDate`, `DeleteFutureWeather`, `SaveGenerated`
  - SQL patch `MFT.M.2026.04.22-009` — 8 `WeatherGen*` global variables
  - Renamed `SharedLib/Travel` -> `SharedLib/Weather` (svn copy, history preserved)
  - WebAdmin: admin weather grid filtered to `Date >= today`; old DELETE-ALL regenerate replaced
- **MFT r16025** — Build fix: moved randomization logic from WebAdmin `RandomizeWeatherModel` to shared `WeatherRandomizationService` (behavior-preserving move, verified)
- **MFT r16033** — "Removed debug logic from WeatherInfoController" (**untagged**, not posted to JIRA; removes a `static int i; ++i % 2` toggle introduced in r16023)

Audited via `svn log | grep` + per-file history. No other FP-43296 commits.
WC at r16168 (fresh, > reviewed revs); Weather folder untouched after r16025 — disk == reviewed state.

## Release context

Release is tomorrow. Task ships in this release. QA played the build — no blockers reported.
A crit that seriously breaks something → roll back the task. Minor bugs are acceptable.
Branch-copy inheritance: NPN (Code) base = MFT:16130; r16023/r16025 ≤ 16130 → already
inherited in Code via branch copy. No explicit merge to Code expected.

## Findings

### F-1: Seed history window counted in rows, not days [Medium]

**Description:** `SqlWeatherProvider.GetRecentWeatherSeedByPond` selects `ROW_NUMBER() ... WHERE rn <= @DaysCount`. The `Weather` table stores 8 rows per day (one per `TimeOfDay`, all sharing the day's pattern `Name`). So `WeatherGenSeedHistoryDays`=60 fetches ~7.5 days, and the `WeatherGenRecentHistoryDays`=9 recent window (`InitializeStateFromSeed`) gets ~1 day. The seeded `CurrentBaseWeatherStreak` is inflated to >=8 (the last seed day is 8 identical rows). In daily-continuation mode (`WeatherGenerationJob` appends 1 day/night and re-seeds each run) this forces every newly appended day to differ from the previous one (max 1 consecutive vs the spec's allowed 2).

**Investigation:** Read the SQL (rows-not-days confirmed); traced `InitializeStateFromSeed` streak/recent computation; confirmed bulk `RegenerateAll` tracks streak/recent correctly in DAY units via `UpdateGenerationState` (1 enqueue/day), so the 6-month bulk distribution — the primary deliverable — is correct. Independently confirmed by code-reviewer agent (verdict: confirmed, moderate, non-blocking).

**Resolution:** `Filed → FP-44564` (Bug, Low). Fix: select DISTINCT dates / `daysCount * <TimeOfDay count>`. Not blocking — affects only the daily-appended tail at the 6-month horizon; the headline "max 2 consecutive" rule is still enforced live, and bulk generation respects per-week probabilities.

**Discovered by:** skill recon, confirmed by code-reviewer agent.

### F-2: `GeneratedDaysCount` not seeded while counts are [Low]

**Description:** `InitializeStateFromSeed` populates `GeneratedBaseWeatherCounts` from the seed window but leaves `GeneratedDaysCount`=0. In `GetCumulativeCorrectionFactor`, `actualShare = actualCount / generatedDaysCount` mixes seeded numerator with non-seeded denominator.

**Investigation:** Bounded the result: with shipped defaults (factor 0.05, seed <=60 rows, `MinHistoryDays`=30 guard) `actualShare <= 3`, so the multiplier stays in ~[0.85, 1.15] — never zero/negative, no divide-by-zero (guard returns 1.0 while `generatedDaysCount < 30`). Agent confirmed: guard neutralizes it; mild bias only.

**Resolution:** `Accepted` — bounded, sub-5% effect; cosmetic.

### F-3: Static `Random` in static `WeatherBuilder` not thread-safe [Low]

**Description:** `private static readonly Random rnd` shared across all `Generate` calls. `System.Random` is not thread-safe; concurrent use can yield a degenerate (all-zero) sequence.

**Investigation:** `WeatherGenerationJob` is a single daily scheduled job (3:00, single-threaded scheduler) → no self-overlap. Only exposure is an admin `RegenerateAll` (IIS thread) firing concurrently with the 3 AM job — narrow window.

**Resolution:** `Accepted` (note for follow-up: `lock` or instance `Random`). Not blocking.

### F-4: `RegenerateAll` delete+insert not transactional; `SaveGenerated` not idempotent [Low]

**Description:** `RegenerateAll` does `DeleteFutureWeather(today)` then plain `INSERT`s with no surrounding transaction and no `IF NOT EXISTS`. A concurrent admin regenerate + daily job could duplicate rows (or throw on a unique index, if one exists).

**Investigation:** Single-run `ContinueGeneration` is safe — `GetGenerationPeriods` starts at `MAX(futureDate)+1`, no overlap, steady-state = 1 day/run. Duplicate path requires the rare admin+job race.

**Resolution:** `Pre-existing`-class risk (old admin path also non-transactional, did DELETE-ALL). Not blocking.

### F-5: `CheckWeather` throws on `WindDirection == "None"` — refuted as regression [Info]

**Description:** Agent raised `ValidateSelectedPattern`/`CheckWeather` throwing `InvalidOperationException` on `WindDirection == "None"` as a potential release blocker.

**Investigation:** Read old `Travel/WeatherBuilder.cs` @ r16022 — the identical `CheckWeather` with the same `|| weather.WindDirection == "None"` throw and the same 8 per-pattern calls existed pre-refactor. Behavior is byte-for-byte carried over; r16025 randomization is a verified behavior-preserving move (no new "None" in data). Therefore not a regression of FP-43296 — if prod data contained "None", generation would already have been failing.

**Resolution:** `Skipped` — pre-existing, unchanged; not introduced by this task.

## Empirical validation on [F2P] QA (read-only)

- **Config health:** all 31 rows in `PondWeatherSettings` have non-null/non-empty `RandomizedWeatherJson` + `BaseWeatherJson` → the "one misconfigured pond aborts the whole nightly run" landmine is NOT present. `GlobalVariables` `WeatherGen*` = shipped defaults (`WeatherGenMaxConsecutiveDays`=2); patch `MFT.M.2026.04.22-009` applied.
- **Coverage:** every pond has full 184 future days (today → +6mo) + 50 preserved past days. Historical-weather preservation works; new Lone Star has weather.
- **Rule validation (gaps-and-islands on base weather):**
  - Daily-appended FAR tail (d154-184) across all multi-base ponds: **MaxRun=2, 0 violations** — the new algorithm enforces "max 2 consecutive" correctly. Runs are overwhelmingly length-1 (888 vs 6 length-2) → **F-1 empirically confirmed** (daily continuation over-varies; harmless).
  - NEAR body (d0-30) of EXISTING ponds: MaxRun=7, 61 violations of the rule → this region is **old-algorithm data** (generated before the fix took effect; daily job only rewrites the tail, never the body). Pre-existing; not introduced by FP-43296.
- **Lone Star (`USA_TX_LoneStar`):** two ponds share the asset. **PondId 119** (active/visible, public): 3 bases, **MaxRun=2, 0 violations in both near and far windows — fully new-algo, fully compliant.** **PondId 2** (inactive/invisible, `<100` so excluded from randomization): a disabled test/system pond reusing the asset; single base weather → continuous run, not player-visible. Irrelevant to gameplay.

**Conclusion:** new algorithm is correct (verified on live data); the release's target pond (Lone Star 119) already carries compliant new-algo weather. Other existing ponds' near-term weather is stale old-algo — a one-time `RegenerateAll` post-deploy would refresh them, but it is not required for this release's deliverable.

## Verdict — APPROVE (resolved)

**APPROVED for release.** No release-blocking crit found. The player-facing daily path (job → `ContinueGeneration` → `WeatherBuilder.Generate` → `SaveGenerated` → `WeatherCache`) does not crash, corrupt, or wipe data in normal operation; the primary deliverable (per-week probability distribution + max-2-consecutive rule via bulk `RegenerateAll`) is implemented correctly and verified on live QA data, including the release's target pond (public Lone Star 119). Independent code-reviewer agent concurred.

- **Cross-branch merge:** none needed. Source = MFT (Content); only upward target = Code (NPN20260602 @ base MFT:16130). All commits (r16023/r16025/r16033 ≤ 16130) are inherited via branch copy — verified by `svn log` on `WeatherGenerationService.cs` in NPN (shows r16023). No `Merged →` claim posted.
- **Follow-up:** F-1 filed as **FP-44564** (Bug, Low; daily continuation over-varies — seed window counted in rows not days), linked Relates to FP-43296.
- **JIRA:** LGTM comment posted (id 125070).
- **Operational note (handed off in JIRA):** existing ponds keep old-algorithm near-term weather until a post-deploy `RegenerateAll`; the new Lone Star pond is already regenerated.

## Investigation Journal

- Intake from JIRA FP-43296. Executor field (customfield_11224) empty; executor identified
  as Yevhenii Shust from commit-author comment id:115967.
- Confluence design doc linked: "New weather generation algorithm" (page 5530222593).
- r16033 found via per-file history (untagged, `svn log | grep FP-43296` missed it) — executor commits follow-ups without the JIRA tag; widened sweep over all weather paths r16023:HEAD to confirm scope is exactly r16023/r16025/r16033.
- Code-reviewer agent spawned (independent). Its strongest concern (F-5 CheckWeather/"None") refuted by reading old `WeatherBuilder` @ r16022 — pre-existing identical validation, not a regression. F-1/F-2/thread-safety confirmed non-blocking.
