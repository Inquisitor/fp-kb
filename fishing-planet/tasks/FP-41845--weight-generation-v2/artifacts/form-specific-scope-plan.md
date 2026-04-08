# Form-Specific Edge Distribution Scope — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add form-specific flags (Young/Common/Trophy/Unique × Upper/Lower) to `EdgeDistributionScope`, enabling GD to target concrete fish forms instead of only dynamic roles (Heaviest/Lightest/Others).

**Architecture:** Extend the existing `[Flags]` enum with 8 new bits (6–13). Add form-specific matching in `GetEdgeFlags()` as OR with role-based logic. Update `ToFileNameSlug()` to recognize new flags. Add `YoungAndHeaviest` preset to WebAdmin dropdown. TDD: tests first, then implementation.

**Tech Stack:** C# 9 / .NET Framework 4.7.2, MSTest, ASP.NET MVC Razor

---

### Task 1: Write failing tests for form-specific scope

**Files:**
- Modify: `Shared/BiteSystem.Tests/FishWeight/FishWeightGeneratorTests.cs`

Tests use the existing `CreateTestFish()` helper (Nile Perch: Young 15–40, Common 40–80, Trophy 80–130, Unique 130–204) and the same CapAtThreshold + exaggerated zone pattern as existing scope tests.

- [ ] **Step 1: Add test — YoungLower applies to Young, not to Common**

```csharp
[TestMethod]
public void Generate_ScopeYoungLower_OnlyAffectsYoungForm()
{
    var fish = CreateTestFish();
    var config = new FishWeightGeneratorConfig(
        upperEdgeZoneFraction: 0f,
        lowerEdgeZoneFraction: 0.5f,
        edgeScope: EdgeDistributionScope.YoungLower,
        edgeStrategy: CapAtThreshold.Instance);

    // Young — lower edge should cap min weight at 50% of range
    var rnd1 = new Random(42);
    float minYoung = float.MaxValue;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Young, 1f, config);
        if (result.Weight < minYoung) minYoung = result.Weight;
    }
    float youngFloor = 15f + 0.5f * (40f - 15f); // 27.5
    Assert.IsTrue(minYoung >= youngFloor - 0.1f,
        $"Young lower capped at {youngFloor}, got min={minYoung}");

    // Common — should NOT be affected (it's neither Young nor lightest-role with this scope)
    var rnd2 = new Random(42);
    float minCommon = float.MaxValue;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Common, 1f, config);
        if (result.Weight < minCommon) minCommon = result.Weight;
    }
    Assert.IsTrue(minCommon < 42f,
        $"Common should reach near min (40), got min={minCommon}");
}
```

- [ ] **Step 2: Add test — HeaviestUpper | YoungLower combo**

```csharp
[TestMethod]
public void Generate_ScopeYoungAndHeaviest_UpperOnUniqueAndLowerOnYoung()
{
    var fish = CreateTestFish();
    var config = new FishWeightGeneratorConfig(
        upperEdgeZoneFraction: 0.5f,
        lowerEdgeZoneFraction: 0.5f,
        edgeScope: EdgeDistributionScope.YoungAndHeaviest,
        edgeStrategy: CapAtThreshold.Instance);

    // Unique (heaviest) — upper edge caps max at 50%
    var rnd1 = new Random(42);
    float maxUnique = 0;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, config);
        if (result.Weight > maxUnique) maxUnique = result.Weight;
    }
    float uniqueCeiling = 130f + 0.5f * (204f - 130f); // 167
    Assert.IsTrue(maxUnique <= uniqueCeiling + 0.1f,
        $"Unique upper capped at {uniqueCeiling}, got {maxUnique}");

    // Young — lower edge caps min at 50%
    var rnd2 = new Random(42);
    float minYoung = float.MaxValue;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Young, 1f, config);
        if (result.Weight < minYoung) minYoung = result.Weight;
    }
    float youngFloor = 15f + 0.5f * (40f - 15f); // 27.5
    Assert.IsTrue(minYoung >= youngFloor - 0.1f,
        $"Young lower capped at {youngFloor}, got {minYoung}");

    // Common — no edge distribution at all
    var rnd3 = new Random(42);
    float maxCommon = 0, minCommon = float.MaxValue;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd3, fish, FishForm.Common, 1f, config);
        if (result.Weight > maxCommon) maxCommon = result.Weight;
        if (result.Weight < minCommon) minCommon = result.Weight;
    }
    Assert.IsTrue(maxCommon > 75f, $"Common max near 80, got {maxCommon}");
    Assert.IsTrue(minCommon < 45f, $"Common min near 40, got {minCommon}");
}
```

- [ ] **Step 3: Add test — YoungLower on species without Young form**

```csharp
[TestMethod]
public void Generate_ScopeYoungLower_SpeciesWithoutYoung_NoEdgeApplied()
{
    // Species with only Common, Trophy, Unique — no Young form
    var fish = new FishDescription(FishName.NilePerch);
    fish.AddForm(FishForm.Common, 40f, 80f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
    fish.AddForm(FishForm.Trophy, 80f, 130f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
    fish.AddForm(FishForm.Unique, 130f, 204f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);

    var config = new FishWeightGeneratorConfig(
        upperEdgeZoneFraction: 0f,
        lowerEdgeZoneFraction: 0.5f,
        edgeScope: EdgeDistributionScope.YoungLower,
        edgeStrategy: CapAtThreshold.Instance);

    // Common is the lightest, but YoungLower targets Young specifically — not the lightest role
    var rnd = new Random(42);
    float minCommon = float.MaxValue;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd, fish, FishForm.Common, 1f, config);
        if (result.Weight < minCommon) minCommon = result.Weight;
    }
    Assert.IsTrue(minCommon < 42f,
        $"Common should reach near min (40) when YoungLower is set but species has no Young, got {minCommon}");
}
```

- [ ] **Step 4: Add test — UniqueUpper form-specific flag**

```csharp
[TestMethod]
public void Generate_ScopeUniqueUpper_OnlyAffectsUniqueForm()
{
    var fish = CreateTestFish();
    var config = new FishWeightGeneratorConfig(
        upperEdgeZoneFraction: 0.5f,
        lowerEdgeZoneFraction: 0f,
        edgeScope: EdgeDistributionScope.UniqueUpper,
        edgeStrategy: CapAtThreshold.Instance);

    // Unique — upper edge should cap
    var rnd1 = new Random(42);
    float maxUnique = 0;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd1, fish, FishForm.Unique, 1f, config);
        if (result.Weight > maxUnique) maxUnique = result.Weight;
    }
    float uniqueCeiling = 130f + 0.5f * (204f - 130f); // 167
    Assert.IsTrue(maxUnique <= uniqueCeiling + 0.1f,
        $"Unique capped at {uniqueCeiling}, got {maxUnique}");

    // Trophy (not Unique, not heaviest via form-specific) — should NOT be capped
    var rnd2 = new Random(42);
    float maxTrophy = 0;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd2, fish, FishForm.Trophy, 1f, config);
        if (result.Weight > maxTrophy) maxTrophy = result.Weight;
    }
    Assert.IsTrue(maxTrophy > 125f,
        $"Trophy should reach near max (130), got {maxTrophy}");
}
```

- [ ] **Step 5: Add test — UniqueUpper on species without Unique (form-specific ≠ role)**

```csharp
[TestMethod]
public void Generate_ScopeUniqueUpper_SpeciesWithoutUnique_NoEdgeApplied()
{
    // Species: Young, Common, Trophy only — Trophy is heaviest
    var fish = new FishDescription(FishName.NilePerch);
    fish.AddForm(FishForm.Young, 15f, 40f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
    fish.AddForm(FishForm.Common, 40f, 80f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);
    fish.AddForm(FishForm.Trophy, 80f, 130f, 1f, false, 0, DetractionType.None, 0, 0, 0, false);

    var config = new FishWeightGeneratorConfig(
        upperEdgeZoneFraction: 0.5f,
        lowerEdgeZoneFraction: 0f,
        edgeScope: EdgeDistributionScope.UniqueUpper,
        edgeStrategy: CapAtThreshold.Instance);

    // Trophy is heaviest, but UniqueUpper targets Unique specifically — no edge applied
    var rnd = new Random(42);
    float maxTrophy = 0;
    for (int i = 0; i < 10000; i++)
    {
        var result = FishWeightGenerator.Generate(rnd, fish, FishForm.Trophy, 1f, config);
        if (result.Weight > maxTrophy) maxTrophy = result.Weight;
    }
    Assert.IsTrue(maxTrophy > 125f,
        $"Trophy should reach near max (130) when UniqueUpper is set but species has no Unique, got {maxTrophy}");
}
```

- [ ] **Step 6: Run tests — verify they fail (enum members don't exist yet)**

Run: `dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj --filter "FullyQualifiedName~FishWeightGeneratorTests"`

Expected: Build failure — `EdgeDistributionScope` does not contain `YoungLower`, `YoungAndHeaviest`, `UniqueUpper`.

---

### Task 2: Implement form-specific flags in enum and GetEdgeFlags

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/FishWeight/EdgeDistribution/EdgeDistributionScope.cs`
- Modify: `Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGenerator.cs` (lines 161–198)

- [ ] **Step 1: Add form-specific flags and preset to EdgeDistributionScope**

Add after `OthersLower = 32`:

```csharp
// --- Form-specific flags (match by exact FishForm value, not by role) ---

/// <summary>Upper edge when form is Young, regardless of role.</summary>
YoungUpper    = 64,
/// <summary>Lower edge when form is Young, regardless of role.</summary>
YoungLower    = 128,
/// <summary>Upper edge when form is Common, regardless of role.</summary>
CommonUpper   = 256,
/// <summary>Lower edge when form is Common, regardless of role.</summary>
CommonLower   = 512,
/// <summary>Upper edge when form is Trophy, regardless of role.</summary>
TrophyUpper   = 1024,
/// <summary>Lower edge when form is Trophy, regardless of role.</summary>
TrophyLower   = 2048,
/// <summary>Upper edge when form is Unique, regardless of role.</summary>
UniqueUpper   = 4096,
/// <summary>Lower edge when form is Unique, regardless of role.</summary>
UniqueLower   = 8192,
```

Add to named presets section:

```csharp
/// <summary>Upper edge on heaviest form + lower edge on Young only (skipped if species has no Young).</summary>
YoungAndHeaviest = YoungLower | HeaviestUpper,
```

- [ ] **Step 2: Add form-specific matching to GetEdgeFlags()**

In `FishWeightGenerator.cs`, after the role-based `upper`/`lower` assignments (after line 195), add:

```csharp
// Form-specific flags — match by exact FishForm, OR with role-based result
upper |= (form == FishForm.Young   && scope.HasFlag(EdgeDistributionScope.YoungUpper))
      || (form == FishForm.Common  && scope.HasFlag(EdgeDistributionScope.CommonUpper))
      || (form == FishForm.Trophy  && scope.HasFlag(EdgeDistributionScope.TrophyUpper))
      || (form == FishForm.Unique  && scope.HasFlag(EdgeDistributionScope.UniqueUpper));

lower |= (form == FishForm.Young   && scope.HasFlag(EdgeDistributionScope.YoungLower))
      || (form == FishForm.Common  && scope.HasFlag(EdgeDistributionScope.CommonLower))
      || (form == FishForm.Trophy  && scope.HasFlag(EdgeDistributionScope.TrophyLower))
      || (form == FishForm.Unique  && scope.HasFlag(EdgeDistributionScope.UniqueLower));
```

- [ ] **Step 3: Build and run tests — verify all pass**

Ask user to build. Then run:
`dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj --filter "FullyQualifiedName~FishWeightGeneratorTests"`

Expected: All tests pass (existing + 5 new).

---

### Task 3: Update ToFileNameSlug to recognize form-specific flags

**Files:**
- Modify: `Shared/BiteSystem/ServerOnly/FishWeight/FishWeightGeneratorConfig.cs` (lines 67–72)

- [ ] **Step 1: Extend anyUpper/anyLower to include form-specific flags**

Replace lines 67–72 with:

```csharp
var anyUpper = EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.HeaviestUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.LightestUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.OthersUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.YoungUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.CommonUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.TrophyUpper)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.UniqueUpper);
var anyLower = EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.HeaviestLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.LightestLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.OthersLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.YoungLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.CommonLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.TrophyLower)
            || EdgeScope.HasFlag(EdgeDistribution.EdgeDistributionScope.UniqueLower);
```

- [ ] **Step 2: Build — ask user to verify**

---

### Task 4: Update WebAdmin dropdown and scope change handler

**Files:**
- Modify: `WebAdmin/WebAdmin/Views/Settings/FishWeightGenerator.cshtml`

- [ ] **Step 1: Add new option to scope dropdown**

After the `Extremes` option (line 98), add:

```html
<option value="HeaviestUpper, YoungLower" @(Model.Scope == "HeaviestUpper, YoungLower" ? "selected" : "")>Young + heaviest</option>
```

- [ ] **Step 2: Update tooltip text on label and select**

Add description of the new option to both `title` attributes (label line 94, select line 95):

```
&#x2022; Young + heaviest — upper edge on heaviest form + lower edge on Young only (skipped if no Young)
```

Insert after the Extremes line in each tooltip.

- [ ] **Step 3: Update onScopeChange() to detect lower zone in decomposed flag strings**

In the `onScopeChange()` function (line 748), replace:

```javascript
var hasLower = scope === "Extremes" || scope === "ExtremesAndAllUpper" || scope === "All";
```

with:

```javascript
var hasLower = scope === "Extremes" || scope === "ExtremesAndAllUpper" || scope === "All"
            || scope.indexOf("Lower") !== -1;
```

- [ ] **Step 4: Build — ask user to verify WebAdmin renders correctly**

---

### Task 5: Run full test suite, commit

- [ ] **Step 1: Run all BiteSystem tests**

`dotnet test --no-build Shared/BiteSystem.Tests/BiteSystem.Tests.csproj`

Expected: All tests pass.

- [ ] **Step 2: Commit**

Output commit message for user.
