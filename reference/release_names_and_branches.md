---
name: FP release names and server-branch mapping
description: Canonical JIRA release naming (version-first, e.g. "2026.5 Anniversary"), short-code synonyms (FPA / FTUE / LB-MM), the release-to-server-branch map, and the non-release buckets
type: reference
---

## Naming convention

Name a release **version-first, then name — exactly as its JIRA fixVersion reads**:
`2026.5 Anniversary`, `2026.6 Australia`, `2026.4 FTUE`. In JIRA a platform / qualifier trails the name
(`2026.4 FTUE Steam/EGS`, `2026.4.2 FTUE Consoles Release`, `2026.4.2.1 FTUE Server Hotfix`).

- Do **not** invent abbreviations — write version + name.
- If the name is long, the **version alone** suffices.
- The short codes below (FPA, FTUE, LB/MM) are for recognition/synonyms, not for writing release labels.

## Release names, synonyms, corresponding branches

Each major release maps to **one server branch**; a branch may host **consecutive** releases; the branch codename
encodes its original topic. Buckets carry no version and are not branch-scoped — their semantics are
in [release versions and process](release_versions_and_process.md).

| Kind     | Release                   | Abbreviations | Server branch | Note                                                                                                     |
|----------|---------------------------|---------------|---------------|----------------------------------------------------------------------------------------------------------|
| retail   | The Fisherman (Retail)    | Retail        | MI20200128    | 2020 Monetization Improvements branch, still live; maintenance only. Retail ships Steam / PS / Xbox only |
| release  | 2025.5 Maldives           | MV            | IMV20250220   | Maldives (country code MV)                                                                               |
| release  | 2025.8 Norway             | NW, NO        | KNW20250723   | Norway                                                                                                   |
| release  | 2026.3 Leaderboards       | LB/MM         | LBM20251201   | Leaderboards/Matchmaking                                                                                 |
| release  | 2026.4 FTUE               | FTUE          | MFT20260325   | FTUE (First-Time User Experience) Rework                                                                 |
| release  | 2026.5 Anniversary        | FPA           | MFT20260325   | same branch — continuation of FTUE; in-branch boundary = `F2PProtocolVersion` 1125 -> 1126               |
| release  | 2026.6 Australia          | AU, AUS       | NPN20260602   | New Pond                                                                                                 |
| release  | 2027.1 Father's Day Event | FD            | TBD           | content split out of 2026.5 into its own version                                                         |
| bucket   | Next Server Hotfix        | NSH           | —             | rolling ASAP collector; tasks move out into a concrete hotfix version when one is cut                    |
| bucket   | Internal/Async            | —             | —             | no code shipping with the server stack; released as each task is done                                    |
| umbrella | 2027 Releases             | 2027          | —             | year-level catch-all; can co-tag a task alongside its real version                                       |
| bucket   | LiveOps for all platforms | —             | —             | live-ops work, not tied to a stack release                                                               |

Notes:

- A server branch is `<3-letter codename><YYYYMMDD-created>`; the **codename encodes the branch's original dev topic**,
  which is often NOT the release name that eventually ships from it (2026.6 Australia ships from the "New Pond" branch
  NPN).
- The branch **rotates roles** (Code / Content / Stable / OldStable) each release cycle, so map a release to the branch
  **folder name**, never to the role.
- A release spawns per-platform and patch fixVersions (`... Steam/EGS`, `... Consoles Release`,
  `... Mobile + Nintendo`, `....1 Server Hotfix`); they all belong to the **same branch** as the parent.
- The client always releases from `MainClient`.

## Older releases

Before 2025 the versions were not named version-first — e.g. `All platforms Patch 9 [Halloween event
release]`, `All platforms Dnipro Release 10`, `2024.12 Patch 10 & Kherson Release` — so the join between a version name
and a branch cannot be read off the name. Those branches are still listed, with the topic each was created for and the
ancestry graph, in the Confluence Branch History (below).

## Related

- [FP release versions and server-patch process](release_versions_and_process.md) — fixVersion semantics (buckets,
  "released-for-us"), protocol-increment boundary, patch-prep method.
- `_index.md` -> Releases (live release↔branch), Branch Roles (role assignments + client pin revisions), Server Branch
  Ancestry (fork revisions).
- Confluence "Environment and branch status" (page id 68616199) → Branch History — every branch with its original
  purpose, status and the ancestry graph.
