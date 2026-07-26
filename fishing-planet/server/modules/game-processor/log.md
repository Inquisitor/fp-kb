# game-processor — Decision Log

2026-07-21 [MFT] Module created during preparation for the client fish-fight campaign (FP-44583 phase 5). Sources: full code sweep of `GameProcessor.cs` / `MultiRodGameProcessor.cs` / FSM tables / `GameActionAdapter`, plus FP-38709 epic history (49 children).

2026-07-21 Finding: FP-43424 pass-3 catalogue drafts this area as a `game-state` module (with sub-engine extraction candidates `rod-cast`, `reel`, `chum`, `fish-box`, `physics-model`) under a `game` system umbrella — all marked tentative. This module was created as `game-processor` (user-requested name, orchestrator-scoped). Reconcile naming/boundaries when FP-43424 Pass 2 reaches the `game` system.

2026-07-21 Finding: "server computes the fight" is only half-true — outcome models are server-side (`FishTireModel`, escape/cutter/breaker), but their inputs (forces, line length, `isReeling`, positions) are client-supplied and trusted (anti-cheat scores, rarely rejects), and their clocks are wall-clock. Relevant to any server-authority design for phase 5.
