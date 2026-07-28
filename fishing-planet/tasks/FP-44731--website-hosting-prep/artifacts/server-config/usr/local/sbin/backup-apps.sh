#!/bin/sh
# Nightly local backups for the web apps: DB via a consistent logical dump, webroot via tar.
# Kept 7 days on-box; a separate off-box pull is expected to copy these to an internal host.
set -eu
umask 077
STAMP=$(date +%F_%H%M)
DEST=/srv/backups/$STAMP
mkdir -p "$DEST"

# --- fp-main-website (WordPress) ---
docker exec fp-main-website-db sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/db_root_password)" --single-transaction --quick --routines wordpress' | gzip > "$DEST/fp-main-website-db.sql.gz"
tar -C /srv/apps/fp-main-website -czf "$DEST/fp-main-website-html.tar.gz" html

# --- integrity check: dump must be valid gzip and non-empty ---
gzip -t "$DEST/fp-main-website-db.sql.gz"
test "$(zcat "$DEST/fp-main-website-db.sql.gz" | head -c 64 | wc -c)" -gt 0

# --- retention: 7 days ---
find /srv/backups -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} +
