---
name: Confluence edits preserve manual layout
description: Before changing a published page, check whether its nodes carry data-local-id and edit those nodes in place; a full body rewrite silently discards table widths, layout and anything else set by hand in the editor
type: feedback
---
A page someone has adjusted in the Confluence editor — table width, content width, column sizes, date
macros — carries that state in its body. Replacing the body wholesale re-creates every node from your
markup, so all of it disappears, and the author finds their page reset without being told.

**Check first.** Read the page as HTML and look for `data-local-id` on the nodes you intend to change. When
they are present, edit in place with granular operations (`replaceNode`, `insertNodeAfter`), naming the node
by its id. Everything you do not name stays untouched, the table's own attributes included.

**When the ids are absent** — and they are, inconsistently, even across pages of the same account — do not
fall back to a full-body rewrite on a page other people maintain. Bring the wording to the user and let them
paste it. A body rewrite is acceptable only on a page you authored and nobody has adjusted since, and even
then copy the existing `data-width`, `data-layout` and `data-colwidth` into the new markup.

**Verify after publishing.** `confluence-md` does not convert markdown task lists (`- [ ]`) into ADF task
lists; they land as plain bullets and a checklist becomes unusable. Read the page back after any publish and
confirm the shape you intended, not merely that the call succeeded.

**The API handles content well and formatting badly — check whether that is still true.** Observed on
2026-09-17: a markdown task list published as plain bullets; a full body rewrite dropped the table width its
author had set; line breaks inside a table cell did not come out as written. Each time the call reported
success and the markdown export looked plausible, so neither of those proves anything about layout — only
opening the page does.

Treat this as a dated observation, not a property of the tooling. Before concluding "the API cannot do it",
spend one edit finding out: make the change, open the page, look. If the layout lands correctly, the converter
or the API has been fixed — delete this file and its line in `CLAUDE.md` rather than work around a problem
that no longer exists. While it holds, split the work the way that costs least: content, facts and wording
through the API, fine formatting by whoever is already in the editor.

The date above is when this was **first observed**, and it stays as written. When it was last re-checked, and
when it next falls due, are kept out of KB on purpose — see
[external_claims_recheck](../reference/external_claims_recheck.md) for the cycle, including the rule that a
re-check is asked for rather than taken on your own initiative.

**Why:** caught 2026-09-17 — a checklist page was rewritten several times through full-body updates, and every
pass dropped the width its author had set in the editor. The same mechanism silently reverts any manual
formatting on a shared page, and shared pages are the ones people notice.
