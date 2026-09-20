// Derive the owning SVN path for every git commit (for git-svn-id trailers).
// Rule: owner = the branch with the LATEST birth rev <= commit's SVN rev among branches
// containing the commit. master maps to /trunk (birth rev 1).
// Inputs: svn-admin-revs.xml (births), mapping.tsv (hash -> rev), bare repo.
// Outputs: owners.tsv (hash, rev, svnPath); stats to stdout.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const dir = __dirname;
const repo = path.join(dir, 'fp-server.git');

// births from admin revs
const xml = fs.readFileSync(path.join(dir, 'svn-admin-revs.xml'), 'utf8');
const births = new Map(); // branch -> earliest create rev into /branches
const entryRe = /<logentry\s+revision="(\d+)">([\s\S]*?)<\/logentry>/g;
const pathRe = /<path([^>]*)>([^<]+)<\/path>/g;
let m;
while ((m = entryRe.exec(xml)) !== null) {
  const rev = +m[1];
  let p;
  while ((p = pathRe.exec(m[2])) !== null) {
    const tm = p[2].match(/^\/branches\/([^/]+)$/);
    if (!tm) continue;
    if (!/action="A"/.test(p[1])) continue;
    const b = tm[1];
    if (!births.has(b) || births.get(b) > rev) births.set(b, rev);
  }
}

// mapping hash -> rev
const revOf = new Map();
for (const line of fs.readFileSync(path.join(dir, 'mapping.tsv'), 'utf8').split('\n')) {
  if (!line) continue;
  const [hash, rev] = line.split('\t');
  revOf.set(hash, +rev);
}

// branch list from repo
const branches = execFileSync('git', ['-C', repo, 'for-each-ref', '--format=%(refname:short)', 'refs/heads'],
  { maxBuffer: 1 << 24 }).toString().split(/\r?\n/).filter(Boolean);

const owner = new Map();       // hash -> {branch, birth}
for (const b of branches) {
  const birth = b === 'master' ? 1 : (births.get(b) || 0);
  const svnPath = b === 'master' ? '/trunk' : '/branches/' + b;
  const list = execFileSync('git', ['-C', repo, 'rev-list', b],
    { maxBuffer: 1 << 26 }).toString().split(/\r?\n/).filter(Boolean);
  for (const h of list) {
    const rev = revOf.get(h);
    if (rev === undefined) continue;
    if (birth > rev) continue;                    // branch born after the commit: inherited, not owner
    const cur = owner.get(h);
    if (!cur || birth > cur.birth) owner.set(h, { branch: b, birth, svnPath });
  }
}

const rows = [];
const unowned = [];
for (const [h, rev] of revOf) {
  const o = owner.get(h);
  if (o) rows.push([h, rev, o.svnPath]); else unowned.push([h, rev]);
}
fs.writeFileSync(path.join(dir, 'owners.tsv'), rows.map(r => r.join('\t')).join('\n') + '\n');
fs.writeFileSync(path.join(dir, 'owners-unowned.tsv'), unowned.map(r => r.join('\t')).join('\n') + '\n');

const byPath = new Map();
for (const r of rows) byPath.set(r[2], (byPath.get(r[2]) || 0) + 1);
const top = [...byPath.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12);
console.log('owned:', rows.length, 'unowned:', unowned.length, 'paths:', byPath.size);
for (const [p, n] of top) console.log('  ', p, n);
