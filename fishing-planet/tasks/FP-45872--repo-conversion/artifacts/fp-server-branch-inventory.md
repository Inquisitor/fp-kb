# fp-server (GitLab) — branch inventory of the first conversion

Snapshot taken 2026-08-15 from `fishing-planet/server/fp-server` (project id 14, git.fishingplanet.org).

## Summary

- Full SVN branch tree converted (back to 2016), `master` = trunk lineage. Default branch: `master`.
- Repository size 283 MB, no LFS objects; `master` carries 4258 commits. No tags.
- **Committer dates are rewritten to import-run dates** (2026-02-21 base run; KNW re-synced 2026-02-26; LBM re-synced 2026-04-08 = last sync). Author dates presumably historical — verify.
- **No SVN revision metadata in commit messages** (no `git-svn-id` trailer) — SVN rev <-> git commit mapping must be reconstructed by message/author-date matching.
- Present: old `MFT20260209` (the branch later deleted in SVN and re-created as `MFT20260325`).
- **Missing: `MFT20260325`, `NPN20260602`** and all SVN commits after the last LBM sync (2026-04-08).
- Temporary/dead branches from the historical delete-branch flow are included (`TMP_`, `*TMP`, `R2018*`, ...).

## Reading the table

Date = committer date of the branch tip (i.e. when the conversion run imported it, NOT the historical commit date). Tip message identifies the last converted SVN commit.

## Branches

| Branch | Tip imported | Tip commit | Tip message |
|--------|--------------|------------|-------------|
| `AccClosure` | 2026-02-21 | 1d3472c5 | FP-10499 - Naming WebAdmin Changes part 3 - comments in saving geometry |
| `BRA20201214` | 2026-02-21 | 8d5ce1bc | FP-21595 - Fixed copyright automatic year update |
| `Boats20170816` | 2026-02-21 | 357c637c | FP-6487 - New achievement counter for night fishing |
| `BottomFishing20170804` | 2026-02-21 | 0de81ec1 | Special config for auto-tests on dev envs |
| `CLB20211202` | 2026-02-21 | 747e3b40 | Merged revision(s) 9361 from branches/CLU20220510: FP-23045 - CommandLine: Fix a |
| `CLU20220510` | 2026-02-21 | eaa1c840 | FP-23989 - Load detection, RAM usage flags in PROD configs |
| `CLX20220713` | 2026-02-21 | 97e1b21b | update configs for oceandev |
| `CLY20220905` | 2026-02-21 | 97be8be2 | FP-27741 - Give PS pond pass with WebAdmin without platform control |
| `CLZ20230216` | 2026-02-21 | eb1b16ad | FP-28402 - Added new key overrides to deployment |
| `CarpFishingRelease20190322` | 2026-02-21 | 13693feb | Merged revision(s) 6340 from branches/MotorBoats20190116: |
| `ConsoleBoats20171017` | 2026-02-21 | 21ca79d1 | Merged revision(s) 3307, 3309 from trunk: |
| `ConsoleBoats20171107` | 2026-02-21 | d96dde1b | Merged revision(s) 3352-3353 from trunk: FP-8090 - Additive generation of compet |
| `Consoles20170629` | 2026-02-21 | b728eabf | Merged revision(s) 3345 from trunk: Dev & PsDev data freeze |
| `Consoles20180323` | 2026-02-21 | 484a1167 | FP-10349 - Added DEBUG logging PS product delivery |
| `EGS20230619P4` | 2026-02-21 | 8a7363ca | FP-29937 - Fix for bug with PSN supplying incorrect information for entitlement  |
| `EGS20230619` | 2026-02-21 | 1de68133 | Merged revision(s) 12038 from branches/FTG20230906: |
| `FGS20220227` | 2026-02-21 | 2ca5d5af | Merged revision(s) 8932, 8936, 8953 from branches/MOB20210302: |
| `FSC20220227` | 2026-02-21 | c0d56e79 | Merged revision(s) 8910-8911 from branches/MOB20210302 |
| `FTG20230906HF2` | 2026-02-21 | 6b54f6d6 | Merged revision(s) 12996-12997 from branches/GRM20240409: |
| `FTG20230906HF` | 2026-02-21 | 28fa3006 | Merged revision(s) 12676 from branches/GRM20240409: FP-32730: Server Exception - |
| `FTG20230906` | 2026-02-21 | ba6e5360 | FP-35239: Akhtuba Removal - log weight of updated fish (bug: some counters were  |
| `GCR20200421` | 2026-02-21 | e857e64b | FP-17138 - Games.com Release (TEST) |
| `GRM20240409` | 2026-02-21 | 22c13b76 | Merged revision(s) 14382 from branches/IMV20250220: |
| `HFH20241126` | 2026-02-21 | c8270f10 | FP-38520: [Maldives] [Release] - release script to convert UGC and Profiles with |
| `HNX20241105` | 2026-02-21 | ac484811 | Merged revision(s) 13298 from branches/GRM20240409: |
| `Halloween201809` | 2026-02-21 | 8f59b722 | Merged revision(s) 5040 from trunk: |
| `IMV20241106` | 2026-02-21 | c98c98af | Merged revision(s) 13717 from branches/HFH20241126: |
| `IMV20250220` | 2026-02-21 | 10b41d60 | Merged revision(s) 15578 from branches/KNW20250723: |
| `IM_SS_20200217` | 2026-02-21 | 7205c50a | FP-19463 : Make "timed" objects testable without changing dates in DB |
| `IPE20220321` | 2026-02-21 | 88bd2bb7 | Log4net reference fix |
| `JLM20250520` | 2026-02-21 | ef897347 | Merged revision(s) 15072 from branches/IMV20250220: |
| `KNW20250723` | 2026-02-26 | 240234df | Merged revision(s) 14767 from branches/IMV20250220: |
| `LBM20251201` | 2026-04-08 | 50902cbe | FP-43286 Fix DailyMissionTaskAllPonds counter to exclude invisible ponds |
| `LOT20200302` | 2026-02-21 | a5567610 | FP-19198 - fixed giving license without start date |
| `MFT20260209` | 2026-02-21 | 3bd148c6 | [FTUE] Extend bite editor fish list with new fish related to Lesni Vila Rework ( |
| `MI20200128` | 2026-02-21 | 5bcd0823 | IP change from 198 to 192 in RetailSteam |
| `MOB20210302` | 2026-02-21 | 86eb13fb | GC config: remove logging to Console |
| `MergeMultiRods` | 2026-02-21 | fd2d205e | Update from MultiRods20180406 up to revision 5188 |
| `MissionsPerformance20180809` | 2026-02-21 | 47eaf93e | Merge with trunk |
| `MotorBoats20171026` | 2026-02-21 | 6878b413 | Merged revision(s) 3513-3515 from trunk: (the rest of changes) |
| `MotorBoats20190116` | 2026-02-21 | 67babced | Fixed A/B tests for initial money |
| `MultiRods20180406` | 2026-02-21 | fb760e31 | WebAdmin: PSTEST2 added to test profiles |
| `OK_INV_20201215` | 2026-02-21 | 43622424 | updates |
| `P5M20240214` | 2026-02-21 | 954785bc | Merged revision(s) 11850 from branches/FTG20230906: |
| `PFL20191122` | 2026-02-21 | 26cd0122 | Change langversion 7.3 |
| `PMB20210914` | 2026-02-21 | 9678fdaf | FP-21544 : SHOP --> Services |
| `PMR20210914` | 2026-02-21 | 3bf04fd6 | FP-22609 : IsTutorialFinished |
| `PS520201209TMP` | 2026-02-21 | 047d73fe | Single game server PSTEST2 |
| `Photon4Migrate20171208` | 2026-02-21 | fdb6c0e2 | FP-8667 - Photon 4 + WSS - Finished |
| `PhotonV4Migrate20170904` | 2026-02-21 | 2e956e72 | Merged all revision(s) 3166-3310 from trunk |
| `PredatorFish20191030` | 2026-02-21 | ed5b59e2 | Merged revision(s) 7126-7129 from branches/Ugc20190620: |
| `PsMultiRods20190116` | 2026-02-21 | ac68d7fd | FP-15580: XB F2P Release: convert profiles (BottomToCarpRods) |
| `PsRelease20190611` | 2026-02-21 | 5a29c209 | Merged revision(s) 6622-6625 from Retail20190522 |
| `R20180520` | 2026-02-21 | 91634b66 | Fixing Datapamp EnvScripts issue |
| `R20180601` | 2026-02-21 | 18544f97 | Fixing Datapamp EnvScripts issue |
| `Retail20190522` | 2026-02-21 | 676a135a | Deleted old and unused branches |
| `SS202007014` | 2026-02-21 | 1972a2fe | FP-18039 - WebAdmin/Tools: add an option to reset profiles, keeping friends (add |
| `SteamAsyncRealtime20170921` | 2026-02-21 | 7211caeb | Merged revision(s) 3271 from trunk: FP-7455 - Thread deadlock fix |
| `SteamFpaRelease20170727` | 2026-02-21 | de719dba | FP-6047 - Fixed refreshing license after product delivery |
| `SteamFpaRelease20170728` | 2026-02-21 | 8efccbe4 | FP-6776 Cut off new functionality |
| `TMP_` | 2026-02-21 | 5e346d2a | Merged revision(s) 7660 from branches/MI20200128: |
| `TWS20200723` | 2026-02-21 | 96ed9cbd | All players changes |
| `TargetedAds20180306` | 2026-02-21 | ff077ec8 | FP-10041: TA - multiple EventIDs support in events |
| `TempRigs20190604` | 2026-02-21 | 98ef4e9d | FP-14672 - FP-14672 - Double baits attraction (reworked) |
| `TmpFixProductDelivery20191010` | 2026-02-21 | 35f7ad6e | FP-15887 - Fixed hidden transfer of item from Home Storage to Equipment when buy |
| `TmpSonyAsia20190801` | 2026-02-21 | 0ed0ff1b | Changes PS Stats location for master |
| `Ugc20190529` | 2026-02-21 | 24126e82 | FP-12859: UGC: Server |
| `Ugc20190620` | 2026-02-21 | e1f39efd | Merged revision(s) 7478 from branches/PFL20191122: |
| `WebCopy20171026` | 2026-02-21 | bc8a201b | Fixed issue with Boat prices for multiple boats |
| `XBS20210729` | 2026-02-21 | 91ad6eef | Fix build Photon |
| `XMS20201103` | 2026-02-21 | 4404def2 | AsyncProcessor/WebAdmin/TA/TWN Stats: Improve Sales detection and TargetedAdsByC |
| `XboxUwp20181022` | 2026-02-21 | 27f4d162 | Merged revision(s) 5298, 5308-5309, 5319 from branches/MultiRods20180406: 8 room |
| `ZFishing20171109` | 2026-02-21 | 9c5f5838 | Merged revision(s) 3337, 3339, 3341-3342 from trunk: |
| `branch20160415` | 2026-02-21 | 313615f0 | No commit message |
| `master` | 2026-02-21 | 2644af4f | achievmets for translations |
| `remote20180416` | 2026-02-21 | e1c82c7f | HintMessage.OrderIndex added |
