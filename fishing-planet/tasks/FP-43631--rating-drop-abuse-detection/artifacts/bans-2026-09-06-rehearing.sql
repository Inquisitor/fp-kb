-- FP-43631 week-18 -- re-hearing additions (2 NEW + 1 REPEAT)
-- ============================================================================
-- WHY THERE IS A SECOND BAN SCRIPT THIS CYCLE. The first hearing returned 4 BAN of 17, against 11
-- of 16 the cycle before. The cause was a briefing defect, not a change in the cohort: the brief
-- omitted the standing week-12 finding that a same-second ledger group is a FLUSH MOMENT -- the
-- server reconciling queued penalties -- and not evidence that the player was present or deciding
-- anything. Prosecutors therefore built their rule 1(a) sequence cases on exactly that artifact, and
-- judges, checking the raw log, struck them down: a registration booking at the same second a prior
-- competition resolved, while the player had been scoring inside that prior competition for hours,
-- is write order, not a choice to skip.
--
-- The 13 unconvicted candidates were re-heard on a corrected brief that (a) restored the week-12
-- finding as a rule binding BOTH sides, (b) closed the flat-cadence argument the operator had
-- already rejected in week-12 -- a player winning inside the bottom bracket accrues rating
-- continuously and must keep shedding it, so a steady cadence at the floor is ceiling maintenance --
-- and (c) stated what rule 1(a)'s temporal limb can be proved from at all: the rating chain of
-- resolved competitions, never the ordering inside one second.
--
-- Result: 5 BAN of 13. The four already convicted at the first hearing were NOT re-heard --
-- reopening a conviction on a brief corrected in the prosecution's favour would be indefensible.
--
-- TWO OF THE FIVE ARE ALREADY BANNED and are not in this script: seagate22022 and o Lord Mac o were
-- banned ahead of the reward run under the week-12 operator-override criterion
-- (bans-2026-09-06-operator-override.sql). The re-hearing convicted both independently, at
-- confidence 8 and 9, on a brief that carried no knowledge of the override. That is a clean
-- confirmation of the override rather than a contradiction of it, and it is the reason this cycle's
-- low first-hearing count is recorded as a process failure rather than as a finding about the rules.
--
-- The 3 in this script (judge confidence in parens):
--   NEW 4W -> 2026-10-05 (2):
--     Steam: Ilija1982 (8) -- pure bottom-bracket: plays 7 NOOBS, cashes 5 NOOBS, never above
--                             PCR 95 in the window, 11 unproductive of 18 at 61%.
--            codeco    (8) -- plays 7 NOOBS and 4 MIDDLES, cashes 3 NOOBS and 1 MIDDLES;
--                             15 unproductive of 25 at 60%, -212 from them against +233 productive.
--   REPEAT 8W -> 2026-11-02 (1):
--     Steam: Myky0576  (8) -- Epic account; our own week-2 ban lapsed 2026-06-17. The cohort's
--                             defining zero-score case and the reason the screen was rewritten this
--                             cycle: 42 registrations, 41 starts, ONE no-show, 27 zero-score
--                             finishes. Absence share 2.38% -- invisible to the previous no-show-only
--                             screen, which is why he was never caught on it.
--
-- All three sit on the Steam PROD MAIN database. Running elsewhere is harmless; the UserIds simply
-- do not join Profiles.
--
-- Afterwards: re-run leaderboard-ban-sync.sql (separate COMMIT) and verify-bans-2026-09-06.sql.
-- Block C of the verify script sweeps the whole reviewed cohort for anyone left unbanned in a
-- rewarded position of the closing period; it must come back empty.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @BanUntil_NEW    date          = '2026-10-05';   -- 4 weeks from Monday 2026-09-07
    DECLARE @BanUntil_REPEAT date          = '2026-11-02';   -- 8 weeks (recidivism)
    DECLARE @Note            nvarchar(300) = N'Auto-ban by Stan via FP-43631 follow-up 2026-09-07 - rating-drop abuse (week-18)';

    BEGIN TRAN;

    IF OBJECT_ID('tempdb..#BanCandidates') IS NOT NULL DROP TABLE #BanCandidates;
    CREATE TABLE #BanCandidates (
        UserId   uniqueidentifier PRIMARY KEY,
        Username varchar(64)      NOT NULL,
        BanUntil date             NOT NULL,
        Verdict  varchar(10)      NOT NULL
    );

    INSERT INTO #BanCandidates (UserId, Username, BanUntil, Verdict) VALUES
        -- NEW - 4W -> 2026-10-05
        ('E7B743E8-FBF0-4C6C-8A27-CC333C199BAF', 'Ilija1982', @BanUntil_NEW,    'NEW'),     -- Steam, conf 8/10 (5 of 5 prizes in NOOBS, max PCR 95, 61% unproductive)
        ('A7D0B667-2796-462E-9763-2B2ACAF4E2B9', 'codeco',    @BanUntil_NEW,    'NEW'),     -- Steam, conf 8/10 (cashes NOOBS while playing MIDDLES, 60% unproductive)
        -- REPEAT - 8W -> 2026-11-02
        ('B8CA6B12-3057-4BBE-9980-53F655FCF065', 'Myky0576',  @BanUntil_REPEAT, 'REPEAT');  -- Steam DB / Epic, conf 8/10 (our week-2 ban lapsed 2026-06-17; 27 zero-score finishes against 1 no-show)

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

    UPDATE p
    SET p.IsInfluencer = 0
    FROM Profiles p
    INNER JOIN #BanCandidates b ON b.UserId = p.UserId
    WHERE p.IsInfluencer = 1;

    PRINT CONCAT('Influencer flags cleared: ', @@ROWCOUNT);

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
