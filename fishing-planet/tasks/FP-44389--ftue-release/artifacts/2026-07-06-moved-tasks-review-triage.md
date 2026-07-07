# Tasks moved 2026-07-06 (release cleanup) — review triage

On 2026-07-06, during FTUE release cleanup, Anna Vorona swept a batch of tasks that were sitting
**Resolved / In Review on Stanislav**. This tracks the ones that must not be lost. Priority (per owner):
a fixVersion move is fine — the task still hangs on Stanislav and is visible in his own filters.
**Critical** = tasks that **closed** or **moved off Stanislav to someone else** — they may have shipped
without his review. Goal: track them all and review any not yet reviewed.

**Key finding:** every close below was done by **Anna Vorona** (In Review/Resolved -> Closed); Stanislav
did not perform any of the closing transitions. So each closed task needs a check: was it actually
reviewed (by Stanislav or a valid reviewer) before Anna administratively closed it?

Source: JIRA changelog — status/assignee changed 2026-07-06 by Anna Vorona or Stanislav Samoilov, on
issues that were In Review/Resolved with Stanislav as assignee. Enriched from a full changelog pass of
all 97 same-day-touched candidates + spot checks.

Review mark: `[ ]` not reviewed · `[x]` reviewed · `[-]` N/A (not mine / already reviewed).

## CRITICAL — Closed on 2026-07-06 by Anna Vorona (verify review happened)
All `In Review -> Closed` unless noted. Time = close time.
- [ ] 14:47 FP-42786 — Lone Star Kayak: Server - TDD + dev tasks + estimates
- [ ] 14:49 FP-42890 — FTUE New Tutorial: Server - new default profile
- [ ] 14:50 FP-42891 — FTUE New Tutorial: Server - new parameters to MissionFishBox
- [ ] 14:50 FP-42894 — FTUE New Tutorial: Server - mission condition `it.IsZoom`
- [ ] 14:50 FP-42914 — FTUE New Tutorial: Server - fix `{ @MissionWeather: 'Sunny' }`
- [ ] 14:53 FP-43171 — Lone Star Kayak: Server - Object Model for TrollingKayak
- [ ] 14:53 FP-43172 — Lone Star Kayak: Server - new mechanics for TrollingKayak
- [ ] 14:54 FP-43176 — FTUE New Missions: Server.Hints - show hints when mission not active
- [ ] 14:56 FP-43271 — FTUE Server - profile conversion, marker buoys for reworked locations
- [ ] 15:05 FP-43435 — FTUE New Tutorial: Server - delay parameter for missionfishbox
- [ ] 15:05 FP-43562 — FTUE/Tutor: Server - add MissionGroupId to HintMessage
- [ ] 15:06 FP-43421 — FTUE New Tutorial: GD - default profile leader height
- [ ] 15:07 FP-43415 — FTUE New Tutorial: Server - first Reel of Fortune logic for new players
- [ ] 15:37 FP-35972 — WebAdmin - Translate system Design  (`Resolved -> Closed`)

## CRITICAL — Reassigned off Stanislav on 2026-07-06 (all via Anna Vorona)
- [ ] FP-43180 — compass hint on distance — Stanislav ->(14:55) Anna ->(15:30) Andrii Smilianets; now **Closed**
- [ ] FP-43422 — increase Strike period for new players — Stanislav ->(15:06) Anna ->(15:31) Kyrylo Rovnyi; In Review
- [ ] FP-43011 — PremPromo: Client - Today&Trip result window — Stanislav ->(14:52) Anna ->(15:32) Kyrylo Rovnyi; In Review (client task)

## Non-critical — status/assignee changed but still on Stanislav
- FP-43181 (On Hold) — Hints: parameter to hide tasks in menu. Taken from Yuriy Burda by Stanislav 14:15;
  then Anna churned status (In Review -> Reopened -> In Progress -> On Hold) and resolution (Done -> Not Done). On you.
- FP-33074 (In Progress) — [Chat] messages disappear. **You** moved it Reopened -> In Progress at 13:36. On you.

## fixVersion moves (not critical — still on Stanislav, visible in his filters)
By Anna Vorona today; recorded for completeness, not review-blocking:
- FP-40968 -> 2026.5 Anniversary
- FP-39673 -> 2026.5 Anniversary
- FP-41256 -> 2026.5 Anniversary
- FP-41593 -> 2026.5 Anniversary
- FP-42124 -> 2026.5 Anniversary
- FP-44537 -> 2026.5 Anniversary (removed 2026.6 Australia)
- FP-44282 -> 2026 Releases (removed 2026.5 Anniversary)
- FP-43181 -> 2026.5 Anniversary (also above)
- FP-35682 -> 2026.4.2.1 FTUE Server Hotfix (also churned Next Server Hotfix / 2026 Releases)
