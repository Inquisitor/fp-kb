# Review Card Format

## Frontmatter schema

```yaml
---
status: resolved | waiting-for-release | in-progress
executor: <Commit author>          # point-in-time fact from SVN, stable
branch: <source> @ r<rev>[, merged to <target> @ r<rev>]
jira: <URL>                         # convenience link
---
```

## Frontmatter principle

KB is not SSoT for what already lives in JIRA. KB complements with information not present there (e.g., the server branch a commit lives on) and condenses for the agent what would otherwise require many MCP queries.

Rules:
- Include a field if it is (a) unique to KB — not in JIRA, or (b) a point-in-time fact about the artifact (review status, commit branch)
- Do not include fields that live in JIRA and drift (assignee, epic, related, labels) — fetch via MCP on demand
- `branch:` field is a strict contract — only `<source> @ r<rev>[, merged to <target> @ r<rev>]`. Do not stuff inheritance notes, parenthetical annotations, or other prose into it. Such facts belong in Investigation Journal.

## Required H1 heading

Body starts with `# Review: <JIRA-ID> — <Title>` or `# <JIRA-ID>: <Title>`. Do not duplicate title in frontmatter.

## Always present sections

- YAML frontmatter (per schema above)
- Summary — what the task does
- Scope (see format below)
- Investigation Journal — running log of methodology and non-obvious decisions

## Scope format — hierarchical list

Top level: commit ID + branch + commit msg first line. Nested: bullets from commit msg expanding intent.

**Simple case (1 commit):**

```markdown
## Scope

- **{branch} r16001** — Fix PremiumLedger crash when product is missing from cache
  - Null check before using product reference
  - Refactored `MonetizationCache.GetProductBrief` to use `TryGetValue`
- **{target-branch} r16014** — Merge from {branch} r16001
```

**Multi-commit, multi-branch — group by branch:**

```markdown
## Scope

### {Source branch}
- **r16003** — Add `UnlimitedBuoyRecolors` per-pond flag
  - Added boolean to `BaseConfigJson`
  - Wired into `BuoyRecolorPricing` logic
- **r16006** — Add `LastRecolorPricing` enum on buoy for recolor audit
- **r16012** — Move `UnlimitedBuoyRecolors` from JSON to column

### {Target branch} (merged)
- **r16007** — Merge of r16003+r16006
- **r16013** — Merge of r16012

### {Code branch}
- **r53190** — Add `UnlimitedBuoyRecolors` pond flag, temp guards for recolor UI
```

**Format rules:**
- Hierarchical lists — never markdown tables (alignment cost)
- Branch names without `(server)`/`(client)` annotations — agent looks up branch nature in `<kb>/_index.md` → Branch Roles
- Group by branch only when commits >1; for 1 commit, one-level list

**Drift refresh:** on any re-read of the task, re-fetch the commit list from both JIRA comments and `svn log | grep "FP-XXXXX"`. Cached scope cannot be trusted. If list changed, flag the new commits to user.

**Intent ≠ ground truth:** commit msg shows what the author intended; reality is in the diff. If they diverge meaningfully, that's a finding.

## Investigation Journal — what belongs, what doesn't

Journal captures methodology and non-obvious decisions, not action narration. Each line answers "what was done that isn't derivable from the rest of the card / external state".

**Belongs:**
- Hypotheses formed and disproven (e.g., "Initial hypothesis 'fix creates dead zone' proven wrong — two independent changes")
- Verification work whose record exists nowhere else (e.g., "Verified r15868 ≤ MFT copy source r15942 via `svn log` on `MissionsManager.cs`")
- Findings routing decisions (e.g., "F-2 → triage, F-5/F-6 → module backlog, F-1/F-4/F-7 accepted inline")
- Course changes (e.g., "Re-ran exploration after executor commented about missed file")

**Does NOT belong:**
- "JIRA comment posted" — comment is in JIRA, posting is closure step, not methodology
- "Review closed as resolved" — `status: resolved` in frontmatter already says this
- "Removed from Active Reviews in `_index.md`" — derivable from the index itself
- "Card created" — file's existence and git-log already record this; exception only if creation happened at an unusual phase
- "Merge committed at r<rev>" — `branch: ..., merged to <target> @ r<rev>` in frontmatter already says this

**Rule of thumb:** if removing the line leaves zero information loss (the fact is in frontmatter, JIRA, git, or the index), delete it. Routine closure steps are state, not methodology.

## Present when applicable

- **Findings** — with severity tags + structured format, only if there are non-trivial observations
- **Checklist** — correctness checks, only for complex logic changes
- **Verdict** — explicit approve/reject, only when not obvious from Findings + Resolution
- **Notes** — minor observations that don't rise to Findings

## Examples by complexity

- **Simple** (single-commit fix): Summary + Scope + Notes (or Findings if any non-trivial)
- **Medium** (multi-commit feature): Summary + Scope + Checklist + Notes
- **Complex** (multi-commit cross-branch): Summary + Scope + Findings (multiple) + Notes
