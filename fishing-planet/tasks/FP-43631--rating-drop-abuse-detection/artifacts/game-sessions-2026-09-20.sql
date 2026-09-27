-- FP-43631 week-20 -- online presence of the reviewed cohort, from Stats.dbo.GameSessions
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
-- already carry `Comp start`. Export the result as TSV next to the other dumps.
--
-- Retention is not a limit here: the table is written continuously and is not pruned, so it covers
-- the whole card span. A candidate missing session rows for a stretch was genuinely not in the game.

SELECT gs.UserId,
       CONVERT(varchar(19), gs.StartedAt, 126)                        AS StartedAt,
       CONVERT(varchar(19), gs.UpdatedAt, 126)                        AS UpdatedAt,
       CONVERT(varchar(19), gs.EndedAt,   126)                        AS EndedAt,
       gs.IsForceClosed,
       DATEDIFF(minute, gs.StartedAt,
                COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt))     AS Minutes
FROM Stats.dbo.GameSessions gs WITH (NOLOCK)
WHERE gs.UserId IN (
        '54EA8084-5546-4EA8-8068-4C1FDBE77D4A',  -- Bas_di08         PS      BAN
        'A92ED0C7-BB5E-43AC-971C-7AF91FD47D31',  -- CrazyGepard      PS      BAN
        '80B05C6C-7719-40B5-89CA-3A358F0BD166',  -- Gentleman83190   PS      BAN
        'F3150296-CC7F-43B0-90A5-CC941B45E960',  -- HavocHHH         Steam   BAN
        '6B94E751-0D2F-40B0-81EA-FB7C9DA0FD14',  -- Iron.Claw        Steam   BAN
        'DCB21F48-6B54-4F74-8A3F-9CAAE8BFF6A0',  -- LEK_TARNO        Steam   BAN
        '013368D1-E8A8-437A-88B0-71059E3287EB',  -- BuzzingLemur417  Xbox    BAN
        '16DDA5F1-E9C3-46F5-A43F-BFB806DE1F8F',  -- Rapidstrapon     Xbox    BAN
        '3C88816F-250B-44FD-9AB3-2D41DDF24D0A',  -- EZ-Enlightened1  PS      clean
        'BDD6D57E-E41F-475E-B067-C0D990A5A92C',  -- xFenrir77        Xbox    clean
        '67E551F8-A305-4BBD-9C1E-8F96EBDD24B1',  -- HalfSand_        PS      watch
        '8451EC2F-001F-4697-94C3-0AE532D942ED',  -- flacheman2       PS      watch
        '76DC3E6B-4BEA-47ED-83A4-D0649D605FF9',  -- JoeCoviDodo      Steam   watch
        'DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3',  -- MP_Alan          Steam   watch
        '67831814-56C8-47AC-BBE2-882DC339072A',  -- kojldyn          Steam   watch
        '03DE1972-344F-4EEF-935A-7574F652320D'   -- M4M Ovi          Xbox    watch
      )
  AND gs.StartedAt <  '2026-09-21'
  AND COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt) >= '2026-09-06'
ORDER BY gs.UserId, gs.StartedAt;
