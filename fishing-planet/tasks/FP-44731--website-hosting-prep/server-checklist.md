# FP-44731 Server Setup Checklist

Live status of the isolated web-host build. Detail in `journal.md`; actionable list in `backlog.md`;
config mirror in `artifacts/server-config/`.

## Done

| Item | Status |
|---|---|
| VM baseline | ✅ Ubuntu 24.04, full-upgrade, unattended-upgrades, etckeeper |
| SSH access | ✅ key-only (passwords off), source-IP allowlist, fail2ban; `ap` locked |
| Host firewall (inbound) | ✅ default-deny + allowlist (22 by list, 80/443/2222) |
| Farm isolation (VM->farm) | ✅ farm-side firewall (HARD GATE) verified; host plug as second layer (host + containers) |
| Docker + Compose | ✅ 29.6.2 / v5.3.1 |
| WordPress stack | ✅ nginx + php-fpm + MariaDB, per-app isolated networks, file secrets |
| Edge nginx + TLS | ✅ wildcard `*.fishingplanet.com` (exported from IIS, valid to 2026-11-03) |
| Container hardening | ✅ php `read_only`+tmpfs, `cap_drop`, `no-new-privileges`, pid/mem limits |
| Contractor isolation | ✅ `snig` off `www-data` (dedicated `webdata` group) |
| SFTP endpoint | ✅ chroot, key-only, forwarding off, symlink/hardlink deny, DoS limits |
| Security review + fixes | ✅ StreamLocal forwarding, container egress, farm block in `forward` |
| Backups (local) | ✅ nightly dump + tar, integrity check, 7-day retention |
| Mail (SendGrid) | ✅ DKIM verified, scoped key, transport tested (`wp_mail=true`) |
| Contractor handover | ✅ WP admin `snig`, migration plugin, SFTP access, message sent |
| Contractor toolbox console | ✅ `snigcli` -> `docker exec` into an isolated `wordpress:cli` container (WP-CLI/files/db as www-data, no host shell) |
| phpMyAdmin for the contractor | ✅ `pma.fishingplanet.com` behind edge basic-auth, isolated container, login as the site DB user (not root) |
| Config mirror | ✅ `artifacts/server-config/` |

## Remaining

| Item | Status |
|---|---|
| Snig upload content | ⏳ waiting on them |
| Re-apply strict fail2ban (2 fails -> 1-year ban) | ⏳ after Snig handover (relaxed to 10/15m for now so they don't self-lock) |
| Retire contractor tools (toolbox, phpMyAdmin, `snigcli`) | ⏳ after handover - they are working aids, not for prod (reduce surface) |
| wp-admin IP gate | ⏳ before go-live |
| Least-privilege DB user + rotate | ⏳ before go-live |
| Full egress allowlist on the VM | ⏳ after upload (learn real destinations) |
| Backups off-box pull | ⏳ needs a target machine |
| DNS cutover | ⏳ final, CEO-controlled |
| `yk`/`vk` keys | ⏳ add when sent |
| Drop temporary NOPASSWD for `inqui` | ⏳ after setup work is done |
| Hypervisor console / external 22 / IPv6 parity | ⏳ confirm with the farm owner |
| Front WAF (Cloudflare) | ➖ optional; DNS is CEO-controlled |
| Retire `fpwebadmin` | ➖ optional (shared, now keyless) |

## Contractor SFTP keys (`snig`)

| Key | Note |
|---|---|
| `alexcss@Kaliuzhnyis-MacBook-Pro.local` (RSA-4096) | original; Oleksii can't connect with it - candidate for removal |
| `kalyuzhnyi@gmail.com` (ed25519) | added 2026-07-23, Oleksii's working key |

Toolbox console (`snigcli` on :2222 -> site container): Oleksii's ed25519 key + the automation key
(for testing/support) + the user's `inqui@fpweb-putty` key.
