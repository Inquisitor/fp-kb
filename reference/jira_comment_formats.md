---
name: JIRA comment formats
description: ADF formats for posting SVN commit notes and cross-branch merge notes to JIRA issues. MUST propose after every SVN commit (or merge) — do not wait for user to ask.
type: reference
---

## Workflow

After every SVN commit (or merge) to an FP-##### task: propose a JIRA comment in plain text for user review. Post only after user approves the text.

## Repos and branch labels

Two SVN repos, two URL segments. The Code-role branch in each repo uses the role color from `<kb>/CLAUDE.md` → Branch Roles.

| Repo   | URL segment | Branch label                                                                                                                                                                |
|--------|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Server | `#SRV`      | 3-letter SVN release branch name (e.g. `MFT`, `LBM`); first letter advances through the alphabet with each release so names self-sort. Current Code branch in `<kb>/_index.md` → Branch Roles. |
| Client | `#CLN`      | `CodeBranch` (working tree `Win64_CodeBranch`).                                                                                                                              |

Throughout this reference, `{branch}` and `{url-segment}` are the row values for the repo the commit was made on.

## Commit comment

### Format

**{branch}** (bold, colored by current branch role) @ [r{revision}](https://svn.fishingplanet.com/!/#{url-segment}/commit/r{revision}): {summary}

- Bullet points with details
- Code identifiers in `code` marks (ADF "code" mark type)
- Keep concise — not a full commit message, more like a changelog entry

### ADF structure

- First line: paragraph with `{branch}` (strong + textColor by role), " @ ", revision as link, ": summary"
- Body: bulletList with listItems
- Code names from codebase wrapped in `{"type": "code"}` marks

### Example — server

**LBM** @ [r15919](https://svn.fishingplanet.com/!/#SRV/commit/r15919): Edge distribution system - extract, implement, normalize
- Removed polynomial weight bias, Marsaglia re-roll
- `FishWeightGenerator` with normalized piecewise inverse CDF sampling
- Four edge strategies, `FishWeightGeneratorConfig`, `EdgeDistributionScope`

### Example — client

**CodeBranch** @ [r54342](https://svn.fishingplanet.com/!/#CLN/commit/r54342): Mirror MonoLeader leader-rod compatibility on client
- Added `MonoLeader` to `ListOfCompatibility` entries for the rods covered by the task

## Merge comment

### Format

Merged → **{target-branch}** (bold, colored by target branch role) @ [r{revision}](https://svn.fishingplanet.com/!/#{url-segment}/commit/r{revision})

### ADF structure

Paragraph: "Merged → ", branch name (strong + textColor by role), " @ ", revision as link.

### SVN-side commit message

The svn commit producing this merge uses the TortoiseSVN-style format documented in `<kb>/CLAUDE.md` → SVN merge commit format.

## Combined commit + merge in one workflow

When a single change lands as a commit on the source branch immediately followed by a merge to the target branch (the usual flow), post **one** combined JIRA comment, not two:

- The commit-comment paragraph + bullet list comes first.
- The merge-comment paragraph follows as a trailing paragraph in the same ADF document.

Two separate comments fragment the timeline and clutter the issue thread; one comment carries the same information with less noise.

## Paired server + client commits in one workflow

When a task requires changes in both repos (e.g. `ObjectModel` mirror, paired UI updates), post **one** combined comment, not two:

- Server paragraph first, with its bullet list (if any).
- Client paragraph next, with its bullet list (if any).
- Optional trailing paragraph with an @mention of the relevant lead (e.g. client lead) asking for review / merge into the target client branch.
