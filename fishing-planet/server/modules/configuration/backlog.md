# configuration — Backlog

## Done (2026-06) - MFT r16151 (CBT), r16152 (Retail); merged to NPN/Code r16153, r16154

- [x] Prod fix: RetailXBox WebAdmin + AsyncProcessor `XBox,Win10` → `XBox` (match Photon side; retail not on Win10).
- [x] CBT normalized to `Steam,Epic` across all 6 components (Photon Master/GameServer1/GameServer2/Chat + WebAdmin + Async; Club has no `Source`). Narrowed Master/Game from all-7 → `Steam,Epic` after DB confirmed CBT is Steam-only (see log).

## Source normalization (cross-component, cross-environment) — ticket

- [ ] File a dedicated ticket: normalize `Source` to be uniform per environment across all components (Master / Game / GameOnMaster / Chat / Club / WebAdmin / Async).
- [ ] Build the full matrix `env × component × current → target` for staging envs (Photon `Config/<env>/…` + `Build/Configs/{Async,WebAdmin}`). Prod (SoftwareDistributor) is the reference.
- [ ] Staging PC envs: remove stray `Apple` (QA, STEAMDEV, TEST2 WebAdmin; TEST Photon) → `Steam,Epic`.
- [ ] Add `Epic` to PC staging that still lacks it (auto-testing WebAdmin+Async; Test/TEST2/OceanTest/DEV Async).
- [ ] PondDev → `Steam,Epic` (PC stack); drop `Apple,PlayStation,Android`.
- [ ] Remove dead `M.RU` from GC (Web + Async). (`Tencent` — never-launched; not present in any current `Source`, keep on the dead-list for vigilance.)
- [ ] Remove stray `Steam` from NXDev → `Nintendo`.
- [ ] Caveat: removing a platform from runtime servers (Master/Game/Chat) is riskier than from WebAdmin — confirm the env does not serve that platform before stripping.

## CBT — DONE (resolved this session)

CBT was internally non-uniform (Master/Game = all 7, Chat/WebAdmin/Async = `Steam`). DB evidence confirmed CBT is Steam-only (zero non-Steam logins since the 2024 all-platform commit). Narrowed all components to `Steam,Epic`. See log "CBT environment internally non-uniform".

## Dead-environment cleanup (separate, do first)

- [ ] Identify and remove dead staging envs (config folders + Build/Configs files) before normalizing — shrinks the matrix. Candidates to confirm: OceanTest, GC/GCTEST, TESTvova, personal `stan-*` Photon folders.

## Verification gaps

- [ ] Confirm whether the AsyncProcessor delivery path ever sets AccessibleLevel for Epic products (currently none found) — determines whether Async `Source` widening is functional or cosmetic.
- [ ] Pin the exact revision that introduced multi-platform `Source` into WebAdmin/Async (between MI/2020 and IMV/2025-02) — optional, for completeness.
