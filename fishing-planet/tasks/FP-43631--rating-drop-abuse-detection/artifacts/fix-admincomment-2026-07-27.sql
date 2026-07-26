-- FP-43631 -- strip internal review-method wording from Profiles.AdminComment
-- ============================================================================
-- The weekly ban scripts for cycles 6-12 appended an internal description of how the case was
-- reviewed into the player-facing admin note. That wording describes our internal process and
-- does not belong in a production player record; the note should carry the reason and the
-- duration only.
--
-- Removes exactly two substrings, leaving the rest of the comment byte-identical:
--   ", adversarial-reviewed: prosecutor/defense/judge per case"   (cycles 6-11)
--   ", reviewed: prosecutor/defense/judge per case"               (cycle 12)
--
-- Effect on a row:
--   before: ... rating-drop abuse (week-8, adversarial-reviewed: prosecutor/defense/judge per case) (NEW until 2026-07-13)
--   after:  ... rating-drop abuse (week-8) (NEW until 2026-07-13)
--
-- Comments are multi-line for repeat offenders (entries separated by CRLF); REPLACE is applied
-- across the whole value, so every affected entry in a multi-line note is cleaned in one pass.
--
-- Idempotent: after the replace the WHERE predicate no longer matches, so re-running is a no-op.
-- Affects only rows whose comment contains the marker; no other profile is touched.
--
-- Run on each platform PROD MAIN. Expected row counts at time of writing:
--   [F2P] STEAM PROD MAIN -> 20   (16 from cycles 6-11 + 4 from cycle 12)
--   [F2P] PS    PROD MAIN -> 27   (26 + 1)
--   [F2P] XB    PROD MAIN -> 5    (4 + 1)
--
-- Atomic: SET XACT_ABORT ON auto-rolls-back on any error. Inspect the verify SELECT, then
-- COMMIT TRAN (or ROLLBACK TRAN) by hand.

SET XACT_ABORT ON;
SET NOCOUNT ON;

BEGIN
    DECLARE @Matched int;

    BEGIN TRAN;

    -- Snapshot the affected rows so the verify step can show before/after side by side
    IF OBJECT_ID('tempdb..#Before') IS NOT NULL DROP TABLE #Before;
    SELECT p.UserId, p.AdminComment AS CommentBefore
    INTO #Before
    FROM Profiles p WITH (NOLOCK)
    WHERE p.AdminComment LIKE '%prosecutor/defense/judge%';

    SELECT @Matched = COUNT(*) FROM #Before;
    PRINT CONCAT('Rows matching on this DB: ', @Matched);

    UPDATE p
    SET p.AdminComment =
        REPLACE(
            REPLACE(p.AdminComment, ', adversarial-reviewed: prosecutor/defense/judge per case', ''),
            ', reviewed: prosecutor/defense/judge per case', '')
    FROM Profiles p
    INNER JOIN #Before b ON b.UserId = p.UserId;

    PRINT CONCAT('Rows updated: ', @@ROWCOUNT);

    -- Verify: Residual must be 0 on every row; CommentAfter should differ from CommentBefore
    -- only by the removed phrase.
    SELECT u.Username,
           b.CommentBefore,
           p.AdminComment AS CommentAfter,
           LEN(b.CommentBefore) - LEN(p.AdminComment) AS CharsRemoved,
           CASE WHEN p.AdminComment LIKE '%prosecutor/defense/judge%' THEN 'FAIL: residual' ELSE 'OK' END AS Status
    FROM #Before b
    INNER JOIN Profiles p WITH (NOLOCK) ON p.UserId = b.UserId
    LEFT JOIN Users    u WITH (NOLOCK) ON u.UserId = b.UserId
    ORDER BY u.Username;

    -- Global residual check across the whole table, not just the snapshot
    SELECT COUNT(*) AS ResidualRowsOnThisDb
    FROM Profiles p WITH (NOLOCK)
    WHERE p.AdminComment LIKE '%prosecutor/defense/judge%';

    DROP TABLE #Before;

    -- After visual inspection pick ONE:
    -- COMMIT TRAN;
    -- ROLLBACK TRAN;
END;
