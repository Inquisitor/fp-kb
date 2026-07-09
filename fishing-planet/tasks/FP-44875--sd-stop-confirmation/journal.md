---
jira: FP-44875
title: "Software Distributor: confirmation before stopping a node or a whole farm"
status: completed
executor: Stanislav Samoilov
created: 2026-07-09
type: story
---

# FP-44875 - Software Distributor: stop confirmation for nodes and farms

## Status
Delivered and live: confirm prompt on node Stop (both render paths, node name in the prompt) and on farm Stop - MFT r16293, merged to NPN r16294; versioned view hand-deployed to the SD host and verified live (hot-fix superseded, backed up as `Index.cshtml.bak-hotfix-20260709`). Deferred server-side Stop guard bubbled up to the server backlog. Parent epic: FP-44818 (Tech Debt 2026 Q3).

## Summary
Incident 2026-07-09: taking Game node Node69 out of rotation, the operator clicked "Stop" instead of "Remove" in Software Distributor; the node stopped instantly, dropping ~300-400 online players. A hot-fix (unconditional confirm on the JS-built Stop link) was applied directly on the SD host; this task lands the improved versioned fix, which supersedes the hot-fix on the next SD deployment.

Why the fix touches both render paths: the dashboard renders the node actions column from independent sources - Razor markup is only the first frame; a JS poller (`checkNodeStatus`, 2s interval via `/Home/GetStatus`) rewrites the `#actions` innerHTML wholesale after the first successful poll and keeps rewriting it. A guard only in the JS path leaves the unguarded Razor links clickable during the initial window, while `GetStatus` is failing, or permanently if page JS breaks. Farm header buttons are Razor-only (the poller does not rebuild them).

## Design decisions
- Confirm is unconditional: Stop is destructive regardless of the current peer count. A confirm-only-when-loaded variant (10+ peers threshold) was implemented first and dropped by decision.
- Node name for the prompt travels via a `data-name` attribute on the row (read with `attr()`), not the hot-fix's positional `td.eq(3)` lookup - survives column reordering.
- Client-side guard only: `HomeController.Stop` remains an unguarded GET; a server-side guard needs an SD rebuild/redeploy (deferred, see backlog).

## Plan
- [x] Recover and analyze the hot-patch from the SD host
- [x] Apply the improved patch to the MFT WC (node confirm in both render paths, farm confirm)
- [x] Create FP-44875 under FP-44818
- [x] Commit to MFT, comment the revision in JIRA
- [x] Merge MFT -> NPN

## Milestones
- 2026-07-09 [MFT] Recovered the hot-patch from the SD host, applied the improved patch to the MFT WC, created FP-44875 under FP-44818.
- 2026-07-09 [MFT r16293 -> NPN r16294] Committed the fix and merged to NPN; combined commit+merge comment posted on FP-44875.
- 2026-07-09 [prod] Hand-deployed the versioned view to the SD host (hot-fix backed up); confirm dialog verified live.
