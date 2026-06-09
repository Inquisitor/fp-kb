---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16118
jira: https://fishingplanet.atlassian.net/browse/FP-42686
---

# FP-42686: [WebAdmin][Competitions] System does not allow registering more than 1000 players in a competition

## Summary

WebAdmin Tools > Competitions test tool fails when registering more than 1000 test players:
`Cannot insert the value NULL into column 'UserId', table 'Main.dbo.TournamentParticipants'`.
Root cause per executor: not enough pre-generated test users exist, so registration of a range
beyond the pool inserts NULL UserIds. Fix adds test-user generation before competition
registration, and a new "Test Users" block on the Tools page.

## Scope

- **MFT r16118** — Fixed. Added user generation before registering for the competition; added
  a new separate "Test Users" block on the Tools page.

> Scope is taken from the JIRA comment at face value. To be audited via `svn log | grep` in Phase 2.

## Findings

### F-1: New "Test Users" UI block and the competition flow use different prefixes [Info]

**Description:** The new standalone `<li title="Test Users">` block (Tools.cshtml) binds to model field
`UserPrefix`, whose default is `"abc"` (`ToolsModel_Clubs.cs`). The competition range-registration path
(`ToolsModel_Competitions.RegisterInCompetition`) hardcodes `"tst"` for both generation and lookup. The two
paths are independent: the competition fix self-generates `tst*` users and does not read `UserPrefix` or the
new block. No defect — nothing breaks, no data risk. Observation only: a tester generating users via the new
block with the default prefix produces `abc*` users that the competition registration (`tst*`) will not pick
up, so the block is not wired to the competition use-case despite sitting next to it.

**Investigation:** Verified the two call paths are independent — `RegisterInCompetition` hardcodes `"tst"`
(`ToolsModel_Competitions.cs` + `SqlTournamentTestProvider`); the block routes through
`ToolsModel_Clubs.GenerateTestUsers` using `UserPrefix`. Confirmed end-to-end `tst` consistency for the
actual fix path.

**Resolution:** Accepted — observation, no action.

**Discovered by:** skill recon + code-reviewer agent.

### F-2: Cross-domain coupling — Competitions code calls `GetLeagueTestProvider().GenerateTestUsers` [Info]

**Description:** Test-user generation lives in `SqlLeagueTestProvider` but is now invoked from Competitions
model code. Architectural smell (test users for Competitions routed "through leagues"). No compile/runtime
issue — `ILeagueTestProvider.GenerateTestUsers` is a defined interface method.

**Investigation:** Confirmed interface method exists; executor self-flagged this in the JIRA comment and
proposed a dedicated refactor task (move `GenerateTestUsers` to a `TestUsers` provider).

**Resolution:** Filed → FP-44358 (Story under epic FP-43213 "Technical Debt - 2026 Q2"). Not blocking.

**Discovered by:** executor's comment (confirmed by recon).

### F-3: "tst" prefix duplicated across constants and a call-site literal [Info]

**Description:** `TestNamePrefix = "tst"` is defined independently in both `SqlTournamentTestProvider` and
`SqlLeagueTestProvider`, and passed again as a literal `"tst"` from `ToolsModel_Competitions`. The explicit
arg is redundant (the param default is already `"tst"`). If any copy drifts, generation and registration
desync silently → 0 users registered (no crash, thanks to the `IS NOT NULL` guard). Largely pre-existing.

**Investigation:** Grepped `TestNamePrefix`/`GenerateTestUsers` across Dal; confirmed three independent
sources of the literal.

**Resolution:** Skipped — minor, pre-existing pattern.

**Discovered by:** skill recon.

## Verdict

**Approve.** The fix correctly resolves FP-42686: app-level `GenerateTestUsers(start, end, "tst")` creates the
missing test users (root cause of the NULL `UserId`), and the SQL `WHERE nu.UserId IS NOT NULL` guard defends
against any residual NULL insert (the exact symptom in the stack trace). Generation is idempotent
(`INSERT ... WHERE UserId IS NULL`), prefix is consistent within the fix path, no compile/runtime break, no
data-integrity risk. Findings F-1..F-3 are non-blocking (Info). Minimal, well-targeted diff. Scope is WebAdmin
test-tooling on test servers only — no player-facing or server-logic surface.

Note for QA hand-off: the `IS NOT NULL` guard makes under-generation silent (registered `count` can be less
than requested without an error). Worth verifying that the exact requested number registers, not merely the
absence of an error.

## Investigation Journal

- Intake from JIRA: executor = Yevhenii Shust (commit author per comment), branch = MFT @ r16118.
- ⚠ Executor field (`customfield_11224`) empty in JIRA — detected, not auto-filled.
- VCS audit: `svn log -r 15943:HEAD | grep FP-42686` → exactly one commit r16118 (yevhenii.shust),
  matches JIRA; `svn log -c 16118 -v` → 3 files. No commit-vs-JIRA mismatch.
- Hypothesis "new UI block breaks compile (missing model props / JS / action)" — disproven: `UserPrefix`/
  `UserRange`, JS `GenerateTestUsers()` (Tools.cshtml:550), and the `generateTestUsers` handler all
  pre-existed in the Clubs partial; the block only reuses them.
- code-reviewer agent confirmed the core conclusion. Its finding #6 (duplicate `title="Test Users"` cookie-key
  collision with a Clubs block) was REFUTED by `grep title="Test Users"` → single occurrence; the agent
  conflated the Clubs `<li>`'s internal Generate-control with a separate titled block.
- Branch-copy inheritance: NPN20260602 (Code) created at r16131 = copy of MFT@r16130; r16118 ≤ 16130 —
  verified r16118 present in NPN history of `SqlTournamentTestProvider.cs` via `svn log`. Already inherited,
  no merge. MFT=Content merges only into Code (NPN) per role chain; LBM (Stable) is below, not a target.
  Net: zero merges. JIRA comment omits all `Merged →` lines.
- Closed: approve, dry LGTM + QA hand-off (verify exact registered count on the 1100 scenario). Cross-domain
  `GenerateTestUsers` refactor filed as FP-44358 (per executor's request). QA-handoff rationale: the original
  alarm about a "silent under-count" was walked back — generation covers the full requested range, so the
  `IS NOT NULL` guard removes only the crash, not legitimate rows; under-count is patological, not the reported path.
