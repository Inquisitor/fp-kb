---
date: 2026-05-18
operation: week-2 ban execution — per-user record with pre-ban abuse stats
scripts_run:
  - week2-ban-execution.sql (Profile ban + LB ban + Influencer reset + AdminComment audit, atomic XACT_ABORT)
  - leaderboard-ban-sync.sql (LB-row top-up for pre-existing Profile bans)
admin_comment_applied_to_all: 'Auto-ban by Stan via FP-43631 follow-up 2026-05-17 — no-show abuse (week-2 comparison) (<Verdict> until <BanUntil>)'
ban_until:
  CONTINUED: 2026-06-17 (4 weeks)
  STARTED:   2026-06-01 (2 weeks)
totals:
  steam: 75
  ps: 84
  xbox: 26
  grand_total: 185
sync_topup:
  steam: 101
  ps: 46
  xbox: 3
  grand_total: 150
final_lb_banned_rows_active_profiles:
  steam_weekly: 102
  steam_monthly: 113
  steam_yearly: 113
  ps_weekly: 98
  ps_monthly: 100
  ps_yearly: 100
  xbox_weekly: 27
  xbox_monthly: 27
  xbox_yearly: 27
  grand_total: 707
skipped_expired_profile_bans:
  steam: 143
  ps: 149
  xbox: 8
  grand_total: 300
---
# Executed bans — 2026-05-18 (FP-43631 follow-up week 2)

Per-user record of the bans applied across STEAM / PS / Xbox PROD on 2026-05-18.

Columns:
- **Old:** `NoShows / SharePct / RatingFromNoShow_DQ` for the **2026-04-29 → 2026-05-10** window (only for CONTINUED — STARTED users were not in the old cohort by definition)
- **New:** same stats for the **2026-05-11 → 2026-05-18** window
- **PCR:** `Profiles.CompetitionRating` at the time of the comparison; "—" means NULL (player has no PCR record yet)

For every row below, the script set:
- `Profiles.IsCompetitionsBanned = 1`
- `Profiles.CompetitionsBanEndDate = <BanUntil>` (2026-06-17 for CONTINUED, 2026-06-01 for STARTED)
- `Profiles.AdminComment` appended with `Auto-ban by Stan via FP-43631 follow-up 2026-05-17 — no-show abuse (week-2 comparison) (<Verdict> until <BanUntil>)`
- `CompetitiveRatingsCurrent.IsBanned = 1` across all three current periods (Weekly `20260511` / Monthly `20260501` / Yearly `20260101`)
- `Profiles.IsInfluencer = 0` if previously 1 (no one in this cohort was an influencer; rows showing `IsInfluencer=false` already had it set false)

**New entrants** (rows marked `🆕` below): users who appeared in the cohort between the planning snapshot (`bans-2026-05-18.md`) and the actual script execution, so their pre-ban stats are not preserved in this artifact. They were caught by the script's own derivation of CohortOld/CohortNew at execution time.

## STEAM (75)

### CONTINUED → 2026-06-17 (37)

| #  | Username          | UserId                                 | Old (N / % / RFNS)                                                                       | New (N / % / RFNS) | PCR  |
|----|-------------------|----------------------------------------|------------------------------------------------------------------------------------------|--------------------|------|
| 1  | AC_GAMEBOT        | `3E9CF475-DF93-4A27-AF1A-3E39E7D7DF1A` | 16 / 30.77% / −196                                                                       | 10 / 34.48% / −150 | 878  |
| 2  | BolinhaWJB        | `AF03131F-0553-4EA3-BB33-480D4C0B1D3C` | 18 / 54.55% / −252                                                                       | 7 / 77.78% / −97   | 791  |
| 3  | chenmuya          | `7F670DAC-AA1B-4C86-B264-FAA1DBB8A7A7` | 17 / 85% / −237                                                                          | 11 / 61.11% / −158 | 86   |
| 4  | chinaDF5C         | `F4C50336-CFF0-42EF-8934-4E73DB14F0B7` | 35 / 30.7% / −479                                                                        | 14 / 33.33% / −178 | 1104 |
| 5  | Edukoi            | `C252A85E-94E5-4E10-88A3-CEAC37A85A9D` | 33 / 94.29% / −417                                                                       | 49 / 92.45% / −683 | 118  |
| 6  | EsseDouble        | `F80DF54F-B077-4665-9822-A43414055B1E` | 18 / 46.15% / −234                                                                       | 24 / 58.54% / −347 | 37   |
| 7  | fomaka8           | `D9B3468F-50EC-43A9-BCB1-266C75D9B6D3` | 28 / 43.08% / −378                                                                       | 49 / 65.33% / −685 | 52   |
| 8  | FT.ZZZ            | `AE005A2A-313A-4412-BE77-A80FDFB7A454` | 73 / 96.05% / −1004                                                                      | 26 / 96.3% / −377  | 997  |
| 9  | FUMATII-ESTAA     | `7A0F9E1F-441B-4DC7-9286-E1DAE75D88A6` | 22 / 62.86% / −296                                                                       | 20 / 74.07% / −296 | 963  |
| 10 | IFC_DIT-TO        | `746BE21D-AD49-4224-9CBE-2BB96EFC0B5C` | 41 / 83.67% / −553                                                                       | 50 / 98.04% / −720 | 1343 |
| 11 | IkanBobo          | `CD4A6026-713B-4A9C-995A-8970F18FBD33` | 26 / 31.33% / −365                                                                       | 12 / 30% / −179    | 948  |
| 12 | JAMNF13           | `652885CD-DBA6-4E2F-AD8F-8B91FCAF805B` | 12 / 46.15% / −150                                                                       | 7 / 77.78% / −95   | 0    |
| 13 | LeeooRP           | `7043D475-A8F7-4421-BDF1-F3256FB9D4FC` | 78 / 85.71% / −1081                                                                      | 8 / 47.06% / −122  | 146  |
| 14 | lin-123           | `8E756E04-1A3D-471C-9C10-A55F6023BB1F` | 46 / 70.77% / −614                                                                       | 19 / 51.35% / −314 | 1008 |
| 15 | Master10086       | `68C047FC-9F03-4195-8A59-E1D258EB9253` | 33 / 66% / −430                                                                          | 12 / 41.38% / −175 | 121  |
| 16 | MOF_Adriano       | `06CA0E9C-8EBB-4456-A94E-8D1D407A30C3` | 20 / 54.05% / −232                                                                       | 10 / 71.43% / −118 | 1702 |
| 17 | Myky0576          | `B8CA6B12-3057-4BBE-9980-53F655FCF065` | 14 / 35% / −203                                                                          | 18 / 62.07% / −257 | 25   |
| 18 | NicePoopMachine11 | `C4D9C8FA-613C-4F4F-92C1-94979367161D` | 24 / 38.71% / −298                                                                       | 7 / 50% / −104     | 415  |
| 19 | nM.Wokka          | `23EF4804-3530-4917-B3D0-03C9E862AB6B` | 46 / 100% / −624                                                                         | 10 / 100% / −152   | 904  |
| 20 | NotoriousOne      | `BF3D187D-1B30-45CF-8C50-FB43B1439669` | 76 / 74.51% / −1025                                                                      | 18 / 64.29% / −224 | 76   |
| 21 | O7_MR             | `0D08DBC9-EABA-4B72-B806-2FB5E22845AB` | 36 / 72% / −507                                                                          | 10 / 71.43% / −145 | 1418 |
| 22 | o-huo             | `B71D270F-FA17-4E99-9AE6-8F7169379449` | 38 / 79.17% / −523                                                                       | 22 / 73.33% / −336 | 0    |
| 23 | PKOne_official    | `B6825B26-A30B-4063-A21B-61359F8B92EC` | 46 / 58.23% / −624                                                                       | 11 / 44% / −144    | 86   |
| 24 | rambo04           | `551A9CFD-D2ED-4D40-822E-7956DA9EFCE5` | 62 / 73.81% / −814                                                                       | 18 / 66.67% / −257 | 124  |
| 25 | Rodmaster88       | `E7E26744-FB2E-4C5A-8851-949EAA8D219C` | 41 / 78.85% / −474                                                                       | 23 / 74.19% / −328 | 0    |
| 26 | ScummyLIVE        | `5B3F6D46-004B-4EB6-A823-E9153BF75463` | 17 / 94.44% / −266                                                                       | 32 / 61.54% / −467 | 47   |
| 27 | Serega_MiG 🆕     | `15BCB6AB-60DB-4AE0-9B8E-91AC3ED01A1C` | (no pre-snapshot — was in STOPPED at planning time, crossed thresholds before execution) | —                  | —    |
| 28 | Sne4CKy           | `11363837-35D7-43D2-BD9D-A3044F35C5A3` | 29 / 69.05% / −398                                                                       | 11 / 34.38% / −157 | 119  |
| 29 | TheBestAHFan      | `B8428B8D-7EBF-4924-A9ED-29CB02CE01FC` | 22 / 84.62% / −301                                                                       | 31 / 81.58% / −439 | 0    |
| 30 | tsukuyxmi         | `22ACF515-3D8E-4554-B5A0-FAAB06A0D4B2` | 86 / 86% / −1164                                                                         | 24 / 88.89% / −348 | 0    |
| 31 | UKROP_UA          | `741CE389-345E-4D53-8A46-E2CB3F026902` | 28 / 46.67% / −352                                                                       | 50 / 73.53% / −684 | 532  |
| 32 | vodou61           | `14B955CA-2044-4171-BD98-E768418878C8` | 94 / 89.52% / −1224                                                                      | 8 / 66.67% / −122  | 128  |
| 33 | W0lfver1ne        | `80C34ED9-A35F-4FC7-8C6F-7A6578B47E86` | 24 / 54.55% / −324                                                                       | 16 / 76.19% / −240 | 0    |
| 34 | wanyi12138        | `56189F57-F7DF-4DC7-837C-0F10533E26EA` | 73 / 69.52% / −921                                                                       | 23 / 52.27% / −312 | 91   |
| 35 | X1aoDouYa         | `135725A2-637F-44F3-8389-DF61B85F4E67` | 56 / 93.33% / −773                                                                       | 18 / 94.74% / −310 | 462  |
| 36 | X-SacredAngler    | `95C8F164-8BAF-467E-9826-9CAFDCFA968E` | 43 / 50.59% / −592                                                                       | 13 / 44.83% / −197 | 960  |
| 37 | Zoio_Bruxo157     | `0A030AA4-E9DD-4C88-B0B0-934003AFC79A` | 59 / 70.24% / −782                                                                       | 9 / 56.25% / −137  | 110  |

### STARTED → 2026-06-01 (38)

| #  | Username                                   | UserId                                 | New (N / % / RFNS)                                          | PCR  |
|----|--------------------------------------------|----------------------------------------|-------------------------------------------------------------|------|
| 1  | Batu38                                     | `0AE5B8CD-F06E-4CF5-BD0C-3C2D945632D8` | 9 / 50% / −123                                              | 69   |
| 2  | CirnoOOObaka                               | `6F8D28F6-E440-40CB-8CCE-6161C3B48765` | 11 / 44% / −151                                             | 156  |
| 3  | EmersonSparky                              | `F1FDC8D1-6090-4A4A-B6BA-D61EC5087034` | 8 / 72.73% / −92                                            | 802  |
| 4  | FigaroFegget                               | `A3E0ADCB-FB01-4B6E-8809-D3D0DE48CE8B` | 12 / 100% / −180                                            | —    |
| 5  | FOGGIA1920                                 | `10A0FFF3-E631-413B-B5FA-30208635F2A6` | 11 / 84.62% / −169                                          | 0    |
| 6  | GloomyBayOutlaw                            | `261B0BA0-5BE1-4EC1-95BC-BD2350FE2FDA` | 10 / 55.56% / −143                                          | 75   |
| 7  | GrayPlanktonPaladin                        | `342E02E6-2369-4F00-BE91-012D1BC924D5` | 9 / 100% / −140                                             | —    |
| 8  | irvin85                                    | `A686254B-4451-4609-968F-10CBA4BE9505` | 7 / 77.78% / −90                                            | 936  |
| 9  | JFF_Gothyka                                | `13D390E6-0CB7-4F30-9846-24CC994BBDE2` | 9 / 47.37% / −134                                           | 333  |
| 10 | JFF_Vinss62                                | `7BA48B70-CF01-4671-8183-E11DDB5E5B63` | 7 / 53.85% / −112                                           | 565  |
| 11 | KOP_LR07 🆕                                | `3F0B7ECB-E81B-4123-974D-F1F6A4F77B3E` | (no pre-snapshot — appeared between planning and execution) | —    |
| 12 | KOP_Speedy                                 | `DEC5654D-3307-4CE3-ACFB-187AF3CA66E6` | 7 / 58.33% / −102                                           | 1235 |
| 13 | kos1904_UA                                 | `BB1FB1C6-CDA5-4CC4-975B-797DB64BFB8B` | 11 / 31.43% / −163                                          | 1009 |
| 14 | Kris61                                     | `7A31DBBB-B87F-4FAD-BC2D-8FFE5101F85B` | 9 / 100% / −124                                             | 193  |
| 15 | Mokraya_Pisichka                           | `ECD7C883-B869-4723-AF93-9E50C7A78DD9` | 15 / 42.86% / −209                                          | 8    |
| 16 | Mr-Crabs                                   | `0E9EF191-68BB-48DE-BF02-F11571119A6F` | 26 / 68.42% / −360                                          | 473  |
| 17 | NWTRASLER                                  | `553881AB-8528-4311-B562-75CF39F54312` | 14 / 41.18% / −191                                          | 0    |
| 18 | OnyxGillsRogue                             | `A054C29E-8D62-4129-8B4D-FE049915531E` | 6 / 85.71% / −91                                            | —    |
| 19 | Pescadora_Selvagem                         | `F193E57A-D3D5-483F-8AA2-5E5303CA7D35` | 12 / 100% / −159                                            | 982  |
| 20 | Pescapiaui                                 | `B52A537F-F1D7-4862-A644-E8E3A99705DF` | 7 / 70% / −123                                              | 0    |
| 21 | Pexi86                                     | `15A01B1C-B694-4147-8466-AF94428F48CC` | 15 / 51.72% / −191                                          | 46   |
| 22 | Pilou62                                    | `952EED36-E6A1-40DD-ACD6-7BC8831500CB` | 15 / 44.12% / −212                                          | 962  |
| 23 | ProAndy.EXE                                | `FB74806A-AA01-4D6C-A1C6-B697B4B3E6DA` | 7 / 63.64% / −100                                           | 407  |
| 24 | RedCompGenius (trailing space in Username) | `C684A7FE-7E30-49C7-A52D-506E0CAC9470` | 7 / 100% / −97                                              | —    |
| 25 | RI-1-Prabowo                               | `A2316687-F0DC-4CEE-BEF2-5A42D6AF275A` | 14 / 50% / −193                                             | 1931 |
| 26 | shadow-fear                                | `8FB4514C-ED11-4440-8F18-6B5FCF22027A` | 7 / 100% / −101                                             | —    |
| 27 | sledingMANTANistri                         | `EDD8D34E-325B-4B10-8A9A-7507C3D1BFE9` | 8 / 61.54% / −118                                           | 0    |
| 28 | SUMBULBRIFIR                               | `BF3579A2-5207-4159-A1B7-51ACAA729B54` | 6 / 50% / −91                                               | 94   |
| 29 | SVIP999                                    | `E5040B18-F216-4244-B4A1-AE90A26A0550` | 43 / 70.49% / −572                                          | 0    |
| 30 | SwiftLagoonLord                            | `F164EFE3-72A0-4517-96A3-7574C90AAB91` | 15 / 37.5% / −201                                           | 95   |
| 31 | taktuu                                     | `5A66DB98-970C-4D1C-869A-4EB8ED75D2F9` | 11 / 47.83% / −153                                          | 40   |
| 32 | TTC-SWAX                                   | `4D3EFD74-6B2B-4E65-B434-A63D08BC6F68` | 12 / 37.5% / −194                                           | 39   |
| 33 | U420A                                      | `0A315CFF-7B68-4EF0-B4E7-8490AE84C58B` | 8 / 40% / −115                                              | 50   |
| 34 | UjangBlonde                                | `CA9E447A-EC21-4989-BDF5-C047A52B70DD` | 6 / 33.33% / −100                                           | 2778 |
| 35 | UkrainianLegend                            | `D2DD7657-E8FC-4994-BB75-D7E894F53462` | 10 / 76.92% / −150                                          | 30   |
| 36 | VM_NOi                                     | `8AD35C2D-B6EA-429D-8FC0-3CDBAB4D260D` | 18 / 94.74% / −249                                          | 826  |
| 37 | WoulduRather7                              | `254580AB-A1BF-4A18-99E0-2675ABF013BA` | 7 / 36.84% / −111                                           | 706  |
| 38 | xFenrir                                    | `0F706F7C-0D3F-45FB-ADB3-F9CA23A4BDD0` | 12 / 42.86% / −172                                          | 131  |

## PS (84)

### CONTINUED → 2026-06-17 (22)

| #  | Username        | UserId                                 | Old (N / % / RFNS) | New (N / % / RFNS) | PCR  |
|----|-----------------|----------------------------------------|--------------------|--------------------|------|
| 1  | Besy_1991       | `413754C5-5AFE-4C5A-81AE-E6F662220AC6` | 19 / 42.22% / −240 | 21 / 42% / −267    | 109  |
| 2  | browney73       | `8A4E6218-28F4-4CFF-8C2D-49A85FC66378` | 31 / 86.11% / −440 | 16 / 66.67% / −238 | 440  |
| 3  | DaKingslayer34  | `BECC3B59-5EF7-4AAD-A428-9122F7A870A0` | 11 / 84.62% / −150 | 8 / 72.73% / −119  | 770  |
| 4  | Geelevens       | `262F4CBB-0970-44E3-B9D0-5139BDAC86EB` | 15 / 78.95% / −232 | 15 / 48.39% / −192 | 265  |
| 5  | Guns4Gary       | `1A1E819F-AE99-477E-80EB-7D0F4CFE4CDE` | 21 / 72.41% / −298 | 24 / 96% / −352    | 470  |
| 6  | IKIGAI__1__     | `06BB9D34-BC04-4591-80F6-0F8AD8F05087` | 46 / 86.79% / −620 | 50 / 73.53% / −701 | 14   |
| 7  | jeffbob1979     | `6407B03E-D273-4329-8BA0-91BCD94D148E` | 40 / 85.11% / −552 | 8 / 100% / −114    | 0    |
| 8  | LIP_RIPPER3233  | `16E9369A-8710-40A1-90FD-7938DAAE9BB7` | 19 / 41.3% / −278  | 20 / 37.04% / −296 | 56   |
| 9  | lucyrex69       | `CB3703A3-1A93-49C9-AAFD-946BC825FF47` | 42 / 89.36% / −588 | 61 / 76.25% / −833 | 397  |
| 10 | michelplat      | `418F3ED0-C447-430F-A808-F197AC668C13` | 16 / 59.26% / −234 | 16 / 72.73% / −245 | 2270 |
| 11 | mirador01       | `CFDF2FA5-7C1D-4531-9238-B2AADEF27391` | 16 / 55.17% / −256 | 49 / 75.38% / −669 | 81   |
| 12 | naked-fishing   | `6940D7A1-D527-4484-9EA7-0676A6D8A5EF` | 35 / 94.59% / −515 | 16 / 100% / −216   | 31   |
| 13 | olimpiada__80   | `ABD1EA6D-3EE0-4B4E-BC3B-66C7FAE4028B` | 18 / 52.94% / −275 | 44 / 67.69% / −617 | 63   |
| 14 | otc-X1-         | `77D4CA73-E111-4F74-BEE7-20A76A02D3E0` | 44 / 86.27% / −633 | 22 / 45.83% / −360 | 661  |
| 15 | Proz_For_Life   | `3C8366E8-9669-47A4-87EB-1059D07EAE21` | 15 / 93.75% / −212 | 7 / 70% / −95      | 929  |
| 16 | QG_Geo_vane     | `553D6B17-7ACA-4F9F-9FCC-D5A38276B990` | 25 / 71.43% / −355 | 17 / 54.84% / −232 | 1074 |
| 17 | QG_ZOCA         | `66687801-8051-48BF-A297-07D6F95FF338` | 19 / 90.48% / −271 | 36 / 94.74% / −512 | 1334 |
| 18 | Sajler_1_       | `118B21ED-1D89-4A8D-8296-922452775439` | 39 / 70.91% / −521 | 39 / 78% / −571    | 7    |
| 19 | Whip-_-FP-_-    | `13D1C7C7-1B4D-4A3E-9890-8B4391519EBF` | 37 / 92.5% / −528  | 75 / 100% / −1051  | 743  |
| 20 | yohan-josse-85  | `4F4E4CDC-EEF1-4D79-91C0-47E552AFD7E1` | 13 / 76.47% / −195 | 13 / 68.42% / −159 | 72   |
| 21 | Zatumbik        | `C869B021-3535-4205-A818-B23344024001` | 32 / 91.43% / −435 | 16 / 76.19% / −206 | 229  |
| 22 | Zlat87_X-Series | `D1CB3B8D-C3C4-4491-8AF2-6123FD9606C2` | 20 / 80% / −276    | 46 / 85.19% / −657 | 903  |

### STARTED → 2026-06-01 (62)

| #  | Username            | UserId                                 | New (N / % / RFNS)                                          | PCR  |
|----|---------------------|----------------------------------------|-------------------------------------------------------------|------|
| 1  | AAPC-kaige          | `4A3375B0-59FC-415F-97F7-E8882DE62524` | 22 / 75.86% / −325                                          | 0    |
| 2  | BE_Cr1st1an         | `93E7F4B7-9499-408C-A239-70ABDEB457D5` | 12 / 75% / −157                                             | 15   |
| 3  | berg-zug            | `4D6C6744-33A8-48C6-9D16-D0AD72327202` | 8 / 44.44% / −101                                           | 752  |
| 4  | Black_pantherUSA    | `FE73183F-EED7-4DFA-AD85-D279C5FD80B6` | 11 / 100% / −167                                            | 220  |
| 5  | bold_blade409       | `CF481161-89DC-4072-90A9-82CB2B27DE4F` | 11 / 45.83% / −174                                          | 157  |
| 6  | bostonbroncos24     | `5DB0A328-1307-4762-A1DB-7FF34E63BFE5` | 13 / 54.17% / −176                                          | 21   |
| 7  | boule_tueuse        | `9F90E055-B7E8-4458-8565-F4C88AD7F7F4` | 8 / 53.33% / −123                                           | 23   |
| 8  | Brasil-Fernando_    | `8C49F4D0-8DF2-46D1-9AF3-FCD24C5A25E4` | 6 / 100% / −94                                              | 578  |
| 9  | bullr1de5           | `4D62BBE9-29F3-4815-851B-2C30D65996FE` | 9 / 100% / −105                                             | —    |
| 10 | car_wild995         | `7338B1A9-3A20-486F-97B7-4A60493422DC` | 51 / 63.75% / −745                                          | 56   |
| 11 | Cedric-02000        | `D21225C2-00BB-45E2-A7CE-C132D9A6448C` | 29 / 46.77% / −429                                          | 925  |
| 12 | CFC-Marquezim       | `D17DE48C-4CA9-43C8-B006-FFA6183A6F1A` | 8 / 100% / −121                                             | 65   |
| 13 | chris65445690099    | `00F02301-1D40-4666-80BD-F5BB68196CF4` | 53 / 76.81% / −770                                          | 76   |
| 14 | Closedporcupine     | `C161F041-5AFB-464B-B6D5-BCA02B6CFF08` | 21 / 65.63% / −263                                          | 36   |
| 15 | connorsamson6546    | `B2F00F2E-2018-44A8-B8B2-0708D3597FB6` | 9 / 69.23% / −121                                           | 39   |
| 16 | coro280             | `80AD43C0-F3FF-4FE8-B2DD-B653F169F75F` | 12 / 60% / −174                                             | 477  |
| 17 | CP_Rojao12Vala      | `C7CC4081-3F8E-4591-ACE2-8F5715BA2263` | 17 / 54.84% / −247                                          | 769  |
| 18 | Cra-Poulette        | `E4E9F1DD-5C49-4F89-A41F-0EF5E9829913` | 20 / 76.92% / −272                                          | 100  |
| 19 | DaSs-2613           | `DFFE7879-D8FA-439E-8ECF-31636F49CFD7` | 30 / 68.18% / −408                                          | 102  |
| 20 | dommitab            | `2CD5CEC1-A3EF-4611-84C2-D799D4E6B9A6` | 7 / 77.78% / −102                                           | 382  |
| 21 | ellgringo1983       | `E235F02D-E3C7-48A8-9EA7-999042CF4301` | 8 / 33.33% / −119                                           | 927  |
| 22 | eraul50100          | `08211913-BD17-4126-8FB1-946085F67238` | 9 / 75% / −125                                              | 206  |
| 23 | EZ-AllenWrench      | `EF811669-3C30-4469-ACCB-3D5EC74DCDE6` | 17 / 56.67% / −228                                          | 788  |
| 24 | fabinoux53          | `3ACE0F99-6215-4963-B1EC-72CA62855992` | 32 / 64% / −446                                             | 1    |
| 25 | fiestero45          | `EA640F76-2E33-4459-8CF3-1EF69EB6D00F` | 20 / 57.14% / −293                                          | 637  |
| 26 | Fifi082017          | `C2C46BEA-48DB-4640-AFA8-B66F228210F5` | 6 / 100% / −93                                              | —    |
| 27 | Flo-GrayFOX         | `76B5F7F3-346A-46B1-9C70-4FE0743572C3` | 17 / 47.22% / −266                                          | 77   |
| 28 | FPI_BostonGeorg_    | `0E4C4A88-AF28-4E7E-B57F-9A85133F96E8` | 31 / 96.88% / −472                                          | 687  |
| 29 | FPI_Fvmazz          | `FB1C37CD-B5D2-4A1E-B3E8-A9173621B2A4` | 14 / 48.28% / −204                                          | 837  |
| 30 | FPS_Zerbino85       | `AE57251D-7708-4947-BAB4-FA71552CEBCA` | 6 / 85.71% / −99                                            | 432  |
| 31 | fredtoso            | `BF9BCF1B-92EF-4C38-8588-14C456988CB9` | 10 / 62.5% / −137                                           | 70   |
| 32 | glp023              | `56AE0FF1-7337-49BC-87E9-0B05F435AD44` | 6 / 100% / −98                                              | —    |
| 33 | guszto001           | `7DE8392C-6B0F-495B-AD09-43296A20FEF7` | 7 / 100% / −98                                              | —    |
| 34 | imminent_shoe3      | `4F1C90F0-2A81-4595-9339-B548DD34CD0B` | 6 / 100% / −98                                              | —    |
| 35 | james2629           | `51FF4DFB-31BF-4B74-B984-2E8CB6A1696B` | 7 / 38.89% / −106                                           | 184  |
| 36 | JOCHEN-666-         | `62D767A5-9397-4146-BC98-A96F027817DF` | 8 / 30.77% / −128                                           | 131  |
| 37 | kamson170612        | `2E94E069-BC25-4590-B047-50816502FEEE` | 22 / 78.57% / −331                                          | 852  |
| 38 | krzysztof-widz      | `EF573A5D-E882-4BE6-A388-2E6B03F4DAD4` | 14 / 82.35% / −174                                          | 49   |
| 39 | Le_Zenzen80         | `23203C27-2301-49E9-AD19-2DF699568227` | 24 / 52.17% / −329                                          | 191  |
| 40 | magikstar           | `E7B04618-95A1-4A8A-83C4-43BECBBAD9DA` | 10 / 40% / −145                                             | 999  |
| 41 | maitines            | `BC99AE7E-AEAA-4E4F-959A-DEEE1B0AB03E` | 9 / 90% / −143                                              | 0    |
| 42 | MEGA_GRAVITIES      | `F0547940-6531-405A-8FD1-20F54B803935` | 54 / 100% / −755                                            | 4    |
| 43 | MohandGamer7        | `1AB9C5E1-C2A1-4CC9-A26C-35BF336016E0` | 17 / 80.95% / −247                                          | 97   |
| 44 | mrtoffeeman75       | `7E745998-3686-4CC9-90F5-2C7001E44DBF` | 24 / 85.71% / −338                                          | 119  |
| 45 | Ms-LisahLis         | `FD845E61-3261-4CCD-9CA1-85873D10445D` | 15 / 75% / −194                                             | 127  |
| 46 | Onlinebusiness      | `B9E10F37-0DEA-4824-A8B2-AB55BC633DDC` | 8 / 88.89% / −115                                           | 0    |
| 47 | Panonski_Alas       | `C896536D-28FA-4785-A85E-48C27B947590` | 49 / 71.01% / −736                                          | 379  |
| 48 | pluczmers 🆕        | `D2BD9321-DA45-4454-B5A8-947248319973` | (no pre-snapshot — appeared between planning and execution) | —    |
| 49 | RedBlitz77 🆕       | `0D087E43-D987-4473-8A8A-86C74AD1EE9F` | (no pre-snapshot — appeared between planning and execution) | —    |
| 50 | rentner365          | `0161D8C6-66C9-4D56-8EE3-FD0B8B9C752F` | 10 / 100% / −160                                            | 50   |
| 51 | Ro_kostbar_kraft    | `422F528B-A147-42E8-A15C-2C817E6A45AA` | 25 / 75.76% / −356                                          | 784  |
| 52 | RosUnbent           | `690AC9F2-4839-409E-8EEB-07D05685B252` | 33 / 55% / −494                                             | 126  |
| 53 | serber-denis85      | `70E09BE8-5355-4C3F-AB4E-06AB15B34321` | 25 / 69.44% / −338                                          | 826  |
| 54 | sikosmiths          | `DBA5F812-973C-4B50-B230-FC3E92DEC118` | 7 / 100% / −92                                              | —    |
| 55 | STARI40K_YT         | `E25C082E-8A19-4236-AA8B-C345137E9EA3` | 8 / 100% / −119                                             | 38   |
| 56 | SUB-ZERO2430        | `31B4DED5-7E65-4074-BC05-EFFD897C6D91` | 12 / 63.16% / −174                                          | 603  |
| 57 | svs-Stefken         | `881D8ADA-DB1A-4413-AFB4-5674A75E8FC2` | 7 / 58.33% / −103                                           | 1356 |
| 58 | thesoftandlazy      | `C30809B6-FB50-421A-AC66-435A31D4B278` | 14 / 50% / −211                                             | 54   |
| 59 | TTVteamLazic        | `14DB7502-F904-4E95-B82B-3212045FE4A2` | 14 / 56% / −188                                             | 421  |
| 60 | V1SENT1M_Lz         | `691F3B70-F538-4F99-96D8-74D62DD9887D` | 22 / 48.89% / −311                                          | 853  |
| 61 | xldizzylx420        | `3E09EF0E-6BD0-425A-809A-4BB8FCD21378` | 6 / 100% / −93                                              | —    |
| 62 | X-Series_Rodrigo 🆕 | `99695D7B-E98D-4E1C-9153-E6FBD7F812D8` | (no pre-snapshot — appeared between planning and execution) | —    |

## XBOX (26)

### CONTINUED → 2026-06-17 (10)

| #  | Username        | UserId                                 | Old (N / % / RFNS) | New (N / % / RFNS) | PCR  |
|----|-----------------|----------------------------------------|--------------------|--------------------|------|
| 1  | BellaCiOoo      | `38856606-9A1C-458A-91A6-CEF9ACA5E5A3` | 31 / 86.11% / −437 | 15 / 75% / −218    | 80   |
| 2  | Buckslayer86433 | `18494A55-D471-40DB-955C-4BC1F0CB633E` | 13 / 46.43% / −185 | 55 / 87.3% / −765  | 0    |
| 3  | Direwolfx70     | `3D174D5C-0A64-4F13-BF2C-E7FA69A56E19` | 13 / 100% / −190   | 11 / 100% / −149   | —    |
| 4  | RaidedBYoff     | `9439D534-3527-4D9C-A2D0-0B3DF836B572` | 10 / 43.48% / −156 | 25 / 73.53% / −360 | 0    |
| 5  | rascof molotov  | `EC371F4D-633E-45DB-8B29-83DE86C09DCB` | 18 / 78.26% / −257 | 50 / 62.5% / −718  | 3    |
| 6  | RidwanJaya01    | `979E2B34-0AAA-4722-A800-F97EA2FA7032` | 30 / 76.92% / −434 | 56 / 82.35% / −783 | 85   |
| 7  | Roman77UA       | `F1661B4B-025E-4AAF-A0A7-CAD86C72498A` | 20 / 80% / −265    | 46 / 86.79% / −551 | 1141 |
| 8  | SCATTER FS      | `93146A41-D7D2-4434-A35E-5A1BFEF40CB8` | 24 / 70.59% / −358 | 29 / 65.91% / −439 | 92   |
| 9  | ShrubnSE        | `353B440E-68BF-499A-9CB9-161D901DFCD2` | 29 / 87.88% / −349 | 16 / 59.26% / −206 | 665  |
| 10 | ZellyRolled     | `87223C5F-5082-496F-88D4-507D31B540F5` | 20 / 100% / −219   | 19 / 90.48% / −257 | 499  |

### STARTED → 2026-06-01 (16)

| #  | Username        | UserId                                 | New (N / % / RFNS) | PCR  |
|----|-----------------|----------------------------------------|--------------------|------|
| 1  | AllBrokeByHate  | `8537CB8E-2BFC-417F-BE59-584010A4FA97` | 12 / 63.16% / −181 | 2159 |
| 2  | Arayatron33     | `DF30183B-A1A5-45A9-8E65-E48D1470106C` | 9 / 52.94% / −138  | 189  |
| 3  | AZE GOYCAY      | `E8E1E33C-5579-4DEB-906F-95634355800B` | 8 / 33.33% / −104  | 554  |
| 4  | BadSirGame      | `9DF68AAD-9A79-4680-81BD-8E6C7B6EC544` | 45 / 88.24% / −640 | 17   |
| 5  | BuzzingLemur417 | `013368D1-E8A8-437A-88B0-71059E3287EB` | 23 / 56.1% / −358  | 78   |
| 6  | Clepac ONJD     | `74D3CCA7-0A1D-4F82-8B99-D86044C6E44C` | 7 / 53.85% / −104  | 116  |
| 7  | DelfinatorFish  | `77B13CBC-24B2-4BF9-9A5B-E03052F277A0` | 18 / 85.71% / −242 | 0    |
| 8  | DJBKINGZ6796    | `116C7330-B20B-4FF9-9321-C43C496B783B` | 6 / 100% / −91     | —    |
| 9  | DOU FOR LIFE    | `9CC51AED-3A80-4464-BD46-00C62C14189B` | 23 / 92% / −260    | 659  |
| 10 | Fuzzytacos6571  | `0521E9F5-DCF5-438C-908D-689F0DFD2242` | 26 / 96.3% / −345  | 0    |
| 11 | Maine John      | `0FE47A61-87EA-40BC-8FDE-9D0D03217760` | 43 / 93.48% / −606 | 51   |
| 12 | SmirkyWord9283  | `87D7E8F8-C89C-4E0D-B0FB-F41C1BC42AF6` | 6 / 42.86% / −90   | 1773 |
| 13 | TBF Fox         | `970FAB06-E54C-48E6-A731-754B4DE600C4` | 7 / 87.5% / −90    | 908  |
| 14 | TM BolinhaWJ    | `7D8FDBBC-37BD-4588-A890-A97F5D109337` | 6 / 75% / −94      | 1504 |
| 15 | ToBeng3522      | `1CE9EBEF-5C0D-49AE-9BA6-5ABC67E45CF3` | 11 / 40.74% / −141 | 1537 |
| 16 | xFenrir77       | `BDD6D57E-E41F-475E-B067-C0D990A5A92C` | 15 / 65.22% / −257 | 197  |

## Leaderboard sync top-up — script `leaderboard-ban-sync.sql`

After Profile bans were applied above, `leaderboard-ban-sync.sql` was run to propagate **active** Profile bans (`IsCompetitionsBanned=1` AND not expired) into `CompetitiveRatingsCurrent.IsBanned=1` for any rows still showing `IsBanned=0` (catches users banned by Support in prior weeks where the LB flag was never set).

| Platform  | Rows flipped by sync | Final banned LB rows (Weekly 20260511 / Monthly 20260501 / Yearly 20260101) | Skipped (Profile flag set but ban expired — LB untouched) |
|-----------|----------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------|
| Steam     | 101                  | 102 / 113 / 113                                                             | 143                                                       |
| PS        | 46                   | 98 / 100 / 100                                                              | 149                                                       |
| Xbox      | 3                    | 27 / 27 / 27                                                                | 8                                                         |
| **Total** | **150**              | **227 / 240 / 240** = **707 rows**                                          | **300**                                                   |

Sync rows are not enumerated by name — the sync is set-driven over the join of `Profiles.IsCompetitionsBanned=1` ∩ `CompetitiveRatingsCurrent.IsBanned=0`, covering arbitrary historical Profile bans (some pre-FP-43631). If a per-user list of synced rows is needed for audit, the same query without UPDATE — `SELECT r.UserId, r.PeriodTypeId, r.PeriodId FROM CompetitiveRatingsCurrent r JOIN Profiles p ON p.UserId=r.UserId WHERE p.IsCompetitionsBanned=1 AND (p.CompetitionsBanEndDate IS NULL OR p.CompetitionsBanEndDate > GETUTCDATE()) AND r.IsBanned=1` — produces it any time.
