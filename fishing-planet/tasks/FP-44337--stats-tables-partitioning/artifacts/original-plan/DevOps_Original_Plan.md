1. STOP PROD
2. (delta sync якщо ще не зроблено) -> BCP файл
3. DROP TABLE dbo.StatsFact_old      <- 1 хвилина
4. Створити нову партиційовану структуру  <- 10 хвилин
5. START PROD                         <- downtime закінчився!
6. У фоні: DBCC SHRINKFILE — нехай гудить кілька годин
   поки PSPROD працює нормально