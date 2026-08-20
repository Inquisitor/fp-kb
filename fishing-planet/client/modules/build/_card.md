---
module: build
---

# Build

Editor-side build entry points and the TeamCity configurations that drive them. One module for all client platforms; per-platform pipelines go to deep dives.

## Entry Points
- `BuildScript` — `Assets/Editor/BuildScript.cs` — per-platform static methods invoked by TeamCity through `Unity.exe -executeMethod` (`XboxOneBuildMaster`, `ScarlettBuildMaster`, `PerformPS4SCEABuildMaster`, `BuildSteam`, `BuildNintendoRelease`, `BuildEpic`, `BuildUWPMaster`)
- `BuildScriptBase` — `Assets/Editor/BuildScriptBase.cs` — Addressables prep/restore (`BuildAddressables`, `RestoreAddressablesBuildSettings`), scene set selection (`GetScenesForBuild`)
- `AndroidBuildScript` — `Assets/Editor/AndroidBuildScript.cs` — Android builds
- TeamCity project `Fishing Planet / Client / <Platform>Builds` — one Kotlin DSL config per build configuration (e.g. `XBoxProd.kts`)

## Key Types
| Type | Role |
|------|------|
| `BuildPlayerOptions` | scenes + target + output path handed to `BuildPipeline.BuildPlayer` |
| `BuildReport` | Unity's build outcome; fed to `BuildScriptBase.ExitOnBuildFailure` in CodeBranch — **the helper does not exist in MainClient**, which is what the console configs build |
| `GameCoreXboxOneSettings` | Xbox subtarget (Development/Master), deploy method, package encryption |

## Dependencies
- → Addressables (content built before the player); platform SDKs from `Artifacts/<Platform>/SDKs`; Microsoft GDK (Xbox); Burst AOT + MSVC toolchain for native plugin linking
- ← TeamCity build configurations — they invoke the methods, publish artifacts, upload to Nextcloud, notify Slack
- ~ `ProjectSettings.asset`, `csc.rsp`, `GameCarrierSettings.asset` — swapped per platform from `Artifacts/<Platform>/` before the build runs

## Deep Dives
- [xbox_build.md](xbox_build.md) — Xbox (GameCoreXboxOne) pipeline: TeamCity steps, versioning, agent access, failure modes

## Related Tasks
- Relates: FP-41648 (GitLab CD — buildmachine scripts revision; active, carries no description)
