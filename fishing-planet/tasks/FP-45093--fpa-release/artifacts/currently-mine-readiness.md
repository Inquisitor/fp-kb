# 2026.5 Anniversary (FPA) — ledger of every task that passed through the lead

Snapshot: **2026-09-17**. The release shipped on Steam 2026-07-30, PlayStation 2026-08-04 and Xbox
2026-08-05 (all on SRV/16375, protocol 1126.0); Mobile and Nintendo are still pending. Of the 43 tasks
this ledger tracked through the cycle, **28 have closed**; the 15 below are what is left.

> **Where it stands:** only three tasks still carry `2026.5 Anniversary`, and just one of them needs any
> work — FP-45166. The other twelve left the release during the scope trim and now belong to
> 2026.6 Australia, Next Server Hotfix or Internal/Async; they are tracked with those releases, not here.

## A. Still in 2026.5 Anniversary (fixVersion 16274)

| Key | Title | Status | Holder | What it needs |
|-----|-------|--------|--------|---------------|
| FP-45166 | Server: enforce client/server protocol version compatibility | **In Review** (+ Next Server Hotfix) | Stanislav | reopened for rework and will not ship as it stands; the FPA tag is legitimate — the first part shipped in `r16363` before the boundary — and the rework waits in Next Server Hotfix |
| FP-43181 | Hints — parameter that allows to hide tasks even in menu | Resolved (+ 2026.4 FTUE) | Andrii | reporter to close |
| FP-44701 | Mission ID 435 was completed twice by the same user | Resolved | Stanislav | reporter to close |

The version is flagged released, so these three are what keeps it from closing cleanly.

## B. Left the release during the scope trim — tracked elsewhere

Out of scope for FPA work; listed so the ledger stays complete.

| Key | Title | Status | Now in |
|-----|-------|--------|--------|
| FP-41593 | Steam global chat — restricted-country | Resolved | Next Server Hotfix + 2026.6 Australia |
| FP-41616 | Weather: cleanup regen UI | In Review | Next Server Hotfix + 2026.6 Australia |
| FP-41627 | Weather: new lookup tables | In Review | Next Server Hotfix + 2026.6 Australia |
| FP-42124 | RU players not banned in clubs | In Review | Next Server Hotfix + 2026.6 Australia |
| FP-44680 | No tablet icon, broken FishId 3038 | In Review | Next Server Hotfix + 2026.6 Australia |
| FP-41625 | Weather: save per-pond param | In Review | 2026.6 Australia |
| FP-44730 | Donate Dragonfly Nymphs 32706/07 vs 08 | In Review | 2026.6 Australia |
| FP-44794 | Server.UI — New Pond Event's Icons | In Review | 2026.6 Australia — retitled `AUSTRALIA MISSIONS`, it changed allegiance, not just version |
| FP-44846 | ProfileSerializationHelper nulling profile fields | To Do | 2026.6 Australia |
| FP-41256 | Norway Weather Randomizer DeEngineering | In Review | Internal/Async |
| FP-40968 | WebAdmin — ban player by Mac/IP | In Review | **no fixVersion** — out of every release |
| FP-31878 | GD — Fix Autotracking Mission System | To Do | **no fixVersion** — FPA tag removed 2026-07-30, unspeced GD work |

## Notes

- Eleven of the fifteen sit with the lead, but only two of those (FP-45166, FP-44701) are inside FPA —
  the rest is the Australia and hotfix queue.
- This ledger was built per release and has outlived it: it is now a lead's queue spanning three releases.
  Either it gets re-pointed at a new subject, or the Australia rows move out and it closes with FPA.
- Verification discipline: JQL is the live membership source (`key in (...) AND statusCategory != Done`
  keeps the closed ones out of the way); a commit in the log is not code in the branch — confirm branch
  state before claiming a task ships.
