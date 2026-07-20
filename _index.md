# Knowledge Base

## Active Tasks
| Task     | Topic                          | Status        | Path                                                                    |
|----------|--------------------------------|---------------|-------------------------------------------------------------------------|
| FP-41845 | fish-weight-gen-v2             | in-progress   | fishing-planet/tasks/FP-41845--weight-generation-v2/                    |
| FP-41929 | xbox-purchases                 | investigating | fishing-planet/tasks/FP-41929--xbox-duplicate-purchases/                |
| FP-43424 | kb-mapping                     | in-progress   | fishing-planet/tasks/FP-43424--server-kb-mapping/                       |
| FP-41595 | lbm-release-support            | in-progress   | fishing-planet/tasks/FP-41595--leaderboards-release-support/            |
| FP-43632 | gc-migration                   | in-progress   | fishing-planet/tasks/FP-43632--game-carrier-on-steam-ps-mobile-support/ |
| FP-43625 | matchmaking-maxwins            | in-progress   | fishing-planet/tasks/FP-43625--matchmaking-maxwins/                     |
| FP-32370 | po-test-coverage               | planning      | fishing-planet/tasks/FP-32370--personal-offers-test-coverage/           |
| FP-44337 | stats-tables-partitioning      | in-progress   | fishing-planet/tasks/FP-44337--stats-tables-partitioning/               |
| FP-44591 | twitch-no-email-linking        | planned       | fishing-planet/tasks/FP-44591--twitch-no-email-linking/                 |
| FP-44594 | cpu-memory-map                 | planning      | fishing-planet/tasks/FP-44594--server-cpu-memory-map/                   |
| FP-44598 | buoy-backup-restore            | in-progress   | fishing-planet/tasks/FP-44598--buoy-backup-restore/                     |
| FP-44596 | node-load-observability        | in-progress   | fishing-planet/tasks/FP-44596--node-load-observability/                 |
| FP-42677 | rating-abuse-prevention        | in-discussion | fishing-planet/tasks/FP-42677--rating-abuse-prevention/                 |
| FP-44670 | club-redelivery-damage         | in-progress   | fishing-planet/tasks/FP-44670--club-donation-redelivery-damage/         |
| FP-33074 | chat-messages-disappear        | implementing  | fishing-planet/tasks/FP-33074--chat-messages-disappear/                 |
| FP-44725 | abtests-cache-refresh-reminder | planned       | fishing-planet/tasks/FP-44725--ab-tests-cache-refresh-reminder-on-prod/ |
| FP-44946 | git-workflow                   | in-progress   | fishing-planet/tasks/FP-44946--svn-to-git-migration/                    |

## Active Reviews
| Task     | Executor       | Path                                                                                    |
|----------|----------------|-----------------------------------------------------------------------------------------|
| FP-41962 | Stanislav      | fishing-planet/review/FP-41962--line-logging/                                           |
| FP-43705 | Yuriy Burda    | fishing-planet/review/FP-43705--bait-negative-values/                                   |
| FP-43817 | Yevhenii Shust | fishing-planet/review/FP-43817--tournament-log-levels/                                  |
| FP-44564 | Yevhenii Shust | fishing-planet/review/FP-44564--weather-seed-window-days/                               |
| FP-42918 | Yuriy Burda    | fishing-planet/review/FP-42918--profile-conversion-framework/                           |

## Active Confluence Work
| Draft                    | Task     | Target                                                                        |
|--------------------------|----------|-------------------------------------------------------------------------------|
| twitch-no-email-handling | FP-44591 | TECH > SERVER > Twitch integration (child) — published v2 (5696978945)        |
| git-flow-options         | FP-44946 | TECH > SERVER > Infrastructure (child) — published v6 (5768642569)            |

> See [confluence backlog](confluence/backlog.md) for the broader assessment plan.

> Completed tasks are removed from this table. History lives in task journals under `fishing-planet/tasks/`.

## Branch Roles (current)
| Role      | Server       | Client              |
|-----------|--------------|---------------------|
| Code      | NPN20260602  | CodeBranch          |
| Content   | MFT20260325  | MainClient          |
| Stable    | LBM20251201  | MainClient @ r52058 |
| OldStable | KNW20250723  | MainClient @ r47620 |
| OldStable | IMV20250220  | MainClient @ r47620 |

> Role definitions and colors: see [`CLAUDE.md` → Branch Roles](CLAUDE.md#branch-roles)
> Authoritative source: Confluence "Environment and branch status" (page id 68616199)
> Note: MainClient revisions newer than the Stable-pinned rev belong to Content.

## Releases (current)

Release↔branch mapping — one branch can host several releases at once; a reviewed commit's merge targets follow the RELEASE it ships with, not the role table alone (downward merges are user-directed; see `jira-review-close` → Step 3).

| Release                  | Ships from (server) | Status                                                                                                                                         |
|--------------------------|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| FTUE                     | MFT20260325         | Released on Steam/EGS, PlayStation, Xbox; not released on Mobile and Nintendo — expected to catch up via FPA                                   |
| 2026.5 Anniversary (FPA) | MFT20260325         | In progress, target 2026-07-27; continuation of FTUE from the same branch — in-branch boundary is the `F2PProtocolVersion` 1125→1126 increment |

> The client always releases from MainClient (per-release pin revisions: Branch Roles above).
> Update on each release cut / release-plan change.

## Server Branch Ancestry

Minimal ancestry for active branches — used to decide whether a commit is already inherited via `svn copy` and does not need explicit merge.

| Branch       | Base Rev | Based on          |
|--------------|----------|-------------------|
| NPN20260602  | r16131   | MFT20260325:16130 |
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
