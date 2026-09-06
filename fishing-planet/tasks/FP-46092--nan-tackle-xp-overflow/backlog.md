# FP-46092 backlog

## Immediate
- [ ] Pull raw fight data into artifacts (FishFact rows, FishingSessionsCatch rows, fishingLog fights, cheatLog)
- [ ] Charts on fight duration vs weight, before/after 2026-09-03
- [ ] Re-read fishingLog once the debug flags (127) have produced detailed fight lines

## Deferred
- [ ] Server fix: ignore non-finite tackle coordinates; no tackle bonus on corrupted input; overflow-safe
      experience sum (`FishExperienceData.Recalculate` is `int`, `GetFinalExperience` casts unchecked)
- [ ] Client side: decide whether a client ticket is warranted once the cheat verdict is in; the trace
      of the send path (no sanitiser, sticky accumulator in `HookController.SyncWithSim`) is in the journal
- [ ] `FishValueModulator` and `Rod1stBehaviour.lastValidTacklePosition`: the client already filters
      NaN for its own reset path but not for what it sends; worth a client backlog note if the ticket is filed
- [ ] Other profiles with implausible rank XP on Steam PROD (61 above 1B, 172 above 300M below the cap):
      not evidence by themselves; only revisit if a second confirmed overflow case appears
