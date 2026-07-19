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

## Step 0: Pre-flight reads (mandatory before any other action)

Read these files using the Read tool — do NOT skip; do NOT rely on description summaries; do NOT assume "I remember the rules":

1. [`<kb>/feedback/active_criticism.md`](../../../feedback/active_criticism.md) — verified counter-arguments mandatory; no yes-man
2. [`<kb>/feedback/reference_recheck.md`](../../../feedback/reference_recheck.md) — re-read format references at draft-time
3. [`<kb>/feedback/verify_identifiers.md`](../../../feedback/verify_identifiers.md) — no placeholder URLs/IDs in audit commands

These rules apply throughout the workflow. Skipping this step means the skill cannot enforce its own discipline.

After all three Read calls complete, output one line: `Pre-flight reads done.` Then proceed to Phase 1.

**Closed loopholes:**
- Small commit / "trivial review" → not a reason to skip
- Repeat session, files Read earlier → re-Read; rules' application at draft-time depends on fresh context
- "I'll Read if I need it" → no, the point is preventive load, not on-demand

## Phase 1: Intake (foundational invariant)

**Phase 1 invariant** — ONLY these actions are allowed: read JIRA, write card, write `_index.md` entry. FORBIDDEN: `svn log`/`svn diff`, grep of code, reading project files.

Size of the change is irrelevant. Small commit is NOT grounds to compress this protocol.

### Steps

1. Read JIRA via `jira-read-issue` skill. Include `customfield_11224` ("Executor") — see [`<kb>/reference/jira_executor_field.md`](../../../reference/jira_executor_field.md).
2. **Executor hygiene check** (detect-only): if `customfield_11224` is empty, surface one line: `⚠ Executor field empty (expected: <commit author from JIRA comment>)`. Do NOT block, do NOT auto-fill.
3. Identify executor = commit author per JIRA comment (NOT JIRA assignee).
4. Collect commits as listed in JIRA comments — at face value. Do NOT verify via `svn log` here (that's Phase 2).
5. Determine source branch from JIRA comment as-is. If executor wrote it ambiguously or wrong, capture as Phase 2 finding — do not block intake, do not override.
6. **Existing-card check (re-review guard)** — before creating any folder, glob `<kb>/fishing-planet/review/<JIRA-ID>--*/`. The Active Reviews table in `_index.md` is NOT authoritative for this: resolved reviews are removed from that table but their folder stays. If a folder exists, this is a **re-review** (reopen / second-round fix): reuse that folder, keep the original content, and append a new `## Round N` section (Scope / Investigation / Findings / Verdict) for the new commits. Do NOT create a second folder. If none exists, create new card: `<kb>/fishing-planet/review/<JIRA-ID>--<slug>/review.md` with frontmatter, H1, Summary, Scope (placeholder if no commits in JIRA — capture as Phase 2 finding). See [card-format.md](references/card-format.md).
7. Add to (or refresh) the Active Reviews entry in `<kb>/_index.md` — point to the existing folder on a re-review; list all round executors.

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

**WC freshness check (do this before reading any changed file from disk).** After collecting the revisions, run `svn info --show-item revision` on the WC and compare against the lowest revision under review. If the WC is behind:
1. Run `svn status`. If the WC is clean, **ask the user for permission** and `svn update` to HEAD; after that the disk is trustworthy — read files normally.
2. If the WC is dirty, the user declines, or the review targets a pinned older revision — fall back: treat `svn diff -c` / `svn cat -r` as the sole source of truth, do NOT read the changed files from disk, and (Step 6) include this stale-WC warning plus the exact commands in the delegated reviewers' prompts (agent and Codex).

Why this matters: a stale WC silently shows pre-fix file state, which has twice caused a changed file to look absent/reverted (once propagated into a delegated agent as a false "fix not present" alarm).

### Step 2 — Diff reading

`svn diff -c <rev>` for each commit. Read the DIFF, not the current file state.

For multi-commit reviews (≥3 commits), use `TaskCreate` with one entry per commit; track in_progress / completed as you walk.

### Step 3 — Recon

Quick scan across diffs; surface obvious patterns; summarize to user.

### Step 4 — Hypothesis-then-verification

Every factual claim presented in or used to support a finding — its title/problem statement, description, mechanism, severity, resolution, or remediation (together, the finding's **supported claims**) — must be verified before it is written as fact. Investigation must contain a claim-specific verification bullet stating the exact target, instrument and scope, observed result, and conclusion. One verified premise does not unlock any other premise. "Read code", "checked DB", and delegate confidence are not verification.

If verification does not settle the claim — the instrument is unavailable, or the evidence it produced is inconclusive, partial, or non-reproducible — record it explicitly unresolved and state why (for an unavailable instrument, name the instrument, the blocker, the access attempted, and the alternative considered). Do not use an unresolved claim to support any of the finding's supported claims; unresolved is never rejected and never promoted.

- **Persisted-instance claim** ("row exists", "field has value X", "save committed") — verify the relevant stored state using a DB query or stored bytes, with the environment, record/key, and relevant time/revision identified. A save call or serialization mapping proves only an attempted write or serialization capability, not the persisted outcome.
- **Serialization/schema-shape claim** ("field X is serialized", "DTO lacks property Y") — inspect the actual DTO, mapping, serializer, or schema.
- **Control-flow/reachability/identity claim** ("scenario X calls Y", "this is the applicable implementation") — trace from the scenario entry/dispatch point to the exact implementation at the reviewed revision. Reading an implementation in isolation does not prove that the scenario uses it; use a trace, test, logs, or configuration when dispatch is dynamic.
- **Negative-data claim** — an empty query result establishes only absence from the queried population. It does not refute a reachable or latent case unless that population is shown to be authoritative; check live references and sibling/variant consistency, or record why each cannot affect authoritativeness.
- **Remediation-scope claim** — before stating that a fix requires adding or changing a field, DTO/schema, method, or call site, inspect the exact named artifact and record the missing capability in Investigation. Do not prescribe changes to an uninspected artifact.
- **Other factual claim** (numeric/computation, concurrency/timing/ordering, runtime-config/deployment/feature-flag, protocol/client-contract, provenance/VCS-history, compilation/test/platform, authorization) — use an instrument capable of observing the exact proposition in its applicable revision, environment, configuration, and execution context. Static source inspection establishes only static-source facts; runtime, data, deployment, and external-contract claims require corresponding executable or runtime evidence (a test, a run, a probe), and a provenance/history claim needs the VCS record (svn log/diff/blame). When no capable instrument settles it, the unavailable/inconclusive rule above governs.

Where any rule above says "relevant", "applicable", "the population", or "already verified", bind it to the exact proposition and context the finding asserts; a surrogate context or a subset is admissible only with a stated equivalence or discovery argument, not a judgement that it is close enough.

This gate applies before a recon hypothesis, a delegated finding (Step 6), an executor claim (Phase 3), or a remediation claim is promoted to — or used to support — any of the finding's supported claims. A hypothesis may be recorded unverified in the Investigation Journal; it may not be relied on as fact until it passes this gate.

### Step 5 — Branch-copy inheritance check (if Code-branch merge applies)

See [`<kb>/feedback/branch_copy_inheritance.md`](../../../feedback/branch_copy_inheritance.md). If the fix is already inherited via branch copy, mark in Scope; close phase will skip merge.

### Step 6 — Mandatory independent delegation (agent + Codex)

After recon, launch an independent review in parallel — a required step, run even when recon found nothing (clean-LGTM is the highest-risk case for a missed defect). Two modes, both in parallel:

**Independent defect hunt (blind).** Point the `code-reviewer` agent (Agent tool) and Codex (`/ask-codex` skill) at the diffs/scope: hunt for defects, assume bugs exist, ground each claim in the evidence Step 4 requires — cite the file/method for a code claim; for a data/runtime claim whose probe cannot be run, return it as an unresolved hypothesis, not a finding. Prefer NOT to pre-load the recon findings — a delegate that echoes recon adds nothing, and one told to argue against it manufactures objections. Independence + claim-appropriate evidence (per Step 4) is the goal.

**Targeted verification (grounded).** For any specific recon finding you are genuinely unsure about, hand that finding to a delegate (agent and/or Codex, in parallel with the hunt) for a focused confirm/refute — scoped to that finding, required to cite evidence per Step 4 either way. This is where adversarial pressure belongs: on a named uncertain claim, not a blanket "challenge everything".

**Critically re-verify every delegated finding before accepting it** — this re-verification is the filter that kills both sycophantic confirmations and contrarian red herrings:
- Accept a delegated finding only after your own Step-4-compliant verification supports every one of the finding's supported claims. If your verification disproves it, record it considered-and-rejected; if verification does not settle it (instrument unavailable, or evidence inconclusive), record it explicitly unresolved per Step 4 — never rejected, never promoted.
- Where a delegation corrects your own recon (mechanism, severity), record it in the Investigation journal (hypothesis disproven).
- Where the delegations disagree with each other or with recon, resolve each disagreement using the evidence Step 4 requires for the disputed claim — not by majority; code inspection alone resolves only static-code propositions. **Surface any disagreement that stays unresolved or is decision-affecting to the user directly, not only in the card.**
- Attribute each surviving finding in "Discovered by" (skill recon / code-reviewer agent / Codex).

**Stale-WC propagation (per Step 1 fallback):** if the WC was not updated (dirty / declined / pinned old rev), both the agent and Codex will read pre-fix disk state unless warned. Include in each prompt an explicit warning that the WC is behind the reviewed revision, plus the exact `svn diff -c <rev>` and `svn cat -r <rev> <branch-URL>/<path>` commands to use as the source of truth instead of disk reads.

## Phase 3: Verification

Coverage sweep for executor claims: enumerate the executor's factual claims from commit messages and JIRA comments (structure, data, runtime, deployment, compatibility — not only code structure). For each claim not already verified in Phase 2, apply the Step 4 gate and record its verification bullet in the Investigation Journal; do not re-verify claims already covered. Don't take any executor claim at face value.

## Phase 4: Findings

### Format

```markdown
### F-N: <concrete problem statement> [Severity]

**Description:** what's wrong, where (file/method, no line numbers), why it matters; severity-justifying in 1 sentence.

**Investigation:** chronological bullets of work done — read, grepped, hypothesized, ruled out, agent-checked. Trivial findings are NOT exempt from Step 4: each verification bullet must still state the target, instrument and scope, observed result, and conclusion; a bare "File inspection only" is invalid.

**Resolution:** action + brief justification.

**Discovered by:** skill recon | code-reviewer agent | Codex | executor's comment | manual scan. (Required for non-trivial findings.)
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
