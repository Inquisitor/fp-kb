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
- **Certificates via ACME DNS-01** (we control DNS): pre-issue a real cert for `fishingplanet.com`
  (and later `forum.`/`wiki.`) **without** pointing A-records at the VM. Needs DNS-provider API
  credentials for acme.sh.
- Front proxy = **nginx**; TLS via **acme.sh (DNS-01)** with auto-renew.
- **Staging = hosts-file:** testers map `fishingplanet.com` -> VM IP locally. Because the cert is a real
  DNS-01-issued cert for that exact name, testers get valid TLS with no public exposure and no public
  staging hostname.
- **Cutover:** flip apex/`www` A-records to the VM; verify legal URLs + transactional emails; keep
  `live.fishingplanet.com` untouched (separate distribution host, out of scope).

## Content-in (Snig)
- **chroot-SFTP** account, jailed to the WordPress webroot bind-mount; no interactive shell; key-based;
  source-IP-allow to Snig's egress IPs; time-boxed; removed / credentials rotated after handoff.
- **DB import:** SFTP alone cannot import a DB. Snig upload a WP migration plugin (All-in-One WP
  Migration / Duplicator) via SFTP and import through `wp-admin`. No separate DB admin tool is exposed
  to the internet.

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

## Prerequisites to gather at execution
- SSH access (public key added / credentials) + confirm this workstation reaches the VM shell.
- DNS provider + API credentials for ACME DNS-01.
- Snig's fixed egress IP ranges (SFTP + wp-admin allowlists).
- SendGrid: confirm DKIM domain authentication; issue the scoped Mail-Send key.
- VM specs (RAM/CPU/disk) - verify on the box that it can eventually hold WordPress, Invision and
  MediaWiki together.
- (Later) Invision license; current forum/wiki hosting + data exports for migration.

## Out of scope
- `live.fishingplanet.com` (separate game-build distribution host).
- Legal-document content corrections (deferred; publish as-is now).
- Forum/wiki migration execution (designed-for now, executed later).
