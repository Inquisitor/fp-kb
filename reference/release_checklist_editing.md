---
name: Server release checklist - editing procedure
description: How to fill a cloned Server Release checklist page - confirmation gate, what may and may not be touched, the 🚧 marker, when a panel is warranted, batching edits, and the HTML round-trip mechanics
type: reference
---

Companion to [Server Release Checklist Steps field](release_checklist_field.md): that one says **what
content** belongs in a release checklist (the field vocabulary, the SVN blind-zone sweep, release
mechanics). This one says **how to edit the page** without damaging it.

Applies to the per-release pages under SERVER RELEASE CHECKLISTS (page `60097315`) and to the template
(`4395597825`).

## Confirmation gate

- **Every edit needs the user's explicit confirmation before it is written** - including corrective edits
  and reverts. Show the change list per step, wait, then write.
- Approval of the *substance* is not approval of the *wording*: show new sentences verbatim before they
  go in.
- The checklist is an operator runbook executed under downtime pressure. Page history makes damage
  recoverable, but reviewing a bloated diff on release day costs the operator time they do not have.

## What may be touched

- **Fill only what was asked.** Do not add explanatory notes, context or "helpful" remarks to steps that
  were not part of the request. A "fill the checklist" request is not a licence to touch every row.
- **Never delete or rewrite template instructions.** A step that does not apply this release gets a note
  saying so; the instructions themselves stay for the operator. (Deleting the NoSQL instructions while
  writing "the routine `indexes.js` run still applies" is the shape of the mistake.)
- **Deleting whole steps is a scope decision** - e.g. dropping the offline-converter steps when no offline
  conversion ships. Confirm it explicitly; do not fold it into a fill.
- **Prefer the smallest possible diff.**

## The 🚧 marker

- 🚧 marks template-provided text that has not been validated for this release. It is the **operator's
  sign-off**, not the agent's.
- **Only the user removes it**, and each item is approved individually before its marker goes.
- Filling a step's content and clearing its 🚧 are two separate acts.

## Per-release notes vs standing text

- **Do not write "no changes this release" notes on steps that carry standing instructions.** They go
  stale the moment a later patch touches that area, and a checklist reused for a small release then
  carries a statement that is quietly false.
- **Placeholders the template provides are meant to be filled** - e.g. the env-vars / A-B block, or
  "[Should be listed if any]" under Stats Synchronization. Filling one with "None this release." is the
  answer to that step, not a stale annotation. Keep the fill short; no rationale paragraph.
- **A reminder that applies to every release belongs in the template, once** - not copied into each
  release page.

## Panels

Info/warning panels are a visual "do not miss this". Reserve them for **exceptions**, where the plain
reading of the step would lead the operator to do the wrong thing - e.g. a script that is listed but must
**not** be run, because it has already been executed on one platform.

Do **not** panel a "nothing to do here" step: it draws the eye to the one step that needs none, and it
dilutes panels where they matter.

## Batching

Each save rewrites the **whole page**. Agree the complete set of changes first, then perform **one**
write. Applying items one at a time inflates the version history and multiplies the risk of an
unintended diff.

## Mechanics

- Edit with `contentFormat: "html"` - it is round-trip safe and preserves macros, inline-card links and
  existing `data-local-id` anchors. Markdown round-trips lose them.
- **Re-fetch the page immediately before writing.** The user may be editing it in parallel; a write built
  on a stale snapshot silently reverts their work.
- Preserve what the operator has already done - notably **checked checkboxes** (`<input type="checkbox"
  checked>`) and any 🚧 they cleared.
- Keep `data-local-id` on untouched nodes; omit it on nodes you add.
- Set a `versionMessage` that names the change - the page history is the audit trail.

## Related

- [Server Release Checklist Steps field](release_checklist_field.md) - what content belongs in the checklist
- Worked example: `tasks/FP-45093--fpa-release/artifacts/release-steps-mapping.md` (2026.5 Anniversary),
  `tasks/FP-44389--ftue-release/artifacts/release-steps-mapping.md` (2026.4 FTUE)
