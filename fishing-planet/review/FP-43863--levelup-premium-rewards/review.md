---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16100
jira: https://fishingplanet.atlassian.net/browse/FP-43863
---

# FP-43863: [FTUE][UI][Level Up] User does not receive premium rewards after buying premium from Level Up window

## Summary

FTUE bug: buying a premium account from the Level Up window does not deliver
premium rewards. Expected — rewards are granted, including the multi-level-up
case (rewards for every level gained). Requirement source FP-42346; parent
FP-43819. New feature still under test, per assignee.

Executor's fix (r16100): "Run post-delivery hooks on all product delivery
paths" — implies the Level Up purchase path bypassed the post-delivery hook
that grants premium rewards.

## Scope

- **MFT20260325 r16100** — Run post-delivery hooks on all product delivery paths
  (single file: `GameClientPeer_Monetization.cs`)
  - Introduces `RunPostDeliveryHooks()` (currently a thin wrapper over
    `TryApplyPremiumBonusAfterDelivery()`)
  - Adds the hook to active-purchase delivery paths that lacked it: PS, XBox,
    UWP, Steam (inside the `EnqueueSafeAction` after `DeliverSteamTransaction`),
    mobile receipt
  - Renames existing `TryApplyPremiumBonusAfterDelivery()` calls to
    `RunPostDeliveryHooks()` on login/sync paths (Steam/Nintendo/Retail
    ownership, MessageBus delivery, pending-items)
  - Wraps `TryApplyPremiumBonusAfterDelivery()` body in try/catch: logs via
    `ExceptionLogging` then re-throws

## Investigation Journal

- Intake: commit per executor comment = MFT r16100 (Code branch). Executor
  field populated (Yuriy Burda) — no hygiene warning.
- VCS audit: `svn log | grep 43863` on MFT confirms r16100 is the sole FP-43863
  commit. r16101 (cited as "test (16101)" by QA) = FP-43705, unrelated; "16101"
  is the server build number, not a fix commit.
- Root cause: the Steam Level-Up-window purchase path (`HandleGiveSteamProduct`
  → `DeliverSteamTransaction`) delivered the premium product but never invoked
  the premium-bonus applier, so frozen pending rewards were never granted.
- Re-throw safety verified: all NEWLY-covered sites (PS 356 / XBox 613 / UWP 709
  / mobile-receipt 980) are inside the method's own try/catch (graceful
  InternalServerError response + `ExceptionLogging`); Steam (763) is inside
  `EnqueueSafeAction` which swallows. Pre-existing renamed sites keep prior
  propagation behavior, now with added logging — no regression.
- Multi-level-up: handled by `PremiumBonusApplier.TryApplyPendingSnapshot` (FP-
  42346) — the frozen `DeltaExperience` is replayed through the full
  `IncrementExperience` pipeline (leveling + per-level rewards). r16100 only has
  to invoke the hook, which it does. No multi-level logic belongs in r16100.
- "All product delivery paths" claim holds: coverage now spans PS/XBox/UWP/Steam
  /mobile/Nintendo/Retail/MessageBus/pending-items. `HandlePremiumShopOperation`
  is correctly NOT hooked — its Open/Close PremiumBonusScope sub-ops create the
  snapshot, they are not a delivery path.
- Branch-copy / merge: r16100 is on MFT (Code = top of merge chain). QA build
  16101 is itself an MFT build, so the verified fix already lives where it
  ships. No downward merge to Content/LBM applies.

## Findings

### F-1: Re-throw surfaces secondary premium-bonus failure as a primary-delivery error [Low]

**Description:** At the newly-covered active-purchase sites (PS/XBox/UWP/mobile-receipt), the product is delivered and persisted via `SaveProfileWithLog` *before* `RunPostDeliveryHooks()`. The new try/catch in `TryApplyPremiumBonusAfterDelivery` re-throws, so a premium-bonus apply exception now propagates to the method's outer catch and returns `InternalServerError` to the client even though the product was already delivered. Pre-fix these paths never ran the applier, so this is a new (rare) failure mode. The Steam Level-Up path — the actual bug — is unaffected (response sent early, hook runs in a swallowing `EnqueueSafeAction`).

**Investigation:** Read all call-site methods on MFT r16100; confirmed catch blocks (PS 416, XBox 631, UWP 728, receipt 1012) send InternalServerError. Confirmed `SaveProfileWithLog` precedes the hook on these paths.

**Resolution:** Accepted — re-throw confirmed by assignee. The applier throws only on genuine errors; failing loudly (vs silently skipping the bonus) matches the bug class this ticket fixes, and the feature is under test where visibility is wanted.

**Discovered by:** skill recon

### F-2: `RunPostDeliveryHooks()` wraps a single call [Info]

**Description:** The new method currently only delegates to `TryApplyPremiumBonusAfterDelivery()`. Borderline premature abstraction.

**Investigation:** File inspection only.

**Resolution:** Accepted — a named, greppable post-delivery seam is justified given the bug was precisely "a delivery path missed a post-delivery step"; future hooks add in one place.

## Verdict

**Approve.** r16100 correctly addresses the root cause: the Steam Level-Up purchase delivery path now invokes the premium-bonus applier, and the hook is consistently applied across all product-delivery paths. Multi-level-up is handled by the pre-existing applier pipeline (FP-42346). No blocking findings; F-1 and F-2 are minor and accepted. QA verified FIXED on build 16101 (Steam/EGS). No cross-branch merge applies (fix is on Code = MFT, where the QA build originates).

Optional follow-up (non-blocking): one-line confirmation with the author on F-1 — whether premium-bonus apply failure should swallow (log-only) rather than re-throw at the active-purchase delivery sites.
