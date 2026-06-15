---
status: resolved
executor: Yuriy Burda
branch: MFT @ r16165, merged to NPN @ r16166
jira: https://fishingplanet.atlassian.net/browse/FP-44341
---

# FP-44341: [FTUE][Friends] Friends cannot see each other's tackle in the profile when the same language is selected

## Summary

A player viewing a friend's profile does not see the tackle equipped on the friend's mannequin (doll) when both players have the **same** client language. With **different** languages the tackle is visible. Fix is server-side; related to FP-43576 (a prior translate/enrich-step skip case).

## Scope

- **MFT r16165** — Fix friend tackle hidden from same-language profile viewers
  - Rename `ProfileHelper.TranslateProfile` -> `TranslateAndPopulateProfile` (reflects dual role: translate strings + populate item config properties)
  - `ProfileAdapter.ObfuscateOtherPlayerProfile`: drop the `if (profile.LanguageId != languageId)` guard, call unconditionally
  - Update remaining 3 call sites to the new name
- **NPN20260602 r16166** — Merge of MFT r16165 (inherited via merge; close-phase skips merge)

## Regression origin

This is a regression introduced by **FP-43576 r16119** (Yevhenii Shust, 2026-05-25) — "Fix other-player profile translation without SetAddProps". Before r16119, `ObfuscateOtherPlayerProfile` did `fullProfile.LanguageId = 0; SysAdapter.SetAddProps(platformId, languageId, ...)`, where the forced `0` vs viewer `languageId` made the inner guard always true -> `TranslateProfile` (populate) always ran (at the cost of "Language updated" Sys-log spam). FP-43576 removed `SetAddProps` to kill the log spam and replaced it with a direct `TranslateProfile` guarded by `if (profile.LanguageId != languageId)` using the owner's real language -> populate skipped when owner and viewer share a language -> FP-44341.

**Review-accountability note:** the FP-43576 review (`review/FP-43576--profile-language-log-spam/`) raised this exact symptom as F-1 ("same-language profiles returned untranslated"), then RETRACTED it after the executor's challenge + a DB query proving `InventoryItem.Name/Desc/Params` are persisted. The retraction was incomplete: it verified the **translate** half (display strings survive serialization — true) but did not account for the **populate** half — specifically `RodSetup.Items`, which is NOT persisted (only `ItemIDs` are) and is rebuilt from `ItemCache` at read time by `TranslateRodSetup`. The DB check that "proved skip is safe" looked at inventory item strings, not rod setups. r16165's rename `TranslateProfile -> TranslateAndPopulateProfile` makes the dual responsibility explicit. Lesson: when a method both translates and populates, proving SOME outputs are persisted does not license skipping the whole method — re-enumerate every output (esp. computed/`[JsonConfig]` collections).

## Root cause (DB-verified)

`TranslateAndPopulateProfile` (ex `TranslateProfile`) translates display strings AND populates computed collections from `ItemCache`. The populate output that actually matters here is **`RodSetup.Items`**: persistence stores only `RodSetup.ItemIDs` (an `int[]`); the `Items` list (full `InventoryItem` objects) is a `[JsonConfig]` property rebuilt from those IDs by `TranslateRodSetup` (`ItemCache.GetItem` -> `CloneItem` -> `DisassembleItem`). `ObfuscateOtherPlayerProfile` sends the friend's `InventoryRodSetups` (not nulled in obfuscation). With equal languages the populate was skipped -> `setup.Items` stayed empty -> the client received rod setups carrying only `ItemIDs`, nothing to render on the doll -> tackle invisible. The fix runs populate unconditionally.

**DB evidence (local `Main.dbo.Profiles`, read-only):**
- A stored `Doll` rod (`UserId 1ac2b37e...`) already carries full config in `ProfileJson` — `Asset`, `ThumbnailBID`, `DollThumbnailBID`, `ItemType`, names/descs. So inventory-item config IS persisted; the earlier "config not persisted" framing was wrong (corrected).
- A stored `RodSetup` (`UserId 4acec0a2...`) persists only `"ItemIDs":[5890,5990,1158,1128]` + `InstanceId`/`Name`/`LineLength` — no `Items`. Confirms `RodSetup.Items` is populate-only.

**Confidence:** DB-proven that `RodSetup.Items` is populate-only and shipped to the friend; HIGH (not 100%) that the doll renders tackle from rod setups rather than from the (persisted) equipped Doll/Hands items — last-mile client-rendering not reproduced.

## Findings

### F-1: Unconditional translate now runs on every other-player profile view [Info]

**Description:** Removing the language guard means `ObfuscateOtherPlayerProfile` now always performs full translate+populate, even when viewer and owner share a language (the common case). Previously that case was skipped entirely.

**Investigation:** Read `TranslateAndPopulateProfile` body — the correctness-critical populate is `TranslateRodSetup` (rebuilds non-persisted `RodSetup.Items`); it is fused with translation in one method. Translation to the same language is idempotent (cache lookup yields identical strings), so no correctness harm; only minor extra CPU on the read path.

**Resolution:** Accepted — correctness requires the populate; splitting populate from translate would be a larger refactor with no functional gain here.

**Discovered by:** skill recon

### F-2: Pre-existing broken "force" in `ProfileAdapter.UpdateProfile` [Low / pre-existing, out of scope]

**Description:** At `UpdateProfile` the code does `serverProfile.LanguageId = 0; // force TranslateAndPopulateProfile in SetAddProps`, then calls `SetAddProps(..., serverProfile.LanguageId, ...)` passing the just-zeroed value as the target `languageId`. Inside `SetAddProps`, `originalLanguage = profile.LanguageId (0)` and target `languageId (0)` are equal, so the guard `originalLanguage != languageId` is false: populate is NOT forced AND `serverProfile.LanguageId` is left at 0. The handler then calls `peer.SaveProfileWithLog` -> the profile is persisted with `LanguageId = 0`.

**Investigation:**
- Read `SysAdapter.SetAddProps` signature/body and `ProfileAdapter.UpdateProfile` (lines 1015-1021): confirmed both old and new language are 0, guard never fires.
- Traced the caller in `GameClientPeer` (UpdateProfile suboperation, ~line 1851): `translateProfile = clientProfile.LanguageId != Profile.LanguageId` (true only on a real language change); `AssignClientProfileToServer` runs first (line 1877) and writes the NEW language (`serverProfile.LanguageId = clientProfile.LanguageId`, ProfileAdapter line 1233); then `UpdateProfile(translate:true)` zeroes it back to 0 and SaveProfileWithLog persists 0.
- r16165 only renamed the method on this line; the broken force logic predates the commit and is neither introduced nor worsened by it.
- Independently corroborated by a code-reviewer agent (same conclusion).
- **Severity downgrade Medium -> Low after tracing the mitigations:** (a) `GetProfile` normalizes `LanguageId == 0 -> DefaultLanguageId` on load (ProfileAdapter line 830), so no permanent `0` in displayed data; (b) own-profile load always runs with `translateProfile: true`, so stale stored strings self-heal on read; (c) the dominant language-change path is the direct `SetAddProps(platformId, languageId, ...)` calls in `GameClientPeer:2553` / `MasterClientPeer:1107` (real language from the request, guard works), NOT this `UpdateProfile` branch — so the broken force is largely latent. Worst realistic effect: a language change routed through `UpdateProfile` would not stick (saved 0 -> reverts to Default on reload). Contrast: the registration site (ProfileAdapter:307-310) uses the same idiom CORRECTLY — zeroes one object's field but passes a *different* object's real language as the arg.

**Resolution:** `Filed → FP-44378` (Story, Low, epic "Technical Debt - 2026 Q2", relates to FP-44341 + FP-43576). Pre-existing — out of scope for r16165. Trivial fix: capture the target language before zeroing and pass it (as the registration site does).

**Discovered by:** skill recon; corroborated by code-reviewer agent

## Verdict

**APPROVE r16165 + r16166.**

The fix is correct, minimal, and complete for FP-44341: dropping the language guard in `ObfuscateOtherPlayerProfile` makes the populate step run unconditionally, rebuilding the non-persisted `RodSetup.Items` (DB-verified: persistence stores only `RodSetup.ItemIDs`) that the same-language case was dropping. The rename is consistent across all 4 call sites (no stale references, compiles), the affected read path is the only other-player profile path, and there is no correctness regression from always running translate+populate on a transient, already-filtered profile object (idempotent, no persistence, no shared-state mutation). F-1 accepted as-is. F-2 is a genuine but pre-existing, out-of-scope defect, filed as FP-44378.

## Investigation Journal

- Phase 1 intake: executor field populated (Yuriy Burda), commits taken from JIRA comment at face value.
- Phase 2 VCS audit: confirmed MFT r16165 (`svn log | grep`) and NPN20260602 r16166 (merge of r16165). Matches JIRA exactly; no executor-quality discrepancy.
- WC at r16168 >= reviewed r16165 — disk reflects post-fix state; diff read via `svn diff -c 16165`.
- Grepped all `TranslateProfile`/`TranslateAndPopulateProfile` refs: all 4 sites renamed, no stale references -> compiles.
- Root-cause mechanism corrected mid-review after user challenge ("profile is stored already-translated, not raw"): initial "item config not persisted" hypothesis (skill recon + code-reviewer agent) was DB-refuted — stored Doll items carry full config (`Asset`/`DollThumbnailBID`/etc.). The true populate-only output is `RodSetup.Items` (persistence stores only `ItemIDs`), verified via `Main.dbo.Profiles` reads (`UserId 1ac2b37e…` complete item; `4acec0a2…` rod setup with `ItemIDs` only). Logged to [[review-process-observations]] + [[verify-persistence-before-translation-only-claim]].
- F-2 filed as FP-44378 (Story / Low / epic Technical Debt 2026 Q2), linked relates-to FP-44341 + FP-43576.
