---
status: resolved
executor: Yevhenii Shust
branch: MFT @ r16119
jira: https://fishingplanet.atlassian.net/browse/FP-43576
---

# Review: FP-43576 — `ObfuscateOtherPlayerProfile` spams Sys log with "Language updated" messages

## Summary

Opening other players' profiles floods the viewer's own Sys log with "Language updated from 0 to …" messages. Root cause (per ticket): the other-player profile flow goes through `SetAddProps`, which resets/applies the language as a state change and logs it. The fix removes that call from the other-player flow and translates the profile directly without mutating the other player's state or logging.

## Scope

- **MFT r16119** — Removed `SetAddProps` call from other-player profile flow; added direct `TranslateProfile` when language differs
  - Avoid "Language updated" spam in the viewer's Sys log
  - Avoid mutating other players' profiles
  - Stated impact: other-player profiles still translated; achievements still rebuilt via `AchievementManager`

## Findings

### F-1 (RETRACTED): "Same-language profiles returned untranslated" — refuted

**Original hypothesis (wrong):** that `GetProfileOutOfDto(profileDto, translateProfile: false)` + the new `if (profile.LanguageId != languageId)` guard would return un-named/un-translated items when viewer and viewed player share a language.

**Why it is wrong:** the hypothesis rested on the assumption that item display strings are filled *only* at translation time. They are not — they are **persisted** in `ProfileJson`:
- `InventoryItem` is `[JsonObject(MemberSerialization.OptOut)]`; `Name`, `Desc`, `Params` (InventoryItem.cs:22-24) carry **no** `[JsonIgnore]` → serialized and stored.
- `Profile.HomeStateName` is `[JsonProperty]` (Profile.cs:39) → stored.
- `ProfileAdapter.UpdateProfile` (ProfileAdapter.cs:1018-1021) re-translates only `if (translate)` with comment `// Translate profile if language changed` — confirming stored profiles already hold translated strings in the player's `LanguageId`, and the old `LanguageId = 0; SetAddProps(...)` force was an **unconditional re-translation for the language-change case** (a no-op when languages already match).

Therefore: a stored profile already carries display strings in the viewed player's language. When that language equals the viewer's, skipping `TranslateProfile` is **correct** — the strings are already right. When it differs, the new code translates into the viewer's language. The new conditional is correct and strictly more efficient than the old always-translate.

**Empirical confirmation (local `Main.dbo.Profiles`):** a Russian profile (`LanguageId=2`) stores `"Desc":"Серия TeleFloat® – это самые мощные телескопические удилища…"`, `"Params":"Длина: 4.5 м; Рабочая нагрузка…"`; a Ukrainian profile (`LanguageId=7`) stores `"Desc":"Серія TeleFloat® - це найпотужніші телескопічні вудилища…"`. Stored strings are in the profile's own language → `translateProfile:false` preserves them → same-language skip is correct.

**Lesson logged:** both skill recon and the code-reviewer agent failed to check `InventoryItem` serialization attributes before asserting "items raw". Verify persistence (JSON attributes / actual stored data) before claiming a field is translation-only. Caught by the executor's challenge, then proven by direct DB query.

### F-2: Returned DTO carries the viewed player's `LanguageId`, not the viewer's [Low / question]

**Description:** Old `SetAddProps` set `profile.LanguageId = languageId` (viewer) before returning; the new flow leaves `profile.LanguageId` as the viewed player's stored value, which `GetDtoOutOfProfile` copies into the response DTO. In the **cross-language** case the content is translated into the viewer's language while the DTO's `LanguageId` field still reports the viewed player's language — a minor internal inconsistency. The client knows its own language, so visible impact is unlikely.

**Investigation:** Traced `GetDtoOutOfProfile` → `MakeEqualTo(profile)` copying `LanguageId`; compared against old `SysAdapter.SetAddProps` line 16.

**Resolution:** Non-blocking. Optionally set `profile.LanguageId = languageId` after translating, to match prior behavior. Confirm with executor whether intentional.

**Discovered by:** skill recon.

## Notes

- Commit mixes a cosmetic rename (`profile`→`profileDto`, `fullProfile`→`profile`) and style churn (`?.Clear()`, brace additions) into the functional fix, inflating the diff. Not a defect; review-friendliness only.
- Commit-message claim "avoid mutating other players' profiles" is mildly overstated: the old `SetAddProps` mutated only the in-memory deserialized copy, never persisted to DB. The primary observable issue was the log spam.

## Verdict

**APPROVE.** The fix correctly removes the `SetAddProps` call (and its "Language updated" Sys-log spam) from the other-player flow, replacing it with a direct, conditional `TranslateProfile` that is correct given profiles are persisted already-translated. Own-profile flows (login/registration/SetAddProps sub-op) are untouched. Fix inherited into Code branch NPN via branch copy. F-2 is an optional Low-severity polish; the diff churn is a style nit. No blocking issues.

## Investigation Journal

- Intake: single commit MFT r16119 per executor's JIRA comment. Executor = Yevhenii Shust (probation).
- Phase 2 audit: `svn log -r 16100:HEAD --search "FP-43576"` → only r16119; matches JIRA. `--search` worked this session.
- Inheritance verified: NPN20260602 (Code) created at r16131 from MFT:16130; `svn log` on NPN's `ProfileAdapter.cs` shows the FP-43576 commit in history → r16119 inherited via branch copy, no merge to Code branch needed.
- Hypothesis "conditional translate breaks same-language case" formed during recon and (wrongly) confirmed by code-reviewer agent — both missed that `InventoryItem.Name/Desc/Params` are persisted (no `[JsonIgnore]`, OptOut).
- Executor challenged: profiles are stored already-translated, `LanguageId` marks the stored language, force-translate was for language change. Verified via InventoryItem serialization attrs + `Profile.HomeStateName [JsonProperty]` + `UpdateProfile` "translate if language changed" path → F-1 RETRACTED, verdict flipped REJECT → APPROVE.
- Findings routing: F-1 retracted; F-2 optional Low (card + JIRA question, non-blocking).
