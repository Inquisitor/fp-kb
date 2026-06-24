---
status: waiting-for-release
executor: Yevhenii Shust
branch: MFT @ r16226, merged to NPN @ r16233
jira: https://fishingplanet.atlassian.net/browse/FP-44564
---

# Review: FP-44564 — [Weather] Weather changes every day in daily generation instead of the allowed 2 in a row

## Summary

Follow-up bug from the FP-43296 weather-generation rework. `GetRecentWeatherSeedByPond(untilDate, daysCount)` in `Dal/Sql.MsSql/Weather/SqlWeatherProvider.cs` limited the seed window by row count (`ROW_NUMBER() ... WHERE rn <= @DaysCount`), but the `Weather` table stores 8 rows per day (one per `TimeOfDay`, sharing the day's pattern `Name`). The parameters named/intended as *days* (`WeatherGenSeedHistoryDays`=60, `WeatherGenRecentHistoryDays`=9) were applied as *rows*, collapsing the window to ~1/8 and inflating `CurrentBaseWeatherStreak` (8 identical trailing rows => streak >= 8) so the daily `WeatherGenerationJob` always forced a switch — max-1-consecutive instead of the allowed 2. Bulk `RegenerateAll` was unaffected (in-run state already in day units). Cosmetic distribution-quality issue, no crash/corruption.

Fix r16226 reworks the seed query to be date-based and adds real `WeatherBuilder` regression tests (the old test only asserted `IsNotNull`, which is why the bug slipped through).

## Scope

- **MFT r16226** — Fix count recent-weather seed window in days, not rows; cover WeatherBuilder run-mix with tests
  - `SqlWeatherProvider.GetRecentWeatherSeedByPond`: interpose `SELECT DISTINCT PondId, [Date], [Name]` before `ROW_NUMBER`, collapsing 8 rows/day to one so `@DaysCount` means days
  - `WeatherBuilder`: `rnd` from `readonly` to mutable + `internal SeedForTests(int)` test-only hook (gated by `InternalsVisibleTo("SharedLib.Tests")`)
  - `WeatherBuilderTests`: bulk max-consecutive invariant, seed-ending-in-max-run boundary test, 150-day daily-append simulation with pinned RNG; old DB-backed test tagged `[TestCategory("Database")]`

## Findings

### F-1: `rnd` changed from `readonly` static to mutable static for a test hook [Info]

**Description:** `WeatherBuilder.rnd` lost `readonly` so `SeedForTests` can reassign it. The field is a shared static `Random` (already not thread-safe before the change). Reassignment happens only from the internal test-only `SeedForTests`; no production path mutates it, and `InternalsVisibleTo` is scoped to `SharedLib.Tests` only.

**Investigation:** Read `WeatherBuilder.cs` (rnd used in `CreatePondGenerationState`, `SelectPatternName`); confirmed `SeedForTests` is the only writer. Verified `InternalsVisibleTo("SharedLib.Tests")` in `SharedLib.csproj` and in the built `SharedLib.AssemblyInfo.cs`. Confirmed MSTest parallelization is not enabled (`props/Tests.Debug.runsettings` has no `<Parallelize>`), so sequential execution removes the shared-static race in the current config.

**Resolution:** Accepted. Minimal, well-documented, no production exposure. Alternative (injected RNG / `[ThreadStatic]`) would be over-engineering for a test seam.

**Discovered by:** skill recon; corroborated by code-reviewer agent.

### F-2: Daily-append simulation asserts `twoDayRuns > 0` under a pinned "magic" seed [Low]

**Description:** `Generate_DailyAppendSimulation_ProducesTwoDayRuns` pins the RNG with `SeedForTests(20260622)` and asserts at least one 2-day run forms. The assertion is deterministic but tied to a specific seed — a future change to the scoring algorithm could require re-tuning the seed to keep the test green, even if behavior is still correct.

**Investigation:** Traced the test: pinned seed makes the 150-day sequence deterministic; the two invariant tests (`BulkHorizon`, `SeedEndingInMaxRun`) instead assert structurally-guaranteed properties (max-run rule enforced by `GetAvailableBaseWeatherBuckets`, switch forced when streak == max), so they hold for any RNG state. The fragile assertion is isolated to the one simulation test.

**Resolution:** Accepted. The seed-pinned symptom test is a reasonable way to prove "2-day runs actually form"; the hard invariants are covered RNG-independently elsewhere.

**Discovered by:** skill recon; corroborated by code-reviewer agent.

## Notes

- **SQL correctness depends on the per-day `Name` invariant** (all 8 TimeOfDay rows of a `(PondId, Date)` share one `Name`). Guaranteed by construction: `WeatherBuilder.AppendWeatherDayDtos` writes the same `selectedPatternName` to all 8 slots, and generation has always picked one pattern per day. So `SELECT DISTINCT PondId, [Date], [Name]` yields exactly one row/day; `@DaysCount` correctly measures days.
- **NOLOCK** preserved on the only real table reference (`FROM Weather WITH(NOLOCK)`); the two derived tables are subqueries, not table refs. Compliant with read-only SQL convention.
- **Reader alignment** intact: outer query returns `PondId, [Date], [Name]`, mapped by name in `WeatherGenerationSeedItemDto.RestoreObjectFromReader`.
- **Single production caller** `WeatherGenerationService.LoadSeedByPond` passes `WeatherGenSeedHistoryDays` (=60) as `daysCount` — relies on days semantics, benefits from the fix; serves both bulk and daily paths. No caller relied on the old row-based behavior.

## Verdict

**Approve.** Single clean commit implementing exactly the reporter's proposed date-based dedup, plus genuine regression tests where there were none. Two independent passes (skill recon + code-reviewer agent) found no blocking issue. Production caller benefits correctly; no regression. Only Info/Low non-blocking observations, all Accepted.

**Closed (open phase) as `waiting-for-release`.** Merged MFT r16226 -> Code (NPN) @ r16233 (not inherited; r16226 > NPN base 16130, dry-run clean). LGTM posted to JIRA (comment 125986). `customfield_11323` set to Post-Release Checks. Pending: verify on live data, once the 2026.4.1.1 FTUE Server Hotfix (release date 2026-06-30) is deployed, that the daily-appended weather run mix matches bulk `RegenerateAll` (no length-1 over-variety) — reporter's acceptance criterion #2. Stays in Active Reviews until that check confirms.

## Investigation Journal

- Phase 1 intake: JIRA read, card created. Executor = Yevhenii Shust (author of r16226), distinct from assignee = reviewer = reporter (Stanislav). `customfield_11224` (Executor) empty — surfaced detect-only nudge, not filled.
- Branch context: r16226 is on MFT (Content). NPN (Code) was copied at MFT:16130; 16226 > 16130, so the fix is NOT inherited by Code — explicit merge to Code due at close phase.
- Phase 2 VCS audit: `svn log r16130:HEAD | grep FP-44564` on MFT returns exactly r16226; matches JIRA. WC at r16227 >= r16226, disk reflects the fix (read files directly, no stale-WC fallback). r16227 is unrelated (FP-44331).
- Verification: traced `InitializeStateFromSeed` streak computation against test 3's `[Cloudy, Sunny, Sunny]` seed -> streak=2=max -> first appended day excludes Sunny (matches assertion). Confirmed pre-fix 8-row trailing day inflated streak >= 8, forcing daily switch (the bug). Confirmed `Generate(null seed)` guarded. Confirmed `GetBaseWeatherName` strips only `_N` variant suffix (base name == pattern name in tests).
- Delegated independent code-reviewer agent (deep check): returned Approve, no blockers; independently confirmed SQL column alignment, NOLOCK compliance, day-unit streak logic, deterministic DB-free tests. Observations matched recon (F-1, F-2).
- Close phase: user opted for post-release monitoring -> closed `waiting-for-release` (not `resolved`). Release-gate: diff is binary-only (inline SQL in C#, no `SQL/Patches`), so no mechanical option derived; tagged `customfield_11323` = Post-Release Checks for the live-data verification. Merge to NPN hit `E170004 out-of-date` on first commit (NPN root behind); `svn update` to r16232 (pulled unrelated `PondWeatherRandomizationSettingsDto.cs`, no conflict), merge re-committed at r16233. JIRA Resolved + self-assign done by user, not this skill.
