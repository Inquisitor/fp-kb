---
jira: FP-44731
title: Server setup implementation plan - isolated multi-app web host
status: draft
type: plan
created: 2026-07-20
spec: ../server-setup-design.md
---
# Server Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan
> task-by-task over SSH. Steps use checkbox (`- [ ]`) syntax for tracking. This is a *server runbook*:
> "tests" are verification commands run on the VM, "commits" are git commits in the VM's config repos
> (`/etc` via etckeeper, `/srv/apps` via plain git).

**Goal:** Stand up the bare Linux VM as an isolated multi-app web host serving the new WordPress
`fishingplanet.com`, ready to later add the Invision forum and MediaWiki as sibling isolated stacks.

**Architecture:** Docker Compose, one stack per app; a front nginx container terminates TLS (acme.sh
DNS-01, cert pre-issued for the apex) and routes by hostname; per-app Docker networks isolate apps
from each other; host firewall + egress default-deny on top of the already-inplace network isolation.

**Tech Stack:** Ubuntu/Debian (verify in Task 1), Docker Engine + Compose plugin, nginx:alpine,
wordpress:fpm, mariadb, acme.sh, OpenSSH internal-sftp, nftables, fail2ban, etckeeper.

## Global Constraints

- The VM must never be able to reach the internal farm network (network firewall does this; never add
  routes/tunnels that bypass it).
- Public inbound surface: 443 (+80 redirect/ACME) only; SSH only from the internal network; SFTP
  (port 2222) only from Snig's IPs.
- Egress: default-deny + allowlist (Task 8) - applies to host AND containers.
- `wp-admin`/`wp-login.php` never open to the general public - IP-allowlisted.
- No corporate-mail credentials on the VM - SendGrid scoped key only.
- Secrets (DB passwords, API keys) live in root-owned files `chmod 600`, never in compose files or
  the config git repos (`.gitignore` them).
- Before any step that can cut off access (sshd restart, firewall apply) - confirm with the user and
  keep the current SSH session open while testing a second connection.
- `live.fishingplanet.com` is out of scope - never touched.
- User-gated actions (marked **GATE**): VM snapshots, network-firewall change requests, DNS changes.

## Runtime variables (filled in Task 0)

| Var | Meaning |
|---|---|
| `$VM_IP` | VM address reachable from the internal network |
| `$DEPLOY_USER` | sudo user for setup (existing or created in Task 2) |
| `$ADMIN_CIDR` | internal/admin source ranges for SSH and wp-admin allow |
| `$SNIG_IPS` | Snig's fixed egress IPs (SFTP + wp-admin allow) |
| `$DNS_PROVIDER` | DNS provider + acme.sh dns hook name (e.g. `dns_cf`) + API credentials |
| `$SENDGRID_KEY` | scoped Mail-Send API key (Task 6; can arrive later) |

---

## Execution status (updated 2026-07-21)

- **Task 0 Access** - DONE (SSH keys in keystores/fpweb, temp NOPASSWD sudo; snapshot waived).
- **Task 1 Recon** - DONE (Ubuntu 24.04, 4 vCPU / 8 GB; isolation pre-proof FAILED -> temp host plug).
- **Task 2 Host baseline** - DONE (default-deny fw, SSH allowlist, sshd hardening, unattended-upgrades,
  fail2ban 10/15m, etckeeper). Deviation: PasswordAuthentication kept ON (ap/fpwebadmin have no keys).
- **Task 3 Docker** - DONE (29.6.2 + Compose v5.3.1).
- **Task 4 App stack** - DONE, renamed `wordpress` -> **fp-main-website** (nginx+fpm+MariaDB, per-app nets).
- **Task 5 Edge + TLS** - DONE, but via the **purchased GlobalSign wildcard from IIS**, not acme.sh
  DNS-01 (no DNS API token - CEO-controlled domain). Post-cutover renewal -> HTTP-01.
- **Task 6 WP bootstrap** - PARTIAL: `wp core install` done (admin fpadmin); **SendGrid still TODO**.
- **Task 7 chroot-SFTP** - DONE (:2222, Snig key installed). Deviation: source-IP restriction skipped
  pre-live (user). Under authorized pentest (Codex + own audit) 2026-07-21.
- **Task 8 Egress deny** - TODO (experiment after Snig upload).
- **Task 9 Backups** - TODO (GATE before Snig content lands).
- **Task 10 Verify + handoff / Task 11 Cutover** - TODO. HARD GATE: farm-side firewall block.

---

### Task 0: Prerequisites & access check

**Files:** none (checklist).
**Produces:** all runtime variables above; working SSH session.

- [ ] **Step 1:** Obtain SSH access: user adds our public key on the VM (or hands credentials).
- [ ] **Step 2:** Verify login: `ssh $DEPLOY_USER@$VM_IP 'id && hostname'` - expect uid + hostname, no
  password prompts on key auth.
- [ ] **Step 3:** Collect `$ADMIN_CIDR`, `$SNIG_IPS` (ask Snig for fixed egress IPs), `$DNS_PROVIDER`
  + API token (for DNS-01), SendGrid account access.
- [x] **Step 4 (GATE, revised 2026-07-20):** pre-setup snapshot WAIVED by the user - the server is
  empty and the runbook + on-box config git (etckeeper) make the setup reproducible from scratch;
  hypervisor console access exists (farm owner). The gate MOVES to: **snapshots or verified pull-based
  backups (Task 9) must exist before any contractor content lands on the box.**

### Task 1: Recon

**Files:** record results in this plan / journal.
**Produces:** distro/version, resources, network picture; go/no-go for the apt-based commands below.

- [ ] **Step 1:** `cat /etc/os-release; uname -r` - expect Ubuntu 22.04+/Debian 12+. **If RHEL-family
  or other: STOP**, adapt package commands before continuing.
- [ ] **Step 2:** `nproc; free -h; df -h /` - sanity vs. hosting WordPress + Invision + MediaWiki
  later (guideline: >=4 vCPU, >=8 GB RAM, >=80 GB disk; flag to the user if below).
- [ ] **Step 3:** `ip -br a; ip r` - record interfaces/routes.
- [ ] **Step 4 (isolation pre-proof):** from the VM, try one known internal-farm address:
  `timeout 5 bash -c 'curl -sS http://<internal-host>' ; echo rc=$?` - expect timeout/unreachable
  (rc != 0). If it CONNECTS - **STOP**, the inward block is not in place; escalate to the network
  owner before installing anything.
- [ ] **Step 5:** `sudo ss -tlnp` - record already-listening services; nothing should be publicly
  exposed yet.

### Task 2: Host baseline

**Files:** `/etc/ssh/sshd_config.d/10-hardening.conf`, `/etc/fail2ban/jail.local`; etckeeper repo.

- [ ] **Step 1:** Update + base tools:
  `sudo apt update && sudo apt -y full-upgrade && sudo apt -y install etckeeper git fail2ban nftables unattended-upgrades curl jq`
- [ ] **Step 2:** etckeeper auto-inits a git repo in `/etc` (`sudo etckeeper vcs status` to confirm).
- [ ] **Step 3:** If no personal sudo user exists: `sudo adduser --disabled-password deploy && sudo usermod -aG sudo deploy`,
  install our SSH key in `~deploy/.ssh/authorized_keys` (mode 700/600).
- [ ] **Step 4:** Write `/etc/ssh/sshd_config.d/10-hardening.conf`:

```
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowUsers deploy
```

- [ ] **Step 5 (confirm-gate):** `sudo sshd -t` (must be silent), then `sudo systemctl reload ssh`
  **while keeping this session open**; verify a NEW ssh connection works before closing anything.
- [ ] **Step 6:** `/etc/fail2ban/jail.local`: enable `[sshd]` (defaults are fine:
  `bantime = 1h`, `maxretry = 5`); `sudo systemctl enable --now fail2ban`;
  verify `sudo fail2ban-client status sshd` shows the jail.
- [ ] **Step 7:** Enable unattended security updates:
  `sudo dpkg-reconfigure -f noninteractive unattended-upgrades`; verify
  `/etc/apt/apt.conf.d/20auto-upgrades` has `Unattended-Upgrade "1"`.
- [ ] **Step 8:** Inbound host firewall (nftables, second layer over the network fw) -
  `/etc/nftables.conf` input chain: policy drop; accept `lo`, established/related, icmp,
  22 from `$ADMIN_CIDR` only, 80, 443, 2222 from `$SNIG_IPS` only.
- [ ] **Step 9 (confirm-gate):** `sudo nft -c -f /etc/nftables.conf` (syntax check), confirm with
  user, then `sudo systemctl enable --now nftables`. Verify: new SSH from an admin host works;
  `nft list ruleset` matches intent. (Egress stays open until Task 8.)
- [ ] **Step 10:** Commit: `sudo etckeeper commit "FP-44731: host baseline (ssh hardening, fail2ban, inbound fw, auto-updates)"`

### Task 3: Docker

**Files:** `/etc/apt/sources.list.d/docker.list`; etckeeper.

- [ ] **Step 1:** Install per official repo:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update && sudo apt -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

  (Debian: replace `ubuntu` with `debian` in both URLs.)
- [ ] **Step 2:** Verify: `sudo docker run --rm hello-world` prints "Hello from Docker".
- [ ] **Step 3:** `sudo usermod -aG docker deploy` (re-login to pick up the group).
- [ ] **Step 4:** Commit: `sudo etckeeper commit "FP-44731: docker engine + compose"`.

### Task 4: WordPress stack

**Files (create):** `/srv/apps/fp-main-website/compose.yml`, `/srv/apps/fp-main-website/nginx/wp.conf`,
`/srv/apps/fp-main-website/secrets/{db_password,db_root_password}`, `/srv/apps/.gitignore`.
**Produces:** app stack `fp-main-website-nginx` (nginx) + `fp-main-website-php` (php-fpm) + `fp-main-website-db` (MariaDB) on networks
`fp-main-website_front` (shared with proxy) / `fp-main-website_back` (app-private); webroot volume `/srv/apps/fp-main-website/html`.

- [ ] **Step 1:** Layout + config repo:

```bash
sudo mkdir -p /srv/apps/fp-main-website/{nginx,secrets,html}
cd /srv/apps && sudo git init -b main
printf '%s\n' '*/secrets/' '*/html/' | sudo tee /srv/apps/.gitignore
sudo docker network create fp-main-website_front
```

- [ ] **Step 2:** Secrets:
  `sudo sh -c 'openssl rand -base64 24 > /srv/apps/fp-main-website/secrets/db_password'` (same for
  `db_root_password`); `sudo chmod 700 /srv/apps/fp-main-website/secrets && sudo chmod 600 /srv/apps/fp-main-website/secrets/*`.
- [ ] **Step 3:** `/srv/apps/fp-main-website/compose.yml`:

```yaml
services:
  web:
    image: nginx:1.27-alpine
    container_name: fp-main-website-nginx
    restart: unless-stopped
    volumes:
      - ./html:/var/www/html:ro
      - ./nginx/wp.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on: [php]
    networks: [fp-main-website_front, fp-main-website_back]
  php:
    image: wordpress:6-fpm
    container_name: fp-main-website-php
    restart: unless-stopped
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
    volumes:
      - ./html:/var/www/html
      - ./secrets/db_password:/run/secrets/db_password:ro
    networks: [fp-main-website_back]
  db:
    image: mariadb:11.4
    container_name: fp-main-website-db
    restart: unless-stopped
    environment:
      MARIADB_DATABASE: wordpress
      MARIADB_USER: wordpress
    volumes:
      - db_data:/var/lib/mysql
      - ./secrets/db_password:/run/secrets/db_password:ro
      - ./secrets/db_root_password:/run/secrets/db_root_password:ro
    networks: [fp-main-website_back]
volumes:
  db_data: {}
networks:
  fp-main-website_front: {external: true}
  fp-main-website_back: {}
```

  Plus env `WORDPRESS_DB_PASSWORD_FILE: /run/secrets/db_password` on `php`, and
  `MARIADB_PASSWORD_FILE` / `MARIADB_ROOT_PASSWORD_FILE` pointing at the mounted secret files on `db`
  (both images support `_FILE` variants). No `ports:` anywhere in this stack - only the front proxy
  publishes ports.
- [ ] **Step 4:** `/srv/apps/fp-main-website/nginx/wp.conf`:

```nginx
server {
    listen 80;
    server_name fishingplanet.com www.fishingplanet.com;
    root /var/www/html;
    index index.php;
    client_max_body_size 512m;

    location / { try_files $uri $uri/ /index.php?$args; }
    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
    # never execute uploaded PHP
    location ~* /uploads/.*\.php$ { deny all; }
    location ~ /\.(?!well-known) { deny all; }
}
```

- [ ] **Step 5:** Start: `cd /srv/apps/fp-main-website && sudo docker compose up -d`; expect `web`, `php`,
  `db` all `Started`; `sudo docker compose ps` shows 3 running; `html/` gets populated with WP core
  by the php image on first start.
- [ ] **Step 6:** Verify from host: `curl -sS -H 'Host: fishingplanet.com' http://$(sudo docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}} {{end}}' fp-main-website-nginx | awk '{print $1}')/ | head -5`
  - expect WP install-wizard HTML (redirect to `/wp-admin/install.php` is fine).
- [ ] **Step 7:** Commit: `cd /srv/apps && sudo git add -A && sudo git commit -m "FP-44731: wordpress stack (nginx+fpm+mariadb, per-app networks)"`.

### Task 5: Front proxy + TLS (DNS-01)

**Files (create):** `/srv/apps/proxy/compose.yml`, `/srv/apps/proxy/conf.d/fishingplanet.conf`,
`/srv/apps/proxy/snippets/proxy.conf`, certs in `/srv/apps/proxy/certs/`.
**Consumes:** `fp-main-website-nginx` on `fp-main-website_front`. **Produces:** public 80/443; valid TLS for the apex.

- [ ] **Step 1:** Install acme.sh (host): `curl https://get.acme.sh | sh -s email=admin@fishingplanet.com`
- [ ] **Step 2:** Export `$DNS_PROVIDER` API credentials (per acme.sh dnsapi docs for the provider),
  then issue **without touching A-records**:
  `~/.acme.sh/acme.sh --issue --dns $DNS_PROVIDER -d fishingplanet.com -d www.fishingplanet.com`
  - expect "Cert success". This proves domain control via TXT records only.
- [ ] **Step 3:** Install cert to the proxy dir with auto-reload:

```bash
sudo mkdir -p /srv/apps/proxy/{conf.d,snippets,certs}
~/.acme.sh/acme.sh --install-cert -d fishingplanet.com \
  --fullchain-file /srv/apps/proxy/certs/fishingplanet.com.fullchain.pem \
  --key-file       /srv/apps/proxy/certs/fishingplanet.com.key.pem \
  --reloadcmd      "docker exec edge-nginx nginx -s reload"
```

- [ ] **Step 4:** `/srv/apps/proxy/snippets/proxy.conf`:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

- [ ] **Step 5:** `/srv/apps/proxy/conf.d/fishingplanet.conf`:

```nginx
server {
    listen 80;
    server_name fishingplanet.com www.fishingplanet.com;
    return 301 https://$host$request_uri;
}
server {
    listen 443 ssl;
    http2 on;
    server_name fishingplanet.com www.fishingplanet.com;
    ssl_certificate     /etc/nginx/certs/fishingplanet.com.fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/fishingplanet.com.key.pem;
    client_max_body_size 512m;

    # admin surface: allowlisted only (admin-ajax stays public for front-end features)
    location ^~ /wp-admin/admin-ajax.php { include snippets/proxy.conf; proxy_pass http://fp-main-website-nginx; }
    location ~ ^/(wp-login\.php|wp-admin) {
        allow $ADMIN_CIDR;   # expand to real allow lines
        allow $SNIG_IPS;     # one allow line per IP/range
        deny all;
        include snippets/proxy.conf;
        proxy_pass http://fp-main-website-nginx;
    }
    location / { include snippets/proxy.conf; proxy_pass http://fp-main-website-nginx; }
}
```

- [ ] **Step 6:** `/srv/apps/proxy/compose.yml`:

```yaml
services:
  nginx:
    image: nginx:1.27-alpine
    container_name: edge-nginx
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./snippets:/etc/nginx/snippets:ro
      - ./certs:/etc/nginx/certs:ro
    networks: [fp-main-website_front]
networks:
  fp-main-website_front: {external: true}
```

- [ ] **Step 7:** `cd /srv/apps/proxy && sudo docker compose up -d`; verify from an internal admin
  machine with a hosts-entry `fishingplanet.com -> $VM_IP`:
  `curl -sSI https://fishingplanet.com/` - expect `HTTP/2 200` (or 302 to install wizard) and a
  **valid** Let's Encrypt cert (no `-k` needed); `curl -sSI http://fishingplanet.com/` - expect 301.
- [ ] **Step 8:** Verify the admin gate: request `/wp-login.php` from a non-allowlisted source -
  expect `403`; from `$ADMIN_CIDR` - expect the login page (200).
- [ ] **Step 9:** Commit `/srv/apps` ("FP-44731: edge proxy + TLS (acme.sh DNS-01, wp-admin gate)").

### Task 6: WordPress bootstrap + SendGrid

**Consumes:** running stack + proxy. **Produces:** installed WP core, admin account, mail via SendGrid.

- [ ] **Step 1:** Complete the WP install wizard (site title "Fishing Planet", our admin account,
  strong generated password -> hand to the user out-of-band; discourage `admin` as username).
- [ ] **Step 2:** Set `WP_HOME`/`WP_SITEURL` to `https://fishingplanet.com` and the
  reverse-proxy HTTPS hint in `wp-config.php` (via `WORDPRESS_CONFIG_EXTRA` env in compose):

```php
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') { $_SERVER['HTTPS'] = 'on'; }
define('WP_HOME', 'https://fishingplanet.com');
define('WP_SITEURL', 'https://fishingplanet.com');
define('DISALLOW_FILE_EDIT', true);
```

- [ ] **Step 3:** SendGrid: in the SendGrid account confirm **domain authentication (DKIM)** for
  `fishingplanet.com`; create a **scoped Mail-Send-only API key**; store nowhere on disk except the
  WP plugin config.
- [ ] **Step 4:** Install a mail plugin (WP Mail SMTP), configure SendGrid (API key), sender
  `noreply@fishingplanet.com`.
- [ ] **Step 5:** Verify: send the plugin's test email to our mailbox - expect delivery with
  `dkim=pass` for `fishingplanet.com` in the received headers.
- [ ] **Step 6:** Snapshot note in journal; commit any compose change from Step 2.

### Task 7: chroot-SFTP for Snig

**Files:** `/etc/ssh/sshd_sftp_config` (second sshd instance, port 2222),
`/etc/systemd/system/sshd-sftp.service`; user `snig`.
**Produces:** Snig can upload into the WP webroot and nothing else; no shell.

- [ ] **Step 1:** User + jail. The chroot dir must be root-owned; the writable webroot is bind-mounted
  one level down:

```bash
sudo useradd -M -d /srv/sftp/snig -s /usr/sbin/nologin snig
sudo mkdir -p /srv/sftp/snig/html
sudo chown root:root /srv/sftp/snig && sudo chmod 755 /srv/sftp/snig
echo '/srv/apps/fp-main-website/html /srv/sftp/snig/html none bind 0 0' | sudo tee -a /etc/fstab && sudo mount -a
sudo chown -R www-data:www-data /srv/apps/fp-main-website/html   # uid/gid 33 = container www-data
sudo usermod -g www-data snig
sudo find /srv/apps/fp-main-website/html -type d -exec chmod 2775 {} +
```

  Install Snig's SSH public key in `/srv/sftp/snig_keys/authorized_keys` (root-owned, outside jail).
- [ ] **Step 2:** `/etc/ssh/sshd_sftp_config` - a **separate sshd instance** so the public SFTP
  endpoint shares nothing with admin SSH:

```
Port 2222
PidFile /run/sshd-sftp.pid
AllowUsers snig
AuthorizedKeysFile /srv/sftp/snig_keys/authorized_keys
PasswordAuthentication no
PermitRootLogin no
ChrootDirectory /srv/sftp/snig
ForceCommand internal-sftp -u 0002
AllowTcpForwarding no
X11Forwarding no
```

- [ ] **Step 3:** systemd unit `sshd-sftp.service` (`ExecStart=/usr/sbin/sshd -D -f /etc/ssh/sshd_sftp_config`);
  `sudo systemctl enable --now sshd-sftp`. Host fw already limits 2222 to `$SNIG_IPS` (Task 2).
- [ ] **Step 4 (GATE):** Request the **network firewall** open 2222 from `$SNIG_IPS` only (inbound),
  alongside the existing 80/443.
- [ ] **Step 5:** Verify: `sftp -P 2222 -i <snig_test_key> snig@<public-ip>` from an allowed IP -
  lands in `/` (jail), can `cd html && put test.txt`, **cannot** see anything above; `ssh -p 2222
  snig@...` gets no shell. From a non-allowed IP - connection refused/timeout.
  On the host: `ls -l /srv/apps/fp-main-website/html/test.txt` shows group `www-data`, mode 664; then
  delete the test file.
- [ ] **Step 6:** Add `[sshd]`-style fail2ban jail for port 2222; etckeeper commit
  ("FP-44731: chroot-SFTP endpoint for contractor uploads").

### Task 8: Egress default-deny + allowlist

**Files:** `/etc/nftables.conf` (egress sets + rules), `/usr/local/sbin/refresh-egress-allowlist.sh`,
cron entry. **Produces:** host + containers can only reach allowlisted destinations.

- [ ] **Step 1:** Build the domain allowlist (resolved to nft sets by the refresh script):
  distro mirrors (`archive.ubuntu.com`, `security.ubuntu.com` - adjust per Task 1), Docker Hub
  (`registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com`), WP updates
  (`api.wordpress.org`, `downloads.wordpress.org`), SendGrid (`api.sendgrid.com`,
  `smtp.sendgrid.net`), ACME (`acme-v02.api.letsencrypt.org`) + the DNS provider's API host.
- [ ] **Step 2:** `/usr/local/sbin/refresh-egress-allowlist.sh` - resolves each domain, feeds
  `nft add element inet filter egress_allow_v4 {...}`; cron `*/30 * * * *`. (IPs of CDNs rotate -
  the refresh keeps the sets warm; log misses to syslog.)
- [ ] **Step 3:** nftables egress rules - **host** (`chain output`): policy drop; accept lo,
  established, DNS to the configured resolvers only, NTP, tcp 80/443/587 to `@egress_allow_v4`;
  **containers** (`chain forward` / DOCKER-USER equivalent): same accept set for traffic originating
  from the Docker bridges; established/related both ways.
- [ ] **Step 4 (confirm-gate + GATE):** dry-run `nft -c`, confirm with the user (this is the step
  most likely to break something), apply, keep session open.
- [ ] **Step 5:** Verify:
  - `curl -sS --max-time 5 https://api.wordpress.org/core/version-check/1.7/` -> 200 (allowed)
  - `curl -sS --max-time 5 https://example.com` -> timeout (blocked)
  - same pair from inside a container: `sudo docker exec fp-main-website-php curl ...`
  - `sudo apt update` still works; `sudo docker pull hello-world` still works.
- [ ] **Step 6:** etckeeper commit ("FP-44731: egress default-deny + allowlist (host + docker)").

### Task 9: Backups

**Files:** `/usr/local/sbin/backup-apps.sh`, cron entry. **Produces:** nightly local dumps; pull
instructions for an internal machine (the VM cannot push inward - by design).

- [ ] **Step 1:** `/usr/local/sbin/backup-apps.sh`:

```bash
#!/bin/sh
set -eu
STAMP=$(date +%F)
DEST=/srv/backups/$STAMP
mkdir -p "$DEST"
docker exec fp-main-website-db sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/db_root_password)" --single-transaction wordpress' | gzip > "$DEST/wordpress-db.sql.gz"
tar -C /srv/apps/fp-main-website -czf "$DEST/wordpress-html.tar.gz" html
find /srv/backups -maxdepth 1 -mtime +7 -exec rm -rf {} +
```

  `chmod 700`; cron `10 3 * * * root /usr/local/sbin/backup-apps.sh`.
- [ ] **Step 2:** Run once by hand; verify `zcat .../wordpress-db.sql.gz | head -5` shows SQL and the
  tar lists `html/wp-config.php`.
- [ ] **Step 3:** Document the pull side (journal + note to the user): an internal machine pulls
  `/srv/backups/` nightly via `rsync -a --delete deploy@$VM_IP:/srv/backups/ <local-dir>` (key-based;
  internal->VM SSH is allowed by design). Confirm with the user who owns that pull job.
- [ ] **Step 4:** etckeeper commit ("FP-44731: nightly app backups + retention").

### Task 10: Final verification & handoff

**Produces:** verified stand; Snig unblocked; post-setup snapshot.

- [ ] **Step 1:** Full verification pass, all from the checklist:
  - routing/TLS: `curl -sSI https://fishingplanet.com/` (hosts-entry) - 200/302, valid cert chain;
  - admin gate: 403 from non-allowlisted / 200 from `$ADMIN_CIDR`;
  - inward isolation: internal-farm address unreachable from VM and from `fp-main-website-php`;
  - app isolation: `sudo docker exec fp-main-website-php getent hosts fp-main-website-db` resolves, but a probe container on a
    fresh network cannot reach `fp-main-website-db` (`docker run --rm --network fp-main-website_front alpine nc -zw3 fp-main-website-db 3306`
    -> fails; `fp-main-website-db` is only on `fp-main-website_back`);
  - egress: allowed hosts pass, others blocked (host + container);
  - SFTP jail: upload lands in webroot, no shell, IP-restricted;
  - mail: test email `dkim=pass`.
- [ ] **Step 2 (GATE):** User takes the **"post-setup" VM snapshot**.
- [ ] **Step 3:** Hand Snig (via the agreed channel): SFTP endpoint `<public-ip>:2222` + their key
  setup, hosts-file staging instructions (`fishingplanet.com -> <public-ip>` - NB: staging tests go
  to the public IP, which serves valid TLS), `web-2026-07-07-clean-v3.zip`, the keep-set URL list,
  and the requirement that every kept URL resolves (same path or 301) on the new site.
- [ ] **Step 4:** Journal milestone + backlog updates in KB; JIRA FP-44731 status/comment (drafted
  for approval first, per jira-post-preview).

### Task 11 (LATER, separate session): DNS cutover

Gated checklist - not executed as part of the setup:

- [ ] Snig confirms content complete; final verification pass (Task 10 list) green on staging.
- [ ] Fresh backup + snapshot; lower apex/`www` TTL to 300 in advance.
- [ ] **(GATE)** Flip `fishingplanet.com` + `www` A-records to the public IP. `live.` untouched.
- [ ] Verify from the outside: TLS, homepage, the kept legal URLs for F2P + Retail paths
  (spot-check `gamerules.htm`, `/xbox/privacy/`, `/console/tos/`, `/consoler/`, `/pcr/`), a
  transactional email, `.well-known/apple-app-site-association` + `microsoft-identity-association.json`.
- [ ] Watch logs/fail2ban for the first days; then rotate the SFTP credentials / close 2222 (GATE)
  when Snig's upload window ends.

### Appendix: adding Invision / MediaWiki later (pattern, not executed now)

Each new app repeats the Task 4 pattern under `/srv/apps/<app>/`: own compose stack (`<app>-web` +
php + own MariaDB), own `<app>_back` network, own `<app>_front` network joined by `edge-nginx`, own
server block in `/srv/apps/proxy/conf.d/` (`forum.fishingplanet.com` / `wiki.fishingplanet.com`),
cert extended via acme.sh (add `-d`), own backup lines in `backup-apps.sh`, own secrets dir.
App-to-app isolation holds because stacks share no networks: the proxy joins each `<app>_front`;
DBs live only on their app's `_back`.
