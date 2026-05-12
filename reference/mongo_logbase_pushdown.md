---
name: Mongo LogBase.Find content-filter pushdown via BsonRegularExpression
description: For heavy fishingLog (or similar) queries with a message-content filter, push the filter to Mongo via the BsonRegularExpression overload — client-side filtering on the cursor enumerates the full user/range slice
type: reference
---
For heavy Mongo log collections (`fishingLog` chief among them), prefer pushing a message-content filter into the Mongo query rather than filtering the C# cursor enumeration.

**API:** `LogBase.Find(string userId, DateTime from, DateTime to, BsonRegularExpression messagePattern)` — returns only matching docs, server-side.

**Why:** `LogBase.Find(userId, from, to)` without content filter materialises the **entire** user/range slice from Mongo. For an active player over the 14-day retention window that can be hundreds of thousands of BSON-deserialised entries; filtering by `Message.StartsWith("TakeClick")` in C# after the fact iterates them all. FP-43579 measured a ~30-minute query on a 2797-take-click user before the fix; subsecond after.

**When to use:** any query where the moderator's intent is a subset of message kinds (Take/Release only; Cast only; Bite only; …) on a high-volume collection.

**Caller pattern:**

```csharp
var re = new MongoDB.Bson.BsonRegularExpression("TakeClick|ReleaseClick");
var hits = new LogBase(LogCollection.FishingLog).Find(userId, from, to, re);
```

- Single-kind prefix → `BsonRegularExpression("^TakeClick")`
- OR-of-kinds → `BsonRegularExpression("TakeClick|ReleaseClick")`
- Mongo regex anchoring rules apply — unanchored regex is a collection scan unless an index covers the prefix.

**Index considerations:** there is currently no `Message` index on `fishingLog`. The pushdown still wins because the dominant cost is BSON deserialisation across the user/range slice — pushing the filter cuts the *returned* document count by 100×–1000× even without an index. If query latency becomes a problem at scale, the next lever is a partial index on `Message` for the hot prefixes.

Added in FP-43579 r16063 (VS4 post-smoke perf fix). The new overload is reusable for any other `fishingLog`/`*Log` query with a message-content filter.
