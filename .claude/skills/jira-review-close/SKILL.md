---
name: jira-review-close
description: Use when finalizing an open JIRA review — verdict, cross-branch merge, JIRA comment, KB commit; activated by closure intent on a session with an active review card
---

# JIRA Review — Close Phase

Finalize the review opened in `jira-review-open`: confirm verdict → cross-branch merge if applicable → draft & post JIRA comment → finalize KB → commit.

## Triggers

State-aware: invoke only when an active review card exists in this session AND user signals closure intent.

**Declarative (go directly to closure checklist):**
- `closing` / `closing review` / `finalize` / `finalizing` / `finalize review` (EN)
- `закрываем` / `закрываем ревью` / `финализируем` / `финализируем ревью` (RU)
- `закриваємо` / `закриваємо рев'ю` / `фіналізуємо` / `фіналізуємо рев'ю` (UA)

**Question (status snapshot first, then ask to proceed):**
- `that's all?` / `is that all?` / `what else?` / `what else is left?` / `anything else on the review?` (EN)
- `это всё?` / `всё?` / `что ещё?` / `что ещё осталось?` / `что ещё осталось по ревью?` / `что ещё осталось по задаче?` (RU)
- `це все?` / `все?` / `що ще?` / `що ще лишилось?` / `що ще лишилось по рев'ю?` (UA)

## State-guard at start

Before any closure action:
1. Confirm an active review card exists at `<kb>/fishing-planet/review/<JIRA-ID>--<slug>/review.md` and is referenced in `<kb>/_index.md` Active Reviews.
2. If only a task journal `<kb>/fishing-planet/tasks/<JIRA-ID>--<slug>/journal.md` exists (no review card) → user likely wants `kb-close-task`, not this skill. Suggest and stop.
3. If both exist → AskUserQuestion to disambiguate which one to close.

## Question-trigger sub-flow

If invoked via a question-form trigger:
1. Produce a status snapshot — for the active review card, list what's done and what's remaining out of the closure checklist (verdict / merge / JIRA comment / KB finalize / index cleanup / KB commit).
2. AskUserQuestion: "Ready to proceed with closure?"
3. On "Yes" — continue with the checklist below. On "No" — stop.

Declarative-trigger goes straight to the checklist.

## Required reads

Load before drafting any JIRA comment or running any merge:
- [`<kb>/feedback/active_criticism.md`](../../../feedback/active_criticism.md) — verified counter-arguments mandatory
- [`<kb>/feedback/reference_recheck.md`](../../../feedback/reference_recheck.md) — re-read format references at draft-time
- [`<kb>/feedback/jira_comment_preview.md`](../../../feedback/jira_comment_preview.md) — show preview, get approval, then post; share permalink after
- [`<kb>/feedback/branch_copy_inheritance.md`](../../../feedback/branch_copy_inheritance.md) — verify before svn merge whether the fix is already inherited

## Closure checklist

### Step 1 — Confirm verdict

The verdict was drafted in Phase 5 of `jira-review-open`. Confirm it still reflects the current state — revise if findings shifted or new info emerged. Final verdict is one of: `approve` / `reject` / `approve-with-waiting-for-release`.

### Step 2 — Waiting-for-release check / finalize

**Forward path (when closing a fresh review):** if the change matches signals for post-release verification AND user hasn't declared status, AskUserQuestion:

> "This change matches signals for post-release verification (<signal X>, <signal Y>). Close as:
> 1. resolved (skip post-release check)
> 2. waiting-for-release (revisit after deployment)"

Signals include: logging improvements, fixes for rare races/unsync, changes observable only via production telemetry, threshold/heuristic changes whose effect needs production data.

If neither signals match nor user explicitly requests post-release verification — go straight to `resolved`.

**Reverse path (when this skill triggers on a card already in `waiting-for-release` status):**
1. Load the existing review card
2. Collect verification signal (logs / metrics / support reports) per the subject stated in the prior JIRA comment
3. Present findings to user
4. User decides outcome:
   - `resolved` — signal confirms behavior
   - Reopen — new problem found, back to executor
   - Close and file new task — different issue surfaced during verification
5. Execute the chosen action through the rest of this skill

### Step 3 — Cross-branch merge (only if approve)

Look up [`<kb>/_index.md`](../../../_index.md) → Branch Roles for current role assignments. Per [`<kb>/CLAUDE.md`](../../../CLAUDE.md) → Branch Roles, merge direction is `OldStable → Stable → Content → Code` — each level merges into all levels above it. Determine the target list from the source branch role:

- Source = OldStable → targets: Stable, Content, Code
- Source = Stable → targets: Content, Code
- Source = Content → targets: Code
- Source = Code → no upward merges

**For each target branch, apply branch-copy inheritance check** (see required reads). If the commit revision is ≤ the target's creation revision from its source, the fix is already inherited via branch copy — skip merge for that target.

For each remaining target:
- `svn merge -c <rev>` into target branch working copy
- Verify result (no unexpected files, no conflicts); on conflict — STOP, do not post any JIRA comment yet
- Commit using SVN merge commit format from [`<kb>/CLAUDE.md`](../../../CLAUDE.md) → SVN merge commit format

### Step 4 — Draft JIRA comment

Read formats fresh at draft-time: [`<kb>/reference/jira_comment_formats.md`](../../../reference/jira_comment_formats.md).

The comment combines a verdict base with optional add-ons. Default is to combine in one comment; split when an add-on is substantial, wants its own notification thread, or is technically independent.

**Verdict patterns:**

- **Dry approval** (default): `LGTM.`
- **Approval with reasoning** (when accepted approach is non-obvious): `LGTM. <1-2 sentences stating what about the approach is sound — facts, not praise>.`
- **Dry approval + warning panel** (when the only non-trivial add-on is a behavioural caveat): `LGTM.` + ADF panel with the caveat
- **Rejection** (verdict-first, no praise padding):
  ```
  <1-sentence verdict>

  Blocking:
  - <issue framed as fact + direction, not complaint>

  Non-blocking:
  - <minor observation>
  ```
  Opening phrases: "A few items need rework before this can merge." / "Approach is close; flagging [N] blocking items." / "Raising blockers below; rest of the change reads well."

**Add-ons:**

- **Merge notation** — `Merged → <BRANCH>` per merged target. Branch role colors per [`<kb>/CLAUDE.md`](../../../CLAUDE.md) → Branch Roles. Branch-copy-inherited targets: omit their lines (no false audit claims).
- **Waiting-for-release note** — pattern: `[Specific subject] + [will need / should be] + [verification action] + [temporal anchor: once the release is deployed | after the release]`. Concrete subject ("This", "The logs", "Any recurrence"); impersonal tone ("should be", "will need"); no contractions, no idioms, no first person.
- **Audience handoff** — `@<Person>` (look up account ID via `lookupJiraAccountId` in Atlassian MCP) or role prefix (`QA: please verify <specific scenario>.`). Simplest form: "Please test."

### Step 5 — Show draft, get approval, post

Per `jira_comment_preview` rule:
1. Show issue link: `Issue: https://fishingplanet.atlassian.net/browse/FP-XXXXX`
2. Show formatted draft text. Ask "Post?"
3. On approval — call `addCommentToJiraIssue` MCP tool
4. After posting — share direct comment permalink

### Step 6 — Finalize review card

- Fill in remaining sections (verdict body, final notes)
- Set closure status in frontmatter:
  - `resolved` (default)
  - `waiting-for-release` (only when post-release verification needed)

### Step 7 — Update Active Reviews in `<kb>/_index.md`

- `resolved` → remove entry
- `waiting-for-release` → keep entry (stays listed until resolved later)

### Step 8 — KB commit

Format: `[Review] FP-XXXXX: <Title> (<status>)` + bullets describing what changed in KB.

Examples:

- Full close: `[Review] FP-42924: PremiumLedger crash (resolved)` + `+ Merged to MFT @ r16014`
- Park as waiting-for-release: `[Review] FP-41962: Line break logging (waiting-for-release)` + `+ Awaiting log review post-release`
- Open then pause: `[Review] FP-XXXXX: Title (in-progress)` + `+ Initial card with 3 findings; paused waiting for executor response on F-2`
- Finalize after waiting-for-release: `[Review] FP-41962: Line break logging (resolved)` + `+ Logs verified post-release; behavior confirmed`
- Reopen: `[Review] FP-XXXXX: Title (in-progress)` + `+ Reopened — F-1 turned out blocking after retest`

Do NOT list the `_index.md` Active Reviews row add/remove as a bullet — it is housekeeping implied by the status (resolved drops the row, reopen keeps/returns it). The row change is bundled into this `[Review]` commit by design — it keeps the review's active/reopen state in focus — and does not get a separate commit. Describe only real content.

The commit message describes what changed in KB, not what's in the review card. The card itself is the state; the commit message is the diff.

### Step 9 — Reflection (post-commit, lightweight)

After commit, briefly reflect on the review cycle as a whole — both `jira-review-open` and `jira-review-close` — and ask: did anything reveal something worth feeding back into the review workflow?

Triggers for action:

- **Improvement clearly visible** OR **user intervened during the cycle and the corrected behavior is clear** → propose change inline. If accepted, revise the relevant `SKILL.md` (open or close) or its references now. If user defers, record below.
- **Incident worth noting but improvement unclear** (e.g., "took longer than expected because of X", "almost slipped on Y", "user pushed back but the right fix isn't obvious yet") → append entry to project memory `review-process-observations.md` (created on first entry, append-only thereafter):
  ```markdown
  ## YYYY-MM-DD — FP-XXXXX

  **Observation:** <what happened, which phase / skill it touched>
  **Status:** unresolved | proposed-improvement-pending
  **Note:** <optional context>
  ```
  Entries are reviewed periodically; user decides what to codify into the skills, then clears the entry.
- **Nothing notable** → skip.

This step does NOT block closure — closure already complete at Step 8. Reflection is value-add, not load-bearing.

## Edge cases

- **Reject verdict** — skip step 3 (merge) entirely. JIRA comment uses rejection template (step 4).
- **Multiple target branches** — all merges in step 3 happen as separate commits; one JIRA comment in step 5 lists multiple `Merged → <BRANCH>` lines.
- **Merge conflict** — fix or skip the merge first; do not post any JIRA comment until merge state is settled.
- **Fix already inherited via branch copy on all targets** — skip step 3 entirely; JIRA comment omits all `Merged → <BRANCH>` lines.
