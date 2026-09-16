-- FP-46200 catalog recheck
--
-- Re-derives the numbers quoted during the investigation. The earlier figures used
-- "Params LIKE 'Length: % m; Test: % Diameter: %'" as a line detector, which also matches leaders:
-- both render the same parameter template. For a leader Count is a piece count and the printed length
-- is the length of one piece, so every aggregate built on that predicate mixed metres with pieces.
--
-- The discriminator used here is structural instead: a leader carries LeaderLength in its ConfigJson,
-- a line does not. Verified against Catfish Moustache Line (36), Glowing Mono 1.4 (180),
-- Mono Leader 0.09 (67) and Colorful Fluorocarbon Leader 1.2 (181).
--
-- Results 1-4 run against any Main. Result 5 only makes sense on DEV, the authoring environment -
-- DataChanges is not carried to the other environments by DataPump.

IF OBJECT_ID('tempdb..#item') IS NOT NULL DROP TABLE #item;
IF OBJECT_ID('tempdb..#entry') IS NOT NULL DROP TABLE #entry;

-- items that render the Length/Test/Diameter template, split into lines and leaders
SELECT i.ItemId,
       v.Name,
       i.CategoryId,
       TRY_CAST(JSON_VALUE(CAST(i.ConfigJson AS nvarchar(max)), '$.Count') AS int) AS DeliveredCount,
       JSON_VALUE(CAST(i.ConfigJson AS nvarchar(max)), '$.ParamsLength')           AS PrintedLength,
       CASE WHEN JSON_VALUE(CAST(i.ConfigJson AS nvarchar(max)), '$.LeaderLength') IS NULL
            THEN 'line' ELSE 'leader' END                                          AS Kind
INTO #item
FROM dbo.InventoryItems i WITH (NOLOCK)
JOIN dbo.VW_AllItems v WITH (NOLOCK)
  ON v.ItemId = i.ItemId AND v.LanguageId = 3
 AND v.Params LIKE 'Length: % m; Test: % Diameter: %';

CREATE CLUSTERED INDEX IX_item ON #item (ItemId);

-- every pack entry
SELECT p.ProductId, e.ItemId, ISNULL(e.Storage, '(null)') AS Storage, e.Cnt
INTO #entry
FROM dbo.Products p WITH (NOLOCK)
CROSS APPLY OPENJSON(CAST(p.ItemJson AS nvarchar(max)))
     WITH (ItemId int '$.ItemId', Storage nvarchar(50) '$.Storage', Cnt int '$.Count') e
WHERE p.ItemJson IS NOT NULL AND ISJSON(CAST(p.ItemJson AS nvarchar(max))) = 1;

CREATE CLUSTERED INDEX IX_entry ON #entry (ProductId, ItemId);


-- result 1: how many of the template-matching items are lines and how many are leaders.
-- Shows how much of the earlier figures was leaders.
SELECT Kind, COUNT(*) AS Items, MIN(DeliveredCount) AS MinCount, MAX(DeliveredCount) AS MaxCount
FROM #item
GROUP BY Kind;


-- result 2: fold pairs for lines only - the item is both mounted and standalone in the same pack.
-- StandaloneMaxOne is the group the stack gate deliberately leaves alone.
SELECT COUNT(*) AS LinePairs,
       SUM(CASE WHEN StandaloneMax = 1 THEN 1 ELSE 0 END) AS StandaloneMaxOne
FROM (
  SELECT e.ProductId, e.ItemId,
         MAX(CASE WHEN e.Storage <> 'ParentItem' THEN e.Cnt END) AS StandaloneMax
  FROM #entry e
  JOIN #item it ON it.ItemId = e.ItemId AND it.Kind = 'line'
  GROUP BY e.ProductId, e.ItemId
  HAVING SUM(CASE WHEN e.Storage =  'ParentItem' THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN e.Storage <> 'ParentItem' THEN 1 ELSE 0 END) > 0
) pairs;


-- result 3: for those line pairs, what the pack delivers in total against the printed spool length.
-- Split = one spool divided between reel and bag. Plus = a whole spool and extra metres on the reel.
-- Below would mean the pack prints more than it gives.
SELECT COUNT(*) AS LinePairs,
       SUM(CASE WHEN Delivered =  Nominal THEN 1 ELSE 0 END) AS SplitOneSpool,
       SUM(CASE WHEN Delivered >  Nominal THEN 1 ELSE 0 END) AS FullSpoolPlusMounted,
       SUM(CASE WHEN Delivered <  Nominal THEN 1 ELSE 0 END) AS DeliversLessThanPrinted
FROM (
  SELECT e.ProductId, e.ItemId,
         SUM(e.Cnt)          AS Delivered,
         MAX(it.DeliveredCount) AS Nominal
  FROM #entry e
  JOIN #item it ON it.ItemId = e.ItemId AND it.Kind = 'line'
  GROUP BY e.ProductId, e.ItemId
  HAVING SUM(CASE WHEN e.Storage =  'ParentItem' THEN 1 ELSE 0 END) > 0
     AND SUM(CASE WHEN e.Storage <> 'ParentItem' THEN 1 ELSE 0 END) > 0
) pairs;


-- result 4: the printed length against the delivered one at item level, per kind.
-- For a line these should be the same number. For a leader they legitimately differ - the printed
-- value is the length of one piece, the count is how many pieces - so that row is a control, not a defect.
SELECT Kind,
       COUNT(*) AS Items,
       SUM(CASE WHEN PrintedNumber =  DeliveredCount THEN 1 ELSE 0 END) AS Agree,
       SUM(CASE WHEN PrintedNumber <> DeliveredCount THEN 1 ELSE 0 END) AS Disagree,
       SUM(CASE WHEN PrintedNumber IS NULL THEN 1 ELSE 0 END)           AS Unparsed
FROM (
  SELECT Kind, DeliveredCount,
         TRY_CAST(LEFT(PrintedLength, NULLIF(CHARINDEX(' ', PrintedLength), 0) - 1) AS int) AS PrintedNumber
  FROM #item
) parsed
GROUP BY Kind;


-- result 4b: the disagreeing lines themselves, if result 4 shows any.
SELECT TOP 50 ItemId, Name, CategoryId, DeliveredCount, PrintedLength
FROM #item
WHERE Kind = 'line'
  AND TRY_CAST(LEFT(PrintedLength, NULLIF(CHARINDEX(' ', PrintedLength), 0) - 1) AS int) <> DeliveredCount
ORDER BY ItemId;


-- result 5: DEV ONLY. Who authored the 1200 m of Catfish Moustache Line (31250) in the
-- Supernatural Explorer Pack. ItemJson is stored pretty-printed inside DataChanges, so the token
-- carries a space after the colon and the quotes are escaped - matching on '"ItemId":31250' finds nothing.
-- FP-46200 who set 1200 m of line 31250 (loose match)
SELECT TOP 50
    CONVERT(varchar(19), [Timestamp], 120) AS Changed,
    ChangeType, CreatedBy, Comment,
    SUBSTRING(NewValues, NULLIF(CHARINDEX('31250', NewValues), 0) - 60, 260) AS Fragment
FROM dbo.DataChanges WITH (NOLOCK)
WHERE TableName = 'Products'
  AND (NewValues LIKE '%31250%' OR OldValues LIKE '%31250%')
ORDER BY [Timestamp];