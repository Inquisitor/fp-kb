# configs — Decision / Finding Log

Append-only. Decisions with rationale + lessons. `Finding:` = verified observation.

## 2026-06 [MFT r16130] FP-44134 root cause — Source gates AccessibleLevel

Finding: TEST WebAdmin `Source="Steam"` excluded Epic from `SupportedPlatformIds`, so Epic products never loaded into `MonetizationCache` and `ProductAccessibleLevels` had no entry for the Epic DLC. WebAdmin grant wrote a `LevelLockRemoval` with `AccessibleLevel=null`; the later PO purchase merge in `ProfileHelper.PutProductToProfile` requires `AccessibleLevel != null`, so it created a parallel record instead of summing. Fixed by `Source="Steam,Epic"` (r16130). Game Server on TEST already had `Steam,Apple,Epic`, so only the WebAdmin grant produced null records. Verified end-to-end by code read + code-reviewer agent.

## 2026-06 Finding: cross-component Source non-uniformity within an environment

Finding: a single environment can carry three different `Source` values across components (e.g. TEST: Photon `Steam,Apple,Epic`, WebAdmin `Steam,Epic` post-fix, Async `Steam`). Root cause is independent ad-hoc edits + copy/paste of "PC-ish" templates. Decision: configs must be uniform per environment across Master/Game/Chat/Club/WebAdmin/Async.

## 2026-06 Decision: production (SoftwareDistributor) is the canonical reference

Decision: `SoftwareDistributor/Configs/` (one folder, per-platform prod values) is the etalon. Prod is internally uniform per platform with one exception (RetailXBox, below). Derived PC canon = `Steam,Epic` (no Apple). Retail = platform only (no Epic, no Win10).

## 2026-06 [MFT] Finding: RetailXBox WebAdmin/Async `XBox,Win10` is a copy/paste artifact

Finding: prod RetailXBox Photon `Source=XBox` (since r7004, ivan; identical in MI/2020), but RetailXBox WebAdmin + AsyncProcessor `Source=XBox,Win10`. MI/2020 had only `PlatformId=3` (no multi-platform `Source`); `Win10` entered when multi-platform `Source` was rolled into WebAdmin/Async, copied from the digital-XBox template. Retail ships on neither Win10/Microsoft Store nor Epic. Present in all current branches; IMV already had it by 2025-02. r15382 (dmytro.kurylovych, `ReplaceTabsInAppSettings` tool) is the blame top but only rewrote whitespace — not the value origin. Canonical fix: RetailXBox WebAdmin/Async → `XBox`. Lesson: a mechanical mass-edit (tab replace) can mask a value's true origin in `svn blame`; trace the actual value via sibling branches (MI) and the unedited Photon side.

## 2026-06 Decision: canonical per-environment Source rules

Decision (agreed with maintainer): PC env (incl. PondDev) → `Steam,Epic`; `DEV` master base and `Yellow*` Code-branch dev/test → all platforms (intentional); console/mobile staging → match prod platform set; Retail → platform only; `M.RU` (dead mail.ru) and `Tencent` (never-launched) → remove everywhere.

## 2026-06 [MFT] Applied: RetailXBox prod Source canonicalized

Edited `SoftwareDistributor/Configs/RetailXBox.WebAdmin.Web.config` and `RetailXBox.AsyncProcessor.exe.config`: `Source` `XBox,Win10` → `XBox` (match Photon side). Prod RetailXBox now uniform `XBox` across all components. Committed r16152 (MFT); merged to NPN (Code) r16154.

## 2026-06 Finding: CBT environment internally non-uniform (3 distinct values)

Finding: CBT (AllInOne: Master/Game1/Game2/Chat/Club + WebAdmin + Async) carries three different `Source` values — Master/Game1/Game2 = `Steam,Epic,Apple,PlayStation,Android,XBox,Win10` (all 7); Chat/WebAdmin/Async = `Steam`; Club has no `Source` setting. Making CBT canonical `Steam,Epic` means NARROWING the Game/Master servers from 7 platforms to 2, not just adding Epic. Narrowing runtime servers is riskier than adding — needs confirmation CBT does not actively test non-PC platforms before stripping. Pending maintainer decision; not yet edited.

Provenance: the 7-platform list on CBT Master/Game1/Game2 originates in **r12146 (yurii.krepel, 2024-05-09, FTG20230906)** — message "Added support all platforms for CBT env". This was **intentional**, NOT drift — but the rollout was **incomplete**: r12146 touched only `GameServer1`, `GameServer2`, `Master`, leaving Chat (`Steam`, r11546), WebAdmin, and Async at `Steam`. Merged to mainline via r12168 (ivan, 2024-05-15, Vanya's bare "Merged revision(s)…" message). So CBT's intra-env divergence = a deliberate "all platforms for CBT" change applied to only the game-serving components. Open question (2026): is the all-platform intent still current? Resolved by DB evidence below.

DB evidence (CBT `Main.dbo.Users`, by `Source`, active non-deleted): Steam = 5271 users, 135 logins since 2024-05-09, last login today; PlayStation = 3 users, 0 logins since the commit, last login **2017-05-19** (legacy); `(null)` = 5 (dead, 2023); `M.RU` = 3 (dead, 2020). **Zero** Epic / Apple / Android / XBox / Win10 / Nintendo users at all. Conclusion: the "all platforms for CBT" change never produced any non-Steam usage — CBT is effectively Steam-only. Narrowing Game/Master from 7 → `Steam,Epic` is safe (no live non-PC testers; external PS/Xbox test-build delivery needs test-kits + NDA — impractical, confirmed by data). Epic kept as PC canon (key-gated Epic external testers are theoretically possible, unlike consoles).

Applied 2026-06 [MFT]: CBT normalized to `Steam,Epic` across all 6 components — Photon `cbt/{Master,GameServer1,GameServer2,Chat}/bin/Photon.LoadBalancing.dll.config` + `Build/Configs/{WebAdmin/CBT.Web,Async/CBT.AsyncProcessor.exe}.config`. Committed r16151 (MFT); merged to NPN (Code) r16153.
