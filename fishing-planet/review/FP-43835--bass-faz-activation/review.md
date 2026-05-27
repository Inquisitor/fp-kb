---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16121
jira: https://fishingplanet.atlassian.net/browse/FP-43835
---

# Review: FP-43835 — [FTUE] Jumping fish FAZ: Bass fish FAZ no activate

## Summary

Bug: jumping-fish FAZ (fish activity zones) for BASS do not activate, while PIKE and G_BASS do. QA observed that the attractors themselves activate, but the zones linked to them do not. Fix targets FAZ activation for group-bound weather fish entries.

## Scope

- **MFT r16121** — Fix FAZ activation for group-bound weather fish entries
  - `WeatherServer.cs` / `Weather.FinishInitializationServer`: replace direct `Settings.GetFishId(fish.Name, form)` with iteration over `fish.AllFish` (the fish group's constituent species records), filtering layer forms by `record.FishForms` and keying the chart binding by each constituent species' fishId.
  - New `WeatherServerTests.cs`: two tests — group-bound entry registers a chart for each constituent species; single-species entry still registers its own chart.

## Root cause / fix logic

`fishIdTimeCharts` maps a global `fishId` → set of time-chart ids; it is the producer side consumed by `FishHasNonZeroChart` (which iterates `attractor.FishGroup.Fish` and looks up each constituent species' fishId). The old producer keyed bindings by `fish.Name` — the weather *entry* name. For a group-bound entry (BASS), `fish.Name == FishName.None`, so `GetFishId(None, form) == -1` and no chart was ever registered → the linked FAZ never saw a non-zero chart → zones did not activate (PIKE / G_BASS are single-species entries, so they worked). The fix keys bindings by the group's constituent species, matching the consumer.

## Verdict

**Approve.** Correct, minimal, well-targeted fix with tests. No regression for single-species entries; ordering and null-safety verified. No blocking findings.

## Findings

### F-1: `record.FishForms.Contains` not null-guarded [Low]

**Description:** `WeatherServer.cs` / `FinishInitializationServer` dereferences `record.FishForms` without a null check. `FishGroup.Record.FishForms` is a bare public field; Newtonsoft would leave it `null` if JSON omitted it. Raised by the code-reviewer agent (confidence 85).

**Investigation:** Grepped all `FishForms` usages across BiteSystem — 8 dereference sites (`WeatherServer.cs` ×2 incl. the existing consumer `FishHasNonZeroChart` at the `foreach (var form in fish.FishForms)`, `PondServer.cs` ×6). None null-guard it. The synthetic-group path (`Fish.cs`) always assigns a non-null `List`. Non-null `FishForms` is therefore a firmly established, system-wide data invariant.

**Resolution:** `Accepted` — fix matches existing convention. Guarding only the new site would be inconsistent with 7 other unguarded dereferences (including the consumer in the same class, which runs on the same pond load) and would give false safety: a null `FishForms` in data would still NPE in the consumer / `PondServer` on the same load. If the team wants hardening, it belongs as a one-shot guard at the `Record` level (e.g. initialize the field), not piecemeal here.

**Discovered by:** code-reviewer agent.

## Notes

- N-1 (Info): the fix assumes a weather `Fish` entry is *either* single-species (`fishGroupId` unresolved → synthetic group from `_name`) *or* group-bound (`_name == None`), never both. If an entry ever had both a valid `_name` and a valid `fishGroupId`, the new code binds by group records and drops the `_name` binding. This matches the consumer (which keys by group species), so it is the correct unification, not a regression — noted only as a documented assumption.
- N-2 (Info): the added tests have no `[TestInitialize]` (only `[TestCleanup]` resetting the global `Settings` fish table). Pre-existing pattern in the suite, not introduced by this commit.

## Investigation Journal

- Intake: commit list taken from JIRA comment at face value (Yuriy Burda, MFT @ r16121).
- Executor field (`customfield_11224`) empty in JIRA; commit author per JIRA comment = Yuriy Burda.
- Branch context: r16121 on MFT (Code role), post branch-copy (MFT from LBM:15942) → lives only on MFT; no branch-copy inheritance applies. No cross-branch merge noted in JIRA — consistent with FTUE 2026.4 developed on the Code branch.
- VCS audit: `svn log -r 15943:HEAD MFT | grep 43835` → single match r16121; matches intake.
- WC note: `WeatherServer.cs` on disk is at r16119 (pre-fix, last-changed r15412); diff read directly from repository via `svn diff -c 16121`.
- Verified single-species equivalence: `Fish.FinishInitialization` builds a synthetic 1-record group (`FishName=_name`, `FishForms` = union of layer forms) when `_fishGroup == null`, so `AllFish` + `record.FishForms.Contains(form)` reduces to the old `GetFishId(fish.Name, form)` path. Covered by the single-species test.
- Verified init ordering: `Weather.FinishInitialization` runs `Fish[i].FinishInitialization` (builds `_fishGroup`) before `FinishInitializationServer()` → `fish.AllFish` never dereferences a null group.
- Verified null-safety: `record.FishForms.Contains` mirrors the existing consumer `FishHasNonZeroChart` which already iterates `fish.FishForms`; non-null is an existing system invariant, fix introduces no new risk.
- Verified test validity: `BiteSystem.csproj` defines `BITE_SYSTEM_SERVER` unconditionally → `FinishInitializationServer` is compiled and the tests exercise the server path (not vacuous).
- Per-site audit: `fishIdTimeCharts` is private to the `Weather` partial; `WeatherServer.cs` is the only producer. `PondServer.cs` already iterates `f.AllFish`. Fix site is unique.
- code-reviewer agent dispatched (independent validation): confirmed Q1/Q3/Q4/Q5/Q6; surfaced F-1 (null `FishForms`). F-1 resolution = Accepted after grep-verifying the non-null invariant across 8 unguarded sites. Verdict unchanged.
