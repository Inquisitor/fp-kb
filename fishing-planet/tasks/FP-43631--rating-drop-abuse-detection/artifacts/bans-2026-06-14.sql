-- FP-43631 week-6 ban — surgical Profile ban of 4 log-verified rating-drop abusers (2 NEW + 2 REPEAT)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log trajectory analysis on 2026-06-15 (see artifacts/bans-2026-06-14.md) AND passed
-- a per-candidate adversarial trial (prosecutor / defense / impartial-judge per case, run as a
-- 45-agent workflow against 15 wide-cohort candidates). Only the four cases with both a strong
-- trajectory signal and an adversarial-trial BAN verdict end up here.
--
-- Trial outcomes summary (full reasoning in bans-2026-06-14.md):
--   LaccFarro        (Steam, NEW)    — BAN 2W, judge confidence 10/10 (most extreme)
--   STARI40K_YT      (PS,    REPEAT) — BAN 4W, judge confidence  9/10
--   IIGot-_-Smoked   (PS,    REPEAT) — BAN 4W, judge confidence  8/10
--   Mr-crimson-21    (PS,    NEW)    — BAN 2W, judge confidence  7/10
--
-- Watchlist (11) and three categories of WATCH:
--   * Heavy-lifetime veterans (real top-tier players, NOT NOOBS-farmers): VM_NPWP (Steam, REPEAT
--     but lifetime 23/29/26 + net +412 + MIDDLES-skewed prizes), MonsterFish_fuark (lifetime
--     49/64/47), JIALIN0720 (lifetime 67/49/43 — second-cycle watchlist after week-5)
--   * Adversarial-trial close calls or sawtooth/reconciliation patterns: Kacumi, ArTeM209,
--     MonsterFish_fuark (Steam); rabolio41100, mingocai_10 (PS); MikeikeMOON (Xbox)
--   * TOP-only sandbagging (different mechanism, not our enforcement target): Ttv_s4muka019,
--     VM_Vigor (Steam); IFC_BaysEmperor (Steam, already banned)
--
-- Two REPEAT offenders with extended 4W duration:
--   * STARI40K_YT — prior ban expired 2026-06-01, returned with 7 NOOBS prizes and is sitting
--     PS leaderboard #1 by wins for the current week
--   * IIGot-_-Smoked — our own week-3 ban expired EXACTLY 2026-06-08 (one week ago), three
--     climb-then-flush MIDDLES->NOOBS cycles within 6 days of being unbanned
--
-- The four live on two platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches LaccFarro
--   [F2P] PS    PROD  -> matches Mr-crimson-21 + STARI40K_YT + IIGot-_-Smoked
-- (No Xbox ban this cycle — only MikeikeMOON appeared in the wide cohort and the trial
-- downgraded him to WATCH on no-MIDDLES-exposure and net-negative trajectory.)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- For REPEAT users, IsCompetitionsBanned is still set=1 from the prior (now-expired) ban; the
-- UPDATE filter explicitly allows re-banning when the prior BanEnd has passed.
--
-- LEADERBOARD ban is intentionally NOT done here — run leaderboard-ban-sync.sql afterwards.
-- Standing rule from week-3/4 incidents: after every cycle, verify all three layers (Profiles /
-- CompetitiveRatingsCurrent / banLog) per platform individually — see verify-bans-2026-06-14.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-06-29';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-07-13';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-06-15 - rating-drop abuse (week-6, adversarial-reviewed: prosecutor/defense/judge per case)';

    BEGIN TRAN;

    -- Step 1: explicit ban list with per-row BanUntil + Verdict tag
    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- NEW - 2W -> 2026-06-29
        ('47FEE9FA-C9E6-4DBE-8742-63B56558D890', 'LaccFarro',     @BanUntil_NEW,    'NEW'),    -- Steam, trial confidence 10/10
        ('78C4A65F-EF45-482A-A125-88D71973013B', 'Mr-crimson-21', @BanUntil_NEW,    'NEW'),    -- PS,    trial confidence  7/10
        -- REPEAT - 4W -> 2026-07-13
        ('E25C082E-8A19-4236-AA8B-C345137E9EA3', 'STARI40K_YT',   @BanUntil_REPEAT, 'REPEAT'), -- PS,    trial confidence  9/10
        ('8F36F30F-ADE0-4D9A-BC88-765AE61E5384', 'IIGot-_-Smoked',@BanUntil_REPEAT, 'REPEAT'); -- PS,    trial confidence  8/10

    -- Step 2: Profile ban (durable). Re-bans expired-ban REPEAT users by allowing the UPDATE
    -- when (IsCompetitionsBanned=0) OR (existing ban has already expired).
    UPDATE p
    SET p.IsCompetitionsBanned   = 1,
        p.CompetitionsBanEndDate = b.BanUntil,
        p.AdminComment           = CASE
            WHEN p.AdminComment IS NULL OR LTRIM(RTRIM(p.AdminComment)) = ''
                THEN @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
            ELSE p.AdminComment + CHAR(13) + CHAR(10) + @Note + ' (' + b.Verdict + ' until ' + CONVERT(varchar(10), b.BanUntil, 23) + ')'
        END
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE ISNULL(p.IsCompetitionsBanned, 0) = 0
       OR (p.CompetitionsBanEndDate IS NOT NULL AND p.CompetitionsBanEndDate <= GETUTCDATE());

    PRINT CONCAT('Profiles banned on this DB: ', @@ROWCOUNT);

    -- Step 3: Influencer reset (matches WebAdmin behaviour)
    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;

    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

    -- Step 4: verify (FoundUser non-null = matched on this DB; null = belongs to another platform)
    SELECT b.Verdict,
           b.Username AS Expected,
           u.Username AS FoundUser,
           b.UserId,
           u.Source   AS Platform,
           p.IsCompetitionsBanned,
           p.CompetitionsBanEndDate,
           p.CompetitionRating AS CurrentPCR,
           p.IsInfluencer,
           p.AdminComment
    FROM #BanCandidates b
    LEFT JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
    LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
    ORDER BY b.Verdict, FoundUser;

    DROP TABLE #BanCandidates;

    -- After visual inspection pick ONE:
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
