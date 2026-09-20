# SVN rev <-> git commit mapping — build report

Built 2026-08-15 by `match-svn-git.js` (this folder). Inputs: full SVN log r1:16426 (no paths),
all fp-server git commits with full message bodies. Match key: author epoch second + normalized
message (whitespace collapsed, non-ASCII stripped — the conversion flattened multiline messages
and mangled some encodings, normalization absorbs both).

## Results

| Metric                          | Value |
|---------------------------------|-------|
| git commits (all branches)      | 15729 |
| SVN revisions r1:16426          | 16426 |
| matched                         | 15729 — every git commit, zero unmatched, zero ambiguous |
| matched via date-only fallback  | 43 (message formatting drift; all date-unique — safe)    |
| SVN revs without a git commit   | 710   |

## Triage of the 710 unmatched SVN revisions

- **437 revs > r15989** — the known unsynced tail: MFT20260325, NPN20260602, post-April LBM/admin
  work. Converted in the surgery step by design.
- **273 revs <= r15989** — overwhelmingly branch administration (copy/delete/prepare revs, Ivan-era
  messages: "Create branch for ...", "Branch deleted as unused", empty messages on copies). These
  have no git counterpart by nature (a git branch is a ref, not a commit).
  - **To verify (deep sweep)**: a small subset reads like content commits (e.g. r3235 "Merged
    revision(s) 3167 from trunk: Fixed unsupported type issue...") — likely commits on deleted
    branches that the conversion did not recover. Each such rev gets a targeted `svn log -v`
    check: content on an unrecovered branch = acceptable loss (decide), content on a recovered
    branch = conversion gap (fix).

## What the mapping unlocks

- `git-svn-id: <url>@<rev> <repo-uuid>` trailers for every commit (rewrite pass).
- Committer date := SVN date (rewrite pass; author dates already historical).
- Completeness proof: the 100% match is strong evidence the conversion lost nothing on the
  branches it covers.

## Files

- `match-svn-git.js` — the matcher (rerunnable; inputs regenerable from SVN/GitLab).
- Generated TSVs (session scratchpad, regenerable): `mapping.tsv`, `anomalies-svn-unmatched.tsv`,
  `anomalies-git-unmatched.tsv` (empty), `anomalies-ambiguous.tsv` (empty).

## Next

- Owning-branch derivation per commit (for the git-svn-id path component).
- Targeted `svn log -v` on the suspicious subset of the 273.
- Rewrite tooling (filter-repo: dates + trailers + PlayerDesc case fix), then tail conversion.
