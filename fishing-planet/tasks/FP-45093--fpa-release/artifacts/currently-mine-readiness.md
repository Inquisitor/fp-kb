# FPA (2026.5 Anniversary) — readiness of server tasks on Stanislav

Snapshot refreshed: 2026-07-22 evening. Source: JIRA fixVersion **16274** (FPA) ∩ current assignee = Stanislav.
Commit presence verified by `svn log --search` on MFT/NPN. FPA ships from **MFT**, so an
NPN-only commit must be merged down before it can ship.

> **Membership drifts hourly** — as tasks are reviewed and handed to QA they leave `assignee = me`,
> and new ones arrive. This file is a periodic enrichment snapshot (priority + commit/review/QA state),
> **not** the live membership. Live membership = the JQL:
> `project = FP AND assignee = currentUser() AND fixVersion = 16274`.

Priority inputs folded in:

- **QA reporters** = Churylova, Horishnyi ("Misha"), Sova, Liliia Finenkova — their bugs rank first.
- **Andrii Smilianets (Slack 2026-07-22 13:28):** personally tested only FP-43181 / FP-44668 / FP-41501;
  FP-44667 = feature missed/not configured, he's on it; FP-44985 = Misha (QA) retesting; the rest he did NOT vouch.
- Yuriy Burda's weather cluster = internal, lead self-handles; Vika Shulyak (CS lead) task = not urgent.

## Order (highest first)

- 🔴 **P1** — QA bugs + PM request
- 🟢 In QA (Misha)
- 🟠 Andrii actively fixing (missed config)
- 🟠 **P2** — Top-QA, blocked on merge NPN->MFT
- 🟡 **P3** — Needs QA verification (mission tasks Andrii did not vouch)
- 🟡 **P4** — Medium (GD-reported / reviewed prod hotfix)
- 🔧 Release gate (client / mechanics)
- ⚪ Done — Andrii-confirmed / QA-waived -> close
- ⚪ Self / not urgent

---

## 🔴 P1 — QA bugs + PM request

_Cleared 2026-07-23 — the last P1 item (FP-44536) reviewed (LGTM) and handed to the reporter for verification._

## 🟢 In QA (Misha)

| Key        | Title                                     | MFT    | State                                                                                                                     |
|------------|-------------------------------------------|--------|---------------------------------------------------------------------------------------------------------------------------|
| FP-44985   | Add "Distance" to Hook/CatchFishCondition | r16310 | Misha (QA) retesting. Open action: remove dev tasks 15741-15744; check if new serialized fields need a protocol increment |

## 🟠 Andrii actively fixing

| Key      | Title                               | MFT    | State                                                                         |
|----------|-------------------------------------|--------|-------------------------------------------------------------------------------|
| FP-44667 | Mission auto-tracking after failure | r16271 | Andrii: feature missed / not configured — he's checking + configuring         |

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
| FP-42531 | Mission Variable Functionality                         | r15972-15994  | Oldest (April); docs done, never QA'd                                                                      |

## 🟡 P4 — Medium (GD-reported / reviewed prod hotfix)

| Key      | Title                                   | MFT                        | Note                                                                                                                                                               |
|----------|-----------------------------------------|----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| FP-44943 | [Xbox][DLC] Duplicate DLC-pack delivery | r16343-16348 (+NPN r16355) | Prod hotfix; code-reviewed; ReleaseTool revert already run on Xbox prod 07-20. Reporter sergii.chop. Your verify/close; over-report cleanup deferred (no criteria) |
| FP-42557 | Air Temperature Checking Functionality  | r16073                     | Reporter Davydiuk (GD); client dep done (r53902); client-visible contract rename -> end-to-end QA                                                                  |

## 🔧 Release gate (client / mechanics)

| Key      | Title                              | Where                    | Note                                                                                                                               |
|----------|------------------------------------|--------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| FP-45149 | Protocol version check is disabled | Client CodeBranch r56601 | Reporter = lead. Re-enable client protocol version check before FPA ships. No server commit — release gate, not server-code review |

## ⚪ Done — Andrii-confirmed / QA-waived -> close

| Key      | Title                                            | MFT    | Why                                                                                                            |
|----------|--------------------------------------------------|--------|----------------------------------------------------------------------------------------------------------------|
| FP-44668 | HUD mission/task-name variables not shown        | r16273 | Andrii personally tested + QA waived                                                                           |
| FP-41501 | Add RodCategoryId into CatchFishCondition        | r16285 | Andrii personally tested                                                                                       |
| FP-44759 | "Is Hidden When Completed" inconsistent Menu/HUD | r16279 | QA waived; tests-only change                                                                                   |
| FP-44859 | Some conditions don't refresh properly           | r16291 | QA waived (Anna Vorona)                                                                                        |
| FP-44761 | Wrong mission restart after fail via fail task   | r16287 | QA waived; fixed via linked task + regression test                                                             |
| FP-43181 | Hints — hide tasks even in menu                  | r16049 | On Hold, resolution **Not Done** (reopened); blocked on client support FP-42951. Andrii tested the server part |

## ⚪ Self / not urgent

| Key      | Title                                                   | NPN (not in MFT) | Why                                                                              |
|----------|---------------------------------------------------------|------------------|----------------------------------------------------------------------------------|
| FP-41627 | Weather — new lookup tables                             | r16221-16245     | Yuriy/weather cluster; lead self-handles. Merge to MFT still required            |
| FP-41625 | Weather — save per-pond randomization params            | r16230-16231     | Yuriy/weather; self. Merge still required                                        |
| FP-41616 | Weather — cleanup regen UI                              | r16220-16225     | Yuriy/weather; self. Merge still required                                        |
| FP-42124 | RU players not banned in clubs/social while chat-banned | r16191-16303     | Vika Shulyak (CS lead); not urgent. Merge to MFT still required                  |

---

## 🔵 On devs (Burda / Shust) — server tasks not yet in the review queue

FPA server tasks currently held by the developers; they reach the lead's review after the dev finishes.

| Key      | Title                                                 | Assignee       | Status                  | Server code                                                   |
|----------|-------------------------------------------------------|----------------|-------------------------|---------------------------------------------------------------|
| FP-41593 | [Steam] Global chat — restricted-country send/display | Yevhenii Shust | **Reopened** (Not Done) | MFT r16158, but reopened — fix deemed incorrect, being redone |
| FP-44701 | [Steam] Mission ID 435 completed twice                | Yuriy Burda    | In Progress             | not committed yet                                             |

## Recently left the queue (verified 2026-07-22/23 — all Resolved, awaiting reporter verification; none lost)

- FP-44536 -> **Liliia Finenkova** (QA, reporter), Resolved — LGTM posted 2026-07-23; drag-style binding closes the rod-stand loophole
- FP-44757 -> **Anna Sydorchuk** (QA lead), Resolved — in QA
- FP-44758 -> **Anna Sydorchuk** (QA lead), Resolved — in QA
- FP-45032 -> **Liliia Finenkova** (QA, reporter), Resolved — reporter/QA verification
- FP-44994 -> **Oleksandr Davydiuk** (GD, reporter), Resolved — GD verification (not QA lead)
- FP-41593 -> **reopened, back to dev (Shust)** — see "On devs" above

## Off this list (context)

- **Drifted off earlier** (were mine at the 07-20 snapshot): FP-41256 (Norway weather), FP-40968 (WebAdmin ban by
  Mac/IP), FP-44846 (ProfileSerializationHelper prod bug).
- **FP-44794**: moved to **2026.6 Australia** release (not FPA); server on NPN r16339-16342, In Review, still on lead.
  Review under Australia.

## Progress tracking

Re-run the live JQL before trusting membership; refresh this snapshot's buckets/notes when the set moves. Review happens
in parallel sessions; this file is the shared readiness view.
