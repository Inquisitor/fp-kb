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

**Why:** caught 2026-09-17 — a checklist page was rewritten several times through full-body updates, and every
pass dropped the width its author had set in the editor. The same mechanism silently reverts any manual
formatting on a shared page, and shared pages are the ones people notice.
