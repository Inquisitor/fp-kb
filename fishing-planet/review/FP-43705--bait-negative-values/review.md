---
status: waiting-for-release
executor: Yuriy Burda
branch: MFT20260325 @ r16101, r16103
jira: https://fishingplanet.atlassian.net/browse/FP-43705
---

# Review: FP-43705 — Possibility to use bait into negative values after STR

## Summary

Bug fix: bait/feeder consumable counters could be driven into negative values and remain
infinitely usable. STR: hook bait on two setups, deplete one (eaten/lost without hooking),
swap a different bait from backpack onto the first setup's depleted slot, then cast the
second setup. The second setup's bait counter goes negative and never recovers (reload /
re-entering the pond does not fix it). Fix intent (per commit message): stop bait/feeder
replenish from depleted stacks.

## Scope

- **MFT20260325 r16101** — Stop bait/feeder replenish from depleted stacks
- **MFT20260325 r16103** — update related tests

## Findings

### F-1: `ReplanishConsumables()` added only to `ResetState`, not to sibling `Reset` call-sites [Medium]

**Description:** In `MultiRodGameProcessor.cs` the pattern `if (StateMachine.State != GameStates.Initial) StateMachine.Reset(peer)` exists in three methods: `ResetState` (~l.819, got the new `ReplanishConsumables()` call), `UnloadGameProcessor` (~l.524) and `Teleport` (~l.1444) — the latter two without it. Reviewed for whether the omissions reopen the bug. They do not: the negative-counter root cause is `FindReplenishmentStack`'s missing `Count>0` filter, which is fixed globally. `UnloadGameProcessor` is safe (rod items return to storage → `RemoveItemOnReturnToStorage` cleans Count≤0). `Teleport` (fast-travel, e.g. Nav Buoy) with mid-cycle depleted bait leaves the rod at `HasBait=false` until the next replenish — a minor UX window, not a negative counter and not the reported STR.

**Investigation:** Diff read + grep of all three call-sites; independent code-reviewer agent traced each path. ReplanishConsumables did not exist before r16101, so all three sites previously behaved identically — the asymmetry is new but the Teleport gap is pre-existing behavior, out of the reported scope.

**Resolution:** Accepted — non-blocking. Teleport gap is a candidate follow-up, not part of this fix's scope.

**Discovered by:** skill recon + code-reviewer agent

### F-2: `FindReplenishmentStack` filters on `Count > 0` with no guard against amount-stack callers [Info]

**Description:** `Inventory_Operations.cs::FindReplenishmentStack` uses `Count > 0`, correct for count-stack items (Bait, PvaFeeder). For amount-stack items (Line, Chum) `Count` is pack size, not remaining `Amount` — the filter would be wrong. Verified only count-stack callers exist (`ReplanishBait`, `ReplanishPvaFeeder` in both `GameProcessor` and `GameClientPeer_Inventory`), so safe as used. No type guard / remark to protect a future amount-stack caller.

**Investigation:** grep of all call-sites; no amount-stack caller found.

**Resolution:** Accepted — note only; optional `remarks`/assert hardening.

**Discovered by:** code-reviewer agent

### F-3: `FixDepletedItemsConverter` class comment omits amount-stack ParentItem removal [Info]

**Description:** Class comment describes the count-stack `ParentItem` exemption but not that amount-stack items (Chum/Line) with non-positive `Amount` are removed everywhere including on-rod (`ParentItem`). The asymmetry is intentional and explicitly tested (`Execute_on_rod_chum_with_negative_amount_should_be_removed`); only the doc lags the predicate.

**Investigation:** Read converter predicate + tests; behaviour matches intent.

**Resolution:** Accepted — doc-only nit.

**Discovered by:** code-reviewer agent

## Verdict

**APPROVE.** Core fix is sound and correctly targets the reported bug:
- `FindReplenishmentStack` `Count>0` filter stops replenishment from depleted stacks (root cause).
- `ShouldRemoveItem` re-enables `Count<=0` removal for count-stacks and broadens amount-stack removal to negative values (old `IsNegligible` only caught ≈0). On-rod consumed bait (`ParentItem`, `Count=0`) is preserved — `RemoveItemOnReturnToStorage` guards on `Storage==Storage||Equipment`.
- `RemovalReason` enum migration complete and verified (no stray `.Broken`/`.RentExpired` bool reads remain); incidentally fixes old bug where all return-to-storage removals were logged as `isBroken: true`.
- New replenish-before-`Reset` in `ResetState` covers the STR's pin-change path.
- `FixDepletedItemsConverter` + SQL patch `MFT.M.2026.05.19-019` (idempotent, `IF NOT EXISTS`) clean up already-corrupted prod profiles.

All findings (F-1/F-2/F-3) are non-blocking — one out-of-scope follow-up candidate (Teleport) and two doc/hardening nits.

## Remediation / Release plan

Code review approved. Remaining work is data cleanup of already-corrupted profiles — gated on release.

Scope (full prod assessment, see [scope-results.md](scope-results.md)): **227 affected F2P players**
(Steam 141, PS 56, XB 22, Mob 8, NX 0; Retail out of scope — not patched). 1 negative item per
player, mostly cheap PVA feeders, no stockpiling → low impact, not urgent. No clawback/compensation
(players gained free consumable usage, not a loss; value negligible vs cost/risk — decided against).

Cleanup mechanism (already built, no new dev):
- Login path: `FixDepletedItems` conversion (registered, `IsEnabled=1`) auto-applies for active players.
- Dormant players: run `ReleaseTool.ProfileConversionFinalizer.Run(<ConversionId of 'FixDepletedItems'>)`
  offline during release — processes ALL profiles incl. dormant, per-user status tracked, profiles
  backed up. ConversionId per prod: `SELECT ConversionId FROM ProfileConversions WHERE Code='FixDepletedItems'`.

At release (TODO, not yet done):
- [ ] Run the offline finalizer for `FixDepletedItems` on each F2P prod (or point `SmartOfflineProfileUpdater`
      at the `FP43705_Candidates_*` tables for a targeted 227-profile pass). This also clears the int-overflow
      account (it is in the candidate set; the converter removes the corrupted stack like any other) — no
      separate one-off needed.
- [ ] Optional: anti-cheat review of active+deep Steam accounts (haiminh992 −117 / CheatRating 169k, warius13).
- [ ] On QA handoff: reassign FP-43705 back to Stanislav with status `resolved`.

## Investigation Journal

- Intake: executor = Yuriy Burda (commit author per JIRA comment), not assignee (Stanislav, reviewer).
- ⚠ Executor field (`customfield_11224`) empty at intake — detect-only nudge, not auto-filled.
- Phase 2 VCS audit: `svn log --search "FP-43705"` confirmed exactly r16101 + r16103 on MFT, both by yuriy.burda; matches JIRA. r16103 msg is "...(fix tests)" vs JIRA "update related tests" — cosmetic only.
- Verified `MaterialAmountIsConsiderable` = `IsPositiveWithTolerance` (>tol) and `MaterialAmountIsNegligible` = `EqualsToZeroWithTolerance` (|x|≈0); new `!IsConsiderable` removal condition is strictly broader than old `IsNegligible` exactly on negatives — the intended fix, no false removal of valid positive stacks.
- `InitItemCount` (Count==0→1) wrapping in r16103 tests confirms prod items normally carry positive Count; default-Count=0 was a test-only artifact now removed by the re-enabled cleanup.
- Inheritance check (close-phase relevance): NPN20260602 base = MFT:16130 ≥ r16103 → fix already inherited into Code branch via branch-copy, no merge to NPN needed. LBM (Stable, base MFT? no — MFT from LBM:15942) does NOT contain r16101/r16103 → down-merge to Stable is a release decision for close phase.
- Findings routing: F-1 accepted (Teleport = out-of-scope follow-up candidate), F-2/F-3 accepted as doc/hardening nits — none blocking.
