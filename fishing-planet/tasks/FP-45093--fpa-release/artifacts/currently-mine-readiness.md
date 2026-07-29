# 2026.5 Anniversary (FPA) — ledger of every task that passed through the lead

Snapshot: 2026-07-29 (**release day**). Every task assigned to Stanislav at any point in the 2026.5 Anniversary cycle,
with its final disposition. Grouped by where it landed (in-release vs rerouted) and status.
`Holder` = current JIRA assignee (where it sits now). Releases are named version-first, as in JIRA (2026.5 Anniversary,
2026.6 Australia, 2026.4 FTUE); `Next Server Hotfix` is a rolling ASAP bucket (unversioned). Release↔branch map:
`_index.md` → Releases (2026.5 Anniversary ships from MFT20260325).

> **Bottom line:** 2026.5 Anniversary is shipping clean. Everything still tagged to it is Resolved/Closed
> except **FP-45166** (protocol gate, Reopened) — it goes out with the **Next Server Hotfix**, not blocking
> the cut. No lead action left inside the release. Sensitive-tail / non-critical work was rerouted to
> Next Server Hotfix / 2026.6 Australia.

## A. In 2026.5 Anniversary (fixVersion 16274)

### Open — needs the hotfix

| Key      | Title                                  | Status       | Holder                                                        |
|----------|----------------------------------------|--------------|---------------------------------------------------------------|
| FP-45166 | Server: enforce protocol compatibility | **Reopened** | Yuriy Burda (→ Next Server Hotfix; server code in MFT r16363) |

### Resolved — awaiting reporter to Close (no lead action)

| Key      | Title                                     | Holder                                       |
|----------|-------------------------------------------|----------------------------------------------|
| FP-41501 | Add RodCategoryId into CatchFishCondition | Andrii                                       |
| FP-41593 | Steam global chat — restricted-country    | Sova (+ Next Server Hotfix)                  |
| FP-42531 | Mission Variable Functionality            | Davydiuk                                     |
| FP-42557 | Air Temperature Checking                  | Davydiuk                                     |
| FP-43181 | Hints — hide tasks even in menu           | Andrii (+ 2026.4 FTUE)                       |
| FP-44392 | UniqueBy doesn't work as intended         | Andrii                                       |
| FP-44413 | Failing + re-receiving mission            | Andrii                                       |
| FP-44501 | Fish Dragging Kayak Tracking              | Davydiuk                                     |
| FP-44667 | Mission Auto-Tracking After Failure       | Davydiuk                                     |
| FP-44701 | Mission 435 completed twice               | Stanislav                                    |
| FP-44716 | Dynamic tasks don't update queued HUD     | Andrii (+ Internal/Async)                    |
| FP-44859 | Some conditions don't refresh properly    | Andrii                                       |
| FP-44943 | [Xbox][DLC] duplicate DLC-pack delivery   | sergii.chop                                  |
| FP-37369 | [Xbox] buy product before products loaded | Churylova (client; + 2026.4.2 FTUE Consoles) |

### Closed

| Key      | Title                                    | Holder                             |
|----------|------------------------------------------|------------------------------------|
| FP-44318 | add "FishForm" to CatchFishCondition     | Andrii (done under daily-missions) |
| FP-44536 | Daily mission completable by bottom rod  | Liliia                             |
| FP-44537 | [Inventory] rod repair quiver state      | Nikiforova                         |
| FP-44668 | HUD mission/task-name variables          | Andrii                             |
| FP-44726 | Reactivating mission resets variables    | Horishnyi (As Designed)            |
| FP-44757 | Same fish counted multiple (Worm Wisdom) | Horishnyi                          |
| FP-44758 | Mission variables random values          | Horishnyi                          |
| FP-44759 | "Is Hidden When Completed" inconsistent  | Andrii                             |
| FP-44761 | Wrong mission restart after fail         | Mary Key                           |
| FP-44777 | [Xbox][Clubs] requests not sent          | Liliia (Duplicate)                 |
| FP-44779 | [Xbox][Clubs] item not real-time         | Liliia (Duplicate)                 |
| FP-44889 | Tournament trophy counters               | Churylova                          |
| FP-44985 | add "Distance" to Hook/Catch conditions  | Andrii                             |
| FP-44994 | Pond Event Icon (Server.UI)              | Davydiuk                           |
| FP-45032 | Kayak task completes on boarding boat    | Liliia                             |
| FP-45149 | Protocol version check disabled (client) | Anna Sydorchuk                     |
| FP-41925 | Client — Put Hats to Backpack            | Churylova (client)                 |

### Not started

| Key      | Title                                | Status | Holder                    |
|----------|--------------------------------------|--------|---------------------------|
| FP-31878 | GD — Fix Autotracking Mission System | To Do  | Andrii (GD; never speced) |

## B. Rerouted out of 2026.5 Anniversary (scope trim before the cut)

| Key      | Title                                     | Status    | Now in                                                          |
|----------|-------------------------------------------|-----------|-----------------------------------------------------------------|
| FP-41616 | Weather: cleanup regen UI                 | Resolved  | Next Server Hotfix + 2026.6 Australia                           |
| FP-41625 | Weather: save per-pond param              | Resolved  | 2026.6 Australia                                                |
| FP-41627 | Weather: new lookup tables                | In Review | Next Server Hotfix + 2026.6 Australia                           |
| FP-42124 | RU players not banned in clubs            | Resolved  | Next Server Hotfix + 2026.6 Australia                           |
| FP-44680 | Broken FishId 3038 icon                   | In Review | Next Server Hotfix + 2026.6 Australia (+ prod data-fix rollout) |
| FP-44730 | Donate Dragonfly Nymphs 32706/07 vs 08    | In Review | 2026.6 Australia                                                |
| FP-44794 | Pond Event's Icons (Server.UI)            | Reopened  | 2026.6 Australia                                                |
| FP-44846 | ProfileSerializationHelper nulling fields | To Do     | 2026.6 Australia                                                |
| FP-41256 | Norway Weather Randomizer DeEngineering   | In Review | Internal/Async                                                  |
| FP-40968 | WebAdmin — ban player by Mac/IP           | Resolved  | 2027 Releases                                                   |

## Notes

- Only **FP-45166** remains open inside 2026.5 Anniversary; ships via Next Server Hotfix.
- The lead's remaining open tails (FP-44680, FP-41627, FP-44730, FP-44794, FP-44846) are all now **outside** 2026.5
  Anniversary.
- Verification discipline: JQL is the live membership source; SVN presence checked against branch HEAD (not a lagging
  WC).
