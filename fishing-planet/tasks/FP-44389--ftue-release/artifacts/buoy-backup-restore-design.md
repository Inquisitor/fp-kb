# Deprecated-pond buoy backup & opt-in restore — design

Companion to the 2026.4 `RemoveDeprecatedBuoys` profile conversion (strips buoys from ponds
**119 Lone Star, 150 Lesni Vila, 160 Zeekanaal** and refunds GC for paid recolors). A restored
pre-removal DB backup exists on a reserve server; we extract the buoy data now (while the backup
lives) so it can later be merged back for players who ask to keep theirs.

## Where buoy data lives

`Profiles.ProfileJson` is the full `ObjectModel.Profile` serialized with
`SerializationHelper.JsonSerializerSettings` (`GetProfileOutOfDto` -> `JsonConvert.DeserializeObject<Profile>`).
Buoys are nested inside that blob:
- `Buoys` (`TrackingList<BuoySetting>`) — marker buoys: `BuoyId, Name, PondId, Position, Fish (CaughtFish), ColorId, LastRecolorPricing, CreatedTime, Sender…`
- `NavBuoys` (`List<NavBuoySetting>`) — `Id, PondId, Name, Position, CreatedTime`
- `BuoyShareRequests` (`TrackingList<BuoySetting>`)
- `BuoyRecolorCount` / `FreeBuoyRecolorCount` (`Dictionary<int,int>`; key = `PondId`, value = how many paid / free buoy recolors the player did on that pond). The conversion zeroed these for the removed ponds; we keep them so the counters *can* be restored if we choose to — policy deferred (see Open items). (The GC refund itself is recomputed from per-buoy `LastRecolorPricing`, not from this dict.)

SQL-parsing this (OPENJSON over nested arrays/dicts + `TrackingList` wrapper + `Point2`/`CaughtFish`)
is brittle. A converter that deserializes to `Profile` and re-serializes with the same settings
round-trips cleanly, so extraction/restore are done in code (ReleaseTool), not SQL.

Completeness (reviewed against the conversion + code): these 5 fragments (+ the `GoldCoins` refund,
recomputable from `LastRecolorPricing`) are the complete set the conversion touches.
`Inventory.SharedBuoys` / `AcceptedBuoys` / `DeclinedBuoys` are `[JsonIgnore]` transient runtime queues
(not in `ProfileJson`, not pond-keyed) and capacity fields (`BoughtBuoyCapacity` etc.) are global and
untouched — both correctly out of scope.

## Two artifacts per stream

Streams are separate DBs (Steam/PS/XB/MOB/NX); UserIds are per-stream. Run once per stream ->
five file pairs. Base name shared so the pair is obvious: `buoys_<stream>_<yyyymmdd>.*`.

### 1) JSONL payload — `buoys_<stream>_<yyyymmdd>.jsonl`
One line per player that has any buoy on the 3 ponds; arrays/dicts serialized with
`SerializationHelper.JsonSkipInventorySerializerSettings` — the same settings the live profile writer
uses in `GetDtoOutOfProfile`, so the dump matches the on-disk shape and drops straight back into
`Profile.*` on restore. (Plain `JsonSerializerSettings` also round-trips but emits `BuoySetting` noise:
`Update`/`Tracking` have no `[JsonIgnore]` on the class; the skip resolver drops them.)
```json
{"UserId":"<guid>","Buoys":[{…BuoySetting…}],"NavBuoys":[{…}],"BuoyShareRequests":[{…}],"BuoyRecolorCount":{"119":2},"FreeBuoyRecolorCount":{"150":1}}
```
Fragments filtered to `PondId in (119,150,160)`; recolor dicts filtered to those keys. Players with
nothing on these ponds are skipped (no line). Sidecar `buoys_<stream>_<yyyymmdd>.meta.json`:
stream, extracted-UTC, source server/rev, `pondIds`, schema version, totals, and the buoy-recolor
prices (`BuoyRecolorPriceGc` / `BuoyRecolorPricePremiumRatio`) read from the backup's `GlobalVariables`
(or the code defaults `2` / `0.5` if there's no explicit row — so a faithful GC recompute stays possible)
— keeps the JSONL homogeneous (every line is a user record).

### 2) CSV index — `buoys_<stream>_<yyyymmdd>.csv`
Long format, one row per (user × pond) with counts; a human-readable index and the source for the
import temp table:
```
UserId,PondId,PondName,MarkerBuoys,NavBuoys,ShareRequests
3fa8…,119,LoneStar,4,1,0
3fa8…,150,LesniVila,2,0,1
```
- `PondName` from `SharedConsts` (`LoneStar` / `LesniVila` / `Zeekanaal`) for readability; `PondId`
  stays for machine use.
- per-pond counts let support say "you had N buoys on Lone Star" and let ops pick opt-in by threshold.
- long > wide (`UserId,PondLoneStar,…`): survives a changed pond set, keeps marker/nav/share breakdown.

**The visitor's temp table needs UNIQUE UserId.** The CSV is per (user × pond) -> duplicate UserIds;
the visitor enumerates and runs multiple worker threads, so a duplicate UserId could be processed
twice concurrently -> double-merge race. So `BULK INSERT` the CSV into a staging table, then build the
visitor table deduped: `INSERT INTO dbo.TempBuoyRestore_<yyyyMMdd>(UserId) SELECT DISTINCT UserId FROM
<staging> WHERE <opt-in>` (dated name, universal like the finalizer's temp tables). The per-buoy
idempotency (below) is the second safety net against any double-process.

## Extraction flow (reserve DB, read-only)

`ProfileConverter.VisitProfiles(reserveConn, Action<PlayerProfileDto>, predicate: null, nolock: true)`:
- visits all real players (the visitor enumerates internally, Role NOT IN T/M/C) — **no manual temp
  table, no WHERE prefilter** (visit-all; skip-in-code when empty; pond 119 is near-universal so a
  prefilter would not prune and risks false negatives);
- per profile: deserialize `ProfileJson` -> `Profile`, collect the 3-pond fragments, append one JSONL
  line + the CSV rows (streamed, low memory, resumable). **Thread-safe writers required**: `VisitProfiles`
  runs the callback concurrently (`PerformOfflineConvert` thread pool) — lock the file writers or buffer
  per-thread, else lines interleave/corrupt;
- malformed/old `ProfileJson` -> skip + log, never abort;
- on finish: write `.meta.json` + log totals (profiles seen, users with buoys, per-pond buoy totals).

New `ReleaseTool` command `--export-buoys --ponds 119,150,160` — pond IDs are a comma-separated
**option, not hardcoded**, so the tool is reusable for future deprecations (`--import-buoys` takes the
same `--ponds`). The IDs can also be read from the `RemoveDeprecatedBuoys` conversion's
`ParametersJson` to stay in sync. `BuoyBackupRecord` DTO alongside it; reuses `ObjectModel` types.
`--ponds` is parsed to ints and used for **in-code** filtering only — never interpolated into a SQL
predicate (the only thing the predicate carries is the import's `UserId IN (SELECT … FROM <temp>)`).

Output: the file pairs are written into the ReleaseTool (converter) folder. Ops collects them, keeps
them locally, and copies them to the DB server. Retention is ops-side (local + DB server).

## Restore flow (prod DB) — sketch; merge policy deferred

1. ops loads the opt-in subset per the CSV section above: `BULK INSERT` the CSV into a **wide staging
   table** (`UserId, PondId, PondName, MarkerBuoys, NavBuoys, ShareRequests`; index `(PondId, UserId)` for
   pond/user lookup), then build the **UserId-only visitor table** `INSERT INTO dbo.TempBuoyRestore_<yyyyMMdd>(UserId)
   SELECT DISTINCT UserId FROM <staging> WHERE <opt-in>` (index `(UserId)`). The per-pond counts stay on
   staging; `TempBuoyRestore_<yyyyMMdd>` is deduped UserId only (what the visitor predicate references).
2. `--import-buoys` loads the JSONL into `Dictionary<Guid, BuoyBackupRecord>`.
3. `--import-buoys` uses the **load-mutate-save** path (the `ProfileConversionFinalizer.ConvertUser`
   pattern): per opt-in user `LoadPlayerProfile` -> `GetProfileOutOfDto` -> add the backup buoys into the
   LIVE `Profile` (`Buoys.Add(...)` etc.) -> `GetDtoOutOfProfile` -> `SavePlayerProfile`. Drive it via the
   **single-threaded** `ConvertProfiles(prodConn, Action<Guid>, predicate: "AND UserId IN (SELECT UserId FROM TempBuoyRestore_<yyyyMMdd>)")`.
   Do NOT write the backup's `ProfileJson` wholesale — that clobbers everything changed since the backup
   (stats/inventory/balances); only ADD buoys to the current live profile. Single-threaded +
   DISTINCT-UserId table prevents the double-merge race.

**Deferred (design later), but the format already carries what these need:**
- dedup + idempotency + authentic restore in one rule — **never lose a buoy** (the goal is the catch at
  a spot, not the id): a buoy's identity is **(`PondId`, `Position`, `Fish`)** — the marked location and
  the fish caught there (`Position` is `float` X/Y -> compare with tolerance; `Fish` compared by value on
  `FishId` + `Weight` (`decimal` -> exact) + tackle ids, NOT the `[JsonSkip]` `Name`/`Desc`; import must
  load untranslated (`translateProfile: false`) so `TranslateBuoy` doesn't enrich `Fish`; `Name`/`ColorId`
  are mutable, NOT identity; `BuoyId` is secondary). For each backup buoy:
  - if a live buoy with the same (`PondId`, `Position`, `Fish`) exists -> already there, skip (this is the
    dedup + safe-re-run guard; at first restore the removed ponds have no live buoys, so it mostly matters
    on re-runs);
  - else restore it, **best-effort preserving the original `BuoyId`** (`BuoyId` is a profile-local int,
    `AddBuoy` = `Buoys.Max(BuoyId)+1`, not a GUID; collision with a post-removal buoy is uncommon, esp.
    starter pond 119 whose buoys have low ids); if that id is already taken by another live buoy, give the
    restored buoy a fresh id (`max+1`) and log.
  Result: every backup buoy ends up present, none duplicated, ids authentic where free. Do the identity
  check **before** assigning the id. NavBuoys: identity (`PondId`, `Position`) (no fish); share requests:
  (`PondId`, `Position`, `Fish`, `SenderId`);
- `BuoyRecolorCount` / `FreeBuoyRecolorCount` restore — **open edge case, decide later**: the conversion
  zeroed these (key kept). Blindly restoring the old "used" count could re-impose a free-recolor limit the
  player has effectively been re-granted; since this is our error, lean lenient — don't re-charge for
  limits already consumed. Final rule pending edge-case analysis;
- GC re-debit / claw-back — **decision deferred pending scale analysis** (it's our error -> lean lenient).
  Per buoy we store only the recolor **type** — the LAST recolor's `BuoyRecolorPricing` enum (no price
  field); only `Paid` / `PaidPremiumDiscount` are GC-charged (the `Free*` values cost nothing), and only
  the last recolor's type is known, so the recompute is "last-recolor-based" — but that's the SAME basis
  the original refund used, so it nets consistently. The refund priced that type by `BuoyRecolorPriceGc` /
  `BuoyRecolorPricePremiumRatio` with an `(int)` premium truncation. Prices have not changed, but they live
  in the reserve backup's `GlobalVariables` — captured into `.meta.json` at extraction so an exact recompute
  stays possible. Whether to claw back at all depends on how many players were refunded and didn't
  re-place/recolor — analyze the blast radius first; if we do, replicate the `(int)` truncation and clamp
  `GoldCoins` >= 0;
- capacity (`BoughtBuoyCapacity` etc.) is global, was not touched by the conversion -> out of scope.

## Open items
- `--import-buoys` merge identity settled (spot x fish, best-effort id preserve). Deferred for later
  analysis: the recolor-counter restore policy and the GC claw-back (blast-radius + fairness, lean lenient).
- Personal-data note: the only free-text field is the buoy `Name` (player-typed); coordinates are
  gameplay data. The dump stays internal (ops-local + DB server), so likely no special handling —
  flag only if data-retention rules say otherwise.
