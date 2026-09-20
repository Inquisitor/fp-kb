// SVN -> Git tail sync for the pre-cutover window (and the final freeze catch-up).
// For every live branch: if SVN has revisions beyond the git tip, git-svn fetch the tail,
// transplant it (append-only, exact meta, git-svn-id trailers) and finally push to GitLab.
// Idempotent: nothing to do -> nothing done. Run: node sync-tails.js [--no-push]
const { execFileSync } = require('child_process');
const path = require('path');
const fs = require('fs');
const dir = __dirname;
const REPO = 'D:/FishingPlanet/src/server/git/fp-server.git';
// Git for Windows >= 2.51 dropped git-svn entirely; svn subcommands go through this bundled 2.50.
const GITSVN = path.join(dir, 'portable-git-2.50', 'cmd', 'git.exe');
const GITLAB = 'https://git.fishingplanet.org/fishing-planet/server/fp-server.git';
const SVNBASE = 'https://svn.fishingplanet.com/svn/SRV/branches/';
const BRANCHES = [
  { ref: 'NPN20260602', side: 'npn-svn' },
  { ref: 'MFT20260325', side: 'mft-svn' },
  { ref: 'LBM20251201', side: 'lbm-svn' },
  { ref: 'KNW20250723', side: 'knw-svn' },
  { ref: 'IMV20250220', side: 'imv-svn' },
  { ref: 'MI20200128', side: 'mi-svn' }, // side repo created on first drift
];
const noPush = process.argv.includes('--no-push');

function run(cmd, args, opts) {
  const out = execFileSync(cmd, args, Object.assign({ maxBuffer: 1 << 28 }, opts));
  return out === null ? '' : out.toString();
}
let pushed = 0;
for (const b of BRANCHES) {
  const msg = run('git', ['-C', REPO, 'log', b.ref, '-1', '--format=%B']);
  const tipRev = +msg.match(/git-svn-id: [^@]+@(\d+) /)[1];
  const tipSha = run('git', ['-C', REPO, 'rev-parse', b.ref]).trim();
  let svnLatest = 0;
  try {
    const log = run('svn', ['log', '-q', '--limit', '1', SVNBASE + b.ref, '--non-interactive']);
    svnLatest = +(log.match(/^r(\d+) /m) || [0, 0])[1];
  } catch (e) { console.error(b.ref + ': svn log failed - ' + String(e).slice(0, 120)); continue; }
  if (svnLatest <= tipRev) { console.log(b.ref + ': up to date @' + tipRev); continue; }
  console.log(b.ref + ': tail r' + (tipRev + 1) + '..r' + svnLatest);
  const side = path.join(dir, b.side);
  if (!fs.existsSync(side)) {
    run(GITSVN, ['-C', dir, 'svn', 'init', SVNBASE + b.ref, b.side]);
    run('git', ['-C', side, 'config', 'core.longpaths', 'true']);
    run('git', ['-C', side, 'config', 'svn.authorsfile', path.join(dir, 'authors.txt')]);
    console.log(b.ref + ': side repo initialized');
  }
  try {
    run(GITSVN, ['-C', side, 'svn', 'fetch', '--no-follow-parent'], { stdio: ['ignore', 'ignore', 'pipe'] });
  } catch (e) {
    console.error(b.ref + ': git-svn fetch FAILED (missing author? network?): ' + String(e.stderr || e).slice(-300));
    continue;
  }
  const out = run('node', [path.join(dir, 'transplant.js'), side, b.ref, tipSha, 'keep-root', '400', String(tipRev)]);
  process.stdout.write(out);
  pushed++;
}
if (!pushed) console.log('nothing to sync');
if (!noPush) {
  // Unconditional: a previously failed push must not be skipped by a later quiet run.
  console.log('pushing to GitLab...');
  run('git', ['-C', REPO, 'push', GITLAB, '--all']);
  console.log('push done');
}
