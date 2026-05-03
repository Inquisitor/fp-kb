---
id: BCK-002
title: Events endpoint with 10k cap
slice: VS2
status: todo
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
- [ ] Endpoint returns JSON matching architecture shape including `totalAvailable / returnedCount / truncated`
- [ ] Manual call against LureKing sample (LUYA168) returns clicks at expected pixel
- [ ] Range with > 10k events shows `truncated: true` and exactly 10000 items
