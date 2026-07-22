# FPA (2026.5 Anniversary) — readiness of server tasks on Stanislav

Snapshot: 2026-07-22. Source: JIRA fixVersion **16274** (FPA) ∩ current assignee = Stanislav.
Commit presence verified by `svn log --search` on MFT/NPN. FPA ships from **MFT**, so an
NPN-only commit must be merged down before it can ship.

Priority inputs folded in:

- **QA reporters** = Churylova, Horishnyi ("Misha"), Sova, Liliia Finenkova — their bugs rank first.
- **PM (Anna Vorona) priority list** (⭐): FP-45032, FP-44994, FP-44985.
- **Andrii Smilianets input (Slack 2026-07-22 13:28):** personally tested only FP-43181 / FP-44668 /
  FP-41501; FP-44667 = feature was missed/not configured, he's on it now; FP-44985 = Misha (QA) retesting;
  everything else he did NOT personally verify ("fixed? good, QA/ZBT will check" — mostly OK per ZBT, not vouched).
- Yuriy Burda's weather cluster = internal, lead self-handles; Vika Shulyak (CS lead) task = not urgent.

## Order (highest first)

- 🔴 **P1** — QA bugs + PM request
- 🟢 In QA (Misha)
- 🟠 Andrii actively fixing (missed config)
- 🟠 **P2** — Top-QA, blocked on merge NPN->MFT
- 🟡 **P3** — Needs QA verification (mission tasks Andrii did not vouch)
- 🟡 **P4** — Medium, GD-reported
- ⚪ Done — Andrii-confirmed / QA-waived -> close
- ⚪ Self / not urgent

---

## 🔴 P1 — QA bugs + PM request

| Key        | Title                                               | MFT    | Why P1                                                     |
|------------|-----------------------------------------------------|--------|------------------------------------------------------------|
| FP-45032 ⭐ | Kayak task completes when boarding a boat           | r16333 | QA (Liliia) + PM                                           |
| FP-44994 ⭐ | Pond Event Icon (Server.UI)                         | r16315 | PM; client dep resolved (r56400/56414)                     |
| FP-44757   | Same fish counted multiple times (Worm Wisdom)      | r16254 | QA (Horishnyi/Misha)                                       |
| FP-41593   | Steam global chat — restricted-country send/display | r16158 | QA (Sova); temp workaround, client = FP-41809              |
| FP-44536   | Daily retrieve-mission completable by bottom rod    | r16289 | QA (Liliia); Andrii left only a bonus note, did not verify |

## 🟢 In QA (Misha)

| Key        | Title                                     | MFT    | State                                                                                                                     |
|------------|-------------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------|
| FP-44985 ⭐ | Add "Distance" to Hook/CatchFishCondition | r16310 | Misha (QA) retesting. Open action: remove dev tasks 15741-15744; check if new serialized fields need a protocol increment |

## 🟠 Andrii actively fixing

| Key      | Title                               | MFT    | State                                                                         |
|----------|-------------------------------------|--------|-------------------------------------------------------------------------------|
| FP-44667 | Mission auto-tracking after failure | r16271 | Andrii: feature was missed / not configured — he's checking + configuring now |

## 🟠 P2 — Top-QA, blocked on merge NPN->MFT

| Key      | Title                                                         | NPN (not in MFT) | Gates                                                                                                                                              |
|----------|---------------------------------------------------------------|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|
| FP-44730 | Cannot donate Dragonfly Nymphs 32706/32707 vs 32708           | r16282-16298     | QA (Churylova). Client r56237/r56271, SQL 020-023, profile conversion (RemapInventoryItems)                                                        |
| FP-44680 | No tablet icon — Historic Chain Pickerel (broken FishId 3038) | r16251-16335     | QA (Liliia). Prod data-fix rollout: `--scan-broken-fish` -> GD mapping -> SQL -> `--finalize-conversion`. Executor Yevhenii Shust; has review card |

## 🟡 P3 — Needs QA verification (mission tasks Andrii did not vouch; ZBT "mostly OK")

| Key      | Title                                                  | MFT           | Note                                                                                                       |
|----------|--------------------------------------------------------|---------------|------------------------------------------------------------------------------------------------------------|
| FP-44413 | Fail + re-receive mission: inconsistent task behaviour | r16263        | Andrii is reporter; QA must confirm his 2nd symptom (mission 3957 `_FailCondition` never fires) is covered |
| FP-44501 | Kayak fish-drag tracking                               | r16256        | Andrii filed a bug (mission 3983) BEFORE the merge — QA must re-verify vs r16256                           |
| FP-44392 | UniqueBy doesn't work as intended                      | r16257+r16259 | Only dev merge notes                                                                                       |
| FP-44716 | Dynamic task completion doesn't update queued HUD      | r16283        | QA repro was pre-fix; fix itself not verified                                                              |
| FP-44758 | Mission variables assigned random values               | r16252        | Silent on QA                                                                                               |
| FP-42531 | Mission Variable Functionality                         | r15972-15994  | Oldest (April); docs done, never QA'd                                                                      |

## 🟡 P4 — Medium, GD-reported

| Key      | Title                                  | MFT    | Note                                                                                              |
|----------|----------------------------------------|--------|---------------------------------------------------------------------------------------------------|
| FP-42557 | Air Temperature Checking Functionality | r16073 | Reporter Davydiuk (GD); client dep done (r53902); client-visible contract rename -> end-to-end QA |

## ⚪ Done — Andrii-confirmed / QA-waived -> close

| Key      | Title                                            | MFT    | Why                                                                     |
|----------|--------------------------------------------------|--------|-------------------------------------------------------------------------|
| FP-44668 | HUD mission/task-name variables not shown        | r16273 | Andrii personally tested + QA waived                                    |
| FP-41501 | Add RodCategoryId into CatchFishCondition        | r16285 | Andrii personally tested                                                |
| FP-44759 | "Is Hidden When Completed" inconsistent Menu/HUD | r16279 | QA waived; tests-only change                                            |
| FP-44859 | Some conditions don't refresh properly           | r16291 | QA waived (Anna Vorona)                                                 |
| FP-44761 | Wrong mission restart after fail via fail task   | r16287 | QA waived; fixed via linked task + regression test                      |
| FP-43181 | Hints — hide tasks even in menu                  | r16049 | Andrii personally tested; still On Hold pending client support FP-42951 |

## ⚪ Self / not urgent

| Key      | Title                                                   | NPN (not in MFT) | Why                                                                              |
|----------|---------------------------------------------------------|------------------|----------------------------------------------------------------------------------|
| FP-41627 | Weather — new lookup tables                             | r16221-16245     | Yuriy/weather cluster; lead self-handles (internal). Merge to MFT still required |
| FP-41625 | Weather — save per-pond randomization params            | r16230-16231     | Yuriy/weather; self. Merge still required                                        |
| FP-41616 | Weather — cleanup regen UI                              | r16220-16225     | Yuriy/weather; self. Merge still required                                        |
| FP-42124 | RU players not banned in clubs/social while chat-banned | r16191-16303     | Vika Shulyak (CS lead); not urgent. Resolved but merge to MFT still required     |

---

## Off this list (context)

- **Drifted off** (were mine at the 07-20 snapshot, no longer mine at 07-22): FP-41256 (Norway weather), FP-40968 (
  WebAdmin ban by Mac/IP), FP-44846 (ProfileSerializationHelper prod bug).
- **FP-44794** (was on the PM priority list): moved to **2026.6 Australia** release (not FPA); server on NPN
  r16339-16342, In Review, still on Stanislav. Review under Australia, not FPA.

## Handoff filter given to Andrii (mission-team actualization)

`key in (FP-41501, FP-44392, FP-44413, FP-44668, FP-44716, FP-44758, FP-44759, FP-44859, FP-44985, FP-44667, FP-44536, FP-44501, FP-43181, FP-42531, FP-44761)` —
Andrii's reply folded into the buckets above.

## Progress tracking

Update buckets/notes as tasks move. Review happens in parallel sessions; this file is the shared readiness view.
