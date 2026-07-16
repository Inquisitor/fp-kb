---
status: resolved
executor: Yevhenii Shust
branch: NPN20260602 @ r16270, merged to MFT20260325 @ r16327
jira: https://fishingplanet.atlassian.net/browse/FP-42522
---

# Review: FP-42522 — FTUE. PremPomo. Client - Player Profile (min)

## Summary

Primarily a client task: revamp of the Player Profile screen for the premium promo (FTUE) — highlight active Premium state, add "Buy Premium" button opening the upsell window, add a Services section (Repair Kits, Marker/Navigation Buoys, Tackle Template Slots, Recipe Slots), replace trophy cup icons with the Hall of Fame tournament cup images.

Server-side scope is a single commit updating the `StatsCounterType` enum (tournament trophy counters for the profile). Populating the new counters (`TourWon`/`Tour2nd`/`Tour3rd`) and restoring historical tournament data was split into a separate server task FP-44889 (own review: `FP-44889--tournament-trophy-counters`) — out of scope here.

## Scope

Audited against `svn log | grep FP-42522` on NPN20260602 and MFT20260325 — matches the JIRA comment exactly; no unlisted server commits. Merge r16270 → MFT required (FPA team, ships with the MFT release "2026.5 Anniversary"), and it must land BEFORE the FP-44889 merge set (r16312,16313,16317,16325), which is blocked on it.

### NPN20260602
- **r16270** — Updated the `StatsCounterType` enum (author per JIRA comment: Yevhenii Shust)

### Unity_Fishing_CodeBranch (client — context only, not in server review scope)
- **r56112** — StatsCounterType enum mirror (Yevhenii Shust)
- **r56123** — Profile UI: trophies split Comp/Tour, Services section, Buy Premium button, premium frame texture, localization keys (Sergii Karchavets)
- **r56264** — localization refresh: "active until" wording + full translations (Sergii Karchavets)

All three verified present in MainClient at close (arrived via regular Code→Content bulk merges) — no client merge action needed.

## Investigation Journal

- Intake 2026-07-16: Executor field (`customfield_11224`) empty in JIRA — surfaced as hygiene warning; executor taken from commit-comment author (Yevhenii Shust), not JIRA assignee.
- Branch per JIRA comment: "NPN" = NPN20260602, Code role at review time. r16270 > branch base r16131 → commit genuinely on NPN, not inherited.
- Related: FP-44889 spun off from this task for server counter population + historical data restore; reviewed separately.
- VCS audit: `svn log | grep FP-42522` on NPN (16131:HEAD) and MFT (15943:HEAD) — exactly one server commit, NPN r16270; nothing on MFT. Matches JIRA comment; no executor-quality findings on commit posting.
- WC freshness: NPN WC at r16324 ≥ r16270 → disk reads trustworthy. Caveat: HEAD `PlayerStats.cs` differs from post-r16270 state — FP-44889 r16312 relocated the three members to the enum end. Delegated reviewers warned to evaluate r16270 as of its own revision.
- Recon: r16270 inserts `TourWon`/`Tour2nd`/`Tour3rd` mid-enum (after `TourBigFish`, before `FloatScriptedFish`), violating the file's explicit `// !ATTENTION! Values of this enum MUST be added ONLY to the end` invariant. Ground truth of the defect: the executor himself relocated the members to the end in r16312 (FP-44889) 8 days later.
- Persistence surfaces verified server-side: `StatsCounter.Type`, `CounterCondition.CounterType`, `AchievementStageConfig.CounterType` all carry `[JsonConverter(typeof(StringEnumConverter))]`; `GenericStats` dictionary keys serialize by name in Json.NET; grep found no `(int)` casts of `StatsCounterType` anywhere on the branch → no server-side numeric persistence surface for the shifted window.
- Cross-ref FP-44889 review card: shifted values (r16270..r16311) were live only on TEST2 (pre-release); merge ordering agreed there — this review's r16270 → MFT must land BEFORE FP-44889's merge set (r16312,16313,16317,16325).
- MFT WC check: the applied-but-uncommitted r16270 merge left over from the FP-44889 session is confirmed reverted — `PlayerStats.cs` absent from `svn status` on MFT WC (remaining local mods belong to unrelated in-flight tasks).
- Client mirror check: MainClient checkout `Assets/Photon Server Networking/ObjectModel/Stats/PlayerStats.cs` has `TourWon` mid-enum → r56112 mirror already present in MainClient at the pre-relocation position; relocation mirror r56379 arrives with FP-44889's client merge.
- Step 6 delegation launched: code-reviewer agent + Codex (gpt-5.6-sol), both blind (no recon findings pre-shared), both instructed on the later-commits-on-HEAD caveat with `svn cat -r 16270` / `svn diff -c 16270` as source of truth for the reviewed state.
- Codex (blind) returned two Mediums — no producer for the new counters, no backfill of historical trophies. Both code observations correct, but defect status refuted by task context Codex lacked: the executor flagged the gap himself in JIRA the same day ("Server implementation is required...") and spun it into FP-44889 (r16313 producer, r16317 backfill); merge ordering ships them together. Folded into one Info finding (F-2). Codex explicitly declined to rank the ordinal shift as a defect (no int surface found; cited `ProfileSerializationHelper` compressed-JSON persistence and `Enum.GetName` on the Photon wire).
- code-reviewer agent (blind) returned one High — the mid-enum insertion violating the file's append-only rule; converges with recon. Independently verified: no ordinal-indexed structures over `Enum.GetValues`/`.Length`, no SQL patches / Mongo class maps / WebAdmin tables referencing `StatsCounterType` by raw integer, no duplicate names, naming consistent with `CompWon`/`Comp2nd`/`Comp3rd`.
- Delegate disagreement on the placement violation (agent: High; Codex: not-a-defect) resolved by code + release context: wire name-transfer re-verified directly (`GameClientPeer_Game.cs` lines 549/791), no realized damage surface, TEST2-only window, superseded by r16312 → carded as F-1 Medium / Skipped-superseded. Disagreement surfaced to user in the findings discussion.
- Close: release-step gate — no options derivable from the diff (single .cs file, no SQL/NoSql/services/conversions); `customfield_11323` empty, consistent → pass without field edit. Executor field re-fetched at close — now filled (Yevhenii Shust), intake warning cleared.
- Close: merge direction deviates from the standard role table (source = Code → normally no targets): FPA-team task ships with the MFT release "2026.5 Anniversary" → cherry-pick NPN r16270 → MFT, per the ordering agreed in the FP-44889 review. MFT holds the mid-enum state transiently until the FP-44889 merge set lands.
- Close (user direction): client commits checked for MainClient presence — `svn mergeinfo` eligible list empty for r56112/r56123/r56264 AND per-commit content tokens verified in the MainClient checkout (r56112: `TourWon` in PlayerStats.cs; r56123: `tourn3rd`/`LevelPremiumFormatNoTags`/`_buyPremium`/`Avatar-Prem-Frame.png`; r56264: "active until {0}" present, old "active before {0}" absent, RU translations present). All three arrived via regular Code→Content bulk merges — no client merge performed, no Merged → MainClient claim in the JIRA comment.

## Findings

### F-1: Enum members inserted mid-enum in violation of the append-only invariant [Medium]

**Description:** r16270 adds `TourWon`/`Tour2nd`/`Tour3rd` after `TourBigFish` instead of the enum tail, directly violating the file's explicit `// !ATTENTION! Values of this enum MUST be added ONLY to the end` rule (`PlayerStats.cs`, `StatsCounterType`). The enum has no explicit values, so every subsequent member's ordinal shifted by +3. No realized damage: all persistence/wire surfaces are name-based (`StringEnumConverter` on `StatsCounter.Type` / `CounterCondition.CounterType` / `AchievementStageConfig.CounterType`; `GenericStats` dictionary keys serialize by name; Photon events send `Enum.GetName`), and the shifted window (r16270..r16311) was live only on TEST2. Severity-justifying: the invariant is load-bearing against latent int surfaces (client Unity asset serialization, future analytics), and only luck of name-based coverage prevented corruption.

**Investigation:** Diff read; enum head/tail read at HEAD; grep for `(int)` casts of the enum across the branch (none); converter attributes verified on all three typed properties; Photon wire path re-verified directly (`GameClientPeer_Game.cs` 549/791 — `Enum.GetName`); release status checked (Code branch, pre-release; FP-44889 card confirms TEST2-only exposure); fix commit located via `svn log` on the file (r16312).

**Resolution:** Skipped — superseded by r16312 (FP-44889): the executor relocated the members to the enum end; client mirror r56379.

**Discovered by:** skill recon + code-reviewer agent (independent convergence); Codex traced the same fact but ranked it non-defect.

### F-2: r16270 alone adds display keys with no producer and no backfill [Info]

**Description:** The commit only declares the enum members; nothing increments them at r16270 (`ProcessTournamentResult` had no Tour*-place counting) and historical trophies are absent from persisted `StatsJson`. A client reading these counters against a server with only r16270 shows zero cups for everyone.

**Investigation:** Codex traced `GameClientPeer_Tournaments.ProcessTournamentResult` (no producer at r16270) and `ProfileHelper.GetProfileOutOfDto` (StatsJson load path). Cross-checked against the executor's same-day JIRA comment explicitly flagging that server implementation and data restore are required, and against the FP-44889 scope (r16313 producer, r16317 backfill).

**Resolution:** Accepted — deliberate task decomposition tracked by the executor in JIRA the same day; FP-44889 (reviewed separately) supplies producer + backfill, and the agreed merge ordering ships r16270 together with the FP-44889 set.

**Discovered by:** Codex.

## Verdict

Approve. The commit is a minimal, mechanically correct enum-key addition matching its message and the JIRA-declared scope. The one defect — mid-enum insertion violating the file's append-only invariant (F-1, Medium) — is already superseded by r16312 (FP-44889); no realized damage (all serialization surfaces name-based, shifted window TEST2-only). The functional incompleteness of the commit taken alone (F-2, Info) is deliberate decomposition tracked by the executor in JIRA the same day and covered by FP-44889.

Merge pending: server r16270 → MFT, strictly BEFORE the FP-44889 merge set (r16312,16313,16317,16325 → MFT; client r56379 → MainClient) — MFT holds the mid-enum state only transiently within the same merge session. Client mirror r56112 is already present in MainClient.
