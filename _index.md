# Knowledge Base

## Active Tasks
| Task     | Project   | Topic               | Status        | Path                                                                    |
|----------|-----------|---------------------|---------------|-------------------------------------------------------------------------|
| FP-41845 | FP/server | fish-weight-gen-v2  | in-progress   | fishing-planet/tasks/FP-41845--weight-generation-v2/                    |
| FP-41929 | FP/server | xbox-purchases      | investigating | fishing-planet/tasks/FP-41929--xbox-duplicate-purchases/                |
| FP-43424 | FP/server | kb-mapping          | in-progress   | fishing-planet/tasks/FP-43424--server-kb-mapping/                       |
| FP-41595 | FP/server | lbm-release-support | in-progress   | fishing-planet/tasks/FP-41595--leaderboards-release-support/            |
| FP-43632 | FP/server | gc-migration        | in-progress   | fishing-planet/tasks/FP-43632--game-carrier-on-steam-ps-mobile-support/ |
| FP-43625 | FP/server | matchmaking-maxwins | in-progress   | fishing-planet/tasks/FP-43625--matchmaking-maxwins/                     |

## Active Reviews
| Task     | Executor    | Path                                                                                       |
|----------|-------------|--------------------------------------------------------------------------------------------|
| FP-41962 | Stanislav   | fishing-planet/review/FP-41962--line-logging/                                              |
| FP-42016 | Yuriy Burda | fishing-planet/review/FP-42016--pond-pass-expired-on-globe-exit/                           |

## Active Confluence Work
(none yet — see [confluence backlog](confluence/backlog.md) for assessment plan)

> Completed tasks are removed from this table. History lives in task journals under `fishing-planet/tasks/`.

## Branch Roles (current)
| Role      | Server       | Client              |
|-----------|--------------|---------------------|
| Code      | MFT20260325  | CodeBranch          |
| Content   | LBM20251201  | MainClient          |
| Stable    | KNW20250723  | MainClient @ r52058 |
| OldStable | IMV20250220  | MainClient @ r47620 |

> Role definitions and colors: see [`CLAUDE.md` → Branch Roles](CLAUDE.md#branch-roles)
> Authoritative source: Confluence "Environment and branch status" (page id 68616199)
> Note: MainClient revisions newer than the Stable-pinned rev belong to Content.

## Server Branch Ancestry

Minimal ancestry for active branches — used to decide whether a commit is already inherited via `svn copy` and does not need explicit merge.

| Branch       | Base Rev | Based on          |
|--------------|----------|-------------------|
| MFT20260325  | r15943   | LBM20251201:15942 |
| LBM20251201  | r15396   | KNW20250723:15394 |
| KNW20250723  | r14593   | JLM20250520:14592 |
| IMV20250220  | r13733   | HFH20241126:13732 |

> **How to read**: row `<Branch>` was created at `<Base Rev>` as a copy of `<Based on>`. Everything on the source branch **at or before** the source revision is inherited in `<Branch>` automatically — no merge needed. Anything committed to the source branch **after** the source revision must be merged explicitly.
>
> **Inheritance check** (before any `svn merge`): if the commit rev on the source branch is ≤ the source-rev of the target branch's ancestry line, the change is already present. Skip the merge and omit the `Merged → <BRANCH>` line from the JIRA comment. `svn mergeinfo` does NOT reflect branch-copy inheritance; verify via `svn log` on a file the commit touched in the target branch.
>
> **Full history** (all branches back to trunk, with status/purpose/graph): Confluence "Environment and branch status" (page id 68616199) → Branch History table. KB mirrors only active branches; older ancestry lives in Confluence.
>
> **Refresh command**: `svn log --stop-on-copy -v <branch-URL> --limit 1 -r 1:HEAD` — the `A /branches/<name> (from /branches/<source>:<rev>)` line gives both fields.

## Quick Links
- [FP Server modules](fishing-planet/server/_index.md)
- [FP Client modules](fishing-planet/client/_index.md)
- [Confluence progress](confluence/_index.md)
- [Glossary](fishing-planet/glossary.md)
