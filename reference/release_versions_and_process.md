---
name: FP release versions and server-patch process
description: How Fishing Planet's JIRA fixVersions map to its release model (Internal/Async, Next Server Hotfix incubator, platform releases, "released-for-us"), why the JIRA "released" flag is misleading, the protocol-version increment as the release boundary, and the method to prepare a server patch (transfer/add classification, client-coupling, server-task identification)
type: reference
---

Fishing Planet's release model does not map cleanly onto JIRA's single `released` checkbox. A
fixVersion can be partly shipped, an incubator, or a continuous stream. This reference captures the
semantics and the method to prepare a server patch from a release branch.

## fixVersion types and semantics

- **Platform release** — e.g. `YYYY.N <Name> Steam/EGS`, `YYYY.N.M <Name> Consoles Release`,
  `... Mobile + Nintendo`. A specific feature release to a specific platform stack. Different
  platforms release the same content at different times, so the same content lives under several
  per-platform versions.
- **`YYYY.N.M.K ... Server Hotfix (<topic>)` / `... Server Patch (<topic>)`** — a server-only patch
  cut after a platform release. Naming convention: version + `Server Hotfix`/`Server Patch` +
  optional `(topic)` naming the biggest fix(es). These are the vehicle for post-release server code.
- **`Next Server Hotfix`** — an **incubator / collector**. Tasks that must ship in the next server
  hotfix (ASAP) are tagged here while it accumulates. When a concrete hotfix version is created, the
  selected tasks **move out** of `Next Server Hotfix` into that concrete version (it only holds
  tickets until a real version exists). JIRA description verbatim: "Release version that contains
  tasks that have to be released within the next server hotfix (i. e. ASAP)".
- **`Internal/Async`** — for work with **no code that ships with the server/WebAdmin/AsyncProcessor
  stack**: internal tools, one-off analytics scripts/reports, and the separately-hosted cross-platform
  services (Twitch, Webhooks). These release immediately when done, need no server-stack downtime, and
  are easily rolled back. It is **always semi-released** — each task stands on its own. Rule of thumb:
  *if a task has no code that releases with the server stack, it belongs in Internal/Async.*
- **`YYYY Releases`** — a year-level umbrella version; can co-tag a task alongside its real version.

**"Released for us"** — a release is considered released once its code has reached users, **even if
not on all platforms yet**. Example: `2026.3 Leaderboards` is "released for us" (code is with users)
though not every platform has it and JIRA may still show `released = false`.

**Therefore the JIRA `released` flag is not a reliable signal** for these version types — read the
version's role, not the checkbox.

## Protocol version = the release boundary

`<project>/Shared/Photon.Interfaces/SharedConsts.cs` holds `F2PProtocolVersion` (major) and
`MinorProtocolVersion` (minor). Error/analytics reports stamp `"{F2PProtocolVersion}.{MinorProtocolVersion}"`
(via `AnalyticsAdapter`), so the protocol version tells which release an error belongs to.

After a release ships from a branch, a commit **increments the minor protocol version** — message
pattern `[<BRANCH>] Increment minor protocol version after the <release>: <maj>.<old> -> <maj>.<new>`.
This commit is the **boundary** between released code and new post-release code:

- Commits at or before the increment rev = shipped in that release.
- Commits after the increment rev = new code that needs a patch vehicle.
- Branch history after the increment is the list of post-release work.

### Increment commit convention

Both major and minor increments are **standalone one-line, branch-local commits** — no FP-task
prefix, no JIRA link, no bullets — touching only `SharedConsts.cs`. **Increment commits are never
merged between branches**: the `[<BRANCH>]` prefix exists precisely to mark the commit as
branch-local (exclude it from upward merges); every branch commits its own increment.

- **Major** — when a branch enters its (next) release phase. A branch can receive more than one
  major bump if it carries consecutive releases (e.g. FTUE → FPA phases on one branch):
  `[<BRANCH>] Increment major protocol version for the branch: <maj>.<min> -> <maj+1>.0`
  — `MinorProtocolVersion` resets to 0 in the same commit.
- **Minor** — after each sub-release ships:
  `[<BRANCH>] Increment minor protocol version after the <release> release: <maj>.<min> -> <maj>.<min+1>`

The old value in the message is the actual current `major.minor`. `RetailProtocolVersion` is a
separate constant, untouched by F2P bumps. The new value reaches clients only via the per-branch
`Photon.Interfaces.dll` rebuild — see [Photon.Interfaces DLL distribution](photon_interfaces_dll_distribution.md).

The paired client-side DLL commit is also a standalone one-liner, prefixed `[Maintenance]` with the
server branch named by role:
`[Maintenance] Increment major protocol version for the <role> branch: <maj>.<min> -> <maj+1>.0`.
The dedicated commit is preferred; historically a bump has also reached the client piggy-backed on a
task commit that refreshed the DLL anyway.

**Pairing is atomic in time: the server increment commit and the paired client DLL commit always
land together (within the same minute).** Committing the server side while the client DLL is not yet
built and tested breaks every developer on that branch pair — their local client fails the protocol
gate against the updated server. Never commit the server increment until the paired DLL is built,
tested, and sitting in the client WC ready to commit.

## Preparing a server patch (method)

1. **Find the boundary** — `svn blame`/`svn log` `SharedConsts.cs` for the last "Increment minor
   protocol version" commit on the Code branch; its rev is the boundary.
2. **Collect post-release work** — `svn log -r <boundary+1>:HEAD` on the branch -> `FP-XXXXX` keys.
   These are all server tasks (server branch).
3. **Pull JIRA state** — status + fixVersions per key (request `fixVersions` explicitly).
4. **Classify each task for the new server version:**
    - **TRANSFER** (replace fixVersion) when the task has **no commit at or before the boundary** —
      purely post-release, never shipped; move it entirely to the new server version (drop the
      incubator / client-patch tag).
    - **ADD** (keep current + add the new version) when the task **had a commit at or before the
      boundary** — partially shipped in the prior release; keep the version where it shipped and add
      the new server version for the post-release fix.
    - Drop year-umbrella tags (`YYYY Releases`), if there is concrete release assigned; drop `Next Server Hotfix`
      on move (it leaves the incubator for the concrete version).
5. **Decide async vs sync with the client** — for each task, check the **paired client checkout** for
   the FP-ID (`svn log` the Content-role client `Win64_MainClient` and the Code-role `Win64_CodeBranch`).
   No client commit -> server can release **async**. Client commit present -> release the server patch
   **as close to the client release as possible**.
6. **Groom `Next Server Hotfix`** — its members not yet in the branch are merge/triage candidates;
   decide which belong in this patch and whether they need merging into the branch (respect merge
   direction OldStable -> Stable -> Content -> Code; only lower branches merge *into* Content, never
   Code -> Content). WebAdmin tasks deploy separately and need not gate the Photon server patch.

## Identifying server tasks in a mixed (mostly-client) release

A platform patch (e.g. `YYYY.N.1 ... Steam/EGS Patch 1`) is mostly client but accumulates server and
non-server tasks. **Server tasks = assignee was a server programmer** (the server devs at time of
writing: Stanislav Samoilov, Yuriy Burda, Yevhenii Shust). Find them with JQL `assignee was`:
`fixVersion = "<patch>" AND (assignee was "Stanislav Samoilov" OR assignee was "Yuriy Burda" OR
assignee was "Yevhenii Shust")`. Use `assignee was` (historical) because tasks get reassigned to QA
by the time you look.

A server task can legitimately have **no branch commit**: it may be analytics-only (Internal/Async),
its fix may have shipped pre-boundary (already released), or the fix arrived via a linked ticket's
commit. Read the comments before assuming it needs patch action.

## Related

- [Server Release Checklist Steps field](release_checklist_field.md) — `customfield_11323`, the
  per-task release-step tagging that the closure/review gate enforces
- Branch roles and merge direction: `_index.md` -> Branch Roles; `CLAUDE.md` -> Branch Roles
