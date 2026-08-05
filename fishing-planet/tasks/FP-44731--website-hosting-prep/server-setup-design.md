---
jira: FP-44731
title: Server setup design - isolated multi-app web host
status: draft
type: design
created: 2026-07-18
---
# FP-44731 - Server setup design: isolated multi-app web host

## Goal / scope
Stand up the received bare Linux VM as an **isolated, multi-app web host**. First app: the new
WordPress `fishingplanet.com` (built by Snig). Designed from the start to *also* host, later, the
forum (**Invision Community**) and the wiki (**MediaWiki**) - each isolated from the others and from
the internal farm network. WordPress, Invision and MediaWiki are all PHP + MySQL/MariaDB, so the
per-app pattern is uniform.

## Fixed context (decided)
- **Server:** bare Linux VM.
- **Network isolation - already in place by design:** the VM segment cannot reach the internal farm
  network; only 80/443 exposed outward; shell reachable only from the internal network. The inward
  block is load-bearing and confirmed by the network owner.
- **Public surface = dynamic WordPress** (nginx + uploads + DB + server-side form email) -> dynamic-WP
  hardening is required, not optional.
- **Content delivery:** Snig upload their site themselves via chroot-SFTP and manage WP/content.
- **DNS:** controlled by us. Pre-cutover testing via hosts-file; real DNS flip at cutover.
- **Email:** via the existing SendGrid account, scoped Mail-Send API key (not corporate-mail creds).
  SPF already includes `sendgrid.net`.
- **Execution model:** configured directly over SSH as a sudo user (no root login); VM snapshot before
  start; pause for confirmation before any irreversible step (firewall lockout risk, DNS cutover).

## Architecture - isolated multi-app host
**Docker Compose, one stack per app.** A single **front nginx reverse proxy** terminates TLS and routes
by hostname:
- `fishingplanet.com` / `www` -> `wordpress` stack
- `forum.fishingplanet.com` -> `invision` stack (later)
- `wiki.fishingplanet.com` -> `mediawiki` stack (later)

**Per-app stack (uniform):**
- app web+php: nginx + php-fpm serving only that app's files
- db: a dedicated MariaDB container, dedicated database + user
- volumes: app code, uploads, db data - per app
- network: a dedicated Docker network per app. The front proxy joins each app's front-facing network,
  but each app's DB sits on an app-internal network only. Result: the WP container cannot reach the
  forum/wiki DBs, and vice versa.

**Host baseline:**
- Docker Engine + Compose plugin
- deploy user (sudo), key-only SSH, no root SSH login
- host firewall (nftables/ufw) as a second layer over the network firewall: inbound 443 (+ 80 for
  ACME/redirect), SSH from the internal network only, the SFTP port IP-allowed to Snig
- fail2ban on SSH / SFTP / wp-login

## TLS, DNS, staging, cutover
- **Certificate: the purchased GlobalSign wildcard** `*.fishingplanet.com`, exported from the previous
  IIS host and installed on the edge (valid to 2026-11-03). It covers the apex, `www` and the future
  `forum.`/`wiki.` names. *Superseded the original plan of pre-issuing via ACME DNS-01: no DNS API
  credentials exist or will exist, because the domain is controlled personally by the CEO.*
- Front proxy = **nginx**, terminating TLS for every hostname.
- **Renewal after cutover:** switch to acme.sh over **HTTP-01** on the VM, which needs no DNS access at
  all once the domain resolves here.
- **Staging = hosts-file:** testers map `fishingplanet.com` -> VM IP locally; the wildcard is a real
  certificate for that name, so they get valid TLS with no public exposure and no staging hostname.
- **Cutover:** flip apex/`www` A-records to the VM; verify legal URLs + transactional emails; keep
  `live.fishingplanet.com` untouched (separate distribution host, out of scope).

## Content-in (Snig)
- **chroot-SFTP** account, jailed to the WordPress webroot bind-mount; no interactive shell; key-based;
  time-boxed; removed / credentials rotated after handoff. *Source-IP restriction was dropped while the
  contractor works - key-only plus the chroot carry it, and their address list was not fixed.*
- **DB import:** SFTP alone cannot import a DB. In practice the contractor pulled the source database
  with their own migration plugin, which also replaced the WordPress user table - locally created
  accounts have to be recreated after each import.
- **Console access:** a long-lived `wordpress:cli` container the contractor reaches over SSH through a
  forced command, giving WP-CLI, file and database access as the web user with no host shell.
- **phpMyAdmin** on its own hostname behind HTTP basic auth at the edge, signing in as the site
  database user, never root. *Both of these are working aids and are removed at handover.*

## Hardening
- Network isolation (done) + per-app container isolation (app-to-app).
- **Egress: default-deny outbound + allowlist** (OS package repos, SendGrid API, ACME/DNS API,
  WordPress core/plugin update hosts).
- **wp-admin / wp-login:** restricted by source-IP allowlist (our admin ranges + Snig), not open public.
- WordPress mail via **SendGrid** using the scoped key (SMTP or API plugin), not corporate-mail creds.
- Backups & recovery: VM snapshot before/after setup; automated per-app backups (DB dump + volumes)
  shipped off-box; automatic security updates on the host; minimal plugins; review Snig-uploaded
  plugins/themes (supply chain) post-upload.

## Verification (per phase)
- **Routing/TLS:** curl each hostname; validate the certificate chain and SAN.
- **Email:** send a test WP mail through SendGrid; confirm delivery + DKIM pass.
- **Legal URLs:** confirm the preserved apex paths (ToS/Privacy/rules for both F2P and Retail) resolve,
  not 404.
- **Isolation proofs:**
  - from the VM, attempt to reach an internal-farm host -> must fail (inward block)
  - egress to a non-allowlisted host -> must fail (default-deny)
  - from the WP container, attempt to reach the forum/wiki DB -> must fail (app-to-app isolation)

## Prerequisites (all obtained unless noted)
- SSH access, VM specs, SendGrid DKIM and a scoped Mail-Send key - done.
- Certificate: taken from the previous IIS host, so no DNS credentials were ever needed.
- Still open: a target machine for off-box backup copies; the contractor's address ranges if we decide
  to restrict their endpoints before handover.
- (Later, for the forum and wiki) Invision licence; current forum/wiki hosting and data exports.

## Out of scope
- `live.fishingplanet.com` (separate game-build distribution host).
- Legal-document content corrections (deferred; publish as-is now).
- Forum/wiki migration execution (designed-for now, executed later).
