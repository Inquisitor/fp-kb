# Missions — Decision Log

## 2026-04-23 [LBM r15733] Bite system is the authoritative fish source for Daily Missions

When gating whether a caught fish counts toward the Daily Mission "recently caught" list, use `ServerLocation.AllFish` — the precomputed set built from `LocationFish` + `FishBoxes.Conditions.Fish` in `GameServerCache.LoadPondConfigurations()`. Fish whose FishId is not in this set (event fish spawned via mission DynamicFishBox or similar transient sources) are excluded.

**Context:** `DynamicFishBox` is legacy technology, surviving only inside the mission system. The bite system (bite maps + bite system JSON on pond) replaced boxes as the canonical pond fish source. Treating `ServerLocation.AllFish` as "bite-system fish" is therefore accurate in current code.

**Lesson learned:** when reviewing changes that filter by "pond fish", do not confuse `DynamicFishBox`-spawned species with regular pond fish — they are intentionally excluded. The filter is by species ID, not by catch source (a species caught from an event path still counts if it exists in the pond's bite system).

## 2026-04-27 [LBM r15957] Daily mission regeneration suppresses forced profile save (anti-thundering-herd)

`SaveProfileWithLog` was removed from `GameClientPeer_Travel.GetTime` and the new `OnScheduledDailyMissionRefresh` path persists no profile blob. This is by design: per-node `GenerationRefreshJitterSeconds` jitter spreads scheduler firings on each worker node, but every node's `SavePlayerProfile` writes still converge on the single central SQL Server (full-blob stored proc with four large JSON columns; `SqlProfileProvider.cs:143` already flags mass-save as a known pain point with bumped 180s timeout). Suppressing the forced save during regen is what actually mitigates the central-DB burst.

**Trade-off:** WebAdmin's `PlayerDailyMissionsModel.Load()` reads the profile from DB (no in-memory fallback for online players). Between regen and the next natural save event (level-up, balance change, mission completion, session unload), an online player's freshly-generated daily missions are not visible in WebAdmin. Conscious cost.

**Lesson learned:** per-node jitter does not stretch the aggregate write rate when all nodes write to one central DB. Mitigating bursts of full-profile writes requires suppressing the write or per-write jitter, not per-trigger jitter on the source side.

Decision 2026-04-27 [release 2026.3 triage]: Accept. See [review FP-43186 / F-1](../../../review/FP-43186--daily-missions-tab-refresh-delay/review.md).
