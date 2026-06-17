/*
    FP-44465 - LocalShop pricing audit (read-only)
    -----------------------------------------------
    Every LocalShop row: ALL ponds (incl. 119), ALL items. Shows how each
    current local price relates to the item's global price.
      Markup = 'x1.0'  -> local equals global
               'x1.5'  -> local equals ROUND(global*1.5, 0)
               'other' -> anything else (own discount / legacy / stale value)
    Names via Translations, LanguageId = 3 (English).
    Tip: append  "WHERE ls.PondId <> 119"  to hide the FTUE tutorial pond.
*/
SELECT
    ls.PondId                                            AS PondId,
    pt.String                                            AS PondName,
    ls.ItemId                                            AS ItemId,
    itr.String                                           AS ItemName,
    rt.String                                            AS ItemRarity,
    ii.Price                                             AS GlobalPrice,
    ii.Currency                                          AS Currency,
    ls.Price                                             AS LocalPrice,
    CAST(ls.Price / NULLIF(ii.Price, 0) AS decimal(10,3)) AS LocalToGlobalRatio,
    CASE
        WHEN ABS(ls.Price - ii.Price) < 0.001              THEN 'x1.0'
        WHEN ABS(ls.Price - ROUND(ii.Price*1.5,0)) < 0.001 THEN 'x1.5'
        ELSE 'other'
    END                                                  AS Markup
FROM LocalShop ls WITH (NOLOCK)
JOIN InventoryItems ii WITH (NOLOCK)     ON ii.ItemId = ls.ItemId
LEFT JOIN Translations itr WITH (NOLOCK) ON itr.TranslationId = ii.NameSID AND itr.LanguageId = 3
LEFT JOIN Ponds p WITH (NOLOCK)          ON p.PondId = ls.PondId
LEFT JOIN Translations pt WITH (NOLOCK)  ON pt.TranslationId = p.NameSID  AND pt.LanguageId = 3
LEFT JOIN ItemRarety r WITH (NOLOCK)     ON r.UniquenessId = ii.RaretyId
LEFT JOIN Translations rt WITH (NOLOCK)  ON rt.TranslationId = r.NameSID  AND rt.LanguageId = 3
ORDER BY ls.PondId, ii.RaretyId, ls.ItemId;


/* =========================================================================
   RARITY x CURRENCY distribution over the whole InventoryItems catalog.
   Used to spot wrong currency/rarity pairings (e.g. Common items sold for
   Gold/baitcoins - items 642/644). Expected: Common -> SC (Cash),
   Premium/Unique -> GC (Gold).
   ========================================================================= */
SELECT
    ii.RaretyId                          AS RaretyId,
    rt.String                            AS ItemRarity,
    ii.Currency                          AS Currency,
    COUNT(*)                             AS ItemCount,
    SUM(CASE WHEN ii.IsActive = 1 THEN 1 ELSE 0 END) AS ActiveCount
FROM InventoryItems ii WITH (NOLOCK)
LEFT JOIN ItemRarety r WITH (NOLOCK)     ON r.UniquenessId = ii.RaretyId
LEFT JOIN Translations rt WITH (NOLOCK)  ON rt.TranslationId = r.NameSID AND rt.LanguageId = 3
GROUP BY ii.RaretyId, rt.String, ii.Currency
ORDER BY ii.RaretyId, ii.Currency;
