---
jira: FP-45122
title: Fish Fight Sync Contract (Server)
status: in-progress
executor: Stanislav
created: 2026-07-22
type: epic
---

## Status
Fish Fight Protocol v2 moves by a plan of seven steps instead of an evaluation letter (letter `a961a80`,
2026-09-15): the client side accepted the frame (fight wire only, contract = DTOs, encoding = the server side's
layer), the owner narrowed the first stage to envelope numbers and acks inside operation 193 with no second
operation code and no protocol switching, and the server side answered with the ordered steps, their costs and
dependencies; first queue = schema and DTOs, envelope and acks, packed codec; deltas, groups and snapshot are
deferred by dependency, no dates anywhere. Next, in this order: the server lead's talk with the owner on the two
divergences (codec before ticks; snapshot and groups after the first five steps), the rows letter with the four
2026-09-03 findings before the step-1 schema closes, the numbers-letter corrections, the GameCarrier codec
measurement for step 3, then the step letters (2, 4, 5) as each step comes up; the slack wire form stays paused
until the server journal has slack measurements after step 4.

## Summary
Server half of the client player-core campaign (FP-44583 phase 5, fish-fight). Rework the fishing sync layer properly instead of re-patching: as-is documentation → authority/interruption analysis → joint target design with the client team → implementation. Ships in a single release with a protocol version bump and forced update — no backward compatibility, no feature flags.

## Design decisions
- Plan restructured from contract-first (S0–S6 draft) to understand-first (D1–D3 → I1–I3): this campaign is the chance to design the system properly, not to codify the patched status quo.
- Fish Fight Protocol v2: message schema as the single source of truth → typed DTOs, binary serialization, auto-generated readable debug log (schema-driven pretty-printer on both sides — hand-rolled binary without a schema would reproduce the `iR`/`iF` problem in bytes).
- Terminology: D3 produces a fight/FSM/protocol section of the KB glossary; new naming mandatory for new code and the protocol boundary; legacy renames deferred to I3 and scoped to the fish-fight zone (no server-wide mass renames).
- Current-FSM diagram is generated from the transition tables (`StateTransitions`/`TransitionTargets`/`StateTransitionsIgnore`) — regenerable, cannot drift from code; rendered to SVG for Confluence.
- Model pins (I1) freeze gameplay outcome models only (stamina, escapes, breaks, wear) — the transport is deliberately replaced, not pinned.
- Shadow fields / pre-contract path CANCELLED (2026-08-05, owner + server side aligned): the wire is not touched by a single key until the v2 flip; pre-flip measurements come from server logging; the client writes its receiver directly against v2. Document addressing convention: revision + symbol name, no bare line numbers.

## Plan
| Step                                    | JIRA     | Status |
|-----------------------------------------|----------|--------|
| D1 as-is docs + generated FSM diagram   | FP-45137 | To Do  |
| D2 authority/interruption analysis      | FP-45138 | To Do  |
| D3 target design (with the client team) | TBD      |        |
| I1 gameplay-model pins                  | TBD      |        |
| I2 implementation (Fish Fight Protocol v2 + FSM)   | TBD      |        |
| I3 cleanup (crutches, renames, docs)    | TBD      |        |

Related: module cards [game-processor](../../server/modules/game-processor/_card.md) (incl. [unsync-tolerance](../../server/modules/game-processor/unsync-tolerance.md)) and [fish-fight](../../server/modules/fish-fight/_card.md) — the canonical record of both studies.

## Milestones
- 2026-07-21 — Preparation: client phase-5 slides studied; FP-38709 epic fully swept (49 children → taxonomy + shipped-mechanism inventory); full code map of `GameProcessor` / `MultiRodGameProcessor` / FSM tables / `GameActionAdapter`; KB module `game-processor` created.
- 2026-07-22 — Epic FP-45122 created (Tech Debt, High) with ADF description (issue mentions as inline cards); plan restructured to D/I after discussion (single-release forced-update rollout, understand-first order, schema-driven binary protocol, glossary-driven terminology, generated diagrams); children FP-45137 (D1) and FP-45138 (D2) created and linked.
- 2026-07-31 — Fish-fight study (D1 core): three client-team documents of 07-30 digested (codebase verdict, dormant machinery fate, FP-45194 blocker-2 deck) + comment 133151 in the epic; full code sweep of the fight on both sides (server NPN20260602, client Win64_CodeBranch r56789); every client-team claim verified and confirmed, several amplified; Q1-Q14 answers drafted. KB module `fish-fight` created (card + fight-tick + transport-contract + defect-register deep dives). Key new findings beyond the client docs: dead strong-fish escape throttle; no-escape returns suppressing tooth cutters; duplicate-"success" echoing the client's own request; cycle 0 on post-reconnect events; rod-on-pod event drain commented out on the client.
- 2026-08-01..05 — Answer round: Q1-Q14 + follow-up questions answered in writing to the client team; the four 133151 findings verified and answered in JIRA (comment 133365). Two corrections after cross-checks: Q11 (the "1 of 6" number belongs to fish GENERATION — `FishSelector.TryToGenerateFish` steps counter, not the fight path) and Q4/P-3 (cycle-0 events are ACCEPTED unchecked by the client filter, not dropped). `IsNetworkThreadEnabled` swept across all prod/test/QA/CERT/DEV DBs — off everywhere; `PondAustralia` provenance resolved (uncommitted Australia-campaign tail in a dev working copy; DLL commits to carry source revision going forward). Shadow/pre-contract fork CLOSED: straight v2, measurements via server logs. Client team delivered protocol-v2 input accepted as D1/D3 material: seven schema requirements (absence != zero, server-issued persistent cycle, dense per-slot event numbering, timestamps + evaluation-clock decoupling, refusal taxonomy, authority matrix, idempotency), wire-key registry (86 keys; `iF`/`iR` collisions, three case-pair hazards, dual-meaning `hTf`), three design proposals (server-derived unhitch slack, rod-replace hold via event, pod identity in the same bump) and client-side constraints for the format choice (IL2CPP/AOT, five stands, above-ITransport, schema-generated debug log). Unhitch redesign assessed and accepted as direction with two caveats (the `"l"` flag stays client-owned; C-7 latch leaks require flag-quality measurement in the observation phase).
- 2026-08-06..10 — D1 server half shipped and the exchange moved to Git. Contracts repo
  `fishing-planet/server/r-n-d/protocol-docs` created on the company GitLab (private, master append-only, the company
  owner — who personally drives the client side of this campaign — as Developer); the old exchange folder stays only as an inbox for out-of-repo drops. Delivered: generated server FSM
  (SVG + per-state tables, regenerable from the transition tables), `server-refusals.md` (three parts: operation
  envelope, FSM refusal layer with the provenance-annotated rollback table, per-opcode pass) with answers to the six
  client questions, and `server-fight-path.md` (tick pipeline, clock/pause coverage, escape and break trees, identity,
  threading) plus two counter-questions. `IsNetworkThreadEnabled` removed on both sides (client r56884 FP-45638,
  server SRV r16407 FP-45657 + patch NPN.M.2026.08.06-032). Answered all seven questions of the client's
  `state-map.md` §6: phase map confirmed with two corrections and a fourth async window; full wire-vocabulary
  inventory; the D2 divergence framework (ownership, reaction classes A–D, commit points, debuffs, generated
  divergence matrix — server side to produce the skeleton); inventory mutations bypassing the fight FSM (new defects
  D-14..D-19); and the fight-timeout question, whose premise proved wrong — `ImitateSynchronizationBroken` was a
  debug imitation whose call was commented out in the very commit that introduced it, so nothing was ever designed and
  cancelled. Every outgoing document passed two adversarial review rounds before publication; four of our own claims
  were refuted and fixed pre-send (Hitch free-escape, exception direction in `AttackFinished`, `SwapRods` coverage,
  `RodCaster` ownership). Glossary elevated to a checked artifact (`tools/check-glossary.py`: structure, closed status
  set, doc-link and live-identifier existence with comments stripped). Client side meanwhile answered our two
  questions (`FightFishOnPod` is an adapter method, not a wire opcode; only `b` is dead on arrival) and FIXED `lTf`
  after ten years — which changes the unhitch roll inputs and leaves a GD/threshold decision open on our side.
- 2026-08-10 (late) — Client team answered both server questions and shipped a `lTf` fix of their own; server
  response sent the same evening. Decisions: the client fix is not reverted (it rides with v2); the server takes on
  three commitments for the new branch — move `LowHitchForce`/`HighHitchForce`/`MinHitchTime` from compile-time
  constants into `GlobalVariables` (today the thresholds are not tunable at all, only the probability is), add
  observation logging to `HandleUnhitch` so the "how much rarer" question is answered with numbers before the v2
  ship, and pin current unhitch behaviour with a test under I1. Threshold calibration goes to GD together with those
  numbers, not before. Server concern about `FightFishOnPod` withdrawn — it is an adapter method name, not a wire
  opcode; instead two client defects surfaced (no `CanSendGameActions` guard on the pod path, three arguments
  hardcoded to `false`), which also means the `wLn` third state collapses on the pod path and `isPoolingOrStriking`
  never reaches anti-cheat from a rod on a stand. Of the server-written response keys only `b` proved dead on
  arrival — it will not be carried into the v2 schema.- 2026-08-11..12 — D2 answered in full and the exchange became two-way at speed. Five reply letters published to
  `protocol-docs` (guard sequencing, v2 envelope, response-key inventory, server-side audit, divergence policy),
  plus corrections to `server-refusals.md`, the state-map reply, the glossary and the FSM generator. Decisions taken:
  the r1435 unhitch guard ships on the v2 branch together with the client `lTf` fix and not before, because reaching
  prod first would remove jerk-unhitch entirely - a narrower replay of the 2015 r1442 revert; `NeedClientReset` is
  renamed `StateCorrection` with an enum target, a mandatory else branch and an acknowledgement; class A is a rule
  ("every server-initiated transition opens a legal window"), not a hand-written list; B1 gains the clause that a
  client may converge presentationally but never fix value; and the anti-cheat is removed whole rather than repaired -
  it measures playtime, not cheating (81 of the top 100 by tournament rating sit above the ban threshold, mean rating
  224572 against a threshold of 20), and `BanCheaters` is off in every configuration.
- Three defects found that are worth more than the documents they came from. (1) A free exit from a snag: staying
  silent for the unsync window and then sending `Move` with `fkt = true` reaches the fake-transition branch of
  `Rollback`, where `Hitch` is in `inWaterStates`, so the rollback is non-null and `DoNeedClientReset` performs
  `ReleaseTackle` before it - the tackle leaves the snag with no unhitch roll and no risk of losing rigging. The
  client's debuff rule therefore closes a live hole rather than designing v2. (2) Wire byte 25 resolves to
  `Transitions.LoseItem`: `GameActionCode` declares 1..24 and 250, 252..255, `Transitions` carries no explicit
  numbers, and the adapter parses `actionCode.ToString()`, which for an undefined byte is a numeric string that
  `Enum.Parse` accepts. `LoseItem` is permitted from `WithItem`, is not static and has no handler, so a modified
  client leaves `WithItem` for `Move` with neither `ResetGeneratedItem()` nor the event. (3) `Rollback` dereferences
  `transitionContext.Header` unconditionally while server transitions omit the optional header - unreachable today
  because all eight server transitions are guarded by their callers, and armed the moment one is added without a guard.
- Review discipline: nine adversarial rounds with two independent reviewers (agent + Codex), roughly sixty factual
  corrections. Blockers per round 10 / 22 / 4 / 8 / 5. The character of the findings changed near the end - the last
  rounds caught edit discipline rather than ignorance of the code: twice a fix introduced a new error (the landing-net
  wording, the NRE paragraph), twice a fix reached one carrier of a claim and not the other two (the SVG legend was
  corrected while the same sentence survived in the generated markdown and the as-is prose). Worth keeping as the
  argument for reviewing after one's own corrections, not only after the first draft.
- Client side verified our five letters and changed three of our facts. `iR` is closed and could not have reproduced -
  the `RodId` read already carried a type check, precisely because `iR` rides every `Move`; all nine identifier keys
  are pinned by `WearDecoderKeyCollisionTests` since CLN r56942. Their own "30 of 33" figure is retracted: both enums
  are 35 transitions and 13 states with identical names and order, so the FSM mirror has not drifted at all - our
  conclusion about moving the enumerations into `Photon.Interfaces` stands, but on the weaker and honest ground that
  a manual copy happens to match and nobody checks it. And demolishing the backlash reaches DATA, not only the FSM
  vocabulary: `Reel.BacklashProbability` is a `[JsonConfig]` field on every reel, assigned into
  `RodCaster.ReelBacklashProbability` on tackle assembly, with the formula consumer commented out and `FormulasTest`
  still asserting it - a decision to take with GD.
- A fourth defect in the correction channel, theirs, removes a premise of ours: "for `Initial` the client resets the
  rod" holds only for the ACTIVE rod, and even for a matching slot the flag is cleared in `onEnter` before anything
  reads it. `StateCorrection` remains one message rather than two, but the client half is BUILT rather than completed,
  and this also explains why the existing correction never helped - server resets mostly touch inactive slots, and
  teleport resets them in a volley.
- Open on our side: four named pin tests (`JerkUnhitch_RollsWithoutLowTerminalForce_`,
  `StrongFishEscape_RollsOnEveryMessage_`, `StartDraw_FromFishFight_EntersDraw_`,
  `Rollback_ServerTransitionWithoutHeader_`, all suffixed `KNOWN_DEFECT_FP45122`) do not exist yet, and every document
  says so rather than implying convention 9 is satisfied; the small SVN batch on NPN (delete `UpdateObjectModel.cmd`,
  mirror `CharacterEventType`, add a `TryParse` fallback in the restore path) is unstarted; and the backlash data
  parameter needs a GD decision. Server tree moved r16404 -> r16422 during the exchange; the load-bearing facts were
  re-checked at the new revision and hold, with the configuration sweep now covering 115 files instead of 106 and
  giving the same result.
- 2026-08-12..14 — Review cycle carried to seventeen rounds and the exchange turned two-way at speed.
  Two independent reviewers per round until Codex ran out of workspace credits after round eleven; from twelve on it
  was a single reviewer, which is a real loss - across the early rounds the two overlapped on almost nothing.
  Blockers per round ran 10 / 22 / 4 / 8 / 5 / 6 / 3 / 4 / 5 / 3 / 5 / 8, and the flat tail is not stalled convergence:
  each round opened a new search dimension. Round fifteen found the biggest one - the values of `GlobalVariables` and
  `EnvironmentVariables` are readable from `SQL/Patches` in the branch, and fourteen rounds had searched only the C#
  while repeatedly concluding "this needs a database measurement" for values the repository already carried.
  Round seventeen found another: per-env server overrides do not live in `SoftwareDistributor/Configs` at all but in
  `Photon/src-server/Loadbalancing/Config/<env>/<Role>/bin/Photon.LoadBalancing.dll.config`, where `IsDetailedLogging`
  is `True` in 216 files while prod has no key and therefore runs `False` - which changes the measurement recipe we
  had handed the client, since a QA stand and prod behave differently.
- The dominant defect class shifted, and it is worth carrying into future work: from round eleven onward most blockers
  were introduced BY THE PREVIOUS ROUND'S FIXES, not present in the original text. The pattern was consistent -
  blockers were verified against code, while "improvements" were written from the reviewer's description or from
  memory, and that is exactly where new errors landed: an invented method name (`LeaderBreaker.InjectGlobals`), a
  wrong mechanism for constants, a new glossary term defined wrongly for two of its own three examples, a rename that
  reached one carrier of a claim and not the other two. The working rule now is that a correction is not cheaper than
  an original claim and gets the same verification.
- Two claims about live values were published and then corrected, both worth remembering as method failures rather
  than facts. The strong-fish escape threshold: the code default is 0.165 but `UgcOld/2016.02.08-063` seeds
  `Fishing.LimitForce = .2` and `CLZ.M.2023.06.13-047` copies that row (its own 0.165 survives only as an `ISNULL`
  fallback), `-049` renames it - so the expected value is 0.2. But the follow-on argument built on `UgcOld/<ENV>.log`
  was wrong twice over: there are six Xbox logs, not none, and the runner does not read those files at all. The
  correct and much shorter statement is that `SqlCheck` enumerates `*.sql` without recursion, so the `UgcOld` layer is
  never applied and the live value must be measured in the database rather than derived from patch history.
  The second claim - "the lure-fish step counter lost its 8 in 2024" - is RETRACTED outright: `GRM.M.2024.08.19-030`
  deletes from `GlobalVariables` while the accessors read `EnvironmentVariables`, so the deleted rows were never read,
  6/6 applied before the patch, and the patch is cleanup rather than cause.
- Client side delivered four substantial pieces. A verification of our five replies that closed `iR` (the `RodId` read
  already carried a type check, all nine identifier keys pinned by their test since CLN r56942) and retracted their
  own "30 of 33" - though our pinned client tree still shows 33 against 35, so the question of which revision shows
  35 is open. Envelope revision 2, where seven of fourteen fields turned out to be unserializable: the Photon encoding
  registers no unsigned types at all, an unregistered type reaches `throw new Exception("Unknown type")`, and the
  transport is chosen by a race at connect - so the failure would have landed on whichever share of players the race
  sent down that path. A twelve-slide deck for management and game design, with a convention-11 proofreading request.
  And key presence measured on live traffic: three gate keys never appeared in 1479 `Move` messages, the window leak
  measured at 1.28 per cent as a floor, `Move` cadence median 210 ms against a nominal 200.
- Their I1 letter is the one that needs our work. Recording player inputs cannot reproduce a fight - fish behaviour is
  chosen client-side by roughly 55 generator calls feeding one physical body, and frame rate changes both the content
  and the count of messages. So they will record the outgoing message stream instead, and ask us to make the seed
  settable in five server generators: `GameProcessor` (hitch, bite, breaks), `StrongFishEscapeModel` (fight duration
  and the escape itself), `FishGenerator` (which fish, weight, active escape), `FishTireModel` and BiteSystem's
  `PlayerData`. Two already expose `RngSeed` and need only a constructor parameter; `HitchGenerator` needs nothing.
  Two cautions from them are worth honouring: within one rod `GameProcessor.rnd` is shared by hitch, breaks, bite and
  fish count, so any change to call counts shifts everything else - separate streams by purpose; and the
  `TODO: refactor to Random.Shared` in `NormalRandom` must not be executed, because `Random.Shared` cannot be seeded.
  If the seed also lands in the fight log, any player's fight becomes reproducible - complaints and anti-cheat
  disputes turn into repeatable runs.
- The radar author answered the `LocationFishData` question and it reframes more than it settles. `GenerationTime` ->
  `StayTimeMinutes` was a deliberate optimisation: expiring the cache by date looked natural until it turned out the
  cache never expires while the client is paused, because game time stands still and so does biting. The client was
  simply not updated, and the field is useless to it either way. The consequence for us is that part of the
  `ObjectModel` divergence is intentional - client and server need different data - and the root mistake is the
  absence of DTOs separate from the business models on the server. So the comparison manifest we proposed must check
  the subset that actually crosses the wire, or it will flag divergences that were made on purpose.
- Our proofread of their deck confirmed slide 6 in full, corrected two things on slide 5 (a swallowed message does not
  come back "exactly the same as a success", and "up to three repeats" is one budget of three) and one generalisation
  on slide 7. Its own first draft contained the session's most instructive error: it "corrected" their `tPs` slide by
  claiming the consequence lands in missions rather than biting, when the early exit on `tackleStatus` sits sixteen
  lines above the `tMs` exit the same document had just cited as verified, and the key also feeds lure attraction,
  hitch generation and wear. An internal review caught it before it went out.
- 2026-08-15..17 — Convention 9 closed, and the local stand resurrected to prove it. The five pin tests written via a
  subagent-driven flow (one batch implementer, two independent adversarial seats, one fix round) and committed: SRV
  r16427; contract-pin assert strengthening r16428 (pP absence on the applied response; value-exact sN, pP presence
  and exact key count on the echo); comment revision fix r16429. Four Unit pins pass in suite; the contract pin
  verified TWICE against a live local NPN stand — original and strengthened editions. Bringing the stand up was its
  own excavation: the deploy loop needs the per-machine env-folder argument (a deploy without `-p:deploy` wipes every
  app's `dll.config` — Chat then kills the whole instance with "Connection string 'sql' cannot be blank"); local DBs
  turned out to be ONE PER BRANCH behind the user's environment-switcher tool (the active one is always named `Main`);
  the NPN DB was ten patches behind its own series (`PondPinIcons` was the boot blocker). Verification findings worth
  more than the run: the whole Integrated category is broken environment-wide — the shared ut profile is a 2014 relic
  whose dev rod matches no RodTemplate, the "save: UnitTestTemplate" checkpoint that AssemblyInitialize silently
  restores does not exist in ANY local DB, and both legacy harnesses are bit-rotted (pond purchases land in the
  unreachable Storage; component equip capacity; the slot processor initializes only on an on-pond Hands move) — the
  contract pin now runs on a freshly registered temp player and shows the repair pattern. The pins-landed letter took
  three review rounds before publication (opus seat 10 findings, Codex 7, then a scoped recheck of the rewrite): three
  REAL blockers caught — the client-fix revision in the exchange docs was off by one (r56959 is a foreign render
  commit; the actual fix is CLN r56960/FP-45737, verified by svn log, corrected in three doc spots plus the pin's own
  comment), the suite numbers had gone stale mid-work (a foreign r16424 added nine Unit tests to the same project;
  re-measured 292/0/3 at r16427 after svn update and a stand rebuild), and the "all five promised" claim was false for the
  escape pin (name never published before; the letter now also answers the client's open "fix or keep"
  question: pinned as baseline, GD decides before I1 recording). Letter + doc edits published to protocol-docs
  `fefa4a2`; JIRA comment on the epic posted (135754). Register lesson re-learned the hard way: impersonal voice in
  cross-team documents bans the SECOND person too ("your fix" -> "the client-side fix"); verbatim quotes exempt.
- 2026-08-17..24 — D1-D2 decision retro run to completion: 17 items, each re-owned by the user with the source
  document open in Plannotator (his annotations drove the depth; the assistant answered each with code/doc
  verification, confirm-or-refute). Verdicts: HOLDS across the board with riders; item 11's checks half REOPENED
  (detection system indicted by its own astronomical scores — per-check audit gates any v2 migration); item 13's
  premise DOWNGRADED (the 12.08 "both encodings forever" label treated as an acknowledgement of dual-transport
  reality, not a binding owner requirement — convention-12 treatment). The retro out-earned its cost in design
  deltas, all recorded to backlog: ignore-budget replacement (staleness/escalation/rate-limit + reverse-ack candidate
  field), §3.6 accumulate-not-drop + server-vs-client suppression split, divergence-§2C "no notification needed"
  correction (holds only under continuous traffic), the GAP-STALL analysis (dt lower bound unenforceable by
  construction; anti-stall = wall-clock deadline + per-reason gap policy + telemetry; user goal: "do not let the client stretch the fight to its own benefit"), FIXATION POINTS reconnected (a concept from the user's earlier matrix work with a server developer; already a glossary candidate via srv 2140 §5 — the user's synchronization rider is the new half), the catch-flow value-disclosure rule
  (weight hidden until landing — licenses/fines/kukan), the anti-cheat checks audit, the campaign invariant pending
  the user's sign-off, and TWO rules-pass filters (construction-level vs cosmetic; no v2 rule may rest on an as-is
  observation). Side products: an explainer of the seq/srvSeq counter anatomy (with a worked trace);
  `PreserveFishingState = N` measured on all five F2P PROD Mains, retiring the 2258 platform assumption; the
  FinishAttack contract-pin blind spot narrowed by code walk (central Clear, `tP` never re-echoed — Throw pin protects
  transitively); I1 scope narrowed at verdict (bite/generation out of the campaign's critical path — fight entry via
  the existing scripted-fish mechanism; stream split lands before any recording; exact-replay vs distributional
  comparison modes). Process rules that emerged: Plannotator windows are named per retro item and their lifecycle is
  managed (announce unseen content before closing; re-ask on comment-less closes); annotation replies always restate
  the annotated subject (the user cannot see his own annotations after submitting).
- 2026-08-31..09-02 — Published: the types-and-t0 reply and the sticky-keys classification (`a19592c`, `13eb40e`),
  the I1-scope letter `a6ef7aa` (recording-protocol rules: mandatory fish assignment, optional wait-skippers, no
  outcome clamps, identical config in record and replay, two comparison modes) and the two-keys letter `97ee383`.
  Verified on both trees: the short `Move` form cannot be sent after the hook, so the fast-reel slack immunity does
  not exist in a fight; the common extractor erases the slack stopwatch on any applied slot opcode without the slack
  key, and `Spool`/`ElectricAutoWinding` are legal in `FishFight` — the electric reel is the real in-fight erasure;
  this retracts the 2026-08-06-1509 conclusion (convention-10 correction in the letter). Positions: the registry rule
  "no key without a category" accepted, the enforcing tool declined for v1; two orthogonal absence columns instead of
  a fourth category; FP-46028 ordered after the slack-on-phases cure; the schema counts as frozen only after the rules
  pass. Glossary `1f7abec`: bite-off names the fish's action. Commit language English/ASCII in every repo.
- 2026-09-07..08 — Client side delivered the slack-to-phase design (2026-09-02-1939), a unilateral rules pass with a
  generated schema draft (2026-09-03-2021), tools and glossary entries; the owner decided to legalize the
  electric-reel slack immunity. Published: `c904898` (the decision accepted as the owner's, three candidate rule
  texts, GD text to follow, recount and admin form closed); `1e086cb` (GD-lead verdicts in person: electric-reel
  protection not to be made, pending prod counters and the owner's word; the windowed slack flag is intended
  smoothing, so "level" is rejected as the phase carrier and "duration > 0" accepted; slack rows and the wire form of
  the slack flag paused because the owner proposed server-computed slack with a delta-based state model; glossary
  rows hooking, slack synonym, window smoothing, phase carrier, slack suppressor); `225fa28` (git rules for the
  owner's own server work: integration branch `fp-45122-fish-fight-protocol-v2` from NPN, rebase-only task branches,
  MR landing, `env/fp-45122-*` tags; branch protection, tag mask and the owner's Developer role set up and read
  back). Verified: a missing slot number addresses slot 0; the pod no-escape window
  `ElectricReelFishEscapeSlackDelayOnPod` already exists. The client side then published the full v2 package — the
  written formulation the pause letter asked for.
- 2026-09-09 — Package v2.1 read; frame letter `96be4ad` published: FP-45122 = the fight wire only (TPM, the mission
  position operation, telemetry and diagnostics out); contract = DTOs from the schema, the encoding is the server
  side's layer and is slated for replacement; the 08-17 acceptance of the type whitelist as a permanent schema rule
  retracted; answers to the client side's requests (intervals as `GlobalVariables`, missed-interval policy,
  `SnapshotRequested`, the TPM relay is by design, the GD lead named); two questions ahead of the evaluation (delta as
  a separate type; console certification vs hard cutover). KB: module `tpm` created; the missions position-operation
  item corrected (two source substitutions needed); glossary rows Hooking and Fish Fight Protocol v2.
- 2026-09-10 — Codec cost measured (`artifacts/2026-09-10-codec-cost-measurement.md`, KB `b5ecbc1`): full-form
  `FightFish` on the Photon GpBinary path 204 bytes and about 11 KB of allocations per message against 56 bytes and
  about zero packed; prod counters from three game nodes give 4.4 fight-loop messages per online player per second;
  load model for today and for the five-slot ceiling.
- 2026-09-14 — Letter `e5d8d83` published: reply to the client side's one-page table of 2026-09-10 (four rows against
  the frame; the codec measurement and the load model; GameCarrier platform correction). The push rebased onto the
  client side's letter of 2026-09-10 12:30 and package edits (`c81d429`), unseen before the push: the frame is
  accepted (fight wire only, contract = DTOs, encoding = the server side's layer, unsigned = codec rule, response
  field names, intervals and the missed-interval policy, telemetry level removed); the owner keeps delta as a
  separate type with acks; the electric-reel rule is not built; hard cutover is replaced by two protocols side by
  side (protocol 2 on its own operation code, proposal 201 `FishFightV2`, selection per session via
  `GetProtocolVersion`). They ask: confirm the operation code and name; element order of the array fields in the
  snapshot response; GD proofreading. The published letter's §2 restates rows their letter had already settled.
- 2026-09-15 — Letter `a961a80` published: reply to the client side's five decisions. Facts of 2026-09-14 recorded
  as the server lead relayed them: the owner narrowed the first stage to envelope numbers, ticks and acks inside
  operation 193, left protocol switching to the server side, and by phone dropped the second operation code, agreed
  that binary packing covers the envelope's traffic and that the server lead's client-side changes reach the client
  tree as diffs. Server side's decisions in the letter: no second operation code, no dual support, no switches on
  either side (the only server variable enables the step-5 penalty after a journal-only release); the second
  question of 2026-09-09 §4 withdrawn (installations release separately, canonical order Steam/EGS first because one
  small team prepares releases); the evaluation of the principle replaced, without dates, by seven ordered steps with
  costs, dependencies and the mapping to the client's plan §33: 1 schema and DTOs on `IPhotonServerConnection` and the
  `GameProcessor` boundary with a codec interface (Hashtable behind it, wire byte for byte, unsigned DTO types over
  unchanged wire types, absence reproduced as absence); 2 envelope and acks per §8 with `v` dropped, `t0`/`t1` kept as
  `int` (a game-server connection lives at most `MaxDaysOnPond`, 7.5 real days), event numbering in, client acks of
  events later; 3 packed codec behind the interface for all 28 opcodes of operation 193, presence bits while a field
  is optional, Hashtable implementation removed; 4 full windows (all fields with values, four meanings of silence
  gone, slack read only as "was there slack in the window", timer source unchanged until step 5); 5 accounting by
  declared window with window arithmetic, two tolerances (relative for clock rate, constant seconds for silence and
  lag), gap budgets per sliding minute and per cycle, penalty left open between disconnect and forced fish escape
  (`EscapeFishOnRoomEnd`), first release journal-only, slot lifecycle table to answer question 12; 6 seeded
  randomness; 7 numeric state codes with a one-off migration. Deltas, thresholds and groups deferred by dependency
  (base = acked full state); division of labour: schema, generator and DTO types on the client side (FP-46119 minus
  the codec), codec, `PhotonServerConnection`, `GameActionAdapter` boundary on the server side, client-end changes
  as diffs. Two divergences with the owner's order, to be settled by the server lead in person: codec before ticks;
  snapshot, delta and groups after the first five steps. Four review rounds (fact-check, recipient read, Codex) before
  the push; the fish-restore benefit was dropped from the plan (needs FP-45678 first).
