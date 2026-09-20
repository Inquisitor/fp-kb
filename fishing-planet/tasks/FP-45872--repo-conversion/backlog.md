# FP-45872 Backlog

- [x] Verify GitLab edition/tier — resolved: CE (push_rule API 404), so no push rules;
      commit-message enforcement goes through a CI check (job still to be drafted)
- [x] Access review — RESOLVED (user, 2026-08-25): Melnyk keeps Owner+admin, Kondratenko keeps
      instance admin, "но не больше" — the elevated-access list is CLOSED, no further owners or
      admins. Gnatkivskyi removed (new CLIENT programmer, devops over-granted at account
      creation). POLICY: client programmers do NOT get server-repo access for now, especially
      new hires — apply to future membership requests. Root custody stays with devops.
- [x] packages/ + LFS decision — resolved 2026-08-15: packages/ not versioned (0 files in LBM
      tip); pack 265 MiB, largest blob ~11 MB — no LFS needed
- [x] Empty-directory census — DONE 2026-08-18 (keeps timeline built from svn log -v, verified
      vs independent `svn ls -R` at all six live tips)
- [ ] Recursive svn:externals check
- [x] SVN archive/ inventory — resolved 2026-08-16 via the genealogy pass: all names accounted
      for, everything non-live lives under `archive/`; deleted CS20210519/GCP20230523 recovered,
      "MultiRods20180406 (to delete)" skipped as a botched-copy artifact (user-confirmed)
- [x] Authors map — resolved 2026-08-16: auto-generated from the svn-git correlation
      (scratchpad/authors.txt, 21 entries + VisualSVN Server), no conflicts
- [ ] fp-server-test project (created 2025-10) — inspect and decide disposal
- [ ] Flow-doc addendum: `trunk` name + moving `master` pointer policy (decided 2026-08-15)
- [ ] Post-cutover NFC commit (FIRST after cutover, user-confirmed): seed diff drivers into
      versioned `.gitattributes` so hunk headers show the enclosing method for everyone,
      retroactively for all history (attributes are read from worktree/HEAD, not the diffed
      commit; GitLab included — bare repos read HEAD attributes since git 2.43):
      `*.cs diff=csharp`, `*.java diff=java`, `*.css diff=css`, `*.html diff=html`,
      `*.cshtml diff=html`, `*.md diff=markdown`. No built-in drivers exist for sql/js/ts/vue
      (unknown driver names are silent no-ops — do not add placebo lines). Until then each
      local clone needs the same lines in `.git/info/attributes` (done 2026-09-17 in the
      user's viewing WC)
- [x] Junk classification — resolved by outcome: history finalized 2026-08-24 with
      Thumbs.db/.suo/.user kept as historical SVN content (only `.svn/` was conversion damage
      and was cut); the seeded .gitignore prevents new junk
- [x] Verify MI20200128 git tip covers SVN r11914 — confirmed: sync reports @11914 = svn
      latest; full file-list sweep vs SVN HEAD 0 diff (2026-09-17)
- [x] Lost-branch recovery — DONE 2026-08-16: CS20210519 and GCP20230523 recovered and
      transplanted; "MultiRods20180406 (to delete)" skipped as a botched-copy artifact
      (user-confirmed, recorded in genealogy)
- [ ] Pin down unattached genealogy edges (FSC20220227, SteamAsyncRealtime20170921,
      branch20160415) — cosmetic, for the genealogy artifact
- [ ] Later, separately: extend the Confluence Branch History table with the missing side
      branches (material ready in branch-genealogy.md) — ask before touching the page
- [ ] Carry into FP-45873 when it opens: epoch subfolders under archive/ (sortable numbering
      keyed by reconstructed release versions; genealogy artifact has the chain positions)
