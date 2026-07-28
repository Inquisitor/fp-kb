---
name: Knowledge homes & authoring
description: Where knowledge belongs (the homes + visibility nesting), the cross-audience mirror exception, and how to abstract a memory note when promoting it. Read when authoring KB content or deciding where a rule belongs.
type: reference
---

**Read when authoring KB content, deciding where a rule belongs, or promoting a memory note.**

## Homes — place by audience and visibility, not convenience

Visibility is nested (each inner home is seen by fewer contexts):

    global ~/.claude/CLAUDE.md   ⊃  every project, personal — shareable across YOUR machines via a dotfiles repo; NOT visible to the team
      project CLAUDE.md          ⊃  this project, team-facing — the standard project file: build/run, code navigation, SQL-patch format, where prod configs live
      KB (auto-loaded head)      ⊃  FP work — deep systematized knowledge, task history, rules/techniques/skills; the auto-loaded head (`<kb>/CLAUDE.md`) links out to reference docs for action-time rules
      project memory             —  FP staging — fast un-systematized flow-notes, machine-specific facts (this machine's DB access, which MCP reads what), personal project prefs

## Placement rule (visibility nesting)

Put the text in the **narrowest home whose visibility still covers the rule's scope of application**; a narrower home may reference or annotate it, never copy it. Example: a rule that applies in every project ("no counts in enumerative prose") belongs in **global**, not KB — KB is invisible outside FP.

## Cross-audience exception (the only sanctioned duplicate)

When a rule's scope spans audiences with **no common home** — e.g. a convention the **team** must follow (KB / project CLAUDE.md) AND **you** need in non-FP sessions (global) — a deliberate mirror is unavoidable. (No-dup only ever applied *within* one audience; here neither home sees the other's.) Then:
- Name one copy **canonical** (usually the team one).
- Mark the other a **mirror**: `mirror of <canon> — for non-FP sessions`.
- Keep the mirrored text **minimal** — full rationale lives in the canon only, so the copies do not drift.

This exception is narrow: it does NOT license copying within one audience/visibility (that is the ordinary duplication to remove).

## Memory is an inbox, not storage

Nothing lives in memory long-term except machine-specific / personal-project bits with no other home. Everything else is **transit**: cement it into its home — a skill (for a behavior), a KB reference (for a rule), project CLAUDE.md (for a project fact), global (for a personal pref) — and clear it. The periodic memory sweep IS this cementing.

## Abstracting a memory note on the way into KB

- **Paths**: `<kb>/...` (KB root) and `<project>/...` (working tree root) placeholders, not absolute paths
- **Branches**: by role (`{branch}`, "Code branch"), not current name; role assignments in `_index.md` → Branch Roles
- **Tools / MCPs**: the capability ("DB-access MCP", "JIRA account lookup tool"), not vendor/server name
- **Examples**: concrete data in dedicated Example sections; mark transient state ("X at time of writing")

Drop on migration from memory to KB:
- `originSessionId` and session-bookkeeping
- "Verified on FP-XXXXX (date)" historical citations
- "This rule was violated on FP-YYYYY" narrative — keep the rule, drop the incident
- User-specific framing — generalize to engineering reasons
- Hard machine paths — replace with placeholders

## Promote periodically

When a memory entry stabilizes (no recent edits, applied across sessions, applicability beyond one branch/machine), promote it to its home per the placement rule above.

**On promotion, fix the graph.** After moving a note out of memory: `grep` the memory folder for `[[<note-name>]]` cross-links from other notes and redirect each to the new home's path (a memory note cannot `[[link]]` into KB — a dangling link is what breaks recall). Also remove the note's own index line from `MEMORY.md`.
