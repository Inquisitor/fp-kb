---
name: JIRA Story authoring format
description: How to write an engineering Story - summary tag grammar, the description skeleton and when to use it, the input-vs-research boundary, text rules, typed links and fields
type: reference
---

How to write an engineering Story in the **FP** project.

Bugs have their own standard — [JIRA bug ticket format](jira_bug_ticket_format.md). Other Story
shapes exist in the project (campaign, mission and event tickets written by game design, art,
content and production); **do not infer the format from existing tickets**, they predate this file.
Nothing is retro-fitted to it either.

## Summary

```
[Kind][Subsystem][Subsystem] Sentence
```

Tags are adjacent, no spaces. At least one subsystem tag; a second where the work genuinely sits at
the intersection and neither area alone would find it. 3 tags is the ceiling, and needing a 3rd usually
means the Story is two Stories.

**Subsystem** — the area the work lives in. A game-domain area (`[Leaderboards]`, `[Missions]`,
`[Clubs]`), a deployable or infrastructure component (`[MasterServer]`, `[GameCarrier]`,
`[SoftwareDistributor]`), a tool (`[SqlCheck]`), or a platform where the work is platform-specific
(`[Xbox]`, `[Mobile]`) — a platform tag standing for that platform's integration or infrastructure
subsystem.

Pick the tag from the KB module covering that area, written in tag casing —
`<kb>/fishing-planet/server/modules/anti-cheat` gives `[Anticheat]`, `web-admin` gives
`[WebAdmin]`. Where no module covers it, ask rather than mine existing tickets for a spelling: the
tag vocabulary is not maintained anywhere, and old tickets carry shapes this file does not follow.

`[Server]` and `[GameServer]` are not interchangeable. `[GameServer]` is the Game Application, one
component of the server. `[Server]` means the server side as a whole and is a fallback for work that
genuinely spans it — prefer the narrowest component that is true.

**Kind** — what the work produces rather than where it lands. Optional, at most one, placed first
because it changes how the rest is read. The list is closed: `[Refactoring]` where behavior does not
change, `[RnD]` where no production code changes and any scripts written are throwaway. Extend it
only by an explicit decision.

**A colon or a dash introduces a sub-topic, never a prefix.** The tag names the subsystem, the
separator narrows to the component or aspect inside it:

```
[Missions] WeatherCondition: variant chain stops on a time-window miss
[Stats] PlayerDailyActivity - historical backfill (fix + cross-platform data assembly)
```

Prefer the colon. A trailing parenthetical may carry a scope qualifier. A summary that opens with a
bare topic and a separator — `Server: Codebase Map` — leaves the subsystem outside the brackets;
bracket it instead. The exception is an epic running an established series prefix
(`Save Player State:`), which wins inside that epic.

**Sentence form follows the work.** Verb-first and imperative where the work adds or changes
something; defect-first where the Story reports a latent defect:

```
[GameServer] Remove dead GameClientPeer_MultiRods.cs
[GameServer] Profile event subscriptions are never unsubscribed
```

What is excluded is a summary naming neither the change nor the defect.

English, sentence case, no trailing period. 3-15 words after the tags; longer where a defect needs
its symptom stated.

## Description

**Use the skeleton when the description would fill 3 or more slots, or when it needs
`Acceptance criteria`.** Below that, write a paragraph — headings on a two-sentence ticket are
ceremony.

| Slot                     | Required | When it appears                                                                                                   |
| ------------------------ | -------- | ----------------------------------------------------------------------------------------------------------------- |
| `## Context`             | yes      | Opens the description. What exists, who depends on it, what changed                                                 |
| `## Problem`             | no       | Corrective work — something is broken, missing, or in the way                                                       |
| `## Goal`                | no       | Only when `Scope` lists activities rather than the intended end state                                               |
| `## Scope`               | yes      | The work itself                                                                                                     |
| `## Out of scope`        | no       | When a named adjacent system, follow-up or cleanup could reasonably be assumed included                             |
| `## Acceptance criteria` | usually  | Behavior changes, migrations, operational changes and cross-component work need it; mechanical maintenance does not |

The order is fixed as listed. `Goal` is the intent in a sentence and need not be checkable;
`Acceptance criteria` are the checkable outcomes — if the Goal is checkable, it is an acceptance
criterion.

Slot names are written exactly as above, in sentence case: `Acceptance criteria`, not
`Acceptance Criteria`. Older tickets use `Background` for `Context`, and `Acceptance` or
`Expected result` for `Acceptance criteria`; those names are not used any more. `Related` and
`Cross-references` are not slots at all — see Links.

`##` for slots, `###` for sub-sections inside one. Bold is not a section heading here — it is
reserved for inline labels, and bold headings are the bug format's dialect.

Custom `##` sections are allowed where the content genuinely does not fit a slot — a decision that
needs recording, a constraint list, an inventory of affected call sites. The canonical slots keep
their order relative to each other; a custom section goes where it reads best. Readability wins
where it conflicts with the skeleton.

## What the description does not carry

**The description states the task, not the answer.** The symptom or the finding, the landscape, and
what must be true when it is done — not the chosen mechanism and not a step-by-step remediation.

A Story has **no `Research` slot**, unlike a bug. Investigation findings are provisional:
incomplete, or accurate only as of the day they were gathered. Keeping them out of the description
keeps the input separate from the research — the description holds the task as it reached us, and
everything learned **after filing** goes in comments, where it is dated and can be superseded
without rewriting the brief. A finding promoted into the description silently becomes a premise, and
the next reader treats it as given.

Where the Story exists *because of* a finding — a latent defect found by reading code, with no
external reporter — that finding is the task and belongs in `Context` or `Problem`, stated as of the
date it was gathered. What still stays out is the answer.

A brief that already contains a worked-out fix is a defect even when the analysis is correct and the
assignee is its author: it freezes one hypothesis before pickup and invites skipping verification
against state that has since drifted.

## Text

- **English**, summary and body alike. No exceptions.
- **Impersonal register** — no `we`/`our`/`us`, no `you`/`your`. Neutral subjects or passives. Where
  avoiding a pronoun produces a contortion, name the actor — a team, a service, a role. Verbatim
  quotes keep their original voice.
- **Inline code for anything meant to be reproduced exactly that is not a link** — identifiers,
  symbols, literal values, domains, record and header names, configuration keys. Product and service
  names stay plain: Zendesk, SendGrid, Photon.
- **Point at symbols, not coordinates** — file, class, method, enum; never line numbers, and no
  counts unless the count is itself the claim.
- **Do not pre-allocate mutable values.** The next free enum number, category id, port or token is
  chosen against live state when the work starts; a draft may sit for weeks and the value it
  reserved can be taken by then. Stable identifiers — symbol, table and column names, existing ids
  relevant to the problem — belong in the text, formatted as code. Secrets never appear.
- **No hard line wrapping.** A paragraph is one line; a fixed-column wrap reads well in a file and
  badly in JIRA, where the breaks survive into the rendered description.
- **Bullets or prose inside a slot as the content dictates** — bullets for a set of independent
  items, prose for one continuous change.

## Links

Relationships are typed issue links: `Relates` for related or follow-up work, `Blocks` for ordering
— direction rules in [JIRA required fields](jira_required_fields.md). A `## Cross-references` list
in the description is not a substitute: it does not appear in the Links panel, is not reachable
through `linkedIssues()` in JQL, and has to be kept current by hand.

Where a relationship carries a warning rather than a fact — planned work elsewhere that would break
this — put it as a comment on the *other* issue, where it is read at the moment it matters.

**Every reference in the body is a live link.** An issue key is posted as an ADF `inlineCard` node,
which renders as a card carrying the issue's summary and status; written as plain markdown it stays
dead text. Any other resource is either a hyperlink with meaningful anchor text where the surrounding
sentence supplies the context, or the URL itself rendered as a link where it does not. Dead text
pointing at something the reader then has to go and find by hand does not belong in a description.

## Fields

Mechanics, option ids and create-time requirements are in
[JIRA required fields](jira_required_fields.md).

| Field           | Convention                                                                                                                                |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Epic (`parent`) | Always. With no better home, the current Technical Debt epic — [which one that is](technical_debt_epic_rotation.md) rotates quarterly         |
| Scrum Team      | Always; enforced at create time. Ask which value applies rather than defaulting silently                                                     |
| Assignee        | The user filing it, unless someone else is named                                                                                             |
| Fix versions    | Always. See [release versions and process](release_versions_and_process.md) for which one, including the hotfix incubator                     |
| Components      | Always, wherever the component is identifiable. The tag reads a backlog, the field queries one — a bracket in a summary is only reachable by text match. Coarser axis than the tag: layer and discipline rather than subsystem. Same on a bug |
| Platform        | If the summary carries a platform tag, set Platform to that platform; otherwise leave it unset                                                |
| Priority        | `Medium` unless there is a reason; `Low` for cosmetic or deferred cleanup, `High` where the work unblocks other work or stops ongoing harm    |
| Severity        | Leave unset — a bug field                                                                                                                    |
| Labels          | Leave unset — effectively unused across the project, so nothing queries them                                                                 |
