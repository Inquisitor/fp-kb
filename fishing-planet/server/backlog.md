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
