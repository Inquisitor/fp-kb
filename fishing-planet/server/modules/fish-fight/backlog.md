# fish-fight — Backlog

- [ ] Pre-v2 measurement, server logs only (no wire changes): per-platform distribution of generation gate passes vs
  real generation attempts (`FishGenerator.CheckBiteSystemFishGenerationTimeout` + `FishSelector.TryToGenerateFish`;
  reason strings `BiteSystemGenerationTimeout` / `SkippedByStepsToGenerateGlobalVar` already exist — add counters +
  export). Answers whether Mobile's StepsToGenerate=3/3 compensates a sparser message stream or just doubles the
  cadence; input for FP-38190 and for the evaluation-clock design. Belongs to generation/BiteSystem but shares the
  clock-decoupling discipline with this module.

- [ ] D2 input: fold the defect register into the authority/interruption matrix (per state/transition: who initiates, who may interrupt, what bounds the input)
- [ ] Point fixes shippable before protocol v2 (candidates for the first implementation series of FP-45122): D-3 pause/wear, D-5 dead throttle, dt clamps, ping guards (P-22), NRE in Rollback (P-17)
- [ ] Unhitch redesign (client-team design doc 2026-08-05, variant C accepted as direction): server derives the
  "slack recently" condition from the `HasLineSlack` ("l") flag over the last N Move windows instead of the dead `lTf`
  minimum. Sequence: observation logging in `HandleUnhitch` (old vs new condition vs slack presence — no behavior
  change) -> GD picks parameters (slack source, jerk threshold per tackle class, N windows, per-roll probability) ->
  hot `EnvironmentVariables` toggle. Baseline to preserve: `Hitch.UnhitchProbability = 0.05` global + ~5 rolls/s under
  today's always-true min clause = snag frees in ~4 s of steady pulling. Caveats recorded: "l" is still CLIENT-owned
  (spoof = today's behavior, no regression, but D2 matrix must not claim ownership change); client period-latch leaks
  (C-7) apply to the flag — observation phase must also measure the flag's quality. Supersedes the "fate of lTf" item
  below for the mechanics half; the v2-schema half (drop lTf or keep with explicit no-measurement marker) decides
  after observation.
  UPDATE 2026-08-06 (client re-check + server answer): the flag leaks WORSE than C-7 suggested — the shortened x4-reel
  send path drops the accumulated window AND does not clear it (flag shifts into the next window; a rarer third leak
  loses a whole window on location transition). Server-side quality measurement is impossible on the current wire
  ("false" vs "shortened packet" indistinguishable) — measurement splits two-sided: server logs outcomes on live
  players, client measures input quality on a test build. The flag IS live combat logic on the server: heavy-fish
  slack escapes (`lineSlackStartDate` + per-fish `SlackEscapeDelay`), both leader cutters, and missions
  (`MissionsContext[Slot].HasLineSlack`) — so the client leak fix changes balance (today's leaks shield fast reeling
  from slack consequences) and ships only under the same hot toggle + observation phase, or with v2; GD approves.
- [x] DECIDED 2026-08-10 (answered in `reviews/2026-08-10-2152-srv-ltf-unhitch-response.md`): the client-side
  `lTf` fix is NOT to be reverted — it ships with v2 as is (client branch `Unity_Fishing_CodeBranch_Decomposition`,
  not on prod). A revert would only preserve a ten-year-old defect. The three commitments this created are the
  items below.
- [ ] **Unhitch knobs — first thing on the new branch.** `LowHitchForce` (1) and `HighHitchForce` (2) plus
  `MinHitchTime` (.5s) are compile-time `private const` in `HitchGenerator` — not DB, not bite map. Move all three
  to `GlobalVariables` so GD can calibrate hot instead of via deploy. Without this the client's request to
  "re-evaluate the thresholds" is not executable in any reasonable cycle. Note the asymmetry being compensated:
  the client fix changes WHEN the roll happens at all, while the only hot knob today (`UnhitchProbability`, 0.05)
  changes HOW OFTEN it is thrown once the condition already held. Calibrate the pair 1/2 jointly — they were tuned
  when the left half was always true, so effectively only `hTf > 2` was live.
- [ ] **Observation logging in `HandleUnhitch`** (old condition vs new condition vs slack presence, live players) —
  produces real numbers on "how much rarer" before the v2 release instead of estimates. Same phase as the unhitch
  redesign item above; now has a concrete trigger and deadline (must precede the v2 ship).
- [ ] Generalise the phase gate for inventory mutations of an active slot (defects D-14..D-19): today only
  `HandleUseRepairKits` checks slot FSM phase. Target for v2: an inventory mutation of an active slot becomes an
  operation of the fight protocol and passes one shared gate (reject, or explicit cycle close) instead of per-op
  checks. Note `HandleUseRepairKits` itself is not fully fail-closed (missing processor -> `slotState == null` -> passes).
- [ ] Fight timeout (server-side, promised to the client team): no watchdog closes a silent fight today —
  `FightFishInactivityCheck` writes one WARN line and nothing else. Order is mandatory: v2 must first guarantee fight
  ticks or a heartbeat on ALL branches incl. the rod stand, because today silence on the stand is normal for part of
  the client branches; only then enable the timeout. Must respect pause and measure fight time by the interval model,
  not by packet arrival. Duration and outcome (escape without penalty? bait? stats?) are GD/config.
- [ ] Regression pins owed to the client team (convention 9 of the contracts repo): each defect we deliberately left
  until v2 — stand two-step, inventory mutations bypassing the FSM, `RodSetupEquip`/`SwapRods`/`MoveItems`, missing
  fight timeout — needs a test pinning today's observable behaviour BEFORE the v2 work starts.
- [ ] Server-wide identifier proofreading pass (user intent, 2026-08-10): fix typos (`PeerInactivityIntervalMinites`,
  `CastLegth`, `Replanish*`, `fishTempalteReset*`, `UnEquiped`, `IsPoolingOrStriking`), engrish semantics
  (`NeedClientReset`, `UnHitch`, `FinishMove`, `FSMEvent`, time-stop), terminology divergences (`LineLengthConst` vs
  client `LineLength`, `SetShimsCount` opcode vs `SetShimCount` handler). Wire-facing names get fixed by the v2
  schema; internal names — a dedicated refactor pass. Accumulator: protocol-docs `GLOSSARY.md` rename tables. Optional
  tooling: automated identifier spell-check sweep (split CamelCase, dictionary + domain-term allowlist) to produce the
  exhaustive typo register in one artifact.
- [ ] Answer decision needed: does `StrongFishEscapeModel` per-tick rolling change effective escape rates enough to matter for balance once fixed? (GD question before touching)
- [x] Network-thread switch removal — DONE both sides: client machinery in client r56884 (FP-45638; only
  flag-dependent branches cut — the *Async files keep live flag-independent machinery: RequestId stamping, disconnect
  queue drain, stale-connection response gate; not renamed to avoid a GameCarrier-migration merge); server half in
  SRV r16407 (FP-45657: both `EnvironmentVariableCache` properties + the login push removed, patch
  `NPN.M.2026.08.06-032` deletes the two `Connectivity.*` rows). DB values were 'N'/absent everywhere beforehand
  (2026-08-04 sweep)
