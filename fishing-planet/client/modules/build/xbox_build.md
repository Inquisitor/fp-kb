# Xbox (GameCoreXboxOne) build pipeline

How an Xbox client package is produced, where it goes, and how its failures present themselves. Source of truth for the steps is the TeamCity config `XBoxProd.kts`; this document records what the config does not say.

## Pipeline shape

TeamCity configuration `Fishing Planet / Client / XBoxBuilds / XBoxProd`, VCS root `MainClient` (`Unity_Fishing_MainClient`), checkout to `F:\depotTeamCity` on the agent. Ten steps:

| # | Step | What it does |
|---|------|--------------|
| 1 | Cleanup SVN directory except Library | `svn-cleanup.bat` — wipes everything unversioned but keeps Unity's `Library` |
| 2 | ClearResultFolder | recreates `GDK\Xbox` output dir |
| 3 | Create file with SVN revision number | writes `revision.txt` into `StreamingAssets` and the output dir |
| 4 | Replace csc and projectSettings | copies `Artifacts\XBox_GDK\csc.rsp`, `ProjectSettings.asset`, `GameCarrierSettings.asset` over the project's own |
| 5 | Copy AssetBundles | `AssetBundles\GameCoreXboxOne` -> `Assets\StreamingAssets\AssetBundles` |
| 6 | Setup package | patches `ProjectSettings\XboxOneGame.config` — Identity Version and Publisher |
| 7 | Build Client | `Unity.exe -quit -batchmode -buildTarget GameCoreXboxOne -executeMethod BuildScript.XboxOneBuildMaster`, logging to `GDK\Xbox\build.log` |
| 8 | Upload to Nextcloud | PowerShell + curl, WebDAV `PUT` of everything under `GDK\Xbox\Package` |
| 9 | Slack notification | posts build name / revision / version to `#team_city_notification_dev`; skipped when a previous step failed |
| 10 | (print build log) | `RUN_ON_FAILURE` — dumps Unity's `build.log` into the TeamCity log |

Inside step 7 Unity runs: Addressables content build -> scene build -> il2cpp C++ generation -> **Burst AOT native plugin linking** -> il2cpp native compile -> `makepkg` packaging into `.xvc`.

## Versioning

`package.version` (`2.10.2.0`) with its last octet replaced by `build.counter - package.build.counter` (base `101`). Build #219 therefore produces `2.10.2.118`. The same arithmetic feeds the Slack message, which reads `_currentVersion` out of `LaunchInit.cs`. The server domain the client talks to also lives in `LaunchInit.cs` (`_connectionStringDefault`, e.g. `wss://xb_v1_46.fishingplanet.org`) — a domain switch is a client rebuild, not a config change.

## Delivery

- Artifacts: `Symbols`, `GeneratedCpp`, `Loose\Data\Native`, `Loose\Data\Plugins`, `Package\*.zip` -> `Build-<counter>.zip`; Unity log -> `Build-XboxOne-log-<counter>.zip`
- Nextcloud: `https://cloud.fishingplanet.org/remote.php/dav/files/build/TeamCity/Builds/Xbox/Prod/<vcs-revision>/`
- Normal duration is 30-33 min. A run that ends around 24 min did not reach packaging.

## Build agent

Pinned by `requirements { equals("system.agent.name", "BuildClient_NY2") }` — no other agent can take these builds.

- Machine `SERGBUILD`, located in New York. Service `TCBuildAgent` runs as **LocalSystem** — reproducing a build-time failure from an interactive RDP session proves little; re-run the check under SYSTEM (scheduled task with `/ru SYSTEM`).
- **RDP works only at the internal address over the `fp-us-farm` WireGuard tunnel** (routes `10.1.132.0/22`, `10.7.0.0/24`, `10.1.135.0/24`). As of 2026-08-20 the agent is `10.1.134.179`.
- The host does not answer ICMP — a dead ping proves nothing.
- Do not trust DNS for the agent: `*.fishingplanet.com` is a wildcard onto the website, so any invented subdomain resolves and looks real. The agent's true address comes from TeamCity (Agents -> `BuildClient_NY2` -> Agent Summary, or `app/rest/agents/name:BuildClient_NY2`).
- Defender exclusions already in place: `F:\BuildAgent`, `F:\Builds`, `F:\depotTeamCity`, `C:\Program Files\Unity`, `C:\ProgramData\Unity`, GDK, both Unity cache dirs under the SYSTEM profile, and the Burst compiler `bcl.exe`. `C:\ProgramData\Microsoft\VisualStudio` is **not** excluded.

## Failure mode: a failed build reports as success

In MainClient — the branch this configuration builds — `BuildScript.XboxOneBuildMaster` calls `BuildPipeline.BuildPlayer(bpo)` and drops the returned `BuildReport`. `BuildPlayer` does not throw on failure, so Unity exits 0 and **step 7 goes green on a failed build**.

It was fixed upstream on 2026-07-28: CodeBranch r56720 (`serg`, *"fail the Unity build step instead of the next one when BuildPlayer reports failure"*) added `BuildScriptBase.ExitOnBuildFailure` and wired it into both Xbox methods, both Scarlett methods, UWP, GDK PC and the PS4 SCEA / SCEE-master builds. **The helper does not exist in MainClient** — ten occurrences in CodeBranch, zero in MainClient — and merge direction runs Content -> Code, so it reaches the shipping branch only with the next CodeBranch -> MainClient release merge. Until that lands, every console build configuration keeps the old behaviour.

What the operator sees instead: step 8 fails with `Source folder not found: F:\Builds\GDK\Xbox\Package`, naming Nextcloud — a subsystem that is working perfectly. Worse, `Build-<counter>.zip` is still published (~300 MB of symbols and generated C++) and looks like a real build while containing no package.

That alarm is accidental, not a check: step 2 wipes `GDK\Xbox`, so a missing package happens to trip the upload step. A failure occurring *after* packaging, or one producing a partial package, passes every gate — the upload succeeds, step 9 posts `Build load success` with revision and version, and the `buildFailed` notification never fires. **This hole survives the merge**; closing it needs a CI-side check that the expected artifact exists.

**Diagnosis order for any red Xbox build:** read the Unity log first (step 10 prints it into the TeamCity log; the artifact `Build-XboxOne-log-<counter>.zip` holds the same). Search for `Build Finished, Result: Failure.` and for the failing Bee node — the step-8 message tells you nothing about the real cause.

## Failure mode: Burst AOT toolchain lookup (transient, seen once)

Build #218 (2026-08-19, revision 56864) died in `PostprocessBuildPlayer` with:

```
Library\Bee\artifacts\GameCorePlayerBuildProgram\AsyncPluginsFromLinker:
Burst internal compiler error: Burst.Compiler.IL.Aot.AotLinkerException:
Burst requires Visual Studio ... in order to build a standalone player for GameCoreXboxOne with AVX
Failed to determine visual studio installation path - is Visual Studio installed?
((-2147023485 - False - Error 0x80070583: Class does not exist.))
```

Burst locates MSVC through the VS Setup Configuration COM API — since VS2017 there is no registry path to fall back on, so a failed lookup makes an installed toolchain invisible. Everything downstream (il2cpp native compile, `makepkg`) needs that toolchain too, so disabling Burst would not have produced a package.

Investigation found the machine healthy **after** the fact: COM class instantiates under both the interactive user and SYSTEM, `vswhere` lists VS 2022 17.12.4 and VS 2026 18.7.3, x86 and x64 registrations both present, GDK and Windows SDKs installed, no MSI activity and no OS updates in the preceding weeks. Neither the code (the two revisions since the last green build only bumped platform versions and the server domain) nor the environment (machine booted 2026-07-28, four green builds after VS 2026 was installed on 2026-07-14) explained it. **A plain re-run — build #219, same revision, nothing changed — produced the package.**

Treat a single occurrence as transient: re-run first, investigate only on repeat. If it does repeat, the untested candidate is the Defender exclusion for `C:\ProgramData\Microsoft\VisualStudio`, which holds `Setup\{x86,x64}\Microsoft.VisualStudio.Setup.Configuration.Native.dll` — the very library the lookup loads. The presence of `bcl.exe` in the exclusion list suggests someone fought Burst on this machine before, so the excluded process was protected while the DLL it loads was not.
