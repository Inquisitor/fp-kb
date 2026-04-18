# FP-43424 Plan — Server Architecture & Map

## Phases overview

Seven-pass plan. Each pass leaves an artifact; the next pass reads prior artifacts to bootstrap context.

| Pass | Goal                                                | Artifact                                 | Done when                                               |
|------|-----------------------------------------------------|------------------------------------------|---------------------------------------------------------|
| 0    | KB readiness — policies and task structure          | KB `CLAUDE.md` updated; task dir created | This session                                            |
| 1    | Mechanical inventory of solutions / projects / dirs | `artifacts/pass-1-inventory.md`          | Every `.sln`/`.csproj` + key subfolders classified      |
| 2    | Layered architecture analysis                       | `artifacts/pass-2-layers.md`             | Each project mapped to one or more layers               |
| 3    | Domain analysis                                     | `artifacts/pass-3-domains.md`            | Each project mapped to one or more domains              |
| 4    | Cross-reference — gaps and conflicts                | `artifacts/pass-4-crossref.md`           | Conflicts and gaps reviewed                             |
| 5    | System grouping — crystallize systems from Pass 2+3 | `artifacts/pass-5-systems.md`            | ~8-12 systems defined; each module has one system       |
| 6    | Index emission — stubs + overviews + `_index.md`    | Real KB files                            | All modules have stub cards; all systems have overviews |

### What happens after Pass 6

Initial mapping closes. We switch to **post-mapping operations** (pilot deepening, skills for VCS-scan and review-sync, organic growth). These are **out of scope for this task** — spawn a separate task when we get there.

## Dependencies

```
Pass 0 → Pass 1 → { Pass 2 | Pass 3 (parallel) } → Pass 4 → Pass 5 → Pass 6
```

Only Pass 2 and Pass 3 are parallelizable. The rest is strictly sequential.

## Iteration model

- Each pass runs in its own session (or multiple, for large passes — e.g. Pass 6 emission).
- After each pass: a short reflection loop in a separate session — validate the artifact, check for missed items, refine the next pass's runbook.
- Ideas and deferred items flow to `backlog.md` immediately — not held in conversation.

## Tooling notes

- **Sub-agents (`Agent` tool with `Explore`)** for parallel directory walks in Pass 1 and Pass 6. Each returns a compact table.
- **No agent teams** (experimental `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` feature) — overkill for our workflow.
- **Context preservation across sessions** via `journal.md` Status + final artifact of the last completed pass. Session bootstrap: read KB `CLAUDE.md` → this plan → last artifact.

## Pass 1 — Runbook

**Goal:** full inventory of every solution, project, and top-level directory that might contain code worth mapping. **Classification, not analysis** — no code reading yet.

### Inputs

- Server repo root: `D:\FishingPlanet\src\server\svn\branches\LBM20251201\` — Content branch, used as Code proxy for Pass 1 only. MFT took the Code role on 2026-04-06, so structural divergence is minimal at inventory level. Record the LBM revision at inventory time in the artifact header. Re-check against MFT in Pass 2+ when content differences matter.
- Server `CLAUDE.md` (lists main solutions and key paths)

### Procedure

1. **Walk every `.sln` file** in the repo. For each:
   - Record name and path
   - List contained `.csproj` files

2. **For each `.csproj`:** record path, type — one of:
   - `production` — shipped code
   - `tests` — test project (record but do not deep-dive)
   - `tool` — helper / utility (e.g. `TestClient`, `JsonVerificator`)
   - `infra` — scaffolding (e.g. `Dal.Common`, `Async.Common`)

3. **Walk top-level directories 2 levels deep** inside known big projects (`SharedLib`, `WebAdmin`, `Loadbalancing/LoadBalancing`, `Dal`). Record subfolders + purpose-signal **from folder name only, no code reading**.

4. **Classify each path** with a `nature` field:
   - `module` — clear logical unit with entry point (tentative)
   - `module-part` — sub-component of a larger module (e.g. a specific algorithm file)
   - `cross-cutting` — shared utility (logging, helpers)
   - `tests` / `generated` / `config` / `trash` — non-module

5. **Parallelization:** spawn `Explore` sub-agents for independent big directories (one per top-level: `Loadbalancing`, `Shared`, `Dal`, `AsyncProcessor`, `WebAdmin`). Each returns a compact table. Main session merges results.

### Output format (`artifacts/pass-1-inventory.md`)

````markdown
# Pass 1 — Inventory

Branch at inventory time: `<branch>` r`<rev>`

## Solutions
| Solution | Path | Projects count |
|---|---|---|

## Projects
| Project | Path | Type | Nature | Notes |
|---|---|---|---|---|

## Key subfolders (2 levels deep under big projects)
| Path | Nature | Purpose signal |
|---|---|---|
````

### What to defer

- Reading code inside files — wait until Pass 2/3
- Deciding "what is a module" boundary — tentative now, firmed up by Pass 5
- Naming systems — that's Pass 5's job

### Completion check

- Every `.sln` / `.csproj` in the repo is in the inventory
- Every subfolder under top-level big projects is in the inventory
- Nothing missing (verify with a final recursive `ls` pass)

### Estimated effort

1-2 hours (mostly parallel sub-agent walks + merge into one artifact).

## Passes 2-6 — Runbooks

Not yet written. **Principle:** only detail the next pass; keep later passes as one-liners until we're there. Write the Pass 2 runbook at the end of Pass 1's reflection session, etc.
