---
status: completed
executor: Stanislav Samoilov
jira: https://fishingplanet.atlassian.net/browse/FP-43837
related:
  - FP-43547  # parent feature: batch MoveItems server-side (shipped r16093, introduced MoveResults)
  - FP-43819  # JIRA parent of the bug ticket
---

# FP-43837: Inventory batch "Move to" UI does not refresh -- MoveResults deserialization fails on Steam build

## Status

Completed. Server r16108 on MFT (PreserveAttribute.cs + [Preserve] on MoveResults default ctor), client
r54392 on CodeBranch (Photon.Interfaces.dll refresh). Smoke on a locally built IL2CPP client passed before
commit. JIRA comment 120610 posted with @-mention to Kyrylo Rovnyi for downstream Content-client merge.
Plan items 1-5 done; item 6 (Content-branch merge) is owned by the client lead and tracked outside this
task.

## Summary

### Symptom

Inventory -> Backpack -> select category -> "Move to" -> confirm. On the Steam build (Code-client 6.0.11/54204
against `yellowtest`/16097), items keep displaying on the source tab until the user switches tabs and comes
back. QA filed `Записування з екрана 2026-05-18 174911.mp4` showing the regression.

A `UserError` log line in the client reports `JsonSerializationException: Unable to find a default constructor
to use for type Photon.Interfaces.Inventory.MoveResults` at
`PhotonServerConnection.HandleInventoryOperationResponse:51` -- the response is delivered but
`GetParameterJsonCompressed<MoveResults>` throws, so `OnInventoryMoveBatchResult` never fires. The visual
state stays stale because the per-tab refresh hangs off that event.

### Root cause

Standalone Steam build = IL2CPP + `managedStrippingLevel = 1` (Low / Conservative). UnityLinker's reachability
graph sees `new MoveResults(items.Count)` statically (server-mirrored client code in
`Assets/Photon Server Networking/ObjectModel/Inventory/Inventory.cs`) and keeps the `(int)` ctor. The
parameterless `MoveResults()` ctor is never called statically -- Newtonsoft.Json only reaches it via
reflection on deserialization -- so the linker strips it from `GameAssembly.dll`.

Editor smoke during FP-43547 development passed because the Editor runs on Mono with no managed stripping;
both ctors stayed reachable through plain reflection. The stripped form only appears in IL2CPP outputs.

### Reproduction

1. **Editor simulation** (instant, no Steam build): comment out `public MoveResults() { }` in
   `Shared/Photon.Interfaces/Inventory/MoveResults.cs`, rebuild Photon.Interfaces, copy DLL to client
   `Assets/Plugins/PhotonServer/Photon.Interfaces.dll`, run STR in Editor -> same stack trace as
   `yellowtest`, identical down to `CreateNewDictionary` -> `GetParameterJsonCompressed[T]` ->
   `HandleInventoryOperationResponse:51` frames.

2. **UnityLinker dry-run** (no Editor, no Steam build):
   - Minimal Root.dll that statically calls only `new MoveResults(5)`
   - Run `UnityLinker.exe --rule-set=Conservative --dotnetprofile=unityaot-win32 --dotnetruntime=il2cpp
     --platform=WindowsDesktop --architecture=x64` against the real `Photon.Interfaces.dll`
   - Result: output DLL shrinks 75264 -> 7168 bytes, `MoveResults` retains only `.ctor(int)`; the
     parameterless ctor is physically absent.

Together: (1) shows the stack trace is the exact failure mode; (2) shows the linker really deletes the ctor
on the project's actual stripping setting. The previously suspected "DLL wasn't copied to client" hypothesis
was falsified (`svn status` clean; client DLL matches the SVN-committed Release build) -- the bug exists in
the build pipeline, not in distribution.

### Fix

Local `[Preserve]`-by-name attribute in `Photon.Interfaces`. UnityLinker matches `PreserveAttribute` by class
short name regardless of namespace, so the server assembly does not need to depend on `UnityEngine`. Same
trick is used by `Newtonsoft.Json.Utilities.PreserveAttribute` for the same reason.

Changes:

- `Shared/Photon.Interfaces/PreserveAttribute.cs` (new): `internal sealed class PreserveAttribute :
  Attribute` with `[AttributeUsage(AttributeTargets.All, Inherited = false)]`.
- `Shared/Photon.Interfaces/Inventory/MoveResults.cs`: `[Preserve]` on the parameterless ctor.

Verified on the same UnityLinker setup: after applying the fix, the parameterless ctor survives Conservative
stripping (the `.ctor(int)` survival is unchanged).

### Alternatives considered

- `[JsonConstructor]` on `MoveResults(int capacity)`: would tell Newtonsoft to skip the default-ctor path
  entirely. Rejected because it makes `Photon.Interfaces` depend on Newtonsoft.Json -- `Photon.Interfaces` is
  the base contracts assembly that every project pulls in; tying it to a JSON library is wrong direction.
- `link.xml` shipped in the client tree: would add a Unity-build-pipeline coupling and one more file to keep
  in sync with each platform's stripping config. Rejected.
- Replace `MoveResults : Dictionary<,>` with a wrapper that holds a public `Dictionary` field: linker can't
  strip the BCL `Dictionary<,>` ctor. Architecturally cleanest but defeats the explicit decision in
  `MoveResults.cs` to use a named subclass (avoids `$type` metadata under `TypeNameHandling.Auto`). Kept as
  an "if `[Preserve]` ever fails us" fallback.

## Plan

1. **Done** -- Diagnose: stack trace + UnityLinker dry-run reproduction.
2. **Done** -- Apply server-side fix in MFT (PreserveAttribute.cs + MoveResults.cs).
3. **Done** -- Build `Photon.Interfaces` Release in MFT; refresh client DLL; smoke on a local IL2CPP build.
4. **Done** -- Commit: MFT r16108, CodeBranch r54392.
5. **Done** -- JIRA comment 120610 posted with commit IDs, root cause, and Kyrylo Rovnyi @-mention.
6. **Handed off** -- DLL merge into Content client branch (MainClient) requested from client lead via JIRA
   comment 120610; tracked outside this task.

## Milestones

- 2026-05-20: Bug picked up from Sergii Karchavets's comment on FP-43837 with the runtime stack trace.
  Initial guess "stale DLL not copied to client" falsified -- `svn status` clean on client plugin, both
  current Release-built `Photon.Interfaces.dll` in MFT (76288 b, r16099 build) and the SVN-committed client
  copy (75264 b) contain both ctors of `MoveResults`.
- 2026-05-20: Diagnosed IL2CPP managed-stripping pitfall via two independent reproductions: (a) Editor
  simulation by commenting out the default ctor, (b) UnityLinker.exe dry-run with the real client DLL under
  Conservative ruleset matching the project's `managedStrippingLevel: 1` for Standalone. Both paths
  reproduce the exact JIRA stack trace / deletion behavior.
- 2026-05-20: Applied fix in MFT (PreserveAttribute.cs + `[Preserve]` on `MoveResults()`). Verified the
  rebuilt DLL through the same UnityLinker dry-run -- default ctor now survives Conservative stripping
  alongside the parameterized one.
- 2026-05-20: Audit -- enumerated instantiable types in `Photon.Interfaces` via PE inspect of the built
  DLL (not just grep, which had missed `static class` and `struct`). The complete set is exactly four
  classes: `AndroidAuthParameters` (client instantiates directly in `PhotonServerConnection.cs:579`),
  `UnityDebugSubject` (client has 10+ static `new UnityDebugSubject(...)` call-sites in `DebugUtility.cs`),
  `UserLib` (not referenced anywhere on the client -- linker drops the whole type, no deserialization risk),
  and `MoveResults`. The first three each have at least one statically-resolvable instantiation in client
  code, which keeps their ctors reachable. `MoveResults` is the only one without any static `new
  MoveResults()` call -- the client receives it solely via Newtonsoft deserialization on the wire. That is
  what makes it uniquely vulnerable.
- 2026-05-20: Cross-checked existing project conventions for reflection-deserialized types. Source-copy
  types under `Assets/Photon Server Networking/ObjectModel/` (Radar, Leaderboards) consistently use
  `[JsonConstructor]` on a parameterized ctor (immutable DTO pattern, no default ctor at all) -- e.g.
  `FishRadarDataChangeSet`, `LeaderboardPeriod`. They can do this because the source-copied files reach
  the client as user code with Newtonsoft.Json already on the reference graph. Shared-DLL types in
  `Photon.Interfaces/` cannot take the same path without dragging Newtonsoft.Json into the base contracts
  assembly, which we deliberately keep minimal. The `[Preserve]`-by-name approach taken here is the
  parallel solution for the shared-DLL side: same goal (survive managed stripping for reflection-only
  access), different mechanism, zero new dependencies.
- 2026-05-20: Shipped. MFT r16108 (PreserveAttribute.cs + [Preserve] on MoveResults default ctor) and
  CodeBranch r54392 (Photon.Interfaces.dll refresh). Local IL2CPP client smoke confirmed the original
  repro STR no longer throws and items refresh immediately on Move-to confirmation. JIRA comment 120610
  posted (root cause + commit IDs + @-mention to Kyrylo Rovnyi for Content client merge). Task remains
  open pending the Content-branch merge.
