---
jira: FP-44731
title: Prepare hosting & infrastructure for the new fishingplanet.com website (WordPress, Snig)
status: in-progress
executor: Stanislav Samoilov
created: 2026-06-30
type: story
---
# FP-44731: Prepare hosting & infrastructure for the new fishingplanet.com website (WordPress, Snig)

## Status
In progress - the isolated multi-app web host is standing up on the received VM (`fpweb`,
162.222.23.28, Ubuntu 24.04). Design (`server-setup-design.md`) and runbook
(`artifacts/server-setup-plan.md`) approved. **Done:** host baseline (default-deny nft firewall, SSH
source-IP allowlist, sshd hardening, unattended-upgrades, fail2ban tuned, etckeeper); Docker; the
`fp-main-website` WordPress stack (nginx+php-fpm+MariaDB, per-app isolated networks, file secrets);
edge-nginx on 80/443 with the purchased GlobalSign wildcard cert exported from IIS (valid to
2026-11-03); WP core installed; chroot-SFTP endpoint on :2222 for Snig (their key installed).
**In flight:** authorized pentest of the SFTP/defense posture (Codex + own audit).
**Next:** act on pentest findings; egress default-deny experiment (once Snig upload shows what the site
needs); backups (Task 9); SendGrid DKIM + scoped key (Task 6).
**Blockers / external:** farm-side firewall block of the VM subnet (HARD GATE before go-live - currently
only a bypassable host-level plug); DNS cutover is CEO-controlled (post-cutover TLS renewal switches to
HTTP-01); keys/personal accounts for `ap`/devops before disabling SSH passwords.
Snig get no access to the internal-network site - they upload via SFTP; the cleaned archive
(`web-2026-07-07-clean-v3.zip`) + validated URL keep-set are the reference deliverables.

## Summary
Snig.digital delivered a new WordPress fishingplanet.com site. The website project itself (content,
art, design) is tracked under epic FP-40093 and Confluence "Websites Research" (page 5262868489), but
the hosting / security / cutover side was untracked. This task owns that gap: where and how to host
the new site (isolated, outside the internal network), preserving the existing public apex URLs
(legal pages especially), keeping `live.fishingplanet.com` out of scope, and the cutover itself.

## Design decisions
- **Do not host the public WordPress on the internal IIS/MySQL server, and do not grant Snig access to
  internal-network servers.** A public CMS is a high-value, continuously-scanned target; a compromise
  inside the perimeter would hand an attacker a foothold next to game infrastructure. The
  "moderators-only uploads" point does not reduce this surface - WordPress is attacked over the
  internet through core/plugin/PHP CVEs regardless of who uploads content.
- **"nginx/mod_rewrite required" is not a blocker and is the wrong axis.** IIS can host WordPress via
  the URL Rewrite module (the mod_rewrite equivalent). The real driver is network isolation, which
  makes the current server unsuitable regardless of feasibility.
- **Hosting architecture (agreed):** a dedicated **VM in a separate, firewalled network segment** -
  not the internal IIS/MySQL server, and not an external VPS. Shell reachable only from the internal
  network; only 80/443 exposed outward. This is the Option B infrastructure and also supports
  static-publish later from the same VM.
- **The separate network cannot reach the internal farm network in any way (firewall) - confirmed by
  the network/farm owner.** This is the load-bearing control: even a fully compromised WordPress cannot
  pivot inward. (Outbound egress *to the internet* from the VM, and a front-end WAF, are separate items
  still under discussion - the inward block is settled.)
- **Snig upload channel = SFTP/FTPS, not plain FTP (accepted).** Plain FTP is cleartext over the
  internet; SFTP (chroot, no interactive shell) or FTPS gives encrypted, single-port, IP-restrictable,
  time-boxed upload without granting a real shell or any internal-network access. We still snapshot the
  old static webroot ourselves to hand Snig an archive plus a URL list.
- **Email / form-sending via SendGrid (accepted by Snig).** We do not share corporate-mail credentials
  or open our mail server; the site sends via our existing SendGrid account using a dedicated, scoped
  Mail-Send API key handed over securely. The domain SPF already contains `include:sendgrid.net`
  (alongside Google Workspace, Zendesk, Mailchimp, eSputnik), so no SPF change is needed; the remaining
  piece is confirming DKIM domain authentication in the SendGrid account.
- **Public surface is a dynamic WordPress (effectively decided).** Snig's requirements - nginx +
  uploads directory + database + server-side form email - describe a standard dynamic WP install, so
  static-publish now looks unlikely. Consequence: the dynamic-WP hardening (front-end WAF, egress
  filtering, wp-admin exposure) should be treated as required, not optional.

## Context - verified findings (repo grep)
- Our own backend artifacts link to specific apex paths that must survive cutover:
  `fishingplanet.com/gamerules.htm`, `/xbox/privacy/`, `www.fishingplanet.com/console/tos/`
  (`Photon/tools/EmailGenerator` templates) and the apex root (`TwitchAccountLinking` view). These are
  ToS / Privacy / rules pages also referenced by store pages and platform certification - if the new
  site 404s them, transactional emails and legal links break, with possible platform-compliance impact.
  (The in-game EULA subsystem `EulaCache` / `EulaDto` is DB-backed and separate from these marketing
  pages.)
- `live.fishingplanet.com` is a **separate distribution host** serving game build manifests
  (`index.json`) for Steam/Xbox/PS/Nintendo/Mobile. It is **out of migration scope**; only the apex
  `fishingplanet.com` (and possibly `www`) is being replaced. Must be made explicit to Snig.
- The old site serves legal docs for **two products under the same apex**: F2P *Fishing Planet*
  (`console/`, `pc/`, `mobile/`, `nintendo/`, `xbox/`) and Retail *The Fisherman - Fishing Planet*
  (`consoler/`, `pcr/`, `xboxr/`). Both path sets must be preserved / redirected on cutover, not just
  the F2P ones. (Source: cleaned dump + cleaning report, 2026-07-07.)

## Artifacts
- [`site-dump-cleaning-report-2026-07-07.txt`](artifacts/site-dump-cleaning-report-2026-07-07.txt) -
  cleaning agent's report on the site dump (structure, current pages per product, migration watch-outs,
  and what was stripped as secrets/PII).
- Deliverable for Snig: `web-2026-07-07-clean-v2.zip` (241 files) in the website working dir - cleaned
  webroot with `FP_files` removed and support emails fixed; forward-slash paths. Original dumps kept
  alongside for audit; the original `web-2026-07-07.zip` is never handed over.
- [`server-setup-plan.md`](artifacts/server-setup-plan.md) - step-by-step implementation runbook for
  the approved server design (`server-setup-design.md`): host baseline, Docker stacks, TLS, SFTP,
  egress, backups, verification, cutover checklist.
- [`f2p-vs-retail-legal-diff.md`](artifacts/f2p-vs-retail-legal-diff.md) - per-doc-type comparison of
  F2P vs Retail legal texts (same entity; Retail an older generation, Privacy 2018-05-25).
- [`web-accessible-urls-grouped-2026-07-07.xlsx`](artifacts/web-accessible-urls-grouped-2026-07-07.xlsx) -
  all 100 web-reachable HTML pages (path, URL, title, content description) for the site-owner review;
  F2P/Retail tabs, grouped by folder, collapsible, with a `Drop?` column. Descriptions validated by
  reading each file. (Flat `.md`/`.xlsx` versions were dropped as redundant.)

## Open questions
- Does the new site need any dynamic features (forms, search, login, on-the-fly localization), or is it
  effectively a brochure/content site? Determines dynamic-WP vs static-publish for the public surface.
- Front-end WAF: put Cloudflare (or similar) before the VM's 80/443 and firewall origin to its IP
  ranges? (under discussion)
- Restrict the VM's outbound internet egress to default-deny + allowlist? (under discussion)
- Keep `wp-admin` / `wp-login` off the public 443 (internal-only or access-gated)? (under discussion)
- VM hygiene: post-setup snapshot, backups, auto-updates; post-handoff credential rotation and review
  of uploaded plugins/themes (supply chain). (under discussion)
- Snig fixed egress IPs for whitelisting the temporary upload channel; TLS termination location
  (Cloudflare vs VM).
- Full inventory of current public apex URLs (legal first) - to be produced from the old-site snapshot.

## Milestones (log)
- 2026-06-30: Opened. Brainstormed the hosting/security approach against Snig's request; recommended
  no-internal-host + no-access + apex-URL-preservation + static-publish-preferred. Verified apex URL
  references and the `live.` distinction via repo grep. JIRA FP-44731 created (Story under epic
  FP-40093; components Infrastructure + Web; Scrum Team Other; Medium). Confluence "Websites Research"
  (5262868489) confirms Snig.digital as the chosen provider but carries no hosting/security info.
- 2026-06-30: Hosting approach agreed with the network/farm owner - dedicated VM in a separate,
  firewalled network segment (cannot reach the internal farm network; shell internal-only; 80/443
  outward; temporary Snig upload channel removed after handoff). Upload protocol decided: SFTP/FTPS
  instead of plain FTP. Front-end WAF, outbound-egress filtering, wp-admin exposure, static-publish vs
  dynamic public surface, and VM hygiene left for further discussion.
- 2026-07-07: Snig exchange - reply sent declining direct access to the current (internal-network)
  site; Snig accepted a static archive + full URL list instead, now being prepared from a downloaded
  site dump. Email path agreed: via our existing SendGrid account (dedicated scoped API key; domain
  authentication to merge into the existing SPF), not shared corporate-mail creds. Snig's asks
  (nginx + uploads + DB + form email) confirm a dynamic WordPress, so static-publish is now unlikely.
- 2026-07-07: Site dump cleaned (helper agent) and verified - risky items confirmed gone (`ap/` with a
  hardcoded private key + unrelated firmware; a 156 MB IIS log with visitor IPs; QRfy third-party JS);
  `web.config` carries no secrets. Deliverable to Snig = the clean zip `web-2026-07-07-clean.zip`
  (~297 files) + a page/URL list derived from the cleaning report's content map; never the original
  dump. The domain serves BOTH F2P and Retail (The Fisherman) legal docs under one apex - both path
  sets must be preserved on cutover. Content/compliance flags recorded in backlog. (The report's
  "428 files kept" is the original count; ~297 remain.)
- 2026-07-07: Cleaning report archived to task artifacts. Confirmed the clean zip = 257 files (earlier
  297 was files + 40 dir entries); the on-disk folder additionally holds a manually-copied
  domain-control-validation token (`qtedvrf...html`, 30 bytes) the automated dump had missed. Applied
  approved fixes to the clean webroot: removed the orphaned `FP_files` (no page referenced it) and
  corrected support emails - `support@fishingplane.com` (typo, 14 files) and `support@fishingbeta.com`
  (stale, 3 files incl. root `GameRulesPC.htm`, which the report missed) all -> `support@fishingplanet.com`.
  Rebuilt the deliverable as `web-2026-07-07-clean-v2.zip` (241 files, forward-slash paths); originals
  kept. Flagged `.well-known/apple-app-site-association` + `microsoft-identity-association.json` for
  preservation on cutover (app deep-link / identity association).
- 2026-07-07: F2P-vs-Retail legal comparison done (`artifacts/f2p-vs-retail-legal-diff.md`). Verdict:
  Retail (The Fisherman) is the SAME legal entity/publisher as F2P (Fishing Planet LLC, NY law) - no
  separate publisher, and no disc/DLC/exclusive-waterbody language - but its legal docs are an older
  generation and need updating. Privacy is the top exposure (Effective 2018-05-25, never updated;
  weaker child-consent; stale vk.com reference). EULA/TOS are prior-gen (min age 13 vs F2P 3;
  "clans" vs "clubs"; PS4-only; missing club-conduct clauses). Two Retail bugs also found: `xboxr/eula`
  carries the F2P "Fishing Planet" brand string, and `xboxr/tos` has a broken unsubstituted support URL.
  This is a content/legal action for the site owner/PM, not infra.
- 2026-07-07: Decision (Viktoriya) - publish the legal docs **as-is** now and correct them later; a
  legal-doc change requires a change-notification mailout that must not delay the launch. Produced a
  web-accessible page table for her review: `artifacts/web-accessible-urls-2026-07-07.md` (100 HTML
  pages: path, URL, title, content description).
- 2026-07-07: Re-validated all 100 pages by reading actual content (not trusting the cleaning report /
  comparison agent). Corrections: root `index.html` + sibling stubs are a real homepage landing page
  (Steam/forum/support CTAs, FB pixel), not "no content"; F2P bare folder indexes are exact copies of
  the folder EULA, Retail ones near-copies. Confirmed the "Game Rules" split by direct reading - short
  (`GameRules.htm`, age 13, "clan") = full EULA under a Game Rules title; long (`pc/GameRules.htm`,
  age 7) = in-game conduct rules. EULA/ToS/Privacy/Tournament/Denuvo confirmed by heading+path. Rebuilt
  the review artifacts incl. a grouped two-sheet spreadsheet (F2P/Retail tabs, folder groups, Drop?
  column). Retail ships only on Steam/PlayStation/Xbox (`pcr`/`consoler`/`xboxr`) - no
  mobile/Nintendo/UWP/Epic (see [[retail-platforms]]).
- 2026-07-07: CS lead completed the URL relevance review - drop only the six old homepage variants
  (`fp_beta`, `old`, `new`, `Index_old`, `index_preapple`, `i`.html); everything else is current and
  stays, published as-is (13/7 age discrepancy accepted). Remaining URL work: preserve every kept path
  on the new site (same path or 301); 301 targets pending Snig's new URL structure; the six stubs can
  404 or 301 to `/`. The deferred legal-doc corrections still stand as a separate content/legal
  follow-up.
- 2026-07-07: Built `web-2026-07-07-clean-v3.zip` = v2 minus the six dropped homepage stubs (272 vs 278
  entries; `index.html` + domain-validation token kept, no FP_files, everything else byte-identical to
  v2). This is now the Snig deliverable; v2 retained on disk as history. XLSX drop handled separately by
  the site owner.
- 2026-07-20: Server received (bare Linux VM, network isolation already in place by design). Server
  setup design brainstormed and **approved**: isolated multi-app web host on Docker Compose (one stack
  per app - WordPress now, Invision forum + MediaWiki later), front nginx reverse proxy, TLS via
  acme.sh DNS-01 pre-issued for the apex, hosts-file staging, egress default-deny + allowlist,
  chroot-SFTP for Snig, wp-admin IP-gated, SendGrid scoped key. Spec: `server-setup-design.md`.
  Execution model: direct SSH configuration by Claude (sudo user, snapshot first, confirm before
  irreversible steps). Next: implementation plan, then execution once SSH access is granted.
- 2026-07-20: Task 0-1 executed: SSH key access + temporary NOPASSWD sudo working (user `inqui`, host
  `fpweb`, 162.222.23.28). Recon: Ubuntu 24.04.4, 4 vCPU / 7.8 GB / 97 GB, clean box (only sshd
  listening), public IPv4 + global IPv6. Flags raised: confirm network fw filters 22/tcp from
  internet, and that v6 is filtered like v4. **Isolation pre-proof FAILED - setup halted:** from the
  VM both `svn.fishingplanet.com` (HTTP 401 - full connect) and `steam-webadmin.fishingplanet.com`
  (TLS connect OK) are reachable; farm hosts sit on public IPs (192.40.222.x). Pending
  disambiguation: are farm hosts internet-open (VM not privileged; separate webadmin-exposure
  concern) or is the VM subnet (162.222.23.0/26) in the farm firewall's allow list (real perimeter
  breach - must be removed)? Test: open both from LTE. No installation until resolved.
- 2026-07-20: LTE test: both farm hosts unreachable from the internet -> the VM subnet IS privileged
  on the farm firewall (perimeter breach confirmed). Escalated to the farm owner with a concrete ask:
  deny all traffic initiated from 162.222.23.0/26 (+ the VM's IPv6 /64) toward farm ranges; keep
  farm->VM SSH working (stateful); confirm 22/tcp on the VM is closed from the internet; inbound from
  internet = 80/443 only (2222 later for the contractor); rules for both v4 and v6. Setup resumes
  only after the isolation re-test goes green (farm hosts time out from the VM, SSH still works).
- 2026-07-20: New facts: the VM is NOT in our vCenter (provisioned elsewhere by the farm owner -
  provider/console/snapshot capability pending their answer); auth log showed 22/tcp open to the whole
  internet with password auth on and active brute-force (170 failures/48h) - and fail2ban already
  running (pre-installed, ~380 bans). Emergency hardening applied ahead of Task 2, user-approved:
  nftables SSH allowlist (Portugal office 5.249.108.171, farm VPN 192.40.222.26, admin WireGuard 8.44.201.100;
  all other v4 + all v6 dropped on 22), persisted via nftables.service (survives reboot), applied with
  a 3-min auto-rollback timer then confirmed + cancelled; fail2ban restarted on top. Access reorg: both
  keypairs (automation + user's PuTTY) moved to D:\FishingPlanet\keystores\fpweb\, user key
  passphrase-protected (openssh file + ppk), ssh-config alias `fpweb`. Pending decision: disable
  PasswordAuthentication globally - other human accounts `ap` (empty authorized_keys) and `fpwebadmin`
  (no .ssh) are password-only, presumably the farm owner's; either add their keys first or accept
  ssh-lockout for them (hypervisor console remains).
- 2026-07-20: Decision (user): keep PasswordAuthentication ON for now - `ap`/`fpwebadmin` owners (farm
  owner / devops) unreachable; risk contained by the allowlist + fail2ban. Follow-up in backlog:
  personal devops accounts instead of shared `fpwebadmin`, keys for all, then disable passwords. SSH
  allowlist extended with the Kyiv office ISPs (109.86.89.251, 82.193.99.168, 193.34.218.232 reserve) -
  live set + persistent config in sync.
- 2026-07-20: fail2ban policy audited: farm owner had set bantime=1y / maxretry=1 (edited in the
  packaged jail.conf [DEFAULT] - would not survive a package upgrade). With the new SSH allowlist that
  jail could effectively only ban trusted sources (one typo = office/VPN egress locked out for a
  year, and its chain fires before the allowlist chain). ignoreip rejected (user): it would remove all
  throttling of password guessing from a compromised trusted host. Softened instead (user's values)
  via /etc/fail2ban/jail.local [sshd]: maxretry=10, findtime=3h, bantime=15m. Old 423 year-bans
  expired on restart (harmless - those sources are firewall-dropped anyway). Tell the farm owner:
  jail.conf edits are upgrade-fragile, use jail.local.
- 2026-07-20: Farm owner (by phone): put a TEMPORARY host-level plug on the VM instead of waiting for
  the farm-side firewall fix. Applied + persisted: nftables output rule dropping NEW VM-initiated
  connections to 192.40.222.0/24 (established/related accepted first, so SSH replies to the farm-VPN
  source keep working). Verified: svn/steam-webadmin/192.40.222.26 all time out from the VM, internet
  unaffected. **Explicitly recorded limitation: a host-level rule is bypassable by root on the VM -
  the farm-side block remains a HARD GATE before go-live / contractor handover.** With this plug the
  Task-1 isolation check passes in its temporary form; setup can proceed once a snapshot exists.
- 2026-07-20: Pre-setup snapshot WAIVED (user): the server is empty and the runbook + etckeeper make
  the setup reproducible from scratch; hypervisor console exists at the farm owner. Gate moved to
  "snapshots or verified backups before contractor content lands". Plan Task 2 (host baseline)
  executed: full-upgrade + reboot into the new kernel (nftables persistence verified by the reboot),
  input chain tightened to default-deny (lo, established, ICMP/v6, SSH allowlist, 80/443), sshd
  hardening drop-in (PermitRootLogin no, X11Forwarding no; passwords intentionally kept),
  unattended-upgrades enabled, etckeeper baseline commit. All verified by fresh logins +
  egress/farm-plug checks.
- 2026-07-20: Plan Tasks 3-4 executed. Docker 29.6.2 + Compose v5.3.1 (official repo, hello-world
  verified, config committed). WordPress stack up: nginx:1.27-alpine (wp-web) + wordpress:6-fpm
  (wp-php) + mariadb:11.4 (wp-db), per-app networks wp_front/wp_back, file-based secrets, /srv/apps
  under git. Install wizard verified ("WordPress > Installation", 302, clean php log). Fixes along the
  way: zsh fatal unmatched glob under sudo (wrap in sh -c), db_password secret needed root:www-data
  640 (php-fpm reads it per-request as uid 33), $ in WORDPRESS_CONFIG_EXTRA must be $$-escaped
  (compose interpolation). wp-config extras in place: proxy HTTPS hint, WP_HOME/WP_SITEURL=
  https://fishingplanet.com, DISALLOW_FILE_EDIT. Next: Task 5 (edge nginx + TLS) - blocked on DNS
  provider API token for DNS-01; Task 7 blocked on Snig egress IPs; Task 6 on SendGrid access.
- 2026-07-20: App renamed wordpress -> fp-main-website (user request; fp-web rejected as clashing with
  the host name fpweb): folder /srv/apps/fp-main-website, compose project name, containers
  fp-main-website-{nginx,php,db}, networks fp-main-website_{front,back}. DB volume recreated (was
  empty - install wizard not yet run). Wizard re-verified after rename; git tracked the rename; the
  runbook artifact updated to the new naming. Future apps follow the family: fp-forum, fp-wiki.
- 2026-07-21: Decision (user): no source-IP restriction for the contractor SFTP pre-live - key-only +
  chroot + fail2ban carry the load; IPs will be requested in the same message as the key exchange and
  added if fixed. Plan Task 7 executed: dedicated sshd instance on 2222 (chroot to a bind-mount of the
  webroot, ForceCommand internal-sftp, no shell/forwarding), snig user (locked-account gotcha fixed
  with usermod -p "*"), setgid group-www-data webroot, fail2ban jail [sshd-sftp], port 2222 opened in
  the host fw (live + persistent), etckeeper commit. End-to-end verified: upload lands in the webroot
  as snig:www-data, shell refused, jail escape impossible; test key/file cleaned - authorized_keys
  empty, awaiting Snig's real public key. Known rough edge (deliberately not pre-fixed): SFTP-uploaded
  files arrive 644 snig-owned - WP (www-data) cannot overwrite them later; fix with a perms sweep/ACL
  only if the contractor actually hits it.
- 2026-07-21: TLS strategy pivot: no DNS API token will ever be available (the domain is personally
  controlled by the CEO) -> DNS-01 dropped. Instead: the live IIS site uses a purchased GlobalSign
  wildcard *.fishingplanet.com valid to 2026-11-03; user exported the PFX from IIS (OpenSSL 3 needs
  -legacy for Windows RC2 PFX), key<->cert match verified, files under keystores/fpweb/fishingplanet.com/.
  Post-cutover renewal switches to plain HTTP-01 acme.sh on the VM (no DNS access needed ever).
- 2026-07-21: Plan Task 5 + Task 6 (install part) executed: edge-nginx (proxy compose stack) on
  80/443 with the wildcard cert (80->301, unknown-SNI/bare-IP -> 444 drop), routing to
  fp-main-website-nginx over fp-main-website_front. WP core installed via wordpress:cli (admin
  `fpadmin`, password in keystores/fpweb/wp-admin-fpadmin.txt, --skip-email) - closes the
  public-install-wizard hole. wp-admin IP gate deliberately absent pre-live (user decision) - MUST be
  added before go-live (backlog). Incident during commit: cert+PRIVATE KEY got tracked by /srv/apps
  git (certs/ not ignored) - purged via rm --cached + amend + gc --prune, */certs/ added to
  .gitignore, history verified clean; repo is local root-only, never left the box. External
  verification from the workstation (hosts-pinned): valid chain, 200 homepage "Fishing Planet", www
  and http 301s, wp-login 200, bare-IP scan gets connection drop. Remaining in Task 6: SendGrid
  (DKIM + scoped key) - blocked on account access.
- 2026-07-21: Snig's real SFTP public key installed (RSA-4096, SHA256:J6UiRYH1z8R..., from
  alexcss@Kaliuzhnyis-MacBook-Pro.local). Endpoint handed to Codex (gpt-5.6-sol) for an authorized
  pentest review of the chroot-SFTP config; active probes run from a throwaway key added alongside
  (to be removed after). Findings + fixes to follow.
- 2026-07-21: SFTP security review done (Codex + own active probes). **Holding (verified):** chroot
  (root-owned jail, writable bind below root), forced-command (no shell), symlink/hardlink escape
  (resolves inside chroot), TCP forwarding blocked, docker.sock unreachable (root:docker, snig not in
  the docker group). **Real gap found & fixed:** StreamLocal (Unix-socket) forwarding was NOT covered
  by `AllowTcpForwarding no` (dbus `0666` reachable). Fixed on three locks: `DisableForwarding yes` +
  `AllowStreamLocalForwarding no` + `restrict` prefix on the key; also `AllowAgentForwarding no`,
  `PermitTunnel/PermitTTY/PermitUserRC` off, `PermitOpen/PermitListen none`, denied symlink/hardlink
  (`-P`), tightened `LoginGraceTime/MaxAuthTries/MaxStartups/PerSourceMaxStartups/UnusedConnectionTimeout`.
  Then cleaned ALL my server configs of task-ids / dates / process / tooling mentions (comments are
  technical-why only), renamed `10-fp44731-hardening.conf` -> `10-hardening.conf`
  (see [[no-ai-pentest-mentions-in-server-configs]]). Test key + probe artifacts removed; clean configs
  committed.
- 2026-07-21: Deferred hardening (ranked; before go-live / before Snig content lands): (1) snig primary
  group is `www-data` - move to a dedicated group so a jail-escape/shell cannot read the `www-data`
  db secret [needs matching `group_add` on the php container to keep mutual webroot writes]; (2) harden
  the php container (`read_only` rootfs + tmpfs, `cap_drop: [ALL]`, `no-new-privileges`, pids/mem
  limits); (3) container egress filtering in the Docker forwarding path + block `169.254.169.254`
  (this is Task 8); (4) least-privilege DB user + rotate after handoff; (5) restrict port 2222 + key
  `from=` to Snig IPs at handoff; (6) upload into a staging dir, not straight into the served webroot;
  (7) wp-admin IP gate; (8) farm-side firewall block (HARD GATE).
- 2026-07-21: Applied deferred hardening (1) and (2). `snig` moved off the `www-data` primary group to
  a dedicated `webdata` group (gid 1004); webroot regrouped `www-data:webdata` 2775 setgid, so php
  (owner uid33) and snig (primary webdata) still write mutually, but snig can no longer read the
  `www-data` `db_password` on a jail-escape/shell. php container hardened: `read_only` rootfs + tmpfs
  `/tmp`,`/run`, `cap_drop: ALL` + minimal `cap_add`
  (CHOWN,DAC_OVERRIDE,FOWNER,SETGID,SETUID,KILL), `no-new-privileges`, pids/mem limits, `group_add`
  1004 for mutual webroot writes; db container cap-dropped + no-new-privs. Verified: home/wp-login 200,
  php worker `groups=33,1004`, php-written file inherits group `webdata`, writes outside webroot/tmp
  fail (read-only), containers healthy. Probe symlink leftover removed from the webroot. Clean commit.
- 2026-07-21: Created personal devops accounts `yk` (uid 1004) and `vk` (uid 1005): home + bash, in
  the `sudo` group (password sudo, not NOPASSWD), temporary passwords set and force-expired (`chage -d
  0`) for a first-login change; passwords handed to the user out-of-band. No `AllowUsers` restriction
  on sshd, so they can log in - but only from IPs already in the SSH allowlist (office/VPN/WG); add
  their source IPs if they connect from elsewhere.
- 2026-07-21: Task 9 local backups done. `/srv/backups` (root 700), `/usr/local/sbin/backup-apps.sh`:
  consistent `mariadb-dump` (`--single-transaction`) of the WordPress DB + `tar` of the webroot, gzip,
  gzip-integrity + non-empty check, 7-day retention; nightly cron `/etc/cron.d/backup-apps` at 03:10.
  Manual run verified: dump has 12 `CREATE TABLE`s, tar has `wp-config.php`/`version.php`, dumps are
  root:600. Off-box pull (internal host rsync of `/srv/backups`) still TODO - needs the target machine.
  Note: the script lives in `/usr/local/sbin` (outside etckeeper); only the cron.d entry is versioned.
- 2026-07-21: Started SendGrid mail wiring (Task 6). Domain Authentication already Verified
  (`em330.fishingplanet.com`) - no DNS round with the CEO needed. Added a secret file
  `secrets/sendgrid-mailsend.key` (root:www-data 640, gitignored) mounted into php; installed WP Mail
  SMTP. Snag: `WORDPRESS_CONFIG_EXTRA` only applies at first wp-config generation, so the added WPMS
  defines did not land (`mailer=undef`) - to be redone cleanly (mail config as a file under /srv/apps
  mounted as an mu-plugin) later; git-mirror of configs deferred by the user. Contractor does NOT need
  the SendGrid key: their contact form calls `wp_mail()`, which our transport routes via SendGrid with
  our key held only on the server.
- 2026-07-21: Two firewall bugs found + fixed while enabling container internet (plugin install). (1)
  `nft flush ruleset` was wiping Docker's own nat/filter rules on every reload, killing container
  internet - scoped the reset to `delete table inet filter`. (2) The farm block lived only in host
  `output`; container traffic goes via `forward`, so containers still reached the farm (php container
  got 401 from svn). First forward attempt (priority -10, blunt drop of all traffic to 192.40.222.0/24)
  broke the site two ways: priority -10 disturbed Docker's forward handling (external 443 timed out),
  and the blunt drop killed replies to visitors arriving via the farm VPN (192.40.222.26 is inside the
  blocked range - user was on VPN, which surfaced it). Final forward rule: priority 10 (after Docker),
  accept established first (VPN visitors answered), drop only NEW connections to the internal range.
  Verified: container->internet ok, container->farm blocked, external 443 back to 200. Lesson: run
  container network-path probes at review time, not only SFTP probes. Config snapshot now mirrored in
  `artifacts/server-config/` (secrets/certs/webroot excluded).
- 2026-07-21: Mail transport finished cleanly - WPMS config moved out of `WORDPRESS_CONFIG_EXTRA`
  (didn't apply post-first-boot) into an mu-plugin `php-config/mail.php` (in /srv/apps, mounted to
  wp-content/mu-plugins, reads the key from the mounted secret). `mailer=sendgrid`, key_len=69 resolved.
  Test send returned false: SendGrid API rejected with "requestor's IP Address is not whitelisted" -
  the account has IP Access Management on and the VM's egress IP (162.222.23.28) isn't listed. Transport
  and key are correct (auth passed); user to add 162.222.23.28 in SendGrid Settings -> IP Access
  Management, then re-test. mail.php + updated compose mirrored in artifacts.
- 2026-07-21: After the user whitelisted 162.222.23.28 in SendGrid IP Access Management, the test send
  returned `wp_mail = true` - mail transport fully working (WordPress -> SendGrid, from
  noreply@fishingplanet.com, DKIM-signed domain). Task 6 complete. The contractor's contact form will
  route through this automatically; no SendGrid key handed to Snig.
- 2026-07-21: Prepared the contractor handover. Created WP administrator `snig` (temp password, they
  change on login; email a placeholder). Installed + activated All-in-One WP Migration for their
  content/DB import (free-version size limit noted - offer direct SQL import as the fallback for large
  sites). SFTP source-IP restriction: none pre-live (user decision). Handover message drafted in RU
  (SFTP creds, hosts staging, wp-admin login, migration plugin ready, mail already routed - no
  SendGrid key to them).
- 2026-07-22: HARD GATE cleared - the farm owner closed the VM off at the farm-side firewall. Verified
  properly: temporarily removed our host-level nft plug (SSH input rules untouched) and probed the farm
  with only the farm-side firewall deciding - svn (192.40.222.76:443), webadmin (192.40.222.55:443) and
  svn.fishingplanet.com all blocked from the HOST, and svn blocked from the CONTAINER too. Restored our
  plug (defense-in-depth); internet + site unaffected (302 / 200). The load-bearing "VM cannot reach the
  farm" control now lives on the network firewall, not only on the root-removable host rule.
- 2026-07-22: Farm owner won't adopt a key and confirmed `ap` is unneeded. Disabled SSH
  PasswordAuthentication globally (key-only now); verified key login still works on a fresh connection
  before trusting it. Locked `ap` (`passwd -l`) and removed it from sudo. Only `inqui` (keyed) can log
  in now; `yk`/`vk`/`fpwebadmin` have no keys so SSH is closed to them - yk/vk will send public keys to
  add on return. SSH surface = keys + source-IP allowlist + fail2ban. Config mirrored to artifacts.
  Still pending: drop the temporary NOPASSWD sudo for `inqui` (drop-in `90-inqui-setup`) once setup
  work is finished.
- 2026-07-23: Oleksii (Snig) couldn't connect with the original RSA key; added his new ed25519 key
  (`kalyuzhnyi@gmail.com`, SHA256:c7H95X...) to the SFTP authorized_keys with `restrict`, kept the old
  RSA alongside for now (candidate for removal once he's fully switched). Created a live status
  checklist `server-checklist.md` (done / remaining / contractor keys).
- 2026-07-23: Snig connected (178.43.243.226) - old RSA in the morning, new ed25519 at 13:48 UTC (the
  added key works). No content uploaded yet (0 files owned by snig, no `.wpress`, 1 default post). The
  2222 port also draws constant internet bruteforce (~338 preauth fails/3d) - all rejected (AllowUsers
  snig + key-only + no passwords); offered to restrict 2222 to Snig's IP.
- 2026-07-23: Farm owner insisted on a strict fail2ban policy - set 2 failures within 1h -> 1-year ban
  on both jails (sshd:22, sshd-sftp:2222); recovery via hypervisor console or an alternate source IP.
  Risk with key-only login: an ssh client offering several agent keys can self-ban before the right one;
  mitigated by IdentitiesOnly on our side. **Snig must use a single specified key** or they hit a
  1-year ban. Verified own key login still works after the change. Server is UTC (Etc/UTC).
- 2026-07-23: Immediately relaxed the ban policy back (10 tries / 15-min ban) while Snig are actively
  uploading, to avoid them self-locking for a year via a multi-key client. The strict 2/1-year policy
  is to be re-applied after the contractor handover (tracked in the checklist/backlog).
- 2026-07-23: Built a contractor "toolbox" console (Oleksii asked for shell/WP-CLI/db access). No host
  shell: a long-lived `fp-main-website-toolbox` container (`wordpress:cli`, runs as www-data:webdata,
  only the webroot + db network, isolated like the rest) + a dedicated SSH account `snigcli` on :2222
  whose sftp-sshd `Match` forces `sudo /usr/local/bin/toolbox-enter` -> `docker exec` straight into that
  container. `snigcli` is not in docker/sudo; the sudoers entry allows only that one no-arg wrapper.
  Verified with the automation key: lands as uid 33 inside the container (hostname = container id, not
  fpweb), wp-cli 6.9.4 works, internet ok, farm blocked. Same locked-account gotcha as snig fixed
  (`usermod -p '*'`). Automation key added to `snigcli_keys` for testing/support. Confirmed the user's
  own key (`inqui@fpweb-putty`) is in inqui's authorized_keys - inqui key login works. Files mirrored
  to artifacts (`toolbox-enter` lives in /usr/local/bin, outside etckeeper, like backup-apps.sh).
- 2026-07-23: Fixed toolbox DB access (two bugs). (1) The toolbox container lacked the WORDPRESS_DB_*
  env, so wp-config's `getenv_docker` fell back to sample defaults (host `mysql`, user `example
  username`) - added the env + db_password secret mount. (2) `toolbox-enter` forced `-u 33:1004`,
  which dropped the www-data group (gid 33) needed to read the db secret; removed `-u` so the
  container's own 33:33 + supplementary 1004 (both groups) apply. Verified via a snigcli login:
  id 33 / groups 33,1004; `wp db query` works; direct `mysql -h db -u wordpress -p<secret> --skip-ssl`
  works (server does not require secure transport). Contractor reaches the DB as the site user (not
  root) via wp-cli or the mysql client.
- 2026-07-23: Added phpMyAdmin at Oleksii's request (he asked for it rather than an SSH tunnel).
  `phpmyadmin:5` container (PMA_HOST=db, on front+back, no-new-privileges, farm-blocked), reached via
  the edge on `pma.fishingplanet.com` behind HTTP basic-auth (so scanners never reach phpMyAdmin
  itself), TLS via the wildcard. phpMyAdmin login uses the site DB user (`wordpress`), not root.
  Verified from the workstation: 401 without auth, phpMyAdmin login page with auth, container->farm
  blocked. Basic-auth `snig` / (in the handover note). htpasswd kept out of git (gitignored + purged
  like the certs).
- 2026-07-29: wp2shell (CVE-2026-63030 + CVE-2026-60137, pre-auth RCE, in CISA KEV, public exploits)
  affects WP 6.9.0-6.9.4 - we were on 6.9.4. Updated core to the patched 6.9.5 (backup taken first);
  checksums verify, site 200. IoC check clean: no forged admin (only fpadmin + snig), no unexpected
  users, cron hooks all stock, siteurl/home intact, no PHP in uploads, active plugins ours only - not
  compromised. Root cause we stayed vulnerable: WP-Cron was stalled (all next_run frozen at Jul 21-22)
  because the in-container loopback to the site URL does not resolve behind the reverse proxy, so the
  security auto-update never fired. Fixed: `DISABLE_WP_CRON` + `WP_AUTO_UPDATE_CORE='minor'` in the
  mu-plugin, and a host cron (`/etc/cron.d/wp-cron`) runs `wp cron event run --due-now` every 10 min
  via the toolbox container. Catch-up ran 14 events; events now reschedule forward; core is latest.
- 2026-07-30: Split the WordPress runtime config into one mu-plugin per concern, each on its own
  removable mount so a feature can be killed by dropping its compose line (no code edit):
  `00-mail.php` (SendGrid transport), `01-cron.php` (`DISABLE_WP_CRON`), `02-updates.php`
  (`WP_AUTO_UPDATE_CORE='minor'`). Verified both defines still active in the web container, site 200.
- 2026-07-30: Supply-chain question on core auto-updates weighed. Kept ON: it covers core only
  (plugins/themes stay manual - that's the real WP supply-chain vector), minor/security only, over
  HTTPS with checksum verification, and we just got burned by the opposite failure (stuck on the
  vulnerable 6.9.4 during active exploitation). Compensating controls - container egress allowlist and
  checksum/integrity monitoring with mail alerts - deliberately **deferred until the contractor
  finishes and their access is removed**: only then is traffic representative enough to carve egress
  granularly, and only then is the webroot stable enough that integrity alerts are signal rather than
  noise (constant contractor uploads would drown them).
