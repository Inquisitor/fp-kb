/* =====================================================================
   FP-43705  -- Scope assessment: consumables driven into negative counters
   ---------------------------------------------------------------------
   Profiles is ~1.5 TB and ProfileJson is nvarchar(max). We scan it ONCE,
   cheaply (substring LIKE only, no OPENJSON), to materialize a lean
   candidate list of UserIds. All later parsing/analysis joins back to that
   small list, so the 1.5 TB table is never re-scanned.

   Why UserId-only: legit profiles never carry a negative Count (the game
   clamps), so the candidate set is expected to be small. Even a worst case
   of millions of rows is just 16 bytes/UserId -> tens/hundreds of MB, so
   disk is a non-issue. The detailed per-item data stays in ProfileJson and
   is parsed on demand from the candidate subset (optionally materialized).

   Known positive for end-to-end validation BEFORE prod:
     tester profile (Test env) UserId = 1fba52a7-20dc-415d-bf1a-ee01ff1854dd
     -> run STEP 1-4 on [F2P] TEST first, confirm it is captured, then prod.

   Inventory shape (verified on live JSON), per $.Inventory.Items[]:
     "$type"   -> concrete class, e.g. "ObjectModel.Bait"/"ObjectModel.Feeder"
     "ItemId"/"ItemType"/"ItemSubType", "Count" (int), "Storage" (enum name)
     ParentItem == on a rod hook. Amount-stack family (Chum/Line/BoatFuel)
     keeps its amount in Weight/Length/Capacity, not Count -> excluded.

   RUN per Main DB (Steam/PS/XB/MOB/NX, + Retail if needed), DB=Main, schema=dbo.

   LOCKING: every read of dbo.Profiles / dbo.InventoryItems uses WITH (NOLOCK)
   on purpose -- dirty reads are acceptable here; we must NOT take shared locks
   on the 1.5 TB Profiles table for the duration of a full scan. Keep NOLOCK on
   any query you add against Profiles.
   ===================================================================== */


/* ---------------------------------------------------------------------
   STEP 1 -- Lean candidate table (permanent, date-stamped, UserId only).
   Idempotent.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.FP43705_Candidates_20260607', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FP43705_Candidates_20260607
    (
        UserId     uniqueidentifier NOT NULL PRIMARY KEY,
        SourceDb   sysname          NOT NULL,
        CapturedAt datetime         NOT NULL CONSTRAINT DF_FP43705_Cand_At DEFAULT (GETUTCDATE())
    );
END;


/* ---------------------------------------------------------------------
   STEP 2 -- The single heavy scan. Run ONCE per Main DB.
   Substring prefilter only (NO OPENJSON), so this is the cheapest possible
   full pass over the 1.5 TB table. It over-includes slightly (matches any
   "Count":- anywhere in the blob, e.g. an unrelated nested object) -- that
   is fine; STEP 4 parses $.Inventory.Items precisely and drops false hits.
   Re-running is safe (NOT EXISTS guard); use the TRUNCATE for a clean reload.
   --------------------------------------------------------------------- */
-- TRUNCATE TABLE dbo.FP43705_Candidates_20260607;   -- uncomment for clean reload
INSERT INTO dbo.FP43705_Candidates_20260607 (UserId, SourceDb)
SELECT p.UserId, DB_NAME()
FROM dbo.Profiles p WITH (NOLOCK)
WHERE p.ProfileJson LIKE '%"Count":-%'
  AND NOT EXISTS (SELECT 1 FROM dbo.FP43705_Candidates_20260607 c WHERE c.UserId = p.UserId);


/* ---------------------------------------------------------------------
   STEP 2B -- RESILIENT batched scan. Use this INSTEAD of STEP 2 on big/hot
   DBs that fail STEP 2 with:
     Msg 601 "Could not continue scan with NOLOCK due to data movement."
   That error means a long unordered NOLOCK scan raced concurrent page moves
   on a hot table. Here we walk the clustered PK (UserId) in ordered keyset
   batches (each a short scan, far less exposed to 601) and retry any batch
   that still trips 601. Resumable + idempotent (NOT EXISTS guard).
   --------------------------------------------------------------------- */
SET NOCOUNT ON;
DECLARE @last uniqueidentifier = '00000000-0000-0000-0000-000000000000';
DECLARE @next uniqueidentifier;
DECLARE @batch int = 10000;
DECLARE @retry int;

WHILE 1 = 1
BEGIN
    -- window upper bound: index-only over the clustered key, low 601 risk
    SELECT @next = MAX(UserId) FROM (
        SELECT TOP (@batch) UserId
        FROM dbo.Profiles WITH (NOLOCK)
        WHERE UserId > @last
        ORDER BY UserId
    ) w;

    IF @next IS NULL BREAK;          -- no more rows

    SET @retry = 0;
    scan_window:
    BEGIN TRY
        INSERT INTO dbo.FP43705_Candidates_20260607 (UserId, SourceDb)
        SELECT p.UserId, DB_NAME()
        FROM dbo.Profiles p WITH (NOLOCK)
        WHERE p.UserId > @last AND p.UserId <= @next     -- bounded short scan
          AND p.ProfileJson LIKE '%"Count":-%'
          AND NOT EXISTS (SELECT 1 FROM dbo.FP43705_Candidates_20260607 c WHERE c.UserId = p.UserId);
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 601 AND @retry < 5
        BEGIN
            SET @retry += 1;
            WAITFOR DELAY '00:00:02';
            GOTO scan_window;        -- retry just this window (@last not yet advanced)
        END
        THROW;
    END CATCH

    SET @last = @next;               -- advance keyset cursor
END


/* ---------------------------------------------------------------------
   STEP 3 -- Candidate volume sanity check (cheap).
   If this is implausibly large, inspect a few blobs before STEP 4.
   --------------------------------------------------------------------- */
SELECT COUNT(*) AS Candidates FROM dbo.FP43705_Candidates_20260607;


/* =====================================================================
   STEP 4  ANALYSIS -- parse OPENJSON only over the candidate subset.
   Cheap and repeatable; the big table is touched only by PK seeks.
   ===================================================================== */

/* 4a -- headline: real affected players, items, deepest negative, on/off rod.
        (Confirms how many candidates truly have a negative inventory item.) */
;WITH neg AS (
    SELECT c.UserId, it.[Count], it.Storage
    FROM dbo.FP43705_Candidates_20260607 c
    JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = c.UserId
    CROSS APPLY OPENJSON(p.ProfileJson, '$.Inventory.Items')
        WITH (t nvarchar(100) '$."$type"', [Count] int '$.Count', Storage nvarchar(30) '$.Storage') it
    WHERE it.[Count] < 0
      AND it.t NOT LIKE '%Chum%' AND it.t NOT LIKE '%.Line' AND it.t NOT LIKE '%BoatFuel%'
)
SELECT
    COUNT(DISTINCT UserId)                                   AS AffectedPlayers,
    COUNT(*)                                                 AS NegativeItems,
    MIN([Count])                                             AS DeepestNegative,
    SUM(CASE WHEN Storage =  'ParentItem' THEN 1 ELSE 0 END) AS OnRodItems,
    SUM(CASE WHEN Storage <> 'ParentItem' THEN 1 ELSE 0 END) AS OffRodItems
FROM neg;

/* 4b -- breakdown by item (which items, how many, how deep) */
;WITH neg AS (
    SELECT c.UserId, it.ItemId, tr.String AS ItemName,
           REPLACE(it.t, 'ObjectModel.', '') AS Kind,                 -- item class from the blob
           icc.ParentCategoryId AS TypeId,    pcat.String AS [Type],  -- ParentCategoryId == ItemType enum
           ic.CategoryId        AS SubTypeId, icat.String AS SubType, -- CategoryId       == ItemSubType enum
           ic.Asset, it.[Count]
    FROM dbo.FP43705_Candidates_20260607 c
    JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = c.UserId
    CROSS APPLY OPENJSON(p.ProfileJson, '$.Inventory.Items')
        WITH (t nvarchar(100) '$."$type"', ItemId int '$.ItemId', [Count] int '$.Count') it
    LEFT JOIN dbo.InventoryItems ic WITH (NOLOCK) ON ic.ItemId = it.ItemId
    LEFT JOIN dbo.Translations  tr   WITH (NOLOCK) ON tr.TranslationId   = ic.NameSID  AND tr.LanguageId   = 3
    LEFT JOIN dbo.InventoryCategories icc WITH (NOLOCK) ON icc.CategoryId = ic.CategoryId
    LEFT JOIN dbo.Translations  icat WITH (NOLOCK) ON icat.TranslationId = icc.NameSID AND icat.LanguageId = 3
    LEFT JOIN dbo.InventoryCategories pcc WITH (NOLOCK) ON pcc.CategoryId = icc.ParentCategoryId
    LEFT JOIN dbo.Translations  pcat WITH (NOLOCK) ON pcat.TranslationId = pcc.NameSID AND pcat.LanguageId = 3
    WHERE it.[Count] < 0
      AND it.t NOT LIKE '%Chum%' AND it.t NOT LIKE '%.Line' AND it.t NOT LIKE '%BoatFuel%'
)
-- Type/SubType = the item-category ids (ParentCategoryId/CategoryId), which ARE the
-- ItemType/ItemSubType enums in code; names via Translations (LanguageId 3 = English).
-- The blob's own ItemType/ItemSubType are unreliable (some profiles omit them).
SELECT ItemId, ItemName, Kind, TypeId, [Type], SubTypeId, SubType, Asset AS ItemAsset,
       COUNT(*) AS Items, COUNT(DISTINCT UserId) AS Players,
       MIN([Count]) AS DeepestNegative, SUM([Count]) AS SumNegCount
FROM neg
GROUP BY ItemId, ItemName, Kind, TypeId, [Type], SubTypeId, SubType, Asset
ORDER BY Items DESC;

/* 4c -- per-player detail (each player, who they are, their negative items).
        Level/Rank from Profiles columns, Username from Users, item name from
        Translations (LanguageId 3 = English). */
SELECT u.Username, u.LastLoginDate, p.Level, p.[Rank], c.UserId,
       it.ItemId, tr.String AS ItemName,
       REPLACE(it.t, 'ObjectModel.', '') AS Kind,                 -- item class from the blob
       icc.ParentCategoryId AS TypeId,    pcat.String AS [Type],  -- ParentCategoryId == ItemType enum
       ic.CategoryId        AS SubTypeId, icat.String AS SubType, -- CategoryId       == ItemSubType enum
       it.Storage, it.[Count] AS NegCount, ic.Asset AS ItemAsset
FROM dbo.FP43705_Candidates_20260607 c
JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = c.UserId
LEFT JOIN dbo.Users u WITH (NOLOCK) ON u.UserId = c.UserId
CROSS APPLY OPENJSON(p.ProfileJson, '$.Inventory.Items')
    WITH (t nvarchar(100) '$."$type"', ItemId int '$.ItemId',
          [Count] int '$.Count', Storage nvarchar(30) '$.Storage') it
LEFT JOIN dbo.InventoryItems ic WITH (NOLOCK) ON ic.ItemId = it.ItemId
LEFT JOIN dbo.Translations  tr   WITH (NOLOCK) ON tr.TranslationId   = ic.NameSID  AND tr.LanguageId   = 3
LEFT JOIN dbo.InventoryCategories icc WITH (NOLOCK) ON icc.CategoryId = ic.CategoryId
LEFT JOIN dbo.Translations  icat WITH (NOLOCK) ON icat.TranslationId = icc.NameSID AND icat.LanguageId = 3
LEFT JOIN dbo.InventoryCategories pcc WITH (NOLOCK) ON pcc.CategoryId = icc.ParentCategoryId
LEFT JOIN dbo.Translations  pcat WITH (NOLOCK) ON pcat.TranslationId = pcc.NameSID AND pcat.LanguageId = 3
WHERE it.[Count] < 0
  AND it.t NOT LIKE '%Chum%' AND it.t NOT LIKE '%.Line' AND it.t NOT LIKE '%BoatFuel%'
ORDER BY c.UserId, it.[Count];

/* 4d -- per-player roll-up (one row per player: who they are + how bad) */
;WITH neg AS (
    SELECT c.UserId, it.[Count]
    FROM dbo.FP43705_Candidates_20260607 c
    JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = c.UserId
    CROSS APPLY OPENJSON(p.ProfileJson, '$.Inventory.Items')
        WITH (t nvarchar(100) '$."$type"', [Count] int '$.Count') it
    WHERE it.[Count] < 0
      AND it.t NOT LIKE '%Chum%' AND it.t NOT LIKE '%.Line' AND it.t NOT LIKE '%BoatFuel%'
)
SELECT u.Username, u.LastLoginDate, p.Level, p.[Rank], n.UserId,
       COUNT(*) AS NegativeItems, MIN(n.[Count]) AS DeepestNegative, SUM(n.[Count]) AS SumNegCount
FROM neg n
JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = n.UserId
LEFT JOIN dbo.Users u WITH (NOLOCK) ON u.UserId = n.UserId
GROUP BY u.Username, u.LastLoginDate, p.Level, p.[Rank], n.UserId
ORDER BY NegativeItems DESC, DeepestNegative;

/* ---------------------------------------------------------------------
   OPTIONAL -- freeze STEP 4c into a detail snapshot (only if you want a
   stable per-item table to share / cost out later). Tiny vs Profiles.
   --------------------------------------------------------------------- */
-- SELECT u.Username, p.Level, p.[Rank], c.UserId, it.ItemId, tr.String AS ItemName,
--        it.Storage, it.[Count] AS NegCount, ic.Asset AS ItemAsset, DB_NAME() AS SourceDb,
--        CAST(GETUTCDATE() AS datetime) AS CapturedAt
-- INTO dbo.FP43705_NegativeItems_20260607
-- FROM dbo.FP43705_Candidates_20260607 c
-- JOIN dbo.Profiles p WITH (NOLOCK) ON p.UserId = c.UserId
-- LEFT JOIN dbo.Users u WITH (NOLOCK) ON u.UserId = c.UserId
-- CROSS APPLY OPENJSON(p.ProfileJson, '$.Inventory.Items')
--     WITH (t nvarchar(100) '$."$type"', ItemId int '$.ItemId',
--           [Count] int '$.Count', Storage nvarchar(30) '$.Storage') it
-- LEFT JOIN dbo.InventoryItems ic WITH (NOLOCK) ON ic.ItemId = it.ItemId
-- LEFT JOIN dbo.Translations  tr WITH (NOLOCK) ON tr.TranslationId = ic.NameSID AND tr.LanguageId = 3
-- WHERE it.[Count] < 0
--   AND it.t NOT LIKE '%Chum%' AND it.t NOT LIKE '%.Line' AND it.t NOT LIKE '%BoatFuel%';
