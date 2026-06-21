# twitch-drops — Decision Log

(append-only; newest at bottom)

## 2026-06-21 [MFT] No-email linking crash — root cause + product direction
**Incident.** One week of linking-site logs (2026-06-11..06-17) showed the `@TwitchEmail` `SqlException` accounting for ~44% of 302 link attempts (134 failures, 18 users retrying deterministically — top user 29 tries). Side-effect: the same 9 users generated 65 `Invalid authorization code` 400s by re-submitting consumed OAuth codes after the 500.

**Root cause.** `DalAdapter.CreateLink` calls `AddWithValue("@TwitchEmail", twitchEmail)` with a CLR `null` when Twitch returns no e-mail. `AddWithValue(name, null)` stores a CLR null (not `DBNull.Value`), which SqlClient refuses to transmit → "parameter not supplied", failing before any constraint check. The column is nullable in all DBs, so `(object)x ?? DBNull.Value` is the fix. This is a regression of FP-34340 (which handled "no email" in the old session-based flow, "we do not use it anyway") — the hard dependency returned once the e-mail was persisted to the DB (FP-28678).

**Finding:** delivery (`DeliverDrops`) identifies the player by the stored token (TwitchId) and never reads `TwitchEmail`. So "no e-mail → no reward" is a *product* rule, not a technical necessity.

**Decision (Producer + Live-Ops + CS Lead).** Allow links with NULL e-mail; capture/backfill the e-mail when confirmed (page + delivery + daily job); gate reward delivery on a present e-mail with explicit support-readable logging. Tracked as FP-44591. Rationale: the e-mail is a wanted contact datum (FP-28678) but not needed for delivery, so we keep linking working while still pushing users to confirm.

## 2026-06-21 [MFT] Unify the Twitch HTTP client (FP-44590)
Two Twitch clients exist only because `Shared/Twitch` targets net472 and the net8 linking site cannot reference it. Decided to retarget `Shared/Twitch` to netstandard2.0 and unify (add `GetUserInfo`) so the e-mail backfill logic is written once and used by both site and server. DAL stays split (different connection models: site = N platform DBs; server = one DB) — deliberately not unified.

## 2026-06-21 [MFT] Finding: DataProtection keys not persisted
Linking-site DataProtection keys live in `/root/.aspnet/DataProtection-Keys` inside the container; a redeploy rotates them and kills active sessions (correlation/anti-forgery 500s, "not signed in" warnings). Already observed and deferred in FP-34340; now tracked in FP-44592 (persist keys + interim copy-from-live-container rescue).
