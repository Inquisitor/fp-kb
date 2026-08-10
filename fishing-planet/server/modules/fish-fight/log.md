# fish-fight — Decision Log

2026-07-31 [NPN] Module created as the D1/D2 ground truth for FP-45122. Sources: full pipeline read of
`HandleFightFish` + all fight models (server NPN20260602), client fight stack (Win64_CodeBranch r56789), protocol audit
answering the client team's Q1-Q14.

2026-07-31 Finding: every claim in the client-team documents of 2026-07-30 (codebase verdict Part III, comment 133151 in
FP-45122) CONFIRMED against code, several amplified: `isFishPassive` disables three models (not one) without restarting
the stamina stopwatch; the strong-fish escape throttle is dead code; the rod-on-pod event drain is commented out
entirely; the swallowed-duplicate response returns the client's own request as success.

2026-07-31 Finding: `NeedClientReset` reachable payload domain is exactly {Initial, Move} — the client's two-case
handler is complete for the current server; the domain is implicit (no enum/contract), so any Rollback change silently
widens it.

2026-08-02 Resolved (ex-backlog): `IsRequestFiberEnabled=True` on the seven test envs is INTENTIONAL — a live
server-side experiment the server lead plans to develop, NOT dead code; do not remove or align. Design intent: split
avatar traffic from game-action processing — game actions queue on the per-peer fiber, broadcast-class requests
(avatar actions visible to other players) bypass the queue for immediate handling (`GameClientPeer.cs:166-177`,
`OnOperationRequest` fast path); optional follow-up idea: range filter so e.g. rod-angle updates are not broadcast to
distant players. QA/prod threading asymmetry (P-8) is the accepted cost for now; possibly rewritten later.

2026-08-02 Correction: client-team Q13 ("processing on a separate thread, server global variable") refers NOT to
`IsRequestFiberEnabled` but to `Connectivity.IsNetworkThreadEnabled` — an `EnvironmentVariables` row (seeded 'N' by
`JLM.M.2025.08.04-017`), pushed to the client at login (`GameClientPeer.cs:2877`), toggling the client's
`PhotonDispatcherThread` (`PhotonServerConnection_ClientSideCache.cs:156`). Hot-editable without restart, so "guaranteed
off" holds only per DB state, not by code. Unused; slated for two-sided removal (see backlog).

2026-08-05 Correction (P-3): the client-team re-check is right — events with cycle 0 are NOT dropped by the client
filter; the outer guard `FishingCycleId > 0` bypasses the whole check, so post-restore events are accepted unvalidated
(no freshness compare, no receive-window check). Verified against FishSpawner.cs:151-155. Register and the Q4 answer
corrected; D1 as-is must carry this version. Their proposal (server-issued cycle kills the guard and both diseases)
noted as D3 input.

2026-08-05 Fact (generation cadence, context for the "6 vs 8" question): effective StepsToGenerate values come from
`EnvironmentVariables` — rows absent on Steam/TEST prods (cache default 6/6 applies), Mobile prod has 3/3. The static
lure default 8 in `FishSelector.cs:25` is a remnant of the 2018 seed (Float=6, Lure=8) and is overwritten at startup.
FP-38190 (To Do): the ~500ms generation-interval check accumulates lateness instead of compensating (+25%+ always
positive, connection-dependent) — fix proposal there pairs the interval fix with 6->8 (mobile 3->4); GD consult
required.

2026-08-08..10 D1 server half delivered into the contracts repo (`fishing-planet/server/r-n-d/protocol-docs`):
generated FSM (`server-fsm.md/.svg`, regenerated from the transition tables), `server-refusals.md` (envelope, FSM
refusal layer with the provenance-annotated rollback table, per-opcode pass, answers to the client's six questions),
`server-fight-path.md` (tick pipeline, clocks, escape/break trees, identity, threading). Two adversarial review
rounds (Codex + independent agent) before sending; four of our own claims were REFUTED and fixed before publication —
see the "what we got wrong" entry below.

2026-08-10 Self-correction round (adversarial review of our own reply, both reviewers agreeing): (1) there is NO free
escape from `Hitch` by breaking sync — `Rollback` returns `null` for `Hitch`, so `DoNeedClientReset` neither rolls
back nor emits, and the `ReleaseTackle`-before-rollback path needs a non-null rollback; (2) the exception direction in
`AttackFinished` is the opposite of what we wrote — `State` is assigned BEFORE `OnTransition`, so a throw BEFORE the
handler's nested `GoTo…` is what strands the FSM there; (3) `SwapRods` is NOT covered by the rod-setter compensator;
(4) `RodCaster` is shared code constructed by the server, not "client-side", so "no server backlash mechanics at all"
was too strong — only the effect (`CheckBacklash`) is disabled. Also: `MultiRodsOperationCode` is dead (sole consumer
fully commented out; live stand ops are `InventoryOperationCode`), and static transitions
(`Board`/`Unboard`/`TravelByBoat`/`Walk`/`RestoreBoatPosition`) bypass the FSM entirely in
`MultiRodGameProcessor.PerformTransition` — they are declared in `StateTransitions` but never reach the machine.

2026-08-10 Client answers to the two server questions (`server-fight-path.md` §8): (Q1) `FightFishOnPod` is an
ADAPTER METHOD name, not a wire opcode — it calls `Game.FightFish` and sends `GameActionCode.FightFish`, so the
server does understand stand ticks; our concern was unfounded, their FSM diagram draws adapter calls rather than the
wire. Two real defects surfaced instead (C-15, C-16). (Q2) Of the server-written response keys only `b` is dead on
arrival on the client (C-17); `lBp`, `fRf`, `wLn` echo, `bI`, `rU` and the wear triples are all live, `wLn` and `bI`
gameplay-bearing. Consequence for our own §3.4 answer 5: on the pod path `wLn` is a definite `false`, so the
"unknown" third state collapses there.

2026-08-10 Glossary discipline formalised in the contracts repo: strict article contract (mandatory English column,
"in code" separated from "where documented", side markers srv/cln/shd, closed status vocabulary, alphabetical order)
plus `tools/check-glossary.py`, which fails on violations and verifies that every listed identifier exists in LIVE
code — comments are stripped first, precisely because `MultiRodsOperationCode` "exists" only inside a commented-out
file. Coined term "valve" dropped (collides with the Russian term for logic gate) in favour of "commit point";
"debuff"/"debuff state" adopted for states that impose a cost, with the invariant "a debuff is removed only by game
mechanics, never by a technical event".

2026-08-10 Fact (unhitch roll tunables, checked in `HitchGenerator`): the jerk condition
`lTf < LowHitchForce && hTf > HighHitchForce` uses `private const float` values 1 and 2, and the gate
`MinHitchTime` is a `private const float` of .5s — none of the three is a DB row or bite-map data, so changing them
needs a code change plus deploy. The only hot knob is the probability: `config.UnhitchProbability()` ->
`GlobalVariablesCache.UnhitchProbability` -> `GlobalVariables` row `UnhitchProbability` (0.05 as measured).
Bite-map data (`CanBreak`, `MaxLoad` of the hitch box) feeds only the OTHER unhitch path — "force the box" — which
the client `lTf` fix does not touch. Consequence recorded for the v2 work: the client fix changes when the roll
fires, while the only hot compensator changes how often it is thrown — a coarse substitute, hence the commitment to
move the three constants into `GlobalVariables` first.
