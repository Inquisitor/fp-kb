-- FP-43631 week-22 -- time in the game for the cohort, from Stats.dbo.GameSessions
-- ============================================================================
-- Same query as every cycle; only the UserId list and the two dates change.
--
-- ONE block. Run it unchanged on each platform PROD STATS (Steam / PS / Xbox). The list matches
-- only the candidates that exist on that database.
--
-- GameSessions is presence on a game server: opened at game-server login, kept alive by the
-- client's time request, closed on disconnect unless the player moves rooms. The card generator
-- overlaps these sessions with each competition window.
--
-- Export the result as TSV WITH the header row into `pcr-log-trajectories-2026-10-04/`:
--   steam-sessions-2026-10-04.tsv / ps-sessions-2026-10-04.tsv / xb-sessions-2026-10-04.tsv

SELECT gs.UserId,
       CONVERT(varchar(19), gs.StartedAt, 126)                        AS StartedAt,
       CONVERT(varchar(19), gs.UpdatedAt, 126)                        AS UpdatedAt,
       CONVERT(varchar(19), gs.EndedAt,   126)                        AS EndedAt,
       gs.IsForceClosed,
       DATEDIFF(minute, gs.StartedAt,
                COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt))     AS Minutes
FROM Stats.dbo.GameSessions gs WITH (NOLOCK)
WHERE gs.UserId IN (
        '17D9446A-6115-42B0-A48D-14914922F593',  -- Tho1324          Steam
        'DAA00F0B-2BA8-49A5-8BE2-9880D6C856E3',  -- MP_Alan          Steam
        '8E2F69A6-B63B-46E6-A0B8-CDFB5741DD50',  -- mr.GreeM         Steam
        '76DC3E6B-4BEA-47ED-83A4-D0649D605FF9',  -- JoeCoviDodo      Steam
        '99D3FC51-C708-4C3E-9BAF-DAAB73A22602',  -- 1st_Demigod      Steam
        '60D42746-1430-4D54-A479-29583B87B0A5',  -- Mariusz1029      Steam
        '2C393625-F229-4284-8DB2-962BEBDE0774',  -- marzak66         PS
        '1CDB373F-5A08-4D3A-AB4A-83DAB1F00685',  -- anatoly2026      PS
        'BB7842CC-E2F4-491A-A6A1-0083D202BCF7',  -- keeno1           PS
        '8CFF48CD-F1AE-418F-82B4-20FD72B6F1DC',  -- intro20          PS
        '496E32D7-CD9F-4F8F-96DF-F9171FCE1E93',  -- zezinho_curuja   PS
        'E3A99CF5-48D9-423F-998B-D714CC1668F6',  -- thebig35994      PS
        'D442B23B-4502-4427-8E08-CA35871DDC4D',  -- popeye-43        PS
        'E25C082E-8A19-4236-AA8B-C345137E9EA3',  -- STARI40K_YT      PS
        'C896536D-28FA-4785-A85E-48C27B947590',  -- Panonski_Alas    PS
        '623A4D04-BC0D-486B-AFF5-FEA169CBD915',  -- ArticSquid71     Xbox
        'BDD6D57E-E41F-475E-B067-C0D990A5A92C',  -- xFenrir77        Xbox
        '13090FFE-7894-4C66-9AF2-0CD81C1A03EB',  -- ChaChaWuu9588    Xbox
        '2F692613-2090-4D4C-8E52-736A6BEF5C2C'   -- ScionHades8639   Xbox
      )
  AND gs.StartedAt <  '2026-10-05'
  AND COALESCE(gs.EndedAt, gs.UpdatedAt, gs.StartedAt) >= '2026-09-20'
ORDER BY gs.UserId, gs.StartedAt;
