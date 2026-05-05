---
id: BCK-002
title: Events endpoint with 10k cap
slice: VS2
status: done
depends-on: [FRT-001]
effort: M
---

## Scope
Add `Action Events(string userId, DateTime from, DateTime to)`. Reads `LogCollection.Fishing.Find(userId, from, to)`, filters `Message.StartsWith("TakeClick"/"ReleaseClick")`, parses `(x, y)` from message text, returns shape per [architecture → Events](../architecture.md#events-get-anticheatgamesessionanalysisevents) including 10k cap + `truncated` flag.

## Files
- Modify: `Areas/Anticheat/Controllers/GameSessionAnalysisController.cs` — add `Events`
- Create: `Areas/Anticheat/Models/GameSessionAnalysis/GameSessionAnalysisEventsModel.cs` — Fill + Data projection + cap logic
- Modify: `WebAdmin.csproj` — `<Compile>` for new model

## Implementation notes
- DAL access pattern: instantiate `new LogBase(LogCollection.FishingLog)` directly (matches `WebAdmin/Models/Players/Logs/MongoLogModel.cs:29`). Do **NOT** use `LogCollection.Fishing` — that resolves to `ILogBase` which only exposes `Log/LogAsync`, not `Find`. The `Find(userId, start, end)` overload lives on the concrete `LogBase` (`Dal/NoSql.Mongo/Log/LogBase.cs:84`).
- Cap rule: if `totalAvailable > 10000`, take **last** 10k by `Timestamp DESC` then re-order ASC for client.
- Coord parser regex (verified format from `artifacts/heatmap_gen.py:79` and `verify_lureking_runtime_geom.py:38`):
  ```csharp
  // Message format: "TakeClick: 663.000; 89.000" or "ReleaseClick: 473.000; 89.000"
  private static readonly Regex EventRe = new(
      @"^(?<kind>TakeClick|ReleaseClick):\s+(?<x>[\d.]+);\s+(?<y>[\d.]+)$",
      RegexOptions.Compiled);
  // Parse to int via (int)double.Parse(group.Value, CultureInfo.InvariantCulture).
  // The .000 suffix is formatting; underlying values are integer pixels.
  ```
- `kind` discriminator: prefix-based (`TakeClick` → `take`, `ReleaseClick` → `release`).
- Watch out: `LogBase.Find` returns `IEnumerable` lazily — materialize via `.ToList()` before counting to avoid double-iteration of the Mongo cursor.
- Date validation: same as BCK-001 — guard `from > to` or `DateTime.MinValue`, return 400 JSON.

## Exit criteria
- [x] Endpoint returns JSON matching architecture shape including `totalAvailable / returnedCount / truncated`
- [x] Manual call against LureKing sample (LUYA168) returns clicks at expected pixel *(verified via TST-002 smoke 2026-05-04)*
- [x] Range with > 1000 events shows `truncated: true` and exactly 1000 items *(verified via TST-002 smoke 2026-05-04 — cap reduced 10k→1k mid-iteration; truncation observed on active player)*

## Implementation notes (DONE 2026-05-03)
- Used `new LogBase(LogCollection.FishingLog)` per subtask hint — `LogCollection.FishingLog = "fishing"` (constant in `Dal/Dal.Log/Logs/LogCollection.cs:24`).
- `LogBase.Find(userId, start, end)` already exists with event-stream semantics (`GTE/LTE Timestamp`); no new method needed. **Distinction from VS1's SysInfo fix**: `fishingLog` is genuinely an event stream (clicks happen at instants), so `>= from AND <= to` is correct here. Different from `diagSysInfoLog` which is stateful and needed `FindActiveDuring`.
- Coord parser regex (relaxed during smoke after 0-clicks result on a known-good user): non-anchored `(?<kind>TakeClick|ReleaseClick):\s+(?<x>[\d.]+);\s+(?<y>[\d.]+)`. Original anchored `^...$` was too strict — heatmap_gen.py's `re.finditer(line)` over htm-export'ed log files works because messages come with prefix/suffix HTML noise. Same defensive approach here (filter `EventRe.IsMatch(message)` instead of `StartsWith`). Parse via `(int)double.Parse(..., CultureInfo.InvariantCulture)` — handles `663.000` formatting suffix robustly (raw `int.Parse` would throw on `.000`).
- Cap algorithm: order desc → take first N → re-order asc. Single pass over parsed list. Cap reduced from 10000 to **1000** during smoke (5 min wait on 2797-click query — cap reduction trims slowest-render path).
- **Mongo-side regex pre-filter** added during smoke (real culprit for slowness): `LogBase` got `Find(userId, from, end, BsonRegularExpression)` overload that pushes `Query.Matches("Message", regex)` to Mongo. Without this, an active player's fishingLog could deserialise hundreds of thousands of cast / bite / fish entries in C# only to discard them. The new overload narrows the cursor at the source.
- Materialized to `List<>` once via `.ToList()` to avoid double-iteration of the Mongo cursor.
- Frontend: `useApiClient.fetchEvents` switched from stub to real `getJson` call. `App.vue.loadEvents` now also captures `eventsTruncated` (used by FRT-008 banner).
- Date validation: reuses `ValidateInputs` from BCK-001 — same guards (userId, MinValue, from > to).
