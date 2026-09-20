// FINAL metadata pass: embed .gitattributes + .gitignore into every commit tree, and .gitkeep
// files per the verified empty-dir timeline (keeps-timeline.tsv, keyed by current hashes).
// Rebuilds every commit via a temp index; remaps parents; moves all refs. Prints verification.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const dir = __dirname;
const REPO = 'D:/FishingPlanet/src/server/git/fp-server-rewritten.git';
const TMPIDX = path.join(dir, 'rewrite-metadata.index');

function git(args, opts) {
  return execFileSync('git', ['-C', REPO, ...args],
    Object.assign({ maxBuffer: 1 << 28 }, opts)).toString();
}
const IDXENV = Object.assign({}, process.env, { GIT_INDEX_FILE: TMPIDX });

const ATTRS = [
  '# No end-of-line normalization: files stay byte-exact as committed.',
  '# The codebase is CRLF per .editorconfig; history was imported from SVN as-is.',
  '* -text',
  '',
].join('\n');
const IGNORE = [
  '# IDE',
  '.vs/',
  '.idea/',
  '*.user',
  '*.suo',
  '_ReSharper*/',
  '.sonarqube/',
  '',
  '# Build outputs (environment deploy configs under Config/**/bin/ stay tracked)',
  '**/[Bb]in/**',
  '!**/Config/**/[Bb]in/**',
  '**/[Oo]bj/**',
  'TestResults/',
  '',
  '# NuGet (solution-local; restore needs -p:RestorePackagesConfig=true)',
  '**/packages/**',
  '',
  '# Node (WebAdmin component islands)',
  '**/node_modules/**',
  '',
  '# OS junk',
  'Thumbs.db',
  'Desktop.ini',
  '',
].join('\n');

const attrBlob = git(['hash-object', '-w', '--stdin'], { input: ATTRS }).trim();
const ignoreBlob = git(['hash-object', '-w', '--stdin'], { input: IGNORE }).trim();
const emptyBlob = git(['hash-object', '-w', '--stdin'], { input: '' }).trim();
console.log('blobs:', attrBlob.slice(0, 8), ignoreBlob.slice(0, 8), emptyBlob.slice(0, 8));

// keeps per current hash
const keepsByHash = new Map();
for (const line of fs.readFileSync(path.join(dir, 'keeps-timeline.tsv'), 'utf8').split('\n')) {
  if (!line) continue;
  const [, , hash, dirsCsv] = line.split('\t');
  keepsByHash.set(hash, dirsCsv.split(','));
}
console.log('commits with keeps:', keepsByHash.size);

// full graph, children after parents
const lines = git(['rev-list', '--all', '--parents', '--topo-order', '--reverse'])
  .split(/\r?\n/).filter(Boolean);
const map = new Map(); // old -> new
const treeMemo = new Map(); // oldTree + keepsKey -> newTree
let done = 0;
for (const l of lines) {
  const ids = l.split(' ');
  const old = ids[0];
  const parents = ids.slice(1);
  const raw = git(['cat-file', 'commit', old]);
  const tree = raw.match(/^tree ([0-9a-f]{40})/m)[1];
  const am = raw.match(/^author (.*) <(.*)> (\d+ [+-]\d{4})$/m);
  const cm = raw.match(/^committer (.*) <(.*)> (\d+ [+-]\d{4})$/m);
  const msg = raw.slice(raw.indexOf('\n\n') + 2);
  const keeps = keepsByHash.get(old) || [];
  const memoKey = tree + '|' + keeps.join(',');
  let newTree = treeMemo.get(memoKey);
  if (!newTree) {
    execFileSync('git', ['-C', REPO, 'read-tree', tree], { env: IDXENV });
    const infos = [
      `100644,${attrBlob},.gitattributes`,
      `100644,${ignoreBlob},.gitignore`,
      ...keeps.map(k => `100644,${emptyBlob},${k}/.gitkeep`),
    ];
    execFileSync('git', ['-C', REPO, 'update-index', '--add',
      ...infos.flatMap(i => ['--cacheinfo', i])], { env: IDXENV });
    newTree = execFileSync('git', ['-C', REPO, 'write-tree'], { env: IDXENV }).toString().trim();
    treeMemo.set(memoKey, newTree);
  }
  const env = Object.assign({}, process.env, {
    GIT_AUTHOR_NAME: am[1], GIT_AUTHOR_EMAIL: am[2], GIT_AUTHOR_DATE: am[3],
    GIT_COMMITTER_NAME: cm[1], GIT_COMMITTER_EMAIL: cm[2], GIT_COMMITTER_DATE: cm[3],
  });
  const pArgs = parents.flatMap(p => ['-p', map.get(p) || p]);
  const nw = execFileSync('git', ['-C', REPO, 'commit-tree', newTree, ...pArgs],
    { input: msg, env, maxBuffer: 1 << 20 }).toString().trim();
  map.set(old, nw);
  if (++done % 2000 === 0) console.log('  ...', done, 'commits');
}
console.log('rebuilt commits:', done, 'tree variants:', treeMemo.size);

// move refs
const refs = git(['for-each-ref', '--format=%(refname) %(objectname)', 'refs/heads'])
  .split(/\r?\n/).filter(Boolean);
let moved = 0;
for (const r of refs) {
  const [ref, sha] = r.split(' ');
  const nw = map.get(sha);
  if (!nw) { console.error('REF NOT MAPPED:', ref); continue; }
  git(['update-ref', ref, nw]);
  moved++;
}
console.log('refs moved:', moved);
fs.writeFileSync(path.join(dir, 'metadata-pass-map.tsv'),
  [...map.entries()].map(e => e.join('\t')).join('\n') + '\n');
try { fs.unlinkSync(TMPIDX); } catch {}

// verification
console.log('=== VERIFY ===');
console.log('total commits now:', git(['rev-list', '--all', '--count']).trim());
const rootEra = git(['log', 'archive/trunk', '--reverse', '--format=%H']).split(/\r?\n/)[0];
console.log('r1 tree sample:');
console.log(git(['ls-tree', '--name-only', rootEra]).split(/\r?\n/).filter(x => x.startsWith('.git')).join(' '));
console.log('r1 CounterPublisher keep:', git(['ls-tree', rootEra, '--', 'Photon/deploy/CounterPublisher/.gitkeep']).trim() ? 'PRESENT' : 'MISSING');
const npnMeta = git(['ls-tree', 'NPN20260602', '--name-only']).split(/\r?\n/).filter(x => x.startsWith('.git'));
console.log('NPN tip meta files:', npnMeta.join(' '));
console.log('NPN tip keeps count:', git(['ls-tree', '-r', 'NPN20260602', '--name-only'])
  .split(/\r?\n/).filter(x => x.endsWith('.gitkeep')).length);
