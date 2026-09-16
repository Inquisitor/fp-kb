---
jira: https://fishingplanet.atlassian.net/browse/FP-46179
title: "[GameServer] Listening port differs depending on the node role"
status: in-progress
executor: Stanislav Samoilov
created: 2026-09-14
type: story
platforms: [Steam/EGS, PlayStation, Mobile]
---
# FP-46179: [GameServer] Listening port differs depending on the node role

## Status
The config change is committed across all five branches (IMV r16547 through NPN r16551). Not complete until
deployed: the dedicated Game nodes of PlayStation and Steam need 4531 open before their next deployment,
otherwise client connections to those nodes break the moment the updated config ships. Stays in progress
until the deployment lands.

## Summary
The `Game` application bound a different port depending on the role of the node hosting it — 4531 on Master
nodes, where it runs as the `GameOnMaster` adapter, and 4530 on dedicated Game nodes. This task binds the
port to the application instead of the node role: `Game` listens on 4531 everywhere.

4531 is not an arbitrary pick. Within a port range the last digit encodes the application's position in the
canonical order, so `Game` follows `Master` at 4531. Nintendo, Xbox and the Retail platforms already used
4531, and so did the GameCarrier `config.json` of Mobile, PlayStation and Steam. The deviation was confined
to the Photon configs of those three platforms, where both `GamingTcpPort` and the `Game` TCP listener still
read 4530 — so a GameCarrier node listened on 4531 while announcing 4530 to Master.

**Gotcha:** the Mobile pilot Game node was overridden to 4531 by hand when it was moved onto GameCarrier.
Both the Photon and the GameCarrier manifests deploy the same `<Platform>.Game.Photon.LoadBalancing.dll.config`,
so until this change every deployment of that node silently reverted it to 4530.

Relates: FP-43632 (the deviation surfaced while preparing the GameCarrier migration)
Relates: FP-46180 (matching deviation on Chat; fixed on NPN only, so it ships with the Australia release)

## Milestones
- 2026-09-16: `GamingTcpPort` and the `Game` TCP listener set to 4531 for Mobile, PlayStation and Steam in
  IMV r16547, carried up the chain — KNW r16548, LBM r16549, MFT r16550, NPN r16551. Combined commit + merge
  note posted to JIRA, with a warning panel carrying the firewall prerequisite for the PlayStation and Steam
  Game nodes
