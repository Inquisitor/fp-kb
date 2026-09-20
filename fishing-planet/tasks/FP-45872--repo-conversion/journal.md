---
jira: FP-45872
title: Convert the server repository from SVN to Git
status: in-progress
executor: Stanislav Samoilov
created: 2026-08-15
type: story
---
# FP-45872: Convert the server repository from SVN to Git

## Status
Conversion executed and live as a read-only synced showcase: GitLab
`fishing-planet/server/fp-server` (id 21) carries the full rewritten history (live branches +
`master` + `archive/*`, default NPN20260602), team has read-only access. Canonical bare:
`D:/FishingPlanet/src/server/git/fp-server.git`; viewing WC: `git/fp-server`; Kondratenko's old
clone archived as `git/fp-server-kondratenko`. SVN->git sync is self-service
(`svn-sync/sync-tails.js` + WC pull), proven on multi-branch merge caravans. Blocked on:
TeamCity build from git (devops; deploy-token handover pending) and the cutover window. Cutover
sequence: SVN freeze -> final sync -> freeze verification (file lists, empty dirs, default
branch) -> flow-doc protection (ff-only) -> seed diff drivers (first commit) -> SVN read-only ->
retire fp-server-old-conversion -> stale accounts -> close, start FP-45873.

## Summary
Convert the server repo to Git on GitLab: audit the existing fp-server conversion, decide
reuse-vs-reconvert, bring history up to date (MFT20260325, NPN20260602, post-April tail),
execute pre-cutover items, verify against SVN, cut over. Relates: FP-44946 (flow definition,
published), Relates: FP-45873 (semver tags, JIRA-linked as blocked by this task).

## Design decisions
- **Reuse the base conversion + tail surgery — CONFIRMED** (2026-08-15). Full reconvert rejected:
  base proven clean and connected.
- **Full-history rewrite before opening** (one pass, all SHAs change): committer dates := SVN
  commit dates (= author dates); `git-svn-id:`-style trailers embedded (rev<->commit mapping
  reconstructed by date+author+message matching); `PlayerDesc.cs` case fix. Consequence: the old
  GitLab project is deleted and a fresh clean repo is uploaded.
- **trunk/master policy**: the trunk lineage is named `trunk`, not master. `master` is a moving
  pointer advanced as releases cement/stabilize; initial position at least LBM. Needs a small
  addendum to the published Git flow doc (backlog).
- **MI20200128 (live Retail) included** in the refresh — Retail is released from it.
- **Historical branches under an `archive/` ref prefix** (decided 2026-08-16): everything not
  live (SVN-archived + deleted-recovered) becomes `archive/<OriginalName>`; live branches stay
  top-level. Mirrors the SVN archive/ concept; GitLab groups slash-prefixed branches in the UI.
  **Flat in this task**; epoch subfolders with sortable numbering deferred to the semver pass
  (FP-45873) — the epoch key should come from reconstructed release versions, not an invented
  interim scheme; ref re-foldering later is a cheap scripted operation.
- Deep-history defect sweep before the rewrite — early defects suggest more may lurk.
- **Git metadata decisions** (2026-08-18): `.gitattributes` (`* -text`, no eol normalization —
  binary-safe for everything) embedded through the ENTIRE history in a final tree-rewrite pass
  (standard migration practice: historical checkouts must carry the attributes; last cheap
  moment — repo unpublished). `.gitkeep` done HONESTLY through history (user call): injected
  into existing commits' trees when a dir exists empty in SVN, removed by the commit that brings
  the first file; emptiness = svn-dirs minus git-tree-dirs; dir-sets tracked through genealogy
  (branch copies bring dirs implicitly). `.gitignore`: root file (VS/build/NuGet/IDE/OS junk;
  `.sonarqube` kept as inherited from svn:global-ignores; deploy configs under Config/**/bin/
  re-included — pattern verified with check-ignore); whether to embed it full-history — pending
  user answer. Explicit `binary` marks for dlls — rejected (display-only, clutter).

## Plan
- [x] Audit first conversion: base clean (file lists 1:1, sentinel byte-identical, connected
      topology); damage = LBM tail `.svn` commits + one case-rename; reuse decision confirmed
- [ ] Deep-history defect sweep: per-branch fidelity spot-checks, junk classification
      (historical-in-SVN vs conversion artifact), empty-dir and case anomalies
- [~] Surgery + tail conversion IN PROGRESS (2026-08-17). Inventory: tails exist on IMV
      (r15621:16210, hotfix merges), KNW (r15857:16052), LBM (r15965:16116 — 6 contaminated +
      post-April), MFT (r15943:16401), NPN (r16131:16434, active today); MI fully covered
      (@11914 = svn latest, VERIFIED). LBM cut point: last clean commit 8af4d3c0 (@15964).
      Engine: git-svn fetch --no-follow-parent per branch + transplant.js (fetch objects into
      the target, rebuild chain via commit-tree with exact meta; graft gate = root-diff file
      count). KNW pilot DONE and verified against `svn diff -c 16052 --summarize` — exact match,
      property-only changes correctly dropped. ALL TAILS TRANSPLANTED 2026-08-17: KNW (1), IMV
      (2), LBM (36, grafted onto clean 8af4d3c0 — contaminated commits now unreachable), MFT
      (222, creation root dropped, grafted onto LBM@15942), NPN (219, grafted onto MFT@16130;
      tip = same-day commit). Repo: 80 branches, 16256 commits; `.svn` count in reachable
      history = 0. Verified: sentinel SharedConsts byte-identical NPN-git vs SVN HEAD; protocol
      increment commits present incl. 1126.0->1126.1 Anniversary. Fetch hiccup en route: authors
      file lacked post-Feb author (yevhenii.shust) — git-svn dies quietly when its stdout is
      piped; error capture must go to files, never `| tail`. Full file-list verifications ran
      for NPN/MFT/LBM (see next milestone).
- 2026-08-17: TAIL VERIFICATION PASSED. Full file-list vs SVN HEAD: MFT 0 diff, LBM 0 diff, NPN
      0 diff modulo r16435+ committed AFTER the fetch snapshot (live branch — final catch-up is
      part of cutover by design). Sentinel SharedConsts byte-identical; protocol increments all
      present. Remaining before upload: final catch-up fetch at freeze moment, ref restructure
      (trunk/master/archive per decisions), .gitattributes + .gitignore/.gitkeep, stale GitLab
      accounts, commit-message enforcement path, MSBuild smoke, delete old project + push clean
      repo.
- 2026-08-18: Empty-dir timeline BUILT AND VERIFIED for the honest .gitkeep pass
      ([artifacts/build-keeps-timeline.js](artifacts/build-keeps-timeline.js)): global versioned
      dir-set simulated over all revisions (changed-paths dump); emptiness = svn-dirs minus
      git-tree-dirs; keeps at leaf-empty dirs only. Two subtle SVN-log traps found and fixed:
      merges materialize parent dirs implicitly (file/dir adds without explicit parent A), and
      replay of copyfrom snapshots must apply the op sequence in order (replace revisions
      self-destruct otherwise). Self-check: empty-dir sets at ALL SIX live tips match
      independent `svn ls -R` sweeps EXACTLY. Transitions report for user review:
      [artifacts/keeps-transitions-report.md](artifacts/keeps-transitions-report.md) (74 dirs,
      924 intervals, 73 branches). User decisions: .gitignore embedded full-history too;
      .sonarqube line kept. Final tree-rewrite pass awaits user's OK on the report.
- 2026-08-24: Report review rounds via Plannotator: v2 fixed the misleading per-segment "tip"
      label (user caught it — GameServer1/2 died on trunk r3550, never reached NPN; data was
      right, the label lied); v3 regrouped by directory (166 event lines instead of 924
      inheritance repeats), user spot-checks confirmed App_Data r45 and Master. User OK received.
- 2026-08-24: FINAL METADATA PASS DONE ([artifacts/rewrite-metadata.js](artifacts/rewrite-metadata.js)): 16259
      commits rebuilt via temp-index tree surgery — .gitattributes + .gitignore in every tree
      from r1, .gitkeep per the verified timeline; 81 refs moved; SHAs changed the LAST time.
      Verified: r1 carries meta + CounterPublisher keep; NPN tip = SVN list + meta + exactly the
      17 keeps (extra Yespo files explained: live-branch drift, arrived r16437 after the
      comparison snapshot); historical boundary exact (GameServer1 keep present at parent of
      r3550, gone at r3550). Inspection clone refreshed. REMAINING: freeze + final catch-up,
      repack, GitLab replacement (delete old project, push, protection/ff-only, default branch,
      stale accounts, CI commit-message check) — needs team coordination.
- 2026-08-24: UPLOADED TO GITLAB (user decisions: old project renamed, upload now with locked
      branches). Old conversion lives on as fishing-planet/server/fp-server-old-conversion
      (retire after cutover). New clean project fishing-planet/server/fp-server (id 21): 81
      branches pushed, default = NPN20260602, protected `*` with push/merge = No one until
      cutover — team can clone and browse read-only. Remaining for cutover: SVN freeze + final
      catch-up (transplant catch-up mode is push-button), unlock to the flow-doc protection
      config (ff-only), stale account disable, CI commit-message check, retire the old project.
- 2026-08-24: PRE-CUTOVER SYNC MECHANISM in place (user call — the showcase must not go stale).
      Durable home `D:/FishingPlanet/src/server/git/svn-sync/`: side git-svn repos moved from
      scratchpad, authors.txt, transplant.js, sync-tails.js (idempotent: detect tails on all
      live branches -> git-svn fetch -> transplant -> push). GitLab protection relaxed to
      push=Maintainers (team stays read-only). First sync: NPN caught up 19 commits
      (r16438..16456, tip = FP-46015 same-day). INCIDENT fixed in the same session: transplant
      grafted raw git-svn trees, dropping the metadata at the new tip — transplant.js now
      carries .gitattributes/.gitignore/keeps from the graft parent (keeps dropped when a dir
      gains files; new empty dirs deferred to freeze verification); the 19 commits were redone
      and force-pushed (rule lifted/restored around the push). Remote tip verified with meta.
- 2026-08-25: Team access organized for the pre-cutover showcase: Burda raised Guest->Developer,
      Krepel and Kryzhovets added as Developer (Shust already had it); branches stay
      push=Maintainers (read-only showcase). TeamCity wired via a project deploy token
      (`teamcity-build`, read_repository only) — handed to devops for the VCS root; not tied to
      a person, revocable. All four accounts pre-existed and are active. CANONICAL bare =
      `D:/FishingPlanet/src/server/git/fp-server-rewritten.git` (all remaining steps target it;
      scratchpad copies are now disposable). Inspection working clone:
      `D:/FishingPlanet/src/server/git/fp-server-new` (checked out NPN20260602, longpaths on,
      ignorecase off). The old-conversion clone `git/fp-server` still points at the OLD GitLab
      project — do not confuse. GitLab not yet updated (fresh upload is the final cutover step).
- [x] Full-history rewrite pass DONE: committer dates, git-svn-id trailers, case fix
      (2026-08-16, rewrite-history.js; final tree pass 2026-08-24, rewrite-metadata.js)
- [x] Ref restructure DONE 2026-08-18: top-level = six live branches + `master` (= LBM tip, the
      cemented-release pointer); the dead trunk lineage lives as `archive/trunk` (user call:
      dead = archived, regardless of pedigree); 74 branches under `archive/`; HEAD -> NPN20260602
- [~] Pre-cutover: .gitattributes/.gitignore/.gitkeep DONE 2026-08-24; authors map DONE
      2026-08-16; stale-account review DONE 2026-08-25 (backlog); remaining: CI
      commit-message check
- [~] Fresh upload DONE 2026-08-24 (old project renamed fp-server-old-conversion, retire after
      cutover); fp-server-test disposal pending
- [x] Verify: tree comparison vs SVN HEAD (NPN/MFT/LBM done), protocol-increment commits present
      (done); MSBuild smoke from the git checkout PASSED 2026-08-18 (EXIT=0; fresh git checkouts
      need `-p:RestorePackagesConfig=true` — packages.config projects expect solution-local
      packages/ that SVN WCs carry unversioned); KNW/IMV/MI full file-list sweeps vs SVN HEAD
      completed 2026-09-17 (0 diff each)
- [ ] Cutover: branch protection + ff-only config per the published flow, open for the team; SVN
      read-only for converted branches

## Milestones (log)
- 2026-08-15: Task opened (ticket created same day). First audit probes via GitLab API:
  fp-server tree is genuinely connected — real merge-bases at branch points (LBM/MFT20260209
  fork authored 2026-02-09; trunk fork 2018); author dates historical; committer dates = import
  dates; no git-svn-id trailers. push_rule API 404 — push rules unavailable on the instance.
  (An earlier "SVN unreachable / VPN" claim was a wrong hostname on our side: .org vs .com.)
  Branch inventory: [artifacts/fp-server-branch-inventory.md](artifacts/fp-server-branch-inventory.md).
- 2026-08-15: SVN-side audit inputs (host fine at svn.fishingplanet.com, HEAD r16426): archive/
  branches are all present in the conversion; git branches absent from both branches/ and
  archive/ correspond to SVN-deleted ones — the first conversion recovered them from history.
  Live branches/: IMV20250220, KNW20250723, LBM20251201, MFT20260325, NPN20260602, and
  MI20200128 (Retail-era, still live — clarify its fate). LBM git tip 50902cbe = LBM@r15989
  (2026-04-08). Bare clone of fp-server started for blob/packages audit.
- 2026-08-15: Fidelity verdict on the first conversion. Clean: file lists match SVN 1:1 outside
  `.svn/`; sentinel `SharedConsts.cs` (git LBM tip vs SVN LBM@15989) byte-identical; no LFS need
  (pack 265 MiB, largest blob ~11 MB); packages/ not versioned. Dirty: the 2026-04-08 LBM tail
  sync committed a working copy with `.svn/` (8224 files; first contaminated commit 90018fac7,
  KNW and all other tips clean) — tail must be cut and reconverted; one missed case-rename
  (`PlayerDEsc.cs` -> `PlayerDesc.cs`), symptom of a Windows-WC-based sync method. Working clone
  created at `D:/FishingPlanet/src/server/git/fp-server` (origin -> GitLab); audit bare clone in
  session scratchpad.
- 2026-08-15: User decisions recorded (see Design decisions): reuse+surgery confirmed; full
  rewrite with SVN committer dates + git-svn-id trailers; trunk/master policy; MI included; old
  GitLab project to be replaced by a fresh upload. Additional probes: `.svn` contamination spans
  only the LBM tail commits across ALL branches (confirmed globally); junk files
  (Thumbs.db/.suo/.user) appear in old history — likely committed to SVN historically, classify
  before treating as conversion defects; MI20200128 dormant in SVN since r11914 (2024-04,
  pre-base-run) — tail sync likely unnecessary, verify tip. vegasrc/fp-server on GitHub
  identified as the earlier 2025-11 conversion run (same tree, older) — cross-check reference
  only; other vegasrc repos out of scope per user.
- 2026-08-15: rev<->commit mapping BUILT — every git commit matched to an SVN revision, zero
  unmatched/ambiguous (43 date-only fallbacks, all safe). Unmatched SVN revs: 437 = unsynced
  tail (>r15989), 273 = branch administration; a small content-looking subset flagged for
  targeted `svn log -v` verification. Report:
  [artifacts/rev-mapping-report.md](artifacts/rev-mapping-report.md); matcher:
  [artifacts/match-svn-git.js](artifacts/match-svn-git.js). The 100% match doubles as a
  completeness proof for the covered branches.
- 2026-08-16: Branch genealogy BUILT from SVN copyfrom data (verbose logs of all branch-admin
  revisions) — [artifacts/branch-genealogy.md](artifacts/branch-genealogy.md), builder
  [artifacts/build-genealogy.js](artifacts/build-genealogy.js). Names total: 82 (Confluence
  Branch History covers 32). Confluence table fully CONFIRMED (its "Base Rev." = branch creation
  rev; zero real mismatches) — accurate but incomplete. Discoveries: trunk archived+restored at
  r3824 (2018); MI20200128 re-created three times incl. restore-from-archive r8843; conversion
  LOSSES found — deleted SVN branches absent from git: CS20210519, GC.Proto, GCP20230523 (+ the
  unrepresentable "MultiRods20180406 (to delete)") — decide recover-vs-accept; several
  unattached births to pin down individually.
- 2026-08-16: Owning-path derivation DONE ([artifacts/derive-owners.js](artifacts/derive-owners.js)):
  every commit assigned its SVN path (68 paths; /trunk count equals master's commit count —
  sanity). Spot-verified against SVN changed paths — all samples correct, and one uncovered an
  era nuance: pre-r2975 history lived at the repo ROOT (r2973/r2974 created /branches and /trunk,
  r2975 moved the root in) — trailer builder maps trunk-owned revs <= 2974 to the root path.
  `archive/<name>` ref-prefix decision recorded for all non-live branches. Outputs (owners.tsv,
  mapping.tsv) live in session scratchpad — regenerable by the scripts.
- 2026-08-16: REWRITE PASS BUILT AND VERIFIED ([artifacts/rewrite-history.js](artifacts/rewrite-history.js)):
  fast-export -> transform -> fast-import; committer := author everywhere (svn2git import
  identity erased), git-svn-id trailers on all commits (root-era <=r2974 without /trunk), lost
  SVN r5292 case-rename reconstructed as a real commit (Ivan Malyshev, 2018-12-11) with
  descendants rewired, later case-folded filechanges fixed. Verification: 15730 commits
  (15729+1); untouched-lineage trees byte-identical; LBM/MFT tip diff vs original = exactly one
  rename `PlayerDEsc.cs => PlayerDesc.cs | 0`. ROOT CAUSE FOUND for both our no-op AND the
  original conversion's loss of r5292: Git-for-Windows fast-import case-folds tree ops under
  `core.ignorecase=true` (silent, exit 0) — target repo must set it to false (memory note
  git-fastimport-ignorecase). Rewritten repo: scratchpad/fp-server-rewritten.git. NOTE: the
  contaminated LBM tail is still present in the rewritten history — the surgery happens in the
  tail-conversion step.
- 2026-08-16: Lost-branch recovery (user verdict: recover everything hanging; creation-with-files
  becomes the branch's first commit). Facts: CS20210519 and GC.Proto were born as EMPTY dirs
  (VisualSVN Server web-UI) with files added in following revs; GC.Proto was renamed to
  GCP20230523 at r10378 (one branch, recovered under the final name). CS20210519 RECOVERED via
  git-svn (birth commit "Created folder" kept — faithful) and transplanted into the rewritten
  repo; GCP20230523 RECOVERED and transplanted too (46 commits, GC.Proto era included via
  copy-follow; the rewritten repo now holds 78 branch refs). "MultiRods20180406 (to delete)" turned out to be a botched
  `svn cp` artifact (r3822 empty branch, r3823 trunk copied INTO it as a nested subfolder, r3824
  renamed to "(to delete)", r3825 real branch re-created) — zero own commits, recommended SKIP
  (recorded in genealogy instead). Tooling notes: git-svn auth needs the CLI svn auth cache
  copied from %APPDATA%/Subversion to ~/.subversion; authors.txt auto-generated from the
  svn-git correlation (21 entries + VisualSVN Server); core.longpaths=true required for git-svn
  worktrees (TargetedAdsPlanningTool paths exceed 260 chars).
- 2026-09-03: Git for Windows auto-updated to 2.55, which drops git-svn entirely — sync restored
  by bundling Portable Git 2.50.1 under `svn-sync/portable-git-2.50/` and routing the `git svn`
  calls through it. Local layout finalized (user call): bare `fp-server-rewritten.git` ->
  `fp-server.git`, viewing WC `fp-server-new` -> `fp-server`, Kondratenko's clone ->
  `fp-server-kondratenko` (origin repointed at fp-server-old-conversion to prevent accidental
  mixing); scripts repointed and the whole chain verified end-to-end.
- 2026-09-07: GitLab auth rot: the keyring OAuth token expired (pushes dead since ~09-04,
  invisible while nothing needed pushing). Re-authed with a long-lived PAT; git credential
  helper for the host switched to `glab auth git-credential` — one credential, no separate rot.
  `sync-tails.js` push made unconditional so a failed push cannot be skipped by a later quiet
  run.
- 2026-09-09: First real merge caravan carried: MFT r16246,16267 cherry-picked to IMV (r16519 +
  r16520 revert of stray debug settings), merged up IMV->KNW->LBM->MFT->NPN (r16522..16525).
  One sync run picked up all five branches, gates passed, pushed. SVN merges become plain linear
  commits with the TortoiseSVN matryoshka message + git-svn-id — no git merge edges pre-cutover,
  by design.
- 2026-09-17: Sync confirmed self-service (the user runs `node sync-tails.js` + `git pull`
  routinely; the week's drift carried by his runs). Diff drivers enabled locally in the WC
  (`.git/info/attributes`: csharp/java/css/html/markdown) so hunk headers name the enclosing
  method; versioned seeding = first post-cutover commit (attributes act retroactively; no
  built-in drivers exist for sql/js/ts). KNW/IMV/MI full file-list sweeps vs SVN HEAD: 0 diff
  each. Task folder committed to KB for the first time.
