# game-processor — Backlog

- [ ] Reconcile module naming/boundaries with FP-43424 pass-3 catalogue (`game-state` + sub-engines, tentative) when Pass 2 reaches the `game` system
- [ ] Deep dive on fight satellite models (FishTireModel parameters, StrongFishEscapeModel, cutters/breakers) if phase-5 server work starts
- [ ] Audit legacy fish-box generation path in `HandleMove` (pass-3 note: survives only in missions; dual generation with BiteSystem)
- [ ] Map `AntiCheatFishingManager` checks into hard-reject vs scoring candidates (feeds S5 of FP-45122)
- [ ] `GetCaughtFish` equipment->`CaughtFish` mapping has no unit coverage (population side untested; condition tests build `CaughtFish` directly). Extract the snapshot mapping into a testable helper. Surfaced by FP-41501 review.
