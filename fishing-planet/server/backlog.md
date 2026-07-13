# Backlog — Server

- [ ] Map client project structure
- [ ] Write module cards
- [x] Update matchmaking card to v2 format (5-section, YAML frontmatter, directional deps)
- [ ] Create bite-system module card
- [ ] Map key Photon server components (Master, Game, Chat, Club)
- [ ] Document DAL patterns and factory usage
- [ ] Map WebAdmin controller structure
- [ ] Revisit the ObjectModel client-distribution approach (manual source duplication, see `<kb>/reference/photon_interfaces_dll_distribution.md`). Manual mirroring is inconvenient and prone to silent divergence — the copies already drift: client `MotorBoat` omits all server `Params*` display fields, client `PedalKayak` carries unused/vestigial `ParamsEchoSounder`/`ParamsGps` and an extra `MaxSpeed` the server lacks. Suspected costs: forces client-side workarounds, redundant dead fields, no compile-time guard against drift; the only clear upside is simplicity. Evaluate alternatives (shared DLL like `Photon.Interfaces`, or source generation from a single SSoT) and document the real trade-offs. (Surfaced by review FP-44331: a server-only `ParamsIsobar` add raised "should this be mirrored?"; the answer for that field was no — these are server-produced display strings with no client consumer — but the mirroring model itself is the concern.)
- [ ] Software Distributor: server-side guard for node Stop — the dashboard confirm() covers the UI only, `HomeController.Stop` is an unguarded GET (bookmarks / direct URL bypass it); consider rejecting Stop for a node with players online unless an explicit force flag is passed. Needs an SD rebuild + redeploy. (Bubbled from FP-44875 on close.)

## Remove Mongo from the critical path (epic FP-44798)

Seeds for the Mongo-decoupling epic. A Mongo outage currently takes down the live farm because several hot-path subsystems call it synchronously. Two strategies per subsystem: remove the data from Mongo, or buffer through the file system so the game thread never blocks on Mongo. Surfaced by review FP-36095; motivated by a prod Mongo outage that took the farm down.

- [ ] Sessions / crude single sign-on live in the Mongo `oc` ("online cache", often mis-typed "online cash") collection and are read on the authentication path (`Dal\NoSql.Mongo\OnlineCash\MongoOnlineCash.cs`, `IOnlineCash`, routed via `OnlineCacheAdaper.cs`, consumed in `MasterAuthenticator`/`GameAuthenticator`). This is the biggest coupling — even resilient logging won't save the farm while login/session depends on Mongo. Decouple (move to a store that is not a farm-wide SPOF).
- [ ] Player IP records are written to Mongo on the hot path — move off the critical path.
- [ ] Diagnostic data is written to Mongo — move off the critical path.
- [ ] Full review of the user-logging subsystem: emission is via direct DAL calls writing mostly raw strings (rarely structured fields), tightly coupled to the log DAL; assess resilience and structure (see FP-44799 pipeline productionization, FP-44800 structured-logging refactor).
