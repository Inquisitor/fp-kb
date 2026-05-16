---
name: Don't track other teams' pre-existing bugs in our backlog
description: When reviewing for our task surfaces a bug in code another team owns (client UI, art assets, etc.), do not bubble it into our backlog. Either flag it in the relevant communication channel (e.g. JIRA comment to the right person) or drop it. Our backlog is for work we own.
type: feedback
---

When a deep review on our task surfaces a bug or smell in code that belongs to another team (e.g. UI code
during a server-side task, client-only logic during a server task, an asset issue during a code task), do
not add it to our task backlog or any module backlog under our ownership.

**Why:** Our backlog is a load-bearing artifact for **our** triage and prioritization. Polluting it with
items we won't action -- and shouldn't action -- adds noise, dilutes ownership, and creates a false
impression of accountability. The other team has their own backlog and process; tracking their work in
ours doesn't help them and burdens us.

**How to apply:** Three options when an other-team item surfaces:

1. **Flag in communication:** mention in a JIRA comment (review notes, follow-up), in chat, or in a
   handoff comment. Direct line to the owner.
2. **Drop with reason:** if the item isn't worth raising, note it in the "Dropped" section of the closing
   task backlog with one line of context. Stops noise without losing the fact that it was noticed.
3. **Bubble only if shared:** if the code is actually in a shared layer that both teams touch (e.g.
   `Shared/ObjectModel/` mirrored between server and client), the item is jointly owned and can go to a
   neutral backlog.

What NOT to do: silently bubble to our own module/client/server backlog "just in case". That's how
backlogs become unreviewable junk drawers.
