---
status: resolved
executor: Dmytro Kurylovych
branch: LBM @ r15552, r15553, r16034, merged to MFT @ r16035
jira: https://fishingplanet.atlassian.net/browse/FP-41353
---

# Review: FP-41353 — [PlayStation] Don't log PondUnlock spam on relogin when expireDate unchanged

## Summary
On PlayStation the entitlement delivery path emitted a "Player was given a PondUnlock" License Log entry at every login, even when the PondUnlock expireDate was unchanged. Fix narrows the log to cases where PondUnlocksChanged is set during PS product delivery. Companion change in WebAdmin improves how License Log messages are presented.

Feature is on Test environment, not production yet.

## Scope
- **LBM r15552** — `[PlayStation] [Entitlements] log PondUnlock details when PondUnlocksChanged on delivering PS product to player`
- **LBM r15553** — `[WebAdmin] [MergedLog] improve logging and representation of license log messages`
- **LBM r16034** — `[Entitlements] [Profile] coalesce save in PS alreadyGiven re-delivery; fix license log typo` (review follow-up by Stanislav for F-1 and F-3)

## Investigation Journal
- 2026-04-25: Card created from JIRA intake (Phase 1). Branch and commits taken from executor's JIRA comment as-is.
- 2026-04-25: VCS audit on LBM (`svn log --search "FP-41353" -r 1:HEAD`) — exactly r15552 + r15553, matches JIRA. No unposted commits.
- 2026-04-25: Inheritance check on MFT (Code) — both revisions appear in `svn log` of MFT (LBM:r15942 ≥ r15553), so inherited via branch copy. No explicit merge required; closure comment will omit `Merged → MFT`.
- 2026-04-25: H1 verified — read `GameClientPeer_Monetization.HandleGivePsProduct` lines 240-413. After the new `if (result.PondUnlocksChanged) LogPondUnlocksDelivery(...)` block (line 309-310), no `SaveProfile` is invoked in the `alreadyGiven` branch. In old code `SaveProfileWithLog("Subscription duration prolonged")` fired whenever the `bool result` was true, including pond-unlock changes. New code persists only on `SubscriptionChanged`. Edge case: `alreadyGiven=true` + `existingUnlock==null` for a newly-added pond, or `existingUnlock.EndDate != expireDate` → memory mutated, profile not saved. Auto-save via `OnDependencyChanged("UnlockedPonds", …)` is plausible but unverified. Surfaced as F-1.
- 2026-04-25: code-reviewer agent invoked for independent verification. Results:
  - F-1 confirmed (High per agent). Persistence chain: `OnDependencyChanged("UnlockedPonds", ...)` → `Profile.OnDependencyChanged` → `MissionsContext.OnDependencyChanged` — no save side-effect. Disconnect-time `SaveProfileWithLog("Disconnect/Quit")` in `GameClientPeer.cs` covers graceful logout but not crash/force-restart. Regression is broader than first noted: `outdateLevelLockRemovals` (the `out`-parameter populated by `UpdateSubscriptionEndDate`) — its in-memory deletion of expired unlocks is also no longer persisted in this branch.
  - F-2 refuted — `[id, id]` `PondsUnlocked` is a legitimate pre-existing pattern. `TrackedProductDelivery.DeliverPondUnlocks` handles the same shape with a "Single compensation pass" comment. The new `LogPondUnlockCompensationAdd` mirrors it on the log side. Not scope creep.
  - F-3, F-4, F-5 confirmed.
  - Severity disagreement on F-1 — agent says High; my read leans Medium-with-escalation (config-driven scenario is rare, normal logout paths persist, crash window is a generic monetization risk). To resolve in discussion.
- 2026-04-25: Discussion with user — narrowed F-1 scope further. Self-healing argument: each subsequent login re-runs `UpdateSubscriptionEndDate` and mutates in-memory state; sessions trigger many `SaveProfileWithLog` calls (`RequestMissionResult`, `Tournament.ReleaseFish`, `LevelGained`, etc.) and graceful disconnect always saves. Functional player impact is zero; worst case is a few extra log entries in a narrow crash-window that self-heal next normal session. Severity dropped to Low/Info.
- 2026-04-25: Patched anyway for semantic symmetry. Considered "add `SaveProfileWithLog` inside `if (result.PondUnlocksChanged)`" — rejected because it would cause a double save when both flags were true. Final shape: single coalesced save after the log calls, gated on `SubscriptionChanged || PondUnlocksChanged`, with a switch-expression message reflecting which path triggered it. Test-helper in `HandleGivePsProductTest` synced. Typo `Unimited` → `Unlimited` (F-3) bundled into the same commit. Committed as **LBM r16034**.
- 2026-04-25: Cross-branch merge — r15552 and r15553 inherited in MFT via branch copy (LBM:r15942 ≥ r15553), no merge needed. r16034 (post-base) merged explicitly into MFT as **r16035**. KNW (Stable) and IMV (OldStable) — feature is on Test, no backport required.

## Findings

### F-1: SaveProfile regression in `alreadyGiven` branch — pond unlock changes and expired-unlock removals not persisted [Medium → potentially High]

**Description:** In `GameClientPeer_Monetization.HandleGivePsProduct`'s `alreadyGiven=true` branch (`GameClientPeer_Monetization.cs`), the new flow gates `SaveProfileWithLog("Subscription duration prolonged")` strictly on `result.SubscriptionChanged`. The companion `if (result.PondUnlocksChanged) Profile.LogPondUnlocksDelivery(...)` logs the change but does not persist. The unconditional `Profile.LogPondUnlocksRemoved(outdateLevelLockRemovals, source)` likewise does not persist — and the in-memory removal of expired entries inside `UpdateSubscriptionEndDate` (which populates the `outdateLevelLockRemovals` out-parameter) is therefore not flushed either. In the prior implementation a single `bool result` covered both axes, so any pond-unlock or expiry change persisted via the same `SaveProfileWithLog` call. Persistence chain traced (by code-reviewer agent): `OnDependencyChanged("UnlockedPonds", ...)` → `Profile.OnDependencyChanged` → `MissionsContext.OnDependencyChanged` — no save side-effect. `SaveProfileWithLog("Disconnect/Quit")` in `GameClientPeer.cs` covers graceful logout; crash / force-restart between re-delivery and disconnect drops the changes.

**Investigation:**
- Read diff for r15552 — `UpdateSubscriptionEndDate` split into `(SubscriptionChanged, PondUnlocksChanged)`.
- Read `GameClientPeer_Monetization.cs` lines 240-413 — confirmed no `SaveProfile` after the `if (alreadyGiven)` block; the `else` branch separately calls `SaveProfileWithLog("DeliverConsoleProduct")`, so first-delivery is not affected.
- code-reviewer agent traced the full `OnDependencyChanged` chain — confirmed no auto-save side effect; identified `SaveProfileWithLog("Disconnect/Quit")` as the catch-all and broadened the regression scope to also include `outdateLevelLockRemovals` (expired unlocks cleaned in memory but not flushed until disconnect).

**Resolution:** Patched in **LBM r16034**. Severity reassessed to **Low/Info** during discussion: self-healing covers the regression — every login re-runs `UpdateSubscriptionEndDate`, mutates the in-memory state, and any of the dozens of session-scoped `SaveProfileWithLog` calls (or graceful disconnect-time save) persists the profile, so functional impact is zero and worst-case is a few extra log lines in a narrow crash-window which themselves self-heal on the next normal session. `outdateLevelLockRemovals` removals were NOT a fresh regression — pre-existing behavior never persisted them on the `result==false` path either. Patch landed for semantic symmetry with the old behavior: a single `SaveProfileWithLog` gated on `SubscriptionChanged || PondUnlocksChanged` with a switch-expression message reflecting which path triggered it (avoids the double-save that a naive "add another save" patch would have caused when both flags were true). Test-helper synced.

**Discovered by:** skill recon; verified by code-reviewer agent; resolved via discussion + patch

### F-2: `LogPondUnlockCompensationAdd` for `Length == 2 && [0] == [1]` case [Refuted → Info]

**Description:** Initially flagged as scope creep. `ProductHelper.LogPondUnlocksDelivery` gains a special branch: if `product.PondsUnlocked.Length == 2 && PondsUnlocked[0] == PondsUnlocked[1]`, route through the new `LogPondUnlockCompensationAdd` (which looks up a `LevelLockRemoval` whose `Ponds` array is `[pondId, pondId]`).

**Investigation:**
- Initial file inspection only — origin of `[id, id]` convention unclear.
- code-reviewer agent located `TrackedProductDelivery.DeliverPondUnlocks` which already handles `pondIds.Length == 2 && pondIds[0] == pondIds[1]` with a comment "Single compensation pass (PondsUnlocked = [id, id])". The new method mirrors this established convention on the log side.

**Resolution:** Accept — consistent with pre-existing pattern, not scope creep.

**Discovered by:** skill recon; refuted by code-reviewer agent

### F-3: Typo `Unimited` in new License log message [Low]

**Description:** `Profile.AddLicense` (`Shared/ObjectModel/Profile/Profile.cs` r15553) emits `"About to make Unimited {info}, {term}"` — `Unimited` is a typo for `Unlimited`. The phrasing is consistent with the prior message which spelled `Unlimited` correctly (`"replaced with Unlimited"`). Visible to admins in WebAdmin License Log.

**Investigation:** File inspection only — diff context shows the prior string was `"replaced with Unlimited"`, confirming intended spelling.

**Resolution:** Patched in **LBM r16034**.

**Discovered by:** skill recon

### F-4: License log format change — possible breakage of external parsers [Info]

**Description:** `ProductHelper.FormatLevelLockRemoval` reformatted: `"#{pondId} '{name}' term {term}"` → `"#{pondId} '{name}', Term: {term}"`, similar for the multi-field overload. Default source label in `LogPondUnlockAdd` flipped from `"License Added"` to `"PondUnlock Added"`. The new format is intentional — `MergedLog.cshtml` (r15553) introduces `regexEndDate` parsing `"End: '...'"`. Any external alerting / anti-cheat scripts parsing the prior strings will need updating.

**Investigation:** File inspection only — no grep done for external consumers.

**Resolution:** Accept. No internal consumers found (`MergedLog.cshtml`'s `regexEndDate` is the only parser and it's aligned with the new format); external consumers, if any, will adapt when needed.

**Discovered by:** skill recon

### F-5: No new test for the "no log on unchanged relogin" path [Info]

**Description:** `LoadBalancing.Tests/HandleGivePsProductTest.cs` is touched in r15552 but the changes are limited to (a) syncing the test-side helper that mirrors the production `UpdateSubscriptionEndDate` callsite and (b) adding `Console.WriteLine()` separators between phases. No new assertion-bearing test exercises the bug condition (relogin with `alreadyGiven=true` and unchanged pond — license log entry must NOT be emitted).

**Investigation:** File inspection only.

**Resolution:** Accept as pre-existing coverage gap, card only (no backlog entry). PS entitlement and Premium subsystems are slated for rewrite, so investing in coverage on the about-to-be-replaced code path would be wasted.

**Discovered by:** skill recon