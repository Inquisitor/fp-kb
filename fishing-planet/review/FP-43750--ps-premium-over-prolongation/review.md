---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16085+r16115, merged to LBM20251201 @ r16116
jira: https://fishingplanet.atlassian.net/browse/FP-43750
---

# Review: FP-43750 — [PS] Premium subscription duration exceeds the purchased period

## Summary

PSPROD bug: PlayStation premium subscriptions were granted longer terms than purchased.
Root cause per executor: `HandleGivePsProduct` delivered the PS product without passing the
PlayStation-supplied `expireDate`, so each entitlement re-sync prolonged `SubscriptionEndDate`
by `Term` again instead of pinning it to the platform expiry. The one-line fix passes
`expireDate` into `ProductDeliveryService.DeliverProduct`; a drift-check test plus a regression
test were added on the Code branch and merged into Content.

## Scope

### MFT20260325 (Code)
- **r16085** — actual one-line production fix, mis-committed under unrelated message
  "FP-43172 Support PedalKayak boat type (trolling cap, anti-cheat, stats, equipment)"
  - Added `expireDate: expireDate` to the `ProductDeliveryService.DeliverProduct` call in
    `HandleGivePsProduct` (`GameServer/GameClientPeer_Monetization.cs`)
- **r16115** — Add HandleGivePsProduct drift check + resync + regression test
  - `#region HandleGivePsProductBody` markers in the real method and its test copy
  - drift-check test `Test_HandleGivePsProductBody_copy_matches_real_method` (asserts copied
    body stays in sync with the real method)
  - regression test `Test_PA_Resync_Does_Not_Prolong` (pins the repeated-resync scenario)
  - test-copy body sync + two no-op stubs

### LBM20251201 (Content, merged)
- **r16116** — MFT->LBM merge of r16115 + the missing one-line production fix re-applied
  directly (r16085 not in the merge range because of its FP-43172 attribution)

## How the fix works (verified against r16116 sources)

`HandleGivePsProduct` has a single product-delivery site (the `else`/new-delivery branch) and a
separate `alreadyGiven` branch:

- First delivery: `alreadyGiven == false` -> `ProductDeliveryService.DeliverProduct(..., expireDate: expireDate)`
  pins `SubscriptionEndDate` to the PS-supplied `expireDate` (reconstructed from `request[Data]`
  ticks). Before the fix the call omitted `expireDate`, so delivery prolonged by `Term`.
- Re-sync (same `expireDate`): `alreadyGiven = (currentExpireDate != null && expireDate == currentExpireDate)`
  is now true -> `UpdateSubscriptionEndDate` sees no change -> no prolongation, and
  `LogSubscriptionUpdated` (the club-chat notification) is skipped. Both reported symptoms
  (over-prolongation + per-login notifications) are addressed by the one line.

## Findings

### F-1: Cross-session idempotency rests on an unenforced whole-second invariant; regression test can't catch a violation [Low / robustness + test-gap]

**Description:** Re-sync idempotency relies on exact `DateTime` equality
`alreadyGiven = (expireDate.Value == currentExpireDate.Value)`. `SubscriptionEndDate` is persisted
to a SQL **`datetime`** column (rounds to ~1/300 s), while `expireDate` is reconstructed from
client ticks (100 ns). If the PS-supplied expiry ever carried a sub-(1/300 s) component, then after
a profile reload `expireDate != currentExpireDate` -> `alreadyGiven == false` -> the `else` branch
re-runs and fires `LogSubscriptionUpdated` (club-chat notification) every login. The **duration**
stays capped regardless (`PutProductToProfile` sets `newEndDate = expireDate.Value`), so this can
only ever resurface the *secondary* symptom, not the ticket's primary one.

**Investigation:**
- Discovered by the code-reviewer agent; mechanism verified end-to-end here.
- Column type: `Profiles.SubscriptionEndDate datetime` (`SQL/PowerDesignerDBScript.sql`;
  `SavePlayerProfile` proc takes `@SubscriptionEndDate DATETIME`) -> 1/300 s rounding on persist.
- No second-truncation in the path: `ProfileHelper.PutProductToProfile` -> `newEndDate = expireDate.Value`;
  `UpdatePremiumSubscriptionEndDate` assigns verbatim. Sub-second ticks would reach the DB.
- Test blind spot: `HandleGivePsProductTest.SaveProfileWithLog` is a no-op stub -> no DB round-trip
  -> `Test_PA_Resync_Does_Not_Prolong` compares the exact in-memory value and cannot reproduce a
  rounding mismatch.
- **Client-path trace (FP-owned source):** `PlayStationManager.GivePsProduct(..., entitlementBeingConsumed.ExpireDate)`
  sends `e.ExpireDate.Ticks`, where `e` is a Sony `NpToolkit2` `ServiceEntitlement`. That type lives
  in the Sony plugin (not in the FP repo), so its precision can't be proven from source.
- **Evidence it's whole-second in practice:** sample telemetry `Expire date: 2026-05-21 08:36:25` /
  `Create date: 2026-05-14 08:36:25` (exactly 7 days, whole seconds); PSN commerce timestamps are
  epoch-second based. Whole seconds are exactly representable in SQL `datetime`, so the round-trip
  is lossless and `alreadyGiven` stays true -> no spam. Caveat: the log uses `ToString("...HH:mm:ss")`,
  which would mask sub-seconds anyway, so this is strong-but-not-conclusive.

**Resolution:** Accepted — not a live defect given PSN's whole-second entitlement timestamps; the
pre-fix notification spam is fully explained by the prolongation mismatch, not by rounding.
Optional hardening (non-blocking): truncate `expireDate` to whole seconds at parse, or compare at
second granularity, so idempotency no longer depends on an external platform invariant; and, if a
cheap seam exists, cover the persist round-trip so this path isn't test-blind.

### F-2: Drift-check reads source via `[CallerFilePath]` at runtime — CI fragility [Low-Med]

**Description:** `Test_HandleGivePsProductBody_copy_matches_real_method` reads the real `.cs` via
`[CallerFilePath]` (compile-time absolute path) + relative hop `..\LoadBalancing\GameServer\GameClientPeer_Monetization.cs`.
If tests run where the source tree isn't present at that path (artifact-based or multi-machine CI),
`File.ReadAllText` throws FileNotFound -> spurious RED unrelated to actual drift.

**Investigation:** Surfaced by code-reviewer agent; verified here. The relative hop resolves
correctly (`LoadBalancing.Tests` and `LoadBalancing` are siblings). `Tests.Debug.runsettings` is
empty -> MSTest V2 runs in-place from build output, so the test works whenever the source checkout
is present at the compile-time path (the normal dev/`dotnet test` and co-located-CI case). It is a
**new** pattern (no other `[CallerFilePath]` source-reads exist in the branch), so it has not been
exercised against the team's CI topology. Failure mode if source is absent: a confusing
`FileNotFoundException`, not the intended drift `Assert.Fail`.

**Resolution:** Accepted if build+test are co-located (most likely). Cheap hardening (non-blocking):
wrap the read in `try/catch (IOException) -> Assert.Inconclusive(<clear message>)`, or embed the
real body as a compile-time embedded resource. Author to confirm CI topology.

### F-3: Production one-liner committed under unrelated ticket FP-43172 [Low / executor-quality]

**Description:** The actual production fix (MFT r16085) was bundled into the FP-43172 "Support
PedalKayak boat type" commit with a misleading message; not discoverable via FP-43750 in MFT
history (`svn log | grep FP-43750` finds only r16115/r16116).

**Investigation:** `svn log -c 16085 -v` confirms r16085 is the FP-43172 PedalKayak commit and
touches `GameClientPeer_Monetization.cs`. Executor self-disclosed the full audit trail in JIRA;
LBM re-application (r16116) is correctly attributed.

**Resolution:** Accepted — transparent disclosure mitigates the traceability loss. Process note:
do not bundle unrelated production fixes into feature commits.

### F-4: Hand-copied method body + regex drift-check is a fragile testing pattern [Low / design]

**Description:** The bug's root cause was that the test class's copy of `HandleGivePsProduct` had
drifted from the real method (copy correct, real buggy), so the pre-existing `GenTest_PA_Buy`
passed while production was broken. The fix adds the drift-check to prevent recurrence.

**Investigation:** Extracted `HandleGivePsProductBody` from real+test at r16116 on both LBM and MFT
and compared (whitespace-normalized): EQUAL on both -> drift-check passes today. Method is tightly
coupled to `GameClientPeer`, so direct testing is hard; copy+drift-check is a pragmatic stopgap.

**Resolution:** Accepted as pragmatic. Optional follow-up: extract delivery orchestration into a
testable unit (module backlog, non-blocking).

### F-5: Forward-only fix; already over-granted PS subscriptions not corrected [Info]

**Description:** The fix prevents future over-prolongation but does not roll back existing inflated
`SubscriptionEndDate`s for players affected in PSPROD. Clawing back would be player-hostile, so
almost certainly intentional.

**Resolution:** Info — product awareness only; no code action.

### F-6: Manual re-apply leaves no mergeinfo for the one-liner [Info]

**Description:** r16085 was outside the r16116 merge range (FP-43172 attribution), so the one-liner
was re-applied by hand on LBM. A future MFT->LBM merge of the FP-43172 PedalKayak change will
re-touch that same line -> likely a no-op or trivial text conflict.

**Resolution:** Info — minor future-merge heads-up.

## Checklist

- [x] Duration fix correct: `expireDate` -> `PutProductToProfile` caps `newEndDate = expireDate`
      (old path prolonged via `SubscriptionEndDate.AddDays(Term)`); re-sync hits `alreadyGiven`
- [x] Per-site audit: single PS subscription delivery site (line 343) fixed; sibling sites are
      Xbox/UWP (no subscription-expiry semantics, out of scope) / receipt-validation (already
      passes `expiresAt`, line 955 — the correct reference pattern) / boat-rent (out of scope)
- [x] Regression test exercises real `DeliverProduct` + real `Profile`/`UpdateSubscriptionEndDate`
      (only logger/analytics/save faked); asserts exact in-memory `SubscriptionEndDate == expireDate`
- [~] Cross-session idempotency NOT covered — `SaveProfileWithLog` stubbed, no DB round-trip (F-1)
- [x] Drift-check regions EQUAL on both LBM and MFT at r16116
- [x] LBM r16116 one-liner identical to MFT r16085
- [x] Stable (KNW20250723) uses old `PutProductToProfileAndLog(..., expireDate)` -> unaffected;
      bug confined to the `DeliverProduct` refactor on LBM/MFT only -> fix scope correct
- [x] Independent verification: code-reviewer agent (surfaced F-1, F-2). Codex could NOT run —
      its Windows sandbox blocked process creation (`CreateProcessAsUserW failed: 5`); it read
      nothing and correctly declined to infer. No second opinion obtained from Codex.

## Verdict

Draft: APPROVE — the fix is minimal, correct, verified to the storage layer, and consistent with
the established correct pattern (`HandleProcessProductPurchaseReceipt`). F-1 verified down to a
Low robustness note: cross-session idempotency holds given PSN's whole-second entitlement
timestamps (sample telemetry confirms; Sony plugin precision not provable from FP source) —
optional hardening is to truncate `expireDate` to seconds and cover the persist round-trip. F-2
(CI fragility) and F-3/F-4 (process/design) are non-blocking; F-5/F-6 informational. No blockers.

## Investigation Journal

- Intake: Executor field (`customfield_11224`) empty; executor identified as Yuriy Burda from
  the JIRA audit-trail comment. Commits taken from JIRA at face value; SVN audit deferred to
  Phase 2.
- Branch roles (from `_index.md`): MFT20260325 = Code, LBM20251201 = Content. Fix flowed
  Code -> Content; verified in Phase 2 this is correct scope (not a finding) — see Stable check.
- Ancestry: MFT20260325 forked from LBM20251201:15942; r16085/r16115 are post-fork, so not
  inherited by LBM -> explicit merge r16116 is justified (consistent with executor's note).
- SVN audit: `svn log | grep FP-43750` finds r16115 (MFT) + r16116 (LBM) but NOT r16085 (it is
  the FP-43172 commit) -> F-1.
- Hypothesis "two delivery sites need fixing" disproven: reading the full method shows ONE
  `DeliverProduct` site; the confusing test-file diff (`PutProductToProfileAndLog` ->
  `DeliverProduct`) was the test copy catching up to a prior real-method refactor, not a second site.
- Verified drift-check by reproducing its region-extraction (Node) on both branches: regions EQUAL.
- Verified Stable (KNW20250723) delivery path is the old correct `PutProductToProfileAndLog(...,
  expireDate)` -> bug confined to LBM/MFT; fix needs no merge to Stable/OldStable.
- Per-site audit of all `DeliverProduct` calls in the LBM file: 343 (fixed), 955 (already correct),
  605/699 (Xbox/UWP, out of scope), 1916 (boat rent, out of scope).
- Dispatched independent checks: code-reviewer agent + Codex (gpt-5.5). Codex failed to run on
  this Windows host (sandbox `CreateProcessAsUserW failed: 5`) — read nothing, declined to infer;
  no second opinion from it. Agent surfaced the precision/notification risk (F-1) and CI fragility
  (F-2).
- Verified F-1 mechanism end-to-end: `Profiles.SubscriptionEndDate` is SQL `datetime` (DDL +
  `SavePlayerProfile` proc); `ProfileHelper.PutProductToProfile` sets `newEndDate = expireDate.Value`
  with no truncation; test `SaveProfileWithLog` is a no-op stub so the regression test never
  round-trips through DB. Severity set to Medium (not High): primary duration symptom is fixed;
  notification residue is conditional on sub-second PS expiry + `!UseTrackedDelivery` (both
  unverified in PSPROD) -> decision-affecting question, not a confirmed defect.
