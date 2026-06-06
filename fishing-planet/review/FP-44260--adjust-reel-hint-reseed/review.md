---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16146, merged to NPN @ r16147
jira: https://fishingplanet.atlassian.net/browse/FP-44260
---

# Review: FP-44260 — 'Adjust reel drag...' hint shown for correct reel drag after exiting to local map during tutorial

## Summary

FTUE tutorial bug: the "Adjust reel…" hint is displayed even when reel drag is correctly set to 4, if the player exits to the local map before catching the first two fish. The stale hint never clears, and it suppresses the subsequent Strike/Pull hints. Fix reseeds the reel drag/speed indicators when a rod becomes foreground.

## Scope

- **MFT r16146** — Reseed reel drag/speed indicators when a rod becomes foreground
- **NPN r16147** — Merge from MFT r16146

## Findings

### F-1: Second `if (value != null)` guard looks redundant [Info]

**Description:** `SeedForegroundReelIndicators` is wrapped in a fresh `if (value != null)` even though the same setter dereferences `value.Slot` a few lines above. At first glance redundant.

**Investigation:** Read the full `HandsProcessor` setter. The prior `IsForeground = true` assignment is itself guarded by `if (value != null)` — `value` is legitimately null when a rod is unequipped to empty hands. The new guard mirrors the existing pattern; without it the reseed would NPE on unequip.

**Resolution:** Accepted — consistent with existing null-handling, not redundant.

**Discovered by:** skill recon

### F-2: `ReelSettingsPersister.GetReelSettings` dereferences `Profile.Settings` without a null guard [Low]

**Description:** `GetReelSettings(peer.Profile.Settings, ...)` calls `settings.ContainsKey(...)` with no null check; `Profile.Settings` is a nullable dictionary. A null would throw during a foreground switch.

**Investigation:** code-reviewer agent + manual scan. The identical exposure already exists at the `SetReelFriction(Profile.Settings, ...)` call site in `GameClientPeer_Missions.cs`. `Profile.Settings` is populated at login before game logic initializes, so this is a latent pre-existing risk, not newly introduced by this fix.

**Resolution:** Pre-existing — not attributable to this commit.

**Discovered by:** code-reviewer agent

### F-3: Multiple `OnDependencyChanged` emissions per indicator via `SetIndicator` [Info]

**Description:** Seeding through `SetIndicator` fires the dependency-changed callback more than once per indicator (top-level property setter cascade + `SetIndicator`'s own emission).

**Investigation:** code-reviewer agent. This is the exact same path `HandleSetIndicator` uses during normal gameplay (same `SetIndicator`, same foreground context). No persisted-settings write occurs here (`SetReelFriction`/`SetReelSpeed` live only in `HandleSetIndicator`), so no spurious save or extra client event beyond normal gameplay.

**Resolution:** Pre-existing design — no regression.

**Discovered by:** code-reviewer agent

## Verdict

**APPROVE.** The fix is correct, durable, and minimal.

- Bug mechanism verified: `SwitchForegroundRod` else-branch (`MissionsContext.cs`) copies the stale per-rod `rodContext.FrictionPosition` (= 0 when the client friction push was lost on map exit) into the foreground context → "invalid drag" → "Adjust reel..." hint shows despite drag=4.
- Fix verified: `SetIndicator` writes `hashIndicators`, the foreground `rodContext` (`Foreground`), and raises `OnDependencyChanged`, forcing the hint mission to re-evaluate against the authoritative persisted reel settings (or sane defaults {Friction=3, Speed=1}).
- Durability verified: because `SetIndicator` writes into the foreground `rodContext`, the next `SwitchForegroundRod` copies the corrected value — fix survives repeated equip/unequip cycles.
- Reseed is hooked at the single correct site (`HandsProcessor` setter, the path `AssociateRodInHands`/`ActivateSlot` flow through after returning from the local map).
- No blocking findings. F-1 accepted, F-2/F-3 pre-existing.

## Investigation Journal

- Intake: executor field populated (Yuriy Burda), commit list taken from JIRA comment at face value.
- Phase 2 VCS audit (`svn log -r 16100:HEAD | grep`): exactly r16146 on MFT + r16147 merge on NPN, both yuriy.burda. Matches JIRA comment — executor hygiene clean, no unposted/extra commits.
- Verified core claims independently: `SwitchForegroundRod` zeroes/copies-stale indicators (`MissionsContext.cs:2276-2277`, `2350-2351`); `GetReelSettings` returns persisted-or-default {3,1}; `GameIndicatorType` has `FrictionPosition`/`ReelSpeed`; `Foreground` == the rodContext that `SetIndicator` writes (durability proof).
- Reel-lookup idiom `Inventory.Where(ParentItemInstanceId == rod.InstanceId)` matches existing usage (`GameProcessor.cs:787, 2770`) — not a finding.
- **WC-stale caveat:** at review time the working copy on disk was at r16143; the fix landed at r16146. Initial disk `Read` (and the code-reviewer agent) saw the pre-fix version and the agent flagged "fix not present". Resolved via `svn cat -r 16146` + `svn info` — fix IS in the repo exactly as the diff shows; only the WC was behind. WC subsequently `svn update`d to r16150, disk now matches committed state (`SeedForegroundReelIndicators` present). Lesson: review committed `svn diff`/`svn cat -rREV`, not disk `Read`, when the WC may be stale.
- code-reviewer agent (deep delegation): no blocking issues; all surfaced concerns are pre-existing or confirmatory.
