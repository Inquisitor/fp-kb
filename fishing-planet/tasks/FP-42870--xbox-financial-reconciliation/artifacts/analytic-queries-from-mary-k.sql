-- Queries used by our analyst (Mary K) to pull paying-user data for reporting.
-- Source: Stats database (TransactionFact + TransactionFactBundle), cross-joined
-- to Main database (Transactions, Products, Users).
--
-- Pipeline overview:
--   Transactions (Main) -> TransactionFact (Stats, via ETL)
--   DetectBundlePurchasesJob (hourly) -> TransactionFactBundle + TransactionFact.BundleTransactionId
--   These queries consume the post-detection state, collapsing N component rows
--   into 1 bundle row per detected bundle purchase.

-- ---------------------------------------------------------------------------
-- Step 1: Pull paid transactions for the period into #temp1.
--   - Only "Complete" rows (Main.Transactions as the authoritative status source)
--   - Only rows with ProductPriceUsd > 0 (paid sales, excludes freebies)
--   - Joins: TransactionFact (facts/metadata), Main.Transactions (status),
--            Main.Products (for raw product info), Main.Users (profile enrichment)
--   - Preserves raw BundleTransactionId (non-null where detection linked a component to a bundle)
-- ---------------------------------------------------------------------------
SELECT
    [t].[userid],
    [CreationDate],
    [LastActivitydate],
    [t].[level],
    [t].[TransactionId],
    [ProductPriceUsd],
    [typeid]                                                      AS [ProductTypeId],
    [Currency],
    CONVERT(DATETIME, CONVERT(VARCHAR(16), [t].[timestamp], 120)) AS [Timestamp],
    [Name],
    [EquivalentPrice],
    [BundleTransactionId]
INTO [#temp1]
FROM [TransactionFact] AS [t] WITH (NOLOCK)
         JOIN      [Transactions] [tz] WITH (NOLOCK)
                   ON [tz].[userid] = [t].[userid] AND [tz].[TransactionId] = [t].[TransactionId] AND
                      [tz].[Status] = 'Complete'
         LEFT JOIN [Products] [p] WITH (NOLOCK) ON [t].[productid] = [p].[productid]
         JOIN      [Users] [u] WITH (NOLOCK) ON [u].[userid] = [t].[userid]
WHERE [t].[timestamp] > '20260406'
  AND [ProductPriceUsd] > 0

-- ---------------------------------------------------------------------------
-- Step 2: Collapse bundle components into single bundle rows (#TransactionFact1).
--   - LEFT JOIN to TransactionFactBundle brings in bundle-level price/id
--   - ISNULL fallbacks: if a row IS part of a detected bundle, use bundle values;
--     otherwise fall back to the component's own values (standalone purchase)
--   - WHERE ... IN (SELECT MIN(TransactionId) GROUP BY ISNULL(BundleTransactionId, TransactionId))
--     keeps only ONE row per bundle (the component with the lowest TransactionId stands in),
--     effectively deduplicating N-component rows into 1 bundle row.
--   - Net effect: standalone purchases stay 1:1; detected bundles go from N rows to 1.
-- ---------------------------------------------------------------------------
SELECT
    [UserId],
    [CreationDate],
    [Timestamp],
    [Level],
    [Name],
    [tf].[ProductTypeId],
    [Currency],
    [BundleTransactionId],
    ISNULL([tfb].[ProductPriceUsd], [tf].[ProductPriceUsd]) AS [ProductPriceUsd],
    ISNULL([tfb].[BundleId], [tf].[TransactionId])          AS [TransactionId],
    ISNULL([tfb].[EquivalentPrice], [tf].[EquivalentPrice]) AS [EquivalentPrice]
INTO [#TransactionFact1]
FROM [#temp1] [tf]
         LEFT JOIN [TransactionFactBundle] [tfb] ON [tf].[BundleTransactionId] = [tfb].[BundleId]
WHERE [TransactionId] IN
      (
          SELECT
              MIN([Transactionid])
          FROM [#temp1] [tf]
                   LEFT JOIN [TransactionFactBundle] [tfb] ON [tf].[BundleTransactionId] = [tfb].[BundleId]
          GROUP BY ISNULL([tf].[BundleTransactionId], [TransactionId]))

-- ---------------------------------------------------------------------------
-- Step 3: Relabel detected bundles with human-readable names.
--   - Hardcoded heuristic: patterns in component names identify which bundle
--     the row came from. Only relabels rows where BundleTransactionId is set
--     (i.e. actually detected as part of a bundle).
--   - Rough and covers only Sport/Lucky families — reflects the current
--     analytics-level shortcut, not a comprehensive solution.
-- ---------------------------------------------------------------------------
UPDATE [#TransactionFact1]
SET [Name] =
        CASE
            WHEN [Name] LIKE '%Sport%' AND [BundleTransactionId] IS NOT NULL THEN 'Sport bundle'
            WHEN [Name] LIKE '%Dragon%' AND [BundleTransactionId] IS NOT NULL THEN 'Lucky bundle'
            WHEN [Name] LIKE '%Lucky%' AND [BundleTransactionId] IS NOT NULL THEN 'Lucky bundle'
            ELSE [Name]
            END
