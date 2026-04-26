---
name: jira-review-open
description: Use when starting a JIRA task review — opens the review card, audits commits, drafts findings
---

# JIRA Review — Open Phase

Per-ticket review discipline: read JIRA → create review card in KB → audit commits → diff review → record findings → draft verdict. Closure happens in sibling skill `jira-review-close`.

## Triggers

- `review FP-XXXXX` / `review <JIRA-URL>` (EN)
- `ревью FP-XXXXX` / `ревью <JIRA-URL>` (RU)
- `рев'ю FP-XXXXX` / `рев'ю <JIRA-URL>` (UA)
- Without ID: model picks active JIRA-ID from prior conversation context

## Required reads

These rules apply throughout the workflow. Load before Phase 1:
- [`<kb>/feedback/active_criticism.md`](../../../feedback/active_criticism.md) — verified counter-arguments mandatory; no yes-man; no performative critique
- [`<kb>/feedback/reference_recheck.md`](../../../feedback/reference_recheck.md) — re-read format references at draft-time
- [`<kb>/feedback/verify_identifiers.md`](../../../feedback/verify_identifiers.md) — no placeholder URLs/IDs in audit commands

## Phase 1: Intake (foundational invariant)

**Phase 1 invariant** — ONLY these actions are allowed: read JIRA, write card, write `_index.md` entry. FORBIDDEN: `svn log`/`svn diff`, grep of code, reading project files.

Size of the change is irrelevant. Small commit is NOT grounds to compress this protocol.

### Steps

1. Read JIRA via `jira-read-issue` skill. Include `customfield_11224` ("Executor") — see [`<kb>/reference/jira_executor_field.md`](../../../reference/jira_executor_field.md).
2. **Executor hygiene check** (detect-only): if `customfield_11224` is empty, surface one line: `⚠ Executor field empty (expected: <commit author from JIRA comment>)`. Do NOT block, do NOT auto-fill.
3. Identify executor = commit author per JIRA comment (NOT JIRA assignee).
4. Collect commits as listed in JIRA comments — at face value. Do NOT verify via `svn log` here (that's Phase 2).
5. Determine source branch from JIRA comment as-is. If executor wrote it ambiguously or wrong, capture as Phase 2 finding — do not block intake, do not override.
6. Create review card: `<kb>/fishing-planet/review/<JIRA-ID>--<slug>/review.md` with frontmatter, H1, Summary, Scope (placeholder if no commits in JIRA — capture as Phase 2 finding). See [card-format.md](references/card-format.md).
7. Add to Active Reviews in `<kb>/_index.md`.

### Blocking checkpoint (BEFORE Phase 2)

Use `AskUserQuestion`:
> "Phase 1 invariant: confirm — review card exists on disk, `_index.md` updated.
> 1. Yes, proceed
> 2. Something not done — stop"

Wait for explicit "Yes". Without it, do NOT proceed to Phase 2. Applies regardless of commit size.

## Phase 2: Analysis

### Step 1 — VCS audit (executor-quality check)

For each plausible branch, run:
```
svn log -r <low>:HEAD <branch-URL> | grep "FP-XXXXX"
```

(`svn log --search` proven unreliable across multiple sessions — prefer `svn log | grep`.)

Cross-check found commits against intake. Findings:
- Commits found that aren't in JIRA → executor-quality finding (commit not posted)
- Branch in JIRA comment doesn't match commit metadata → executor-quality finding
- Commit count mismatch → either above

Update card Scope with audited commit list. See [commit-discovery.md](references/commit-discovery.md) for fallback strategies.

### Step 2 — Diff reading

`svn diff -c <rev>` for each commit. Read the DIFF, not the current file state.

For multi-commit reviews (≥3 commits), use `TaskCreate` with one entry per commit; track in_progress / completed as you walk.

### Step 3 — Recon

Quick scan across diffs; surface obvious patterns; summarize to user.

### Step 4 — Hypothesis-then-verification

Each hypothesis-level concern (potential issue) gets verified before becoming a finding. The Resolution field of any finding may NOT be drafted until at least one verification bullet exists in the Investigation section.

### Step 5 — Branch-copy inheritance check (if Code-branch merge applies)

See [`<kb>/feedback/branch_copy_inheritance.md`](../../../feedback/branch_copy_inheritance.md). If the fix is already inherited via branch copy, mark in Scope; close phase will skip merge.

### Step 6 — Mandatory agent delegation question

Use `AskUserQuestion`:
> "Diffs read, recon observations collected. Spawn code-reviewer agent for independent check?
> 1. Yes — deep delegation
> 2. No — recon sufficient"

Spawn the question even when recon found nothing. The question's purpose is to validate "absence-of-issues" claim from outside — clean-LGTM territory is the highest skip-risk for this step.

## Phase 3: Verification

Verify executor's claims about codebase structure (claims in commit messages, JIRA comments). Don't take at face value.

## Phase 4: Findings

### Format

```markdown
### F-N: <concrete problem statement> [Severity]

**Description:** what's wrong, where (file/method, no line numbers), why it matters; severity-justifying in 1 sentence.

**Investigation:** chronological bullets of work done — read, grepped, hypothesized, ruled out, agent-checked. For trivial findings: "File inspection only".

**Resolution:** action + brief justification.

**Discovered by:** skill recon | code-reviewer agent | executor's comment | manual scan. (Required for non-trivial findings.)
```

### Severity (about the issue)

- **High** — bug, data corruption risk, security
- **Medium** — meaningful concern, may not block
- **Low** — minor / cosmetic
- **Info** — observation only

### Resolution (independent of severity)

- `Blocking` — must be fixed before approval
- `Filed → <JIRA-ID>` — tracked separately as new JIRA
- `Accepted` — reviewed and accepted as-is
- `Skipped` — too minor to act on
- `Pre-existing` — noted, not addressed in this review

### Severity-assessment rules

- **Check release status BEFORE assigning severity** to any data-integrity / backfill / stale-row finding. Pre-release / Test environment has no "existing bad rows" surface — severity often collapses (e.g., from High to Skipped).
- **HEAD-verification on commits ≥2 weeks old.** Read each affected file on HEAD before assigning Resolution; if the issue was already addressed in a follow-up commit, Resolution = `Skipped — superseded by r<later>` (cite revision).
- **Per-site audit when N call sites have same risk shape.** Don't assume uniform fix; check each site — different post-call state mutations may need different patterns (or none).

### Routing

- **Blocking** → reject/reopen verdict; JIRA blocker list; status not approve
- **Author clarification, decision-affecting** ("if intentional Accept; otherwise reopen") → triage-file if active; else JIRA question with reopen-pending stance
- **Author clarification, no consequences** ("want to understand the intent") → JIRA comment, card only
- **Pre-existing gap** → `<kb>/fishing-planet/server/modules/<module>/backlog.md` with note citing the discovering review
- **Info / observation** → card only

For triage-file activation and entry rules, see [triage-file.md](references/triage-file.md).

### Findings discussion (when ≥3 findings)

`TaskCreate` per finding for the discussion round. For each: in_progress → discuss → resolution → completed. Skill actively pings: "Pre-publish: review F-1 through F-N severity/resolution."

For 1-2 findings: walk inline, no tracker.

## Phase 5: Draft verdict, stop

Decide approve / reject. Draft the verdict text in the review card body — do NOT publish anything to JIRA. Close phase (`jira-review-close`) takes over from here.
