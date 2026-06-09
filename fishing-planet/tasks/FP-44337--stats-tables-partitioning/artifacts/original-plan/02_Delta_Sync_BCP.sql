-- recovery from full backup (Monday, June 8, 2026 12:45:01 AM)

--DECLARE @cutoff DATETIME = '2026-06-08T00:45:00';
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--                                                                                  BCP
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--step 1

--Підрахувати обсяг delta

-- На ПРОДІ
DECLARE @cutoff DATETIME = '2026-06-08T00:45:00';
SELECT
    COUNT_BIG(*) AS delta_rows,
    MIN(EntityId) AS min_id, MAX(EntityId) AS max_id,
    MIN([Timestamp]) AS first_ts, MAX([Timestamp]) AS last_ts
FROM dbo.StatsFact WITH (NOLOCK)
WHERE [Timestamp] >= @cutoff;

--12 ХВИЛИН
--delta_rows=



-- На пс прод 
-- STEP 2
bcp "SELECT * FROM Stats.dbo.StatsFact WITH (NOLOCK) WHERE [Timestamp] >= '2026-06-08T00:45:00' ORDER BY EntityId" queryout "C:\Temp\statsfact_delta.dat" -S . -T -n

--STEP 3

Copy from PSPRDO to SQLStaging 



--STEP 4  Імпорт на SQLSTAGING (BCP IN з -E)
bcp Stats.dbo.StatsFact in "C:\Temp\statsfact_delta.dat" -S . -T -n -E -b 100000

-- Звірка кількості

-- На SQLSTAGING
SELECT COUNT_BIG(*) AS delta_now
FROM dbo.StatsFact WITH (NOLOCK)
WHERE [Timestamp] >= '2026-06-08T00:45:00';

-- delta_now має дорівнювати delta_rows з STEP 1 



--STEP 5  Sample-перевірка кількох рядків

-- На ПРОДІ — взяти 5 ID
SELECT TOP 5 EntityId, FishName, FishWeight, [Rank]
FROM dbo.StatsFact WITH (NOLOCK)
WHERE [Timestamp] >= '2026-06-08' ORDER BY EntityId;

-- На SQLSTAGING — порівняти
SELECT EntityId, FishName, FishWeight, [Rank]
FROM dbo.StatsFact WITH (NOLOCK)
WHERE EntityId IN (...скопіюй ID...);
