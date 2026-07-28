---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16073
jira: https://fishingplanet.atlassian.net/browse/FP-42557
---

# Review: FP-42557 — Air Temperature Checking Functionality

## Summary

Mission-system weather conditions could previously only check a coarse temperature category (cold / hot). The task extends the mission condition to check air and water temperature in degrees, so event missions can require e.g. "in a kayak, at air temperature below -7 °C, catch a unique Burbot with vertical jigging". Server-side work adds air/water temperature bounds to `WeatherCondition` and renames `Weather.Temperature` to `WaterTemperatureType`; the client mirrors the rename.

## Scope

### MFT20260325
- **r16073** — Add air/water temp bounds to `WeatherCondition` + rename `Weather.Temperature` to `WaterTemperatureType`
  - `Weather` gains `AirTemperature`; `Temperature` renamed to `WaterTemperatureType`
  - `WeatherCondition` / `WeatherResource` / `IWeatherResource` / `MoveTimeWeatherHint` gain `MinAirTemperature`, `MaxAirTemperature`, `MinWaterTemperature`, `MaxWaterTemperature` (inclusive bounds), copied from the weather resource in `EnsureConfiguration`
  - `ConditionExtensions.MatchWeather` checks the new bounds and counts them in the empty-mask test
  - `TravelAdapter.WeatherDescToWeather` copies `AirTemperature` from the DTO
  - New `ObjectModel.Tests/Mission/ConditionsGame/WeatherConditionTests.cs`; an added test in `TravelAdapterTests`

### CodeBranch (client)
- **r53902** — Rename `Weather.Temperature` to `WaterTemperatureType` (`Assets/Photon Server Networking/ObjectModel/Travel/Weather.cs` only)

## Investigation Journal

- Intake: JIRA `customfield_11224` (Executor) is empty; executor identified as Yuriy Burda from the commit-listing comment (2026-05-07).
- VCS audit: `svn log | grep FP-42557` over MFT20260325 (r15943:HEAD), NPN20260602 (r16131:HEAD) and LBM20251201 (r15396:HEAD) — exactly one server commit (r16073, MFT), matching intake; no commits on NPN or LBM.
- Branch-copy inheritance: r16073 ≤ MFT copy source r16130, and `svn cat` of `Shared/ObjectModel/Travel/Weather.cs` on NPN20260602 shows both `WaterTemperatureType` and `AirTemperature` — inherited via the branch copy, no merge to the Code branch needed.
- WC freshness: WC root at r16364 (> r16073), so on-disk reads reflect post-fix state.
- Client mirror: `svn cat` of `Weather.cs` in `Unity_Fishing_MainClient` shows the rename present, so the client half is in the Content-role branch the Anniversary release ships from. `ObjectModel/Mission/ConditionsGame/` on the client holds only `AssembleRodCondition` and `InventoryCondition` — `WeatherCondition` has no client copy, so the new mission-condition fields need no mirror. Client `WeatherDesc.cs` already carries `AirTemperature`, so the client's own air-temperature feed is unaffected by `Weather` gaining the field server-side.
- Rename blast radius (hypothesis under verification): `Temperature` is a `[JsonProperty]` with no explicit `PropertyName` on `WeatherCondition`, `WeatherResource` and `MoveTimeWeatherHint`, so the JSON key stored in mission content changes with the property name. `SerializationHelper.JsonSerializerSettings` leaves `MissingMemberHandling` at its default (`Ignore`), so a stored `"Temperature"` would be dropped silently. Local dev DB (`Main`): `Missions.ConfigJson` 4/966 and `MissionTasks.ConfigJson` 55/4157 rows mention `WeatherCondition`, but zero rows in either table — and zero in `MissionHintMessages`, `Events`, `Tournaments`, `TournamentTemplates`, `Ponds.BaseConfigJson`, `GameScenarios`, `Locations`, `Profiles.ProfileJson` — contain the `"Temperature"` key. Prod exposure not yet checked.
- `Weather` construction paths: `WeatherDescToWeather()` is the only production factory feeding `MissionsContext.Weather` / `FullDayWeather` / `config.CurrentWeather` (`TravelAdapter.InitWeatherInMissionsContext`, `MultiRodGameProcessor`); `Weather.Parse` is test-only. So `AirTemperature` is populated on every runtime path the new bounds read.
- `ObjectModel.Tests.csproj` is SDK-style — the new test file is picked up without an explicit `Compile` entry.
- Prod content exposure — first probe was wrong and was discarded: a sample row (`MissionTasks.ConfigJson`, Steam prod) shows mission config is stored in a JSON5-like dialect with **unquoted keys** (`{ type: 'WeatherCondition', WeatherName: 'Sunny', Hour: 18, Range: 2 }`), so the `LIKE '%"Temperature"%'` pattern could never match anything and its zero result proved nothing. Re-probed with the bare substring: on every F2P prod MAIN database (Steam/EGS, PlayStation, Xbox, Mobile, Nintendo) `Missions.ConfigJson` and `MissionTasks.ConfigJson` contain zero rows with `Temperature`, while `WeatherName` matches 49-50 task rows and 4 mission rows on each — the instrument does match live weather keys, so the negative is meaningful. `Ponds.DailyMissionJson` / `Fish.DailyMissionJson` also zero on the platforms that have those columns (Mobile and Nintendo prod lack them entirely). Scope caveat: this binds to the current content snapshot only.
- Executor claim "TODO: update docs - Done" verified against Confluence "Mission System Manual" (page 194445313): it documents `WaterTemperatureType: 'Cold|Medium|Warm|Hot' // Renamed from Temperature`, the new bounds with explicit `°C (inclusive)` annotations, and the renamed field inside the `FirstWeather`/`SecondWeather`/`ThirdWeather` variants.
- `MissionsContext.FullDayWeather` is written when the mission context is initialised (`TravelAdapter.InitWeatherInMissionsContext`, `MultiRodGameProcessor`) but has no reader in server code — mission-config expressions could reach it by name, so "unused" is not established.
- Deserialization path verified directly: `MissionsSerializationUtils.DeserializeMission`, `DeserializeTask` and `DeserializeHint` each build a local `JsonSerializerSettings` with only `NullValueHandling` and `TypeNameHandling` set, so `MissingMemberHandling` stays at its `Ignore` default — an unknown key is dropped without an exception and without a `LastException` entry.
- Feature adoption in content: on `[F2P] TEST` and `[F2P] QA`, mission 3958 / `Task_2` (TaskId 15690) carries `{ type: 'WeatherCondition', MaxAirTemperature: -7 }` — the new field is in use and matches the ticket's scenario. Note the bound is inclusive, so this content admits exactly -7 °C, whereas the ticket text says "below -7 °C"; the Confluence manual documents the inclusive semantics, so this is a content decision, not a code defect.
- New tests run green on HEAD: `dotnet test Shared/ObjectModel.Tests/ObjectModel.Tests.csproj --filter FullyQualifiedName~WeatherConditionTests` → 13 passed, 0 failed.
- Delegated review (Codex) surfaced the variant-chain/time-window defect in `ConditionExtensions.Match` that neither recon nor the agent had spotted; re-verified independently by reading `WeatherCondition.cs` (the three-arg `Match` selects the first weather-compatible mask and evaluates `MatchTime` only for that one, with no resumption of the chain). Live-content exposure probed on Steam prod: all 50 `WeatherCondition` tasks discriminate their variants by `WeatherName`, which is mutually exclusive, so at most one variant passes `MatchWeather` today.
- Codex's "hint loses the secondary time window" scenario re-verified against content: of the 50 live `WeatherCondition` tasks, 15 combine `AutomaticHints` with `Hour2`/`TimeOfDay2`. An initial sample suggested the secondary window always sits inside a variant; a full probe over those rows confirmed it — every one declares variants, and none places `Hour2`/`TimeOfDay2` ahead of `FirstWeather` in the payload. Since variant objects reach the hint by reference, the copy gap does not bite in current content; the mechanism is real but its manifestation is absent.
- Close: release-step field (`customfield_11323`) derives to no options — the diff touches no `SQL/Patches`, `SQL/Releases`, `NoSql`, WebHooks or Twitch path, no profile conversion and no content rows for DataPump — so the empty field is correct, not a gap. Executor field (`customfield_11224`), empty throughout the review, was filled in with Yuriy Burda during the close, and the ticket moved to Resolved. F-2 through F-5 filed as FP-45262 (Story, Scrum Team `Tech Debt`, component `Server`, related to FP-42557); the local issue draft was dropped once the issue existed.
- Delegated review (code-reviewer agent) independently reached the same code-rooted findings as recon (rename without back-compat; the misnamed test that does not exercise `EnsureConfiguration`), and rejected the `Hour2`/`Range2`/`TimeOfDay2` asymmetry and the hint's "move a day forward" behaviour as pre-existing. The agent had no Bash tool, so it read disk state instead of the diff, and had no DB access — its "Critical" rating for the rename rests on an unresolved hypothesis about live content that the prod probes above settle as zero exposure.

## Findings

### F-1: Renaming the `Temperature` JSON property ships without a back-compat alias or a content migration [Low]

**Description:** `WeatherCondition`, `WeatherResource`, `MoveTimeWeatherHint` and `Weather` renamed `Temperature` to `WaterTemperatureType`. Each declares `[JsonProperty]` with no explicit name, so the stored JSON key changes with the property. Mission content is deserialized with `MissingMemberHandling` left at `Ignore`, so a stored `Temperature` would be dropped without an exception: the coarse temperature restriction would silently vanish, and where it was the mask's only field the mask becomes "empty", which `ConditionExtensions.MatchWeather` treats as a non-match — turning the task unachievable rather than merely easier. Severity is Low, not High, only because current content nowhere uses the key.

**Investigation:**
- Read the renamed declarations in `WeatherCondition.cs` and `Weather.cs` and confirmed none carries `[JsonProperty("Temperature")]` or a legacy setter.
- Read `MissionsSerializationUtils.DeserializeMission` / `DeserializeTask` / `DeserializeHint`: each constructs `JsonSerializerSettings` with only `NullValueHandling` and `TypeNameHandling`, leaving `MissingMemberHandling` at its `Ignore` default — unknown keys are dropped silently, with no `LastException` entry.
- Commit contains no SQL patch; `svn log | grep FP-42557` found no companion migration commit on any branch.
- Content exposure, every F2P prod MAIN DB (Steam/EGS, PlayStation, Xbox, Mobile, Nintendo): zero rows in `Missions.ConfigJson` / `MissionTasks.ConfigJson` contain the substring `Temperature`. Probe validated on the same population by `WeatherName`, which matches 49-50 task rows and 4 mission rows per platform. An earlier `LIKE '%"Temperature"%'` probe was discarded as incapable: sampled content proved mission JSON uses unquoted keys.
- `Ponds.DailyMissionJson` / `Fish.DailyMissionJson` also zero where those columns exist; Mobile and Nintendo prod do not have them.
- Scope caveat: the negative binds to the current content snapshot. Post-deploy the new name is canonical, so the risk window is limited to content authored before the deploy and not yet re-saved.
- Review owner confirmed the zero exposure is not accidental: the coarse `Cold|Medium|Warm|Hot` categories were never adopted in content because the designers wanted granularity the categories could not express. That is why the rename could ship without a compatibility shim.

**Resolution:** Accepted — the breaking mechanism is real but has zero content exposure on every platform; no migration is warranted for content that does not exist.

**Discovered by:** skill recon (independently reported by the code-reviewer agent and by Codex).

### F-2: `ConditionExtensions.Match` abandons the variant chain when the first weather-compatible mask fails the time window [Medium]

**Description:** The three-argument `Match(Weather, IWeatherResource, int)` calls the weather-only overload, which returns the *first* mask passing `MatchWeather`, then evaluates `MatchTime` for that mask alone. If that mask's time window fails, the method returns false without trying the remaining variants, even when a later variant would satisfy both weather and time. The new degree bounds turn this from theoretical into reachable: temperature ranges overlap by nature, whereas the `WeatherName` values that currently discriminate variants are mutually exclusive.

**Investigation:**
- Read `ConditionExtensions.Match` (both overloads) in `WeatherCondition.cs`: the weather-only overload returns on the first `MatchWeather` hit, and the three-arg overload has no loop or fallback after `MatchTime` fails.
- Live exposure probed on Steam prod: all 50 `WeatherCondition` tasks discriminate `FirstWeather`/`SecondWeather`/`ThirdWeather` by `WeatherName`; sampled payloads confirm distinct names per variant, so at most one variant can pass `MatchWeather` and the defect cannot fire on today's content.
- Pre-existing: the diff of r16073 does not touch either `Match` overload.

**Resolution:** Pre-existing → `Filed → FP-45262` (tech-debt follow-up, related to FP-42557). Filing was deferred until the review completed so the whole area could go in one issue.

**Discovered by:** Codex.

### F-3: `MoveTimeWeatherHint.EnsureConfiguration` never copies `Hour2` / `Range2` / `TimeOfDay2` from the weather resource [Low]

**Description:** `WeatherCondition.EnsureConfiguration` copies the secondary time window from its resource; the hint's counterpart copies only `Hour`, `Range`, `TimeOfDay` and then jumps to the new temperature bounds. A hint whose source condition sets a secondary window on the main mask therefore sees no time restriction at all, so `MatchTime` returns true unconditionally and the automatic hint stays silent when it should fire.

**Investigation:**
- Compared both `EnsureConfiguration` bodies at HEAD: the new bounds are copied symmetrically; only the secondary window is missing from the hint.
- `svn cat -r 16072` of `MoveTimeWeatherHint.cs` shows `Hour2`/`Range2`/`TimeOfDay2` already declared and already not copied — pre-existing, not introduced here; the commit added its copy blocks immediately below the gap without closing it.
- Live exposure, Steam prod: 15 of the 50 `WeatherCondition` tasks combine `AutomaticHints` with `Hour2`/`TimeOfDay2`. Every one of those rows declares variants, and in none does `Hour2` or `TimeOfDay2` appear before `FirstWeather` in the payload — the secondary window is always inside a variant, never on the main mask, and variant objects reach the hint by reference. Manifestation therefore absent from current content; the mechanism stands.

**Resolution:** Pre-existing → `Filed → FP-45262`, alongside F-2 — both live in the same node (variant resolution plus hint configuration inheritance) and are worth fixing in one pass.

**Discovered by:** skill recon (concrete failure scenario supplied by Codex).

### F-4: A temperature-bound miss always yields a "move forward a day" hint, ignoring the same-day forecast [Low]

**Description:** In `MoveTimeWeatherHint.Check`, a failed bound makes the weather-only `Match` return null, forcing `matchHour = -1` and emitting `MoveTimeForwardDay`. Air temperature varies across the in-game day and `MissionsContext.FullDayWeather` already holds the per-time-of-day forecast, but the hint never consults it, so a player is told to skip a day even when the condition would be satisfiable a few hours later.

**Investigation:**
- Traced `MoveTimeWeatherHint.Check`: both the three-arg and the weather-only `Match` evaluate the same single `context.Weather` snapshot, so a temperature miss short-circuits before `GetMatchTime` can propose an hour.
- Confirmed `TravelAdapter.InitWeatherInMissionsContext` populates `FullDayWeather` through `WeatherDescToWeather`, i.e. with air and water degrees present.
- Grepped `FullDayWeather` repo-wide: written on the mission-context init paths, read nowhere in server code (mission-config expressions could still reach it by name, so "unused" is not asserted).
- Architecturally the same approximation already applied to `Sky` / `Wind` / `WeatherName`; the new field is simply the most time-volatile one yet.

**Resolution:** Pre-existing → `Filed → FP-45262`, alongside F-2 and F-3 — same node, and the data needed to fix it is already in the mission context.

**Discovered by:** skill recon (independently reported by Codex).

### F-5: The test named for `EnsureConfiguration` does not call it, leaving the resource-copy blocks uncovered [Low]

**Description:** `EnsureConfiguration_copies_bounds_from_resource_when_property_unset` builds a `WeatherResource` with the bounds already set and asserts on `ConditionExtensions.MatchWeather` directly — it never constructs a `WeatherCondition`, never sets `WeatherResourceKey`, never invokes `EnsureConfiguration`. The new copy assignments across `WeatherCondition` and `MoveTimeWeatherHint` could all be deleted and the suite would stay green, while the test name asserts the opposite.

**Investigation:**
- Read the test body and both `EnsureConfiguration` methods; the test's own inline comment concedes it uses `ConditionExtensions.MatchWeather` "directly".
- Grepped `Shared/ObjectModel.Tests` for `WeatherResourceKey` and `FindResource<IWeatherResource>` — no test drives the resource-resolution path.
- Ran the suite: `dotnet test --filter FullyQualifiedName~WeatherConditionTests` → 13 passed, so the gap is in what is asserted, not in a failing test.
- Live content on Steam prod uses `WeatherResourceKey` in zero mission rows, so the untested path carries no current production traffic.

**Resolution:** `Filed → FP-45262`, alongside F-2 through F-4 — the release is imminent, the gap carries no production risk (no live mission uses `WeatherResourceKey`), and fixing that node will need tests over it anyway. Renaming the test to describe what it actually does was offered as an immediate one-line stopgap so the misleading name does not keep suppressing the coverage signal while the follow-up waits.

**Discovered by:** skill recon (independently reported by the code-reviewer agent and by Codex).

## Verdict

**Approve.** The feature does what the ticket asks: mission conditions can now constrain air and water temperature in degrees, the bounds are evaluated on every runtime path that feeds `MissionsContext.Weather`, the client half of the rename is present in the branch the release ships from, and the manual documents the new fields including their inclusive semantics. Nothing found is blocking.

The rename that looked most dangerous (F-1) turns out to be safe here: the coarse categories it replaces were never adopted in content, on any platform. Of the remaining findings, only the test gap (F-5) was introduced by this commit; F-2 through F-4 predate it and are unreachable in current content, but the degree bounds make the variant-chain and hint defects materially easier to hit once designers author overlapping temperature variants. They went into FP-45262 rather than blocking the release.

**Verification scope:** verified — the diff's mechanics by reading, the new unit tests by running them (13 passed), the rename's content exposure by querying every F2P prod MAIN database, the client mirror and the branch-copy inheritance by `svn cat`, and the documentation claim against Confluence. Not verified — end-to-end behaviour in a running game session; the temperature-bounded task exists on TEST/QA (mission 3958 / `Task_2`) but its QA result is not part of this review, and the plausibility of `Weather.AirTemperature` values across ponds was not audited.

## Notes

- JIRA `customfield_11224` (Executor) was empty during the review and was filled in with Yuriy Burda at close.
- Content on TEST/QA sets `MaxAirTemperature: -7`, which is inclusive and therefore admits exactly -7 °C, while the ticket text asks for "below -7 °C". The Confluence manual documents the inclusive semantics, so this is a content decision for the author, not a code defect.
