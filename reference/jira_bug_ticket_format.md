---
name: JIRA bug ticket format
description: The company standard for FP bugs whoever files them - summary tag formula, ENV/PRE-STR/STR/ACT/EXP description skeleton, evidence placement and the field set every bug carries
type: reference
---

How bugs are filed in the **FP** project. Derived from a survey of bug tickets across the regular QA reporters (Oleksandra Churylova, Yevheniia Nikiforova, Dmytro Sova, Liliia Finenkova, Mykhailo Horishnyi, sergii.chop, Anna Sydorchuk), and confirmed as the project-wide shape: in a sample across the past year the bracket-prefixed form accounts for the overwhelming majority of Bug summaries, against a clear minority of Story ones.

**This is the standard for every bug, not only for filing on QA's behalf.** A bug we raise ourselves follows it too — a ticket that deviates reads as developer-authored and gets groomed differently. Stories are a different format and are not covered here: see [JIRA Story authoring format](jira_story_authoring_format.md).

Live example built from this reference: [FP-45969](https://fishingplanet.atlassian.net/browse/FP-45969).

## Summary line

```
[Platform][Environment][Feature area] Declarative sentence describing the broken behavior
```

- **Always English**, even when the description body is Ukrainian. This is the one hard rule — mixed-language bodies are normal, a non-English summary is not.
- Tags open the line, no space between them, one space before the prose. Order: platform -> environment -> feature area.
- Platform: `[Steam]` `[Steam/EGS]` `[PS]` `[PS4]` `[PS5]` `[Xbox]` `[UWP]` `[All Platforms]`. Omit entirely when the bug is platform-agnostic — it is not mandatory.
- Environment: `[Prod]` `[Code Branch]`. Feature area: `[Shop]` `[Club]` `[Tournament]` `[FTUE]` `[Missions]` `[Inventory]` `[Licenses]` `[UI/UX]` `[Gamepad]` `[LiveOps]` `[Exploit]` and similar.
- Present tense, states the symptom. Never a fix, never a question. Roughly 8-18 words.
- A trailing period is a personal habit, not a convention — either way is fine.

Mission/event tickets use a separate dialect owned by that team — `EVENT NAME: Layer - description`, where layer is `Server` / `Client` / `GD`. Do not use it outside a mission/event epic. It is the same shape as the campaign/production Story form; both are conventions of the teams that own that work, and neither is set here. Both are also described from the Story side in [JIRA Story authoring format](jira_story_authoring_format.md), which is where a Story author should look.

## Description skeleton

The dominant dialect uses abbreviated headings, bolded:

```
**ENV:**

<PLATFORM> / <branch> / rev. <n> / <server>
Prod report - <Slack permalink>          <- prod reports only

**PRE-STR:**

* bulleted precondition
* player card URL

**STR:**

1. numbered step, imperative
2. ...

**ACT:**

<what happens>
<screenshot embedded here>
**Logs:** <MergedLog URL>

**EXP:**

<what should happen>
```

For a server-side bug the ENV line names the server build as well: platform / environment / server branch tag with protocol version and server revision, then the client version on the next line, e.g. `STEAM / PROD / [MFT] | Protocol: 1126.0 | Revision: 16375` followed by `Client version: 6.0.13 (revision 56736)` (FP-46092).

A full-word variant is equally legitimate: `**Precondition:**` / `**Steps:**` / `**Actual:**` / `**Expected:**`, optionally closing Actual with `:x:` and Expected with `:white_check_mark:`. `**AR:**` / `**ER:**` also appear. Pick one dialect and stay internally consistent; do not mix abbreviations with full words in the same ticket. Optional trailing `**NOTE:**` or `**Comments:**` carries caveats such as "cannot reproduce on STEAM" or a proposed fix.

When there are no reproduction steps (an unreproducible prod report), `**ENV:**` / `**Problem description**` / `**Research**` / `**Desired outcome**` is the accepted free-form fallback.

Steps are numbered, imperative, one UI action each, and the last one is habitually an observation instruction ("Pay attention to the timer"). Multi-player bugs prefix each step with the actor. `->` is the navigation arrow; `>` appears for menu paths (`SHOP > LICENSES`). Typical body runs 120-250 words.

## Content rules

- **Observed facts only.** The Research block holds log lines, DB state before and after the event, and links, all for THIS case. Inferences from indirect data (profile counts, leaderboard outliers, "probably not the first occurrence") do not belong in the ticket; bring them to the reporter in chat.
- **No root-cause narrative, no code references.** The ticket states the symptom and the desired outcome; the analysis lives in the KB card. A ticket that explains the cause reads as developer-authored and invites skipping verification.
- **One ticket per side.** When a symptom spans server and client (bad data sent by the client, mishandled by the server), file a server bug and a client bug separately; do not fold "investigate the other side" into one ticket. A research or census task is a third ticket, and only when asked for.

## Evidence placement

- **Slack permalink first**, inside or directly under ENV. That provenance line is what marks a ticket as a player report rather than a QA find; omitting it loses the trail.
- **Screenshots embedded inline directly under the ACT text**, not left in the attachment strip. A second one may follow EXP to show correct behavior.
- **WebAdmin links inline and complete**: player card in preconditions, `MergedLog` under a bold `**Logs:**` label right after Actual. Host varies per platform (`steam-webadmin`, `ps-webadmin`, `xb-webadmin`, `psqa`, `xbqa`, `nxtest.fishingplanet.org`).
- Raw log excerpts are pasted inline; DB references are literal (`Table: AdDesigns`, `id = 259`); Figma/Confluence design links sit at the bottom of EXP.

## Fields

| Field             | Convention                                                                                                |
| ----------------- | --------------------------------------------------------------------------------------------------------- |
| Epic (`parent`)   | Always. Prod reports -> `FP-41583` Prod Bugs_2026 (All Platforms); BVT finds -> the per-platform BVT epic    |
| Fix versions      | Always. Either a named release (`2026.6 Australia`) or the rolling `Bugs Sprint <dates>` version             |
| Severity          | Always. `customfield_10030`, options `trivial` `minor` `major` `crash` `block`, default `minor`              |
| Priority          | Always. `Medium` default; `Low` cosmetic; `High`/`Highest` blockers, disconnects, crashes                    |
| Scrum Team        | **Always** - `customfield_11001` is enforced at create time                                                  |
| Platform          | Often. `customfield_11143`, multi-select - array even for one value. PS5 bugs use the `PS4` option           |
| QA assignee       | Often. `customfield_11155`, usually the QA lead                                                              |
| Components        | Set it wherever the component is identifiable - it is the axis JQL can query, and a summary tag is only reachable by text match. Almost no ticket carries it today; that is a discipline gap, not a licence |
| Labels            | **Never.** Effectively unused across the project, on bugs and stories alike                                  |
| Environment field | **Never.** Build and branch info goes in the `ENV:` block of the description                                 |
| Affects versions  | Never                                                                                                        |

Field ids and option values for create: [jira_required_fields.md](jira_required_fields.md).

## What an outsider gets wrong

- Writing the summary in the body's language — the summary must be English regardless.
- Filling Labels because the form offers them; nothing queries them.
- Using the native Environment field instead of the `ENV:` block.
- Forgetting the epic link, leaving the bug orphaned.
- Forgetting Severity, which is a separate field from Priority.
- Attaching screenshots instead of embedding them under ACT.
- Omitting the Slack permalink on a player-reported bug.
- Padding Research with population statistics that were never verified to be caused by the bug.
