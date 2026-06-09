/* ============================================================================
   FP-44337  Phase 3  |  SERVER: PS PROD (MSSQL15.PSSTATS)
   IN THE DOWNTIME WINDOW, after Phase 2 (swap) and BEFORE START PROD.

   Pre-load the current-month (June) tail from *_old into the new tables so that
   incremental / recent-window consumers see a continuous history at restart.

   WHY before START (not online): FishingRateStatUpdateJob is incremental — it
   reads dbo.StatsFact WHERE EntityId > @lastCursor. Its cursor typically lags
   real time by ~1 hour. After the rename those unprocessed recent rows live only
   in StatsFact_old; the job reads the NEW table and would SKIP them, leaving a
   gap in fishing-rate stats. Loading the tail (with original EntityId via
   IDENTITY_INSERT; old ids < the new IDENTITY base, so no collision) restores
   continuity. Same reasoning protects any consumer that reads the last hrs/days.

   Reads *_old (static — prod is stopped). @tailFrom is FIXED at 2026-06-01 (a week
   of margin before the backup point) and MUST NOT be narrowed: keeping it <= the
   backup point is what makes {backup} U {new tables} gap-free for the Phase 6 drop.
   ============================================================================ */

USE [Stats];
GO

-- Control table: records the loaded id range + counts per table, so Phase 6 can
-- assert preload completeness before the irreversible drop.
IF OBJECT_ID('dbo.FP44337_TailLoadControl') IS NULL
    CREATE TABLE dbo.FP44337_TailLoadControl (
        TableName   SYSNAME    NOT NULL PRIMARY KEY,
        TailStartId BIGINT     NOT NULL,
        MaxOldId    BIGINT     NOT NULL,
        OldCount    BIGINT     NOT NULL,
        NewCount    BIGINT     NOT NULL,
        LoadedAt    DATETIME2  NOT NULL DEFAULT SYSUTCDATETIME()
    );
GO

DECLARE @tailFrom DATE = '2026-06-01';   -- FIXED. INVARIANT: @tailFrom <= backup point (2026-06-08 00:45).
                                          -- Do NOT narrow it — the gap-free guarantee for Phase 6 depends on it.

DECLARE @tables TABLE (name SYSNAME);
INSERT INTO @tables VALUES ('StatsFact'), ('MissionsFact');

DECLARE @t SYSNAME;
DECLARE c CURSOR LOCAL FAST_FORWARD FOR SELECT name FROM @tables;
OPEN c; FETCH NEXT FROM c INTO @t;
WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @old SYSNAME = @t + '_old';
    DECLARE @cols NVARCHAR(MAX);

    -- Explicit, ordered column list for the IDENTITY_INSERT insert (built from the table).
    SELECT @cols = STRING_AGG(QUOTENAME(name), ',') WITHIN GROUP (ORDER BY column_id)
    FROM sys.columns WHERE object_id = OBJECT_ID('dbo.' + @t);

    -- SAFETY before TRUNCATE: refuse if the new table already holds LIVE rows (someone ran Phase 3
    -- AFTER START PROD by mistake). Live ids are >= the new IDENTITY seed (MAX(old)+1,000,000) > MAX(old);
    -- tail ids are all <= MAX(old). So any EntityId > MAX(old) means live data -> abort, don't delete it.
    DECLARE @omax BIGINT, @live BIT = 0, @chk NVARCHAR(MAX);
    SET @chk = N'SELECT @x = MAX(EntityId) FROM dbo.' + QUOTENAME(@old) + N';';
    EXEC sp_executesql @chk, N'@x BIGINT OUTPUT', @omax OUTPUT;
    SET @chk = N'IF EXISTS (SELECT 1 FROM dbo.' + QUOTENAME(@t) + N' WHERE EntityId > @m) SET @l = 1;';
    EXEC sp_executesql @chk, N'@m BIGINT, @l BIT OUTPUT', @omax, @live OUTPUT;
    IF @live = 1
        THROW 50041, 'New table already has LIVE rows (EntityId > MAX(old)) - Phase 3 must NOT run after START PROD. Aborted.', 1;

    -- Idempotent re-run: clear any partial load from a prior aborted attempt (pre-START, no live data).
    -- TRUNCATE also resets identity to the seed.
    SET @chk = N'TRUNCATE TABLE dbo.' + QUOTENAME(@t) + N';';
    EXEC sp_executesql @chk;

    -- Tail-start EntityId boundary in *_old (binary search over the clustered PK).
    DECLARE @lo BIGINT, @hi BIGINT, @mid BIGINT, @midTs DATETIME, @jStart BIGINT;
    DECLARE @sqlb NVARCHAR(MAX) = N'SELECT @lo=MIN(EntityId),@hi=MAX(EntityId) FROM dbo.' + QUOTENAME(@old) + N' WITH (NOLOCK);';
    EXEC sp_executesql @sqlb, N'@lo BIGINT OUTPUT,@hi BIGINT OUTPUT', @lo OUTPUT, @hi OUTPUT;
    DECLARE @minId BIGINT = @lo;   -- preserve MIN before the binary search mutates @lo/@hi
    SET @jStart = @hi + 1;
    WHILE @lo <= @hi
    BEGIN
        SET @mid = @lo + (@hi - @lo) / 2;
        SET @sqlb = N'SELECT TOP 1 @ts=[Timestamp] FROM dbo.' + QUOTENAME(@old) + N' WITH (NOLOCK) WHERE EntityId >= @m ORDER BY EntityId ASC;';
        EXEC sp_executesql @sqlb, N'@m BIGINT,@ts DATETIME OUTPUT', @mid, @midTs OUTPUT;
        IF @midTs IS NULL OR @midTs >= @tailFrom BEGIN SET @jStart = @mid; SET @hi = @mid - 1; END
        ELSE SET @lo = @mid + 1;
    END

    -- Lower the start by a margin to also pull in any out-of-order June rows whose EntityId
    -- sits just below the boundary (identity-reseed / late-commit skew).
    -- DATA-SAFETY: the tail IS load-bearing now. {backup} (rows <= the ~2026-06-08 backup point)
    -- U {this tail} (from @tailFrom=2026-06-01 <= the backup point) covers every *_old row
    -- gap-free — that is exactly what the Phase 6 drop relies on. (The former Phase 4/5 SQLSTAGING
    -- delta was redundant and is removed.) A few late-May rows pulled in by the margin are harmless:
    -- they land in P1 (the left catch-all) and are also in the backup.
    SET @jStart = @jStart - 100000;
    IF @jStart < @minId SET @jStart = @minId;   -- clamp: never below the table's MIN(EntityId)

    -- Batched copy from @jStart to max id (SIMPLE recovery truncates between batches).
    DECLARE @maxId BIGINT;
    SET @sqlb = N'SELECT @x=MAX(EntityId) FROM dbo.' + QUOTENAME(@old) + N' WITH (NOLOCK);';
    EXEC sp_executesql @sqlb, N'@x BIGINT OUTPUT', @maxId OUTPUT;

    DECLARE @batch BIGINT = 2000000, @from BIGINT = @jStart, @to BIGINT;
    WHILE @from <= @maxId
    BEGIN
        SET @to = @from + @batch - 1;
        DECLARE @ins NVARCHAR(MAX) =
            N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' ON;' +
            N'INSERT INTO dbo.' + QUOTENAME(@t) + N' (' + @cols + N') ' +
            N'SELECT ' + @cols + N' FROM dbo.' + QUOTENAME(@old) + N' WITH (NOLOCK) ' +
            -- Load ONLY June+ (Timestamp >= @tailFrom). The id-range floor (@jStart, margin-lowered)
            -- guarantees no June row is missed even with id<->time skew; this filter drops the
            -- late-May collateral so the June partition is clean and SWITCH-able later.
            N'WHERE EntityId BETWEEN @f AND @tt AND [Timestamp] >= @tf;' +
            N'SET IDENTITY_INSERT dbo.' + QUOTENAME(@t) + N' OFF;';
        EXEC sp_executesql @ins, N'@f BIGINT,@tt BIGINT,@tf DATE', @from, @to, @tailFrom;
        SET @from = @to + 1;
    END
    PRINT 'Tail loaded: ' + @t + ' from id ' + CAST(@jStart AS VARCHAR(20));

    -- Verify the preload matches *_old over the loaded id range, and record it for the
    -- Phase 6 drop gate. The id range [@jStart, @maxId] is the OLD-id space; live inserts
    -- (ids >= MAX(old)+1,000,000) fall outside it, so this stays comparable even after START.
    DECLARE @oldCnt BIGINT, @newCnt BIGINT;
    -- old-count uses the SAME Timestamp filter as the load so it matches the new-count (new holds
    -- only the >= @tailFrom rows in the id range). Keeps this check — and the Phase 6 gate — honest.
    SET @sqlb = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@old) + N' WITH (NOLOCK) WHERE EntityId BETWEEN @a AND @b AND [Timestamp] >= @tf;';
    EXEC sp_executesql @sqlb, N'@a BIGINT,@b BIGINT,@tf DATE,@c BIGINT OUTPUT', @jStart, @maxId, @tailFrom, @oldCnt OUTPUT;
    SET @sqlb = N'SELECT @c=COUNT_BIG(*) FROM dbo.' + QUOTENAME(@t) + N' WHERE EntityId BETWEEN @a AND @b;';
    EXEC sp_executesql @sqlb, N'@a BIGINT,@b BIGINT,@c BIGINT OUTPUT', @jStart, @maxId, @newCnt OUTPUT;

    DELETE FROM dbo.FP44337_TailLoadControl WHERE TableName = @t;
    INSERT INTO dbo.FP44337_TailLoadControl (TableName, TailStartId, MaxOldId, OldCount, NewCount)
    VALUES (@t, @jStart, @maxId, @oldCnt, @newCnt);

    IF @oldCnt <> @newCnt
    BEGIN
        DECLARE @msg NVARCHAR(400) = N'Phase 3 preload MISMATCH for ' + @t
            + N': old=' + CAST(@oldCnt AS VARCHAR(20)) + N' new=' + CAST(@newCnt AS VARCHAR(20))
            + N'. Aborting — fix and re-run Phase 3 (idempotent) before START PROD.';
        THROW 50040, @msg, 1;   -- THROW aborts the batch (RAISERROR would NOT) -> fail fast, no START on a bad tail
    END
    ELSE
        PRINT 'Tail verified: ' + @t + ' rows=' + CAST(@newCnt AS VARCHAR(20))
            + ' (id ' + CAST(@jStart AS VARCHAR(20)) + '..' + CAST(@maxId AS VARCHAR(20)) + ')';

    FETCH NEXT FROM c INTO @t;
END
CLOSE c; DEALLOCATE c;
GO

-- Build the aligned, compressed NCI now — AFTER the bulk load, far cheaper than
-- maintaining it per-row during the tail insert. Offline on Standard; still in-window.
DROP INDEX IF EXISTS IX_StatsFact_UserId_Aligned ON dbo.StatsFact;
CREATE NONCLUSTERED INDEX IX_StatsFact_UserId_Aligned
ON dbo.StatsFact (UserId, [Timestamp])
WITH (DATA_COMPRESSION = PAGE)
ON ps_StatsFact_Timestamp([Timestamp]);
GO
DROP INDEX IF EXISTS IX_MissionsFact_UserId_Aligned ON dbo.MissionsFact;
CREATE NONCLUSTERED INDEX IX_MissionsFact_UserId_Aligned
ON dbo.MissionsFact (UserId, [Timestamp])
WITH (DATA_COMPRESSION = PAGE)
ON ps_MissionsFact_Timestamp([Timestamp]);
GO

-- Sanity: new tables hold the tail (continuity for incremental consumers).
SELECT 'StatsFact'    AS tbl, COUNT_BIG(*) rows_now, MIN([Timestamp]) min_ts, MAX([Timestamp]) max_ts FROM dbo.StatsFact    WITH (NOLOCK)
UNION ALL
SELECT 'MissionsFact',        COUNT_BIG(*),          MIN([Timestamp]),        MAX([Timestamp])         FROM dbo.MissionsFact WITH (NOLOCK);
GO

-- >>> Tail present, NCI built, counts verified: START PROD. Then proceed to Phase 6 (online). <<<
