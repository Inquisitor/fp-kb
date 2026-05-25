---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16058; CodeBranch @ r53670, r53676
jira: https://fishingplanet.atlassian.net/browse/FP-43535
---

# FP-43535: FTUE. New Tutorial. Server — Spawn point coordinates are incorrect after reload

## Summary

New Level-1 player who untracks the tutorial mission, restarts the client, and presses "Go Fishing" materialises underwater at `(0, 0, 0)`. Bad position is then persisted server-side on the next save, overwriting the correct one.

Root cause (per author note): two unrelated client-side gates were historically used for the "auto-spawn directly to 3D, skip local-map UI" decision — `StaticUserData.IS_MISSION_TUTORIAL` (mission-data-aware) and `PondHelper.TutorLoading == Profile.Level == 1` (proxy, fires before mission data is loaded). For an untracked Level-1 player the proxy is true but the mission check is false — sites of the first kind routed into 3D via `MoveToRoom`, sites of the second kind skipped the positioning step, the player landed at scene-default zero.

Fix: server-owned `PersistentData.IsIn3D` boolean. Set on profile creation together with `Position`/`Rotation` from `GlobalVariablesCache.TutorialInitialSpawnPoint`; cleared on first successful pond arrival. Client gates every "auto-spawn to 3D" decision via the new derived flag `StaticUserData.SHOULD_BE_SPAWNED_TO_3D`. Old client-side gates (`PondHelper.TutorLoading`, `IS_MISSION_TUTORIAL` at spawn sites, `TutorialInitialSpawnPoint` client global) are removed. `IS_MISSION_TUTORIAL` is intentionally kept for UI-mode call sites (HUD, hints, pocket buttons).

## Scope

### MFT20260325 (Code branch — server) — r16058

- `Shared/ObjectModel/Profile/PersistentData.cs` — `+ bool IsIn3D`
- `Shared/SharedLib/Profile/NewPlayerProfileFactory.cs` — **new**. `Build()` clones from `InitialProfileCache`, then `ApplyTutorialSpawnPoint` parses `GlobalVariablesCache.TutorialInitialSpawnPoint` JSON and writes `Position`/`Rotation`/`IsIn3D = true` into `PersistentData`.
- `Loadbalancing/.../ProfileAdapter.cs` — registration path switched to factory; the `if (defaultProfile.LanguageId == 0) defaultProfile.LanguageId = SharedConsts.DefaultLanguageId` line is removed (it mutated a local that wasn't used downstream); a new `if (newProfile.LanguageId == 0)` check is placed against the actual new profile after `userProfile.LanguageId` propagation.
- `Loadbalancing/.../GameServer/GameClientPeer.cs` — `variables["InitialSpawnPoint"]` no longer pushed to client globals.
- `Loadbalancing/.../GameServer/GameClientPeer_Travel.cs` — on successful pond arrival, `Profile.PersistentData.IsIn3D = false` — closes the one-shot lifetime of the marker.
- `Shared/SharedLib/Profile/ProfileHelper.cs::ResetProfileToDefault` — uses the factory (so resets also re-establish tutorial spawn).
- `WebAdmin/.../ToolsModel_Profile.cs` — admin "reset profile" path goes through the factory.
- `Photon/tools/ReleaseTool/.../UserGenerator/Generator.cs` — `InitialProfileCache.GetProfile()` → `NewPlayerProfileFactory.Build()`.

### CodeBranch (Code branch — client) — r53670, r53676

- `Assets/Photon Server Networking/IPhotonServerConnection.cs` + `PhotonServerConnection_GlobalVariables.cs` — `- TutorialInitialSpawnPoint` (removed from interface and partial in lockstep — matches the IPhotonServerConnection sync rule).
- `Assets/Photon Server Networking/ObjectModel/Characters/SpawnCoordinates.cs` (+ `.meta`) — deleted. No remaining references in client code (verified by grep).
- `Assets/Photon Server Networking/ObjectModel/Profile/PersistentData.cs` — `+ bool IsIn3D` (mirror of server model).
- `Assets/Scripts/Common/Managers/StaticUserData.cs` (r53676) — `+ SHOULD_BE_SPAWNED_TO_3D => PhotonConnectionFactory.Instance?.Profile?.PersistentData?.IsIn3D == true`.
- `Assets/Scripts/UI/2D/Helpers/PondHelper.cs` — `- TutorLoading => Profile.Level == 1`. The remaining spawn call site (`Instance_OnGotAvailableLocations`) switched to `SHOULD_BE_SPAWNED_TO_3D`.
- `Assets/Scripts/UI/2D/Actions/Forms Init/PondInit.cs` — spawn gates `IS_MISSION_TUTORIAL` → `SHOULD_BE_SPAWNED_TO_3D`; `GetInitialLocation()` reads `PersistentData.Position` only (the fallback on `TutorialInitialSpawnPoint` is removed); logs error on `Vector3.zero`.
- `Assets/Scripts/UI/2D/Actions/Tasks/LoadLocation.cs`, `LoadPond.cs` — gate `PondHelper.TutorLoading` → `StaticUserData.SHOULD_BE_SPAWNED_TO_3D`.
- `Assets/Scripts/UI/2D/Common/MenuPrefabsSpawner.cs` — gate `IS_MISSION_TUTORIAL` (spawn call site only) → `SHOULD_BE_SPAWNED_TO_3D`. The other use of `IS_MISSION_TUTORIAL` in the same file (`_loadData[FormsEnum.HelpCanvas].IsAutohide`) is correctly left untouched — that one belongs to UI-mode, not spawn.

## Investigation Journal

- Branch-copy inheritance: MFT created from LBM @ r15942 (see `_index.md` → Server Branch Ancestry). r16058 > 15942 — MFT-only. No automatic inheritance into LBM (Content); per merge direction (Content → Code), no propagation expected.
- `SpawnCoordinates` on the server lives at `Shared/ObjectModel/Characters/SpawnCoordinates.cs` — the factory's `JsonConvert.DeserializeObject<SpawnCoordinates>` resolves against the server-side type. Deleting the client-side duplicate is safe.
- `IS_MISSION_TUTORIAL` is retained for UI-mode at ~20 call sites (HUD, hints, pocket buttons, Reel of Fortune disable, info messages, mobile mission handler, etc.). All of them remain semantically correct under the new model — they depend on "is tutorial mission currently tracked", not on "should be auto-spawned".
- JIRA Executor field (`customfield_11224`) is empty — executor identified via commit comment as Yuriy Burda.
- **Planned future use** (per discussion with executor, 2026-05-21): `PersistentData.IsIn3D` is also intended as a "was in 3D" marker for disconnect/reconnect — if a player drops while in 3D (fishing), the flag stays set; on next entry the client skips the local-map UI and lands the player back in 3D. This broadens the flag's semantics from "new-profile auto-spawn pending" to "should resume directly in 3D" in general. F-2 / F-3 / F-4 below are re-assessed against this context.

## Findings

### F-1: Silent fallback in `NewPlayerProfileFactory.ApplyTutorialSpawnPoint` [Low]

**Description:** When `GlobalVariablesCache.TutorialInitialSpawnPoint` is empty/whitespace, or when the JSON parses to a `SpawnCoordinates` without a `Position`, the method returns silently. The new profile is then created with `IsIn3D = false` and default `Position`. Operationally this means: if the global is misconfigured or deleted, the entire FTUE auto-spawn flow turns off for all new players with no diagnostic signal anywhere.

**Investigation:** Read `NewPlayerProfileFactory.cs` body. Both early-return branches have no logging. Compared with peer usages of `GlobalVariablesCache` — most read sites log on missing critical config.

**Resolution:** Suggest a `Logger.Warn` (or whatever the SharedLib convention is) on both early-return branches, naming the global variable. Low — not a behavioral bug, but loses critical signal if config is wrong.

**Discovered by:** review.

### F-2: Implicit invariant — `PondInit.GetInitialLocation` relies on "IsIn3D=true ⇒ Position set" [Low]

**Description:** Client-side `GetInitialLocation()` is invoked only when `SHOULD_BE_SPAWNED_TO_3D` is true (i.e. `PersistentData.IsIn3D == true`). Its first branch checks `data?.Position != null` — if true, uses the position; otherwise falls through to `return GameObject.Find(StaticUserData.CurrentLocation.Asset).GetComponent<Transform>()`. The fallback NREs if `CurrentLocation == null`.

In the current design `CurrentLocation` is set by `PondHelper.Instance_OnGotAvailableLocations` only when `SHOULD_BE_SPAWNED_TO_3D && CurrentPond == LoneStar`. So if `IsIn3D = true` is ever set without a corresponding `Position` populated by the factory (e.g. someone introduces a new code path that toggles `IsIn3D` without setting position), the fallback throws.

The server-side factory currently maintains the invariant (sets both `IsIn3D` and `Position` together, or neither). The risk is invariant drift, not a current bug.

Under the planned disconnect/reconnect use (see Investigation Journal) the invariant becomes load-bearing across more code paths — any disconnect/save that sets `IsIn3D = true` will need to ensure `Position` is meaningful at the same time. Worth encoding explicitly on the server (e.g. couple the assignment so `IsIn3D = true` is unreachable without a `Position` write) before the reconnect feature lands.

**Investigation:** Read full `GetInitialLocation` body (post-diff) and verified the only invocation site is `TransferToLocation_ChangedSky` guarded by `SHOULD_BE_SPAWNED_TO_3D`. Confirmed `Point3` is a reference type; `Position` can be null if the JSON omits it.

**Resolution:** Either (a) add a `data.Position == null` log + safe return on the fallback path, or (b) encode the invariant explicitly on the server — e.g. clear `IsIn3D` whenever `Position` is reset to null. Option (b) is more robust and becomes more valuable as the flag's role broadens. Not blocking for this PR.

**Discovered by:** review.

### F-3: Naming overlap on client — `PersistentData.IsIn3D` vs `ScreenManager.Instance.IsIn3D` [Info]

**Description:** The new client field `PersistentData.IsIn3D` shares a name with the existing `ScreenManager.IsIn3D` used at ~20 call sites for "is the current UI screen the 3D pond" (chat, HUD, tournaments, etc.). Two different concepts under one name on the same client codebase. Current diff routes the new flag exclusively through `SHOULD_BE_SPAWNED_TO_3D`, insulating callers — no current bug.

**Investigation:** `Grep IsIn3D` on the client returned `ScreenManager.IsIn3D` usages across ~20 files plus the new `PersistentData.IsIn3D`. Reviewed `StaticUserData.SHOULD_BE_SPAWNED_TO_3D` definition — accessor wraps the field, no leakage.

**Resolution:** Per discussion with executor (2026-05-21), name retained. Two reasons accepted:
1. Once the flag is extended to the disconnect/reconnect use (see Investigation Journal), `IsIn3D` describes the persistent-state question "was the player in 3D when last persisted" — which is semantically the right shape for both the FTUE auto-spawn use case and the upcoming reconnect use case. The earlier "naming clash" framing assumed the flag's meaning was narrower than it actually is.
2. Same-name fields with different meanings are an accepted convention in this codebase (per executor).

**Follow-up applied** (review-time, 2026-05-21): XML `<remarks>` added on both server (MFT @ r16109) and client (CodeBranch @ r54417). Documents the persistent-state nature, the one-shot lifetime, the Position/Rotation invariant, and the planned disconnect/reconnect use; client-side variant additionally points at `StaticUserData.SHOULD_BE_SPAWNED_TO_3D` as the canonical client access path.

**Discovered by:** review.

### F-4: Hardcoded LoneStar + InitialLocationId in `PondHelper.Instance_OnGotAvailableLocations` [Info]

**Description:** When `SHOULD_BE_SPAWNED_TO_3D` triggers, the client sets `CurrentLocation` only for `Ponds.LoneStar` + `InitialLocationId = 10144`. The destination of auto-spawn is therefore implicitly assumed to be LoneStar — but the server-side source of truth is `TutorialInitialSpawnPoint` JSON, which could in principle point anywhere. If anyone reconfigures the global to a different pond, the client won't set up `CurrentLocation`, and `PondInit.GetInitialLocation` will trigger the fallback path (which depends on `CurrentLocation != null` — F-2 path).

This is **pre-existing** (the hardcode predates this commit; only the gating boolean was swapped). Under the old model the same hardcode was protected by `TutorLoading == Profile.Level == 1` proxy plus identical `LoneStar` hardcode in `LoadLocation`/`LoadPond`, so practical risk was bounded by "Level-1 player always tutors in LoneStar". The new model decouples that — the server flag is destination-agnostic, the client gating is not.

Under the planned disconnect/reconnect use (see Investigation Journal) the LoneStar hardcode becomes a **blocker**: a player disconnected from any pond should resume in that pond, not LoneStar. Lifting the client-side destination hardcode is on the critical path for that feature.

**Investigation:** Read `PondHelper.Instance_OnGotAvailableLocations` (post-diff) and `PondHelper.InitialLocationId` (line 52) — `10144` hardcode marked `Tutorial based on the Missions: LONE STAR LAKE - Home Sweet Home`.

**Resolution:** Not blocking for this PR. Worth a follow-up backlog item on the FTUE / reconnect module — the client needs to derive the destination pond/location from server-provided state (e.g. `CurrentPond` from the persistent profile) rather than hardcoded LoneStar.

**Discovered by:** review.

### F-5: Repeated JSON parsing in `NewPlayerProfileFactory.Build()` [Info]

**Description:** Every `Build()` call deserialises the `TutorialInitialSpawnPoint` JSON. Not a hot path (profile creation, profile reset). A one-line `Lazy<SpawnCoordinates>` keyed against the current global value would amortise it. Optional.

**Investigation:** File inspection. No measurement; classification is by inspection of call sites (registration, reset, release-tool generator).

**Resolution:** Skip — micro-optimisation.

**Discovered by:** review.

### F-6: Lockstep deploy required — old/new mismatches degrade FTUE [Info]

**Description:** The change splits across server and client. Two mismatch scenarios:
- Old client + new server: client still reads the removed `InitialSpawnPoint` global (returns null/default), no fallback, lands at `(0, 0, 0)`. The bug we're fixing reappears, plus there's no `PersistentData.IsIn3D` on the old client to gate auto-spawn.
- New client + old server: server never sets `PersistentData.IsIn3D = true`, so `SHOULD_BE_SPAWNED_TO_3D` is permanently false. Auto-spawn never fires; FTUE Level-1 player always goes through local map — functionally degraded but safe (no `(0, 0, 0)` regression).

Feature is still being tested (2026.4 FTUE Steam/EGS, unreleased), so this is purely a deploy-coordination note, not a code issue.

**Investigation:** Cross-checked client diff against server diff. Confirmed both sides remove `TutorialInitialSpawnPoint`/`InitialSpawnPoint` symmetrically.

**Resolution:** Note for release coordination — server and client must ship in lockstep on the 2026.4 train. Not a code change.

**Discovered by:** review.

### F-7: Dead branch `defaultProfile.LanguageId == 0` removed from `ProfileAdapter` [Info]

**Description:** The removed line `if (defaultProfile.LanguageId == 0) defaultProfile.LanguageId = SharedConsts.DefaultLanguageId;` (around line 304 pre-diff) mutated a local `defaultProfile` that was no longer referenced after that point — a no-op. A new check on `newProfile.LanguageId` is placed at the actual right point (after `userProfile.LanguageId` propagation). Net positive cleanup; flagging only because it sits inside an otherwise spawn-focused commit and is easy to miss.

**Investigation:** Read pre/post hunks for `ProfileAdapter.RegisterPlayer`.

**Resolution:** Accept — correct refactor.

**Discovered by:** review.

### F-8: JIRA `Executor` field (`customfield_11224`) empty [Info]

**Description:** Executor unset in JIRA; identified via commit comment as Yuriy Burda. Process hygiene only.

**Investigation:** `getJiraIssue` returned `customfield_11224: null`.

**Resolution:** Surface in JIRA comment (executor hygiene reminder); no code action.

**Discovered by:** skill recon (executor hygiene).

## Verdict

**Approve.** No blocking findings. The architectural direction is sound — heterogeneous client gates replaced by a single server-authoritative flag whose lifetime is well-defined for the FTUE case and extensible to the planned disconnect/reconnect case. UI-mode call sites of `IS_MISSION_TUTORIAL` correctly left intact.

Suggested improvements (none blocking): F-1 logging on the silent-fallback paths; F-2 explicit encoding of the "IsIn3D=true ⇒ Position set" invariant (more valuable as the flag's role broadens); F-3 short XML `<remarks>` on the property (name retained by executor decision). Follow-up backlog item for FTUE/reconnect module — lift the client-side LoneStar hardcode (F-4) before the reconnect feature lands. F-5 optional micro-opt; F-6 deploy-coordination note; F-7/F-8 informational.
