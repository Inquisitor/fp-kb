---
page_id: "5696978945"
section: tech-guidelines/server
related_tasks:
  - FP-44593
  - FP-44590
  - FP-44591
  - FP-44592
---
# Twitch Account Linking: No-Email Handling & Reward Gating

How the Twitch integration behaves when Twitch does not provide a verified e-mail for a linked account: linking still succeeds, the e-mail is backfilled once the player confirms it, and Twitch Drop rewards are withheld until a confirmed e-mail is present. Child of [Twitch integration](https://fishingplanet.atlassian.net/wiki/spaces/FP/pages/3206119457).

<!-- {toc} -->

---

## Background

Twitch's `Get Users` API returns the player's e-mail **only when the account has a verified e-mail and the `user:read:email` scope was granted**. Some accounts have no verified e-mail, so Twitch returns nothing for that field. This is a normal, persistent state on the player's side — not an error.

Previously a missing e-mail crashed the link entirely (HTTP 500), so affected players could never link Twitch no matter how many times they retried. A week of production logs showed this blocking ~44% of all link attempts (18 distinct players retrying repeatedly). See epic [Twitch] Integration maintenance (FP-44593) for the fix.

## Decision

Reward delivery does **not** technically need the e-mail — Twitch Drops are delivered using the stored Twitch token. Even so, Product (Producer, Live-Ops Producer, CS Lead) decided that a **confirmed e-mail is required to receive rewards**, while linking itself must never fail because of a missing e-mail.

## Player Experience

- **Linking always succeeds**, even when Twitch provides no e-mail.
- If the e-mail is missing, the linking page shows a **warning panel**: the Twitch account is not confirmed, and a confirmed e-mail is required to receive rewards. The player is directed to verify their e-mail on Twitch.
- After the player verifies their e-mail on Twitch, the game **picks it up automatically** — no need to re-link:
  - on the next visit to the linking page (with a "your Twitch account is now confirmed" message),
  - the next time the player enters the game (drop delivery backfills it), or
  - within a day via a background sweep.
- **Rewards are not lost.** While the e-mail is missing, claimed Twitch Drops are simply held; once the e-mail is captured they are delivered on the next entry.

## Support / CS View

- **Player Card (WebAdmin):** when the e-mail is missing it shows a non-categorical note — "E-mail not provided by Twitch (account may be unconfirmed)". It deliberately does **not** state "unverified" as a proven fact (we cannot prove that is the only cause).
- **Delivery logs:** when a reward is withheld, the log states the factual reason (no e-mail on the link, likely an unconfirmed account) plus the Twitch token's granted scopes — so support can tell a genuinely unconfirmed e-mail apart from a missing-scope edge case (scope present + no e-mail = the account has no confirmed e-mail).

## Rollout

Servers deploy per stack (Steam / PlayStation / Xbox / Mobile). Nintendo (NX) has no Twitch rewards. During the rollout window, game servers that have not yet been updated keep delivering rewards even without an e-mail — this is accepted: the affected group is small and self-corrects once the gate is live everywhere.

## Implementation

Tracked under epic [Twitch] Integration maintenance (FP-44593):

- **FP-44590** — unify the Twitch API client into a shared library (prerequisite).
- **FP-44591** — no-email linking: crash fix, e-mail capture/backfill, reward gate, UX.
- **FP-44592** — OAuth error handling + DataProtection key persistence (session reliability).

Engineering detail lives in the KB module `twitch-drops` and the FP-44591 design spec.
