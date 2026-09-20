// Grouped .gitkeep report: one section per DIRECTORY; inheritance collapsed, only real events shown.
// Output: keeps-transitions-report.md (grouped v3)
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const dir = __dirname;
const REPO = 'D:/FishingPlanet/src/server/git/fp-server-rewritten.git';
const LIVE = new Set(['branches/NPN20260602', 'branches/MFT20260325', 'branches/LBM20251201',
  'branches/KNW20250723', 'branches/IMV20250220', 'branches/MI20200128']);

const dateByRev = new Map();
{
  const xml = fs.readFileSync(path.join(dir, 'svn-log-all.xml'), 'utf8');
  const re = /<logentry\s+revision="(\d+)">[\s\S]*?<date>([\s\S]*?)<\/date>/g;
  let m; while ((m = re.exec(xml)) !== null) dateByRev.set(+m[1], m[2].slice(0, 10));
}

// chains + hashes
const logRaw = execFileSync('git', ['-C', REPO, 'log', '--all', '-z', '--format=%H%x09%B'],
  { maxBuffer: 1 << 28 }).toString('utf8');
const chains = new Map();      // svnPath -> sorted [rev]
const hashByPathRev = new Map(); // svnPath#rev -> hash
for (const rec of logRaw.split('\0')) {
  if (!rec.trim()) continue;
  const tab = rec.indexOf('\t');
  const hash = rec.slice(0, tab).trim();
  const body = rec.slice(tab + 1);
  const ms = [...body.matchAll(/git-svn-id: https:\/\/svn\.fishingplanet\.com\/svn\/SRV([^\s@]*)@(\d+) /g)];
  if (!ms.length) continue;
  const m = ms[ms.length - 1];
  const p = m[1].replace(/^\//, '');
  if (!chains.has(p)) chains.set(p, []);
  chains.get(p).push(+m[2]);
  hashByPathRev.set(p + '#' + m[2], hash);
}
for (const arr of chains.values()) arr.sort((a, b) => a - b);

// timeline
const setsByPathRev = new Map();
for (const line of fs.readFileSync(path.join(dir, 'keeps-timeline.tsv'), 'utf8').split('\n')) {
  if (!line) continue;
  const [p, rev, , dirsCsv] = line.split('\t');
  if (!setsByPathRev.has(p)) setsByPathRev.set(p, new Map());
  setsByPathRev.get(p).set(+rev, new Set(dirsCsv.split(',')));
}

// intervals per (path, dir)
const perDir = new Map(); // dir -> {births:[], ends:[], liveTips:[], archTips:0, segments:0}
for (const [p, revs] of chains) {
  const sets = setsByPathRev.get(p) || new Map();
  const open = new Map();
  let prev = new Set();
  const firstRev = revs[0];
  const record = (d) => { if (!perDir.has(d)) perDir.set(d, { births: [], ends: [], liveTips: [], archTips: 0, segs: 0 }); return perDir.get(d); };
  for (const rev of revs) {
    const cur = sets.get(rev) || new Set();
    for (const d of cur) if (!prev.has(d)) open.set(d, rev);
    for (const d of prev) if (!cur.has(d)) {
      const e = record(d);
      e.ends.push({ p, rev });
      open.delete(d);
    }
    prev = cur;
  }
  for (const [d, from] of open) {
    const e = record(d);
    e.segs++;
    if (LIVE.has(p)) e.liveTips.push(p.replace('branches/', ''));
    else e.archTips++;
  }
  // genuine births: interval starting AFTER the segment's first commit, or the root era's very beginning
  for (const [p2, revsUnused] of [[p, revs]]) {} // noop
  // re-walk to capture births
  prev = new Set(); const seen = new Set();
  for (const rev of revs) {
    const cur = sets.get(rev) || new Set();
    for (const d of cur) if (!prev.has(d) && !seen.has(d)) {
      seen.add(d);
      if (rev !== firstRev || p === '') record(d).births.push({ p, rev });
    }
    prev = cur;
  }
}

// classify ends: filled (dir present in git tree of ending commit) vs deleted
function endKind(p, rev, d) {
  const hash = hashByPathRev.get(p + '#' + rev);
  if (!hash) return '?';
  try {
    const outp = execFileSync('git', ['-C', REPO, 'ls-tree', '-d', hash, '--', d], { maxBuffer: 1 << 20 }).toString().trim();
    return outp ? 'filled' : 'deleted';
  } catch { return '?'; }
}

const out = [];
out.push('# .gitkeep transitions report (grouped by directory)');
out.push('');
out.push('One section per directory. Inheritance across branch copies is collapsed - only real events');
out.push('are listed: when the directory became empty (created empty / emptied), and where the emptiness');
out.push('ENDED ("filled" = first file arrived; "deleted" = the directory was removed). "Empty at tips"');
out.push('names the live branches whose current state still carries the .gitkeep (+ count of archived');
out.push('branches frozen with it).');
out.push('');
const dirsSorted = [...perDir.keys()].sort();
let events = 0;
for (const d of dirsSorted) {
  const e = perDir.get(d);
  out.push('## `' + d + '`');
  out.push('');
  for (const b of e.births.sort((a, b2) => a.rev - b2.rev)) {
    const seg = b.p === '' ? 'repo root' : b.p;
    out.push('- empty since r' + b.rev + ' (' + (dateByRev.get(b.rev) || '?') + ', ' + seg + ')');
    events++;
  }
  for (const en of e.ends.sort((a, b2) => a.rev - b2.rev)) {
    const seg = en.p === '' ? 'repo root' : en.p;
    out.push('- ' + endKind(en.p, en.rev, d) + ' r' + en.rev + ' (' + (dateByRev.get(en.rev) || '?') + ', ' + seg + ')');
    events++;
  }
  const tips = [];
  if (e.liveTips.length) tips.push(e.liveTips.sort().join(', '));
  if (e.archTips) tips.push('+' + e.archTips + ' archived');
  if (tips.length) out.push('- empty at tips: ' + tips.join('  '));
  else out.push('- not empty anywhere today');
  out.push('');
}
out.push('---');
out.push('Directories: ' + dirsSorted.length + '. Event lines: ' + events + '.');
fs.writeFileSync(path.join(dir, 'keeps-transitions-report.md'), out.join('\n') + '\n');
console.log('grouped report written; dirs:', dirsSorted.length, 'events:', events);
