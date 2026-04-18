# FP-43424 Backlog

Deferred items and parking lot for ideas that appear during planning/execution. Items bubble up to module or server backlog on task close.

## Open questions

- [ ] Pass 5 systems — draft list from Pass 0 discussion: `fishing-core`, `progression`, `economy`, `social`, `competitive`, `platforms`, `live-ops`, `players-profile`, `monetization`, `infrastructure`. Validate against Pass 2+3 findings before emission; may collapse or split.
- [ ] External resources in cards — user mentioned a private 4-hour video on missions module. Starting simple: inline link in body if needed; promote to a structured field only when a cross-module query use case actually appears.

## Ideas captured during planning (post-mapping candidates — not this task)

- [ ] Skill `kb-vcs-scan` — periodic scan of recent SVN revisions against KB; report modules with code changes but no card updates. Significance heuristics: new public class, public-method signature change, new directory under existing `code_paths`, DB schema change, Photon Operations change. Ignore private method changes, pure refactors, bugfixes without public API change. Write after patterns stabilize.
- [ ] Skill `kb-sync-on-review` — extend review workflow with a step: detect modules touched by diff; check if Entry Points / Key Types / Dependencies in their cards still match; prompt updates.
- [ ] Skill `kb-sync-on-task-close` — analogous to above, at task closure.
- [ ] Skill `resume-mapping-session` — bootstrap protocol for continuing mid-pass work across sessions. Write once the pattern is real (not preemptively).
- [ ] Pilot modules to deepen after Pass 6 — candidates from active tasks: `matchmaking` (FP-41746), `fish-weight-gen` (FP-33182/FP-41845), `xbox-purchases` (FP-41929), `missions`. Aim 3-5.
- [ ] Dependency graph visualization — optional. Consider Mermaid in `_systems/dependencies.md` generated from frontmatter + using-statement grep.

## Deferred decisions (not blocking initial mapping)

- [ ] Test projects in cards — user prefers describing inline in the module card (with a mention of non-trivial test infrastructure) over a separate `-tests` module. Record in KB `CLAUDE.md` conventions after Pass 2, when actual test project patterns are visible.
- [ ] SQL / schema / stored procs — code lives in `SQL/` but logically belongs to individual modules. Deferred; will need a separate effort (possibly a `db-schema` system overview).
- [ ] Glossary — currently small. Decide expansion policy after the first functional modules reveal whether term drift is a real problem.
