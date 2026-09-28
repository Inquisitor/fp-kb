-- FP-43631 week-21 -- participation ledger from SQL, the cohort of 16, run on each platform PROD MAIN
-- ============================================================================
-- NEW ARTIFACT (week-21). This is the SQL half of the trajectory-card generator that week-20 rebuilt
-- around competition start time and never saved. It exists because the log omits participations
-- (week-20: 85 of 961, always ones that cost rating) and cannot tell a no-show from a floor-absorbed
-- penalty. SQL is the spine; the Mongo dump fills Registered / Applied / PCR chain; GameSessions
-- fills online presence.
--
-- DO NOT REWRITE THIS SCRIPT PER CYCLE. Between cycles only the IN-list and the two dates change,
-- exactly as with detection-screen.sql. Any other edit needs a reason recorded in the cycle record.
--
-- ONE block. Run unchanged on each platform PROD MAIN (Steam / PS / Xbox); the IN-list matches only
-- the candidates that exist on that database, so the other platforms' users simply return nothing.
-- Export each result as TSV WITH the header row into `pcr-log-trajectories-2026-09-27/`:
--   steam-ledger-2026-09-27.tsv   (5 candidates expected; 2 of them surfaced only on the post-22:00Z screen re-run)
--   ps-ledger-2026-09-27.tsv      (5 candidates expected)
--   xb-ledger-2026-09-27.tsv      (8 candidates expected)
--
-- Span: competitions STARTING 2026-09-14 00:00Z .. 2026-09-27 23:59:59Z. The card span is cut on
-- competition start on both edges (backlog item from the week-20 boundary defect: rewards landing on
-- 09-07 for competitions started 09-06 appeared in the log-built ledger and not in the SQL spine).
-- The charge window is the sweep week 09-21..09-27 by EndDate; the preceding week is pre-context.
-- The 22:00 competition of 09-27 belongs to the next period and is included as context only, marked
-- IN-PROGRESS where it has not ended at export time.
--
-- Columns map onto the card ledger: Comp start = StartDate, RegPCR = CompetitionRatingAtReg,
-- StartPCR = CompetitionRatingAtStart, Status as below, Place, Delta = Rating, Fee = EntranceFee,
-- ID = TournamentId, Competition = Translations.String for NameSID (LanguageId 3 = en-GB, the code
-- default) with NameCustom as the fallback.
--
-- Status: NO-SHOW = not started; DQ = started and disqualified; ZERO-SCORE = started, not DQ, Score
-- and SecondaryScore both zero or null (the screen's predicate); PLAYED otherwise; IN-PROGRESS where
-- the competition has not ended. Cancelled competitions are not filtered out -- IsCanceled is a column,
-- the reader decides (a cancellation carries no penalty, the screen excludes it).

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
  AND t.StartDate >= '2026-09-14' AND t.StartDate < '2026-09-28'
  AND p.UserId IN (
        -- ---- STEAM DB (1) ----
        '23A99BA9-E0F0-46E0-B5FC-846E5DAD0814',  -- Noob-KAKA1988    Steam  board 10, NEW
        'CE0B47DE-48FE-4494-9AE7-10C3DEFA456F',  -- NotTheTheFace    Steam  outside the money, REPEAT
        '3EDA1A94-2DA6-45B4-A837-465773F5291A',  -- BurnsTroutFishery Steam outside the money, NEW (renamed since the screen)
        '1DFD5192-3B71-437F-BB5E-B0A3CFD2C281',  -- AmazingQuestHero45 Steam surfaced on the post-22:00Z screen re-run, NEW
        '67831814-56C8-47AC-BBE2-882DC339072A',  -- kojldyn          Steam  surfaced on the post-22:00Z screen re-run, week-20 WATCH returning
        -- ---- PS DB (5) ----
        '67E551F8-A305-4BBD-9C1E-8F96EBDD24B1',  -- HalfSand_        PS     board 2,  REPEAT (ban lapsed 2026-09-07)
        '23AD555B-A45C-47AC-AB4A-A469D7DDBE5E',  -- ShrekUndies      PS     outside the money, NEW
        'EBB52E2F-E4ED-42A9-9711-E55FACB1668C',  -- christdu7340     PS     outside the money, NEW
        '0BB2E091-9F60-4045-A615-E01E3ECA5D71',  -- silvery_harvest8 PS     outside the money, REPEAT
        'A52C7F8B-906A-4E82-8E43-B35E76E4417F',  -- mregan52         PS     outside the money, NEW
        -- ---- XBOX DB (8) ----
        'E39C9DAB-1697-434F-ADE9-D0122265ED13',  -- TMRyuko          Xbox   board 2,  NEW
        'BDD6D57E-E41F-475E-B067-C0D990A5A92C',  -- xFenrir77        Xbox   board 3,  REPEAT (ban lapsed 2026-06-01)
        '95D6F8AE-0562-455E-99E0-6679CC506389',  -- LaterGENJI       Xbox   board 5,  NEW
        '0521E9F5-DCF5-438C-908D-689F0DFD2242',  -- Fuzzytacos6571   Xbox   board 7,  REPEAT (ban lapsed 2026-06-01)
        '7ACE60E8-8B33-401A-AE9F-B315DD848049',  -- ELTITOGRAVY6     Xbox   board 8,  NEW
        '7E4889A6-8E26-4EB8-97B5-3C67AD6C423D',  -- BoraxHook        Xbox   outside the money, NEW
        '013368D1-E8A8-437A-88B0-71059E3287EB',  -- BuzzingLemur417  Xbox   outside the money, BANNED to 2026-11-25
        'C6440075-C23C-4B02-80AD-FE1F5FF9B25E'   -- UlfsonUlfstroem  Xbox   outside the money, REPEAT
      )
ORDER BY p.UserId, t.StartDate;
