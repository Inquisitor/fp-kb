-- FP-43631 week-14 ban -- surgical Profile ban of 10 log-verified rating-drop abusers (all NEW)
-- ============================================================================
-- Hand-picked list: each UserId was confirmed via the Mongo Tournament-log trajectory analysis
-- on 2026-08-09 (see artifacts/bans-2026-08-09.md) AND passed a per-candidate review
-- (prosecutor / defense / impartial-judge per case, 76-agent run over 19 wide-cohort candidates).
--
-- Durations unchanged from week-13: 4 weeks first offence, 8 weeks recidivism. No REPEAT in this
-- cycle -- the three candidates carrying expired competition bans (EsseDouble, TrcikLowFiv,
-- x.Anastasia.x) all drew WATCH, so every ban here is a first offence.
--
-- RULE 1 WAS REWRITTEN THIS CYCLE and this is the first cohort judged under it. The offence is
-- now bracket-relative: taking prizes in a bracket below the one the player's own play would
-- place him in, having arrived there by shedding rating. Two limbs must BOTH hold -- chosen
-- descent (rating earned in play, given back by absence, with the temporal order visible in the
-- ledger) and payoff below the ceiling. The previous wording targeted NOOBS farming by name and
-- wrongly excluded upper-bracket candidates as "flavour mismatch".
--
-- The review was run Support-blind: pre-trial context carried no indication of who Support had
-- already actioned, so the verdicts are an independent check rather than a confirmation.
--
-- Review outcome: 10 BAN / 9 WATCH / 0 EXONERATE.
--
-- The 10 in this script (judge confidence in parens):
--   NEW 4W -> 2026-09-07:
--     Steam (4): Dr.Seven         (9, 8 prizes all NOOBS, 29 NS 60%; five descend-and-cash cycles
--                                  in eight days, every 1st place entered at PCR 51 or below)
--                lailailaiyu      (9, all 8 upward boundary crossings are played results, 6 of 7
--                                  downward ones are no-show penalties -- one-sided cause split)
--                ShadowOfOxigen   (8, 6 prizes 5N+1M, 27 NS 66%, net -95)
--                Martino_CZ       (7, upper-bracket case -- 204 of the 222 points of downward
--                                  movement are no-show penalties, played losses only 18)
--     PS    (5): RGC_ReeL_SKiiLLz (9, 9 prizes 8N+1M, 27 NS 61%)
--                Angel_of_Dunkirk (9, 9 prizes all NOOBS, 18 NS 60%, net +61)
--                switch-toad      (8, 7 prizes all NOOBS, 23 NS 52%)
--                Seu_Kuka_Beludo  (8, 7 prizes 5N+2M, 18 NS 35%)
--                HalfSand_        (7, 4 prizes all NOOBS, 9 NS 47%)
--     Xbox  (1): Pilou625057      (7, **week-13 WATCH returning** -- four NOOBS residencies in the
--                                  window, each entered by a no-show penalty and left by a top-3)
--
-- DURATION CORRECTION ON THE RECORD: the judge assigned Pilou625057 8 weeks "REPEAT tariff". He
-- is not a REPEAT -- week-13 gave him a WATCH, not a ban, and he carries no expired competition
-- ban. REPEAT means a prior competition ban that has lapsed. Corrected to the NEW tariff here.
--
-- SUPPORT OVERLAP: RGC_ReeL_SKiiLLz already carries a Support ban to 2026-09-09, which is LATER
-- than our 2026-09-07. The WHERE clause below skips him by design -- shortening another team's
-- ban would be a regression. He still gets a banLog entry recording our intent (LaccFarro
-- precedent, week-10). Expected Profile updates: Steam 4, PS 4, Xbox 1 = 9 of the 10 rows.
--
-- Platform note: the per-DB split is by database, not by the player's platform label --
-- Pilou625057 is a Win10 account living on the Xbox DB.
--
-- Run this same script on EACH platform PROD MAIN:
--   [F2P] STEAM PROD  -> matches 4
--   [F2P] PS    PROD  -> matches 5 (4 updated, RGC_ReeL_SKiiLLz skipped as already banned longer)
--   [F2P] XB    PROD  -> matches 1
-- Non-present UserIds simply don't join Profiles (verify SELECT flags them as not-found per DB).
--
-- REBAN WHERE CLAUSE: mirrors canonical game-engine `ProfileLogic.IsCompetitionsBannedNow()`.
--
-- LEADERBOARD ban is intentionally NOT done here -- run leaderboard-ban-sync.sql afterwards.
-- Standing rule: verify all three layers (Profiles / CompetitiveRatingsCurrent / banLog) per
-- platform individually -- see verify-bans-2026-08-09.sql.
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. After inspecting the verify SELECT,
-- run COMMIT TRAN (or ROLLBACK TRAN) at the bottom by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-09-07';   -- 4 weeks, Monday-aligned (first offence)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-08-10 - rating-drop abuse (week-14)';

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
        -- NEW - 4W -> 2026-09-07
        ('82C921B5-1383-437D-9AFA-9D711A344481', 'Dr.Seven',         @BanUntil_NEW, 'NEW'), -- Steam, conf 9/10 (8 prizes all NOOBS, 29 NS 60%, five descend-and-cash cycles)
        ('9584B60D-67D5-4362-8021-F1065562A5BC', 'lailailaiyu',      @BanUntil_NEW, 'NEW'), -- Steam, conf 9/10 (one-sided cause split across the 100/101 boundary)
        ('B4B0C273-5B5C-4A0C-BDDF-E204EE7F6B1A', 'ShadowOfOxigen',   @BanUntil_NEW, 'NEW'), -- Steam, conf 8/10 (6 prizes 5N+1M, 27 NS 66%)
        ('4422CD0F-153B-477B-A4F5-60353C37B5EA', 'Martino_CZ',       @BanUntil_NEW, 'NEW'), -- Steam, conf 7/10 (upper-bracket harvest; 204 of 222 points of drop are no-shows)
        ('C51F5F26-2816-4FF9-88F3-530AF5E7E875', 'RGC_ReeL_SKiiLLz', @BanUntil_NEW, 'NEW'), -- PS,    conf 9/10 (9 prizes 8N+1M, 27 NS 61%) -- SKIPPED, Support ban to 2026-09-09 runs longer
        ('92264697-3829-4C7A-93F3-861F4533C3BA', 'Angel_of_Dunkirk', @BanUntil_NEW, 'NEW'), -- PS,    conf 9/10 (9 prizes all NOOBS, 18 NS 60%)
        ('BFAF6154-7A56-4025-A4A8-4FFE8D6B74B1', 'switch-toad',      @BanUntil_NEW, 'NEW'), -- PS,    conf 8/10 (7 prizes all NOOBS, 23 NS 52%)
        ('AB70490A-BFFB-4E18-9297-B3479BAC4369', 'Seu_Kuka_Beludo',  @BanUntil_NEW, 'NEW'), -- PS,    conf 8/10 (7 prizes 5N+2M, 18 NS 35%)
        ('67E551F8-A305-4BBD-9C1E-8F96EBDD24B1', 'HalfSand_',        @BanUntil_NEW, 'NEW'), -- PS,    conf 7/10 (4 prizes all NOOBS, 9 NS 47%)
        ('646EFD1D-3A4B-4D62-B8CF-D3BC767AC646', 'Pilou625057',      @BanUntil_NEW, 'NEW'); -- Xbox DB (Win10), conf 7/10 (week-13 WATCH returning; four no-show-entered NOOBS residencies)

    -- Step 2: Profile ban (durable). Allows re-ban when player is NOT effectively banned at
    -- sweep time. WHERE clause mirrors canonical game-engine `IsCompetitionsBannedNow()` check.
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
    WHERE NOT (ISNULL(p.IsCompetitionsBanned, 0) = 1
               AND p.CompetitionsBanEndDate IS NOT NULL
               AND p.CompetitionsBanEndDate > GETUTCDATE());

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
