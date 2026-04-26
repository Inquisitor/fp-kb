---
status: resolved
executor: Yuriy Burda
branch: LBM @ r15930
jira: https://fishingplanet.atlassian.net/browse/FP-42478
---

# Review: FP-42478 — UGC competition not in 'My Sport Event' after Apply without Ready

## Summary

Bug fix: a user-generated (UGC) custom competition did not appear in the player's `My Sport Event` window when the player only pressed `[Apply]` (`RegisterInCompetition`, IsApproved=0) and never pressed `[Ready]` (`ApproveParticipationInCompetition(true)`, IsApproved=1). The fix relaxes the approval predicate in the `GetPlayerTournaments` stored procedure so UGC tournaments are not gated on `IsApproved=1`.

## Scope

- **LBM r15930** — Fix UGC competition not showing in My Sport Event after Apply without Ready
  - Single file: `SQL/Patches/Main/Procedures/GetPlayerTournaments.sql`
  - WHERE clause: `AND p.IsApproved = 1` → `AND (p.IsApproved = 1 OR t.KindId = 4)`
  - Cosmetic: BOM removed from line 1; tabs → spaces in a few lines

## Investigation Journal

- Phase 1 intake from JIRA: single commit r15930 on LBM, executor Yuriy Burda; `customfield_11224` (Executor) empty — non-blocking nudge.
- Branch ancestry verified via `svn log` on the changed file in MFT URL: r15930 appears in MFT history (MFT was copied from LBM @ r15942; r15930 ≤ r15942 → inherited automatically). `Merged → MFT` line omitted from JIRA comment.
- Verified `KindId = 4` = `TournamentKinds.UserGenerated` (`Shared/Photon.Interfaces/Tournaments/TournamentKinds.cs`).
- Recon traced caller chain: `GetSportEvents → TournamentsCache.GetPlayerTournaments → DAL → sproc` — matches the executor-quality hint in Sergii's comment (`OpTimer.Start(... GetSportEvents)`).
- Hypothesis "sibling DAL method `GetActiveUserCompetitionParticipations` needs the same fix" disproven — all callers commented out (dead code).
- Hypothesis "BOM removal violates `.editorconfig`" disproven as actionable — 68 of 121 files in `SQL/Patches/Main/Procedures/` already lack BOM (drift across the directory, not specific to this commit); SQL Server tolerates either form.
- Hypothesis "`(p.IsApproved = 1 OR t.KindId = 4) AND p.IsDisqualified = 0` leaks unregistered UGC rows under LEFT JOIN" disproven via three-valued-logic walkthrough: `p.IsDisqualified IS NULL → UNKNOWN → row excluded`. Independent code-reviewer agent confirmed the trace.
- Behavioral note flagged for the "Ready cleared but not Unregistered" case: old behavior hid the participant, new behavior keeps them visible. Net improvement — the window is "My Sport Event," not "My Ready Tournaments." No regression.

## Findings

### F-1: Functional change `(p.IsApproved = 1 OR t.KindId = 4)` — correct fix [Info]

**Description:** The relaxed predicate gates UGC entries on registration (presence of the `TournamentParticipants` row + `IsDisqualified=0`) instead of approval. This matches the user-visible semantics of the `My Sport Event` window: a player who pressed `[Apply]` is registered and should see their pending UGC competition so they can `[Ready]` from the pond.
**Resolution:** Accepted.
**Discovered by:** skill recon.

### F-2: BOM stripped from `GetPlayerTournaments.sql` [Skipped]

**Description:** First-line BOM removed; `.editorconfig` declares `charset = utf-8-bom` for `[*]`. However, 68 of 121 files in the same directory are already without BOM, so this is a long-standing convention drift, not a per-commit regression. SQL Server tolerates both forms.
**Resolution:** Skipped (drift, not author's oversight).

### F-3: Commit message format outside FP convention [Skipped]

**Description:** Commit message is single-line `FP-42478 Fix UGC competition ...` — no `[Topic]` tag, no bullets, no JIRA URL. Project format expects `FP-#####: [<topic>] <summary>` + bullets per change.
**Resolution:** Skipped — non-blocking; mention as informal nudge if the executor-quality watchlist gets revisited.

### F-4: `customfield_11224` (Executor) empty [Skipped]

**Description:** JIRA Executor field not filled (expected: Yuriy Burda, the commit author).
**Resolution:** Skipped — detect-only nudge per the Phase 1 protocol; user decides whether to fill.

## Verdict

**LGTM** — dry approval (A1). Single-file SQL sproc fix; semantics verified end-to-end and via independent agent review. No merge needed (branch-copy inheritance covers MFT).
