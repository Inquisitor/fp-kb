# Pass 1 — handover for orchestrator

## Goal

Distribute all `LBM20251201` server-branch code across modules with file-level granularity for the subsequent Pass 2 (module card creation). Not a code review, not a refactoring — **map + catalogue + flag problems worth remembering**.

## Artefacts

`D:\kb\fishing-planet\tasks\FP-43424--server-kb-mapping\artifacts\`
- **`pass-1-inventory.md`** — Pass 1 execution output: solutions, projects, subfolders (immutable snapshot)
- **`pass-1-user-notes.md`** — expert annotations on Pass 1 (tools usage, classifications, naming)
- **`pass-1-classification-review.md`** (~25 KB after cleanup) — Pass 1.5 coarse classification + Naming caveats + uncertain questions. Cleaned: security findings extracted, detailed catalogue moved out
- **`pass-3-catalogue-draft.md`** — Pass 3 draft: file-level domain catalogue + detailed tool/test observations. Agent-generated in bulk during Pass 1; **needs curation** before Pass 6 emission
- **`folder-tree.md`** (~130 KB) — annotated folder tree with status and modules per folder (reference, read on-demand)
- All files are human-readable + grep-friendly; edit-in-place workflow (not rewrites)

**Out-of-repo (private):**
- Security findings file — auth gaps, SQL-injection risks, hardcoded secrets, typos in public APIs. Originally Section N of `pass-1-classification-review.md`, extracted per KB policy "no security root causes in KB"

## Process

1. **csproj-level classification** (Sections A-K) — every `.csproj` + top-level folder placed into a category: core / SharedLib / platform SDK / DAL / cross-cutting / standalone services / misc / tools H.1-H.3 / dead / non-code / tests / uncertain
2. **Batched file-level split** (originally Section M — module catalogue; later extracted to `pass-3-catalogue-draft.md`) — walked the tree in large blocks; for each block:
   - Explore-agent with a detailed request (file counts + LOC + classes + gotchas + module dispersal)
   - Manual verification of the report for module-assignment correctness
   - Added paths to corresponding existing modules in M
   - Created new modules when none fit
   - Added dangerous findings to N (no verbatim secret literals — **policy confirmed twice**; secrets-scan agent ran 2×)
   - In parallel — updated tree annotations: `# module:` / `# dispersed:` / `# dead:` / `# note:`
3. **Handback** after each block (brief summary + next-block suggest)

## Review structure (post-split)

`pass-1-classification-review.md` (Pass 1.5 — coarse classification):

| Section | Content                                                                                                                                          |
|---------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| **A-G** | csproj-level classification (core / SharedLib / platforms / DAL / cross-cut / standalone / misc)                                                 |
| **H.1** | 12 active tools (one-liners; details in catalogue)                                                                                               |
| **H.2** | 20 dead tools (one-liners)                                                                                                                       |
| **H.3** | empty after audit — previously unknown tools moved to H.1 or H.2                                                                                 |
| **I**   | Dead / abandoned (FGL / Updater / WebService / PowerDesigner)                                                                                    |
| **J**   | Non-code top-level (SQL / Build / lib / Monitoring / deploy / SqlServerProject CLR UDFs)                                                         |
| **K**   | Test projects (not individually reviewed; details in catalogue)                                                                                  |
| **L**   | Uncertain — questions for Pass 2-3 (some already resolved: async-farm-manager = farm-reboots / leagues UnitOfWork job runners = async-processor) |

`pass-3-catalogue-draft.md`:
- File-level domain catalogue (~60 domain modules) with paths, module assignments, detailed observations
- **Agent-generated in bulk** during Pass 1 — quality variable; first-block sections user-curated, later sections need validation
- Cross-cutting detail for ObjectModel / Photon.Interfaces, tool internals, test coverage (originally scattered across classification-review sections E / H / J / K)

Private out-of-repo:
- Security findings — SQL-injections / hardcoded secrets / auth gaps / XSS / typos. Extracted in multiple passes during the split. Do not re-introduce into KB.

## Coverage

Fully walked (file-level dispersal across domain modules):
- `Photon\src-server\` (LoadBalancing 4 apps + S2S + AntiCheat + CounterPublisher + GameModel)
- `Shared\` (13 subprojects)
- `Dal\` (10 subprojects + tests + CLR assembly)
- `AsyncProcessor\` (4 Windows services + test)
- `SoftwareDistributor\` / `Twitch\` / `WebServices\WebHooks\` / `WebAdmin\` (8 apps)
- `Photon\tools\` (28 tools)

~60 domain modules + 10 systems (game / monetization / social / travel / inventory / missions / progression / competitive / diagnostics / analytics).

## What was NOT done

- No merge against prior reviews / commit history — document is a snapshot of the branch
- No code editing
- No per-method deep-dive except god-methods >100 LOC
- No verification of live-deployment status (relying on user input)
- No secret values stored in KB (strict policy; secrets-audit agent verified 2× — clean)

## Key non-security risks identified

Security-related risks (secrets / injections / auth gaps) moved to the private audit file per KB policy.

- **Framework rot**: MVC 4.0 / .NET Framework 4.7.2 / Kendo 2013 / Photon SDK 4.x / SimpleMembership legacy / MongoDB legacy Query builder API
- **Typos in public API** (~15 cases): `OnlineCash` vs `OnlineCache` / `Achivment` / `Recepient` / `FiendFriends` / `OnJoinedGamed` / `IsVisbleInLobby` / `IsIncongnito` / `JobFrequancy` / `Capitanicity` / `Lincense` / `Convertation` / `_Peristence` / `SimbolsCount` / `Couters` — every rename is a breaking change

## State

Pass 1 complete. Files are ready for Pass 2 (module cards — one `.md` file per module, driven by file paths + descriptions from `pass-3-catalogue-draft.md`). Heaviest inputs for Pass 2: cross-cutting caches (`cache` module with 56 domain-cache classes) + god-module `profile-management` (~25 touch-modules) + `game-state` (GameProcessor 5867 LOC).
