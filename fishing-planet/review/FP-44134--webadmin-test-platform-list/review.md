---
status: resolved
executor: Yuriy Burda
branch: MFT20260325 @ r16130
jira: https://fishingplanet.atlassian.net/browse/FP-44134
---

# Review: FP-44134 — Pond Pass not summed after DLC + PO purchase (WebAdmin platform list fix)

## Summary

Bug: after granting a DLC (gives 60 days of Pond Pass on a pond) via WebAdmin, then buying additional +3 / +7 days of Pond Pass through a Personal Offer, the days are NOT summed onto the existing record — a parallel record is created instead.

Per executor's JIRA comment, the root cause is a **TEST server configuration problem**: granting a product via WebAdmin does not set the Accessible Level properly, which starts a chain that leads to the bug. The committed change is a **point fix** for the WebAdmin platform list on the TEST server; a deeper cleanup of the pond-pass merge + Level Unlock logic is explicitly deferred (executor did not want to push it into the release branch now).

## Scope

- **MFT20260325 r16130** — Fix WebAdmin platform list for TEST server
  - Single-file config change: `Build/Configs/WebAdmin/Test.Web.config`, appSetting `Source` `"Steam"` → `"Steam,Epic"`
  - Already inherited in NPN20260602 (Code) via branch copy — no explicit merge needed (see Journal)

## Verified causal chain

The `Source` appSetting drives `PlatformMapping.Initialize` → `SupportedPlatformIds` (`Shared/SharedLib/Config/PlatformMapping.cs`). With `Source="Steam"`, `SupportedPlatformIds=[Steam]` only.

1. `MonetizationCache.LoadProducts` loads `MultilingualProducts` filtered by `SupportedPlatformIds` (Steam only).
2. `MonetizationCache.LoadProductsAccessibleLevels` builds the `ProductAccessibleLevels` cache by iterating *only* `MultilingualProducts.Cache` → Epic product IDs absent from the cache.
3. Granting the Epic DLC via WebAdmin → `MonetizationHelper.FromDto` calls `GetProductAccessibleLevel(productId)`, which `TryGetValue`-misses → `AccessibleLevel = null`. The created `LevelLockRemoval` record has `AccessibleLevel = null`.
4. Subsequent PO purchase of +3/+7 days runs `ProfileHelper.PutProductToProfile`; its merge lookup requires `r.AccessibleLevel != null` (temporary-pass branch ~line 1463; permanent-unlock branch ~line 1441). The null-AccessibleLevel DLC record is NOT matched → a **parallel** `LevelLockRemoval` is created instead of extending `EndDate`. Matches ACTUAL/EXPECTED exactly.

Fix: adding `Epic` to `Source` loads Epic products → `AccessibleLevel` resolves → DLC grant record carries a non-null level → PO merge matches and sums days.

## Investigation Journal

- Executor field (`customfield_11224`) empty in JIRA; commit author per comment = Yuriy Burda. Surfaced detect-only nudge, did not auto-fill.
- VCS audit (`svn log -r16000:HEAD | grep FP-44134`): single commit r16130, author yuriy.burda — matches JIRA intake, no mismatch.
- Causal chain verified by reading `MonetizationCache.cs` (`LoadProducts`/`LoadProductsAccessibleLevels`/`GetProductAccessibleLevel`) and `ProfileHelper.PutProductToProfile` directly, plus an Explore-agent trace of the `Source` → AccessibleLevel flow.
- Cross-environment check: enumerated `Source` across all `Build/Configs/WebAdmin/*.Web.config`. TEST's new `Steam,Epic` aligns with sibling Epic-hosting envs (QA `Steam,Apple,Epic`, TEST2, STEAMDEV, OceanTest). Each config reflects its environment's platform set (STABLE=Steam-only, NX*=Nintendo, etc.) — the fix is NOT an incomplete change; no prod-config gap. No production data risk: change is confined to a TEST environment config.
- Branch-copy inheritance (Phase 2 Step 5): NPN20260602 (Code) created at r16131 as copy of MFT20260325:16130. r16130 ≤ 16130 → inherited. Verified via `svn log -r16130` on NPN URL for `Build/Configs/WebAdmin/Test.Web.config` — revision present (changed-path shows original MFT path, copy preserves history). Explicit merge MFT→NPN NOT required; close phase skips merge.
- Deferred per executor: deeper cleanup of pond-pass merge + Level Unlock logic (graceful handling of null AccessibleLevel in `PutProductToProfile`) intentionally not pushed to release branch now.
- code-reviewer agent independently confirmed all 6 chain links. It additionally raised the STABLE/AsyncProcessor config gaps and the latent merge-guard hazard (F-1..F-3). It framed STABLE as "Critical production" — I down-rated this (see F-1 reasoning): the WebAdmin-grant path is an admin/QA operation, not the normal player purchase flow.
- Verified config values directly: `STABLE.Web.config`=`Steam`, `CBT`/`RetailSteamQA`=`Steam`; `Test.AsyncProcessor.exe.config`=`Steam` (and `TEST2.AsyncProcessor`=`Steam` while `TEST2.Web.config`=`Steam,Apple,Epic`). The downstream impact (does prod/async actually grant Epic DLCs) is unverified — author/ops question, not a confirmed bug.

## Findings

### F-1: Production/other WebAdmin configs (STABLE, CBT, RetailSteamQA) still lack Epic in `Source` [Medium]

**Description:** This commit fixes only `Test.Web.config`. `STABLE.Web.config`, `CBT.Web.config`, `RetailSteamQA.Web.config` keep `Source="Steam"`. If an Epic DLC Pond Pass is granted via one of those WebAdmin instances and the player later buys a PO extension, the identical null-AccessibleLevel → parallel-record bug reproduces there.

**Investigation:** Enumerated `Source` across all `Build/Configs/WebAdmin/*.Web.config`; values confirmed by grep. NOT a regression from this commit — pre-existing config state.

**Counter to code-reviewer's "Critical production" framing:** the failure requires the DLC to be granted *via WebAdmin* (admin/QA action). In production, players acquire Epic DLC through the Epic store → game-server monetization flow, which is correctly configured and sets AccessibleLevel. The STABLE-WebAdmin path triggers only when support staff manually grant an Epic DLC Pond Pass and the player then buys a PO extension — real but narrow. Hence Medium, not Critical, and decision-affecting rather than blocking.

**Resolution:** Author/ops clarification — does production (STABLE) WebAdmin grant Epic DLC Pond Passes? If yes, apply the same `Source` addition there. Non-blocking for r16130.

**Discovered by:** code-reviewer agent (config gap), severity re-assessed by skill.

### F-2: TEST AsyncProcessor config diverges from WebAdmin after the fix [Low]

**Description:** `Test.AsyncProcessor.exe.config` still has `Source="Steam"` while `Test.Web.config` is now `Steam,Epic` (same divergence on TEST2). AsyncProcessor also calls `PlatformMapping.Initialize(Settings.Source)` and loads `MonetizationCache`. If the TEST AsyncProcessor delivers Epic DLC products, it would hit the same null-AccessibleLevel path; components in one environment now disagree on supported platforms.

**Investigation:** Confirmed config values via grep across `Build/Configs/Async/*`. Whether the AsyncProcessor delivery path actually sets AccessibleLevel via the same cache for Epic products is NOT verified here — gap noted.

**Resolution:** Author clarification — if AsyncProcessor delivers Epic products on TEST, fold `Steam,Epic` into its config for environment consistency. Non-blocking.

**Discovered by:** code-reviewer agent.

### F-3: `AccessibleLevel != null` merge guard leaves existing null-level records permanently unmergeable [Medium, Pre-existing]

**Description:** In `ProfileHelper.PutProductToProfile`, both merge lookups require `r.AccessibleLevel != null` on existing records. Any record already written with null AccessibleLevel (which this bug produced) stays invisible to merge — future purchases keep spawning parallel records. The config fix prevents NEW null records but does not repair existing ones.

**Investigation:** Read `PutProductToProfile` (temporary-pass + permanent-unlock branches). Matches executor's own deferred-cleanup note in JIRA and the QA request to manually clean profile ProfileId=737.

**Resolution:** Pre-existing → module backlog (graceful null-AccessibleLevel handling / data backfill). Existing TEST bad rows handled by manual QA cleanup per JIRA. Non-blocking.

**Discovered by:** code-reviewer agent + executor's comment.

### F-4: `Source` single→multi changes `platformIdOverride` to null on TEST WebAdmin [Info]

**Description:** In `PlatformMapping.Initialize`, the single-source path sets a non-null `platformIdOverride`; the multi-source path sets it null, altering how `PlatformMapping(source, country)` resolves platform. Moving TEST from `"Steam"` to `"Steam,Epic"` flips this. Side-effect beyond cache filtering; likely benign for an admin tool but worth noting.

**Resolution:** Info / note only.

**Discovered by:** code-reviewer agent.

### F-5: Commit message typo "peoduct" → "product" [Info]

**Description:** r16130 message: "giving peoduct via WebAdmin". Cosmetic.

**Resolution:** Info only.

**Discovered by:** skill recon.

## Verdict

**Approve** r16130 as a correct, fully-verified point-fix for its stated TEST-WebAdmin scope. The causal chain (Source → SupportedPlatformIds → product cache → AccessibleLevel cache → null on grant → merge miss → parallel record) is verified end-to-end against the code and independently confirmed. The change is config-only, confined to a TEST environment, already inherited in the Code branch via branch copy (no merge needed).

Findings F-1..F-3 are not blockers and not regressions from this commit; F-1/F-2 warrant an author/ops question (do STABLE WebAdmin and TEST AsyncProcessor need the same `Source` addition?), F-3 is a pre-existing backlog item aligned with the executor's own deferred cleanup. F-4/F-5 are informational.

## Closure (2026-06)

Resolved. Verdict approve; **LGTM posted** (FP-44134 comment 123434). r16130 already inherited in NPN (Code) via branch copy — no merge for the reviewed commit, no `Merged ->` line claimed for it.

F-1/F-2 grew into a broader cross-component `Source` audit, now owned by the new KB module [[configuration]] (`server/modules/configuration`). Actioned under this ticket:
- **CBT** normalized to `Steam,Epic` across all components — MFT r16151, merged to NPN r16153. DB-confirmed CBT is Steam-only, so narrowing the Game/Master servers from all-7 was safe.
- **RetailXBox prod** canonicalized `XBox,Win10` -> `XBox` (WebAdmin + Async) — MFT r16152, merged to NPN r16154. `Win10` was a copy/paste artifact (Photon side already `XBox`).

F-2 gap closed by verification: AsyncProcessor has **no product-delivery path** (no `PutProductToProfile` / `AccessibleLevel` writes), so its `Source` is cosmetic — no bug risk. F-1 STABLE concern moot (that env no longer exists). Remaining staging normalization (Apple removal, Epic additions, PondDev, NXDev, M.RU/GC) + dead-env cleanup are tracked in the `configuration` module backlog for a future ticket. F-3 pre-existing merge-guard hazard remains a module-backlog item.
