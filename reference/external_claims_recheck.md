---
name: External claims and their re-check cycle
description: How a claim about an external system is recorded so it can expire — claim and first-observed date in KB, last-checked and due dates in a memory register, re-check only after asking
type: reference
---

A claim about an **external** system — what a tool can do, how a third-party service is configured, what
someone else's setup permits — is true on a date, not forever. Nobody announces a fix. Undated, such a claim
hardens into "this cannot be done", and the workaround outlives the problem it was built for.

## Where each part lives

| Part | Home | Why there |
|------|------|-----------|
| The claim, and the date it was **first observed** | KB, in the note stating it | It is part of the knowledge; every reader needs to see how old it is |
| **Last checked** and **next check due** | Memory register `external-facts-recheck` | Updating it must not cost a commit and an approval round, or it stops being updated at all |

The register is state, not transit — the sanctioned exception to "memory is an inbox"; see
[knowledge_homes](knowledge_homes.md).

## The cycle

1. **Writing a claim.** State it, date it, and add a row to the register: which note, what it claims, when it
   was checked, when it falls due. Default interval is one week.
2. **Meeting the claim in work.** If the due date has not passed, apply it and move on. Do not re-test — that
   is what the date is for.
3. **Past due.** Do not re-test on your own initiative: **ask first.** A re-check is a real action against a
   live system, and the moment may be wrong for it. Ask, then act on the answer.
4. **After a check.** Update both dates, whether or not anything turned out to have changed.
5. **When a claim stops holding.** Delete the KB note and its line in `CLAUDE.md`, and drop the register row.
   Do not soften the wording and leave it standing — a half-alive rule costs more than no rule.

## What is not an external claim

Knowledge about our own code — build quirks, how a framework behaves in our tree, a gotcha in our own
configuration — ages together with the code and is caught by reading it. It needs no register. This applies
only to what the external system alone can answer.

## If there is no register

A fresh environment, or KB carried to another machine: create `external-facts-recheck` in memory from the KB
notes that carry an observation date, giving each a due date a week out.
