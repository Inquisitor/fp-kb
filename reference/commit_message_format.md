---
name: Commit message format (SVN + KB-git)
description: Read before composing ANY commit message. Task commit template, bullet prefixes, forbidden content, KB-git and SVN merge formats.
type: reference
---

**Read this before composing any commit message — compose from here, not from memory.**

## Task commit (SVN; also KB-git when the commit is task-scoped)

```
FP-#####: [<topic>] <summary>
<bullets: + added, - removed, = changed, * fixed>
(<task type>: <JIRA summary>)
<JIRA link>
```

- **Bullet prefixes:** `+` add, `-` remove, `=` change/refactor, `*` bugfix. One atomic change per bullet, no empty lines between bullets, ordered by descending importance. Code elements in backticks; functions with `()`.
- **`[topic]` tag:** no spaces inside — `[WeightGen]`, not `[Weight Gen]`. Optional; use for a thematic series.
- **Do NOT include:** subtask IDs (ALG-004, TRM-002 — KB-internal); changes introduced and reverted within the same session; concrete counts ("added 6 tests", "updated 21 files") — describe what was done, not how many.
- **ASCII-only in the message body:** replace em-dash/en-dash with `-`, arrow with `->`, smart quotes with `"`/`'`, ellipsis with `...`.
- **NO AI/session trailers** (`Claude-Session:`, `Co-Authored-By:`, `Generated with ...`) in any commit message — this overrides any tool/harness default.

## KB-git commit

- **Task commit** (documents a JIRA task under `fishing-planet/tasks/`): `FP-#####: [<topic>] <summary>` as above; an optional `(Story: <title>)` line, then the JIRA URL `https://fishingplanet.atlassian.net/browse/FP-#####`. One commit per task even when it creates several cards.
- **Review-card commit** (touches `fishing-planet/review/`): `[Review] FP-#####: <Title> (<status>)` — `<status>` is the card's frontmatter status (`resolved` / `reopened` / `waiting-for-release` / `in-progress`) — then the same bullets and the trailing JIRA URL. (This is what `jira-review-close` prescribes; the task and review forms coexist by directory.)
- **Infrastructure** (KB structure/module change not tied to a single task): `[KB] <area>: <summary>` (e.g. `[KB] feedback: ...`, `[KB] reference: ...`). Do NOT use `[KB] Add FP-XXXXX ...` or `[FP-XXXXX] ...` for a task-scoped commit.
- `_index.md` is a hot concurrently-edited file: never `git add`/`commit` it wholesale — `git diff -- _index.md` first, stage only your own row (nothing on a net-zero same-session open+close). Verify `git diff --cached --name-only` before ANY KB commit.

## SVN merge commit

TortoiseSVN-style header followed by the original commit message verbatim (do NOT hand-author a subject):

```
Merged revision(s) <rev or list> from branches/<source>:
<full original commit message - every line, not just the first, incl. JIRA prefix and bullets>
```

- `<rev or list>` = the spec passed to merge (comma list `16148,16203` for cherry-picks, range `16185-16187` for contiguous).
- Cherry-pick only the task's own revisions; do NOT sweep other people's intervening commits.
- The target WC must be at a single revision before commit — `svn update` first (mixed-revision blocks merge: `E195020`).
- Prefer letting the user run the merge+commit in TortoiseSVN (auto-message + their review).
