---
name: Technical Debt epic quarterly rotation
description: Recurring quarterly rotation of the rolling "Technical Debt" epic in FP JIRA — naming, fields, Prev/Next comment chain, rotation steps, orphan sweep, and the updated-field staleness gotcha
type: reference
---
A rolling **Technical Debt** epic is rotated once per quarter in the FP JIRA project (reporter/assignee = the tech-debt owner), one epic per quarter, created on the first day of the quarter. The epics form a continuous chain back to Q4 2024; two older thematic "Technical debt" epics (2022-2023) predate the series and are unrelated. Head epic at time of writing: FP-44818 (2026 Q3), predecessor FP-43213 (2026 Q2).

## Epic fields (mirror the predecessor)
- issuetype **Epic**, summary `Technical Debt - YYYY QN`
- priority **Medium**
- Scrum Team (`customfield_11001`) = **Tech Debt** (id `10783`)
- empty description; no components / labels / fixVersions

## Link convention (comments)
Epics form a doubly-linked chain via a single smartlink comment per epic:
```
Next: <browse url of next epic>

Prev: <browse url of prev epic>
```
- The current (head) epic has only `Prev:`.
- A bare browse URL renders as a smartlink.
- On rotation, the old epic's existing comment is **updated in place** (add-comment API with the existing `commentId`) to prepend the `Next:` line, rather than adding a second comment.

## Rotation steps
1. Create the new quarter's epic (fields above).
2. Link: add `Prev: <old>` comment on the new epic; update the old epic's comment to add `Next: <new>`.
3. Move all **non-Closed** children of the old epic into the new one — JQL `parent = <old> AND status != Closed`, then JIRA bulk-edit change-parent (the owner does the bulk-edit).
4. Sweep **orphans**: open issues still parented to already-closed prior epics — `parent in (<all prior epics>) AND status != Closed`. Move genuinely-open ones into the new epic; leave done-but-not-Closed ones (Verified/Resolved) alone.
5. **Close** the old epic with resolution **Done** (transition "Close" -> status Closed). Verify no non-Closed children remain before closing.
6. Set the new epic to **In Progress**.

## Status semantics
Only **Closed** and **Verified** are statusCategory `done`. **Resolved** is `indeterminate` (still open). So "unclosed" = every status except Closed.

## Staleness gotcha (for the planned year-idle auto-close)
Auto-closing tasks idle for a year is planned but not yet done. The `updated` field is **contaminated** by periodic bulk edits (children get `updated` reset en masse; all epics were touched the same day), so it cannot measure inactivity. Use JQL `status NOT CHANGED AFTER -365d` instead — immune to bulk field/parent edits.

## See also
- [JIRA required fields on issue create](jira_required_fields.md) — Scrum Team option ids, epic-link via parent
- [JIRA comment preview](../feedback/jira_comment_preview.md) — preview every JIRA write before posting
