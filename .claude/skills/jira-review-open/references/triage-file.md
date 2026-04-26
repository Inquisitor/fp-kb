# Release Triage-File

Used when a backlog of review-pending tickets has accumulated under a release window and review is happening close to release. The standard per-ticket workflow (`jira-review-open` and `jira-review-close` skills) still applies in full — cards, index, findings, all of it. The triage-file is one extra artifact that aggregates minor concerns across multiple reviewed tickets into a pre-release meeting agenda, so that authors don't get late-stage reopens for hygiene-level questions.

> This is an emergency protocol, not a steady-state mode. Goal is to keep reviews caught up so this is never needed.

## Activation

The pass is in triage-mode when the user's prompt includes a line `triage file: <path>`. Without that line, the standard workflow applies and there is no aggregate ledger for minor concerns — they route either to the review card, to a JIRA comment, or as a reopen, depending on severity.

## What goes into the triage-file

Strict 3-way AND. An entry is added ONLY IF:

1. **Open** — not resolved during review (`Accept` / `Skip` stay in the review card only)
2. **Introduced by the commit under review** — pre-existing gaps go to `<kb>/fishing-planet/server/modules/<module>/backlog.md` with a note citing the discovering review, NOT to triage
3. **Requires a decision** — author clarification, patch, hotfix, or new ticket. Pure Info notes (no action required) do NOT enter

### Author clarification — when it counts

A "question to the author" is triage-worthy only if **the answer determines an action**:
- "If intentional — Accept; if not — reopen/file ticket" → triage entry (decision under uncertainty)
- "I want to understand the intent, won't change anything either way" → JIRA comment, card only

Dividing line: does anything depend on the answer?

### Rejection examples (do NOT add)

- Pure Info, no decision needed → review card only
- Pre-existing gap not caused by this commit → module `backlog.md`
- Cosmetic / commit-message typo → nowhere
- Author-clarification without consequences → JIRA comment, card only

### Acceptance examples (DO add)

- "Raw `AllMissions.Remove` bypasses helper — ask author: intentional or oversight?" → answer drives action → ADD
- "This reorder depends on an implicit null-check; decide whether to add a clarifying comment" → ADD

## Triage-file location and header

`<kb>/fishing-planet/server/modules/<module>/triage-<YYYY-MM>.md`

The file MUST start with this header verbatim (except the release name):

```markdown
# <Module> — Release <NAME> Triage

> **This file is a transient release-pass triage log.** Format below is strict — do not alter structure.
>
> **Entry criteria (all three must hold):**
> 1. **Open** — not resolved inline during review
> 2. **Introduced by commit under review** — pre-existing gaps go to `<kb>/fishing-planet/server/modules/<module>/backlog.md`
> 3. **Requires a decision** — author clarification (decision-affecting), patch, hotfix, or new ticket
>
> When in doubt: do NOT include. Better to miss than to drown the meeting.
>
> **Closed items move to the "Decided" section with a filled `Verdict` field.**

## Open
```

## Entry schema

Each entry is a single bullet under `## Open` (or `## Decided`), with 6 required fields:

```markdown
- **Source:** [FP-XXXXX](<JIRA URL>) / F-N, <branch> r<rev> — <short concrete title>
  - **Finding:** <1-3 sentences, concrete, files/methods in backticks>
  - **Severity:** Info | Low | Low-Medium | Medium | High (+ optional `(latent)` / `(pre-existing)` qualifier)
  - **Code state:** fresh (~<N days/weeks/months>) | stale | unknown
  - **Proposed action:** <e.g., "Ask author: ...", "Patch: ...", "File new ticket", "Accept with caveat">
  - **Verdict:** TBD <planned-decision-date> | <actual decision after meeting>
```

### Rules

- **Address** is `FP-XXXXX/F-N` — JIRA ID + originating finding ID from the review card. Acts as a stable cross-reference. F-N alone is not unique across the file (different cards can share F-numbers); the JIRA ID disambiguates.
- **Source line** carries: address (with link) + branch + revision + short title. The title summarises the finding for at-a-glance reading; details go in the nested fields below.
- **Finding**: must mention the file or method in backticks. No vague "issue with X logic".
- **Severity qualifiers**: `(latent)` — would manifest only under some future design; `(pre-existing)` — not introduced by the commit but noted alongside.
- **Code state**: helps the meeting decide whether the diff needs re-reading.
- **Proposed action**: one sentence, actionable.
- **Verdict**: `TBD <date>` until decided, then replaced (e.g., `Accept — event suppression was intentional`, `Patch 2026-04-28 r<rev>`, `Filed FP-XXXXX`).

### File structure

```markdown
<header verbatim>

## Open
<bullets...>

## Decided
<bullets moved here after Verdict filled>
```

Append chronologically. Addresses are stable anchors, do not sort.

## Lifecycle

1. **At pass start** — triage-file is created (or already exists for this release). Standard per-ticket workflow runs as usual. Each review produces 0 entries (LGTM with only Info findings) or 1-3 entries.
2. **During pass** — entries accumulate in `## Open`. Per-ticket review cards link to triage entries by F-ID; triage entries link back via JIRA URL.
3. **At meeting** — each entry is discussed; Verdict filled in.
4. **After meeting** — entries move to `## Decided`. Verdicts route per the table below.
5. **After release** — file is deleted (data has fully routed elsewhere).

### Verdict routing after the meeting

| Verdict                       | Where the resolution lives                                                                                                            |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|
| Reopen                        | JIRA comment posted at the meeting; review card reactivates (`status: reopened`) on next-round review                                 |
| File new ticket               | Link to new JIRA in the entry; do not duplicate in module log                                                                         |
| Accept / Skip with reasoning  | One line in `<kb>/fishing-planet/server/modules/<module>/log.md`: `Decision <date> [release X.Y triage]: <reasoning>` + card link     |
| Accept / Skip, trivial        | No record; entry deleted with the file                                                                                                |

Every non-trivial decision lands in a permanent location (JIRA, ticket, module log) before the triage-file dies.

## What NOT to do

- **Do NOT post to JIRA** for triage entries until Verdict is decided. Release-window JIRA noise is worse than delayed answers.
- **Do NOT reopen tickets unilaterally** for triage items between pass and meeting. Reopen is a meeting decision.
- **Do NOT skip the review card.** The card is mandatory per the standard workflow; the triage-file is additive.
- **Do NOT skip `<kb>/_index.md` updates.** Active Reviews is updated as in any review (typically no-op net per closed ticket, but state must be consistent at any moment).

## Volume note

Most LGTM tickets produce 0 triage entries (their findings are Info-only or pre-existing, both of which route elsewhere). Expect entries from a small fraction of the batch. If half the batch is producing entries, criteria are being applied loosely — tighten.

## Escalation hatch

If a finding looks like a **real defect with release impact** (not a hygiene question):
1. Record it as a normal per-ticket finding (severity, resolution) in the card
2. Surface to the user immediately
3. User decides reopen vs. defer
4. Do NOT route through triage as if it were minor

Triage is for hygiene questions; defects deserve standard discipline regardless of batch size.

## Relation to standard workflow

Complementary, not replacing. The standard per-ticket workflow (`jira-review-open` and `jira-review-close` skills) is fully applied for every ticket in the pass. The triage-file is **one additional channel** for minor concerns that would otherwise either:
- Be lost (card-only, never reaches authors)
- Cause a late-stage reopen (too heavy for hygiene questions)
