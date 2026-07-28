---
module: missions
status: stub
---

# Missions

Mission conditions, interactions, and progression tracking for player tasks.

## Entry Points

- `MissionCache.LoadAllMissions` — `Shared/SharedLib/Config/MissionCache.cs` (deserializes `Missions.ConfigJson` / `MissionTasks.ConfigJson` from `Main`; stored config is a **JSON5-like dialect, not strict JSON** — unquoted object keys, single-quoted strings, e.g. `{ type: 'WeatherCondition', WeatherName: 'Sunny', Hour: 18 }` — so a `LIKE`/regex probe over `ConfigJson` written for quoted keys matches nothing)
- `MissionsSerializationUtils.DeserializeMission` / `DeserializeTask` / `DeserializeHint` — `Shared/ObjectModel/Mission/MissionsSerializationUtils.cs` (`PreprocessJson` normalises the dialect first; each builds its own `JsonSerializerSettings` leaving `MissingMemberHandling` at `Ignore`, so a key the model no longer declares is dropped with no exception and nothing in `mission.LastException` — renaming a condition's `[JsonProperty]` silently drops that constraint from every stored mission still using the old key, and needs a legacy alias or a content migration)

## Key Types

TBD

## Dependencies

TBD

## Deep Dives

- [Condition monitoring and re-arming](condition-monitoring.md) *(draft)* — dynamic watched sets, dependency-key shapes, re-arming, the transient-state contract, why stalls happen

## Related Tasks

- FP-41754 — added `GenerationDepth` tracking for fish condition fields (r15807)
- FP-42557 — air/water temperature bounds on `WeatherCondition`; its review established the storage dialect and the silent-drop rename hazard above
- FP-45262 — follow-up from that review: weather-variant chain and automatic-hint defects (open)
