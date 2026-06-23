# `--export-buoys` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `ReleaseTool --export-buoys` command that dumps, per player, the marker/nav/share buoys + recolor counters for the given ponds from a (reserve-backup) DB to a JSONL payload + CSV index + meta sidecar, for later opt-in restore.

**Architecture:** Pure, unit-tested extraction logic lives in the `ReleaseTool` assembly (`BuoyBackupRecord`, `BuoyBackupExtractor`, `BuoyBackupCsv`), tested by the existing `ReleaseTool.Tests` project — **nothing lands in `SharedLib`**, and the whole feature (code + tests) is a deletable unit once the restore is done. The `ReleaseTool` command is thin orchestration that streams over profiles via the existing `ProfileConverter.VisitProfiles` and writes the files under a lock (the visitor callback runs concurrently). Import is a separate later effort.

**Tech Stack:** C# (.NET Framework 4.7.2, C# 9), Newtonsoft.Json, MSTest (existing `ReleaseTool.Tests` project), the existing ReleaseTool/ProfileConverter harness.

**VCS — SVN, single atomic commit:** the code tree is SVN, where commits are immediately visible to the team. So this plan does **NOT** commit per task — Tasks 1-7 build and test entirely locally, and the whole feature lands in **one atomic `svn commit` at the very end (Task 9)** after build + unit tests + manual smoke all pass. Per project convention the actual `svn commit` is run by the user (the executor prepares the change + message).

---

## File Structure

- Create `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupRecord.cs` — the per-user DTO (5 buoy fragments).
- Create `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupExtractor.cs` — `Extract(userId, profile, pondIds)` + `PondName(pondId)`.
- Create `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupCsv.cs` — CSV header + per-(user×pond) rows.
- Create `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyExportRunner.cs` — orchestration + meta + price read.
- Create `Photon/tools/ReleaseTool/ReleaseTool/Cmd/export-buoys.example.cmd` — runnable example with commented parameters (lives in `Cmd/` with the other run scripts; needs a `.csproj` `<None Include>` entry, see below).
- Create `Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs` — unit tests for the three logic classes.
- Modify `Photon/tools/ReleaseTool/ReleaseTool/EntryPoint.cs` — add the `--export-buoys` case + a small `GetOption` arg helper.

Namespace for all new code classes: **`ReleaseTool.BuoyBackup`** (specific, not a generic `Buoys`).

Project facts: `ReleaseTool` and `ReleaseTool.Tests` are SDK-style (`<Project Sdk="Microsoft.NET.Sdk">`) — new `.cs` files auto-compile (no `.csproj` edit). **Exception — the `.cmd`:** the shared props disable `EnableDefaultNoneItems`, so non-`.cs` files are NOT auto-copied to output; the `.cmd` lives in `Cmd/` (with the existing run scripts, e.g. `R201905TruncateMissionsProgress.cmd`) and MUST be added to `ReleaseTool.csproj` as a `<None Include="Cmd\export-buoys.example.cmd"><CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory></None>`, else it won't appear in the build output. `ReleaseTool.Tests` already references `ReleaseTool`; `ReleaseTool` has no `InternalsVisibleTo`, so the tested classes (`BuoyBackupRecord`/`BuoyBackupExtractor`/`BuoyBackupCsv`) are **`public`**; `BuoyExportRunner` stays `internal`.

**Style (enforced):** repo `.editorconfig` requires **UTF-8 BOM**, CRLF, 4-space indent, and **braces on all `if`/`for` bodies** (`csharp_prefer_braces`). All code below already uses braces. New `.cs` files must be saved **with a UTF-8 BOM** (the editor/Write tool may omit it — prepend U+FEFF). Task 8 runs a formatter/linter pass to catch any deviation before the commit.

Known facts the code relies on (verified):
- `ObjectModel.Profile`: `Buoys` (`TrackingList<BuoySetting,int>`), `NavBuoys` (`List<NavBuoySetting>`), `BuoyShareRequests` (`TrackingList<BuoySetting,int>`), `BuoyRecolorCount`/`FreeBuoyRecolorCount` (`Dictionary<int,int>`).
- `BuoySetting`: `BuoyId, Name, PondId, Position (Point2), Fish (CaughtFish), SenderId, Sender, CreatedTime, ColorId, LastRecolorPricing`. `NavBuoySetting`: `Id, PondId, Name, Position, CreatedTime`.
- `Photon.Interfaces.SharedConsts` int consts `PondLoneStar=119`, `PondLesniVila=150`, `PondZeekanaal=160`.
- `ProfileConverter.VisitProfiles(string conn, Action<PlayerProfileDto> cb, string predicate=null, bool nolock=true)` — loads each `PlayerProfileDto` (has `UserId`, `ProfileJson`) and invokes `cb` **concurrently** (`PerformOfflineConvert` -> `action.BeginInvoke`); exceptions per item are caught and counted, never abort.
- `ProfileHelper.GetProfileOutOfDto(PlayerProfileDto dto, bool translateProfile=true)` -> `Profile`.
- `SerializationHelper.JsonSkipInventorySerializerSettings` is the live profile writer's settings (drops `BuoySetting.Update`/`Tracking` noise).
- `GlobalVariables` table is `(Name, Value)`; `BuoyRecolorPriceGc` default `2`, `BuoyRecolorPricePremiumRatio` default `0.5`.
- ReleaseTool reads its DB connection from `ConfigurationManager.ConnectionStrings["sql"]`, then `ProfileConverter.SqlConnectionString = conn; Init();` (mirror the `--finalize-conversion` case).

**One file set per pond (JSONL + CSV + meta), produced in a single pass — rationale:** ponds differ in value — some are pure historical backup, others may need restoring immediately — so each pond gets its own self-contained, independently-restorable set, which is also clearer to eyeball. A single run over `--ponds 119,150,160` makes ONE pass over the DB and writes three sets, one per pond; extracting another pond later yields a homogeneous set. File names: `buoys_<stream>_<PondName>_<date>.{jsonl,csv,meta.json}`. A user with buoys on several of the ponds appears once per relevant pond file, each line carrying only that pond's buoys — which matches pond-by-pond restore.

---

## Task 1: `BuoyBackupRecord` + `BuoyBackupExtractor.Extract`

**Files:**
- Create: `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupRecord.cs`
- Create: `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupExtractor.cs`
- Test: `Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs`

- [ ] **Step 1: Write the failing test**

`Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs`:
```csharp
using System;
using System.Collections.Generic;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using ReleaseTool.BuoyBackup;

namespace ReleaseTool.Tests.BuoyBackup
{
    [TestClass]
    public class BuoyBackupTests
    {
        private static readonly Guid User = Guid.Parse("11111111-1111-1111-1111-111111111111");

        [TestMethod]
        public void Extract_keeps_only_requested_ponds()
        {
            var profile = new ObjectModel.Profile
            {
                Buoys = new()
                {
                    new() { BuoyId = 1, PondId = 119, Name = "A" },
                    new() { BuoyId = 2, PondId = 100, Name = "Other" },
                    new() { BuoyId = 3, PondId = 150, Name = "B" },
                },
                NavBuoys = { new() { Id = 1, PondId = 119 }, new() { Id = 2, PondId = 100 } },
                BuoyRecolorCount = new() { { 119, 2 }, { 100, 5 } },
                FreeBuoyRecolorCount = new() { { 150, 1 } },
            };

            var rec = BuoyBackupExtractor.Extract(User, profile, new[] { 119, 150, 160 });

            Assert.IsNotNull(rec);
            Assert.AreEqual(User, rec.UserId);
            Assert.AreEqual(2, rec.Buoys.Count);
            Assert.AreEqual(1, rec.NavBuoys.Count);
            CollectionAssert.AreEquivalent(new[] { 119 }, new List<int>(rec.BuoyRecolorCount.Keys));
            CollectionAssert.AreEquivalent(new[] { 150 }, new List<int>(rec.FreeBuoyRecolorCount.Keys));
        }

        [TestMethod]
        public void Extract_returns_null_when_no_buoys_on_requested_ponds()
        {
            var profile = new ObjectModel.Profile
            {
                Buoys = new() { new() { BuoyId = 1, PondId = 100 } },
                BuoyRecolorCount = new() { { 100, 3 } },
            };

            var rec = BuoyBackupExtractor.Extract(User, profile, new[] { 119, 150, 160 });

            Assert.IsNull(rec);
        }
    }
}
```

- [ ] **Step 2: Run the test, verify it fails to compile**

Run: `dotnet test --filter "FullyQualifiedName~BuoyBackupTests" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: build error — `BuoyBackupExtractor`/`BuoyBackupRecord` do not exist.

- [ ] **Step 3: Create `BuoyBackupRecord`**

`Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupRecord.cs`:
```csharp
using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using ObjectModel;

namespace ReleaseTool.BuoyBackup
{
    public class BuoyBackupRecord
    {
        public Guid UserId { get; set; }
        public List<BuoySetting> Buoys { get; set; } = new();
        public List<NavBuoySetting> NavBuoys { get; set; } = new();
        public List<BuoySetting> BuoyShareRequests { get; set; } = new();
        public Dictionary<int, int> BuoyRecolorCount { get; set; } = new();
        public Dictionary<int, int> FreeBuoyRecolorCount { get; set; } = new();

        [JsonIgnore]
        public bool IsEmpty =>
            Buoys.Count == 0 && NavBuoys.Count == 0 && BuoyShareRequests.Count == 0
            && BuoyRecolorCount.Count == 0 && FreeBuoyRecolorCount.Count == 0;
    }
}
```

- [ ] **Step 4: Create `BuoyBackupExtractor` (Extract only; PondName added in Task 2)**

`Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupExtractor.cs`:
```csharp
using System;
using System.Collections.Generic;
using System.Linq;

namespace ReleaseTool.BuoyBackup
{
    public static class BuoyBackupExtractor
    {
        /// <summary>Pulls the buoy state for <paramref name="pondIds"/> out of a profile. Returns null if there is none.</summary>
        public static BuoyBackupRecord Extract(Guid userId, ObjectModel.Profile profile, int[] pondIds)
        {
            if (profile == null)
            {
                return null;
            }

            var ponds = new HashSet<int>(pondIds);
            var record = new BuoyBackupRecord { UserId = userId };

            if (profile.Buoys != null)
            {
                record.Buoys = profile.Buoys.Where(b => ponds.Contains(b.PondId)).ToList();
            }

            if (profile.NavBuoys != null)
            {
                record.NavBuoys = profile.NavBuoys.Where(b => ponds.Contains(b.PondId)).ToList();
            }

            if (profile.BuoyShareRequests != null)
            {
                record.BuoyShareRequests = profile.BuoyShareRequests.Where(b => ponds.Contains(b.PondId)).ToList();
            }

            if (profile.BuoyRecolorCount != null)
            {
                record.BuoyRecolorCount = profile.BuoyRecolorCount
                    .Where(kv => ponds.Contains(kv.Key) && kv.Value != 0)
                    .ToDictionary(kv => kv.Key, kv => kv.Value);
            }

            if (profile.FreeBuoyRecolorCount != null)
            {
                record.FreeBuoyRecolorCount = profile.FreeBuoyRecolorCount
                    .Where(kv => ponds.Contains(kv.Key) && kv.Value != 0)
                    .ToDictionary(kv => kv.Key, kv => kv.Value);
            }

            return record.IsEmpty ? null : record;
        }
    }
}
```

- [ ] **Step 5: Run the test, verify it passes**

Run: `dotnet test --filter "FullyQualifiedName~BuoyBackupTests" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: PASS (2 tests). **No commit** — see Task 9.

---

## Task 2: `BuoyBackupExtractor.PondName`

**Files:**
- Modify: `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupExtractor.cs`
- Test: `Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs`

- [ ] **Step 1: Add the failing test** (append to the test class)

```csharp
        [TestMethod]
        public void PondName_resolves_from_SharedConsts_and_falls_back()
        {
            Assert.AreEqual("LoneStar", BuoyBackupExtractor.PondName(119));
            Assert.AreEqual("LesniVila", BuoyBackupExtractor.PondName(150));
            Assert.AreEqual("Zeekanaal", BuoyBackupExtractor.PondName(160));
            Assert.AreEqual("Pond999999", BuoyBackupExtractor.PondName(999999));
        }
```

- [ ] **Step 2: Run, verify it fails to compile** (`PondName` not defined)

Run: `dotnet test --filter "FullyQualifiedName~PondName_resolves" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: build error.

- [ ] **Step 3: Implement `PondName`** (add to `BuoyBackupExtractor`; add `using System.Reflection;`)

```csharp
        /// <summary>Maps a pond id to its SharedConsts const name minus the "Pond" prefix; "Pond{id}" if unknown.</summary>
        public static string PondName(int pondId)
        {
            var field = typeof(Photon.Interfaces.SharedConsts)
                .GetFields(BindingFlags.Public | BindingFlags.Static)
                .FirstOrDefault(f => f.IsLiteral
                    && f.FieldType == typeof(int)
                    && f.Name.StartsWith("Pond", StringComparison.Ordinal)
                    && (int)f.GetRawConstantValue() == pondId);

            if (field == null)
            {
                return $"Pond{pondId}";
            }

            return field.Name.Substring("Pond".Length);
        }
```

- [ ] **Step 4: Run, verify it passes**

Run: `dotnet test --filter "FullyQualifiedName~PondName_resolves" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: PASS. **No commit.**

---

## Task 3: `BuoyBackupCsv`

**Files:**
- Create: `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupCsv.cs`
- Test: `Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs`

- [ ] **Step 1: Add the failing test**

```csharp
        [TestMethod]
        public void Csv_emits_one_row_per_pond_with_counts()
        {
            var rec = new BuoyBackupRecord
            {
                UserId = User,
                Buoys = { new() { PondId = 119 }, new() { PondId = 119 }, new() { PondId = 150 } },
                NavBuoys = { new() { PondId = 119 } },
            };

            var rows = new List<string>(BuoyBackupCsv.Rows(rec));

            Assert.AreEqual("UserId,PondId,PondName,MarkerBuoys,NavBuoys,ShareRequests", BuoyBackupCsv.Header);
            Assert.AreEqual(2, rows.Count);
            Assert.AreEqual($"{User},119,LoneStar,2,1,0", rows[0]);
            Assert.AreEqual($"{User},150,LesniVila,1,0,0", rows[1]);
        }
```

- [ ] **Step 2: Run, verify it fails to compile** (`BuoyBackupCsv` not defined)

Run: `dotnet test --filter "FullyQualifiedName~Csv_emits" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: build error.

- [ ] **Step 3: Create `BuoyBackupCsv`**

`Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyBackupCsv.cs`:
```csharp
using System.Collections.Generic;
using System.Linq;

namespace ReleaseTool.BuoyBackup
{
    public static class BuoyBackupCsv
    {
        public const string Header = "UserId,PondId,PondName,MarkerBuoys,NavBuoys,ShareRequests";

        /// <summary>One row per pond that has any buoy in the record, ascending by pond id.</summary>
        public static IEnumerable<string> Rows(BuoyBackupRecord r)
        {
            var ponds = r.Buoys.Select(b => b.PondId)
                .Concat(r.NavBuoys.Select(b => b.PondId))
                .Concat(r.BuoyShareRequests.Select(b => b.PondId))
                .Distinct()
                .OrderBy(p => p);

            foreach (var pond in ponds)
            {
                var marker = r.Buoys.Count(b => b.PondId == pond);
                var nav = r.NavBuoys.Count(b => b.PondId == pond);
                var share = r.BuoyShareRequests.Count(b => b.PondId == pond);
                yield return $"{r.UserId},{pond},{BuoyBackupExtractor.PondName(pond)},{marker},{nav},{share}";
            }
        }
    }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `dotnet test --filter "FullyQualifiedName~Csv_emits" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: PASS. **No commit.**

---

## Task 4: JSONL round-trip test (locks in the serializer choice)

**Files:**
- Test: `Photon/tools/ReleaseTool.Tests/BuoyBackup/BuoyBackupTests.cs`

No production code — pins the spec decision that a record serialized with `JsonSkipInventorySerializerSettings` round-trips into buoys and carries no `Update`/`Tracking` noise.

- [ ] **Step 1: Add the test** (add `using Newtonsoft.Json;` and `using ObjectModel.Serialization;`)

```csharp
        [TestMethod]
        public void Record_roundtrips_through_JsonSkipInventory_settings()
        {
            var rec = new BuoyBackupRecord
            {
                UserId = User,
                Buoys = { new() { BuoyId = 7, PondId = 119, Name = "A", ColorId = 3 } },
                BuoyRecolorCount = { { 119, 2 } },
            };

            var json = JsonConvert.SerializeObject(rec, Formatting.None, SerializationHelper.JsonSkipInventorySerializerSettings);
            var back = JsonConvert.DeserializeObject<BuoyBackupRecord>(json, SerializationHelper.JsonSkipInventorySerializerSettings);

            Assert.AreEqual(1, back.Buoys.Count);
            Assert.AreEqual(7, back.Buoys[0].BuoyId);
            Assert.AreEqual(119, back.Buoys[0].PondId);
            Assert.AreEqual(3, back.Buoys[0].ColorId);
            Assert.AreEqual(2, back.BuoyRecolorCount[119]);
            StringAssert.DoesNotMatch(json, new System.Text.RegularExpressions.Regex("\"Tracking\"|\"Update\""));
        }
```

- [ ] **Step 2: Run, verify it passes** (no new production code)

Run: `dotnet test --filter "FullyQualifiedName~Record_roundtrips" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: PASS. If `DoesNotMatch` fails, the dump carries tracking noise — investigate before proceeding. **No commit.**

---

## Task 5: `BuoyExportRunner` (orchestration)

**Files:**
- Create: `Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyExportRunner.cs`

No unit test (DB+filesystem orchestration; covered by Task 7 smoke). The pure logic it calls is already tested.

**One set per pond; meta = completion marker:** the runner makes a single `VisitProfiles` pass and fans each profile's per-pond fragments into per-pond writers. Each pond's `.meta.json` is written **last, only on success** — its absence signals that pond's run is incomplete. Re-run-safe: every file is opened `append: false` (overwrite), so re-running cleanly replaces partial dumps. (Simpler/safer than mid-run checkpointing for a one-shot reserve-DB export.)

- [ ] **Step 1: Create `BuoyExportRunner`**

`Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/BuoyExportRunner.cs`:
```csharp
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using ObjectModel.Serialization;
using ReleaseTool.Common;
using SharedLib.Profile;

namespace ReleaseTool.BuoyBackup
{
    internal static class BuoyExportRunner
    {
        public static void Run(string connectionString, int[] pondIds, string outDir, string stream)
        {
            Directory.CreateDirectory(outDir);
            var date = DateTime.UtcNow.ToString("yyyyMMdd");
            var ponds = pondIds.Distinct().ToArray();
            var (priceGc, premiumRatio) = ReadRecolorPrices(connectionString);

            // One output set per pond: ponds differ in value, so each is independently restorable.
            var sinks = new Dictionary<int, PondSink>();
            foreach (var pond in ponds)
            {
                var name = BuoyBackupExtractor.PondName(pond);
                sinks[pond] = new PondSink(outDir, $"buoys_{stream}_{name}_{date}");
            }

            var writeLock = new object();
            try
            {
                // VisitProfiles invokes the callback on MULTIPLE threads -> all writes are under writeLock.
                ProfileConverter.VisitProfiles(connectionString, dto =>
                {
                    var profile = ProfileHelper.GetProfileOutOfDto(dto, translateProfile: false);
                    foreach (var pond in ponds)
                    {
                        var record = BuoyBackupExtractor.Extract(dto.UserId, profile, new[] { pond });
                        if (record == null)
                        {
                            continue;
                        }

                        var line = JsonConvert.SerializeObject(record, Formatting.None, SerializationHelper.JsonSkipInventorySerializerSettings);
                        var rows = new List<string>(BuoyBackupCsv.Rows(record));

                        lock (writeLock)
                        {
                            sinks[pond].Write(line, rows, record.Buoys.Count);
                        }
                    }
                }, predicate: null, nolock: true);
            }
            finally
            {
                // Flush + close writers even if the visit threw (partial files remain, but no .meta.json).
                foreach (var sink in sinks.Values)
                {
                    sink.Dispose();
                }
            }

            // Reached only on success -> write each pond's .meta.json LAST (its presence = completed run).
            foreach (var pond in ponds)
            {
                var sink = sinks[pond];
                var meta = new
                {
                    stream,
                    pondId = pond,
                    pondName = BuoyBackupExtractor.PondName(pond),
                    extractedUtc = DateTime.UtcNow.ToString("o"),
                    source = connectionString.Split(';')[0], // Data Source only - no credentials
                    schema = 1,
                    usersWithBuoys = sink.Users,
                    markerBuoys = sink.MarkerBuoys,
                    buoyRecolorPriceGc = priceGc,
                    buoyRecolorPricePremiumRatio = premiumRatio,
                };
                File.WriteAllText(sink.MetaPath, JsonConvert.SerializeObject(meta, Formatting.Indented));
                Console.WriteLine($"Pond {pond} ({meta.pondName}): {sink.Users} users, {sink.MarkerBuoys} marker buoys -> {sink.JsonlPath}");
            }
        }

        // Reads the buoy-recolor prices from the (backup) GlobalVariables; falls back to code defaults.
        private static (int priceGc, double premiumRatio) ReadRecolorPrices(string connectionString)
        {
            var priceGc = 2;
            var premiumRatio = 0.5;

            using (var conn = new SqlConnection(connectionString))
            {
                conn.Open();
                using (var cmd = new SqlCommand(
                    "SELECT Name, Value FROM GlobalVariables WITH (NOLOCK) " +
                    "WHERE Name IN ('BuoyRecolorPriceGc', 'BuoyRecolorPricePremiumRatio')", conn))
                using (var reader = cmd.ExecuteReader())
                {
                    while (reader.Read())
                    {
                        var name = reader.GetString(0);
                        var val = reader.IsDBNull(1) ? null : reader.GetValue(1)?.ToString();
                        if (val == null)
                        {
                            continue;
                        }

                        if (name == "BuoyRecolorPriceGc" && int.TryParse(val, out var p))
                        {
                            priceGc = p;
                        }
                        else if (name == "BuoyRecolorPricePremiumRatio"
                                 && double.TryParse(val, NumberStyles.Any, CultureInfo.InvariantCulture, out var ratio))
                        {
                            premiumRatio = ratio;
                        }
                    }
                }
            }

            return (priceGc, premiumRatio);
        }

        private sealed class PondSink : IDisposable
        {
            public string JsonlPath { get; }
            public string CsvPath { get; }
            public string MetaPath { get; }
            public long Users;
            public long MarkerBuoys;

            private readonly StreamWriter _jsonl;
            private readonly StreamWriter _csv;

            public PondSink(string outDir, string baseName)
            {
                JsonlPath = Path.Combine(outDir, baseName + ".jsonl");
                CsvPath = Path.Combine(outDir, baseName + ".csv");
                MetaPath = Path.Combine(outDir, baseName + ".meta.json");
                _jsonl = new StreamWriter(JsonlPath, append: false);
                _csv = new StreamWriter(CsvPath, append: false);
                _csv.WriteLine(BuoyBackupCsv.Header);
            }

            public void Write(string jsonlLine, IEnumerable<string> csvRows, int markerCount)
            {
                _jsonl.WriteLine(jsonlLine);
                foreach (var row in csvRows)
                {
                    _csv.WriteLine(row);
                }

                Users++;
                MarkerBuoys += markerCount;
            }

            public void Dispose()
            {
                _jsonl.Flush();
                _jsonl.Dispose();
                _csv.Flush();
                _csv.Dispose();
            }
        }
    }
}
```

Executor note: `ProfileConverter` lives in `ReleaseTool/Common/ProfileConverter.cs` — the `using ReleaseTool.Common;` above assumes that namespace; if it differs, copy the using already present in `EntryPoint.cs`.

- [ ] **Step 2: Build to verify it compiles**

Run: `dotnet build Photon\tools\ReleaseTool\ReleaseTool\ReleaseTool.csproj -c Debug`
Expected: Build succeeded (0 errors). Fix any namespace/using mismatch. **No commit.**

---

## Task 6: `--export-buoys` command in `EntryPoint`

**Files:**
- Modify: `Photon/tools/ReleaseTool/ReleaseTool/EntryPoint.cs`

- [ ] **Step 1: Add a `GetOption` helper** (private static method on `EntryPoint`)

```csharp
        // Returns the value following an --opt flag, or null. e.g. args = [--export-buoys, --ponds, 119,150,160]
        private static string GetOption(string[] args, string name)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                {
                    return args[i + 1];
                }
            }

            return null;
        }
```

- [ ] **Step 2: Add the `--export-buoys` case** to the `switch (cmd)` block (alongside `--finalize-conversion`)

```csharp
                        case "--export-buoys":
                        {
                            // ReleaseTool.exe --export-buoys --ponds 119,150,160 [--stream steam] [--out C:\dir]
                            var pondsArg = GetOption(args, "--ponds");
                            if (string.IsNullOrWhiteSpace(pondsArg))
                            {
                                Console.WriteLine("Usage: ReleaseTool.exe --export-buoys --ponds 119,150,160 [--stream <name>] [--out <dir>]");
                                break;
                            }

                            int[] pondIds;
                            try
                            {
                                pondIds = Array.ConvertAll(pondsArg.Split(','), s => int.Parse(s.Trim()));
                            }
                            catch (FormatException)
                            {
                                Console.WriteLine("--ponds must be a comma-separated list of integer pond ids, e.g. 119,150,160");
                                break;
                            }

                            var stream = GetOption(args, "--stream") ?? "unknown";
                            var outDir = GetOption(args, "--out") ?? AppDomain.CurrentDomain.BaseDirectory;

                            var connectionString = ConfigurationManager.ConnectionStrings["sql"].ConnectionString;
                            ProfileConverter.SqlConnectionString = connectionString;

                            Console.WriteLine("Initializing ...");
                            Init();

                            ReleaseTool.BuoyBackup.BuoyExportRunner.Run(connectionString, pondIds, outDir, stream);

                            Console.WriteLine("Done in " + DateTime.Now.Subtract(start));
                            break;
                        }
```

Note: `--ponds` is parsed to `int[]` here in code and only ever passed to `BuoyExportRunner` for in-code filtering — it is never put into a SQL string (the visitor `predicate` is `null` for export).

- [ ] **Step 3: Build**

Run: `dotnet build Photon\tools\ReleaseTool\ReleaseTool\ReleaseTool.csproj -c Debug`
Expected: Build succeeded. **No commit.**

---

## Task 7: Example `.cmd`

**Files:**
- Create: `Photon/tools/ReleaseTool/ReleaseTool/Cmd/export-buoys.example.cmd`
- Modify: `Photon/tools/ReleaseTool/ReleaseTool/ReleaseTool.csproj` (add the copy-to-output `<None Include>` entry)

The `.cmd` goes in `Cmd/` next to the existing run scripts (`R201905TruncateMissionsProgress.cmd`), matching their convention: **UTF-8 BOM**, `echo off`, and it calls `..\ReleaseTool.exe` (in the build output the exe is one level up from `Cmd\`).

- [ ] **Step 1: Create the example command file** (UTF-8 BOM, CRLF)

`Photon/tools/ReleaseTool/ReleaseTool/Cmd/export-buoys.example.cmd`:
```bat
echo off
REM ============================================================================
REM  Export deprecated-pond buoys from the configured "sql" DB
REM  (set in ..\ReleaseTool.exe.config). Run from this Cmd folder.
REM
REM  Params:
REM    --ponds   comma-separated pond ids (REQUIRED). 2026.4 deprecated ponds:
REM              119 (LoneStar), 150 (LesniVila), 160 (Zeekanaal).
REM    --stream  label for output filenames, e.g. steam / ps / xb / mob / nx
REM              (naming only; default "unknown").
REM    --out     output folder (default the exe folder).
REM
REM  Output: ONE set PER POND in a single run ->
REM    buoys_<stream>_<PondName>_<yyyymmdd>.jsonl / .csv / .meta.json
REM ============================================================================
..\ReleaseTool.exe --export-buoys --ponds 119,150,160 --stream steam --out ..\buoy-export-out
pause
```

- [ ] **Step 2: Register the `.cmd` in the csproj** (non-`.cs` files are NOT auto-copied — `EnableDefaultNoneItems` is off)

In `ReleaseTool.csproj`, in the `ItemGroup` holding the other `Cmd\*.cmd` entries, add:
```xml
<None Include="Cmd\export-buoys.example.cmd">
  <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
</None>
```

- [ ] **Step 3: Build and verify it lands in the output `Cmd\` folder**

Run: `dotnet build Photon\tools\ReleaseTool\ReleaseTool\ReleaseTool.csproj -c Debug`
Expected: 0 errors, and `export-buoys.example.cmd` present in the build output `Cmd\` folder (next to the sibling scripts). **No commit.**

---

## Task 8: Lint / format pass (`.editorconfig` compliance)

**Files:** the new `.cs` files under `ReleaseTool/BuoyBackup/` and `ReleaseTool.Tests/BuoyBackup/`.

- [ ] **Step 1: Verify formatting against `.editorconfig`**

Run: `dotnet format Photon\tools\ReleaseTool\ReleaseTool\ReleaseTool.csproj --verify-no-changes --include Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup/`
Then: `dotnet format Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj --verify-no-changes --include Photon/tools/ReleaseTool.Tests/BuoyBackup/`
Expected: exit 0 (no changes needed). If it reports diffs (braces, spacing, `using` order, etc.), re-run without `--verify-no-changes` to apply, then re-check.

- [ ] **Step 2: Confirm UTF-8 BOM on every new `.cs`** (the `.editorconfig` mandates BOM; the editor may have written them BOM-less). Re-save with BOM if missing. Spot-check by opening the file or checking the first bytes are `EF BB BF`.

- [ ] **Step 3: Re-run the full test suite** to confirm formatting didn't break anything.

Run: `dotnet test --filter "FullyQualifiedName~BuoyBackupTests" Photon\tools\ReleaseTool.Tests\ReleaseTool.Tests.csproj`
Expected: PASS (all buoy tests). **No commit.**

---

## Task 9: Manual smoke + single atomic commit

**Files:** none new (verification + the one commit).

- [ ] **Step 1: Point `App.config`'s `sql` connection at a small dev/QA Main DB** (NOT prod). Confirm with the user which connection; do not commit credential changes.

- [ ] **Step 2: Build and run the exporter** (from the build output dir)

`ReleaseTool.exe --export-buoys --ponds 119,150,160 --stream devtest --out .\buoy-export-out`
Expected: progress bar, then "Export done: N users, M marker buoys." and three files in `.\buoy-export-out\`.

- [ ] **Step 3: Verify the artifacts**

- Three sets: `buoys_devtest_LoneStar_<date>.*`, `…_LesniVila_…`, `…_Zeekanaal_…`.
- each `.jsonl`: one line per user; valid JSON with that pond's `Buoys`/`NavBuoys`/… only; no `"Tracking"`/`"Update"` keys.
- each `.csv`: header + rows for that single pond; distinct-UserId count matches that pond's printed users.
- each `.meta.json`: `pondId`, `pondName`, `usersWithBuoys`, `markerBuoys`, `buoyRecolorPriceGc`, `buoyRecolorPricePremiumRatio`; `source` has no credentials.

- [ ] **Step 4: Sanity cross-check the count** with one SQL query against the same DB (approximate is fine — count profiles whose `ProfileJson` contains a buoy on `"PondId":119` etc.).

- [ ] **Step 5: ONE atomic commit of the whole feature** (run by the user)

```
svn add Photon/tools/ReleaseTool/ReleaseTool/BuoyBackup Photon/tools/ReleaseTool.Tests/BuoyBackup
svn commit -m "FP-44389: [Buoys] Add ReleaseTool --export-buoys (deprecated-pond buoy backup)
+ Add ReleaseTool/BuoyBackup: BuoyBackupRecord, BuoyBackupExtractor (Extract + PondName), BuoyBackupCsv, BuoyExportRunner; export per-user buoy fragments for --ponds to JSONL + CSV index + meta sidecar (recolor prices captured from GlobalVariables)
+ Add ReleaseTool --export-buoys command (--ponds parsed in code, never into SQL) + GetOption helper + export-buoys.example.cmd
+ Add ReleaseTool.Tests/BuoyBackup unit tests (Extract filtering, PondName, CSV rows, JSON round-trip)
https://fishingplanet.atlassian.net/browse/FP-44389"
```

- [ ] **Step 6: Record the smoke-test result** in the task journal (`fishing-planet/tasks/FP-44389--ftue-release/journal.md`) — counts seen, DB used, date.

---

## Self-Review

- **Spec coverage:** JSONL payload (Tasks 1/4/5), CSV index long-format with PondName (Tasks 2/3/5), `.meta.json` incl. recolor prices + completion-marker semantics (Task 5), `--ponds` parsed in code not SQL (Task 6), `VisitProfiles` visit-all + thread-safe writers (Task 5), skip-empty-in-code (Task 1), `JsonSkipInventorySerializerSettings` (Tasks 4/5), output to tool folder by default + example cmd (Tasks 6/7), one file set PER POND in a single pass (File Structure rationale + Task 5). Import/merge/GC is explicitly out of scope.
- **Placeholder scan:** none — all steps carry full code/commands. Defaults (`--stream` "unknown", `--out` exe dir) are real defaults.
- **Type consistency:** `BuoyBackupRecord` shape identical across Tasks 1/3/4/5; `BuoyBackupExtractor.Extract(Guid, Profile, int[])` / `PondName(int)`; `BuoyBackupCsv.Header` / `Rows(BuoyBackupRecord)`; `BuoyExportRunner.Run(string, int[], string, string)` matches the EntryPoint call. Namespace `ReleaseTool.BuoyBackup` used consistently.
- **Style:** all `if`/`for` bodies braced; BOM + format pass in Task 8; single SVN commit in Task 9.
