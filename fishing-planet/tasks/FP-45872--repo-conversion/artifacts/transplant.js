// Transplant a linear git-svn-fetched tail into fp-server.git with corrected parentage.
// Usage: node transplant.js <sideRepo> <targetRef> <graftSha> <keep-root|drop-root> [maxRootDiff]
// Mechanics: fetch side history into the target repo (objects+tmp ref), then rebuild the chain
// with git commit-tree reusing the side trees verbatim; author/committer/message copied exactly.
// Gate: diffstat(file count) of the first kept commit's tree vs the graft parent must not exceed
// maxRootDiff (default 400) — guards against snapshot/parent mismatch.
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const dir = __dirname;
const TARGET = 'D:/FishingPlanet/src/server/git/fp-server.git'; // canonical since 2026-08-18 (renamed from fp-server-rewritten.git 2026-09-03)

const [sideRepo, targetRef, graftSha, mode, maxRootDiffArg, sinceRevArg] = process.argv.slice(2);
if (!sideRepo || !targetRef || !graftSha || !['keep-root', 'drop-root'].includes(mode)) {
  console.error('args: <sideRepo> <targetRef> <graftSha> <keep-root|drop-root> [maxRootDiff] [sinceRev]');
  process.exit(2);
}
const maxRootDiff = +(maxRootDiffArg || 400);
const sinceRev = +(sinceRevArg || 0); // skip chain commits whose git-svn-id rev <= sinceRev (catch-up mode)
function git(repo, args, input) {
  return execFileSync('git', ['-C', repo, ...args], { maxBuffer: 1 << 28, input }).toString();
}

const tmpRef = 'refs/tmp/transplant';
git(TARGET, ['fetch', '--quiet', path.resolve(dir, sideRepo), '+refs/remotes/git-svn:' + tmpRef]);

let chain = git(TARGET, ['rev-list', '--reverse', '--first-parent', tmpRef]).split(/\r?\n/).filter(Boolean);
if (mode === 'drop-root') {
  const dropped = chain.shift();
  console.log('dropped creation root:', dropped, git(TARGET, ['log', '-1', '--format=%s', dropped]).trim().slice(0, 80));
}
if (sinceRev > 0) {
  const before = chain.length;
  chain = chain.filter(c => {
    const m = git(TARGET, ['log', '-1', '--format=%B', c]).match(/git-svn-id: [^@]+@(\d+) /);
    return m && +m[1] > sinceRev;
  });
  console.log('catch-up mode: kept', chain.length, 'of', before, 'commits (rev >', sinceRev + ')');
}
if (chain.length === 0) { console.error('empty chain'); process.exit(1); }

// Gate: first kept commit tree vs graft parent
const firstTree = git(TARGET, ['rev-parse', chain[0] + '^{tree}']).trim();
const diffFiles = git(TARGET, ['diff-tree', '-r', '--name-only', graftSha, firstTree]).split(/\r?\n/).filter(Boolean);
console.log('root-graft diff files:', diffFiles.length, '(gate <=', maxRootDiff + ')');
if (diffFiles.length > maxRootDiff) {
  console.error('GATE FAILED: first commit tree differs from graft parent by ' + diffFiles.length + ' files. Sample:');
  console.error(diffFiles.slice(0, 15).join('\n'));
  git(TARGET, ['update-ref', '-d', tmpRef]);
  process.exit(1);
}

// Metadata carry: .gitattributes/.gitignore blobs and the .gitkeep set from the graft parent
// are overlaid onto every transplanted tree (a keep is dropped once its dir gains files in the
// side tree; brand-new empty dirs are NOT auto-detected - the freeze verification covers that).
function lsBlob(treeish, p) {
  const out = git(TARGET, ['ls-tree', treeish, '--', p]);
  const m = out.match(/blob ([0-9a-f]{40})/);
  return m ? m[1] : null;
}
const attrsBlob = lsBlob(graftSha, '.gitattributes');
const ignoreBlob = lsBlob(graftSha, '.gitignore');
const parentKeeps = git(TARGET, ['ls-tree', '-r', graftSha, '--name-only'])
  .split(/\r?\n/).filter(x => x.endsWith('/.gitkeep')).map(x => x.slice(0, -'/.gitkeep'.length));
const EMPTY_BLOB = 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391';
const TMPIDX = path.join(dir, 'transplant.index');
const IDXENV = Object.assign({}, process.env, { GIT_INDEX_FILE: TMPIDX });
function overlayMeta(sideTree) {
  if (!attrsBlob && !ignoreBlob && parentKeeps.length === 0) return sideTree;
  execFileSync('git', ['-C', TARGET, 'read-tree', sideTree], { env: IDXENV });
  const infos = [];
  if (attrsBlob) infos.push(`100644,${attrsBlob},.gitattributes`);
  if (ignoreBlob) infos.push(`100644,${ignoreBlob},.gitignore`);
  for (const d of parentKeeps) {
    const has = git(TARGET, ['ls-tree', sideTree, '--', d]).trim();
    if (!has) infos.push(`100644,${EMPTY_BLOB},${d}/.gitkeep`);
  }
  if (infos.length) execFileSync('git', ['-C', TARGET, 'update-index', '--add',
    ...infos.flatMap(i => ['--cacheinfo', i])], { env: IDXENV });
  return execFileSync('git', ['-C', TARGET, 'write-tree'], { env: IDXENV }).toString().trim();
}

let parent = graftSha;
let count = 0;
for (const c of chain) {
  const raw = git(TARGET, ['cat-file', 'commit', c]);
  const tree = raw.match(/^tree ([0-9a-f]{40})/m)[1];
  const am = raw.match(/^author (.*) <(.*)> (\d+ [+-]\d{4})$/m);
  const cm = raw.match(/^committer (.*) <(.*)> (\d+ [+-]\d{4})$/m);
  const msg = raw.slice(raw.indexOf('\n\n') + 2);
  const env = Object.assign({}, process.env, {
    GIT_AUTHOR_NAME: am[1], GIT_AUTHOR_EMAIL: am[2], GIT_AUTHOR_DATE: am[3],
    GIT_COMMITTER_NAME: cm[1], GIT_COMMITTER_EMAIL: cm[2], GIT_COMMITTER_DATE: cm[3],
  });
  const finalTree = overlayMeta(tree);
  parent = execFileSync('git', ['-C', TARGET, 'commit-tree', finalTree, '-p', parent],
    { input: msg, env, maxBuffer: 1 << 20 }).toString().trim();
  count++;
}
try { fs.unlinkSync(TMPIDX); } catch {}
git(TARGET, ['update-ref', 'refs/heads/' + targetRef, parent]);
git(TARGET, ['update-ref', '-d', tmpRef]);
console.log('transplanted', count, 'commits ->', targetRef, 'tip', parent);
console.log('tip:', git(TARGET, ['log', '-1', '--format=%an %ad | %s', '--date=short', parent]).trim().slice(0, 120));
