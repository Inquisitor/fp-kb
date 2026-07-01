---
jira: https://fishingplanet.atlassian.net/browse/FP-43009
title: "[XB][Achievements] Reward not displayed on Challenge Complete window"
status: completed
executor: Stanislav Samoilov
created: 2026-06-30
type: bug
platforms: [Xbox]
---

## Status

Resolved. Root cause was a client platform-id mismatch: Xbox GDK builds (`UNITY_GAMECORE_XBOXONE`) reported Win10 instead of XBox, so the client filtered achievement reward products to a platform whose product is absent from its catalog cache. Fixed client-side in `PlatformManager.cs` (`Unity_Fishing_CodeBranch` r55928 -> `Unity_Fishing_MainClient` r55929). No server change. Verified by QA on an Xbox build — reward images render correctly.

## Summary

On Xbox the repair-kit reward of achievement #610 "Emerald Junk Catcher" (and others) was not rendered on the Challenge Complete window nor on the achievement-progress tooltips, although the item was actually delivered to the player. Client logs showed `Could not find StoreProduct in cache by id: <id>` for the **Win10** product of each reward (e.g. 2680 for reward 76640, whose XBox product is 2640).

The same achievement rendered correctly on Steam, so QA reopened the ticket for Xbox only.

## Root cause

Platform is resolved **twice, independently**, and the two diverged on the Xbox GDK build:

- **Server** — `peer.PlatformId` comes from `profile.Source` at login (`GameClientPeer.LoadProfile`). The Xbox GDK client authenticates as `XBox` (`XBoxGamecoreManager` uses `SharedConsts.XBoxSource`), so the server sets `PlatformId = 3 (XBox)` and sends the **XBox** product catalog. The server was already correct.
- **Client** — `PlatformsManager.PlatformId` is derived from build defines. For `UNITY_GAMECORE_XBOXONE` it returned `Win10PlatformId (4)` instead of `XBoxPlatformId (3)`.

Consequence: `RewardsHelper.GetProductRewardForPlatform` filters `reward.Products` by `PlatformsManager.PlatformId` and picked the **Win10** product (4), which is absent from the client's XBox-only product cache. `ProductsCache.GetByID` then failed and the reward image was dropped — on both the Challenge Complete window and the stage tooltips.

Why only Xbox: the defect surfaces only on multi-platform installations where the client build platform must equal the auth/catalog platform. On Steam (`Steam,Epic`) the Steam build reports Steam (1) which matches its auth source, so it never mismatched. The XBox installation serves `XBox,Win10` from one farm, where the GDK build's reported platform (Win10) no longer matched its auth source (XBox).

Note: the JIRA comment labelled this "серверна". The symptom (Win10 products instead of XBox) is server-observable, but the wrong selection happens on the client — the error string `Could not find StoreProduct in cache` exists only in client `ProductsCache`.

## Fix

Client one-liner in `Assets/Scripts/Common/Managers/PlatformManager.cs`:

```
#elif UNITY_GAMECORE_XBOXONE
-   clientPlatformId = SharedConsts.Win10PlatformId;
+   clientPlatformId = SharedConsts.XBoxPlatformId;
```

- Code branch: `Unity_Fishing_CodeBranch` r55928
- Content branch: `Unity_Fishing_MainClient` r55929 (merge of r55928)

No server change required. Final verification is a QA pass on an actual Xbox GDK build (the changed branch is gated by `UNITY_GAMECORE_XBOXONE`, not buildable from the desktop client).

## Plan

Diagnosis + handoff only; implementation owned by the client team. No server work item.

## Milestones

### 2026-06-30 — Diagnosis + client fix delivered

- Traced the `Could not find StoreProduct in cache` errors to a platform-id mismatch: `PlatformsManager.PlatformId` returned Win10 (4) for Xbox GDK builds (`UNITY_GAMECORE_XBOXONE`) while the server treats the peer as XBox (3); `RewardsHelper.GetProductRewardForPlatform` then filtered reward products to the wrong platform, whose product is absent from the client's catalog cache.
- Client fix (one line): `PlatformManager.cs` GDK branch -> `XBoxPlatformId`. `Unity_Fishing_CodeBranch` r55928, merged to `Unity_Fishing_MainClient` r55929.
- User pulled the MainClient update; QA verified on an Xbox build (2026-07-01) — achievement Challenge Complete window and stage tooltips render the reward image, no cache error.
