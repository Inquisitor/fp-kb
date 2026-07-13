---
module: chat-server
---

# Chat server - backlog

- [ ] Implement the unified fenced membership store (FP-33074 fix) - see [fix-design](../../../tasks/FP-33074--chat-messages-disappear/artifacts/fix-design.md)
- [ ] Sub-fix: purge `PlayerCache2` on game-node disconnect (pre-existing presence leak)
- [ ] Retire the dead `Expire` chat command (FP-13595 UGC-era, caller never shipped): server no-op + log, remove `AbsoluteExpireDate` with the timer machinery, update `ChatChannelsCacheTest`; drop the client-side dead `ExpireChatChannel` on occasion (part of the FP-33074 fix)
- [ ] Restructure `MiniLog` into structured JSON (FP-33074 follow-up; output is already JSON on prod)
- [ ] Hardening: per-user channel cap in the membership store (`AuthorizeChannelMessage` gates only club channels; a misbehaving client could join arbitrary channel names) - deferred from the FP-33074 fix plan
