#!/bin/sh
# Nightly local backups for the web apps: DB via a consistent logical dump, webroot via tar.
# Kept 7 days on-box; a separate off-box pull is expected to copy these to an internal host.
#
# Runs under the same lock as the scheduled-task runner: that runner installs updates and lets
# plugins rewrite files in the webroot, and a file changing mid-archive both corrupts the copy and
# aborts this script.
set -eu
umask 077
STAMP=$(date +%F_%H%M)
DEST=/srv/backups/$STAMP
WORK=$DEST/.incomplete
mkdir -p "$WORK"

# --- fp-main-website (WordPress) ---
# Dump to a file first and verify the dumper's own result: piping straight into gzip hides a failed
# or truncated dump, because gzip still exits 0 and writes a perfectly valid archive.
docker exec fp-main-website-db sh -c 'mariadb-dump -uroot -p"$(cat /run/secrets/db_root_password)" --single-transaction --quick --routines wordpress' > "$WORK/fp-main-website-db.sql"
tail -c 200 "$WORK/fp-main-website-db.sql" | grep -q "Dump completed"
gzip "$WORK/fp-main-website-db.sql"
gzip -t "$WORK/fp-main-website-db.sql.gz"

tar -C /srv/apps/fp-main-website -czf "$WORK/fp-main-website-html.tar.gz" html
gzip -t "$WORK/fp-main-website-html.tar.gz"

# --- publish only after every artifact validated, so a partial run never looks like a good backup ---
mv "$WORK"/* "$DEST"/
rmdir "$WORK"

# --- retention: keep seven nightly copies ---
find /srv/backups -mindepth 1 -maxdepth 1 -type d -mtime +6 -exec rm -rf {} +
