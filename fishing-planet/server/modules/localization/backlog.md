# Localization — Backlog

## MeasuringSystemManager — Design

- `ChangeMeasuringSystem(int languageId)` switch in `Shared/SharedLib/MeasuringUnits/MeasuringSystemManager.cs` has no `default:` clause. Unknown `languageId` → silent no-op; `_currentMeasuringSystem` keeps its field initializer `0 = MeasuringSystem.Imperial`. This is the root cause of FP-43265 (Italian rendered as lb/inch/ft) and any future "new locale added, forgot to wire here" bug. Symptomatic-fix pattern. Consider: throw on unknown id, or default to `EnglishMetric`. From FP-43265 review (pre-existing).

- `case 12` and `case 13` in the same switch both map to `CultureInfo("zh-CN")`. **Confirmed bug**: `Shared/Photon.Interfaces/SharedConsts.cs` defines `CH_Simpl = 12` / `CH_Trad = 13` with `Cultures[12]="zh-CHS"` and `Cultures[13]="zh-CHT"` — `case 13` should be `zh-TW` / `zh-CHT`, not `zh-CN`. Relates to parent ticket FP-43264 (Japanese/Chinese mission completion window). From FP-43265 review (pre-existing).

- `case 10` (Portuguese, `PT`) maps to `CultureInfo("pt-BR")` (Brazilian Portuguese), but `SharedConsts.Cultures[10] = "pt-PT"` (European Portuguese). Affects number/date formatting differences between Portugal and Brazil locales. From FP-43265 review (pre-existing).

- `Shared/SharedLib/MeasuringUnits/MeasuringSystemManager.cs` switch uses magic numbers (`case 1: … case 14:`) instead of the existing `SharedConsts` constants (`EN_Imp = 1`, `RU = 2`, `EN_Metr = 3`, `DE = 4`, `FR = 5`, `PL = 6`, `UA = 7`, `IT = 8`, `ES = 9`, `PT = 10`, `NE = 11`, `CH_Simpl = 12`, `CH_Trad = 13`, `JP = 14`). A parallel `Cultures[]` array is also declared — the switch could read from both instead of duplicating the mapping. Drift between the hand-coded map and `SharedConsts.Cultures` has produced culture mismatches (see dedicated entries for cases 10 and 13; also `case 3 → en-US` vs `Cultures[3] = "en-GB"`). From FP-43265 review (pre-existing).

## Test Coverage

- `MeasuringSystemManager` has zero unit-test coverage (verified via grep on `MeasuringSystemManager` in `**/*Tests*.cs` — no matches). A test asserting each `case <id>` maps to expected `MeasuringSystem` + `CultureInfo` would prevent regressions like FP-43265. From FP-43265 review (pre-existing).

## Daily Missions Locale Bypass

- `TaskLocalizer.Term()` (`Shared/SharedLib/DailyMissions/CatchFishTasks/TaskLocalizer.cs`) uses `string.Format(format, arguments)` with the default thread culture rather than `measuring.Format(...)` which would honor `_currentCulture`. Decimal separators in mission task text don't follow the player's locale (e.g., Italian player sees `2.5` instead of `2,5`). Pre-existing, unrelated to FP-43265's symptom but adjacent: if QA reports "wrong decimal separator" in Italian/German missions, this is where to look. From FP-43265 review (pre-existing, found by code-reviewer agent).
