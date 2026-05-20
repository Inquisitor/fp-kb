---
name: Photon.Interfaces DLL distribution to client
description: Server-built Photon.Interfaces.dll is copied to client via Refresh.cmd; ObjectModel is source-duplicated with sensitive code stripped
type: reference
---

# Cross-repo shared code: Server → Client

## `Photon.Interfaces` — DLL distribution

- Source of truth: `Shared/Photon.Interfaces/` (server SVN, in the Code-role branch).
- Build artifact: `Shared/Photon.Interfaces/bin/Release/Photon.Interfaces.dll`.
- Distribution: run `Shared/Photon.Interfaces/Refresh.cmd` from VS tools after a Release build. The script:
  ```cmd
  copy /y %SvnServer%\Shared\Photon.Interfaces\bin\Release\Photon.Interfaces.dll
          %SvnClient%\Assets\Plugins\PhotonServer\Photon.Interfaces.dll
  ```
  `%SvnServer%` / `%SvnClient%` are env vars pointing at the local working copies.
- Client commit: the copied DLL is committed to the client SVN (`Win64_CodeBranch` for the Code-role).
- Consequence: changes to enums under `Photon.Interfaces` (operation codes, parameter codes, error codes, etc.)
  propagate to the client by replacing the DLL — no parallel client-side enum copy to keep in sync.

## `ObjectModel` — source duplication

- `Shared/ObjectModel/` is **not** distributed as a DLL.
- The source is copied into `Assets/Photon Server Networking/ObjectModel/` in the client tree, with sensitive
  pieces (anti-cheat checks etc.) stripped or omitted.
- Combinatorial / non-sensitive logic (e.g. `Inventory.CanMove`, slot constraints, combine resolution) is
  expected to stay symmetric between server and client — when adding such logic, mirror it manually into the
  client source copy.
- Server-only logic (action handlers, persistence, anti-cheat) lives only on the server and has no mirror.

## IL2CPP managed stripping -- reflection-only members

UnityLinker (Conservative ruleset, the project default for Standalone IL2CPP -- `managedStrippingLevel: 1`
in `ProjectSettings.asset`) strips members that have no statically resolvable call-site. Public
ctors/methods/fields reached only through reflection are removed. The typical runtime symptom is
`JsonSerializationException: Unable to find a default constructor` (Newtonsoft.Json hitting a stripped
parameterless ctor) or `MissingMethodException` (Activator.CreateInstance, similar). Editor (Mono) does
no stripping -- Editor smoke tests cannot catch this class of regression.

Two preserve strategies coexist in this codebase, chosen by distribution mechanism, not by taste:

- **Source-copy types in `ObjectModel/`** (Radar, Leaderboards, etc.) use `[JsonConstructor]` on a
  parameterized ctor (immutable DTO pattern -- no default ctor at all). Works because the source-copied
  files reach the client as user code with `Newtonsoft.Json` already on the reference graph; the
  parameterized ctor is statically reachable from Newtonsoft's serializer infrastructure, which keeps it.
- **Shared-DLL types in `Photon.Interfaces/`** use a local `[Preserve]`-by-name attribute (an internal
  `PreserveAttribute` declared in the same assembly). UnityLinker matches the attribute by short type
  name regardless of namespace, so the assembly can guard reflection-only members without depending on
  `UnityEngine` or `Newtonsoft.Json`. Same trick is used by `Newtonsoft.Json.Utilities.PreserveAttribute`.

Apply only when a member is reached **solely** through reflection. If at least one static `new T(...)`
exists anywhere in client code, the linker's reachability graph already keeps the ctor and the
annotation is noise. Do not pre-emptively decorate types "just in case" -- the rule is evidence-based.

## When making a change

1. Edit in the server SVN (Code-role branch).
2. If the change is in `Photon.Interfaces` — Release-build, run `Refresh.cmd`, commit the DLL to client SVN.
3. If the change is in `ObjectModel` and is non-sensitive shared behavior — mirror the source edit into the
   client's `ObjectModel` copy and commit to client SVN.
4. Other client-side code (Photon networking adapters, UI, etc.) lives only in the client SVN and is edited
   there directly.
