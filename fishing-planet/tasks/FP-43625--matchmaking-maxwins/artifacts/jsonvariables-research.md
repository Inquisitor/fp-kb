# JsonVariables-based default Grouping config

## Why this matters for FP-43625

Prod inventory across Steam/PS/Xbox (verified 2026-05-17): 103 active competition templates per platform, 454 future Competitions across three platforms, all carrying **semantically identical** `Grouping` JSON modulo whitespace. **Zero per-template or per-tournament overrides** anywhere on prod.

Three concrete benefits if grouping moves to a single `JsonVariable`:

1. Adding `MaxWins/Max2nd/Max3rd` becomes a **one-row INSERT** on `dbo.JsonVariables` instead of a per-row `JSON_MODIFY` over hundreds of `Tournaments` and `TournamentTemplates` rows. The "future-tournaments-already-generated-with-old-schema" class of failure (matchmaking module log, 2026-04-29 incident) disappears once `Grouping` lives in one place.
2. Future schema extensions (e.g., a `MaxMedals` if abuse pivots) are similarly cheap.
3. `Midles -> Middles` typo gets fixed once in the variable instead of patching all per-row copies.

Cost: one new partial-class file, one consumer change in the matchmaking entry path, one migration script.

## Storage shape

`dbo.JsonVariables(Name VARCHAR PK, Json VARCHAR(MAX), OrderId INT)`. Loaded via `SqlSysProvider.GetJsonVariables` as `IEnumerable<KeyValuePair<string,string>>`.

`SharedLib.Config.JsonVariablesCache` is a static partial class. Each domain extends it with a nested static class providing strongly-typed accessors:

```csharp
public static partial class JsonVariablesCache
{
    public static class DailyMissions
    {
        public const string GenerationSettingsKey = "DailyMissions.GenerationSettings";
        public static GenerationSettings GenerationSettings { get; private set; }

        internal static void UpdateStaticVariables()
        {
            GenerationSettings = JsonVariables.Cache.GetJsonValue<GenerationSettings>(GenerationSettingsKey);
            GenerationSettings ??= new GenerationSettings();
        }
    }
}
```

Top-level `JsonVariablesCache.UpdateStaticVariables` invokes each domain's `UpdateStaticVariables`. Auto-refresh fires on cache invalidate via `OnRefreshPerformed`.

## Design

**Bake-at-start overlay with persistence.** Site: `MatchmakingLogic.ProcessGroupingForTournament` entry. Resolution: `tournament.Grouping ?? JsonVariablesCache.Tournaments.GroupingDefault`. After a successful matchmaking pass, when `tournament.Grouping` was null at entry, the resolved `Grouping` is serialised back into `Tournament.ConfigJson` via a new `ITournamentProvider.PersistTournamentGrouping` call. The row then carries an audit snapshot of what governed the matchmaking that ran.

Migration drops `Grouping` from all active competition templates and from all future tournaments via idempotent `JSON_MODIFY(..., '$.Grouping', NULL)`. Newly generated tournaments produced after migration inherit no `Grouping`, fall through to the default at start, and bake the snapshot then. Already-played tournaments are untouched — they keep their actual matchmaking config as historical audit.

Per-template override remains as a free escape hatch: if any future template ever needs to deviate, populating `template.Grouping` causes generated tournaments to carry the override, the overlay's `??` short-circuits, and the override is baked normally. No code change needed for that path.

## Why bake-at-start beats live-only overlay

Two viable variants once the overlay site is chosen at `ProcessGroupingForTournament`:

| Variant       | Tournament.ConfigJson after first matchmaking | Audit query "what did Comp X use?"                                                             |
|---------------|-----------------------------------------------|------------------------------------------------------------------------------------------------|
| Live-only     | Unchanged (still null)                        | Reads JsonVariable as-of-now; if GD edited it since, the answer is wrong for past tournaments  |
| Bake-at-start | Resolved Grouping snapshot in ConfigJson      | Reads Tournament.ConfigJson directly; answer is correct regardless of later JsonVariable edits |

Bake-at-start also closes a subtle correctness gap. With live-only, if GD edits the JsonVariable mid-tournament-window (between matchmaking-at-start and reward distribution), downstream code reading `Tournament.Grouping` would see the new value while bracket assignment used the old. Bake-at-start writes the resolved snapshot atomically with matchmaking and downstream reads the snapshot, never the live default.

Cost of bake-at-start over live-only: one extra `UPDATE` per matchmaking event. Matchmaking runs once per tournament; cost is negligible.

The other extreme — overlay at deserialization in `TournamentsHelper.FromDto` — was rejected. It pulls in WebAdmin edit-flow questions (does the edit view round-trip the default back into the row?) and a two-overload mirror change (`FromDto(TournamentDto)` and `FromDto(TournamentTemplateDto)`) that has historically been the root cause of asymmetry defects (FP-43553 incident, tracked by FP-43717). Larger blast radius, unnecessary for the MaxWins delivery.

## Concrete stub

New file `Shared/SharedLib/Config/JsonVariablesCache_Tournaments.cs`:

```csharp
using ObjectModel.Tournaments;

namespace SharedLib.Config
{
    public static partial class JsonVariablesCache
    {
        public static class Tournaments
        {
            public const string GroupingDefaultKey = nameof(Tournaments) + "." + nameof(GroupingDefault);

            public static TournamentGroupingRule GroupingDefault { get; private set; }

            internal static void UpdateStaticVariables()
            {
                GroupingDefault = JsonVariables.Cache.GetJsonValue<TournamentGroupingRule>(GroupingDefaultKey);
                // No hardcoded fallback. Null means "no default configured" and
                // matchmaking skips grouping for tournaments without per-row
                // override - same behaviour as before this change.
            }
        }
    }
}
```

Wire-up in top-level `JsonVariablesCache.UpdateStaticVariables`:

```csharp
private static void UpdateStaticVariables()
{
    DailyMissions.UpdateStaticVariables();
    WebAdmin.MergedLog.UpdateStaticVariables();
    Tournaments.UpdateStaticVariables();   // <- new
}
```

Consumer change in `MatchmakingLogic.ProcessGroupingForTournament`:

```csharp
private static TournamentGroup[] ProcessGroupingForTournament(Tournament tournament, ITournamentProvider provider)
{
    var usedDefault = tournament.Grouping == null;
    var grouping = tournament.Grouping ?? JsonVariablesCache.Tournaments.GroupingDefault;

    if (tournament.KindId != (int)TournamentKinds.Competition || grouping == null)
        return new TournamentGroup[] { };

    InitializeGrouping(grouping);   // idempotent; safe for per-row overrides too

    var participants = provider
        .GetTournamentParticipants(tournament.TournamentId, true)
        .OrderBy(p => p.CompetitionRating)
        .Select(p => new TournamentGroupParticipant {
            UserId = p.UserId,
            CompetitionRating = p.CompetitionRating,
            // LifetimeGold/Silver/Bronze populated by the FP-43625 MaxWins gate work
        })
        .ToList();

    var groups = ProcessGroupingByRule(grouping, participants);

    if (usedDefault && groups != null)
        provider.PersistTournamentGrouping(tournament.TournamentId, grouping);

    return groups;
}
```

Behavioural changes:

1. `tournament.Grouping == null` no longer means "skip matchmaking" — it means "use the default".
2. `InitializeGrouping` is invoked unconditionally at matchmaking entry. Idempotent. The path-asymmetry symptom from FP-43553 closes regardless of whether FP-43717 lands.
3. Editing the `JsonVariable` is hot — next `ProcessGrouping` call (at tournament start) picks up the new value.
4. After first matchmaking, the resolved `Grouping` is baked into `Tournament.ConfigJson`. Subsequent reads of the row see exactly what governed the matchmaking that ran.

New `ITournamentProvider.PersistTournamentGrouping(int tournamentId, TournamentGroupingRule grouping)`. Implementation: `UPDATE Tournaments SET ConfigJson = JSON_MODIFY(ConfigJson, '$.Grouping', JSON_QUERY(@grouping)) WHERE TournamentId = @tournamentId`. Single statement, idempotent.

## Migration SQL (sketch)

Single transaction per platform, idempotent:

```sql
-- 1. Insert the default Grouping variable with corrected "Middles" spelling
--    and MaxWins/Max2nd/Max3rd fields used by the FP-43625 MaxWins gate.
MERGE dbo.JsonVariables AS target
USING (VALUES (
    'Tournaments.GroupingDefault',
    N'{
      "MinSize": 20,
      "Brackets": [
        { "BracketId": 1, "BracketName": "Newbies", "MinRating": 0,    "MaxWins": 3,  "Max2nd": 4,  "Max3rd": 5,  "RatingMultiplier": 1.0, "RewardMultiplier": 1.0 },
        { "BracketId": 2, "BracketName": "Middles", "MinRating": 101,  "MaxWins": 12, "Max2nd": 15, "Max3rd": 20, "RatingMultiplier": 1.0, "RewardMultiplier": 1.0 },
        { "BracketId": 3, "BracketName": "Tops",    "MinRating": 1001,                                            "RatingMultiplier": 1.0, "RewardMultiplier": 1.0 }
      ]
    }',
    100
)) AS src(Name, Json, OrderId)
ON target.Name = src.Name
WHEN MATCHED THEN UPDATE SET Json = src.Json
WHEN NOT MATCHED THEN INSERT (Name, Json, OrderId) VALUES (src.Name, src.Json, src.OrderId);

-- 2. Strip per-row Grouping from future tournaments. On their start the overlay
--    resolves the default and bakes a snapshot back into ConfigJson.
--    Already-played tournaments are NOT touched - they carry their actual
--    matchmaking config as historical audit.
UPDATE dbo.Tournaments
SET ConfigJson = JSON_MODIFY(ConfigJson, '$.Grouping', NULL)
WHERE KindId = 3
  AND EndDate > SYSUTCDATETIME()
  AND JSON_QUERY(ConfigJson, '$.Grouping') IS NOT NULL;
-- Prod row counts (verified 2026-05-17): Steam 151, PS 151, Xbox 152.

-- 3. Strip Grouping from active competition templates. Inactive templates
--    (IsActive=false, 29 per platform) already carry no Grouping and are
--    filtered out automatically.
UPDATE dbo.TournamentTemplates
SET ConfigJson = JSON_MODIFY(ConfigJson, '$.Grouping', NULL)
WHERE KindId = 3
  AND JSON_QUERY(ConfigJson, '$.Grouping') IS NOT NULL;
-- Prod row counts (verified 2026-05-17): 103 per platform.
```

After migration, every newly-generated and not-yet-started Competition resolves through the JsonVariable on start and bakes its own snapshot. If a per-template override is ever needed, populating `$.Grouping` on a specific template row makes generated tournaments inherit it; the overlay's `??` short-circuits and the override is baked normally.

## Risks and mitigations

- **Cache load order at startup.** `MatchmakingLogic.ProcessGrouping` runs at tournament start, well after `JsonVariablesCache.InitDefault()`. No race possible. Verified by tracing `JsonVariablesCache.Initialize` callers from `LoadBalancing` startup.
- **Round-trip in WebAdmin.** Admin edit views read `Tournament.Grouping` directly. When it is null, they show empty — already the case for non-Competition tournaments. Future enhancement: add a "view default" link in admin so editors can see the active default.
- **Test coverage.** New integration tests target the `ProcessGroupingForTournament` boundary: tournament with per-row Grouping uses the override; tournament without uses the default; both null skips matchmaking. Tests for the algorithm itself (in `MatchmakingLogicTests`) construct `TournamentGroupingRule` directly and do not exercise the overlay.
- **Reversibility.** Single-line revert in `ProcessGroupingForTournament`. The JsonVariable row stays harmless if no consumer reads it.

## Cache-refresh cadence

Changes to the `JsonVariable` take effect on the next cache reload (`Caches.Instance` global cycle). If GD needs faster iteration during tuning, the existing `JsonVariables` admin page may already provide a manual reload — to be verified during WebAdmin Tools work.
