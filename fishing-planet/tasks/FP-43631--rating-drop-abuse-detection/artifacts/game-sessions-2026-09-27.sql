-- FP-43631 week-21 -- online presence of the cohort of 16, from Stats.dbo.GameSessions
-- ============================================================================
-- ONE block. Run it unchanged on each platform PROD STATS (Steam / PS / Xbox). The IN-list
-- matches only the candidates that exist on that database, so the other platforms' users simply
-- return nothing -- which is also the cross-check that the platform split is what we think.
--
-- WHY. Every presence measure the cycle has used so far is derived from `tournamentLog`, and that
-- log turns out to be blind: for LEK_TARNO 620 of 622 anti-cheat telemetry lines fall inside a
-- competition he actually entered, so the log can never show a player sitting in the game while a
-- competition he paid for runs without him. GameSessions is the real online record --
-- heartbeat-maintained (`UpdatedAt`), closed on timeout, reopened on quick reconnect.
--
-- The join against competition windows is done outside SQL, against the trajectory cards, which
-- already carry `Comp start`. Export the result as TSV WITH the header row into
-- `pcr-log-trajectories-2026-09-27/`:
--   steam-sessions-2026-09-27.tsv / ps-sessions-2026-09-27.tsv / xb-sessions-2026-09-27.tsv
--
-- Retention is not a limit here: the table is written continuously and is not pruned, so it covers
-- the whole card span. A candidate missing session rows for a stretch was genuinely not in the game.
--
-- Same script as game-sessions-2026-09-20.sql; only the IN-list and the two dates differ.

SELECT gs.UserId,
       CONVERT(varchar(19), gs.StartedAt, 126)                        AS StartedAt,
       CONVERT(varchar(19), gs.UpdatedAt, 126)                        AS UpdatedAt,
       CONVERT(varchar(19), gs.EndedAt,   126)                        AS EndedAt,
       gs.IsForceClosed,
       DATEDIFF(minute, gs.StartedAt,
                COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt))     AS Minutes
FROM Stats.dbo.GameSessions gs WITH (NOLOCK)
WHERE gs.UserId IN (
        '23A99BA9-E0F0-46E0-B5FC-846E5DAD0814',  -- Noob-KAKA1988    Steam
        'CE0B47DE-48FE-4494-9AE7-10C3DEFA456F',  -- NotTheTheFace    Steam
        '3EDA1A94-2DA6-45B4-A837-465773F5291A',  -- BurnsTroutFishery Steam (renamed since the screen)
        '1DFD5192-3B71-437F-BB5E-B0A3CFD2C281',  -- AmazingQuestHero45 Steam (post-22:00Z re-run)
        '67831814-56C8-47AC-BBE2-882DC339072A',  -- kojldyn          Steam (post-22:00Z re-run)
        '67E551F8-A305-4BBD-9C1E-8F96EBDD24B1',  -- HalfSand_        PS
        '23AD555B-A45C-47AC-AB4A-A469D7DDBE5E',  -- ShrekUndies      PS
        'EBB52E2F-E4ED-42A9-9711-E55FACB1668C',  -- christdu7340     PS
        '0BB2E091-9F60-4045-A615-E01E3ECA5D71',  -- silvery_harvest8 PS
        'A52C7F8B-906A-4E82-8E43-B35E76E4417F',  -- mregan52         PS
        'E39C9DAB-1697-434F-ADE9-D0122265ED13',  -- TMRyuko          Xbox
        'BDD6D57E-E41F-475E-B067-C0D990A5A92C',  -- xFenrir77        Xbox
        '95D6F8AE-0562-455E-99E0-6679CC506389',  -- LaterGENJI       Xbox
        '0521E9F5-DCF5-438C-908D-689F0DFD2242',  -- Fuzzytacos6571   Xbox
        '7ACE60E8-8B33-401A-AE9F-B315DD848049',  -- ELTITOGRAVY6     Xbox
        '7E4889A6-8E26-4EB8-97B5-3C67AD6C423D',  -- BoraxHook        Xbox
        '013368D1-E8A8-437A-88B0-71059E3287EB',  -- BuzzingLemur417  Xbox
        'C6440075-C23C-4B02-80AD-FE1F5FF9B25E'   -- UlfsonUlfstroem  Xbox
      )
  AND gs.StartedAt <  '2026-09-28'
  AND COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt) >= '2026-09-13'
ORDER BY gs.UserId, gs.StartedAt;
