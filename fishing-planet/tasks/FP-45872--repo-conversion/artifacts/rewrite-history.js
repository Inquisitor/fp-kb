// Rewrite fp-server history: committer := author (identity+date), append git-svn-id trailers
// (from mapping.tsv + owners.tsv), inject the lost SVN r5292 case-rename commit and rewire
// descendants. Input: export.stream (git fast-export --no-data --show-original-ids).
// Output: rewritten.stream for git fast-import.
const fs = require('fs');
const path = require('path');
const dir = __dirname;

const SVN_URL = 'https://svn.fishingplanet.com/svn/SRV';
const UUID = 'a2e3d499-e076-ff40-967a-2141a354fd22';
const ROOT_ERA_MAX_REV = 2974; // /trunk created r2974; earlier trunk-lineage commits lived at repo root

// Injection: SVN r5292 case-rename lost by the conversion
const INJ = {
  afterOid: '060ec2be3e99689d72aaaeaf49e17b9fed42ff93', // r5291
  mark: ':9999991',
  ref: 'refs/heads/MultiRods20180406',
  author: 'Ivan Malyshev <ivan.m@fishingplanet.com>',
  epoch: Math.floor(Date.parse('2018-12-11T22:22:25Z') / 1000),
  tz: '+0000',
  msg: 'FP-12470 - Photon Debug Console - Typo fixed',
  rev: 5292,
  svnPath: '/branches/MultiRods20180406',
  filechange: 'R "Shared/ObjectModel/Debug/PlayerDEsc.cs" "Shared/ObjectModel/Debug/PlayerDesc.cs"',
  minChildRev: 5292, // rewire only children whose own rev >= this
};

const revOf = new Map(), pathOf = new Map();
for (const line of fs.readFileSync(path.join(dir, 'mapping.tsv'), 'utf8').split('\n')) {
  if (!line) continue; const p = line.split('\t'); revOf.set(p[0], +p[1]);
}
for (const line of fs.readFileSync(path.join(dir, 'owners.tsv'), 'utf8').split('\n')) {
  if (!line) continue; const p = line.split('\t'); pathOf.set(p[0], p[2]);
}

const buf = fs.readFileSync(path.join(dir, 'export.stream'));
const out = [];
let i = 0;
let parentMark = null;      // mark of the r5291 commit once seen
let injected = false;
let curOid = null, curRev = null, curMark = null;
let authorLine = null;
let stats = { commits: 0, trailers: 0, committerFixed: 0, rewired: 0, noMap: 0 };

function lineEnd(from) { const nl = buf.indexOf(10, from); return nl === -1 ? buf.length : nl; }

function trailerFor(oid) {
  const rev = revOf.get(oid);
  if (rev === undefined) return null;
  let p = pathOf.get(oid) || '';
  if (p === '/trunk' && rev <= ROOT_ERA_MAX_REV) p = '';
  return `git-svn-id: ${SVN_URL}${p}@${rev} ${UUID}`;
}

function emitInjection() {
  const trailer = `git-svn-id: ${SVN_URL}${INJ.svnPath}@${INJ.rev} ${UUID}`;
  const msg = INJ.msg + '\n\n' + trailer + '\n';
  const msgBuf = Buffer.from(msg, 'utf8');
  out.push(Buffer.from(
    `commit ${INJ.ref}\n` +
    `mark ${INJ.mark}\n` +
    `author ${INJ.author} ${INJ.epoch} ${INJ.tz}\n` +
    `committer ${INJ.author} ${INJ.epoch} ${INJ.tz}\n` +
    `data ${msgBuf.length}\n`, 'utf8'));
  out.push(msgBuf);
  out.push(Buffer.from(`from ${parentMark}\n${INJ.filechange}\n\n`, 'utf8'));
  injected = true;
}

while (i < buf.length) {
  const le = lineEnd(i);
  const line = buf.toString('latin1', i, le);

  if (line.startsWith('commit ')) {
    // if previous block was the injection parent, inject before starting this commit
    if (parentMark !== null && !injected) emitInjection();
    curOid = null; curRev = null; curMark = null; authorLine = null;
    stats.commits++;
    out.push(buf.slice(i, le + 1));
    i = le + 1;
    continue;
  }
  if (line.startsWith('mark ')) {
    curMark = line.slice(5).trim();
    out.push(buf.slice(i, le + 1));
    i = le + 1;
    continue;
  }
  if (line.startsWith('original-oid ')) {
    curOid = line.slice(13).trim();
    curRev = revOf.get(curOid);
    if (curOid === INJ.afterOid) parentMark = null; // set below after mark known; handled at block end
    out.push(buf.slice(i, le + 1));
    i = le + 1;
    continue;
  }
  if (line.startsWith('author ')) {
    authorLine = line;
    out.push(buf.slice(i, le + 1));
    i = le + 1;
    continue;
  }
  if (line.startsWith('committer ') && authorLine) {
    out.push(Buffer.from('committer ' + authorLine.slice(7) + '\n', 'latin1'));
    stats.committerFixed++;
    i = le + 1;
    continue;
  }
  if (line.startsWith('data ')) {
    const n = parseInt(line.slice(5), 10);
    const msgStart = le + 1;
    let msg = buf.slice(msgStart, msgStart + n);
    const trailer = curOid ? trailerFor(curOid) : null;
    if (trailer) {
      const endsNl = msg.length > 0 && msg[msg.length - 1] === 10;
      const add = (endsNl ? '\n' : '\n\n') + trailer + '\n';
      msg = Buffer.concat([msg, Buffer.from(add, 'utf8')]);
      stats.trailers++;
    } else if (curOid) stats.noMap++;
    out.push(Buffer.from('data ' + msg.length + '\n', 'latin1'));
    out.push(msg);
    // remember the injection parent's mark when its block's data is done
    if (curOid === INJ.afterOid) parentMark = curMark;
    i = msgStart + n;
    continue;
  }
  if ((line.startsWith('from ') || line.startsWith('merge ')) && parentMark !== null && injected) {
    const kw = line.startsWith('from ') ? 'from' : 'merge';
    const target = line.slice(kw.length + 1).trim();
    if (target === parentMark && (curRev === undefined || curRev >= INJ.minChildRev)) {
      out.push(Buffer.from(`${kw} ${INJ.mark}\n`, 'latin1'));
      stats.rewired++;
      i = le + 1;
      continue;
    }
  }
  // Case-fix: later commits must reference the renamed path (SVN had PlayerDesc.cs from r5292 on;
  // the original conversion case-folded those filechanges back to PlayerDEsc.cs)
  if (curRev !== undefined && curRev !== null && curRev >= INJ.minChildRev &&
      /^[MDRC] /.test(line) && line.includes('Shared/ObjectModel/Debug/PlayerDEsc.cs')) {
    out.push(Buffer.from(line.split('Shared/ObjectModel/Debug/PlayerDEsc.cs')
      .join('Shared/ObjectModel/Debug/PlayerDesc.cs') + '\n', 'latin1'));
    stats.caseFixed = (stats.caseFixed || 0) + 1;
    i = le + 1;
    continue;
  }
  out.push(buf.slice(i, le + 1));
  i = le + 1;
}
if (parentMark !== null && !injected) emitInjection();

fs.writeFileSync(path.join(dir, 'rewritten.stream'), Buffer.concat(out));
console.log(JSON.stringify(stats), 'injected:', injected);
