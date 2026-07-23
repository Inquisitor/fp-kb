---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16343+r16344+r16345+r16348, merged to NPN20260602 @ r16355
jira: https://fishingplanet.atlassian.net/browse/FP-44943
---

# Review: FP-44943 — [Prod Bugs][Xbox][DLC] User gets items from the same DLC pack every time

## Summary

In H2 2019, 9 Xbox players ended up with broken (empty, `ItemIDs = []`) rod setups in their profiles. When such a player buys a DLC containing rod setups, product delivery crashes (`GetNextIndexForRodSetup` throws), the purchase never completes, and the DLC is re-delivered on every login — one player received the Chameleo pack 26 times. The fix: (1) make product delivery survive empty rod setups, (2) add a ReleaseTool command to revert duplicated DLC deliveries (executed on Xbox prod 2026-07-20), (3) cleanup scripts for phantom DLC transactions for the single affected user. Broader over-delivery cleanup deferred — no exact criteria yet (see Confluence "Xbox UWP Consumable Over-Delivery Diagnostic Report").

## Scope

### MFT20260325
- **r16343** — Add ReleaseTool command to revert duplicated DLC deliveries
  - Executed on Xbox prod 2026-07-20 (per JIRA comment)
- **r16344** — Harden revert-duplicated-DLC command per code review
- **r16345** — Fix empty rod-setups crashing product delivery
- **r16348** — Add phantom DLC transaction cleanup scripts (Xbox, 1 user)

### NPN20260602 (merged)
- **r16355** — Merge of r16343+r16344+r16345+r16348 as a single commit

## Investigation Journal

- Intake from JIRA comment (face value, pre-audit). Executor identified as commit author from JIRA comment; JIRA Executor field (`customfield_11224`) is empty.
- NPN20260602 base is MFT20260325:16130 (`_index.md` ancestry) — r16343+ are NOT inherited via branch copy; explicit merge r16355 was required and is present.
- r16343 command was executed on Xbox prod (2026-07-20) BEFORE this review — remediation already applied; review verifies after the fact.
- r16344 message says "per code review" — indicates an earlier same-session/pre-commit review round by the executor's tooling, not this review.
- VCS audit: `svn log -r 15943:HEAD` on MFT URL grep FP-44943 → exactly r16343/16344/16345/16348 (all yuriy.burda) — matches JIRA comment. r16346/r16347 do not exist on MFT (absent from `svn log -v -r 16343:16348` on the branch URL), so the r16355 range-merge header "16343-16348" swept in no foreign commits; `svn log -v -c 16355` changed paths = exact union of the four commits' paths.
- WC freshness: WC at r16351 ≥ r16348; `svn status` — local modifications only in unrelated ChatServer/Clubs files. Task files clean on disk EXCEPT `EntryPoint.cs` which carries later r16349 (FP-44598) on top — reviewed `EntryPoint.cs` state taken from `svn diff -c 16343/16344`, other files read from disk.
- Crash mechanism verified in source: `RodSetup.Rod` = `Items.OfType<Rod>().FirstOrDefault()` → null for empty setup; pre-fix `GetNextIndexForRodSetup` dereferenced `p.Rod.ItemSubType` unguarded (`Inventory_Static.cs`); `GetNewSetupName` is called from both delivery paths (`ProfileHelper.PutProductToProfile` rod-setups step, `TrackedProductDelivery`).
- Corruption mechanism verified in source: `RodSetup.Items` setter with null resets `ItemIDs` to EMPTY ARRAY (not null) — old `RemoveSetup` (`setup.Items = null; setup.Name = null`) produced exactly the `"ItemIDs":[]` + `Name:null` persisted shape the executor's scan SQL hunts. Exact historical ref-sharing path (2019) not re-derived — the code comment hedges it as "may be ref-shared"; fix is safe regardless (unlink-only is sufficient).
- `RodSetup.IsEmpty` = `ItemIDs == null || ItemIDs.Length == 0` — broader than the old `ItemIDs == null` check in `ProfileHelper.FixInventoryErrors`; empty setups are now removed (with inventory log) at profile load. `FixInventoryErrors` runs from `ProfileAdapter.GetProfileForMaster` (login path) → broken profiles self-heal on next login; this, not the guards, is the primary repair path.
- Legacy delivery order verified (`PutProductToProfile`): balance → subscription → pond passes → paid unlocks → items → licenses → **rod setups (throw point)** → InventoryExt/RodSetupExt/ChumRecipesExt/BuoyExt/NavBuoyExt/RepairKitExt/SkinElements. Revert covers exactly the pre-throw components and skips post-throw ones — matches the r16344 doc-comment claim. PaidPondsUnlocked is add-if-missing (no accumulation) → duplicates added nothing, correctly untouched.
- `Profile.AddLicense` verified: limited license → `Term += license.Term` AND `End += days` (both wound back by revert ✔); existing `Term == 0` (unlimited) → grant ignored (revert's Term==0 skip ✔); `PutLicenses` calls `AddLicense` per occurrence in the group → per-delivery term = SUM per LicenseId (revert's `licenseGroup.Sum(l => l.Term)` ✔).
- Pond passes (non-PS branch = Xbox): delivery loops `foreach (var pondId in product.PondsUnlocked)` — per OCCURRENCE, each adds `Term` days to the existing pass → revert's `GroupBy(p=>p).Count() * Term * failsQty` matches. `LevelLockRemoval.Type` is COMPUTED (`EndDate!=null && AccessibleLevel!=null → Product`) — revert filter `Type == Product` matches delivery-created passes iff the product has non-null `AccessibleLevel` (see unresolved below).
- `Inventory.RemoveItem` verified: recursively removes nested items (`GetNestedItems(item, true)` loop) → r16344 claim "nested items reverted as a cascade of removing their parent" holds.
- `SmartOfflineProfileUpdater` verified: `Execute` → offline check → converter → on `true` + re-confirmed offline → queue row DELETE; `false` keeps the row. Dry-run-returns-false and save-conflict-returns-false semantics in r16344 are correct against this runner.
- `SavePlayerProfile` SP (`SQL/Patches/Main/Procedures/SavePlayerProfile.sql`): `@Overwrite=0` guards ONLY XP monotonicity (`WHERE Experience+RankExperience <= @new`), not general concurrency; provider returns rowcount==2. The r16344 code comment "returns false if the DB copy advanced since load" OVERSTATES the guard — see F-finding. Primary race protection is the runner's offline gating.
- `BalanceHelper.IncrementBalance(profile, currency, value, type, message, preventNegativeBalance)` signature verified.
- Stats script recompute vs live jobs: `SqlAsyncProvider.CaptureSales` — same filters (Status='Complete', PaymentSystemId<>'WebAdmin', u.Source, EquivalentPrice>0, Role '-' or NULL), same joins, same region CASE split; job is forward-only from GetLastSalesDate (historical buckets never re-baked ✔). `GetTotalRevenueByPlatform` — GROUP BY PaymentSystemId matches script's `t.PaymentSystemId = lr.Source`; `CollectLegacyRevenueStatsJob` forward-only from env-var date ✔. Divergences (both negligible, visible in dry-run output): job windows use inclusive `BETWEEN` (boundary-exact tx counted twice by job, once by script); LegacyRevenue job uses INNER JOIN Profiles vs script's LEFT JOIN.
- `SqlAnalyticsProvider.SaveTransactionFact` — INSERT-only, no Status column in the column list → "TransactionFact has no Status and is never re-synced from Main" claim confirmed statically.
- SQL/Releases naming: `R<yyyymm>-<Topic>.sql` matches the established convention in that folder (incl. prior `R202606-RecomputePaymentsBuckets-UWP-Stats.sql` precedent); these are as-executed ops scripts, not AppliedPatches migrations.
- Cross-repo client-mirror check (diff touches `Shared/ObjectModel/`): client source copy (`Win64_MainClient/Assets/Photon Server Networking/ObjectModel/Inventory/Inventory.cs:1917-1933`) has UNGUARDED `GetNextIndexForRodSetup`/`GetNumber`; client has `CanRemoveSetup` but NO `RemoveSetup` (removal is server-side) → root-cause fix needs no mirror; guards divergence recorded as finding. No paired client commit: client repo HEAD r56486 (2026-07-20) predates the server commits (21-22.07) — verified via `svn log` on the MainClient WC.

- Empirical test run: built `LoadBalancing.Tests.csproj` (MSBuild, Debug) at WC r16351 and ran `dotnet test --no-build --filter FullyQualifiedName~RodSetupTests` → 13 passed / 0 failed, including both new r16345 tests. (Reverse-merge discriminating-power check not performed — static trace of the fix was straightforward.)

### Product #15639 config — verified against local Main DB (WebStorm MCP, read-only)

Product exists in local Main and is real: PlatformId=3 (Xbox), TypeId=2, Term=60, Silver=100000, Gold=100, ClubTokens=null, Ponds2Unlock=254, InventoryExt=100/RodSetupExt=2/BuoyExt=50 (post-throw components — correctly NOT reverted), ItemJson 9974 chars, LicenseJson `[{416,30},{416,30}]`.
- **License**: `416` listed twice at 30d → per-delivery term = 60d. Confirms r16344 comment verbatim; revert's `licenseGroup.Sum(l => l.Term)` = 60 is correct (taking first entry alone would revert only 30).
- **Pond pass**: Ponds2Unlock=254, Term=60. `GetProductAccessibleLevel` → `GetPondsMinLevelMaximum` → `Ponds.MinLevel` for pond 254 = **94** (non-null). Delivered `LevelLockRemoval` therefore gets `AccessibleLevel=94`, `EndDate` set → `Type=Product`. Non-PS (Xbox) delivery branch extends a single existing pass additively (`EndDate += Term` per delivery), so N duplicates → `now + 60*N`; revert subtracts `Term * pondGroup.Count() * failsQty` = `60*failsQty` from that one pass → reachable (`Type==Product` filter matches) AND arithmetically correct. Resolves the earlier "pond-pass reachability" hypothesis in the reachable direction.
- **Items / F-3 cascade**: `MonetizationHelper.BuildInventoryItems` links a rod's `RodItemIds` children as `ParentItemInstanceId`/`ParentItem` (`MonetizationHelper.cs:200`), NOT as `NestedItems`. In `Inventory.RemoveItem`, `ParentItemInstanceId` children are RE-PARENTED to Equipment (mechanism #2), while only `GetNestedItems`/`NestedItems` composites are cascade-REMOVED (mechanism #1). The product populates the former, not the latter → removing a product item does not cascade-remove another product item → F-3 part A (cascade-manufactured penalty) is NOT triggered by this product's delivered structure. Activation would require player-side runtime `NestedItems` nesting, which this product does not deliver.

### Considered and rejected

- **`preventNegativeBalance` "does not clamp an already-negative balance" (Codex C5) — rejected, by-design.** `IncrementBalanceEx` (`BalanceHelper.cs:106`) clamps only when `GetBalance(currency) >= 0`; an already-negative balance is deliberately not repaired. Per domain semantics: a negative balance is a legitimate state produced by sanctions or real-money-item refunds — game logic via `BalanceHelper` can never cross zero downward, but admin/sanction actions can. Auto-repairing (clamping a sanctioned negative back to 0) would be the bug — it would erase a legitimate penalty and gift currency. The revert's use of `preventNegativeBalance:true` is correct: it won't push a normal player negative, and legitimately continues withdrawal on an already-sanctioned balance. Pre-existing shared code, not touched by FP-44943. Contract-clarity follow-up (reword flag to "no downward zero-crossing", no behavior change, no auto-repair) filed → `modules/balance/backlog.md` (new stub module).

### Unresolved (data/runtime claims not settled statically)

- Prod-execution claims ("As executed on Xbox prod 2026-07-20"; SQL cleanup applied for 1 user) — deployment facts; instrument would be prod conversion/inventory logs + prod DB (manual-approval prod queries); not decision-affecting for code verdict; taken at face value.
- Whether `applyPenalty=true` was used on the prod run — flags not in JIRA; default is off; penalty affects only already-sold/consumed duplicates.
- Description says 9 affected players, executor's scan found 8 — discrepancy unexplained (possibly early estimate in description); scan SQL itself is shape-correct.
- "TransactionDeliveryItems=0, PurchaseReceipts=0 (verified)" — prod data claim; failure mode if wrong is a loud FK error + rollback (XACT_ABORT), not silent corruption; accepted at face value.
- Stats-side expected deltas (-26 / -967.04; bucket 07:42:30 held only 2 phantom rows) — prod data; script prints stored-vs-recomputed before COMMIT, operator-verifiable.

## Findings

### F-1: Live-login race — revert can be lost or clobber player progress [Medium]

**Description:** `RevertDuplicatedDlc_FP44943` runs via `SmartOfflineProfileUpdater`, whose only concurrency protection is a point-in-time `IsOnline` check before/after the conversion plus `SavePlayerProfile(dto, overwrite:false)`. The `@Overwrite=0` branch of the `SavePlayerProfile` SP guards ONLY XP monotonicity (`WHERE Experience+RankExperience <= @new`), not general concurrency — the revert never touches XP. If the player logs in during the load→compute→save window and makes any XP-neutral change (spend currency, buy/equip item, buy license, unlock pond pass): (A) the tool's save passes the XP guard, zeroes `DeliveryFailsQty`, the post-check sees "online" and keeps the queue row; the server later saves its own copy with the duplicates intact → revert lost, and a re-run reads `DeliveryFailsQty=0` → "nothing to revert" → deletes the row (silent false-completion); or (B) the tool overwrites the profile with its stale snapshot, discarding the player's concurrent progress. If the player instead grew XP and the server persisted it, the guard fires and `SavePlayerProfile` returns false → clean retry (r16344 handles this correctly).

**Investigation:** Read `SavePlayerProfile.sql` — `@Overwrite=0` WHERE clause is XP-monotonicity only; provider (`SqlProfileProvider.SavePlayerProfile`) returns rowcount==2. Read `SmartOfflineProfileUpdater` — `ConvertSingleProfile` brackets converter with `IsUserOffLine`/`IsUserOffLineEx` (point-in-time SELECTs, no held lock); row deleted only on converter `true` + re-confirmed offline. r16344 diff: added result check on `SavePlayerProfile` (r16343 ignored it entirely and logged "Profile saved" unconditionally) and zeroes `DeliveryFailsQty` after save — improves but does not close the window. Both delegates independently reached the same mechanism (Codex High both directions; code-reviewer agent Medium, noting it is the shared `SmartOfflineProfileUpdater` idiom, not introduced here).

**Resolution:** Accepted. One-off command (`ProductId` hardcoded), already executed on Xbox prod 2026-07-20 with dry-run first; target cohort is 8 mostly-dormant accounts (last activity 2019-2022, one 2026-01) so the seconds-wide window has ~0 collision probability; damage bounded to exactly the accounts being repaired; the pattern is inherited from the existing offline-conversion infrastructure, not introduced by this task. ReleaseTool / `SmartOfflineProfileUpdater` hardening tracked separately (out of FP-44943 scope).

**Discovered by:** skill recon + Codex + code-reviewer agent.

### F-2: Non-atomic save→zero-count with swallowed error → double revert on re-run [Medium]

**Description:** The tail of `RevertDuplicatedDlc_FP44943` (r16344) does two separate, non-transactional SQL ops: `SavePlayerProfile(dto, false)` (via the SP), then a direct `UPDATE {tableName} SET DeliveryFailsQty = 0`. The zeroing is wrapped in try/catch that only logs on failure, and the method returns `true` regardless. `DeliveryFailsQty` is the source of truth for `failsQty` at method start. If the profile save committed but the zeroing did not — UPDATE threw (caught, logged, `true` returned), or the process/connection dropped between the two statements, or (with F-1) the post-check saw the player online so the queue row was kept — the row survives with a stale non-zero count. A subsequent tool run re-reads the old count and re-applies the entire currency/subscription/pond/license/item reversal against an already-corrected profile, over-penalizing exactly the players this task should make whole. The `return false`-on-save-conflict branch (step 1) is correct and yields a clean retry; the gap is step 2.

**Investigation:** Verified against r16344 diff — `catch (Exception markEx) { conversionLog.AppendLine("Warning..."); }` followed by `return true`, confirmed verbatim. Profile save and count-zeroing use different `SqlConnection`s (provider/SP vs direct `SqlCommand`), so no shared transaction. Runner (`SmartOfflineProfileUpdater.ConvertSingleProfile`) deletes the queue row only on converter `true` + re-confirmed offline; a kept row with stale count is re-processed next run.

**Resolution:** Accepted. Damage is data-dependent and requires both a step-2 failure AND a deliberate operator re-run (which begins with a dry-run showing per-user `failsQty` and expected deltas). One-off command already executed successfully 2026-07-20 against a small manual cohort. Hardening (make count-zeroing part of the success criterion) folded into the same separate ReleaseTool ticket as F-1.

**Discovered by:** Codex + code-reviewer agent.

### F-3: Dry-run vs apply divergence in the item revert [Low]

**Description:** Two threads. (A) Cascade-manufactured penalty: the item loop re-reads `profile.Inventory` per ItemId group; in apply `RemoveItem` recursively removes `GetNestedItems` composites, in dry-run it does not, so a later group could see fewer items in apply than dry-run reported and charge a penalty apply-only (with `applyPenalty=true`). (B) Balance report fidelity: `RevertBalance` in dry-run logs `Balance X -> X (dry run)` and cannot reveal that apply would clamp the withdrawal at 0 (see F-4) or that a penalty would exhaust the balance — the clamp banner is computed from `before-after`, which is 0 in dry-run.

**Investigation:** Verified product 15639 config against local Main (WebStorm MCP) — see "Product #15639 config" above. Part A is NOT triggered by this product: its rod components are linked via `ParentItemInstanceId` (re-parented on remove), not `NestedItems` (cascade-removed); `RemoveItem` mechanism #1 (`GetNestedItems`) only removes `NestedItems` composites, which the product does not deliver. Activation would need player-side `NestedItems` nesting (runtime, unavailable, and this product delivers none). Part B is unconditionally true but only degrades dry-run report informativeness; the clamp itself is F-4. Traced `IncrementBalanceEx` (`BalanceHelper.cs:106-109`): `trimmedValue = Math.Min(-value, balance)` → withdrawal trimmed to available, leaving 0.

**Resolution:** Accepted. Part A near-unreachable for this product (structure-grounded); `applyPenalty` off by default and only touches already-sold/consumed duplicates. Part B is a report-fidelity gap, not data corruption.

**Discovered by:** Codex.

### F-5: Penalty valuation differs from the in-game `SellPrice` [Low]

**Description:** The penalty for duplicated items the player no longer has uses `(int)(Cache.Price * 0.2 * toCompensate / stackBasis)`, gated on `IsSellable`. The in-game `SellPrice` (`InventoryItem.cs:347`) instead scales by the instance's current `Durability/MaxDurability`, returns null when `MaxDurability==null` / near-broken / value < `MinSellPrice` 0.4, rounds AwayFromZero, and `CanSell` also requires `SellPrice != null`.

**Investigation:** The full-durability basis is correct-by-design, not an approximation error: the penalty reverses a GRANT of a NEW item, which the player received whole, so the whole-item value is what they owe; using current durability would UNDER-charge for a consumed/sold duplicate (a spent consumable would value at 0). The `MaxDurability==null → SellPrice=null` over-charge case (item the game would never credit, but the revert charges) was checked against product 15639's actual items via local Main (WebStorm MCP): OPENJSON over `Products.ItemJson` joined to `InventoryItems` — 150 entries / 85 distinct ItemIds, all 85 matched (0 unmatched), and every distinct item has a NON-NULL `MaxDurability`. So the over-charge class is empirically empty for this product. Residual divergence is only `(int)` truncation vs AwayFromZero rounding (≤1 credit). The 150/85 counts also confirm the executor's "150 entries over 85 distinct ids" comment.

**Resolution:** Accepted. Full-durability valuation is semantically correct for reversing a new-item grant; over-charge case ruled out for this product; ≤1-credit rounding is trivial; penalty is off by default and reported for manual waiver.

**Discovered by:** Codex.

### F-6: `RemoveSetup` still mutates a potentially shared setup (`setup.Profile = null`) [Low]

**Description:** r16345 stopped scrubbing the serialized `Items`/`Name` (the actual persistence-of-empty-record bug) but kept `setup.Profile = null`. Codex (C8) argued that if the `RodSetup` is ref-shared with another profile copy, nulling its back-reference makes that copy's `GetMissingItems` throw (`profile.Inventory`) and silently changes `ItemsToEquip` (`if (profile == null) return Items`).

**Investigation:** `RodSetup.Profile` is `[JsonIgnore]` (`RodSetup.cs:12`) → nulling it never persists; runtime-only. Not a regression: the old code also nulled `Profile` (plus the harmful `Items`/`Name` scrub the fix removed), so the fix is strictly better. Author confirmed on review call: profile copies do not exist (the profile is large; keeping copies would be absurd) — so no sibling copy can hold the same setup with a nulled `Profile`; Codex's harm scenario is unreachable. Setup objects may be ref-shared, but not across profile copies. Author agrees the code comment referencing "ref-shared across profile copies" is misleading/excessive.

**Resolution:** Accepted. Runtime-only, unreachable harm (no profile copies), strictly better than prior behavior. Follow-up: trim the misleading "ref-shared across profile copies" comment in `RemoveSetup` (`Inventory_Operations.cs`) — distracting, no behavior change (bubbles to module backlog on review close).

**Discovered by:** Codex.

### F-7: NOLOCK on mutation-driving reads in the Stats cleanup script [Low]

**Description:** `R202607-RemovePhantomDlcTransactions-XBox-Stats.sql` reads Main under `NOLOCK` and feeds those values into `UPDATE`s: Guard 0 (`MainDbTransactions WITH (NOLOCK)` — enforces run-order), and the `#PaymentBucketRecompute` / `#LegacyRevenueRecompute` reads of `MainDbTransactions/Users/UserCountries/CountryRegionMapping/Profiles WITH (NOLOCK)` that drive `UPDATE Payments` / `UPDATE LegacyRevenueStats`. This is exactly the exception in the project [sql-nolock] rule: a read whose result drives a mutation must not be a dirty read. Codex (C9) adds: if Main's delete is uncommitted, Stats could dirty-read the corrected state, pass Guard 0, and commit; a Main rollback then desyncs Main and Stats.

**Investigation:** Verified against the script header and the [sql-nolock] convention. Practical risk is low: (a) sequential manual run — header mandates `-Main.sql` COMMIT first, Guard 0 THROWs otherwise, so at Stats time Main's delete is committed and NOLOCK reads see committed data; the mid-transaction dirty window requires concurrent execution, absent in a manual op; (b) historical buckets — the recompute targets 2026-07-08/09 windows, ~2 weeks old at run time, so no concurrent writers land in them. The script also prints verification result sets before COMMIT, which the operator reviewed.

**Resolution:** Accepted. Rule-violation is real but practically inert (historical buckets + sequential manual run + post-run verification). Note for future Stats remediation scripts: reads feeding an aggregate UPDATE should avoid NOLOCK (or use snapshot / READ COMMITTED).

**Discovered by:** Codex.

### F-8: Guards assert "one row remains", not that the survivor is `@Keep` [Low]

**Description:** The Main script guards check the phantom list has 26 ids, `@Keep` is absent from it, and the 26 match user/product/Complete; then it DELETEs the 26 and runs a `SELECT` (not a guard) showing `RemainingForUserProduct` + `RemainingTxId`. Nothing asserts that `@Keep` exists or that the single survivor IS `@Keep`. Codex (C10): if `@Keep` never existed but one unexpected non-phantom Complete row X did, Main deletes the 26 phantom, leaves X, and an operator checking only the count (=1) would preserve the wrong transaction.

**Investigation:** Stats Guard 0 (`COUNT(*) MainDbTransactions user/product/Complete <> 1 THROW`) enforces exactly-one-remaining, so the "extra unexpected row" case (originally 28 → remaining 2) is caught before any Stats mutation; only the degenerate "@Keep absent + exactly one foreign row" slips the count check. Identity (`RemainingTxId = @Keep`) is asserted nowhere — left to operator eyeballing the printed `RemainingTxId` under the dry-run ROLLBACK default. Data is pre-verified: executor identified `@Keep = 12176E8B... ` as the real 2026-07-09 18:26:55 purchase, so the degenerate case contradicts established fact.

**Resolution:** Accepted. Count is enforced (Stats Guard 0), identity is operator-verified in the dry-run, `@Keep` pre-verified, one-off already executed. Hardening for future scripts: replace the post-delete `SELECT` with `IF (post-delete count) <> 1 OR NOT EXISTS(@Keep after delete) THROW` so survivor identity is machine-asserted.

**Discovered by:** Codex.

### F-9: "IDEMPOTENT" header claim is imprecise — re-run THROWs, not a silent no-op [Info]

**Description:** Both scripts' headers claim idempotency ("a re-run deletes nothing" / "a re-run changes nothing"). In fact guard 3 (26 phantom rows / 26 fact rows must still exist) runs before DELETE; after a committed run those rows are gone → count 0 <> 26 → THROW. A second run fails at the guard rather than reaching a graceful no-op.

**Investigation:** Verified guard order vs DELETE in both scripts. The safety property holds — THROW precedes `BEGIN TRAN`, so a re-run changes no data — just via fail-loud, not no-op. The backup step IS genuinely idempotent (`IF OBJECT_ID(...) IS NULL` create / else skip); only the DELETE-path wording overstates. Stats' "recomputed == stored → changes nothing" reasoning is unreachable (fact-row guard THROWs first), again on the safe side. No functional defect.

**Resolution:** Skipped. Wording imprecision in a comment of an already-deployed one-off script; functionally fail-safe. Not worth touching.

**Discovered by:** Codex.

### F-10: Recompute bucket/day boundaries differ from the live jobs (`BETWEEN` vs `(start, end]`) [Low]

**Description:** The Stats recompute uses a half-open Payments window (`Timestamp > DATEADD(MINUTE,-10,p.Timestamp) AND <= p.Timestamp`) and `CAST(Timestamp AS date)` for days, whereas the jobs it reproduces use inclusive `BETWEEN` on both ends — `CaptureSales` (`SqlAsyncProvider.cs:882`, `@Start=@End-10min`) and `GetTotalRevenueByPlatform` (`SqlMonetizationStatsProvider.cs:48`). A transaction exactly on a 10-min boundary (or midnight) is double-counted by the job (inclusive both ends → in two adjacent buckets) but counted once by the script, so a recomputed bucket can differ from what the job originally stored if such a boundary transaction exists in the window.

**Investigation:** All other predicates match field-for-field (Status, PaymentSystemId<>'WebAdmin', Role '-'/NULL, region CASE, joins) — verified by the code-reviewer agent; isolated boundary-inclusivity difference. Crucially, the script's half-open `(start, end]` is the CORRECT semantics (each transaction in exactly one bucket); the job's inclusive `BETWEEN` double-counts a boundary transaction across two adjacent buckets — a latent job bug, see F-12. So the divergence is the script being MORE correct, not a script defect. Residual effect: a corrected bucket won't bit-match the job's stored value if a boundary transaction exists in it, but that mismatch is the job's error, magnitude negligible: `Transactions.Timestamp` is `DATETIME` (~3.33 ms resolution), boundaries are exact 10-min marks, so a boundary collision is a real quantized event at ~3.33 ms / 600 s ≈ 5.5e-6 per transaction over low-traffic affected buckets. Any real divergence surfaces in the operator-reviewed dry-run `dCount/dAmount` deltas.

**Resolution:** Accepted. The script is correct (better than the buggy job); the underlying boundary double-count is filed separately as F-12. Do NOT change the script to mirror the job's `BETWEEN` — that would replicate the bug.

**Discovered by:** code-reviewer agent + Codex.

### F-12: Aggregation jobs double-count a boundary transaction (`BETWEEN` both-ends) [Low, pre-existing]

**Description:** `SalesStatUpdateJob`/`CaptureSales` (`SqlAsyncProvider.cs:853,882`) iterates 10-min buckets `CaptureSales(nextCalc-10, nextCalc)` filtering `WHERE Timestamp BETWEEN @Start AND @End` (inclusive both ends) and inserts one `Payments` row per bucket (`Timestamp = end`). Adjacent buckets share their boundary: bucket `T` covers `[T-10, T]`, bucket `T+10` covers `[T, T+10]`, so a transaction at exactly `T` is counted in BOTH rows. Summing `Payments` rows over a period double-counts boundary transactions, inflating revenue aggregates. Same pattern in `GetTotalRevenueByPlatform` (`SqlMonetizationStatsProvider.cs:48`) at day boundaries (a midnight transaction counted in two days).

**Investigation:** Read `CaptureSales` loop + INSERT (`SqlAsyncProvider.cs:849-964`): window inclusive both ends, one row per bucket keyed by `end`; step `+10min` makes each bucket's `@End` the next bucket's `@Start`. Confirmed the FP-44943 cleanup script's half-open `(start, end]` is the correct fix for this (each tx once). Magnitude tiny (boundary txs only, `DATETIME` 3.33 ms quantization, only affects summed aggregates), but a real correctness bug in live analytics. Not touched by FP-44943; surfaced by this review.

**Resolution:** Pre-existing → separate JIRA ticket (server analytics team), to be drafted at review close. Not blocking FP-44943.

**Discovered by:** review discussion (skill + user) off the F-10 boundary analysis.

### F-11: Client ObjectModel copy missing the `GetNextIndexForRodSetup`/`GetNumber` guards [Low]

**Description:** r16345 added server-side null guards (`GetNextIndexForRodSetup`: `p != null && p.Rod != null`; `GetNumber`: `Name == null` early return) in `Shared/ObjectModel/Inventory/Inventory_Static.cs`. The client source-duplicates `ObjectModel` (`Win64_MainClient/Assets/Photon Server Networking/ObjectModel/Inventory/Inventory.cs:1917-1933`) and still has the UNGUARDED versions; no paired client commit (client HEAD r56486, 2026-07-20, predates the server commits). Per [photon_interfaces_dll_distribution], combinatorial/behavioral ObjectModel logic must be mirrored to the client manually.

**Investigation:** Verified the client copy is unguarded (`Inventory.cs:1917-1933`) and that the client has no `RemoveSetup` (only `CanRemoveSetup`) — the client never creates empty setups (the corruption source was the server's old `RemoveSetup` scrub). Server `FixInventoryErrors` (login, `GetProfileForMaster`) now removes `IsEmpty` setups before the profile is built for master/client, so post-fix the client never receives an empty setup → its unguarded `GetNextIndexForRodSetup` has nothing to dereference. No client-side crash window; the missing mirror is defense-in-depth / shared-code symmetry, not a live defect.

**Resolution:** Accepted. Server scrub prevents an empty setup reaching the client, so no live crash. Client-side guard mirror → follow-up ticket (drafted at review close).

**Discovered by:** skill recon (cross-repo client-mirror check).

## Verdict

**Approve.** No blocking findings. The core product fix (r16345, empty rod-setup NRE) is sound and root-cause-understood — crash mechanism (`Rod == null` → NRE in `GetNextIndexForRodSetup`) and corruption mechanism (old `RemoveSetup` scrub persisting `ItemIDs:[]`/`Name:null`) both verified in source; the fix removes the scrub, guards the deref, and self-heals existing broken profiles via `FixInventoryErrors` at login; 13/13 `RodSetupTests` pass (built + run at r16351). The revert command (r16343/r16344) and SQL cleanup (r16348) are careful and, where checked against product 15639's real config + the live aggregation jobs, correct. All findings are Low/Info or Medium-Accepted; the two Medium items (F-1 live-login race, F-2 non-atomic save→zero) are inherited `SmartOfflineProfileUpdater` limitations with ~0 practical impact on a small dormant cohort, and the command was already executed on Xbox prod 2026-07-20 with dry-run first.

**Verification scope:** Root cause of the crash is verified. NOT independently verified: (a) which delivery path (legacy `PutProductToProfile` vs `TrackedProductDelivery`) was live for Xbox product 15639 at the 2019 delivery — the revert assumes legacy component order (post-throw `*Ext`/SkinElements never duplicated); the executor flagged this as "confirm before running" and the executed dry-run would have shown actual components; (b) prod-execution outcomes (conversion/inventory logs, corrected DB state) — deployment facts taken at face value.

**Follow-up tickets (filed at close, non-blocking, all Bug / Scrum Team Tech Debt, Relates FP-44943):**
- **FP-45180** — ReleaseTool `SmartOfflineProfileUpdater`/`SavePlayerProfile(false)` concurrency hardening (F-1, F-2).
- **FP-45181** — client-side mirror of the `GetNextIndexForRodSetup`/`GetNumber` guards (F-11).
- **FP-45182** — aggregation-job boundary double-count in `CaptureSales`/`GetTotalRevenueByPlatform` (F-12).
- `BalanceHelper.preventNegativeBalance` contract wording (F-4) → `modules/balance/backlog.md` (filed, no JIRA ticket).
- Trim misleading `RemoveSetup` comment (F-6) → bubbles to module backlog on close.

**Close actions:** verdict comment posted (id 132085); release-step field `customfield_11323` set to `Custom DB scripts`; cross-branch merge already present (executor's NPN r16355), no merge performed at close; Executor field found filled (Yuriy Burda) at close.

## Notes

- Executor field empty in JIRA (expected: Yuriy Burda) — detect-only, not blocking.
- Executor's scan SQL + affected-users table (8 users listed) posted in JIRA comment 2026-07-13.
- Nice finds credited to Codex: F-7 (NOLOCK on mutation-driving reads), F-8 (survivor-identity not asserted); to the code-reviewer agent + Codex jointly: F-10/F-12 (boundary semantics).
