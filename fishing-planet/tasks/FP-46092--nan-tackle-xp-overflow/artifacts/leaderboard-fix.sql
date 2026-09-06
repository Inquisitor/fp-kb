-- FP-46092: remove the two XP-overflow catches from the Global leaderboard rows of user 88236613 (Steam PROD Main)
-- Rows read 2026-09-06 ~21:50 UTC (GlobalRatingsCurrent, dimension Experience):
--   Weekly  20260831  2,151,655,190
--   Monthly 20260901  2,151,207,600
--   Yearly  20260101  2,152,798,845
--   ExperienceExp (tie-breaker = player total XP at last update) 2,153,030,049
-- Logged overflow XP: 1,073,751,659 (2026-09-05 16:55) + 1,073,752,607 (2026-09-06 14:58) = 2,147,504,266.
-- Legit part of those two fish kept: base 6,571 + 7,199 with the x1.5 premium = 20,656. Subtract 2,147,483,610.
-- Expected after: Weekly 4,171,580; Monthly 3,723,990; Yearly 5,315,235; ExperienceExp 5,546,439.
-- Must run before 2026-09-07 00:00 UTC: the weekly finalization job copies the period to GlobalRatingWeeklyHistory and pays rewards.

DECLARE @UserId UNIQUEIDENTIFIER = '88236613-788F-4FCC-A8B5-7B229B8ED1FC';
DECLARE @Overflow BIGINT = 2147483610;

UPDATE GlobalRatingsCurrent
SET Experience    = Experience    - @Overflow,
    ExperienceExp = ExperienceExp - @Overflow
WHERE UserId = @UserId
  AND ((PeriodTypeId = 1 AND PeriodId = 20260831)    -- Weekly
    OR (PeriodTypeId = 2 AND PeriodId = 20260901)    -- Monthly
    OR (PeriodTypeId = 3 AND PeriodId = 20260101))   -- Yearly
  AND Experience >= @Overflow;   -- second run is a no-op

SELECT PeriodTypeId, PeriodId, Experience, ExperienceTs, ExperienceExp, IsBanned
FROM GlobalRatingsCurrent WITH (NOLOCK)
WHERE UserId = @UserId
ORDER BY PeriodTypeId;

-- Alternative once the account is actually banned (Users.IsBanned = 1 or Profiles.Role outside '-', 'I', 'D'):
-- EXEC UpdateLeaderboardsBanned @PeriodTypeId = 1, @PeriodId = 20260831, @UserId = @UserId;
-- EXEC UpdateLeaderboardsBanned @PeriodTypeId = 2, @PeriodId = 20260901, @UserId = @UserId;
-- EXEC UpdateLeaderboardsBanned @PeriodTypeId = 3, @PeriodId = 20260101, @UserId = @UserId;
-- sets IsBanned = 1 on his Competitive/Global/Fish rows; standings and finalization skip IsBanned rows.
