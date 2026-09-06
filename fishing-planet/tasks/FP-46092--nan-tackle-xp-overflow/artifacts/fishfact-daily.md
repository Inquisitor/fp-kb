# FishFact daily profile, user 88236613-788f-4fcc-a8b5-7b229b8ed1fc

Source: Steam PROD Stats `FishFact`, `GeneratedAt >= 2026-07-20`, grouped by UTC day. Pulled 2026-09-06.
`fight*` = `FishFightDurationSeconds` over caught fish; `w*` = weight (kg) over caught fish;
`distAvg` = `HookedDistance` over hooked fish; `attackAvg` = `FinishAttackSeconds` over hooked fish;
`boat` = rows with `BoatType > 0`. Denuvo detections start 2026-09-03.

| Day        | gen | hooked | caught | esc | broken | fightAvg | fightMax | wAvg  | wMax   | distAvg | attackAvg | expSum        | boat |
|------------|-----|--------|--------|-----|--------|----------|----------|-------|--------|---------|-----------|---------------|------|
| 2026-08-07 | 150 | 29     | 27     | 2   | 0      | 25.8     | 181.6    | 15.14 | 39.09  | 15.8    | 13.6      | 36,084        | 7    |
| 2026-08-08 | 129 | 30     | 30     | 0   | 0      | 29.2     | 610.9    | 9.80  | 54.59  | 18.9    | 14.0      | 15,805        | 1    |
| 2026-08-20 | 22  | 10     | 10     | 0   | 0      | 12.0     | 19.3     | 3.83  | 8.37   | 30.8    | 14.8      | 958           | 10   |
| 2026-08-21 | 16  | 11     | 10     | 1   | 0      | 21.8     | 32.9     | 9.00  | 30.40  | 46.7    | 23.4      | 2,067         | 0    |
| 2026-08-25 | 57  | 26     | 26     | 0   | 0      | 15.5     | 77.2     | 6.86  | 47.69  | 29.4    | 20.6      | 5,535         | 3    |
| 2026-08-29 | 14  | 6      | 6      | 0   | 0      | 13.2     | 46.1     | 15.15 | 74.84  | 22.2    | 18.8      | 4,038         | 4    |
| 2026-08-30 | 238 | 36     | 35     | 1   | 0      | 73.4     | 1148.2   | 28.21 | 292.53 | 28.0    | 16.5      | 97,603        | 34   |
| 2026-08-31 | 370 | 66     | 63     | 2   | 0      | 64.6     | 591.7    | 37.78 | 173.87 | 41.3    | 18.7      | 447,590       | 168  |
| 2026-09-01 | 389 | 47     | 44     | 2   | 0      | 11.5     | 43.0     | 8.85  | 28.26  | 19.8    | 12.8      | 35,036        | 0    |
| 2026-09-03 | 77  | 18     | 17     | 1   | 0      | 7.0      | 11.5     | 66.57 | 273.98 | 46.2    | 9.5       | 256,399       | 70   |
| 2026-09-04 | 22  | 4      | 3      | 1   | 0      | 5.1      | 5.2      | 96.88 | 122.52 | 31.7    | 8.4       | 39,593        | 22   |
| 2026-09-05 | 285 | 106    | 100    | 4   | 2      | 10.8     | 212.8    | 35.71 | 325.26 | 47.1    | 11.4      | 1,074,310,794 | 163  |
| 2026-09-06 | 447 | 143    | 142    | 2   | 0      | 13.6     | 456.9    | 41.47 | 487.78 | 31.9    | 12.1      | 1,074,860,558 | 279  |

Reading: heavy fish before 2026-09-03 (max 293 kg on 08-30, 174 kg on 08-31) took 65-73 s on average
with fights up to 19 minutes; from 2026-09-03 the average weight of a caught fish rises to 36-97 kg
(max 274-488 kg) while the average fight drops to 5-14 s. The two days with `expSum` above 1e9 are the
overflow catches (FP-46092).
