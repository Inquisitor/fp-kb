---
name: Impersonal register in written artifacts
description: JIRA comments and issues, and documents sent to another team, are written without first or second person - no we/our/us and no you/your; neutral subjects or passives instead
type: feedback
---

JIRA comments and issues, and documents addressed to another team, are written in an **impersonal
register**. Both persons are excluded: no `we` / `our` / `us`, and equally no `you` / `your`
(ru: no `мы/наша` and no `вы/ваш/просим`). Use a neutral subject or a passive construction instead.

**Why:** the artifact is a report on what happened or a statement of what is needed, not a
first-person diary and not an address to a counterparty. Personal pronouns add no information in
that register, and in cross-team text the `we`/`you` split quietly turns a technical statement into
a division of blame.

**How to apply:**

| Instead of                                 | Write                                                             |
| ------------------------------------------ | ------------------------------------------------------------------ |
| we didn't re-ban any of them               | none of the four were re-banned                                     |
| our review at confidence 9-10              | the trial review at confidence 9-10                                 |
| banned by us 4 -> 17                       | banned this cycle 4 -> 17                                           |
| your fix                                   | the client-side fix                                                 |
| we ask you to confirm                      | confirmation from the client side is required                       |
| you will see it in the red test            | the red test is the signal                                          |

Where avoiding a pronoun produces a contortion, **name the actor** — a team, a service, a role,
a component — rather than bending the sentence around the ban. "IP ranges that neither side claims"
is worse than "IP ranges that the provider does not recognise as its own".

**Verbatim quotes are exempt.** A quote from the other side keeps its original pronouns: a quote is
data, not voice.

**Never announce the register inside the artifact.** A header saying the document is written
impersonally is internal process leaking outward, the same family as AI attribution.

**Where this does not apply:** Slack and other conversational writing keeps its personal voice.
Commit messages are already impersonal by convention and need no change.

Related: [JIRA Story authoring format](../reference/jira_story_authoring_format.md) restates the
rule for Story descriptions; [JIRA comment preview](jira_comment_preview.md) governs posting.
Cross-team tickets have their own brevity rules on top of this one.
