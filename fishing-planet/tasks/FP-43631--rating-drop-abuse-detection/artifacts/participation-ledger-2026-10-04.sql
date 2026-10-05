-- FP-43631 week-22 -- participation rows from SQL, whole cohort, run on each platform PROD MAIN
-- ============================================================================
-- Same query as every cycle; only the UserId list and the two dates change. Any other change is
-- recorded in the cycle record with its reason.
--
-- ONE block. Run unchanged on each platform PROD MAIN (Steam / PS / Xbox); the list matches only
-- the candidates that exist on that database. Export each result as TSV WITH the header row into
-- `pcr-log-trajectories-2026-10-04/`:
--   steam-ledger-2026-10-04.tsv   (6 candidates expected)
--   ps-ledger-2026-10-04.tsv      (9 candidates expected)
--   xb-ledger-2026-10-04.tsv      (4 candidates expected)
--
-- Span: competitions STARTING 2026-09-21 00:00Z .. 2026-10-04 23:59:59Z. The charge window is the
-- sweep week 09-28..10-04 by EndDate; the week before is context. The 22:00Z competition of 10-04
-- belongs to the next period and is included as context only, marked IN-PROGRESS where it has not
-- ended at export time.
--
-- Columns map onto the card ledger: Comp start = StartDate, RegPCR = CompetitionRatingAtReg,
-- StartPCR = CompetitionRatingAtStart, Status as below, Place, Delta = Rating, Fee = EntranceFee,
-- ID = TournamentId, Competition = Translations.String for NameSID (LanguageId 3 = en-GB, the code
-- default) with NameCustom as the fallback.
--
-- Status: NO-SHOW = not started; DQ = started and disqualified; ZERO-SCORE = started, not DQ, Score
-- and SecondaryScore both zero or null (the detection query's predicate); PLAYED otherwise;
-- IN-PROGRESS where the competition has not ended. Cancelled competitions are not filtered out --
-- IsCanceled is a column, the reader decides (a cancellation carries no penalty).

SELECT p.UserId,
       u.Username,
       p.TournamentId,
       CONVERT(varchar(19), t.StartDate, 126)   AS StartDate,
       CONVERT(varchar(19), t.EndDate,   126)   AS EndDate,
       COALESCE(t.NameCustom, tr.String)        AS Competition,
       t.EntranceFee,
       p.CompetitionRatingAtReg                 AS RegPCR,
       p.CompetitionRatingAtStart               AS StartPCR,
       p.IsStarted,
       p.IsDisqualified,
       r.Place,
       r.Score,
       r.SecondaryScore,
       r.FishCount,
       r.Rating                                 AS Delta,
       CASE WHEN t.IsEnded = 0                                              THEN 'IN-PROGRESS'
            WHEN p.IsStarted = 0                                            THEN 'NO-SHOW'
            WHEN p.IsDisqualified = 1                                       THEN 'DQ'
            WHEN ISNULL(r.Score, 0) = 0 AND ISNULL(r.SecondaryScore, 0) = 0 THEN 'ZERO-SCORE'
            ELSE 'PLAYED' END                                               AS Status,
       t.IsEnded,
       t.IsCanceled
FROM TournamentParticipants p WITH (NOLOCK)
INNER JOIN Tournaments t WITH (NOLOCK) ON t.TournamentId = p.TournamentId
LEFT  JOIN TournamentIndividualResults r WITH (NOLOCK) ON r.TournamentId = p.TournamentId AND r.UserId = p.UserId
LEFT  JOIN Translations tr WITH (NOLOCK) ON tr.TranslationId = t.NameSID AND tr.LanguageId = 3
LEFT  JOIN Users u WITH (NOLOCK) ON u.UserId = p.UserId
WHERE t.KindId = 3
  AND ISNULL(t.IsDeleted, 0) = 0
  AND t.StartDate >= '2026-09-21' AND t.StartDate < '2026-10-05'
  AND p.UserId IN (
        -- ---- STEAM DB (6) ----
        '17D9446A-6115-42B0-A48D-14914922F593',  -- Tho1324          Steam
        'DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3',  -- MP_Alan          Steam  (cleared in week-20)
        '8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50',  -- mr.GreeM         Steam
        '76DC3E6B-4BEA-47ED-83A4-D0649D605FF9',  -- JoeCoviDodo      Steam  (week-20 WATCH)
        '99D3FC51-C708-4C3E-9BAF-DAAB73A22602',  -- 1st_Demigod      Steam
        '60D42746-1430-4D54-A479-29583B87B0A5',  -- Mariusz1029      Steam  REPEAT (ban ended 2025-02-15)
        -- ---- PS DB (8) ----
        '2C393625-F229-4284-8DB2-962BEBDE0774',  -- marzak66         PS
        '1CDB373F-5A08-4D3A-AB4A-83DAB1F00685',  -- anatoly2026      PS     (reviewed in week-18)
        'BB7842CC-E2F4-491A-A6A1-0083D202BCF7',  -- keeno1           PS
        '8CFF48CD-F1AE-418F-82B4-20FD72B6F1DC',  -- intro20          PS     banned elsewhere until 2026-12-02
        '496E32D7-CD9F-4F8F-96DF-F9171FCE1E93',  -- zezinho_curuja   PS
        'E3A99CF5-48D9-423F-998B-D714CC1668F6',  -- thebig35994      PS
        'D442B23B-4502-4427-8E08-CA35871DDC4D',  -- popeye-43        PS
        'E25C082E-8A19-4236-AA8B-C345137E9EA3',  -- STARI40K_YT      PS     REPEAT (ban ended 2026-07-13)
        'C896536D-28FA-4785-A85E-48C27B947590',  -- Panonski_Alas    PS     REPEAT (entered the cohort on the run after 22:00Z)
        -- ---- XBOX DB (4) ----
        '623A4D04-BC0D-486B-AFF5-FEA169CBD915',  -- ArticSquid71     Xbox
        'BDD6D57E-E41F-475E-B067-C0D990A5A92C',  -- xFenrir77        Xbox   REPEAT (ban ended 2026-06-01)
        '13090FFE-7894-4C66-9AF2-0CD81C1A03EB',  -- ChaChaWuu9588    Xbox   REPEAT (ban ended 2026-09-28)
        '2F692613-2090-4D4C-8E52-736A6BEF5C2C'   -- ScionHades8639   Xbox   REPEAT (ban ended 2026-09-28)
      )
ORDER BY p.UserId, t.StartDate;
