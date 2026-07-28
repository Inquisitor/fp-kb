# FP-44731 Backlog

## Immediate
- [x] Clean & verify the site dump (secrets/PII removed: `ap/` private key, 156 MB IIS log with IPs,
  QRfy JS; `web.config` no secrets). Deliverable = clean zip `web-2026-07-07-clean.zip` (~297 files)
- [x] Produce the client-facing page/URL inventory (`artifacts/web-accessible-urls-grouped-2026-07-07.xlsx`,
  100 HTML pages, F2P/Retail tabs grouped by folder; descriptions validated by reading each file)
- [x] CS-lead relevance review done (2026-07-07): drop only the six old homepage variants
  (`fp_beta.html`, `old.html`, `new.html`, `Index_old.html`, `index_preapple.html`, `i.html`); keep
  everything else - legal/rules pages are current, published as-is (13/7 age discrepancy accepted)
- [ ] Hand Snig `web-2026-07-07-clean-v3.zip` (= v2 minus the six dropped homepage stubs, 272 entries)
  + the keep-set; every kept URL must be preserved at the same path or 301'd on the new site. 301
  targets finalized once Snig defines the new URL structure; the six dropped stubs can 404 or 301 to `/`
- [x] Reply to Snig sent (2026-07-07): direct access to the internal-network site declined; archive +
  URL list offered instead - Snig agreed. Email handled via SendGrid, not shared corporate-mail creds
- [x] Required-dynamic-features question answered by Snig's asks (nginx + uploads + DB + form email)
  -> dynamic WordPress; static-publish now unlikely

## Implementation
- [x] Provision + baseline the dedicated VM (`fpweb`, 162.222.23.28, Ubuntu 24.04): default-deny nft
  firewall, SSH source-IP allowlist (office/VPN/WG), sshd hardening, unattended-upgrades, fail2ban,
  etckeeper, Docker. Inward isolation currently via a temporary host-level nft plug - the real
  farm-side block is the HARD GATE below
- [x] **HARD GATE cleared (2026-07-22):** farm owner closed the VM subnet off at the farm-side
  firewall. Verified with our host plug removed: host + container both blocked from svn/webadmin. The
  host nft plug stays as defense-in-depth. Still worth confirming from the farm owner: hypervisor
  console access, and external filtering of 22/tcp + IPv6 parity
- [x] Host access hygiene: personal devops accounts `yk`/`vk` created; SSH PasswordAuthentication
  disabled globally (key-only, verified); `ap` (farm owner - won't use a key, said unneeded) locked +
  removed from sudo. Remaining: add `yk`/`vk` public keys when they send them (and their source IPs to
  the SSH allowlist if outside office/VPN); optionally retire `fpwebadmin` (shared, now keyless);
  drop the temporary NOPASSWD sudo for `inqui` (`90-inqui-setup`) once setup work is done.
- [x] Stand up the SFTP upload channel for Snig (dedicated sshd on :2222, chroot to the webroot,
  no shell, key-only, fail2ban jail; Snig's key installed). Source-IP restriction intentionally
  skipped pre-live (user decision). STILL TODO after handoff: remove/close the endpoint + rotate.
- [ ] Act on the SFTP pentest findings (Codex + own audit, 2026-07-21) - see journal
- [ ] Map and preserve legal & referenced apex URLs (same paths or 301 redirects)
- [ ] Preserve `.well-known/apple-app-site-association` and `.well-known/microsoft-identity-association.json`
  on the new site (iOS universal-link / Microsoft app-identity association)
- [ ] Confirm `live.` distribution is untouched; define the DNS cutover plan
- [ ] Cutover + post-launch verification of legal links and transactional emails

## Email (SendGrid)
- [x] Domain authentication (DKIM) already Verified (`em330.fishingplanet.com`); SPF already has
  `include:sendgrid.net` - no DNS change needed
- [x] Scoped Mail-Send API key issued by the user, stored in the on-server secret file (not in git,
  not handed to Snig); WordPress routes mail via WP Mail SMTP (SendGrid API) from an mu-plugin
- [x] Whitelisted the VM egress IP (162.222.23.28) in SendGrid IP Access Management; test send
  `wp_mail = true`, transport verified end-to-end
- Note: the contractor does NOT get the key - their contact form uses `wp_mail()`, routed via our
  transport automatically

## Content / compliance flags (for the site owner / legal / PM - not an infra fix)
- [ ] **Retail docs are an older generation and need updating** (comparison done - see
  `artifacts/f2p-vs-retail-legal-diff.md`). Same legal entity as F2P (Fishing Planet LLC), so no new
  publisher, but: Privacy is 2018-05-25 (top exposure - weak child-consent, vk.com); EULA/TOS prior-gen
  (min age 13 vs 3, clan/club, PS4-only, missing club-conduct clauses). **Decision (Viktoriya,
  2026-07-07): publish as-is now, correct later** - a doc change needs a change-notification mailout
  that must not delay launch. Deferred follow-up (not this task)
- [ ] Retail bugs found in comparison: `xboxr/eula` shows the F2P "Fishing Planet" brand string (should
  be "The Fisherman"); `xboxr/tos` has a broken unsubstituted support URL (`na.Fishing Planet LLC..net`)
- [x] Fixed in v2: `support@fishingplane.com` (typo, 14 files) -> `support@fishingplanet.com`
- [x] Fixed in v2: `support@fishingbeta.com` (stale, 3 files incl. root `GameRulesPC.htm`) -> `support@fishingplanet.com`
- [ ] `<title>` bug: `consoler/eula` and `xboxr/eula` show a Game Rules title over genuine EULA body
  (not fixed - migrate by body text; correct in the new site's CMS)

## Hardening
- [x] TLS on the edge: purchased GlobalSign wildcard `*.fishingplanet.com` exported from IIS, installed
  on edge-nginx (valid to 2026-11-03). Post-cutover: switch renewal to acme.sh HTTP-01 on the VM
- [x] Auto security updates (unattended-upgrades) on the host
- [ ] Default-deny outbound internet egress from the VM + allowlist (planned as an experiment once
  Snig's upload shows what the site actually needs to reach)
- [ ] Keep `wp-admin` / `wp-login` off public 443 - edge config is ready for an IP gate but it is
  intentionally OFF pre-live (user decision); MUST enable before go-live
- [~] Backups: local nightly done (consistent DB dump + webroot tar, `/srv/backups` root 700, 7-day
  retention, cron at 03:10). TODO: off-box pull from an internal host (VM cannot push inward) - needs
  the source/target machine; plus post-handoff review of uploaded plugins/themes (supply chain)
- [ ] Front-end WAF (Cloudflare or similar) before 80/443 - optional, revisit; DNS is CEO-controlled
- [x] SFTP endpoint hardened after a security review: all forwarding disabled (StreamLocal was the real
  gap - `AllowTcpForwarding no` does not cover it), symlink/hardlink denied, connection/DoS limits,
  `restrict` on the key
- [x] Moved `snig` off the `www-data` primary group (dedicated `webdata` group, gid 1004) + hardened
  the app containers (php `read_only`+tmpfs, minimal caps, `no-new-privileges`, pids/mem limits,
  `group_add` for mutual webroot writes; db cap-dropped)
- [ ] Remaining pre-go-live hardening (ranked): least-privilege DB user + rotate post-handoff;
  restrict port 2222 + key `from=` to Snig IPs; upload into a staging dir rather than the served
  webroot; container egress filter incl. block `169.254.169.254` (folds into the egress task);
  wp-admin IP gate; farm-side firewall (HARD GATE)

## Coordination
- [ ] Flag to the website-project epic owner (FP-40093, currently On Hold) that an infra/security block
  exists and must be unfrozen before launch

## Related
- Parent epic: FP-40093 "[Website] Create Fishing Planet Website" (On Hold)
- Confluence "Websites Research" (page 5262868489) - goals, sitemap, design references, provider
  Snig.digital
