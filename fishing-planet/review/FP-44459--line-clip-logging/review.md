---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16188, merged to NPN @ r16190
jira: https://fishingplanet.atlassian.net/browse/FP-44459
---

# FP-44459: Add logging for clipping

## Summary

Add logging for reel line clip set/clear ("clipping" of tackle). JIRA description: "додать логування для кліпсування снастєй"; executor commit message: "Add logging for reel line clip set/clear". Diagnostic/observability-only change. Parent epic FP-34175.

## Scope

- **MFT r16188** — Add logging for reel line clip set/clear
- **NPN r16190** — Merge from MFT r16188

(Branch roles: MFT = Content, NPN = Code. Source on Content, merged into Code — correct direction.)

## Findings

### F-1: `LogClipChange` is `public` while sibling log helpers are `private` [Low]

**Description:** `GameProcessor.LogClipChange` is `public`; the sibling helpers (`LogFishing`, `LogFishingAsync`, `LogInventory`, `LogSys`) are all `private`. It is `public` because it is invoked cross-class from `GameClientPeer_Inventory.HandleSetClipLength`. Both classes live in the same assembly (`LoadBalancing.csproj`), so `internal` would satisfy the access requirement while staying closer to the encapsulation pattern.

**Investigation:** Confirmed both files compile into `LoadBalancing.csproj` (GameProcessor.cs in `GameLogic/`, GameClientPeer_Inventory.cs in `GameServer/`). Verified sibling Log* helpers are `private`.

**Resolution:** Accepted. `internal` would be marginally more consistent, but for a server-internal DLL with no public API surface the practical difference is nil; non-blocking, optional cleanup.

**Discovered by:** code-reviewer agent.

### F-2: Interpolated `float?` in log message is culture-dependent [Info]

**Description:** `$"Line clip set: {clipLength}"` formats the float using the thread's current culture (locale-dependent decimal separator). Raised by the agent as a potential Medium.

**Investigation:** Verified the directly comparable calls in the same file interpolate floats with no `InvariantCulture` and no format specifier: `LogFishingAsync($"Throw. Leader Length: {rod.LeaderLength}")`, `LogFishingAsync($"Tackle landed: CastLength: {castLength}, PlayerPosition: {playerPosition}, ...")`. The new code follows the established fishing-log convention exactly; this is a pre-existing codebase-wide pattern, not introduced by this commit. The fishing log is human-read diagnostic text, not machine-parsed.

**Resolution:** Pre-existing. Not the author's oversight; non-blocking.

**Discovered by:** code-reviewer agent (downgraded from Medium after verification).

## Verdict

**Approve.** Observability-only change. The `HandleSetClipLength` refactor is behaviorally equivalent: `clipLength` is computed once and reused for persistence and logging; the cast now runs for any `isSet==true` (previously gated by `slotData`), but `ItemCount` presence is packet-driven (always sent when `isSet`), not server-state-driven, so no new exception risk. The log call is null-safe (`processor?.…?.LogClipChange`) and intentionally outside the persistence guard so it captures client intent even when no `slotData` exists — useful for the desync this diagnostic targets. Merge into NPN (Code) at r16190 is faithful (identical diff + `svn:mergeinfo`) and correctly required (r16188 > NPN copy base r16130). Two minor non-blocking findings (F-1, F-2).

## Investigation Journal

- Phase 1 intake: executor field populated (Yuriy Burda); commits taken from JIRA comment at face value, audited in Phase 2.
- VCS audit: `svn log | grep FP-44459` on both branch URLs returned exactly r16188 (MFT) and r16190 (NPN merge) — matches JIRA, no unposted commits, branch metadata matches comment. Executor quality clean.
- WC freshness: WC at r16227 > reviewed revs (r16188/r16190) — disk reads trustworthy, no stale-WC fallback needed.
- Verified `FindGameProcessorInSlot` (on `MultiRodGameProcessor`, returns `GameProcessor`/null) and `LogFishingAsync` (`important=true` default, async fire-and-forget, same as ~15 sibling calls).
- Branch-copy inheritance: r16188 (16188) > NPN base r16130, so explicit merge to NPN was required and was performed — correct.
- code-reviewer agent delegated (user opted in); its two findings verified independently — F-1 confirmed minor, F-2 downgraded Medium→Info as pre-existing pattern.
