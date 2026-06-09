USE [Stats];
GO

-- 1. Дропаємо стару таблицю 
DROP TABLE dbo.StatsFact_old;
GO

-- 2. Подивитись як фонове звільнення йде
SELECT
    name AS logical_name,
    size * 8 / 1024 / 1024 AS total_gb,
    (size - FILEPROPERTY(name, 'SpaceUsed')) * 8 / 1024 / 1024 AS free_gb,
    FILEPROPERTY(name, 'SpaceUsed') * 8 / 1024 / 1024 AS used_gb
FROM sys.database_files WHERE type = 0;
GO

-- 3. Швидкий TRUNCATEONLY (першим)
DBCC SHRINKFILE (N'Stats', TRUNCATEONLY); 
GO

-- 4. Перевірка
EXEC xp_fixeddrives;
GO

-- Якщо TRUNCATEONLY звільнив достатньо — на цьому все.
-- Якщо ні - далі повний SHRINK (можна після запуску прода)
DBCC SHRINKFILE (N'Stats', 1400000);   -- цільовий розмір у МБ
GO