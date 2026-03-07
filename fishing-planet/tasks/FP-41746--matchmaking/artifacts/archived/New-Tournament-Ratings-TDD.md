> **Source:** [New tournament ratings, competitive leaderboards and matchmaking system server technical design](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4009033759) (Confluence)
> **Exported:** 2026-02-16

This TDD is covering the following GDDs:

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4015390722

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3817603108

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3829563393

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3808985095 (in terms of competitive leaderboards only)

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4019585607

Latest addition to this TDD are changes from this GDD:

https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4121460746

There are several aspects to this TDD:

* Rating - how competitive rating is awarded,
* Leaderboards - show current standing, reset, save & show history, rewards: setting, giving,
* Matchmaking - dividing players into groups to compete together,
* Scheduling - changing the way, completions are schedules.

This document is touching Tournaments and Competitions in our current terms. User Generated Competitions are not in scope and are still not rated.

# Rating

## Configuration

### Refac

* Remove TitleGiven, TitleProlonged, IsRated from TournamentPlace + usages.
* Remove TitleGiven, TitleProlonged from PlayerFinalResult + usages.
* Remove Title, TitleTimestamp from Profile. Check profile serialization (should be ok)
* TournamentTitles - remove enum.

### Addition

Add to TournamentPlace:

* public int? Rating { get; set; } - to store rating increment/decrement for the place (client and server).

Examples:

```json
{
  ...
  "Places": [
    {"PlaceId": 1,"Count": 1,"RewardName": "AutoCheesyCat_p1","ClubPoints": 2100,"Rating": 30},
    {"PlaceId": 2,"Count": 1,"RewardName": "AutoCheesyCat_p2","ClubPoints": 1550,"Rating": 25},
    {"PlaceId": 3,"Count": 1,"RewardName": "AutoCheesyCat_p3","ClubPoints": 1250,"Rating": 20},
    {"PlaceId": 4,"Count": 1,"RewardName": "AutoCheesyCat_p4","ClubPoints": 900,"Rating": 15},
    {"PlaceId": 5,"Count": 1,"RewardName": "AutoCheesyCat_p5","ClubPoints": 620,"Rating": 10},
    {"PlaceId": 6,"Count": 1,"RewardName": "AutoCheesyCat_p6","ClubPoints": 500,"Rating": 8},
    {"PlaceId": 7,"Count": 1,"RewardName": "AutoCheesyCat_p7","ClubPoints": 400,"Rating": 6},
    {"PlaceId": 8,"Count": 1,"RewardName": "AutoCheesyCat_p8","ClubPoints": 300,"Rating": 4},
    {"PlaceId": 9,"Count": 1,"RewardName": "AutoCheesyCat_p9","ClubPoints": 200,"Rating": 2},
    {"PlaceId": 10,"Count": 1,"RewardName": "AutoCheesyCat_p10","ClubPoints": 150,"Rating": 1},
    {"PlaceId": 11,"Count": 1,"Rating" : 0},
    {"PlaceId": 12,"Count": 1,"Rating" : 0},
    {"PlaceId": 13,"Count": 1,"Rating" : 0},
    {"PlaceId": 14,"Count": 1,"Rating" : 0},
    {"PlaceId": 15,"Count": 1,"Rating" : 0},
    {"PlaceId": 16,"Count": 1,"Rating" : -5},
    {"PlaceId": 17,"Count": 1,"Rating" : -10},
    {"PlaceId": 18,"Count": 1,"Rating" : -15},
    {"PlaceId": 19,"Count": 1,"Rating" : -20},
    {"PlaceId": 20,"Count": 1,"Rating" : -25},
    {"PlaceId": 21,"Count": 1,"Rating" : -30}
  ],
  "ZeroScoreRatingPenalty" : -40,
  "NoShowRatingPenalty" : -50,
  ...
}
```

`RewardName` could be absent - no reward for the place.

`TitleGiven`, `TitleProlonged`, `IsRated` - To be removed from JSON config.

Add to `TournamentTemplateJsonConfig`:

| **Field Name** | **Type** | **Description** |
| --- | --- | --- |
| `NoShowRatingPenalty`   | `int?` | The rating penalty for no-show (registered, but not participated), places not configured, places beyond the configured range, zero score, and disqualification. |
| `ZeroScoreRatingPenalty`  | `int?` | The rating penalty for receiving zero score while actively participating in the competition |

## Calculation

Remove TournamentRatingCalculator class and usages.

Take rating directly from the place or use NoShowRatingPenalty.

## Saving

Saving ratings should be modified for leaderboards and will be described there. For ratings itself nothing is changes at this stage.

## Notes

Rating awarded is already transferred to client in PlayerFinalResult.Rating. Client devs just need to show it in UI.

After adding Rating to TournamentPlace, client devs will be able to show it in UI also.

# Competitive leaderboards

## Refac

TournamentKinds.Event - remove + all references.

Remove Events\* fields from TopTournamentPlayers.

TournamentKinds.Event - remove.

CalculateTopTournamentPlayer proc should be modified to exclude EventRating and all related field should be removed from TopTournamentPlayers. The main goal for this procedure is to calculate "Legacy" or "all time" rating. For this rating nothing will be rewarded, the process of awarding and calculating this rating will remain the same.

## DB & Capturing Rating

### Rating storage

Create new tables to store ratings:

CompetitiveRatingsCurrent - ratings in currently running period

* UserId - GUID - not null
* PeriodId - int - not null - (1 - Weekly, 2 - Monthly, 3 - Yearly)
* TournamentsPlayed - int - not null - default 0
* TournamentsWon - int - not null - default 0
* TournamentRating - int - not null - default 0
* CompetitionsPlayed - int - not null - default 0
* CompetitionsWon - int - not null - default 0
* CompetitionRating- int - not null - default 0

CompetitiveRatingWeeklyHistory - data for past weekly periods

* UserId - GUID - not null
* Year -  int - not null - year
* Week -  int - not null - week number in year
* TournamentKindId - int - not null - (TournamentKinds enum)
* DimensionId  - int - not null - (1 - Count, 2 - Won, 3 - Rating)
* Value - int - not null
* Place - int - not null
* RewardId - int - null - reward given, if any

CompetitiveRatingMonthlyHistory - data for past monthly periods

* UserId - GUID - not null
* Year -  int - not null - year
* Month -  int - not null - month number in year
* TournamentKindId - int - not null - (TournamentKinds enum)
* DimensionId - int - not null - (1 - Count, 2 - Won, 3 - Rating)
* Value - int - not null
* Place - int - not null
* RewardId - int - null - reward given, if any

CompetitiveRatingAnnualHistory - data for past year periods

* UserId - GUID - not null
* Year -  int - not null - year
* TournamentKindId - int - not null - (TournamentKinds enum)
* DimensionId - int - not null - (1 - Count, 2 - Won, 3 - Rating)
* Value - int - not null
* Place - int - not null
* RewardId - int - null - reward given, if any

### Rewards storage

Create new tables to store competitive leaderboard

CompetitiveLeaderboardRewards

* TournamentKindId - int - not null - (TournamentKinds enum)
* PeriodId - int - not null - (1 - Weekly, 2 - Monthly, 3 - Yearly)
* DimensionId - int - not null - (1 - Count, 2 - Won, 3 - Rating)
* Place - int - not null
* RewardId - int - null
* RewardName - string - null

One of the two - RewardId or RewardName must be not null (check constraint)

## Saving rating for leaderboards

Rating is saved in Profile, however player could be offline and it can receive the result later and the result will be applied later: after period end and period reset. On the other hand, rating should be accounted strictly in the period, when it was received.

End competitive activity procedure calculates the rating, prepares the rating increment, includes it in the result and result is sent to peer as the message. The same process now must:

* Save the increment and counts to the new CompetitiveRatingsCurrent table. This should be merge statement which creates the new row, or updates existing one.

New periodical leaderboard will be calculated based on CompetitiveRatingsCurrent table.

## Calculations

A new procedure to calculate periodical ratings should be created. The procedure should run as a job in Async. It should run daily, but should do anything only if period ends (week, month, year). Period end in UTC. Time to run should be 00:10 UTC. At 00:00 there should end the last competitive activity in the period. And there should be no competitive activity ending at 00:10-00:30 when the job runs. Account that several periods could end simultaneously. But each period could be calculated in an isolated manner, one after one.

What it does on period end:

* Populates temp table with period data from CompetitiveRatingsCurrent
* Sorts the data by each dimension, calculates and assigns places and rewards
* Inserts data into a table for appropriate period: CompetitiveRating\*History
* Deletes period data from CompetitiveRatingsCurrent (record deletion)
* Reorganizes CompetitiveRatingsCurrent table

After the data has been calculated and saved, Async should send reward messages to all winners for all dimensions. This will be the message containing period and dimension Ids as well as Reward Id to give.

Reward itself is processed and announced to client by peer. The reward in most cases should be a loot table.

If calculation process was failed for some reason, next run of calculations should find this out and process calculations for prior periods together with giving rewards. This will let us fix any calculation error, fix input data or deploy new fixed algorithm and the calculation will be resumed and fixed.

Async to remove data older than 3 years in \*History tables (estimate amount of data for 3 years and x10 more participants as of now in records).

## Client API

Review current GetTopTournamentPlayers op. It should serve as the API for legacy leaderboards. Remove Events from it.

General API approach:

* API function should return one period and one dimension at a time.
* Default UI view should be pre-cached on server start and pinned in memory.
* Top 100 is cached. Self (plus surrounding if needed) could be added to the cached data set if self is not in top 100.
*  Server should cache configurable number of (period + dimension) datasets. This should be defined by Global Variable so that caches do not take more than 1 GB RAM.

New API to be added:

* Return standing history in all periods and dimensions (top 100 + self).

    * All past periods are immutable so that server should cache them forever.

* Return current standing in all periods and dimensions (top 100 + self).

    * Current standing should also be cached and refreshed only after any competitive activity ends. (Ideally Async to send a refresh message to all Games or simply rely on competitive activity schedule - this does not work for tournaments as they are reviewed)

## Checks

[Competetive Activity Breaks](https://dev.fishingplanet.com/Stats/CompetetiveActivityBreaks) need to be extended to check:

* that there are no place breaks in Places array, so that all places are going one after the other and there are no gaps in between.
* To avoiding incorrect competition/tournament schedule.

    * No competition or tournament stage should end in a forbidden period (when period end Async job is scheduled).
    * Tournament stages (Qualification) could last for 2 days, stat in one day and end on another. Check that start and end day always belong to the same week/month/year. This is needed to make sure that player make scoring in the same period, where it will be accounted in tops.

## Sort order improvements

Based on the new leaderboards document https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/4121460746 we need to capture additional information in data and also use this data for sorting.

Add Timestamp DateTime columns to the following tables:

* CompetitiveRatingsCurrent
* CompetitiveRating\*History

The column in CompetitiveRatingsCurrent table should be filled up with the UTC date of the last update of the data in the table. The Timestamp should be equal for all ratings, earned in one competition.

\*History tables will be inherit the Timestamp from \*Current table.

Use Timestamp and player's experience to define player places in Leaderboards and make sure one player per place.

* For top rating - Timestamp + Experience (Full)
* For top played - Timestamp + Experience (Full)
* For top won - Timestamp

# Matchmaking

## DB

* Add GroupId - int - null - to TournamentParticipants
* Change GroupId to int in TournamentIndividualResults. Existing GroupId is not used there.
* Add GroupName - char(2) - null - to TournamentParticipants  / TournamentIndividualResults
* Add IsRated bit - not null - to TournamentParticipants . 1 by default.

Same changes should be done to Archive\* tables for tournaments and tournament archival process should be checked to function well.

## JSON Configuration

Grouping rules are taking into account only in Competitions and are ignored in Tournaments.

* `TargetSize` - nullable - the needed group size (ex. 20)
* `MinSize` - non-nullable - the minimum size of group (ex. 15)
* `CrossMovesAllowed` - bool - default true - if there is not enough participants from target group, we can take them from others.
* `CanceledIfIncomplete` - bool - default true - if the group still has less members than "Min group size" - the competitive activity is canceled for players in the group.
* `NotRatedIfIncomplete` - bool - default false - if the group still has less members than "Min group size" - rating is not calculated for this group, has less priority than CanceledIfIncomplete, additional client message needed.
* `IsLowRatingGroupProtectionOn` - bool - default true - Indicates whether players from upper buckets are protected from joining lower buckets if there is a higher bucket for them.
          If this flag is true, players from upper buckets never join lower buckets.
          If this flag is false, players from upper buckets could go to both lower and higher buckets to form a group closest to TargetSize.
* `Groups` - list of the groups, ordered by formation sequencing (first group in list is formed first, etc)

    * `GroupId` - int - must be unique for each group,
    * `GroupName` (internal only),
    * `MinRating` / `MaxRating` - int - rating bracket,
    * `RatingMultiplier` - double- default 1.0 - awarded rating increment is multiplied by this value for the group,
    * `RewardMultiplier` - double- default 1.0 - money rewards are multiplied by this value for the group.

If TargetSize is null (not configured, absent in config) - group does not have subgroups - all players, matching the groups are in.

Maximum size of the group is NOT configured, but it is calculated based on MinSize. The formular for maximum group size is:

MaxSize = (MinSize \*2) - 1.

Maximum size of the group is calculated because values less than (MinSize \*2) - 1 are not valid and those, greater are suboptimal (further than needed from TargetSize)

TargetSize should be still less than MaxSize.

Example of JSON configuration for competitive activity, describing groups:

```json
{
  ...
  "Grouping" : {
    "MinSize" : 15,
    "TargetSize" : 20,
    "CrossMovesAllowed" : true,
    "CanceledIfIncomplete" : true,
    "NotRatedIfIncomplete" : false,
    "IsLowRatingGroupProtectionOn" : true,
    "Groups" : [
      { "GroupId" : 1, "GroupName" : "Newbies", "MinRating" : 0, "MaxRating" : 499, "RatingMultiplier" : 1.0, "RewardMultiplier" : 1.0 },
      { "GroupId" : 2, "GroupName" : "Midles", "MinRating" : 500, "MaxRating" : 1999, "RatingMultiplier" : 1.5, "RewardMultiplier" : 1.5 },
      { "GroupId" : 3, "GroupName" : "Tops", "MinRating" : 2000, "MaxRating" : 2147483647, "RatingMultiplier" : 2.0, "RewardMultiplier" : 2.0 }
    ]},
  ...
}
```

[Competetive Activity Breaks](https://dev.fishingplanet.com/Stats/CompetetiveActivityBreaks) need to be extended to avoid incorrect values for group setting (review other checks):

* MinSize  < TargetSize  < MaxSize (calculated)
* CanceledIfIncomplete and NotRatedIfIncomplete  can't be both true. CanceledIfIncomplete will prevail.
* TargetSize and MaxSize are both null or not null.
* Group rating overlap (sort group by MinRating before check, because formation order could be different):

    * group\[0\].MinRating == 0
    * group\[i-1\].MaxRating == group\[i-1\].MinRating -1
    * group\[N-1\].MaxRating == int.MaxValue (2147483647 or null)

## Matchmaking process

The process begins within the `ProcessGrouping` method, which orchestrates the flow. It extracts the configuration, then creates top-level groups, then (if configured)  sub-divides them into smaller sub-groups.

### Extracting Grouping Configuration

The process extracts the configuration and validates it.

* The system first verifies if the tournament type (`KindId`) supports grouping and if a valid `TournamentGroupingRule` is provided. If these conditions are not met, the process terminates with an empty result.
* The full list of tournament participants is fetched via the `ITournamentProvider`.
* All participants are sorted in ascending order based on their `CompetitionRating`. This ensures that the subsequent distribution into rating-based "bins" is consistent and efficient.
* Participants are mapped into `TournamentGroupParticipant` objects, retaining essential data such as User ID and rating for the grouping logic.
* Before distribution, the `InitializeGrouping` logic ensures that the rating brackets defined in the rules are continuous. It sorts the rules by `MinRating` and automatically fills `MaxRating` gaps to ensure there are no "dead zones" between groups.

The `ProcessGroupingByRule` is called, provided with the grouping configuration and participant list.

### Working with Top-Level Groups

This stage is handled by the `ProcessTopLevelGroupsByRule` function, which converts the raw list of participants into balanced, high-level categories.

#### Creating Groups (`CreateGroups`)

The algorithm distributes participants into `TournamentGroup` objects based on the defined rating brackets:

* A `TournamentGroup` is created for each rule defined in the configuration.
* Participants are assigned to a group if their `CompetitionRating` falls within the group's `[MinRating, MaxRating]` range.

    * Within each group, participants are sorted by rating, and the group's aggregate rating statistics are updated.

#### Balancing Groups (`BalanceGroups`)

The `CrossMovesAllowed` configuration parameter is now deprecated. It will be removed in the future.

A balancing mechanism is triggered to ensure every group meets the `MinSize` requirement.

**Phase A: Ping-Pong Traversal**
The system uses a "Ping-Pong" iterator to traverse the groups.

<!-- Image: Ping-pong traversal of the seven groups -->

* Each group is visited exactly once.
* The algorithm looks at the first group, then the last, then the second, then the second to last, etc.
* Empty groups are skipped.
* Groups having at least `MinSize` players are considered complete, so they are skipped as well.
* If a group is not empty and is found to be below the `MinSize`:

    * The algorithm looks for participants in neighboring groups that were not visited yet and pulls them to the current group.
    * If the neighbor is **stronger** (higher rating bracket), it takes the participant with the **lowest** rating first.
    * If the neighbor is **weaker** (lower rating bracket), it takes the participant with the **highest** rating first.
    * If the adjacent group is emptied, it looks for the next adjacent group behind it.
    * This continues until the current group reaches `MinSize` or no more adjacent participants are available.

* If the group was already visited, it is considered complete. No players can be pulled from it anymore.
* The last group in the sequence _may_ have insufficient players (less than `MinSize`). It will be dealt with in the next phase.

**Example 1:** There are **three** groups: `[1]`, `[2]`, `[3]`. Below is the order of completing the groups.

| **Visiting order** | **Group visited** | **If not enough players, can pull players from groups** |
| --- | --- | --- |
| #1 | `[1]` | `[2]`, `[3]` |
| #2 | `[3]` | `[2]` |
| #3 | `[2]` | - |

**Example 2:**  There are **four** groups: `[1]`, `[2]`, `[3]`, `[4]`. Below is the order of completing the groups.

| **Visiting order** | **Group visited** | **If not enough players, can pull players from groups** |
| --- | --- | --- |
| #1 | `[1]` | `[2]`, `[3]`, `[4]` |
| #2 | `[4]` | `[3]`, `[2]` |
| #3 | `[2]` | `[3]` |
| #4 | `[3]` | - |

**Example 3:**  There are **five** groups: `[1]`, `[2]`, `[3]`, `[4]`, `[5]`. Below is the order of completing the groups.

| **Visiting order** | **Group visited** | **If not enough players, can pull players from groups** |
| --- | --- | --- |
| #1 | `[1]` | `[2]`, `[3]`, `[4]`, `[5]` |
| #2 | `[5]` | `[4]`, `[3]`, `[2]` |
| #3 | `[2]` | `[3]`, `[4]` |
| #4 | `[4]` | `[3]` |
| #5 | `[3]` | - |

**Phase B: Final Merging of Incomplete Groups**
After the traversal, if any group still fails to meet the `MinSize` (often due to low overall tournament turnout), it must be merged:

* The system searches for the nearest non-empty group to absorb the incomplete one.
* The algorithm prioritizes merging an incomplete group into a **stronger** one. This "upward" merging protects lower-rated brackets from being dominated by significantly stronger players from a collapsed higher bracket.
* Fallback: if no stronger group is available, it merges into the nearest weaker group.

At the conclusion of this stage, the `TournamentGroup[]` array represents stabilized rating categories, ready to be further divided into specific match-sized subgroups (if configured).

### Creating subgroups

\[TBD\]

## Tournament lifecycle change

Following changes / additions are needed for competitive activity lifecycle:

* Start competition (TournamentStartAdapter.StartTournaments)

    * Calculate player group based on player's current competition rating,
    * Form groups based on Grouping config,

        * Groups (GroupName) should be named as "A", "B", "C" and after "Z" is reached "AA", "AB", "AC", ...

    * Disband incomplete groups if any, cancel competition for them,
    * Set IsRated = 0 if group is incomplete and NotRatedIfIncomplete is set.

* In competition (op GetCurrentTournamentResult)

    * Return standing only inside the Group in HUD
    * If player will go to the competition menu and selects the competition, there will be shown current results accross all groups.

* End competition (TournamentEndAdapter.EndTournaments)

    * Calculate score, places and rewards inside the group (loop through groups with current calculations).
    * Set rating increment for the place.
    * Change score and place calculation, so that non-participating player:  (1) will have the last place, (2) no reward (even if the number of participants in below 10), (3) have the penalty according to the settings.
    * Send results for all groups specifying the Group Id and Name in Results, sorted by group asc, place desc.

* Results / Archive - Hall of Fame (GetFinalTournamentResult / GetTournamentSecondaryResult)

    * Send results for all groups specifying the group in Results, sorted by group asc, place desc.

# Scheduling

Scheduling (TournamentSchedulingAdapter.ScheduleTournements)

* Adjust scheduling for the new sync competitions/tournaments, change the view of competition / tournament grid on client (if it will be affected)

# Testing

A new tool has to be developed for the web admin panel under the _Tools_ → _Competitions_ section that allows users to simulate player registration for a competition. The simulation has to involve:

*  loading player groups from the competition configuration, allowing to specify the number of players for each group;
* registering players into a competition;
* assigning resulting scores for each player.

## Test matchmaking setup

### Starting matchmaking simulation

Once a test competition is generated **and has not been started**, the user can input its `TemplateId` and click the **Simulate Matchmaking** button, which will:

* Load rating-based player groups from the competition configuration. **For example**, these groups typically include:

    * **Newbies**
    * **Middles**
    * **Tops**

* Display a form where the user can input the number of players for each group.

Attempting to add users to already started competition **has to result in error**.

### Player Selection Form

* The form will include input fields for specifying the number of players to simulate in each of the groups (in our example case, Newbies, Middles, Tops).
* Once the user clicks **Next**, the system should:

    * Retrieve the specified number of player profiles from the database for each group.
    * Register these players in the competition.

### Player Score Assignment

* After players are registered, the tool will display lists of players divided by group.
* Each player will have two editable fields next to their name:

    * **Primary Score**
    * **Secondary Score**

* There will be an optional **Randomize Scores** button to auto-fill these score fields with random values ( (primary score: 1 to 1000, secondary score: 1 to 250) for each player.
* After filling or randomizing the scores, the user will be able to click the **Save** button, which will save the **Primary Score** and **Secondary Score** for each player into their Tournament Result record.

## Viewing matchmaking results

### Competition Results Tool

* The current tool used for viewing competition results (_Stats → Competitive Activity Schedule_) should be modified to include a new column:

    * **Group Name**: The player's group (Tops, Middles, or Newbies) should be displayed in this column.

* The tool should also allow sorting or grouping players by this **Group Name** column for easier review.

# Estimates

Preliminary estimates for server implementation and auto-testing:

* Rating - 1.5 sp
* Leaderboards - 5 sp
* Matchmaking - 7 sp
* Scheduling - 2 sp
* **Totally - 15.5 sp**

+2sp for sorting
