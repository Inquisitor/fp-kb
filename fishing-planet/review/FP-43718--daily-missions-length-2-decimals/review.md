---
status: resolved
executor: Yuriy Burda
branch: LBM20251201 @ r16082, merged to MFT20260325 @ r16083
jira: https://fishingplanet.atlassian.net/browse/FP-43718
---

# Review: FP-43718 — Daily Missions: fish length condition rounded to 2 decimals

## Summary

Daily-mission "catch fish of length X" conditions failed to credit player catches because the generated mission-target length used full decimal precision (e.g. 0.123456 m) while the UI displays — and players perceive — only 2-decimal values (centimetres without millimetres). Server-side fix rounds the generated mission-target length to 2 decimals so the condition matches what the UI shows.

JIRA author clarification: "вирішили переробити генерацію довжин на 2 знака після коми, тобто сантиметри без міліметрів". Feature is already live on STEAM PROD (currently running off LBM); this ticket is the post-release fix. KNW (Stable) does not run this feature, so no port needed.

## Scope

- **LBM20251201 r16082** — Server: Round daily mission fish length conditions to 2 decimals
  - New `LengthMeterDecimalPlaces = 2` const + private `RoundLength(decimal)` helper in `DailyMissionGenerator_Utils`
  - All five `GetLengthRange` switch arms wrap `settings.LessC/MoreC/LessT/MoreT/RangeC/RangeT` in `RoundLength(...)`
  - Test `BuildTask_length_condition_should_be_rounded_to_two_decimal_places` (AvgC 0.123456 → 0.12, AvgT 0.987654 → 0.99)
- **MFT20260325 r16083** — Merge of LBM r16082 into Code branch (diff identical)

## Notes

- **Banker's rounding (ToEven).** `decimal.Round(meters, 2)` without explicit `MidpointRounding` uses ToEven. This is symmetric — the same rounded value flows into both the mission text (`TaskLocalizer.Length(task.MinLength.Value)`) and the catch-side condition (`DailyMissionUtils.CreateTaskConditionCatch`). UI and condition stay aligned regardless of midpoint direction. Accepted as-is.
- **Asymmetric epsilon between Range and one-side cases** (in `DailyMissionUtils.CreateTaskConditionCatch`): the Range branch copies `MinLength`/`MaxLength` directly without epsilon, while one-side branches add `±0.00001`. Pre-existing behaviour; not introduced by this fix.
- **Single generation entry point.** `(task.MinLength, task.MaxLength) = GetFishLength()` is the only place where these fields get populated (verified by grep on `\.MinLength\s*=` across `DailyMissions`). `GetFishLength` routes through `GetLengthRange`, which the fix patches. No other code path bypasses the rounding.
- **Catch-side comparison** (`ConditionExtensions.MatchFishPredicate`): `fish.Length < condition.Length` / `fish.Length > condition.MaxLength`. The fix relies on `fish.Length` (and UI display) effectively living in the 2-decimal world. This is the implicit contract that makes the fix correct.

## Investigation Journal

- Intake from JIRA at face value (Phase 1 invariant); SVN audit deferred to Phase 2.
- Executor field empty in JIRA; commit author from comment = Yuriy Burda → recorded as F-1 (Info).
- Phase 2 audit: `svn log -r 16000:HEAD … | grep FP-43718` on LBM and MFT — confirms r16082 / r16083 exactly as posted in JIRA. KNW (Stable) grep returns no hits — consistent with author's decision not to port.
- Hypothesis: catch-side might consume unrounded length elsewhere. Verified single point of `task.MinLength`/`MaxLength` assignment via grep — `GetFishLength()` → `GetLengthRange()` is the only writer; both `TaskLocalizer` and `CreateTaskConditionCatch` only read these fields. Fix is complete.
- Branch-copy inheritance: not applicable — fix targets LBM (Content) → MFT (Code), standard direction; no inheritance shortcut available.
- Code-reviewer agent delegation declined — recon found no non-trivial issues; observations are pre-existing and accepted.

## Verdict

**Approve.** Minimal, targeted fix with covering test; single generation entry point; UI and condition stay in sync via shared rounded value.
