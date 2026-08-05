#!/bin/sh
# Keep the shared webroot writable by both the site and the upload account.
#
# Uploads arrive with whatever mode the contractor's client sends (typically 644/755), which drops
# group write and collapses the ACL mask, so PHP loses the access it was granted. Nothing on the
# SFTP side can add permission bits back - umask only removes them - so the tree is reconciled here.
set -eu
ROOT=/srv/apps/fp-main-website/html

find "$ROOT" -type d ! -perm 2775 -exec chmod 2775 {} +
find "$ROOT" -type f ! -perm 664 -exec chmod 664 {} +
setfacl -R  -m u:33:rwX -m u:1003:rwX -m m::rwX "$ROOT"
setfacl -R -d -m u:33:rwX -d -m u:1003:rwX -d -m m::rwX "$ROOT"
