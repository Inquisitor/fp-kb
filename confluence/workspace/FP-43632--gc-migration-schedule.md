---
page_id: "5931040769"
section: tech-guidelines/server/infrastructure
related_tasks:
  - FP-43632
---
# GameCarrier Migration — Plan and Schedule

Moving the server transport layer from Photon to GameCarrier on the Steam/EGS, PlayStation and Mobile platform
stacks. Xbox and Nintendo already run GameCarrier in production; Retail is out of scope.

The change is invisible to players: clients keep speaking the same protocol, and no client release is required.

## Scope

| Platform | Today | After |
|----------|-------|-------|
| Steam / EGS | Photon | GameCarrier |
| PlayStation | Photon | GameCarrier |
| Mobile | Photon | GameCarrier |
| Xbox | GameCarrier | — already migrated |
| Nintendo | GameCarrier | — already migrated |

Platforms are converted one at a time, from the smallest audience to the largest: Mobile, then PlayStation,
then Steam.

Each platform is converted in two stages. Game nodes are replaced while the platform stays online — new
GameCarrier nodes take incoming players while the old ones finish serving those already connected. Master,
Chat and Club cannot be replaced this way, so each platform ends with one short maintenance window.

## Milestones

Dates are approximate. What matters is the sequence and the recorded fact of completion.

| Milestone | Planned | Actual |
|-----------|---------|--------|
| Mobile pilot node live on GameCarrier | 9 Sep | 10 Sep |
| Mobile fully on GameCarrier | 15 Sep | |
| PlayStation fully on GameCarrier | 22 Sep | |
| Steam fully on GameCarrier — migration complete | 30 Sep | |

## Schedule

| Date | Work | Status |
|------|------|--------|
| 7 Sep | Staging environment prepared; QA testing started | ✔ done |
| 8 Sep | QA testing continued; pilot node prepared | ✔ done |
| 9 Sep | Configuration merged across all branches; Mobile package built | ✔ done |
| 10 Sep | Pilot node introduced on Mobile production | ✔ done |
| 11–13 Sep | Pilot under observation; rotation switching exercised; entire platform traffic served by the pilot node | ✔ no incidents |
| 14 Sep | Pilot accepted; second Mobile node taken out of rotation | |
| 15 Sep | **Mobile maintenance window — Mobile complete** | |
| 16 Sep | GameCarrier nodes introduced on PlayStation | |
| 17–20 Sep | PlayStation under observation | |
| 21 Sep | PlayStation Photon nodes taken out of rotation | |
| 22 Sep | **PlayStation maintenance window — PlayStation complete** | |
| 23 Sep | GameCarrier nodes introduced on Steam | |
| 24–27 Sep | Steam under observation | |
| 28–29 Sep | Remaining nodes converted | |
| 30 Sep | **Steam maintenance window — migration complete** | |
| 1 Oct | Reserve | |

Maintenance windows are 1–2 hours, booked a day ahead, scheduled early morning at off-peak.

## Dependencies

- **DevOps** — node preparation, package builds, deployment, and observation over weekends.
- **QA** — verification of the Mobile build on the staging environment before the pilot goes to production.

