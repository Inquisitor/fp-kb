/*
    FP-44465 [FTUE][Local shop] Bass Jigs - fix local-shop prices (with DataChanges audit)
    -------------------------------------------------------------------------------------
    Target: DEV (validate first on the local copy of DEV).

    Rule (matches the game-wide local-shop convention):
        Premium (RaretyId = 3) -> local = global price          (x1.0, GC)
        Common  (RaretyId = 1) -> local = ROUND(global * 1.5, 0)
    Scope: the 82 reworked bass-jig IDs, all ponds EXCEPT 119 (FTUE tutorial).

    The APPLY block reproduces the admin DataEditing behaviour: every changed row is recorded
    in DataChanges - a change/commit log (author, comment, old/new payload) from which changes
    can later be extracted, replayed or rolled back for recovery (e.g. via DataChangesImport,
    which builds "UPDATE <table> SET <non-PK keys> WHERE <PK>").
      - Captured payload is the clean {ShopId, Price} delta only (PK = ShopId). The admin also
        leaks the read-only join columns Currency/OriginalPrice into the capture; they are
        excluded here because those columns do not exist on LocalShop, so any UPDATE-based
        replay/restore would fail on them.
      - Timestamp is left to the column default (getutcdate()), as DataCapture does.
*/

-- =========================================================================
-- 1) PREVIEW (read-only) - rows that will change
-- =========================================================================

-- PREVIEW (read-only) - rows that will change
WITH ids(ItemId) AS (
    SELECT v FROM (VALUES
    (451),(513),(514),(515),(516),(517),(539),(630),(631),(632),(633),(634),(635),(636),
    (640),(641),(642),(643),(644),(645),(646),(647),(648),(649),(650),(651),(652),(653),(654),(655),(656),
    (1030),(1031),(1032),(1033),(1254),(1255),(1256),(1257),(1258),(1259),(1260),(1261),(1262),(1263),
    (1264),(1265),(1266),(1267),(1268),(1463),(1464),
    (32670),(32671),(32672),(32673),(32674),(32675),(32676),(32677),(32678),(32679),(32680),(32681),
    (32682),(32683),(32684),(32685),(32686),(32688),(32689),(32690),(32691),(32692),(32693),(32694),
    (32695),(32696),(32697),(32698),(32699),(32700)
    ) t(v)
)
SELECT ls.ShopId, ls.PondId, pt.String AS PondName, ls.ItemId, itr.String AS ItemName,
       rt.String AS ItemRarity, ii.[Price] AS GlobalPrice, ii.Currency,
       ls.Price AS CurLocalPrice,
       CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price*1.5,0) END AS NewLocalPrice
FROM LocalShop ls WITH (NOLOCK)
JOIN ids x          ON x.ItemId = ls.ItemId
JOIN InventoryItems ii WITH (NOLOCK) ON ii.ItemId = ls.ItemId
LEFT JOIN Translations itr WITH (NOLOCK) ON itr.TranslationId = ii.NameSID AND itr.LanguageId = 3
LEFT JOIN Ponds p WITH (NOLOCK)          ON p.PondId = ls.PondId
LEFT JOIN Translations pt WITH (NOLOCK)  ON pt.TranslationId = p.NameSID  AND pt.LanguageId = 3
LEFT JOIN ItemRarety r WITH (NOLOCK)     ON r.UniquenessId = ii.RaretyId
LEFT JOIN Translations rt WITH (NOLOCK)  ON rt.TranslationId = r.NameSID  AND rt.LanguageId = 3
WHERE ls.PondId <> 119
  AND ABS(ls.Price - CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price*1.5,0) END) > 0.001
ORDER BY ls.PondId, [ItemRarity], [Currency], ls.ItemId;


-- =========================================================================
-- 2) APPLY (transactional: DataChanges audit + price update + validation)
-- =========================================================================
BEGIN
    SET XACT_ABORT, NOCOUNT ON;

    DECLARE @author  varchar(32)  = 'stas.samoilov';                 -- executing admin login
    DECLARE @comment varchar(128) = 'FP-44465 bass jig local prices';

    BEGIN TRY
        BEGIN TRAN;

        -- 2a) Audit BEFORE the update so OldValues captures the current price.
        INSERT INTO DataChanges (DataChangeId, TableName, ChangeType, OldValues, NewValues, Comment, CreatedBy)
        SELECT NEWID(), 'LocalShop', 'U',
               '{"ShopId":' + CONVERT(varchar(20), ls.ShopId) + ',"Price":' + CONVERT(varchar(40), CAST(ls.Price AS decimal(38,1))) + '}',
               '{"ShopId":' + CONVERT(varchar(20), ls.ShopId) + ',"Price":' + CONVERT(varchar(40), CAST(tgt.NewPrice AS decimal(38,1))) + '}',
               @comment, @author
        FROM LocalShop ls
        JOIN InventoryItems ii ON ii.ItemId = ls.ItemId
        CROSS APPLY (SELECT CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price * 1.5, 0) END AS NewPrice) tgt
        WHERE ls.PondId <> 119
          AND ls.ItemId IN (
              451,513,514,515,516,517,539,630,631,632,633,634,635,636,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,
              1030,1031,1032,1033,1254,1255,1256,1257,1258,1259,1260,1261,1262,1263,1264,1265,1266,1267,1268,1463,1464,
              32670,32671,32672,32673,32674,32675,32676,32677,32678,32679,32680,32681,32682,32683,32684,32685,32686,
              32688,32689,32690,32691,32692,32693,32694,32695,32696,32697,32698,32699,32700)
          AND ABS(ls.Price - tgt.NewPrice) > 0.001;

        DECLARE @audited int = @@ROWCOUNT;

        -- 2b) Apply the price update.
        UPDATE ls
        SET ls.Price = CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price * 1.5, 0) END
        FROM LocalShop ls
        JOIN InventoryItems ii ON ii.ItemId = ls.ItemId
        WHERE ls.PondId <> 119
          AND ls.ItemId IN (
              451,513,514,515,516,517,539,630,631,632,633,634,635,636,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,
              1030,1031,1032,1033,1254,1255,1256,1257,1258,1259,1260,1261,1262,1263,1264,1265,1266,1267,1268,1463,1464,
              32670,32671,32672,32673,32674,32675,32676,32677,32678,32679,32680,32681,32682,32683,32684,32685,32686,
              32688,32689,32690,32691,32692,32693,32694,32695,32696,32697,32698,32699,32700)
          AND ABS(ls.Price - CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price * 1.5, 0) END) > 0.001;

        DECLARE @updated int = @@ROWCOUNT;

        -- 2c) Validation: every audited row must have been updated, and no in-scope mismatch remains.
        DECLARE @remaining int = (
            SELECT COUNT(*)
            FROM LocalShop ls
            JOIN InventoryItems ii ON ii.ItemId = ls.ItemId
            WHERE ls.PondId <> 119
              AND ls.ItemId IN (
                  451,513,514,515,516,517,539,630,631,632,633,634,635,636,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,
                  1030,1031,1032,1033,1254,1255,1256,1257,1258,1259,1260,1261,1262,1263,1264,1265,1266,1267,1268,1463,1464,
                  32670,32671,32672,32673,32674,32675,32676,32677,32678,32679,32680,32681,32682,32683,32684,32685,32686,
                  32688,32689,32690,32691,32692,32693,32694,32695,32696,32697,32698,32699,32700)
              AND ABS(ls.Price - CASE WHEN ii.RaretyId = 3 THEN ii.Price ELSE ROUND(ii.Price * 1.5, 0) END) > 0.001
        );

        IF @audited = @updated AND @remaining = 0
        BEGIN
            COMMIT;
            PRINT CONCAT('COMMITTED. Updated: ', @updated, ', audited: ', @audited, ', remaining mismatches: 0.');
        END
        ELSE
        BEGIN
            ROLLBACK;
            RAISERROR('ROLLED BACK: updated=%d, audited=%d, remaining=%d (must be updated=audited and remaining=0).', 16, 1, @updated, @audited, @remaining);
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH;
END
