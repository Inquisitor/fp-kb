# Exchange Rate Snapshot — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add manual exchange rate management to RegionalPriceRates so LiveOps can review and selectively snapshot live rates.

**Architecture:** New columns in RegionalPriceRates (`ExchangeRate`, `ExchangeRateTimestamp`), SQL View for the update page, DAL method `SnapshotExchangeRatesForRegionalPricingAsync`, new WebAdmin page with Select All + bulk update pattern.

**Tech Stack:** C# (.NET Framework 4.7.2), ASP.NET MVC, Kendo UI, SQL Server, Photon Server SDK

**Spec:** `artifacts/exchange-rate-snapshot-spec.md`

**Build note:** CLI build does NOT work. After code changes, ask user to build. `dotnet test --no-build` works on already-built projects.

---

## Task 1: SQL — Patch + Views

**Files:**
- Create: `SQL/Patches/GRM.M.2026.04.13-075.sql`
- Create: `SQL/Patches/Main/Views/VW_ExchangeRateUpdates.sql`
- Modify: `SQL/Patches/Main/Views/VW_ProductLocalPrices.sql`

- [x] **Step 1: Create SQL patch — add columns + migration**

```sql
USE [Main]
GO

IF EXISTS (SELECT 1
           FROM [dbo].[AppliedPatches]
           WHERE [PatchName] = 'GRM.M.2026.04.13-075')
    BEGIN
        PRINT 'Script was already applied, canceling execution!'
        SET NOEXEC ON
    END
GO
-- ----------------------------------------------------------------

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_NAME = 'RegionalPriceRates' AND COLUMN_NAME = 'ExchangeRate')
BEGIN
    ALTER TABLE RegionalPriceRates
        ADD ExchangeRate decimal(38, 20) NOT NULL DEFAULT 1,
            ExchangeRateTimestamp datetime NULL;
END
GO

UPDATE r
SET r.ExchangeRate = ISNULL(c.ExchangeRate, 1),
    r.ExchangeRateTimestamp = c.RefreshTimestamp
FROM RegionalPriceRates r
LEFT JOIN CurrencyExchangeRates c ON r.Currency = c.TargetCurrency;
GO

-- ----------------------------------------------------------------
INSERT INTO [dbo].[AppliedPatches] VALUES ('GRM.M.2026.04.13-075');
GO

SET NOEXEC OFF
GO
```

- [x] **Step 2: Create VW_ExchangeRateUpdates.sql**

```sql
USE [Main]
GO

DROP VIEW IF EXISTS VW_ExchangeRateUpdates
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW VW_ExchangeRateUpdates AS
SELECT r.RateId,
       r.PlatformId,
       r.Currency,
       r.Country,
       r.ExchangeRate                                                AS CurrentRate,
       r.ExchangeRateTimestamp                                       AS CurrentRateTimestamp,
       ISNULL(c.ExchangeRate, r.ExchangeRate)                        AS NewRate,
       c.RefreshTimestamp                                            AS NewRateTimestamp,
       DATEDIFF(MINUTE, r.ExchangeRateTimestamp, c.RefreshTimestamp) AS AgeDiffMinutes,
       CASE
           WHEN r.ExchangeRate = 0 THEN 0
           ELSE (ISNULL(c.ExchangeRate, r.ExchangeRate) - r.ExchangeRate)
                    / r.ExchangeRate * 100
           END                                                       AS DeviationPercent
FROM RegionalPriceRates r
         LEFT JOIN CurrencyExchangeRates c ON r.Currency = c.TargetCurrency;
GO
```

- [x] **Step 3: Update VW_ProductLocalPrices.sql — add rt.ExchangeRate**

```sql
USE [Main]
GO

DROP VIEW IF EXISTS VW_ProductLocalPrices
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW VW_ProductLocalPrices AS
SELECT plp.*, p.Price AS BasePrice, p.DiscountPrice AS BaseDiscountPrice, pl.Name AS Platform, r.Name AS Region, rt.Rate, rt.MinimalUnit, rt.RoundingAmount, rt.RoundingType, rt.Beautify, rt.ExchangeRate
FROM ProductLocalPrices plp
    INNER JOIN Products p ON plp.ProductId = p.ProductId
    LEFT JOIN Platforms pl ON p.PlatformId = pl.PlatformId
    LEFT JOIN ProductMappingRegions r ON p.RegionId = r.RegionId
    LEFT JOIN RegionalPriceRates rt ON p.RegionId = r.RegionId
        AND plp.Currency = rt.Currency
        AND (plp.Country = rt.Country OR plp.Country = '--' AND rt.Country = '')
GO
```

---

## Task 2: DAL — DTO + Provider

**Files:**
- Modify: `Dal/Sql.Interface/Monetization/RegionalPriceRateDto.cs`
- Modify: `Dal/Sql.Interface/Monetization/IMonetizationProvider.cs`
- Modify: `Dal/Sql.MsSql/Monetization/SqlMonetizationProvider.cs`

- [x] **Step 1: Add fields to RegionalPriceRateDto**

In `RegionalPriceRateDto.cs`, add after `Beautify`:

```csharp
public decimal ExchangeRate { get; set; }
public DateTime? ExchangeRateTimestamp { get; set; }
```

Full file:

```csharp
using Sql.Interface.Common;

namespace Sql.Interface.Monetization
{
    public class RegionalPriceRateDto : DtoBase
    {
        public int PlatformId { get; set; }
        public string Currency {get;set;}
        public string Country { get; set; }
        public decimal Rate { get; set; }
        public decimal MinimalUnit { get; set; }
        public decimal RoundingAmount { get; set; }
        public int RoundingType { get; set; }
        public bool Beautify { get; set; }
        public decimal ExchangeRate { get; set; }
        public DateTime? ExchangeRateTimestamp { get; set; }
    }
}
```

- [x] **Step 2: Add method to IMonetizationProvider**

Add after `GetProductLocalPricesAsync` (~line 181):

```csharp
Task<int> SnapshotExchangeRatesForRegionalPricingAsync(
    IDictionary<int, (decimal Rate, DateTime Timestamp)> ratesByRateId);
```

- [x] **Step 3: Implement in SqlMonetizationProvider**

Add before the final closing braces:

```csharp
#region Exchange Rate Snapshot

public async Task<int> SnapshotExchangeRatesForRegionalPricingAsync(
    IDictionary<int, (decimal Rate, DateTime Timestamp)> ratesByRateId)
{
    if (ratesByRateId.Count == 0)
        return 0;

    int totalUpdated = 0;
    using var tran = new TransactionScope(TransactionScopeAsyncFlowOption.Enabled);

    foreach (var (rateId, (rate, timestamp)) in ratesByRateId)
    {
        var updated = await ExecuteNonQueryAsync(@"
            UPDATE RegionalPriceRates
            SET ExchangeRate = @rate, ExchangeRateTimestamp = @timestamp
            WHERE RateId = @rateId",
            new { rateId, rate, timestamp });
        totalUpdated += updated;
    }

    tran.Complete();
    return totalUpdated;
}

#endregion Exchange Rate Snapshot
```

---

## Task 3: Entities — RegionalPriceRates + ProductLocalPricesExt + ExchangeRateUpdate

**Files:**
- Modify: `WebAdmin/WebAdmin/Models/Entities.cs`

- [x] **Step 1: Update RegionalPriceRates entity (~line 1864)**

Change `ExchangeRate` — remove `[CalculatedField]`:

Old:
```csharp
[Readonly]
[DisplayFormat(DataFormatString = "{0:N6}")]
[Style("text-align:right;")]
[CalculatedField]
public decimal ExchangeRate { get; set; }
```

New:
```csharp
[Readonly]
[DisplayFormat(DataFormatString = "{0:N6}")]
[Style("text-align:right;")]
public decimal ExchangeRate { get; set; }
[Readonly]
[Hidden]
public DateTime? ExchangeRateTimestamp { get; set; }
```

- [x] **Step 2: Add ExchangeRate to ProductLocalPricesExt (~line 1260)**

After the `Beautify` property, add:

```csharp
[Hidden]
[Readonly]
public decimal? ExchangeRate { get; set; }
```

- [x] **Step 3: Add ExchangeRateUpdate entity (~after CurrencyExchangeRates class, line 1935)**

```csharp
[ViewName("VW_ExchangeRateUpdates")]
public class ExchangeRateUpdate
{
    [Order(1)]
    public bool Selected { get; set; }

    [PrimaryKey]
    [Readonly]
    [Hidden]
    public int RateId { get; set; }

    [Readonly]
    [ForeignKey("Platforms", "PlatformId", "Name")]
    [Order(2)]
    public int PlatformId { get; set; }

    [Readonly]
    [Order(3)]
    public string Currency { get; set; }

    [Readonly]
    [Order(4)]
    public string Country { get; set; }

    [Readonly]
    [Order(10)]
    [DisplayFormat(DataFormatString = "{0:N6}")]
    [Style("text-align:right;")]
    [System.ComponentModel.DisplayName("Current Rate")]
    public decimal CurrentRate { get; set; }

    [Readonly]
    [Order(11)]
    [System.ComponentModel.DisplayName("Saved")]
    public DateTime? CurrentRateTimestamp { get; set; }

    [Readonly]
    [Order(20)]
    [DisplayFormat(DataFormatString = "{0:N6}")]
    [Style("text-align:right; font-weight:bold;")]
    [System.ComponentModel.DisplayName("New Rate")]
    public decimal NewRate { get; set; }

    [Readonly]
    [Order(21)]
    [System.ComponentModel.DisplayName("Fetched")]
    public DateTime? NewRateTimestamp { get; set; }

    [Readonly]
    [CalculatedField]
    [Order(30)]
    [DisplayFormat(DataFormatString = "{0:N2}")]
    [System.ComponentModel.DisplayName("Deviation %")]
    public decimal DeviationPercent { get; set; }

    [Readonly]
    [CalculatedField]
    [Order(31)]
    [System.ComponentModel.DisplayName("Age")]
    public int? AgeDiffMinutes { get; set; }
}
```

---

## Task 4: Models — RegionalPriceRatesModel + ProductLocalPricesModel + ExchangeRateUpdateModel

**Files:**
- Modify: `WebAdmin/WebAdmin/Models/Monetization/RegionalPriceRatesModel.cs`
- Modify: `WebAdmin/WebAdmin/Models/Monetization/ProductLocalPricesModel.cs`
- Create: `WebAdmin/WebAdmin/Models/Monetization/ExchangeRateUpdateModel.cs`

- [x] **Step 1: Update RegionalPriceRatesModel.GetData()**

In `GetData()` (~line 39), replace:

Old:
```csharp
var exchangeRate = MonetizationCache.GetCurrencyExchangeRate(priceSettings.Currency);

priceSettings.ExchangeRate = exchangeRate;
```

New:
```csharp
var exchangeRate = priceSettings.ExchangeRate;
```

- [x] **Step 2: Update ProductLocalPricesModel.GetData()**

In `GetData()` (~line 41), replace:

Old:
```csharp
var exchangeRate = MonetizationCache.GetCurrencyExchangeRate(price.Currency);
```

New:
```csharp
var exchangeRate = price.ExchangeRate ?? 1m;
```

- [x] **Step 3: Create ExchangeRateUpdateModel.cs**

```csharp
using Kendo.Mvc.UI.Fluent;

namespace WebAdmin.Models.Monetization
{
    public class ExchangeRateUpdateModel : TableEditModel<ExchangeRateUpdate>
    {
        public override bool CanAdd => false;
        public override bool CanSave => false;
        public override bool CanDelete => false;

        public override GridBuilder<ExchangeRateUpdate> ConfigureGrid(GridBuilder<ExchangeRateUpdate> grid)
        {
            grid = base.ConfigureGrid(grid);

            grid.Columns(cols =>
            {
                foreach (var column in cols.Container.Columns)
                {
                    if (column.Member == "Selected")
                    {
                        column.Width = "40px";
                        column.HtmlAttributes["style"] = "text-align:center";
                    }
                    else if (column.Member == "DeviationPercent")
                    {
                        column.ClientTemplate =
                            "#= (function() {" +
                            "  var v = data.DeviationPercent;" +
                            "  if (v === 0) return '<span style=\"color:\\#8899aa\">0.00\\%</span>';" +
                            "  var sign = v > 0 ? '%2B' : '';" +
                            "  var color = v > 0 ? '\\#4ade80' : '\\#f87171';" +
                            "  return '<span style=\"color:' %2B color %2B ';font-weight:bold\">' %2B sign %2B v.toFixed(2) %2B '\\%</span>';" +
                            "})() #";
                    }
                    else if (column.Member == "AgeDiffMinutes")
                    {
                        column.ClientTemplate =
                            "#= (function() {" +
                            "  var m = data.AgeDiffMinutes;" +
                            "  if (m == null) return '';" +
                            "  var d = Math.floor(m / 1440);" +
                            "  var h = Math.floor((m % 1440) / 60);" +
                            "  var text = d > 0 ? d + 'd ' + h + 'h' : h + 'h';" +
                            "  var style = d > 30 ? 'color:red;font-weight:bold' : d > 7 ? 'color:orange' : '';" +
                            "  return '<span style=\"' %2B style %2B '\">' %2B text %2B '</span>';" +
                            "})() #";
                        column.Width = "70px";
                    }
                }
            });

            grid.Pageable(pager => pager
                .Enabled(true)
                .Input(true)
                .Numeric(true)
                .Info(true)
                .PreviousNext(true)
                .Refresh(false)
                .PageSizes(true)
                .PageSizes(new[] { 20, 50, 100, 200 }));

            return grid;
        }
    }
}
```

---

## Task 5: View + Button + Controller

**Files:**
- Create: `WebAdmin/WebAdmin/Views/Home/VW_ExchangeRateUpdates.cshtml`
- Create: `WebAdmin/WebAdmin/Models/Monetization/ExchangeRateSnapshotItem.cs`
- Modify: `WebAdmin/WebAdmin/Views/Home/RegionalPriceRates.cshtml`
- Modify: `WebAdmin/WebAdmin/Controllers/HomeController.cs`
- Modify: `WebAdmin/WebAdmin/Helpers/AdminAction.cs`

- [x] **Step 1: Add AdminAction enum entry**

In `AdminAction.cs`, add after `RegenerateTournaments` (~line 259):

```csharp
SnapshotExchangeRatesForRegionalPricing,
```

- [x] **Step 2: Create ExchangeRateSnapshotItem.cs**

```csharp
using System;

namespace WebAdmin.Models.Monetization
{
    public class ExchangeRateSnapshotItem
    {
        public int RateId { get; set; }
        public decimal Rate { get; set; }
        public DateTime? Timestamp { get; set; }
    }
}
```

- [x] **Step 3: Create VW_ExchangeRateUpdates.cshtml**

```html
@using WebAdmin.Models
@using WebAdmin.Models.Monetization
@model WebAdmin.Models.Monetization.ExchangeRateUpdateModel

<script type="text/javascript">
    var uniqueCookieName = '@Model.TableName' + '_';
    var tableName = '@Model.TableName';
    $.cookie("language", '@Model.LangId');
</script>

<hgroup class="title">
    <h1>@ViewBag.Title</h1>
</hgroup>

<script type="text/javascript">
    function UpdateSelectedRates() {
        var gridData = $("#Grid").data("kendoGrid").dataSource.data();
        var rates = gridData.filter(r => r.Selected).map(a => ({
            rateId: a.RateId,
            rate: a.NewRate,
            timestamp: a.NewRateTimestamp
        }));

        if (rates.length === 0) {
            alert("No items selected");
            return;
        }

        if (!confirm("Update exchange rates for " + rates.length + " item(s)?"))
            return;

        $.ajax({
            type: "POST",
            url: "/Home/SnapshotExchangeRates",
            data: JSON.stringify({ rates: rates }),
            contentType: "application/json",
            success: function (result) {
                alert(rates.length + " exchange rate(s) updated");
                location.reload();
            },
            error: function (result) {
                alert(result.statusText);
                location.reload();
            }
        });
    }

    function UpdateAllRates() {
        var gridData = $("#Grid").data("kendoGrid").dataSource.data();
        var rates = gridData.toJSON().map(a => ({
            rateId: a.RateId,
            rate: a.NewRate,
            timestamp: a.NewRateTimestamp
        }));

        if (!confirm("Update ALL " + rates.length + " exchange rates?"))
            return;

        $.ajax({
            type: "POST",
            url: "/Home/SnapshotExchangeRates",
            data: JSON.stringify({ rates: rates }),
            contentType: "application/json",
            success: function (result) {
                alert(rates.length + " exchange rate(s) updated");
                location.reload();
            },
            error: function (result) {
                alert(result.statusText);
                location.reload();
            }
        });
    }

    function toggleSelectAll(cb) {
        var grid = $("#Grid").data("kendoGrid");
        var checkboxes = grid.tbody.find("input[onchange*='Selected']");
        checkboxes.each(function () {
            if (this.checked !== cb.checked) {
                this.checked = cb.checked;
                bindCheckBox(this, "Selected");
            }
        });
    }

    function syncSelectAllState() {
        var grid = $("#Grid").data("kendoGrid");
        var checkboxes = grid.tbody.find("input[onchange*='Selected']");
        var allChecked = checkboxes.length > 0 && checkboxes.toArray().every(function (cb) { return cb.checked; });
        $("#selectAll").prop("checked", allChecked);
    }

    function OnDataBound(e) {
        var selectedHeader = this.wrapper.find(".k-grid-header [data-field=Selected]");
        if (selectedHeader.length && !selectedHeader.find("#selectAll").length) {
            selectedHeader.empty().off("click").css("text-align", "center").append(
                $('<input type="checkbox" id="selectAll" title="Select / Deselect All" />')
                    .on("click", function (ev) {
                        ev.stopPropagation();
                        toggleSelectAll(this);
                    })
            );
        }

        dataBound.call(e.sender);
        syncSelectAllState();

        this.tbody.off("change.selectAll").on("change.selectAll", "input[onchange*='Selected']", syncSelectAllState);
    }

    @Html.Raw(Model.GetDynamicJscripts())
</script>

<table width="100%">
    <tr>
        <td align="left">
            <a href="/Home/EditData?tableName=RegionalPriceRates&lang=3" class="k-button"
               title="Back to Regional Price Rates">
                &larr; Back to RegionalPriceRates
            </a>
        </td>
        <td align="right">
            <button class="k-button" title="Update exchange rates for selected items"
                    onclick="UpdateSelectedRates()">
                Update Selected
            </button>
            <button class="k-button" title="Update exchange rates for all items"
                    onclick="UpdateAllRates()">
                Update All
            </button>
            <input type="button" value="Clear State"
                   title="Clear all filters, column visibility and order" onclick="clearCookies()">
        </td>
    </tr>
</table>

@(Html.Kendo()
    .Grid<ExchangeRateUpdate>()
    .ConfigureInModel(Model)
    .Events(events => events
        .DataBound("OnDataBound")))
```

- [x] **Step 4: Add button to RegionalPriceRates.cshtml**

Replace the toolbar table:

Old:
```html
<table width="100%">
    <tr>
        <td align="right">
            <input type="button" value="Clear State" title="Clear all filters, column visibility and order" onclick="clearCookies()">
        </td>
    </tr>
</table>
```

New:
```html
<table width="100%">
    <tr>
        <td align="left">
            <a href="/Home/EditData?tableName=VW_ExchangeRateUpdates&lang=3" class="k-button"
               title="Review and update saved exchange rates">
                Update Exchange Rates
            </a>
        </td>
        <td align="right">
            <input type="button" value="Clear State" title="Clear all filters, column visibility and order" onclick="clearCookies()">
        </td>
    </tr>
</table>
```

- [x] **Step 5: Add controller endpoint in HomeController.cs**

Add after `ApplySuggestedPrices` (~line 1146):

```csharp
[HttpPost]
[CustomAuthorize(Roles = "RW")]
public async Task<ActionResult> SnapshotExchangeRates(List<ExchangeRateSnapshotItem> rates)
{
    AdminActionLog.LogAction(AdminAction.SnapshotExchangeRatesForRegionalPricing,
        Guid.Empty, string.Join(",", rates.Select(r => r.RateId)));

    var provider = DalFactory.GetMonetizationProvider();
    var ratesByRateId = rates.ToDictionary(
        r => r.RateId,
        r => (r.Rate, r.Timestamp ?? DateTime.UtcNow));

    try
    {
        var updated = await provider.SnapshotExchangeRatesForRegionalPricingAsync(ratesByRateId);
        return new EmptyResult();
    }
    catch (Exception e)
    {
        Log.Error(e);
        return new HttpStatusCodeResult(HttpStatusCode.InternalServerError, e.Message);
    }
}
```

---

## Task 6: Build + Verify

- [x] **Step 1: Ask user to build** WebAdmin.sln and LoadBalancing.sln
- [x] **Step 2: Ask user to apply SQL** — patch + both views on dev DB
- [x] **Step 3: Smoke test checklist**

1. RegionalPriceRates page — ExchangeRate column shows saved values
2. "Update Exchange Rates" button visible
3. New page opens with Platform, Currency, Country, rates, deviation, age
4. Deviation: green +, red −
5. Age: orange >7d, red bold >30d
6. Select items → "Update Selected" → rates updated
7. "Update All" → all rates updated
8. ProductLocalPrices — suggested prices use saved exchange rate
9. Prices stable across reloads

- [x] **Step 4: Commit**

```
FP-43177: [ExchangeRate] Manual exchange rate snapshot for regional pricing
+ ExchangeRate and ExchangeRateTimestamp columns in RegionalPriceRates
+ VW_ExchangeRateUpdates view: current vs live rate comparison
+ ExchangeRateUpdate entity, model, Kendo grid page with Select All
+ SnapshotExchangeRates controller endpoint, AdminAction entry
+ SnapshotExchangeRatesForRegionalPricingAsync in IMonetizationProvider / SqlMonetizationProvider
= RegionalPriceRates and ProductLocalPrices use saved rate instead of MonetizationCache
= VW_ProductLocalPrices view: added rt.ExchangeRate
(Story: Refinement of the price adjustment tool)
https://fishingplanet.atlassian.net/browse/FP-43177
```
