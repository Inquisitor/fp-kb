# FP-43632 Backlog

Open questions, blocking items, and parking lot for the GameCarrier migration coordination task.

## Resolved (decisions integrated into rough-requirements.md / teamcity-and-config-flow.md)

### Track 1 — Build automation
- [x] **Trigger**: tags. Tag scheme is GC dev's call — our requirement is that tags are meaningful and trackable, and that every shipped DLL/EXE carries embedded version metadata so deployed binaries can be traced back to source revision.
- [x] **Storage form**: GC dev's call. Our suggestion — tag-based GitHub Releases on top of the existing flow into the `artifacts` repo.
- [x] **Source repos / build platform / artifact form**: in GC dev's domain. Existing artifact form (deploy-ready folder structure) carries forward by inheritance unless a deliberate redesign is made.

### Track 2 — Env configs in VCS
- [x] **GC-config filename in staging dirs**: not applicable. AllInOne staging nodes run on the default `config.json` from the `artifacts` repo (confirmed with GC dev). No env-specific GC configs need to be committed to SVN for staging.
- [x] **Steam vs EGS**: single farm, single config. PC = Steam + EGS (analogous to Mobile = Android + iOS).
- [x] **Steam/EGS staging schema**: Steam/EGS staging uses `steamdev` + bare `test` + `test2` + `qa` (no `steam`-prefix on test/qa) — historically established. **No `steamtest`/`steamqa` to create**; matrix corrected.
- [x] **Retail***: confirmed out of scope this cycle (later, after GC technology proves itself).
- [x] **Commit cadence in SVN**: GC dev's call.
- [x] **Merge to MFT**: ideally right after LBM commit; server team catches on acceptance if forgotten. **Strict invariant**: this merge must not be missed. Note from incident history: GC dev's commits have been missed cross-branch before — extra vigilance required.
- [x] **Source of staging GC configs for nx/xb/yellowtest**: AllInOne staging works on default `artifacts/deploy/config.json`. Confirmed with GC dev.
- [x] **Mobile/PS/Steam config template**: Nintendo (full TCP/WSS/QUIC vhost set, no XBox-style dummy). XBox's dummy TCP exists because MS certification bans unencrypted Photon TCP for client-server traffic, and the GC runtime at the time required at least one TCP vhost to bind for S2S to work.
- [x] **Canonical vhosts ordering**: by protocol (PHOTON → GAME_CARRIER), then by transport (tcp → wss → quic), then by port ascending.
- [x] **Retroactive canonical sort for existing Nintendo/XBox configs**: applied in LBM. Two files needed reordering (`Nintendo.Master.config.json`, `XBox.Master.config.json`); the other four (Nintendo/XBox Game and Chat) were already canonical. Reference file `artifacts/config.canonical.json` published in KB; canon proposed to GC dev for adoption in `vegasrc/artifacts/deploy/config.json`.

### Track 3 — Local dev environment
- [x] **Distribution form / local config layout / start scripts / personal dev profiles**: GC dev to design jointly with server devs. No premature decisions.
- [x] **Documentation home**: Confluence-only.

## Future work (post-decomposition)

- [ ] File new JIRA tickets adjacent to FP-43632; add links to them in this journal.
  - [x] Track 1 — Build automation: [FP-43669](https://fishingplanet.atlassian.net/browse/FP-43669)
  - [x] Track 2 — VCS-formalised env configs: [FP-43670](https://fishingplanet.atlassian.net/browse/FP-43670)
  - [ ] Track 3 — Local dev environment
- [ ] Migration runbook home: Confluence (section to be agreed by GC dev with the server team). Item kept open until subtasks start landing actual configs.
- [ ] **Confluence page: server transport ports / vhosts distribution** under `tech-guidelines/server/Infrastructure`. Identified as a gap during the TeamCity audit — no such page currently exists, and per-platform port distribution is largely common (with the documented Xbox edge case for client-facing TCP). Source material already in `artifacts/teamcity-and-config-flow.md` and `artifacts/config.canonical.json`; first draft by server team, review by GC dev.
- [ ] **Chat port cleanup (tech-debt)**. Today the Chat app rebases between `4520` (Chat-only node, where Master S2S is absent) and `4521` (AllInOne / Master node, where 4520 is taken by Master S2S) depending on node role. When the upcoming common-template-plus-platform-overrides config rework lands, fix Chat at `4521` universally to remove the rebase mechanic. No port collision then — Master S2S keeps 4520, Chat stays on 4521 everywhere, Club stays on 4522.
- [ ] **GameCarrier source audit — PHOTON-over-UDP transport**. Photon historically supports a UDP variant of the PHOTON wire protocol (ports 5055 Master / 5056 Game), unused in FP and absent from version-controlled configs. Whether GameCarrier provides a transport that exposes the same wire protocol over UDP (in addition to its existing `gcs-tcp`, `gcs-wss`, `gcs-quic`) is undetermined. Worth a one-time check against the GC sources to either confirm and document, or rule out.
