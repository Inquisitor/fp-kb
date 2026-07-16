# FP-44946 Backlog

- [ ] Decide the target surface for the final flow document (Confluence section, KB deep dive, or both)
- [ ] Platform requirement checklist to feed the "Choose Git platform" workstream (enforced merge
      method, protected branches, rebase UX, merge queue availability)
- [ ] Tag convention for protocol-version increments (annotated tags at release boundaries)
- [ ] Branch <> release mapping (which release ships from which server branch; one branch can host
      several releases, e.g. MFT: FTUE + FPA 2026.5) — needed for placing release tags in Git history
      after the migration; seed data: `<kb>/_index.md` → Releases (current)
- [ ] `git worktree` onboarding note for the team (sibling-folder layout, IDE caches)
- [ ] Verify the SVN-Git sync tooling choice against the append-only mirrored-branch rule
