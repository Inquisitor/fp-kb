# AntiCheat Game Session Analysis — Requirements

This document captures stakeholder wishes and known constraints. Concretization (algorithms, exact data shapes, component decomposition) lives in [architecture.md](architecture.md) (TBD) and individual subtask specs.

## Goal

WebAdmin tool for moderators to manually inspect a player's game sessions for anti-cheat patterns. Built for **manual forensics** initially, designed to evolve into the foundation for **automated reporting** and **banwave staging**.

## v1 Scope

The first iteration delivers the analytical primitives needed to turn the manual workflow used during the FP-43579 investigation into a reproducible WebAdmin tool.

### Included
- Per-player click selection by date range
- Click cloud overlay on screenshot (see [Screenshot calibration](#screenshot-calibration))
- Resolution / aspect-ratio detection with manual override
- Visualized window boundaries and KEEP / RELEASE / catch-panel boxes
- Per-player calibration persistence (client-side)

### Explicitly out of scope for v1
- Mobile / console UI variants (different prefab, different geometry — defer)
- Cast position visualization on a pond map (data not in `fishingLog` — needs separate research)
- Cross-player aggregation, top-N suspect lists, mass scan
- Persistent server-side verdict storage (recompute-on-view for v1)
- Automated banwave / report generation

## Future Phases (architecture must accommodate without rewrite)

### Phase 2 — Timeline

A horizontal time axis showing game activity at multiple granularities, simultaneously:

- **Game sessions**: login → logout intervals (`Stats.GameSessions`)
- **Fishing sessions** (pond trips): start → end per pond (`Stats.FishingSessions`); a single pond trip may be split across multiple game sessions when the player exits and returns days later — the tool must visualize that continuity
- **Screenshots**: placed on the timeline at their captured timestamp
- **Competition zones**: time ranges where player participated in tournaments / competitions
- **Fish-catch events** (catch cycles): per-cycle markers from `Stats.FishingSessionsCatch`
- **Catch phases (later)**: cast → bite → reel — if events for these get added to the log later

### Phase 3 — Pond fishing map

Top-down pond map with cast positions overlaid. Requires research into where cast coordinates are logged (not yet identified in `fishingLog`).

### Phase 4 — Anomaly detection (server-computed signals)

- Click cluster density verdict
- Window-center signature
- Hardcoded-coords signatures lookup
- Inter-event timing distribution (bot constancy vs human variance)
- Take/Release ratio anomalies (e.g. inverse keep-everything or release-everything)

Anomalies and timeline overlap in scope; the architecture should treat them as separate concerns (timeline = visualization, anomaly = computed score with traces back to underlying events).

### Phase 5+ — Automation

- Persistent verdict storage (per-player, per-session, with rule version)
- Mass scan with rule definitions configurable in admin UI
- Banwave staging: proposal → review → execute, with audit log
- Auto-report generation for moderators

## Data Sources (cataloged)

| Source                                        | Used for                          | Notes                                                        |
| --------------------------------------------- | --------------------------------- | ------------------------------------------------------------ |
| Mongo `fishingLog`                            | TakeClick, ReleaseClick events    | 14-day retention; `LogBase("fishing").Find(userId, from, to)` |
| Mongo `diagSysInfoLog`                        | Monitor resolution, OS, hw        | 60-day retention; `Monitor` is unparsed string               |
| SQL `Stats.GameSessions`                      | Login / logout intervals          | `(UserId, EndedAt)` indexed                                  |
| SQL `Stats.FishingSessions`                   | Pond trip intervals               | indexed on `StartDate`                                       |
| SQL `Stats.FishingSessionsCatch`              | Per-fish catch cycles             | FK on `SessionId`                                            |
| SQL `Stats.Screens`                           | Player screenshots (varbinary)    | `XAK_Screens_UserId` index; existing reader: `IAnalyticsProvider.GetScreen(id)` |

**Unknown / TBD**:
- Cast coordinates source
- Whether pond geometry / map asset is already available somewhere

## UI Behaviors

### Click cloud overlay

Take/Release events for the selected date range are rendered as points on top of the player's screenshot. Click coordinates and screenshot must be aligned in the same coordinate system — this requires calibration.

### Screenshot calibration

The screenshot's pixel dimensions and the player's game-window resolution may differ (downscaled / cropped / different aspect ratio). The tool must:

- Maintain a list of common resolutions to try, grouped by aspect ratio: **16:9, 16:10, 4:3** (other ratios as found in production data)
- Offer **automatic suggestion** based on click cloud geometry (pattern A hot-spot symmetry, pattern B button-center symmetry, see [Background — investigation findings](../journal.md#background--investigation-findings))
- Offer **manual slider** for the moderator to override / explore
- Compare the chosen resolution with `diagSysInfoLog.Monitor` — **mismatch is informational** (a player may legitimately play in a smaller window on a larger monitor), but a sustained mismatch across multiple sessions is itself a soft suspicion signal
- Render visual **window boundary** outline on the screenshot at the chosen resolution, plus KEEP / RELEASE / catch-panel boxes — the moderator sees the fit hypothesis

### Calibration persistence

Per-player calibration (chosen resolution, manual offset, etc.) is cached **client-side** (localStorage or cookies). v1 does not persist server-side; this can be revisited if calibration needs to survive across moderators / browsers.

### Analytical interactivity

The tool is designed for **manual analysis** — the moderator hypothesizes and the UI helps validate. Examples of expected interactions:
- Toggle precise-points view vs density-heatmap view
- Filter clicks by event type (Take / Release)
- Hover for click metadata (timestamp, exact coords)
- Adjust resolution slider and watch click-fit change in real time

## Server Architecture (preliminary)

The architecture must cleanly separate concerns to survive the planned phase-by-phase growth. Initial slicing:

- **Controller** (thin) — routing, auth (`Abuse` role), input validation
- **Service layer** — analysis logic, data shaping; testable in isolation
- **DAL layer** — existing providers; add read methods where needed (e.g. `IFishingSessionProvider.Find`)
- **DTO / ViewModel** — explicit; no leaking of DAL types into the view
- **Data flow** — AJAX-driven; the server delivers JSON; the client renders dynamically

A SPA-like UX inside the ASP.NET MVC host page is preferred. The lazy / progressive loading pattern matters because Phase 2 timeline can pull large quantities of events.

## Frontend Stack (TBD, captured for follow-up decision)

- **Candidate**: Vue 3 + TypeScript — cutting-edge, component-based, plays well with the planned reuse hooks (timeline, heatmap, raw events, calibration panel as composable components)
- **Existing precedent**: `WebAdmin/Components/TargetedAdsPlanningTool/` uses Vue 2 + Vuetify; the prior author considers it suboptimal — treat as reference pattern for *integration* (build pipeline, host injection) but not as code style template
- **Kendo MVC**: present in WebAdmin, considered legacy; use sparingly if at all in this tool
- **Open question**: Vue 3 build pipeline integration (separate bundle? in-page islands? SSR via Razor for the host shell, then Vue mounts on a div?). To be decided in [architecture.md](architecture.md).

## Hypotheses Still Open

These are explicitly **open** — the tool is being built in part to help close them:

1. **Cursor center-placement attribution**: when a click cluster sits at the window center, is it
   - (a) a bot using `SetCursorPos`-style placement before invoking the handler, or
   - (b) Unity auto-centering on screen change / focus event combined with controller-only play, or
   - (c) something else?

   The tool itself does not need to *answer* this hypothesis to be useful (cluster outside KEEP/RELEASE = suspicious regardless of cause), but Phase 4 anomaly scoring should be able to incorporate the answer once known.

2. **Resolution mismatch semantics**: how strong is the signal of "window resolution detected from clicks" ≠ "monitor resolution from `diagSysInfoLog`"? Multi-monitor setups, windowed mode, OS DPI scaling all complicate this.

3. **Cast coordinate availability**: is there cast position data anywhere in the logs / DB? Phase 3 hinges on this.

## Long-term Goal (set north star, not v1 deliverable)

Replace the current ad-hoc moderator workflow ("look at logs, eyeball screenshots, compare, decide") with:

- **Automated mass scan** producing ranked suspect lists per period
- **Persistent per-player anti-cheat profile** with verdict history and audit
- **Banwave staging UI** for moderators to review proposals, adjust, and execute as a batch with full audit trail
- **Reusable analysis primitives** — the per-player tool of v1 evolves into Tab 1 of a multi-tool moderation surface

The v1 tool's data and component primitives must be designed so this future does not require a rewrite. Specifically:
- Click loading and resolution detection should be packaged as a **service**, not buried in a controller action
- Verdict computation must be **deterministic from inputs**, so it can later be batched server-side
- Frontend components must be **prop-driven and stateless** (where possible), so they can be reused in other moderation pages

