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

The verdict was drafted in Phase 5 of `jira-review-open`. Confirm it still reflects the current state — revise if findings shifted or new info emerged. Final verdict is one of: `approve` / `reject` / `approve-with-waiting-for-release`. An `approve` may additionally carry the **ship-and-reopen sub-case** (Step 4): the change still ships and merges as an approve, but the card is set `status: reopened` and the `_index.md` row stays (Steps 6/7) because the task returns to the executor for non-blocking rework.

### Step 2 — Waiting-for-release check / finalize

**Forward path (when closing a fresh review):** if the change matches signals for post-release verification AND user hasn't declared status, AskUserQuestion:

> "This change matches signals for post-release verification (<signal X>, <signal Y>). Close as:
> 1. resolved (skip post-release check)
> 2. waiting-for-release (revisit after deployment)"

Signals include: logging improvements, fixes for rare races/unsync, changes observable only via production telemetry, threshold/heuristic changes whose effect needs production data.

If neither signals match nor user explicitly requests post-release verification — go straight to `resolved` (unless the approve is a ship-and-reopen sub-case, which sets `reopened` per Step 4).

**Reverse path (when this skill triggers on a card already in `waiting-for-release` status):**
1. Load the existing review card
2. Collect verification signal (logs / metrics / support reports) per the subject stated in the prior JIRA comment
3. Present findings to user
4. User decides outcome:
   - `resolved` — signal confirms behavior
   - Reopen — new problem found, back to executor
   - Close and file new task — different issue surfaced during verification
5. Execute the chosen action through the rest of this skill

### Step 2b — Release-step field gate (mandatory; approve path)

On any approve-family verdict (`approve` / `approve-with-waiting-for-release`, including a ship-and-reopen approve), apply the gate from [`<kb>/reference/release_checklist_field.md`](../../../reference/release_checklist_field.md) -> "Closure / review gate", using the reviewed diff (or `svn diff --summarize` on the carded revs) to derive the required options. If `customfield_11323` misses any, convey the release impact concretely and drive the field to set (propose value + set via `editJiraIssue` on approval, or have the executor/user set it) **before posting the verdict comment (Step 5)**. The only bypass is an explicit user waiver with a stated reason. On `reject`, skip.

### Step 3 — Cross-branch merge (any approve-family verdict; skip on reject)

Look up [`<kb>/_index.md`](../../../_index.md) → Branch Roles for current role assignments. Per [`<kb>/CLAUDE.md`](../../../CLAUDE.md) → Branch Roles, merge direction is `OldStable → Stable → Content → Code` — each level merges into all levels above it. Determine the target list from the source branch role:

- Source = OldStable → targets: Stable, Content, Code
- Source = Stable → targets: Content, Code
- Source = Content → targets: Code
- Source = Code → no upward merges

**Release-mapping caveat (downward merges are user-directed).** The role table covers upward merges only; the target set is ultimately a release question, and one branch can host more than one release at a time (e.g. Content carrying its regular release plus a team-specific one) — that is normal, but it means a commit may need a downward cherry-pick the role table will never produce. Downward merges are directed by the user, not derived. If release↔branch info is available ([`<kb>/_index.md`](../../../_index.md) → Releases) and you are 100% certain which branch the task's release ships from, and the reviewed commit is not there — propose that merge to the user; otherwise surface the uncertainty instead of concluding "no targets" from the role table alone. Record any user-directed deviation in the review card.

**For each target branch, apply branch-copy inheritance check** (see required reads). If the commit revision is ≤ the target's creation revision from its source, the fix is already inherited via branch copy — skip merge for that target.

For each remaining target:
- `svn status` the target WC **first**, before update or merge, to record the pre-existing-mods baseline — so afterward you can tell your merge from the user's in-flight edits (explicit-path commit protects unrelated *files*, but not the user's edits in a file the merge also touches, nor root property changes swept by `.`)
- `svn update` the target branch working copy to HEAD first — a stale target root fails the merge commit with `svn: E170004: ... out of date`, forcing an update + re-commit round-trip
- `svn merge -c <rev>` into target branch working copy
- Verify result (no unexpected files, no conflicts); on conflict — STOP, do not post any JIRA comment yet
- Commit using SVN merge commit format from [`<kb>/CLAUDE.md`](../../../CLAUDE.md) → SVN merge commit format. **If the target WC carries unrelated local modifications** (another task's in-flight edits — run `svn status` before committing), never `svn commit` at the WC root: it sweeps those edits into the merge commit. Commit only the merged paths explicitly, plus the root for mergeinfo: `svn commit <merged-path-1> <merged-path-2> . --depth empty`. After commit, verify only the pre-recorded baseline remains uncommitted. (Same hot-WC discipline as the `_index.md` staging rule in Step 8.)

**Paired client commits.** If the task has paired client commits (client-repo revisions in the JIRA thread / review card Scope), verify at close that they are present in the target client branch. `svn mergeinfo --show-revs eligible` is necessary but NOT sufficient — client bulk merges record ranges without a content guarantee (project memory `mainclient-cherry-pick-mergeinfo`) — so verify by content tokens: distinctive identifiers/files from each client commit's diff, checked in the client checkout. Client-branch merges are owned by the client team: if commits are missing, flag it to the user / client lead — the server side merges client commits only as a last resort, at the user's explicit direction. Record the outcome in the review card. Omit `Merged → <client branch>` JIRA lines for merges not performed.

**Paired landing order.** When the close performs user-directed paired merges (server change + client mirror / `Photon.Interfaces` change), prepare BOTH working copies first — server merge applied, client merge applied, DLL rebuilt from the TARGET server branch (never carried across branch pairs as a binary) — then wait for the user's end-to-end smoke test (build the server, run it, build the client, log in), and only then commit the two halves back-to-back. The server half never lands alone: it opens a mismatch window on a shared release branch. See [`<kb>/reference/release_versions_and_process.md`](../../../reference/release_versions_and_process.md) → pairing rule and [`<kb>/reference/photon_interfaces_dll_distribution.md`](../../../reference/photon_interfaces_dll_distribution.md) → Branch pairing and merge discipline.

### Step 4 — Draft JIRA comment

Read formats fresh at draft-time: [`<kb>/reference/jira_comment_formats.md`](../../../reference/jira_comment_formats.md).

The comment combines a verdict base with optional add-ons. Default is to combine in one comment; split when an add-on is substantial, wants its own notification thread, or is technically independent.

**Verdict patterns:**

**Bare-`LGTM.` admissibility (check first).** A bare `LGTM.` is admissible only when the Verdict carries no caveat. If the Verdict carries a caveat — a `Verification scope:` line from open Phase 5, or a behavioural caveat — a bare `LGTM.` is forbidden and that caveat must be **carried forward into the posted comment**: as the reasoning of **Approval with reasoning**, a **warning panel**, or (for a ship-and-reopen approve) the ship-and-reopen lead. A `Verification scope:` caveat must not be dropped from JIRA — the gate exists to stop the close comment erasing what open Phase 5 made mandatory. Metadata-only Notes (executor-quality) do not by themselves forbid a bare `LGTM.`.

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

- **Ship-and-reopen** (an `approve` sub-case — change ships and merges as-is but the task returns for non-blocking rework): lead by decoupling release safety from the reopen — `No blocking issue; safe for the release.` — then a numbered non-blocking follow-up list. Keep follow-up on the same task (reopen) when it stays within the task's accepted scope; split into a separate ticket only out-of-scope work. This comment does not open with `LGTM.` — an explicit exception to the LGTM-first approve convention. Set card `status: reopened`, keep the `_index.md` row (Steps 6/7), and transition the JIRA ticket back to the executor (or request it; mark pending in the Step 9 table if the tool cannot).

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
  - `reopened` (a ship-and-reopen approve sub-case, or a blocking `reject` that returns the task to the executor for rework)

### Step 7 — Update Active Reviews in `<kb>/_index.md`

- `resolved` → remove entry
- `waiting-for-release` → keep entry (stays listed until resolved later)
- `reopened` → keep entry (stays listed until the executor's rework lands and the review re-closes)

### Step 8 — KB commit

Format: `[Review] FP-XXXXX: <Title> (<status>)` + bullets describing what changed in KB.

Examples:

- Full close: `[Review] FP-42924: PremiumLedger crash (resolved)` + `+ Merged to MFT @ r16014`
- Park as waiting-for-release: `[Review] FP-41962: Line break logging (waiting-for-release)` + `+ Awaiting log review post-release`
- Open then pause: `[Review] FP-XXXXX: Title (in-progress)` + `+ Initial card with 3 findings; paused waiting for executor response on F-2`
- Finalize after waiting-for-release: `[Review] FP-41962: Line break logging (resolved)` + `+ Logs verified post-release; behavior confirmed`
- Reopen: `[Review] FP-XXXXX: Title (reopened)` + `+ Reopened — F-1 turned out blocking after retest`

Do NOT list the `_index.md` Active Reviews row add/remove as a bullet — it is housekeeping implied by the status (resolved drops the row, reopen keeps/returns it). Describe only real content.

**Staging `_index.md` safely (mandatory).** `_index.md` is a hot file the user edits concurrently mid-session — never `git add` / `git commit` it wholesale. Before staging, run `git diff -- _index.md` and confirm every hunk is your review's own row:
- Your row is the only diff → stage it with the card (bundled into this `[Review]` commit).
- The diff also carries the user's unrelated rows → stage only your own row (recipe below), or leave the whole `_index.md` row to the user and commit just the card folder.
- Open+close happened in one session with no intermediate commit → the add+remove nets to zero; nothing of yours to stage — commit only the card.

**Staging a single row without `git add -p`.** `git add -p` is interactive and unusable from the shell tool. Stage the one row by piping a zero-context patch to `git apply --cached --unidiff-zero`, anchored on the HEAD version of the file (not the working copy — your row sits among the user's new rows, which do not exist in HEAD):

```bash
git -C D:/kb show HEAD:_index.md | grep -n "<row above yours in HEAD>"   # gives <N>
git -C D:/kb apply --cached --unidiff-zero - <<'PATCH'
--- a/_index.md
+++ b/_index.md
@@ -<N>,0 +<N+1> @@
+<your row, copied verbatim from `git diff`>
PATCH
```

Do NOT hand-write a normal 3-line-context patch: a context line that is blank (the table's trailing empty line) loses its leading space through the heredoc and `git apply` rejects the whole patch with `corrupt patch at line <n>`. Zero-context sidesteps the problem entirely. Verify with `git diff --cached -- _index.md` before committing — it must show your row and nothing else.

Then, before committing, inspect `git diff --cached -- _index.md` (the full cached content — `--name-only` cannot reveal a foreign hunk staged *inside* `_index.md`) plus `git diff --cached --name-only` for the file list; confirm both are exactly your intended change. The whole KB repo is hot and a concurrent session may have pre-staged foreign files or hunks — capture the pre-existing staged state first, unstage foreign entries (`git restore --staged <path>`), and restore that captured staging afterward. If you leave the `_index.md` row entirely to the user, the KB close is not complete: mark the KB commit pending in the Step 9 table rather than reporting it done.

The commit message describes what changed in KB, not what's in the review card. The card itself is the state; the commit message is the diff.

### Step 9 — Closure summary

Before composing the table, re-read the review card's key points (Scope, verdict,
findings) and re-confirm the intake-established facts. Live JIRA fields (executor
field `customfield_11224`, status) must be re-fetched via MCP at close — they drift
after intake — not read back from the card. The card must be then updated accordingly.

Present a compact status table so the user sees the whole close at a glance. One
row per closure action or re-verified fact, with its concrete result/identifier;
mark anything still pending (user-side action or post-release verification) distinctly.

| Step / Fact                              | Status                                                           |
|------------------------------------------|------------------------------------------------------------------|
| Executor                                 | ✅ <commit author>                                                |
| Executor field (`customfield_11224`)     | ✅ filled  /  ⚠ still empty -> re-flag (intake nudge unactioned)  |
| Reviewed commit(s)                       | ✅ <source branch> r<rev>[, ...]                                  |
| Verdict                                  | ✅ <approve / reject / approve-with-waiting-for-release>          |
| Cross-branch merge                       | ✅ r<rev> per target  /  ➖ inherited-skipped  /  ➖ n/a (reject)   |
| JIRA comment                             | ✅ <permalink>  /  ✅ rejection posted                             |
| Release-step field (`customfield_11323`) | ✅ <options set>  /  ➖ n/a                                        |
| Review card                              | ✅ resolved  /  ✅ waiting-for-release  /  ✅ reopened             |
| KB commit                                | ✅ <hash>                                                         |
| Pending                                  | ⏳ <user-side JIRA transition / post-release due-date>  /  ➖ none |

Lead each Status cell with a state glyph — ✅ done/confirmed, ⏳ pending (user-side or
post-release), ⚠ needs attention (e.g. executor field still empty), ➖ n/a — then the
concrete value (a revision, a link, a hash, a field value). The glyph is the
at-a-glance read; the value is the audit trail. Never a bare glyph with no value, and
never a value without its state glyph.

Adapt rows to the actual close: add a row per merged target when there are several. If
the executor field is still empty, the row doubles as a re-nudge (⚠) - do not silently
mark it done.

Never silently omit a step. A step that does not apply is either kept inline with
`n/a (<reason>)` or, if dropped from the table, named in one trailing line so it
reads as considered-and-excluded, not forgotten - e.g. `N/A: cross-branch merge
(source = Code, no upward targets); release-step field (binary-only change).`

### Step 10 — Reflection (post-commit, lightweight)

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

This step does NOT block closure — closure is complete once Step 8 commits (or, if the `_index.md` row was left to the user per Step 8, once that row lands). Reflection is value-add, not load-bearing.

## Edge cases

- **Reject verdict** — skip step 3 (merge) entirely. JIRA comment uses rejection template (step 4).
- **Multiple target branches** — all merges in step 3 happen as separate commits; one JIRA comment in step 5 lists multiple `Merged → <BRANCH>` lines.
- **Merge conflict** — fix or skip the merge first; do not post any JIRA comment until merge state is settled.
- **Fix already inherited via branch copy on all targets** — skip step 3 entirely; JIRA comment omits all `Merged → <BRANCH>` lines.
- **Reopen after prior approval** — when off-channel triage flips a previously approved (LGTM'd) review: post a rejection-template comment (Step 4), set card frontmatter `status: reopened` (returning finished review work to the executor is `reopened`, not `in-progress` — per card-format semantics), and re-add the row to Active Reviews in `_index.md`. Perform, or request from the user, the actual JIRA workflow transition; if the tool cannot transition it, mark that pending in the Step 9 table. Re-approval after the executor's patch lands uses the standard approve template; if the author merged before the re-LGTM, omit the `Merged → <BRANCH>` line (no false audit claim).
