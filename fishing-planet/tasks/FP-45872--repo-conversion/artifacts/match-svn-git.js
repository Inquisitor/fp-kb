// Match fp-server git commits to SVN revisions by (author epoch second, normalized message).
// Inputs (same dir): svn-log-all.xml, git-commits.z
// Outputs: mapping.tsv (hash, rev, svnIso, subjectHead), anomalies-git-unmatched.tsv,
//          anomalies-ambiguous.tsv, anomalies-svn-unmatched.tsv; stats to stdout.
const fs = require('fs');
const path = require('path');
const dir = __dirname;

// Normalize: collapse all whitespace, strip non-ASCII (conversion mojibake), cap length.
function norm(s) {
  return (s || '').replace(/[^\x20-\x7E]+/g, '').replace(/\s+/g, ' ').trim().slice(0, 300);
}
function decodeXml(s) {
  return s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"')
          .replace(/&apos;/g, "'").replace(/&#(\d+);/g, (m, d) => String.fromCodePoint(+d))
          .replace(/&amp;/g, '&');
}

// --- SVN side ---
const xml = fs.readFileSync(path.join(dir, 'svn-log-all.xml'), 'utf8');
const svn = [];
const entryRe = /<logentry\s+revision="(\d+)">([\s\S]*?)<\/logentry>/g;
let m;
while ((m = entryRe.exec(xml)) !== null) {
  const rev = +m[1];
  const body = m[2];
  const author = (body.match(/<author>([\s\S]*?)<\/author>/) || [])[1] || '';
  const dateIso = (body.match(/<date>([\s\S]*?)<\/date>/) || [])[1] || '';
  const msg = decodeXml((body.match(/<msg>([\s\S]*?)<\/msg>/) || [])[1] || '');
  const epoch = Math.floor(Date.parse(dateIso) / 1000);
  svn.push({ rev, author: decodeXml(author), dateIso, epoch, msg });
}

// --- git side ---
const raw = fs.readFileSync(path.join(dir, 'git-commits.z'), 'utf8');
const gitRecs = raw.split('\0').filter(r => r.trim().length > 0).map(r => {
  const [hash, ad, cd, an, ...rest] = r.replace(/^\n/, '').split('\t');
  return { hash, ad, cd, an, msg: rest.join('\t') };
}).filter(r => r.hash && /^[0-9a-f]{40}$/.test(r.hash));

// --- index svn by key ---
const byKey = new Map();
for (const e of svn) {
  const key = e.epoch + '|' + norm(e.msg);
  if (!byKey.has(key)) byKey.set(key, []);
  byKey.get(key).push(e);
}

// --- match ---
const mapping = [], unmatched = [], ambiguous = [];
const matchedRevs = new Set();
for (const g of gitRecs) {
  const epoch = Math.floor(Date.parse(g.ad) / 1000);
  const key = epoch + '|' + norm(g.msg);
  const hits = byKey.get(key) || [];
  if (hits.length === 1) {
    mapping.push([g.hash, hits[0].rev, hits[0].dateIso, norm(g.msg).slice(0, 80)]);
    matchedRevs.add(hits[0].rev);
  } else if (hits.length === 0) {
    // fallback: epoch-only match if unique
    const sameEpoch = svn.filter(e => e.epoch === epoch);
    if (sameEpoch.length === 1) {
      mapping.push([g.hash, sameEpoch[0].rev, sameEpoch[0].dateIso, norm(g.msg).slice(0, 80) + ' [EPOCH-ONLY]']);
      matchedRevs.add(sameEpoch[0].rev);
    } else {
      unmatched.push([g.hash, g.ad, g.an, norm(g.msg).slice(0, 100), 'sameEpoch=' + sameEpoch.length]);
    }
  } else {
    ambiguous.push([g.hash, g.ad, hits.map(h => h.rev).join(','), norm(g.msg).slice(0, 80)]);
  }
}
const svnUnmatched = svn.filter(e => !matchedRevs.has(e.rev));

// --- outputs ---
function tsv(rows) { return rows.map(r => r.join('\t')).join('\n') + '\n'; }
fs.writeFileSync(path.join(dir, 'mapping.tsv'), tsv(mapping));
fs.writeFileSync(path.join(dir, 'anomalies-git-unmatched.tsv'), tsv(unmatched));
fs.writeFileSync(path.join(dir, 'anomalies-ambiguous.tsv'), tsv(ambiguous));
fs.writeFileSync(path.join(dir, 'anomalies-svn-unmatched.tsv'),
  tsv(svnUnmatched.map(e => [e.rev, e.dateIso, e.author, norm(e.msg).slice(0, 100)])));

const post = svnUnmatched.filter(e => e.rev > 15989).length;
console.log('git commits:', gitRecs.length);
console.log('svn revisions:', svn.length);
console.log('matched:', mapping.length, '(epoch-only:', mapping.filter(r => String(r[3]).includes('[EPOCH-ONLY]')).length + ')');
console.log('git unmatched:', unmatched.length);
console.log('ambiguous:', ambiguous.length);
console.log('svn unmatched:', svnUnmatched.length, '(of which post-sync rev>15989:', post + ')');
