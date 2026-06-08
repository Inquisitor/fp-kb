-- FP-43631 week-5 ban — surgical Profile ban of 8 log-verified rating-drop abusers (6 NEW + 2 REPEAT)
-- ============================================================================
-- Hand-picked list (NOT a HAVING-derived cohort): each UserId was confirmed via the Mongo
-- Tournament-log trajectory analysis on 2026-06-07 (see artifacts/bans-2026-06-07.md). All eight
-- show the same explicit pattern: climb via play into MIDDLES (PCR 100-225+), then drop back to
-- NOOBS via batched no-shows (5-7 in a single second on next login, or sustained hour-by-hour
-- no-show campaigns). PCR returns to NOOBS, prize farming resumes there. Repeats throughout the
-- week.
--
-- Adversarial-review note: a 9th candidate Lay_D14S (PS) was downgraded to WATCH after a
-- prosecutor/defense/judge trial — sample too thin (16 regs / 6 played), Lifetime 3/3/2 with 2 TOP
-- prizes inconsistent with a pure NOOBS-farmer profile, NetDelta only +42. Real pattern is there
-- but not at the same conviction level as the eight kept in this script. Will reassess in week-6.
--
-- Two watchlist escalators from week-4 confirmed and banned this cycle:
--   * JuliaRybalka — was 0N+4M+0 (MIDDLES-only) week-4; now 8N+0+0 pure NOOBS-farmer
--   * Kaneki_Ken2907 — was 3N+2M (mixed) week-4; now 7N+0+0 pure NOOBS-farmer
-- Per the standing rule "if a watched player escalates to pure NOOBS — ban without further
-- deliberation", both go in.
--
-- Two REPEAT offenders banned with extended 4W duration:
--   * I_MACTEP_I — original ban expired 2026-04-04; now back to 8N+0+0 prizes with the most
--     extreme tank-campaign seen on this task (30 hours of continuous no-shows, PCR 346 -> 0)
--   * TTC-SWAX — ban expired 2026-06-01 (today, when previous cycle's ban ended). Within 6 days
--     of being unbanned, climbed to MIDDLES three times and tanked back each time
-- Standing rule: 2W for first-time NEW, 4W for REPEAT (recidivism = doubled ban).
--
-- Excluded from ban (watchlist):
--   * Lay_D14S (PS) — downgraded by adversarial review (thin sample 16/6, Lifetime 3/3/2 with 2T)
--   * yaobaizhishang (Steam) — MIDDLES-only veteran flavor (5M prizes, lifetime 41/40/46);
--     2024 ban predates matchmaking system
--   * JIALIN0720 (Steam) — MIDDLES+TOPS veteran (7 prizes 6M+1T), high no-show but not NOOBS-farming
--   * keke7784, angeperdu (Steam), maminapokorny83 (PS) — borderline at 30-35% no-show threshold
--
-- The eight live on two separate platform PROD DBs. Run this same script on EACH:
--   [F2P] STEAM PROD  -> matches JuliaRybalka + Kaneki_Ken2907 + emer_85_he + I_MACTEP_I + TTC-SWAX
--   [F2P] XB    PROD  -> matches nggaaah + Bejk76 cz + Bizkit3209
-- (PS PROD has no ban this cycle — Lay_D14S was downgraded to WATCH; do not run on PS this week.)
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- For REPEAT users, IsCompetitionsBanned is still set=1 from the prior (now-expired) ban; the
-- UPDATE filter explicitly allows re-banning when the prior BanEnd has passed.
--
-- LEADERBOARD ban is intentionally NOT done here — run leaderboard-ban-sync.sql afterwards.
-- Standing rule from week-3/4 incidents: after every cycle, verify all three layers (Profiles /
-- CompetitiveRatingsCurrent / banLog) per platform individually.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-06-22';   -- 2 weeks, Monday-aligned (first-time bans)
    DECLARE @BanUntil_REPEAT date          = '2026-07-06';   -- 4 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-06-07 — rating-drop abuse (week-5, deliberate MIDDLES->NOOBS drop verified via Mongo log)';

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
        -- NEW — 2W → 2026-06-22
        ('8FD87705-6500-4717-B459-387B07D7B471', 'JuliaRybalka',     @BanUntil_NEW,    'NEW'),    -- Steam, escalator
        ('4545581F-C2DB-4FA4-986E-9AEE3F9CCB48', 'Kaneki_Ken2907',   @BanUntil_NEW,    'NEW'),    -- Steam, escalator
        ('0386A8AA-954F-44CF-B371-6C5BAB96943F', 'emer_85_he',       @BanUntil_NEW,    'NEW'),    -- Steam
        ('E81A2739-534A-4299-80E7-7BF54B573BE8', 'nggaaah',          @BanUntil_NEW,    'NEW'),    -- Xbox
        ('AE6A4BC7-2DBF-4662-B5C3-7A8296A0F387', 'Bejk76 cz',        @BanUntil_NEW,    'NEW'),    -- Xbox
        ('82DA4897-61AB-4B56-BD82-4C654B54B7DA', 'Bizkit3209',       @BanUntil_NEW,    'NEW'),    -- Xbox
        -- REPEAT — 4W → 2026-07-06
        ('5C99BE5A-A7FB-49B1-AAFB-188E26693CA7', 'I_MACTEP_I',       @BanUntil_REPEAT, 'REPEAT'), -- Steam, 30-hour tank campaign
        ('4D3EFD74-6B2B-4E65-B434-A63D08BC6F68', 'TTC-SWAX',         @BanUntil_REPEAT, 'REPEAT'); -- Steam, ban expired today

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
