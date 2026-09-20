// Build the branch genealogy from svn-admin-revs.xml (verbose logs of admin revisions)
// and compare with the Confluence "Branch History" table. Output: branch-genealogy.md
const fs = require('fs');
const path = require('path');
const dir = __dirname;

const xml = fs.readFileSync(path.join(dir, 'svn-admin-revs.xml'), 'utf8');

// Events per revision
const entryRe = /<logentry\s+revision="(\d+)">([\s\S]*?)<\/logentry>/g;
const pathRe = /<path([^>]*)>([^<]+)<\/path>/g;
const creates = [];  // {branch, container, fromPath, fromRev, rev, date}
const deletes = [];  // {branch, container, rev, date}
let m;
while ((m = entryRe.exec(xml)) !== null) {
  const rev = +m[1];
  const body = m[2];
  const date = ((body.match(/<date>([\s\S]*?)<\/date>/) || [])[1] || '').slice(0, 10);
  let p;
  while ((p = pathRe.exec(body)) !== null) {
    const attrs = p[1];
    const target = p[2];
    const tm = target.match(/^\/(branches|archive)\/([^/]+)$/);
    if (!tm) continue;
    const container = tm[1], branch = tm[2];
    const action = (attrs.match(/action="(\w)"/) || [])[1];
    if (action === 'A') {
      const fromPath = (attrs.match(/copyfrom-path="([^"]+)"/) || [])[1] || null;
      const fromRev = +((attrs.match(/copyfrom-rev="(\d+)"/) || [])[1] || 0) || null;
      creates.push({ branch, container, fromPath, fromRev, rev, date });
    } else if (action === 'D') {
      deletes.push({ branch, container, rev, date });
    }
  }
}

// Current SVN state
const live = new Set(['IMV20250220','KNW20250723','LBM20251201','MFT20260325','NPN20260602','MI20200128']);
const archived = new Set(['CLZ20230216','EGS20230619','FTG20230906','FTG20230906HF','GRM20240409','HFH20241126','HNX20241105','IMV20241106','JLM20250520','MFT20260209','P5M20240214','WebCopy20171026']);

// Git branches (from the conversion inventory)
const gitBranches = fs.readFileSync(path.join(dir, 'fp-server-branch-names.txt'), 'utf8')
  .split(/\r?\n/).filter(Boolean);

// Confluence "Branch History" table (bottom table of Environment and Branch Status, v380)
const confluence = {
  'NPN20260602':  { base: 16131, on: 'MFT20260325' },
  'MFT20260325':  { base: 15943, on: 'LBM20251201' },
  'MFT20260209':  { base: 15770, on: 'LBM20251201' },
  'LBM20251201':  { base: 15396, on: 'KNW20250723' },
  'KNW20250723':  { base: 14593, on: 'JLM20250520' },
  'JLM20250520':  { base: 14174, on: 'IMV20250220' },
  'IMV20250220':  { base: 13733, on: 'HFH20241126' },
  'HFH20241126':  { base: 13260, on: 'IMV20241106' },
  'IMV20241106':  { base: 13159, on: 'GRM20240409' },
  'HNX20241105':  { base: 13158, on: 'GRM20240409' },
  'GRM20240409':  { base: 11916, on: 'FTG20230906' },
  'P5M20240214':  { base: 11663, on: 'FTG20230906' },
  'FTG20230906HF':{ base: 12700, on: 'FTG20230906' },
  'FTG20230906':  { base: 10801, on: 'EGS20230619' },
  'EGS20230619':  { base: 10482, on: 'CLZ20230216' },
  'CLZ20230216':  { base: 9942,  on: 'CLY20220905' },
  'CLY20220905':  { base: 9408,  on: 'CLX20220713' },
  'CLX20220713':  { base: 9231,  on: 'CLU20220510' },
  'CLU20220510':  { base: 9146,  on: 'CLB20211202' },
  'CLB20211202':  { base: 8840,  on: 'MOB20210302' },
  'MOB20210302':  { base: 8376,  on: 'BRA20201214' },
  'BRA20201214':  { base: 8239,  on: 'XMS20201103' },
  'XMS20201103':  { base: 8115,  on: 'TWS20200723' },
  'TWS20200723':  { base: 7931,  on: 'LOT20200302' },
  'LOT20200302':  { base: 7539,  on: 'MI20200128' },
  'MI20200128':   { base: 7446,  on: 'PFL20191122' },
  'PFL20191122':  { base: 7245,  on: 'Ugc20190620' },
  'Ugc20190620':  { base: 6542,  on: 'Retail20190522' },
  'Retail20190522':{ base: 6348, on: 'MotorBoats20190116' },
  'MotorBoats20190116': { base: 5521, on: 'MultiRods20180406' },
  'MultiRods20180406':  { base: 3826, on: 'trunk' },
  'WebCopy20171026':    { base: 3330, on: 'trunk' },
};

// Effective parent edge per branch name: the FIRST create into /branches (branch birth);
// later creates into /archive are moves. Multiple births under the same name are re-creates.
const births = new Map(); // name -> [{fromPath, fromRev, rev, date}]
for (const c of creates.filter(c => c.container === 'branches')) {
  if (!births.has(c.branch)) births.set(c.branch, []);
  births.get(c.branch).push(c);
}
const archMoves = new Map();
for (const c of creates.filter(c => c.container === 'archive')) archMoves.set(c.branch, c);
const branchDeletes = new Map();
for (const d of deletes.filter(d => d.container === 'branches')) {
  if (!branchDeletes.has(d.branch)) branchDeletes.set(d.branch, []);
  branchDeletes.get(d.branch).push(d);
}

function parentOf(name) {
  const bs = births.get(name);
  if (!bs || bs.length === 0) return null;
  const b = bs[bs.length - 1]; // last birth wins (re-created branches)
  if (!b.fromPath) return { parent: '(added, no copyfrom)', fromRev: null, rev: b.rev, date: b.date, births: bs.length };
  const pm = b.fromPath.match(/^\/(?:branches|archive)\/([^/]+)$/) || b.fromPath.match(/^\/(trunk)$/);
  return { parent: pm ? pm[1] : b.fromPath, fromRev: b.fromRev, rev: b.rev, date: b.date, births: bs.length };
}

const inGitSet = new Set(gitBranches);
function statusOf(name) {
  if (live.has(name)) return 'live';
  if (archived.has(name)) return 'archived';
  if (inGitSet.has(name)) return 'deleted, recovered in git';
  return 'deleted, NOT IN GIT';
}

// Build children map over all names seen anywhere
const names = new Set([...gitBranches.filter(n => n !== 'master'), ...births.keys()]);
const children = new Map(); // parent -> [{name, fromRev}]
const noParent = [];
const restored = [];
for (const n of names) {
  let p = parentOf(n);
  if (p && p.parent === n) {
    // self-copy = restore from archive; use the FIRST birth as the genealogical edge
    restored.push(`${n} (restored from archive at r${p.rev})`);
    const bs = births.get(n).filter(b => {
      const pm2 = b.fromPath && b.fromPath.match(/^\/(?:branches|archive)\/([^/]+)$/);
      return !pm2 || pm2[1] !== n;
    });
    if (bs.length > 0) {
      const b = bs[0];
      const pm3 = b.fromPath && (b.fromPath.match(/^\/(?:branches|archive)\/([^/]+)$/) || b.fromPath.match(/^\/(trunk)$/));
      p = { parent: pm3 ? pm3[1] : (b.fromPath || '(none)'), fromRev: b.fromRev, rev: b.rev, date: b.date, births: births.get(n).length };
    } else p = null;
  }
  if (!p) { noParent.push(n); continue; }
  const key = p.parent === 'trunk' ? 'trunk' : p.parent;
  if (key === n) { noParent.push(n); continue; }
  if (!children.has(key)) children.set(key, []);
  children.get(key).push({ name: n, fromRev: p.fromRev || 0, rev: p.rev, date: p.date, births: p.births });
}
for (const arr of children.values()) arr.sort((a, b) => a.fromRev - b.fromRev);

// Render ASCII tree
const lines = [];
const visited = new Set();
function render(name, depth, meta) {
  if (visited.has(name) || depth > 30) { lines.push('  '.repeat(depth) + name + ' [CYCLE-GUARD]'); return; }
  visited.add(name);
  const st = statusOf(name);
  const conf = confluence[name];
  const parent = meta ? meta : null;
  let tag = '';
  if (parent) {
    tag = ` <- @${parent.fromRev} (${parent.date})`;
    if (parent.births > 1) tag += ` [re-created x${parent.births}]`;
  }
  let confTag = '';
  if (conf && parent) {
    const okOn = parent && meta ? true : true;
    // Confluence "Base Rev." records the branch CREATION rev; compare against both create rev and copyfrom rev.
    const okRev = conf.base === parent.rev || Math.abs((parent.fromRev || 0) - conf.base) <= 2;
    confTag = okRev ? ' [=confluence]' : ` [confluence says ${conf.on}@${conf.base}, real: created r${parent.rev} from @${parent.fromRev} MISMATCH]`;
  }
  lines.push('  '.repeat(depth) + name + ` (${st})` + tag + confTag);
  for (const ch of (children.get(name) || [])) render(ch.name, depth + 1, ch);
}
render('trunk', 0, null);

// Orphans / unattached
const attached = new Set(lines.map(l => l.trim().split(' ')[0]));
const orphans = [...names].filter(n => !attached.has(n));

const out = [];
out.push('# Server branch genealogy (from SVN copyfrom data)');
out.push('');
out.push('Built 2026-08-16 by `build-genealogy.js` from verbose SVN logs of all branch-admin revisions.');
out.push('Format: `name (status) <- @copyfrom-rev (creation date)`; `[=confluence]` = matches the');
out.push('Confluence Branch History row; MISMATCH rows show the Confluence claim for comparison.');
out.push('');
out.push('```');
out.push(...lines);
out.push('```');
out.push('');
if (orphans.length) {
  out.push('## Unattached (no birth event found in admin revs — creation rev likely carried file changes too)');
  out.push('');
  for (const o of orphans) out.push(`- ${o} (${statusOf(o)})`);
  out.push('');
}
if (restored.length) {
  out.push('## Restore events (branch re-created from its own archive copy)');
  out.push('');
  for (const r of restored) out.push(`- ${r}`);
  out.push('');
}
out.push('## Branches in Confluence table but not in the git conversion');
out.push('');
const inGit = new Set(gitBranches);
for (const c of Object.keys(confluence)) if (!inGit.has(c) && c !== 'trunk') out.push(`- ${c}`);
out.push('');
out.push('## Coverage');
out.push('');
out.push(`- Names total: ${names.size}; in Confluence table: ${Object.keys(confluence).length}; documented share is the rest.`);
fs.writeFileSync(path.join(dir, 'branch-genealogy.md'), out.join('\n') + '\n');
console.log('names:', names.size, 'births:', births.size, 'archMoves:', archMoves.size,
  'deleteEvents:', deletes.length, 'orphans:', orphans.length);
