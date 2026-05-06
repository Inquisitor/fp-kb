---
name: JIRA comment formats
description: ADF formats for posting SVN commit notes and cross-branch merge notes to JIRA issues. MUST propose after every SVN commit (or merge) — do not wait for user to ask.
type: reference
---

## Workflow

After every SVN commit (or merge) to an FP-##### task: propose a JIRA comment in plain text for user review. Post only after user approves the text.

## Branch placeholder

`{branch}` is the SVN release branch the commit was made on. Branches in this project are named with a 3-letter topic acronym; the first letter advances through the alphabet with each new release (e.g., `L`BM, `M`FT, ...), so names self-sort by release order. Current role assignments live in `<kb>/_index.md` → Branch Roles (role definitions and colors in `<kb>/CLAUDE.md` → Branch Roles).

## Commit comment

### Format

**{branch}** (bold, colored by current branch role) @ [r{revision}](https://svn.fishingplanet.com/!/#SRV/commit/r{revision}): {summary}

- Bullet points with details
- Code identifiers in `code` marks (ADF "code" mark type)
- Keep concise — not a full commit message, more like a changelog entry

### ADF structure

- First line: paragraph with `{branch}` (strong + textColor by role), " @ ", revision as link, ": summary"
- Body: bulletList with listItems
- Code names from codebase wrapped in `{"type": "code"}` marks

### Example

Concrete example with `LBM` (Code branch at time of writing):

**LBM** @ [r15919](https://svn.fishingplanet.com/!/#SRV/commit/r15919): Edge distribution system - extract, implement, normalize
- Removed polynomial weight bias, Marsaglia re-roll
- `FishWeightGenerator` with normalized piecewise inverse CDF sampling
- Four edge strategies, `FishWeightGeneratorConfig`, `EdgeDistributionScope`

## Merge comment

### Format

Merged → **{target-branch}** (bold, colored by target branch role) @ [r{revision}](https://svn.fishingplanet.com/!/#SRV/commit/r{revision})

### ADF structure

Paragraph: "Merged → ", branch name (strong + textColor by role), " @ ", revision as link.

### SVN-side commit message

The svn commit producing this merge uses the TortoiseSVN-style format documented in `<kb>/CLAUDE.md` → SVN merge commit format.

## Combined commit + merge in one workflow

When a single change lands as a commit on the source branch immediately followed by a merge to the target branch (the usual flow), post **one** combined JIRA comment, not two:

- The commit-comment paragraph + bullet list comes first.
- The merge-comment paragraph follows as a trailing paragraph in the same ADF document.

Two separate comments fragment the timeline and clutter the issue thread; one comment carries the same information with less noise.
