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

## Artifacts: one set per pond, per stream

Streams are separate DBs (Steam/PS/XB/MOB/NX); UserIds are per-stream. A single `--export-buoys` run
makes ONE pass over the stream's DB and writes **one set per pond** — ponds differ in value (some pure
historical backup, some may be restored immediately), so each is a self-contained, independently-
restorable set; adding another pond later yields a homogeneous set. Per pond:
`buoys_<stream>_<PondName>_<date>.{jsonl,csv,meta.json}`.

### 1) JSONL payload — `buoys_<stream>_<PondName>_<date>.jsonl`
One line per player that has any buoy on **that pond**; arrays/dicts serialized with
`SerializationHelper.JsonSkipInventorySerializerSettings` — the same settings the live profile writer
uses in `GetDtoOutOfProfile`, so the dump matches the on-disk shape and drops straight back into
`Profile.*` on restore. (Plain `JsonSerializerSettings` also round-trips but emits `BuoySetting` noise:
`Update`/`Tracking` have no `[JsonIgnore]` on the class; the skip resolver drops them.)
```json
{"UserId":"<guid>","Buoys":[{…BuoySetting…}],"NavBuoys":[{…}],"BuoyShareRequests":[{…}],"BuoyRecolorCount":{"119":2},"FreeBuoyRecolorCount":{"119":1}}
```
Fragments filtered to the file's single pond; recolor dicts filtered to that key. Players with nothing
on that pond are skipped (no line). Per-pond sidecar `buoys_<stream>_<PondName>_<date>.meta.json`:
stream, `pondId`, `pondName`, extracted-UTC, source server, schema version, totals (users, marker buoys),
and the buoy-recolor prices (`BuoyRecolorPriceGc` / `BuoyRecolorPricePremiumRatio`) read from the backup's
`GlobalVariables` (or code defaults `2` / `0.5` if no explicit row — so a faithful GC recompute stays
possible). The meta is written last, only on success → its absence = that pond's run is incomplete.

### 2) CSV index — `buoys_<stream>_<PondName>_<date>.csv`
The pond's index — one row per user on that pond; human-readable + the source for the import temp table:
```
UserId,PondId,PondName,MarkerBuoys,NavBuoys,ShareRequests
3fa8…,119,LoneStar,4,1,0
9bc1…,119,LoneStar,2,0,1
```
- `PondName` from `SharedConsts` for readability; `PondId` stays for machine use.
- counts let support say "you had N buoys on Lone Star" and let ops pick opt-in by threshold.
- one row per user (per-pond file) -> `UserId` is unique within the file (no dedup needed at import).

## Extraction flow (reserve DB, read-only)

`ProfileConverter.VisitProfiles(reserveConn, Action<PlayerProfileDto>, predicate: null, nolock: true)`:
- visits all real players (the visitor enumerates internally, Role NOT IN T/M/C) — **no manual temp
  table, no WHERE prefilter** (visit-all; skip-in-code when empty; pond 119 is near-universal so a
  prefilter would not prune and risks false negatives);
- per profile: deserialize `ProfileJson` -> `Profile`; for each requested pond, extract that pond's
  fragment and append the user's line to **that pond's** JSONL + CSV (streamed, low memory). **Thread-safe
  writers required**: `VisitProfiles` runs the callback concurrently (`PerformOfflineConvert` thread pool)
  — lock the per-pond writers, else lines interleave/corrupt;
- malformed/old `ProfileJson` -> skip + log, never abort;
- on finish: write each pond's `.meta.json` last (completion marker) + log per-pond totals.

New `ReleaseTool` command `--export-buoys --ponds 119,150,160` — pond IDs are a comma-separated
**option, not hardcoded**, so the tool is reusable for future deprecations (`--import-buoys` takes the
same `--ponds`). The IDs can also be read from the `RemoveDeprecatedBuoys` conversion's
`ParametersJson` to stay in sync. `BuoyBackupRecord` DTO alongside it; reuses `ObjectModel` types.
`--ponds` is parsed to ints and used for **in-code** filtering only — never interpolated into a SQL
predicate (the only thing the predicate carries is the import's `UserId IN (SELECT … FROM <temp>)`).

Output: the per-pond file sets are written into the ReleaseTool (converter) folder. Ops collects them,
keeps them locally, and copies them to the DB server. Retention is ops-side (local + DB server).

## Restore flow (prod DB) — sketch; LOWER PRIORITY than the backup, merge policy deferred

> Priority: the **backup (`--export-buoys`) is the active, high-priority piece** — get the data off the
> reserve server while it exists. Restore (`--import-buoys`) is intentionally a sketch and lower priority.

Restore is **per pond** (matching the per-pond files):
1. ops `BULK INSERT`s the opt-in subset of that pond's CSV into
   `dbo.TempBuoyRestore_<PondName>_<date>(UserId, MarkerBuoys, NavBuoys, ShareRequests)` — already one row
   per user, no DISTINCT needed; index `(UserId)`.
2. `--import-buoys` loads **that pond's** JSONL into `Dictionary<Guid, BuoyBackupRecord>`.
3. `--import-buoys` uses the **load-mutate-save** path (the `ProfileConversionFinalizer.ConvertUser`
   pattern): per opt-in user `LoadPlayerProfile` -> `GetProfileOutOfDto` -> add the backup buoys into the
   LIVE `Profile` (`Buoys.Add(...)` etc.) -> `GetDtoOutOfProfile` -> `SavePlayerProfile`. Drive it via the
   **single-threaded** `ConvertProfiles(prodConn, Action<Guid>, predicate: "AND UserId IN (SELECT UserId FROM TempBuoyRestore_<PondName>_<date>)")`.
   Do NOT write the backup's `ProfileJson` wholesale — that clobbers everything changed since the backup
   (stats/inventory/balances); only ADD buoys to the current live profile. Single-threaded + the
   unique-UserId per-pond table prevents the double-merge race.

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
