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

## When making a change

1. Edit in the server SVN (Code-role branch).
2. If the change is in `Photon.Interfaces` — Release-build, run `Refresh.cmd`, commit the DLL to client SVN.
3. If the change is in `ObjectModel` and is non-sensitive shared behavior — mirror the source edit into the
   client's `ObjectModel` copy and commit to client SVN.
4. Other client-side code (Photon networking adapters, UI, etc.) lives only in the client SVN and is edited
   there directly.
