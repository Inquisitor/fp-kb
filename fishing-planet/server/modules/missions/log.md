# Missions — Decision Log

## 2026-04-23 [LBM r15733] Bite system is the authoritative fish source for Daily Missions

When gating whether a caught fish counts toward the Daily Mission "recently caught" list, use `ServerLocation.AllFish` — the precomputed set built from `LocationFish` + `FishBoxes.Conditions.Fish` in `GameServerCache.LoadPondConfigurations()`. Fish whose FishId is not in this set (event fish spawned via mission DynamicFishBox or similar transient sources) are excluded.

**Context:** `DynamicFishBox` is legacy technology, surviving only inside the mission system. The bite system (bite maps + bite system JSON on pond) replaced boxes as the canonical pond fish source. Treating `ServerLocation.AllFish` as "bite-system fish" is therefore accurate in current code.

**Lesson learned:** when reviewing changes that filter by "pond fish", do not confuse `DynamicFishBox`-spawned species with regular pond fish — they are intentionally excluded. The filter is by species ID, not by catch source (a species caught from an event path still counts if it exists in the pond's bite system).
