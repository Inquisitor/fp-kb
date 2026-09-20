// Build the empty-directory timeline for every commit of fp-server-rewritten.git.
// Empty dir at commit C(ownerPath, rev) = dir existing in SVN under ownerPath at rev,
// but absent from C's git tree (git cannot represent dirs without files).
// Inputs: svn-log-full-v.xml (all revs, changed paths with kind=), the rewritten repo.
// Output: keeps-timeline.tsv  (ownerPath \t rev \t hash \t comma-separated empty dirs)
//         only rows with a non-empty set are written. Stats + NPN-tip self-check to stdout.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const dir = __dirname;
const REPO = 'D:/FishingPlanet/src/server/git/fp-server-rewritten.git';

// --- 1. commits of the rewritten repo, keyed by (svnPath, rev) from their git-svn-id trailer ---
const logRaw = execFileSync('git', ['-C', REPO, 'log', '--all', '-z', '--format=%H%x09%B'],
  { maxBuffer: 1 << 28 }).toString('utf8');
const commits = []; // {hash, svnPath ('' for root era), rev}
for (const rec of logRaw.split('\0')) {
  if (!rec.trim()) continue;
  const tab = rec.indexOf('\t');
  const hash = rec.slice(0, tab).trim();
  const body = rec.slice(tab + 1);
  const ms = [...body.matchAll(/git-svn-id: https:\/\/svn\.fishingplanet\.com\/svn\/SRV([^\s@]*)@(\d+) /g)];
  if (ms.length === 0) continue; // non-SVN commits (none expected yet)
  const m = ms[ms.length - 1];
  commits.push({ hash, svnPath: m[1].replace(/^\//, ''), rev: +m[2] });
}
const byRev = new Map(); // rev -> [commit]
for (const c of commits) { if (!byRev.has(c.rev)) byRev.set(c.rev, []); byRev.get(c.rev).push(c); }
console.log('commits with trailers:', commits.length);

// --- 2. parse dir events from the verbose log ---
const xml = fs.readFileSync(path.join(dir, 'svn-log-full-v.xml'), 'utf8');
const events = []; // {rev, action, kind, path, cfPath, cfRev} — dirs only + all copy events
const entryRe = /<logentry\s+revision="(\d+)">([\s\S]*?)<\/logentry>/g;
const pathRe = /<path([^>]*)>([^<]+)<\/path>/g;
let m;
let maxRev = 0;
const eventsByRev = new Map();
while ((m = entryRe.exec(xml)) !== null) {
  const rev = +m[1];
  maxRev = Math.max(maxRev, rev);
  const list = [];
  let p;
  while ((p = pathRe.exec(m[2])) !== null) {
    const attrs = p[1];
    const kind = (attrs.match(/kind="(\w+)"/) || [])[1] || '';
    const action = (attrs.match(/action="(\w)"/) || [])[1];
    const cfPath = (attrs.match(/copyfrom-path="([^"]+)"/) || [])[1] || null;
    const cfRev = +((attrs.match(/copyfrom-rev="(\d+)"/) || [])[1] || 0) || null;
    // file events matter too: SVN merges can materialize parent dirs implicitly
    if (kind !== 'dir' && !(kind === 'file' && (action === 'A' || action === 'R'))) continue;
    list.push({ action, kind, path: p[2].replace(/^\//, ''), cfPath: cfPath ? cfPath.replace(/^\//, '') : null, cfRev });
  }
  if (list.length) eventsByRev.set(rev, list);
}
console.log('revs with dir events:', eventsByRev.size, 'maxRev:', maxRev);

// --- 3. simulate the global dir set, with replay support for copyfrom snapshots ---
// history: append-only [{rev, adds:[], dels:[]}] enabling "dirs under prefix at rev R"
const history = [];
const current = new Set();
function dirsUnderAt(prefix, rev) {
  // replay the recorded op sequence verbatim (order matters on replace/move revisions)
  const s = new Set();
  for (const h of history) {
    if (h.rev > rev) break;
    for (const op of h.ops) {
      if (op.del !== undefined) {
        for (const x of [...s]) if (x === op.del || x.startsWith(op.del + '/')) s.delete(x);
      } else {
        const a = op.add;
        if (a === prefix || a.startsWith(prefix + '/') || prefix === '') s.add(a);
      }
    }
  }
  return s;
}
const out = fs.createWriteStream(path.join(dir, 'keeps-timeline.tsv'));
let rowsWritten = 0, treeCalls = 0;
const ROOT_EXCLUDE = ['branches', 'archive', 'trunk', 'tags'];

for (let rev = 1; rev <= maxRev; rev++) {
  const evs = eventsByRev.get(rev);
  if (evs) {
    const ops = [];
    const addDir = (d) => { ops.push({ add: d }); current.add(d); };
    const delDir = (d) => {
      ops.push({ del: d });
      for (const x of [...current]) if (x === d || x.startsWith(d + '/')) current.delete(x);
    };
    const addAncestors = (p) => {
      const parts = p.split('/');
      for (let k = 1; k < parts.length; k++) {
        const anc = parts.slice(0, k).join('/');
        if (!current.has(anc)) addDir(anc);
      }
    };
    for (const e of evs) {
      if (e.kind === 'dir' && (e.action === 'D' || e.action === 'R')) delDir(e.path);
      if (e.action === 'A' || e.action === 'R') {
        addAncestors(e.path); // merges materialize parents implicitly
        if (e.kind === 'dir') {
          addDir(e.path);
          if (e.cfPath) {
            // dir copy: bring implicit subdirs of the source at cfRev
            const src = dirsUnderAt(e.cfPath, e.cfRev);
            for (const s of src) {
              if (s === e.cfPath) continue;
              addDir(e.path + s.slice(e.cfPath.length));
            }
          }
        }
      }
    }
    history.push({ rev, ops });
  }
  const cs = byRev.get(rev);
  if (!cs) continue;
  for (const c of cs) {
    // svn dirs under the owner prefix (relative)
    let rel = [];
    if (c.svnPath === '') {
      for (const d of current) {
        const top = d.split('/')[0];
        if (!ROOT_EXCLUDE.includes(top)) rel.push(d);
      }
    } else {
      const pref = c.svnPath + '/';
      for (const d of current) if (d.startsWith(pref)) rel.push(d.slice(pref.length));
    }
    if (rel.length === 0) continue;
    // git dirs of the commit tree
    treeCalls++;
    const gitDirs = new Set(execFileSync('git', ['-C', REPO, 'ls-tree', '-r', '-d', '--name-only', c.hash],
      { maxBuffer: 1 << 26 }).toString('utf8').split(/\r?\n/).filter(Boolean));
    let empty = rel.filter(d => !gitDirs.has(d));
    empty = empty.filter(d => !empty.some(o => o !== d && o.startsWith(d + '/'))); // leaves only
    if (empty.length) {
      out.write(c.svnPath + '\t' + c.rev + '\t' + c.hash + '\t' + empty.sort().join(',') + '\n');
      rowsWritten++;
    }
  }
  if (rev % 2000 === 0) console.log('  ...rev', rev, 'rows so far', rowsWritten);
}
out.end();
console.log('rows written:', rowsWritten, 'tree calls:', treeCalls);

// --- self-check: NPN tip empty set vs the independent svn ls -R sweep ---
const npnTip = commits.filter(c => c.svnPath === 'branches/NPN20260602').sort((a, b) => b.rev - a.rev)[0];
const sweep = fs.readFileSync(path.join(dir, 'lsdirs-NPN20260602.txt'), 'utf8').split(/\r?\n/).filter(Boolean);
const sweepDirs = sweep.filter(l => l.endsWith('/'));
const sweepEmpty = sweepDirs.filter(d => !sweep.some(l => l !== d && l.startsWith(d))).map(d => d.replace(/\/$/, '')).sort();
const rel2 = [];
const pref2 = 'branches/NPN20260602/';
for (const d of current) if (d.startsWith(pref2)) rel2.push(d.slice(pref2.length));
const gitDirsTip = new Set(execFileSync('git', ['-C', REPO, 'ls-tree', '-r', '-d', '--name-only', npnTip.hash],
  { maxBuffer: 1 << 26 }).toString('utf8').split(/\r?\n/).filter(Boolean));
let simEmpty = rel2.filter(d => !gitDirsTip.has(d));
simEmpty = simEmpty.filter(d => !simEmpty.some(o => o !== d && o.startsWith(d + '/'))).sort();
console.log('SELF-CHECK NPN tip @' + npnTip.rev);
console.log('  sim  :', simEmpty.length, 'dirs');
console.log('  sweep:', sweepEmpty.length, 'dirs');
console.log('  match:', JSON.stringify(simEmpty) === JSON.stringify(sweepEmpty) ? 'EXACT' : 'DIFF');
if (JSON.stringify(simEmpty) !== JSON.stringify(sweepEmpty)) {
  console.log('  sim-only  :', simEmpty.filter(x => !sweepEmpty.includes(x)).slice(0, 10).join(', '));
  console.log('  sweep-only:', sweepEmpty.filter(x => !simEmpty.includes(x)).slice(0, 10).join(', '));
}
