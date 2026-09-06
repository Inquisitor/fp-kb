# Remediation notes for the affected player (parked while the ban decision is pending)

User `88236613-788f-4fcc-a8b5-7b229b8ed1fc`, Steam. Numbers below were read on 2026-09-06 and go stale
while the player keeps playing; re-read the profile before acting.

## Overflow catches
| When (UTC)          | Fish                          | Slot | XP granted    | Base XP |
|---------------------|-------------------------------|------|---------------|---------|
| 2026-09-05 16:55:29 | European Sea Sturgeon 96.9 kg | 3    | 1,073,751,659 | 6,571   |
| 2026-09-06 14:58:51 | Atlantic Halibut 78.5 kg      | 2    | 1,073,752,607 | 7,199   |

## Experience revert
Total XP on the profile = `Experience + RankExperience` (cap 109,502,130 at level 110, then
6,000,000 per rank). Pre-incident state derived from the first catch: level 60, 2,531,512 XP.
Revert = total minus the overflow amounts; the remainder is legit play (plus the two base XP values if
the fish are to be credited). Level comes from the `Levels` table (`Experience` column = start of level).

```sql
-- FP-46092: revert the overflow XP for user 88236613; run only while the player is offline (or after Disconnect in WebAdmin)
UPDATE Profiles
SET Level = <level for the new total>,
    Experience = <total - 1073751659 - 1073752607>,
    Rank = 0,
    RankExperience = 0,
    ProfileJson = JSON_MODIFY(ProfileJson, '$.RankExperienceInRanks', 0)
WHERE UserId = '88236613-788F-4FCC-A8B5-7B229B8ED1FC'
  AND Level = <current Level> AND Rank = <current Rank>
  AND Experience = <current Experience> AND RankExperience = <current RankExperience>;
```
The WHERE guard makes the statement a no-op if the profile moved. `ExpToThisLevel` and friends in
`ProfileJson` are recomputed on profile load (`ProfileAdapter.RecalculateExperience`).
Equivalent audited path: WebAdmin Tools -> Update profile (Level, Experience Offset, Rank 0, Rank
Experience Offset 0) writes `AdminActionLog` and the Security log, but has no guard.

## Rewards granted by the overflows
First catch: 211 level/rank rewards, 5,064,000 silver and 1,084 gold (premium doubling). The second
catch granted another 179 rank rewards; totals to be re-read from Stats `Stmt`
(`Msg LIKE '%- Rank % gained'` / `'%- Level % gained'`, amounts are the leading number).
WebAdmin Tools -> Give coins accepts negative amounts (`SilverCoins + @SilverCoins`, no sign check).
The player spent the silver on saltwater gear and travel within hours (Stats `Stmt`, `Item bought`,
`Arrived to Pond`); by 2026-09-06 the balance was 343,123 silver, so a full clawback goes negative.
If the account is banned, none of this matters.
