# FPA (2026.5 Anniversary) — readiness of server tasks on Stanislav

Snapshot: 2026-07-29 (**release day** per JIRA fixVersion 16274). Source: fixVersion 16274 ∩ tasks tracked this cycle.
Commit presence verified by `svn log --search` against branch **HEAD** (branch URL, not a lagging WC).

> **Bottom line:** FPA is effectively clear. The only open item still tagged FPA is **FP-45166** (protocol
> compatibility gate, Reopened) — it ships via **Next Server Hotfix**, so it does not block the FPA cut.
> Everything else in FPA is Resolved. Non-critical / sensitive-tail tasks were trimmed out to NSH / Australia.

## Still in FPA (16274)
| Key      | Title                                  | Status       | Holder      | Note                                                                                                   |
|----------|----------------------------------------|--------------|-------------|--------------------------------------------------------------------------------------------------------|
| FP-45166 | Server: enforce protocol compatibility | **Reopened** | Yuriy Burda | Online-flag sticking tail (not fatal); ships via Next Server Hotfix. Server code already in MFT r16363 |
| FP-41593 | Steam global chat — restricted-country | Resolved     | Dmytro Sova | (+NSH)                                                                                                 |
| FP-42531 | Mission Variable Functionality         | Resolved     | Davydiuk    |                                                                                                        |
| FP-42557 | Air Temperature Checking               | Resolved     | Davydiuk    |                                                                                                        |
| FP-43181 | Hints — hide tasks even in menu        | Resolved     | Andrii      | (+FTUE Steam/EGS)                                                                                      |
| FP-44392 | UniqueBy doesn't work as intended      | Resolved     | Andrii      |                                                                                                        |
| FP-44413 | Failing + re-receiving mission         | Resolved     | Andrii      |                                                                                                        |
| FP-44501 | Fish Dragging Kayak Tracking           | Resolved     | Davydiuk    |                                                                                                        |
| FP-44701 | Mission 435 completed twice            | Resolved     | Stanislav   |                                                                                                        |
| FP-44716 | Dynamic tasks don't update queued HUD  | Resolved     | Andrii      | (+Internal/Async)                                                                                      |

Resolved = awaiting reporter to Close; no lead action left. Only FP-45166 is not Resolved.

## Trimmed out of FPA (scope surgery before the cut)
| Key      | Title                                  | Now in          | Status    | Note                                                                        |
|----------|----------------------------------------|-----------------|-----------|-----------------------------------------------------------------------------|
| FP-41616 | Weather: cleanup regen UI              | NSH + Australia | Resolved  | moved out 07-29                                                             |
| FP-41625 | Weather: save per-pond param           | Australia       | Resolved  |                                                                             |
| FP-41627 | Weather: new lookup tables             | NSH + Australia | In Review |                                                                             |
| FP-42124 | RU players not banned in clubs         | NSH + Australia | Resolved  |                                                                             |
| FP-44680 | No tablet icon, broken FishId 3038     | NSH + Australia | In Review | + prod data-fix rollout (scan-broken-fish -> GD mapping -> SQL -> finalize) |
| FP-44730 | Donate Dragonfly Nymphs 32706/07 vs 08 | Australia       | In Review |                                                                             |

## Open items the lead still owns (now outside FPA — not release-blocking)
- FP-45166 — Reopened (FPA + NSH) — protocol gate, goes out with the hotfix.
- FP-44680 — In Review (NSH + Australia) — still needs the prod data-fix rollout.
- FP-41627 — In Review (NSH + Australia).
- FP-44730 — In Review (Australia).

## Off this list (context)
- Earlier drift: FP-41256 (Norway weather), FP-40968 (WebAdmin ban by Mac/IP), FP-44846 (ProfileSerializationHelper).
- Large batch Closed/Resolved by mission team (Andrii) + QA over 07-27..07-29 as the cut approached.

## Progress tracking
Re-run the live JQL (`assignee = currentUser() AND fixVersion = 16274`) before trusting membership; verify SVN presence against branch HEAD, not a lagging WC. This file is the shared readiness view.
