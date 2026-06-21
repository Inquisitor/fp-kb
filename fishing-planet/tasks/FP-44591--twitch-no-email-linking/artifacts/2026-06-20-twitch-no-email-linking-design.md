# Twitch Account Linking — No-Email Handling, Email Backfill & Reward Gating

**Status:** Approved (2026-06-21). Epic **FP-44593** "[Twitch] Integration maintenance"; stories **FP-44590** (#0, unify client) · **FP-44591** (#1, this feature) · **FP-44592** (#2, OAuth + DataProtection) created and linked.
**Date:** 2026-06-20
**Product decision by:** Producer, Live-Ops Producer, CS Lead
**Related:** FP-34340 (Twitch account link exceptions), FP-28678 (Save e-mail to Twitch link), FP-21797 (Error handling), FP-21080 (original Twitch epic), Confluence "Twitch integration" (3206119457)
**Subsystem reference:** KB module `twitch-drops` (`fishing-planet/server/modules/twitch-drops/`)

---

## 1. Problem & Evidence

Users intermittently fail to link Twitch to their game account. Analysis of one week of
production logs (`twitch-logs-2026-06-17.log`, 2026-06-11 … 06-17) found:

| Symptom | Count | Type |
|---|---|---|
| `SqlException: expects the parameter '@TwitchEmail', which was not supplied` | **134** | HTTP 500, unhandled |
| `400 Invalid authorization code` (token exchange) | 65 | handled (error page) |
| `AuthenticationFailureException` (code missing / correlation / anti-forgery) | 6 | HTTP 500 |
| `Violation of PRIMARY KEY 'PK_TwitchAccountLinks'` (re-link) | 4 | HTTP 500 |
| `Not signed in … DataProtection key expiration` | 10 | warn → re-login |

- The `@TwitchEmail` crash = **~44% of all 302 link attempts**, hits **18 unique users** who
  retry deterministically (top user 29 attempts). All F2P platforms affected
  (Steam 105, Epic 10, Apple 8, XBox 6, PlayStation 5).
- The 65 `Invalid authorization code` events are **the same 9 users** as the crash cohort —
  a retry side-effect of the 500 (re-submitting a consumed OAuth code). Expected to subside
  once the crash is fixed.

## 2. Root Cause

`Twitch/TwitchAccountLinking/DAL/DalAdapter.cs` — `CreateLink`:
```csharp
cmd.Parameters.AddWithValue("@TwitchEmail", twitchEmail); // twitchEmail can be null
```
`AddWithValue(name, null)` stores a CLR `null` (not `DBNull.Value`); SqlClient does not
transmit the parameter, and the server rejects the command before any constraint check.

`twitchEmail` is null because Twitch's `GET /helix/users` returns the `email` field **only when
`user:read:email` is granted AND the e-mail is verified** (per Twitch docs). The scope is
requested, `GetUser` validates only `Id`, and the controller passes the nullable `Email`
straight into `CreateLink`.

`TwitchAccountLinks.TwitchEmail` is **nullable in all DBs** — the DB would accept NULL; this is
purely a client-side ADO.NET defect. Because the INSERT crashes before writing, no link row
with NULL e-mail can currently exist, so every no-email user is fully blocked.

This is effectively a **regression of FP-34340**, which fixed the "no email" case for the old
session-based flow ("we do not use it anyway"); the hard dependency returned once the e-mail was
persisted to the DB (FP-28678).

## 3. Product Decision

E-mail capture is an explicit integration goal ("On link we grab player's verified e-mail" —
Confluence "Twitch integration"; FP-28678). Reward delivery (`TwitchManager.DeliverDrops`) works
purely off the stored token / TwitchId — **e-mail plays no technical role in delivery**. Despite
that, Product (Producer + Live-Ops Producer + CS Lead) decided to **require a confirmed e-mail
for reward delivery**:

1. Allow link with empty e-mail (never crash, link always created).
2. Linking page shows a **warning panel** when e-mail is missing: Twitch account not confirmed;
   a confirmed e-mail is required to receive rewards.
3. **Backfill** the e-mail once the user confirms it on Twitch — via a daily job AND
   event-driven (on linking-page visit and at drop delivery).
4. **Do not deliver rewards without an e-mail.** Log the non-delivery with an explicit,
   support-readable reason.
5. **Rollout** is per-stack (Steam/PS/XB/Mobile; NX has no rewards). Old (un-updated) game
   servers keep delivering without e-mail during the transition — **accepted**: few unverified
   users, self-corrects.
6. **WebAdmin Player Card** shows a **non-categorical** "no e-mail (account may be unconfirmed)"
   mark instead of the e-mail — see §5 wording note.

## 4. Architecture

The feature spans **4 processes** sharing the `TwitchAccountLinks` table through **2 DAL layers**
and (today) **2 Twitch HTTP clients**:

| Process | Framework | DAL | Twitch client |
|---|---|---|---|
| Linking site (`TwitchAccountLinking`) | net8.0 | `DalAdapter` (per-platform conn-string dict) | `TwitchApiClient` |
| AsyncProcessor (jobs) | net472 | `SqlProfileProvider` (single conn) | `TwitchApiUtils` |
| Photon game server (delivery) | net472 | `SqlProfileProvider` (single conn) | `TwitchApiUtils` |
| WebAdmin (Player Card) | net472 | `SqlProfileProvider` | — |

**Key facts:**
- The **DAL split is justified** (site = one process / N platform DBs; server = N processes /
  one DB each) — kept separate; both get a small `Set/UpdateTwitchEmail`.
- The **Twitch-client duplication is not justified** — it exists only because `Shared/Twitch`
  targets net472 (via `FishingPlanet.props`) and the net8 site cannot reference it. Fixed in
  Story #0 (FP-44590) by retargeting `Shared/Twitch` to **netstandard2.0** and unifying the client.
- Twitch Helix rate limit: **800 points/min per client_id**, 1 point/request — backfill volume
  (1 `GetUserInfo` per null-email link) is far below the ceiling even at high frequency.

### Backfill happens at three touchpoints, all sharing one `GetUserInfo` + `SetTwitchEmail`
1. **Linking page (`Index`)** — immediate feedback ("we see your Twitch account is now confirmed").
2. **`DeliverDrops`** — self-healing: on game start, if e-mail is null, fetch it; if now present,
   backfill **and** deliver in the same pass; else skip + log.
3. **Daily safety-net sweep** — for users who neither revisit the site nor launch the game.

The reward **gate** lives in `DeliverDrops`, applied **after** the inline backfill attempt.

---

## 5. Story Breakdown

### Story #0 (FP-44590) — Unify Twitch API client into a shared netstandard2.0 library *(prerequisite)*
- Retarget `Shared/Twitch` (`Twitch.csproj`) to **netstandard2.0** (override `TargetFramework`
  after the `FishingPlanet.props` import — a justified exception to the "don't duplicate
  TargetFramework" convention; document it).
- Consolidate the Twitch HTTP API into a **single modern HttpClient-based client** in
  `Shared/Twitch`, exposing `ValidateToken`, `RefreshToken`, `GetDropEntitlements`,
  `FulfillDropEntitlements`, and a **new `GetUserInfo(token)`** (`GET /helix/users` → id/login/email).
- Reference the shared client from net472 (server, AsyncProcessor) **and** the net8 site;
  remove the duplicate `TwitchAccountLinking.Utils.TwitchApiClient`.
- Verify all three consumer solutions build (LoadBalancing, AsyncProcessor, TwitchAccountLinking).

### Story #1 (FP-44591) — No-email Twitch linking: capture, backfill & reward gating
**Crash fix & data layer**
- `DalAdapter.CreateLink`: null-safe parameters (`(object)x ?? DBNull.Value`), all string fields.
- `DalAdapter`: add `UpdateTwitchEmail(platform, externalId, email)` and a read of the stored
  token for an existing link.
- `IProfileProvider`/`SqlProfileProvider`: add `SetTwitchEmail(source, externalId, email)` and
  `GetTwitchLinksWithoutEmail(...)`.

**Backfill (3 touchpoints, shared `GetUserInfo` + Set/UpdateTwitchEmail)**
- **Page** (`HomeController.Index`): existing link with empty e-mail → `GetUserInfo(stored token)`;
  present → update + success message; absent → warning panel.
- **Delivery** (`TwitchManager.DeliverDrops`): e-mail null → `GetUserInfo(token)`; present →
  `SetTwitchEmail` + proceed; absent → `Trade.Log` "Twitch drops NOT delivered: no e-mail on this
  Twitch link (Twitch returned no e-mail; the account most likely has no confirmed e-mail). User
  should verify their e-mail on Twitch." + return (skip **before** calling entitlements; CLAIMED
  entitlements persist on Twitch → delivered later, never lost). Wording is **factual** (no e-mail
  present) + **likely cause** (unconfirmed) — not an absolute claim. The skip log also appends the
  token's **granted scopes** (from `ValidateToken`) so support can tell "scope missing" apart from
  "no confirmed e-mail" (scope present + null e-mail ⇒ definitively no confirmed e-mail).
- **Job** (`BackfillTwitchEmailJob`, AsyncProcessor): **daily**; selects null-email links with a
  valid/refreshable token → `GetUserInfo` → `SetTwitchEmail`. Separate from
  `RefreshTwitchLinksJob` (different predicate & cadence).

**UX & admin**
- `Index.cshtml`: warning panel (unconfirmed) + success message (now confirmed).
- WebAdmin Player Card: when e-mail is null, show a **non-categorical** note, e.g.
  "E-mail not provided by Twitch (account may be unconfirmed)". **Wording note:** absence of
  e-mail is not proven to be caused solely by an unconfirmed account, so neither the UI nor the
  logs assert "unverified" as the definitive/only cause — they state the fact (no e-mail) and the
  likely cause.

**Minor hardening (same INSERT path)**
- `force_verify=true` (currently a bare flag = no-op).
- Handle `PK_TwitchAccountLinks` violation → friendly "already linked" / update existing link
  instead of HTTP 500.

### Story #2 (FP-44592) — Harden Twitch link OAuth error handling + persist DataProtection keys
- OAuth handlers: `options.Events.OnRemoteFailure` / `OnAccessDenied` → redirect to a friendly
  page instead of HTTP 500 (covers code-missing / correlation / anti-forgery).
- Persist DataProtection keys outside the container (volume / DB / Redis) so container restarts
  no longer invalidate active sessions (root cause of the correlation/anti-forgery failures and
  the "not signed in" warnings; deferred in FP-34340).
- **Immediate mitigation — rescue the current sessions:** the keys are plain XML at
  `/root/.aspnet/DataProtection-Keys/key-*.xml` in the live container. Copy them out onto a
  persistent volume and mount it back (`PersistKeysToFileSystem(/keys)`) **before** the next
  redeploy — the active key is preserved, existing cookies stay decryptable, and current sessions
  survive. This can ship ahead of the full persistence solution and salvages already-affected
  users now.

---

## 6. Rollout & Deferred

- Servers deploy per-stack (Steam/PS/XB/Mobile). NX has no Twitch rewards. During the rollout
  window, un-updated game servers still deliver to no-email users — **accepted** (small cohort,
  self-corrects after the gate ships).
- **Deferred sizing input:** count of `TwitchEmail IS NULL` links on prod (per stack) — used to
  finalize the daily sweep batch size. Pull when prod data access is arranged.

## 7. Status

Design approved; epic FP-44593 + stories FP-44590/91/92 created and linked (2026-06-21). No code yet.
