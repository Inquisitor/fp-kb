# Backlog — FP-33074

## Immediate
- [x] Ingest old FP-33074 Slack thread + JIRA history → [`artifacts/incident-chronology.md`](artifacts/incident-chronology.md)
- [x] Resolve client-version question via Confluence Releases pages (2026 Xbox = r53869, patched; residual defect is one cross-platform bug)
- [x] Determine the failure mechanism (chat-server code) → reorder race on ThreadPool dispatch of adjacent Leave/reJoin; [`artifacts/root-cause.md`](artifacts/root-cause.md)
- [ ] **Millisecond forensics:** extract + merge `sysLog`/`travelLog`/`securityLog`/`togetherLog`/`chatLog` (+ optional `cdLog`/`diagErrLog`) for Waz `a0fe2188-...` (and Gonzo `38aeb767-...`) over the broken 06-24 session; order within connection by `RequestId`; establish WHY the client thrashes Leave/reJoin and how tight the op timing is (the race window). Collections/queries: [`artifacts/mongo-log-collections.md`](artifacts/mongo-log-collections.md)
- [ ] Confirm exact client build via admin `/Stats/Errors` for the 2026 reporters (expect XB 2.9.11 / UWP 2.9.15, r53869)
- [ ] Reproduce live with the player + a test user flagged in `DebugUsers.lst` (chat-server) → read chat-server `MiniLog` to see Leave applied after Join (definitive proof) — only AFTER the forensic reconstruction

## Deferred / later
- [x] **History dig:** parallelism is all dmytro.kurylovych — `UseThreadPoolExecutor`/queue introduced under **FP-25995 "Chat Server: improve queuing"** (r10290..r10331, 2023-05), wired in `ChatApplication` r10756 (2023-08); same path touched under FP-31695 (2024, "chat hang on Mobile"). Caveat: reports predate it, FP-25995 *improved* a pre-existing queue → current mechanism, not provably the original cause. In [`artifacts/root-cause.md`](artifacts/root-cause.md).
- [x] Fix design — done and hardened via two adversarial review passes: [`artifacts/fix-design.md`](artifacts/fix-design.md) (hybrid room/node fence, inline lane + split-safety, membership-driven lifetime, presence reconcile, age canary)
- [ ] Promote [`artifacts/mongo-log-collections.md`](artifacts/mongo-log-collections.md) to a proper KB reference (KB lacks a full Mongo-collection description)
- [x] KB module — `<kb>/fishing-planet/server/modules/chat-server/` created (card + lifecycle-and-membership + minilog-format deep dives)
- [ ] Link FP-36219 as related; keep FP-44478 separate (already fixed, different root)
- [x] Reproduction strategy for QA — deterministic STRs derived from both mechanisms: idle past the inactivity window in club chat (eviction); rapid leave+join under load / F5 trigger (reorder)

## Post-release (after the fix ships to prod)
- [ ] **Monitor the fix telemetry in the chat-server log (`Chat.log`)** — consider moving the JIRA task to waiting-for-release and closing only after this check:
  - `Membership reconcile: dropped=..., skippedYoung=...` sweep lines — a growing `skippedYoung` means the grace window is load-bearing → tune `MembershipReconcileGraceSeconds`;
  - `AGE` canary lines (hourly) — `LongResidentOffline > 0` = leak suspects (something the reconcile should have caught); drill down via `FENCE` log entries for the affected users + PhotonTool `e ctx.Channels.ToArray()` (members, ages) live inspection;
  - `FENCE` verdict volume — a burst of `IGNORED`/`REJECT` lines flags an unexpected op source (e.g. an identity-less producer we ruled out).
  These are plain log lines today; if the MiniLog structured-JSON follow-up lands, they become filterable fields for DevOps log shipping.
- [ ] **Flags cleanup after prod confirmation** — remove `MembershipFenceEnforce` / `MembershipDrivenChannelLifetime` (both flipped ON and confirmed), the legacy timer path (`ChannelInactivityTimeout` / `ExpireDate` / `AbsoluteExpireDate` machinery) and the shadow-only branches. The flags are an activation/rollback lever, not a permanent config surface.
- [ ] **`Expire` final removal** — if prod logs show no `EXPIRE-IGNORED` traces over the observation window: remove `ChatChannelsCommands.Expire` handling and the constant server-side, and the dead client `ExpireChatChannel` API (client-side commit). Until then the command stays a logged no-op.
