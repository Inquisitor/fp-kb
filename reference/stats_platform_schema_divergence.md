# Stats schema divergence across platforms

Point-in-time snapshot (2026-07-15) of the consolidated Stats copy instance ("ALL STATS DB").
Columns of same-named `dbo` tables/views that are **not present on all 5 platforms**
(`SteamStats` / `PsStats` / `XbStats` / `MobStats` / `NxStats`). `Y` = present, `.` = absent.

Related backlog item: eliminate these divergences (server `backlog.md`).

## Live tables (analyst-relevant drift)

| Table | Column | Steam | PS | Xbox | Mob | Nx |
|---|---|:-:|:-:|:-:|:-:|:-:|
| Users | ExternalId | Y | Y | Y | . | . |
| Profiles | DuelRating | Y | . | Y | Y | Y |
| Profiles | EventRating | Y | . | Y | Y | Y |
| AbTestStats | PlayerLevel | Y | Y | Y | Y | . |
| AbTestStats | Timestamp | Y | Y | Y | Y | . |
| MissionsFact | MissionDifficulty | Y | Y | Y | . | . |
| MissionsFact | TaskDifficulty | Y | Y | Y | . | . |
| TransactionFact | BundleTransactionId | Y | Y | Y | Y | . |
| TwitchRewardsDelivered | PlayerLevel | Y | Y | Y | Y | . |
| TwitchRewardsDelivered | OriginalRewadId / RewadId | . | . | . | Y | . |
| TournamentParticipants | BracketId | Y | Y | Y | . | . |
| TournamentParticipants | ClubId | . | . | . | Y | Y |
| TournamentParticipants | GroupName | Y | Y | Y | . | Y |
| TournamentParticipants | IsCanceled / IsRated | . | . | . | Y | Y |
| TournamentIndividualResults | ClubId | . | Y | Y | . | . |
| TournamentIndividualResults | ClubPoints / Experience / GroupId / GroupName / IsInFinishPoint / IsRewardReceived | Y | . | . | Y | Y |

Notable: PS `Profiles` lacks `DuelRating`/`EventRating`; Nx has the most reduced set; the tournament
result/participant tables diverge along Steam/Mob/Nx vs PS/Xbox lines.

## Noise (archive / temp / backup / broken views)

Most divergence is historical objects that exist only on some platforms and are not schema-design
differences:

- Archive: `StatsFact2021-2024` (Xbox), `StatsFact2022-2024` (Steam/PS/Nx), `BalanceOld` (Steam/Nx),
  `TransactionFact_old` (PS), `Transactions_old.EquivalentPrice` (Mob).
- Temp/backup: `FishFactTemp` (Mob), `UsersTemp29` (Steam), `TournamentParticipants_bak` (Steam/PS/Xbox).
- Steam-only: reporting views `R_Profiles` / `R_Transactions`, extra `FishFact` columns.
- Not on Mob/Nx: `AnonymousActionStats`, `VW_TopReferralCheaters` (the latter is broken on the copy —
  it references a linked server that is not configured there).

## Full matrix

Reproduce with a UNION of `<Db>.INFORMATION_SCHEMA.COLUMNS` across the 5 DBs, pivoted per platform,
filtered to `COUNT(DISTINCT platform) < 5`.

```
TableName|ColumnName|Steam|PS|Xbox|Mob|Nx
AbTestStats|PlayerLevel|Y|Y|Y|Y|.
AbTestStats|Timestamp|Y|Y|Y|Y|.
AnonymousActionStats|ActionName|Y|Y|Y|.|.
AnonymousActionStats|CreatedAt|Y|Y|Y|.|.
AnonymousActionStats|ExternalId|Y|Y|Y|.|.
AnonymousActionStats|Id|Y|Y|Y|.|.
AnonymousActionStats|IsRegistrationComplete|Y|Y|Y|.|.
AnonymousActionStats|Parameter1|Y|Y|Y|.|.
AnonymousActionStats|Parameter2|Y|Y|Y|.|.
AnonymousActionStats|Parameter3|Y|Y|Y|.|.
AnonymousActionStats|PlatformId|Y|Y|Y|.|.
ArchiveTournamentIndividualResults|ClubPoints|Y|.|.|.|Y
ArchiveTournamentIndividualResults|Experience|Y|.|.|.|Y
ArchiveTournamentIndividualResults|GroupId|Y|.|.|.|Y
ArchiveTournamentIndividualResults|GroupName|Y|.|.|.|Y
ArchiveTournamentIndividualResults|IsRewardReceived|Y|.|.|.|Y
BalanceOld|Currency|Y|.|.|.|Y
BalanceOld|Level|Y|.|.|.|Y
BalanceOld|Move|Y|.|.|.|Y
BalanceOld|MoveTypeId|Y|.|.|.|Y
BalanceOld|Timestamp|Y|.|.|.|Y
BalanceOld|UserId|Y|.|.|.|Y
Currencies|Currency|Y|.|.|.|Y
Currencies|Id|Y|.|.|.|Y
Currencies|Simbol|Y|.|.|.|Y
FishFact|BoatId|Y|.|.|.|.
FishFact|BoatType|Y|.|.|.|.
FishFact|DragStyle|Y|.|.|.|.
FishFact|GeneratedLocationX|Y|.|.|.|.
FishFact|GeneratedLocationY|Y|.|.|.|.
FishFact|GeneratedLocationZ|Y|.|.|.|.
FishFact|GoneReason|Y|.|.|.|.
FishFact|HookSize|Y|.|.|.|.
FishFact|IsFt|Y|.|.|.|.
FishFact|IsTrolling|Y|.|.|.|.
FishFactTemp|BaitOrLureId|.|.|.|Y|.
FishFactTemp|BrokenAt|.|.|.|Y|.
FishFactTemp|CaughtAt|.|.|.|Y|.
FishFactTemp|EscapedAt|.|.|.|Y|.
FishFactTemp|EscapedDistance|.|.|.|Y|.
FishFactTemp|EscapedReason|.|.|.|Y|.
FishFactTemp|Exp|.|.|.|Y|.
FishFactTemp|FinishAttackSeconds|.|.|.|Y|.
FishFactTemp|FishFightDurationSeconds|.|.|.|Y|.
FishFactTemp|FishId|.|.|.|Y|.
FishFactTemp|GeneratedAt|.|.|.|Y|.
FishFactTemp|GenerateDistance|.|.|.|Y|.
FishFactTemp|GoneAt|.|.|.|Y|.
FishFactTemp|HookedAt|.|.|.|Y|.
FishFactTemp|HookedDistance|.|.|.|Y|.
FishFactTemp|Id|.|.|.|Y|.
FishFactTemp|InterruptedAt|.|.|.|Y|.
FishFactTemp|IsStriking|.|.|.|Y|.
FishFactTemp|IsWrongStriking|.|.|.|Y|.
FishFactTemp|LeaderId|.|.|.|Y|.
FishFactTemp|Level|.|.|.|Y|.
FishFactTemp|LineId|.|.|.|Y|.
FishFactTemp|PondId|.|.|.|Y|.
FishFactTemp|PondTimeSeconds|.|.|.|Y|.
FishFactTemp|ReelId|.|.|.|Y|.
FishFactTemp|RodId|.|.|.|Y|.
FishFactTemp|RodTemplate|.|.|.|Y|.
FishFactTemp|Silver|.|.|.|Y|.
FishFactTemp|Slot|.|.|.|Y|.
FishFactTemp|Source|.|.|.|Y|.
FishFactTemp|UserId|.|.|.|Y|.
FishFactTemp|Weather|.|.|.|Y|.
FishFactTemp|Weight|.|.|.|Y|.
MissionsFact|MissionDifficulty|Y|Y|Y|.|.
MissionsFact|TaskDifficulty|Y|Y|Y|.|.
Profiles|DuelRating|Y|.|Y|Y|Y
Profiles|EventRating|Y|.|Y|Y|Y
R_Profiles|CompetitionRating|Y|.|.|.|.
R_Profiles|DuelRating|Y|.|.|.|.
R_Profiles|EventRating|Y|.|.|.|.
R_Profiles|Experience|Y|.|.|.|.
R_Profiles|GoldCoins|Y|.|.|.|.
R_Profiles|IsInfluencer|Y|.|.|.|.
R_Profiles|IsTutorialFinished|Y|.|.|.|.
R_Profiles|IsUgcHost|Y|.|.|.|.
R_Profiles|LanguageId|Y|.|.|.|.
R_Profiles|LastActivityDate|Y|.|.|.|.
R_Profiles|Level|Y|.|.|.|.
R_Profiles|PondId|Y|.|.|.|.
R_Profiles|Rank|Y|.|.|.|.
R_Profiles|RankExperience|Y|.|.|.|.
R_Profiles|Role|Y|.|.|.|.
R_Profiles|SilverCoins|Y|.|.|.|.
R_Profiles|StartersGivenList|Y|.|.|.|.
R_Profiles|StartersOwnedList|Y|.|.|.|.
R_Profiles|SubscriptionEndDate|Y|.|.|.|.
R_Profiles|SubscriptionId|Y|.|.|.|.
R_Profiles|TournamentRating|Y|.|.|.|.
R_Profiles|UserId|Y|.|.|.|.
R_Transactions|PaymentSystemId|Y|.|.|.|.
R_Transactions|ProductId|Y|.|.|.|.
R_Transactions|Status|Y|.|.|.|.
R_Transactions|Timestamp|Y|.|.|.|.
R_Transactions|TransactionId|Y|.|.|.|.
R_Transactions|UserId|Y|.|.|.|.
StatsFact2021-2024|Achievement|.|.|Y|.|.
StatsFact2021-2024|AchievementName|.|.|Y|.|.
StatsFact2021-2024|Bait|.|.|Y|.|.
StatsFact2021-2024|BaseExp|.|.|Y|.|.
StatsFact2021-2024|BoatId|.|.|Y|.|.
StatsFact2021-2024|BoatSpeed|.|.|Y|.|.
StatsFact2021-2024|Crash|.|.|Y|.|.
StatsFact2021-2024|DaysSpent|.|.|Y|.|.
StatsFact2021-2024|DragStyle|.|.|Y|.|.
StatsFact2021-2024|Duration|.|.|Y|.|.
StatsFact2021-2024|EntityId|.|.|Y|.|.
StatsFact2021-2024|EventType|.|.|Y|.|.
StatsFact2021-2024|Exp|.|.|Y|.|.
StatsFact2021-2024|FishBox|.|.|Y|.|.
StatsFact2021-2024|FishCageFishCount|.|.|Y|.|.
StatsFact2021-2024|FishCount|.|.|Y|.|.
StatsFact2021-2024|FishLength|.|.|Y|.|.
StatsFact2021-2024|FishName|.|.|Y|.|.
StatsFact2021-2024|FishWeight|.|.|Y|.|.
StatsFact2021-2024|FtSessionId|.|.|Y|.|.
StatsFact2021-2024|GameDayNumber|.|.|Y|.|.
StatsFact2021-2024|Gold|.|.|Y|.|.
StatsFact2021-2024|GoldEarnedForDay|.|.|Y|.|.
StatsFact2021-2024|GoldEarnedForFish|.|.|Y|.|.
StatsFact2021-2024|GoldSpentForTravel|.|.|Y|.|.
StatsFact2021-2024|GoldSpentInShop|.|.|Y|.|.
StatsFact2021-2024|GoldSpentOnLicense|.|.|Y|.|.
StatsFact2021-2024|GoldSpentOnRepair|.|.|Y|.|.
StatsFact2021-2024|HasPremium|.|.|Y|.|.
StatsFact2021-2024|HitchBoxName|.|.|Y|.|.
StatsFact2021-2024|HitchMaxLoad|.|.|Y|.|.
StatsFact2021-2024|HookSize|.|.|Y|.|.
StatsFact2021-2024|IsBoatCatch|.|.|Y|.|.
StatsFact2021-2024|IsHookedWithTrolling|.|.|Y|.|.
StatsFact2021-2024|IsReleased|.|.|Y|.|.
StatsFact2021-2024|ItemCount|.|.|Y|.|.
StatsFact2021-2024|ItemId|.|.|Y|.|.
StatsFact2021-2024|ItemType|.|.|Y|.|.
StatsFact2021-2024|Level|.|.|Y|.|.
StatsFact2021-2024|LicenseDays|.|.|Y|.|.
StatsFact2021-2024|LineType|.|.|Y|.|.
StatsFact2021-2024|Location|.|.|Y|.|.
StatsFact2021-2024|Money|.|.|Y|.|.
StatsFact2021-2024|Pond|.|.|Y|.|.
StatsFact2021-2024|PondTime|.|.|Y|.|.
StatsFact2021-2024|Product|.|.|Y|.|.
StatsFact2021-2024|Rank|.|.|Y|.|.
StatsFact2021-2024|RealTimeSpent|.|.|Y|.|.
StatsFact2021-2024|ReelType|.|.|Y|.|.
StatsFact2021-2024|RodTemplate|.|.|Y|.|.
StatsFact2021-2024|RodType|.|.|Y|.|.
StatsFact2021-2024|Silver|.|.|Y|.|.
StatsFact2021-2024|SilverEarnedForDay|.|.|Y|.|.
StatsFact2021-2024|SilverEarnedForFish|.|.|Y|.|.
StatsFact2021-2024|SilverSpentForTravel|.|.|Y|.|.
StatsFact2021-2024|SilverSpentInShop|.|.|Y|.|.
StatsFact2021-2024|SilverSpentOnLicense|.|.|Y|.|.
StatsFact2021-2024|SilverSpentOnRepair|.|.|Y|.|.
StatsFact2021-2024|Source|.|.|Y|.|.
StatsFact2021-2024|StateName|.|.|Y|.|.
StatsFact2021-2024|TackleType|.|.|Y|.|.
StatsFact2021-2024|Throw|.|.|Y|.|.
StatsFact2021-2024|TimeEnd|.|.|Y|.|.
StatsFact2021-2024|TimeForward|.|.|Y|.|.
StatsFact2021-2024|TimeOfDay|.|.|Y|.|.
StatsFact2021-2024|Timestamp|.|.|Y|.|.
StatsFact2021-2024|TournamentId|.|.|Y|.|.
StatsFact2021-2024|TravelCount|.|.|Y|.|.
StatsFact2021-2024|UserId|.|.|Y|.|.
StatsFact2021-2024|Weather|.|.|Y|.|.
StatsFact2022-2024|Achievement|Y|Y|.|.|Y
StatsFact2022-2024|AchievementName|Y|Y|.|.|Y
StatsFact2022-2024|Bait|Y|Y|.|.|Y
StatsFact2022-2024|BaseExp|Y|Y|.|.|Y
StatsFact2022-2024|BoatId|Y|Y|.|.|Y
StatsFact2022-2024|BoatSpeed|Y|Y|.|.|Y
StatsFact2022-2024|Crash|Y|Y|.|.|Y
StatsFact2022-2024|DaysSpent|Y|Y|.|.|Y
StatsFact2022-2024|DragStyle|Y|Y|.|.|Y
StatsFact2022-2024|Duration|Y|Y|.|.|Y
StatsFact2022-2024|EntityId|Y|Y|.|.|Y
StatsFact2022-2024|EventType|Y|Y|.|.|Y
StatsFact2022-2024|Exp|Y|Y|.|.|Y
StatsFact2022-2024|FishBox|Y|Y|.|.|Y
StatsFact2022-2024|FishCageFishCount|Y|Y|.|.|Y
StatsFact2022-2024|FishCount|Y|Y|.|.|Y
StatsFact2022-2024|FishLength|Y|Y|.|.|Y
StatsFact2022-2024|FishName|Y|Y|.|.|Y
StatsFact2022-2024|FishWeight|Y|Y|.|.|Y
StatsFact2022-2024|FtSessionId|Y|Y|.|.|Y
StatsFact2022-2024|GameDayNumber|Y|Y|.|.|Y
StatsFact2022-2024|Gold|Y|Y|.|.|Y
StatsFact2022-2024|GoldEarnedForDay|Y|Y|.|.|Y
StatsFact2022-2024|GoldEarnedForFish|Y|Y|.|.|Y
StatsFact2022-2024|GoldSpentForTravel|Y|Y|.|.|Y
StatsFact2022-2024|GoldSpentInShop|Y|Y|.|.|Y
StatsFact2022-2024|GoldSpentOnLicense|Y|Y|.|.|Y
StatsFact2022-2024|GoldSpentOnRepair|Y|Y|.|.|Y
StatsFact2022-2024|HasPremium|Y|Y|.|.|Y
StatsFact2022-2024|HitchBoxName|Y|Y|.|.|Y
StatsFact2022-2024|HitchMaxLoad|Y|Y|.|.|Y
StatsFact2022-2024|HookSize|Y|Y|.|.|Y
StatsFact2022-2024|IsBoatCatch|Y|Y|.|.|Y
StatsFact2022-2024|IsHookedWithTrolling|Y|Y|.|.|Y
StatsFact2022-2024|IsReleased|Y|Y|.|.|Y
StatsFact2022-2024|ItemCount|Y|Y|.|.|Y
StatsFact2022-2024|ItemId|Y|Y|.|.|Y
StatsFact2022-2024|ItemType|Y|Y|.|.|Y
StatsFact2022-2024|Level|Y|Y|.|.|Y
StatsFact2022-2024|LicenseDays|Y|Y|.|.|Y
StatsFact2022-2024|LineType|Y|Y|.|.|Y
StatsFact2022-2024|Location|Y|Y|.|.|Y
StatsFact2022-2024|Money|Y|Y|.|.|Y
StatsFact2022-2024|Pond|Y|Y|.|.|Y
StatsFact2022-2024|PondTime|Y|Y|.|.|Y
StatsFact2022-2024|Product|Y|Y|.|.|Y
StatsFact2022-2024|Rank|Y|Y|.|.|Y
StatsFact2022-2024|RealTimeSpent|Y|Y|.|.|Y
StatsFact2022-2024|ReelType|Y|Y|.|.|Y
StatsFact2022-2024|RodTemplate|Y|Y|.|.|Y
StatsFact2022-2024|RodType|Y|Y|.|.|Y
StatsFact2022-2024|Silver|Y|Y|.|.|Y
StatsFact2022-2024|SilverEarnedForDay|Y|Y|.|.|Y
StatsFact2022-2024|SilverEarnedForFish|Y|Y|.|.|Y
StatsFact2022-2024|SilverSpentForTravel|Y|Y|.|.|Y
StatsFact2022-2024|SilverSpentInShop|Y|Y|.|.|Y
StatsFact2022-2024|SilverSpentOnLicense|Y|Y|.|.|Y
StatsFact2022-2024|SilverSpentOnRepair|Y|Y|.|.|Y
StatsFact2022-2024|Source|Y|Y|.|.|Y
StatsFact2022-2024|StateName|Y|Y|.|.|Y
StatsFact2022-2024|TackleType|Y|Y|.|.|Y
StatsFact2022-2024|Throw|Y|Y|.|.|Y
StatsFact2022-2024|TimeEnd|Y|Y|.|.|Y
StatsFact2022-2024|TimeForward|Y|Y|.|.|Y
StatsFact2022-2024|TimeOfDay|Y|Y|.|.|Y
StatsFact2022-2024|Timestamp|Y|Y|.|.|Y
StatsFact2022-2024|TournamentId|Y|Y|.|.|Y
StatsFact2022-2024|TravelCount|Y|Y|.|.|Y
StatsFact2022-2024|UserId|Y|Y|.|.|Y
StatsFact2022-2024|Weather|Y|Y|.|.|Y
TournamentIndividualResults|ClubId|.|Y|Y|.|.
TournamentIndividualResults|ClubPoints|Y|.|.|Y|Y
TournamentIndividualResults|Experience|Y|.|.|Y|Y
TournamentIndividualResults|GroupId|Y|.|.|Y|Y
TournamentIndividualResults|GroupName|Y|.|.|Y|Y
TournamentIndividualResults|IsInFinishPoint|Y|.|.|Y|Y
TournamentIndividualResults|IsRewardReceived|Y|.|.|Y|Y
TournamentParticipants|BracketId|Y|Y|Y|.|.
TournamentParticipants|ClubId|.|.|.|Y|Y
TournamentParticipants|GroupName|Y|Y|Y|.|Y
TournamentParticipants|IsCanceled|.|.|.|Y|Y
TournamentParticipants|IsRated|.|.|.|Y|Y
TournamentParticipants_bak|ClubId|Y|Y|Y|.|.
TournamentParticipants_bak|GroupName|Y|.|.|.|.
TournamentParticipants_bak|IsApproved|Y|Y|Y|.|.
TournamentParticipants_bak|IsCanceled|Y|.|Y|.|.
TournamentParticipants_bak|IsDisqualified|Y|Y|Y|.|.
TournamentParticipants_bak|IsDone|Y|Y|Y|.|.
TournamentParticipants_bak|IsLocked|Y|Y|Y|.|.
TournamentParticipants_bak|IsRated|Y|.|Y|.|.
TournamentParticipants_bak|IsStarted|Y|Y|Y|.|.
TournamentParticipants_bak|Team|Y|Y|Y|.|.
TournamentParticipants_bak|TournamentId|Y|Y|Y|.|.
TournamentParticipants_bak|UserId|Y|Y|Y|.|.
TransactionFact|BundleTransactionId|Y|Y|Y|Y|.
TransactionFact_old|BundleTransactionId|.|Y|.|.|.
TransactionFact_old|GoldBalance|.|Y|.|.|.
TransactionFact_old|HasPremium|.|Y|.|.|.
TransactionFact_old|IsPayer|.|Y|.|.|.
TransactionFact_old|Level|.|Y|.|.|.
TransactionFact_old|PaymentSystemId|.|Y|.|.|.
TransactionFact_old|PlatformId|.|Y|.|.|.
TransactionFact_old|ProductId|.|Y|.|.|.
TransactionFact_old|ProductPriceUsd|.|Y|.|.|.
TransactionFact_old|Rank|.|Y|.|.|.
TransactionFact_old|RegionId|.|Y|.|.|.
TransactionFact_old|SilverBalance|.|Y|.|.|.
TransactionFact_old|Timestamp|.|Y|.|.|.
TransactionFact_old|TransactionId|.|Y|.|.|.
TransactionFact_old|UserId|.|Y|.|.|.
Transactions_old|EquivalentPrice|.|.|.|Y|.
TwitchRewardsDelivered|OriginalRewadId|.|.|.|Y|.
TwitchRewardsDelivered|PlayerLevel|Y|Y|Y|Y|.
TwitchRewardsDelivered|RewadId|.|.|.|Y|.
Users|ExternalId|Y|Y|Y|.|.
UsersTemp29|CreationDate|Y|.|.|.|.
UsersTemp29|ExternalId|Y|.|.|.|.
UsersTemp29|LastActivityDate|Y|.|.|.|.
UsersTemp29|Source|Y|.|.|.|.
UsersTemp29|UserId|Y|.|.|.|.
VW_TopReferralCheaters|Cnt|Y|Y|Y|.|.
VW_TopReferralCheaters|UserId|Y|Y|Y|.|.
VW_TopReferralCheaters|UserName|Y|Y|Y|.|.
```
