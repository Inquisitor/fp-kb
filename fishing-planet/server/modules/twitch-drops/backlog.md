# twitch-drops — Backlog

- [ ] Prod sizing: count `TwitchEmail IS NULL` links per stack (Steam/PS/XB/Mobile) to set the daily backfill sweep batch size — deferred until prod data access (FP-44591).
- [ ] After FP-44590 lands, confirm the duplicate `TwitchAccountLinking.Utils.TwitchApiClient` is removed and all three solutions build (LoadBalancing, AsyncProcessor, TwitchAccountLinking).
