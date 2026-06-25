# Club-transfer Log Retention Incident — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve surviving club-transfer log records, stop the 60-day cleaner from deleting them without a game-server release, and make future transfer records permanently survive.

**Architecture:** Three independent, ordered workstreams — (A) `mongodump` backup of `clubLog`, (B) zero-deploy retro-mark `IsImportant=true` on transfer rows so the cleaner skips them, (C) SharedLib code change so future transfer logs are born important. A and B are prod operations the user runs; C is a code change.

**Tech Stack:** MongoDB 4.4 (`mongodump`, `updateMany`), C# 9 / .NET Framework 4.7.2 (SharedLib), MSTest.

## Global Constraints

- Spec: `artifacts/retention-incident-design.md`. Transfer-line scope regex (used verbatim in B and as the set of sites in C): `^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Sent buoy |Accepted .* on pond .* for request ')`
- `.cs` files: UTF-8 **with BOM**, **CRLF** line endings (repo `.editorconfig`). Convert LF→CRLF after any Write/Edit.
- Cannot build from CLI in this environment — the **user builds**; `dotnet test --no-build` works on already-built projects.
- Prod DB ops (A, B): the **user runs** them (DataGrip/prod handoff). Mongo, so no `WITH (NOLOCK)`. Run **before the daily 01:01 cleaner**.
- Platforms: F2P only — Steam/EGS, PlayStation, Xbox, Mobile, Nintendo (Retail excluded). DataGrip Mongo connections `[F2P] <PLATFORM> PROD Mongo`; logs DB on PROD is **`main2`** (NOT `main` — `main` is empty on prod; `main` is only the local-dev name), collection `clubLog`.
- Commit messages (SVN, workstream C): `FP-44478:` prefix per repo convention; output the message text, do not run `svn`.

---

### Task A: Backup `clubLog` on all five F2P prod Mongo

**Files:**
- Produce (off-repo, cold storage): `clubLog-<platform>-2026-06-25.bson` (+ `.metadata.json`) per platform.

**Owner:** user (prod). Run AFTER Task B and after B's verify gate (Step 4 == 0) passes, before 01:01 — the dump then captures the already-marked state.

- [ ] **Step 1: Record the pre-dump transfer count per platform** (baseline for later verification)

In each `[F2P] <PLATFORM> PROD Mongo`, DB `main`:
```js
db.clubLog.countDocuments({ Message: /^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Sent buoy |Accepted .* on pond .* for request ')/ })
```
Record the number per platform.

- [ ] **Step 2: Dump the full `clubLog` collection per platform**

For each platform (substitute the platform's prod Mongo connection string):
```bash
mongodump --uri "<PLATFORM prod mongo connection string>" --db main2 --collection clubLog \
  --out ./fp44478-clublog-backup-2026-06-25/<platform>
```
BSON preserves `_id` (ObjectId → embedded insert timestamp) and every field verbatim.

- [ ] **Step 3: Verify the dump row count matches the live collection**

```js
db.clubLog.countDocuments({})   // live, at dump time
```
Compare against the dumped document count:
```bash
mongorestore --dryRun --uri "<...>" ./fp44478-clublog-backup-2026-06-25/<platform> 2>&1 | grep clubLog
# or: bsondump ./.../clubLog.bson | wc -l
```
Expected: dump count ≈ live count (small drift from concurrent inserts is fine). Store the dumps in cold storage off the live DB.

---

### Task B: Retro-mark transfer rows `IsImportant=true` (stop the bleeding, zero-deploy)

**Files:**
- Create: `artifacts/retro-mark-important.js` (the per-platform ops query, reusable for re-runs).

**Owner:** user (prod write). Run FIRST — before the backup and before 01:01 — so live transfer rows are protected immediately. Verify (Step 4 == 0) before running Task A.

- [ ] **Step 1: Create the ops query file**

Create `artifacts/retro-mark-important.js`:
```js
// FP-44478 - retro-mark club transfer lines IsImportant=true so DeleteOldMessages() skips them.
// Run per F2P prod Mongo (Steam/EGS, PS, Xbox, Mobile, Nintendo), DB main. Prod WRITE.
// Re-run before the newest unprotected transfer rows age past 60 days, until the code fix (Task C) ships.

const transferRegex = /^(Sent bait #|Received bait #|Sent ClubToken |Received ClubToken |Sent buoy |Accepted .* on pond .* for request ')/;

// 1) before: how many transfer rows are still unprotected
db.clubLog.countDocuments({ Message: transferRegex, IsImportant: { $ne: true } })

// 2) protect them
db.clubLog.updateMany({ Message: transferRegex, IsImportant: { $ne: true } }, { $set: { IsImportant: true } })

// 3) after: must be 0 unprotected transfer rows
db.clubLog.countDocuments({ Message: transferRegex, IsImportant: { $ne: true } })
```

- [ ] **Step 2: Run step (1) — record the unprotected transfer count per platform**

Expected: equals (or close to) the Task A Step 1 baseline (minus any rows already marked important — there should be none yet).

- [ ] **Step 3: Run step (2) — the `updateMany`**

Expected: `matchedCount` == the step-1 count, `modifiedCount` == same. `_id` and all other fields untouched.

- [ ] **Step 4: Run step (3) — verify zero unprotected transfer rows remain**

Expected: `0` on every platform. The daily 01:01 cleaner now skips these rows.

---

### Task C: Mark future transfer logs important in code (permanent fix)

**Files:**
- Modify: `Shared/SharedLib.Tests/Clubs/TestClubLog.cs` (capture entries for assertion)
- Test: `Shared/SharedLib.Tests/Clubs/ClubAdapterTests_BaitsBuoysFishing.cs` (new test)
- Modify: `Shared/SharedLib/Clubs/ClubAdapter_ClubTokens.cs` (2 call sites)
- Modify: `Shared/SharedLib/Clubs/ClubAdapter_BaitsBuoysFishing.cs` (4 call sites)

**Interfaces:**
- Consumes: existing test helpers in `ClubAdapterTests` — `BuildProfile`, `CreateClubAdapter`, `BuildClub`, `RequestBait`, `SendBait`, `___ReceiveClubEvent`, `FindClubEvent`; `ClubAdapter.UserLog(string message, bool isImportant = false)`.
- Produces: `TestClubLog.Captured` (`static List<(string Message, bool IsImportant)>`) for tests to assert log importance.

**Owner:** dev change; user builds + a normal server release.

- [ ] **Step 1: Add a capture list to the test logger**

In `Shared/SharedLib.Tests/Clubs/TestClubLog.cs`, replace the `Log(string, int, string, bool)` method and add a static capture list:
```csharp
public static readonly List<(string Message, bool IsImportant)> Captured = new();

public void Log(string userId, int clubId, string message, bool isImportant)
{
    Captured.Add((message, isImportant));
    Log(userId, $"{clubId}: {message}{(isImportant ? " !!!IMPORTANT!!!" : "")}");
}
```
(Keep the existing `LogAsync` and `GetAllClubMessages`.)

- [ ] **Step 2: Write the failing test**

In `Shared/SharedLib.Tests/Clubs/ClubAdapterTests_BaitsBuoysFishing.cs`, add:
```csharp
[TestMethod]
public void ReceiveBait_marks_clublog_entry_important()
{
    DBSetup();
    ItemCache.InitDefault();
    TestClubLog.Captured.Clear();

    OProfile president = BuildProfile(_userUt);
    ClubAdapter presidentAdapter = CreateClubAdapter(president);
    OProfile friend = BuildProfile(_userUt1, level: 10);
    ClubAdapter friendAdapter = CreateClubAdapter(friend);

    Club club = BuildClub();
    presidentAdapter.CreateClub(club);
    friendAdapter.JoinClub(club.ClubId);

    var item = ItemCache.Instance.Cache.GetClubItems().First();
    presidentAdapter.RequestBait(item.ItemId);
    var request = FindClubEvent(ClubEventType.BaitRequest);

    friendAdapter.___ReceiveClubEvent(request);
    var friendItem = ItemCache.Instance.Cache.GetItem(item.ItemId);
    friendItem.Storage = StoragePlaces.Equipment;
    friendItem.Count = 10;
    friend.Inventory.AddItem(friendItem);
    friendAdapter.SendBait(request.InstanceId);

    var response = FindClubEvent(ClubEventType.BaitResponse);
    presidentAdapter.___ReceiveClubEvent(response);

    var received = TestClubLog.Captured.Single(e => e.Message.Contains("Received bait #"));
    Assert.IsTrue(received.IsImportant, "Received-bait club log must be marked important so the 60-day cleaner keeps it");
}
```

- [ ] **Step 3: Run the test — verify it FAILS**

Run (after the user builds, or build then `--no-build`):
```
dotnet test --no-build --filter "FullyQualifiedName~ReceiveBait_marks_clublog_entry_important" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```
Expected: FAIL — `received.IsImportant` is `false` (current code logs unimportant).

- [ ] **Step 4: Mark the token transfer logs important**

In `Shared/SharedLib/Clubs/ClubAdapter_ClubTokens.cs`:
- `UserLog($"Sent ClubToken {count} for request '{requestId}'");` → `UserLog($"Sent ClubToken {count} for request '{requestId}'", isImportant: true);`
- `UserLog($"Received ClubToken count {count} for request '{requestId}' from {ev.FromName} '{ev.From}'");` → append `, isImportant: true` before `);`

- [ ] **Step 5: Mark the bait and buoy transfer logs important**

In `Shared/SharedLib/Clubs/ClubAdapter_BaitsBuoysFishing.cs`:
- `UserLog($"Sent bait #{itemId} count {count} for request '{requestId}'");` → add `, isImportant: true`
- `UserLog($"Received bait #{itemId} count {count} for request '{requestId}' from {ev.FromName} '{ev.From}'");` → add `, isImportant: true`
- `UserLog($"Sent buoy [{string.Join(",", ev.FishIds)}] on pond {ev.PondId} for request '{requestId}'");` → add `, isImportant: true`
- the buoy-accept `UserLog(logMessage);` (the `Accepted {buoy} … on pond … for request …` line) → `UserLog(logMessage, isImportant: true);`

- [ ] **Step 6: Run the test — verify it PASSES**

Run (after rebuild):
```
dotnet test --no-build --filter "FullyQualifiedName~ReceiveBait_marks_clublog_entry_important" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```
Expected: PASS.

- [ ] **Step 7: Run the existing club transfer tests — verify no regression**

```
dotnet test --no-build --filter "FullyQualifiedName~ClubAdapterTests" Shared/SharedLib.Tests/SharedLib.Tests.csproj
```
Expected: all pass (e.g. `Test_SendBait_Ok`).

- [ ] **Step 8: Normalize line endings (LF→CRLF) and confirm BOM on the 3 edited `.cs` files**

The edited files must keep UTF-8 BOM + CRLF per `.editorconfig`. Convert any LF introduced by the edit tool.

- [ ] **Step 9: Commit (output the message; do not run svn)**

```
FP-44478: [ClubLog] Mark club item/token transfers as important so they survive the 60-day log cleaner
= Pass isImportant: true on Sent/Received bait, Sent/Received ClubToken, Sent/Accepted buoy UserLog calls
+ Capture log entries in TestClubLog and assert ReceiveBait marks the club log important
```

---

## Verification (whole incident)

- A: per-platform `clubLog` dump exists in cold storage; dump count ≈ live count.
- B: `countDocuments({ Message: <transferRegex>, IsImportant: { $ne: true } })` == 0 on every platform.
- C: new test passes; existing club tests green; after release, a fresh donation writes a `clubLog` row with `IsImportant: true` (spot-check) that survives a `-clear-logs` dry run on a non-prod env.

## Notes

- B protects only rows that exist now (≤60 days). Until C ships, **re-run B** before the newest unprotected rows age past 60 days.
- `chatLog` 60-day deletion is out of scope (unrelated to transfers); not touched.
