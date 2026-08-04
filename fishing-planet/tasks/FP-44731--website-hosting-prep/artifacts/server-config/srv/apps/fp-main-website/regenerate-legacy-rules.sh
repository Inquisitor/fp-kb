#!/bin/sh
# Regenerate the compatibility include for the pages carried over from the previous site.
set -eu
ROOT=/srv/apps/fp-main-website/html
OUT=/srv/apps/fp-main-website/nginx/legacy-static.conf

{
  cat <<'HEADER'
# Compatibility for the static pages carried over from the previous site.
#
# The previous host ran on Windows and matched paths case-insensitively, so links in outgoing mail,
# store pages and platform submissions use spellings that do not match the files on disk. Matching
# here is case-insensitive, but each target still names the real file: only the URL match ignores
# case, while the filesystem lookup that follows does not.
#
# All of this exists only while these files are served from disk. Once the content lives in the CMS
# under its own URLs, delete this file - the site config includes it by wildcard from a mounted
# directory, so nothing else needs editing.

# Serve a directory index.html on the bare path. index.php stays first so a stray index.html cannot
# shadow application routing; the carried-over folders have none.
index index.php index.html;

# Documents and downloads whose real name is mixed-case.
HEADER

  cd "$ROOT"
  find . -not -path "./wp-*" -type f \( -name "*.htm" -o -name "*.html" -o -name "*.zip" \) -name "*[A-Z]*" -printf "%P\n" \
  | sort \
  | while IFS= read -r real; do
      pattern=$(printf '%s' "$real" | sed 's/[.[\*^$()+?{}|]/\\&/g')
      printf 'location ~* ^/%s$ { try_files /%s =404; }\n' "$pattern" "$real"
    done

  printf '\n# Retail locale folders are upper-case on disk.\n'
  find ./consoler/lang -maxdepth 1 -mindepth 1 -type d -printf "%P\n" \
  | sort \
  | while IFS= read -r loc; do
      printf 'rewrite "(?i)^/consoler/lang/%s/(.*)$" /consoler/lang/%s/$1 last;\n' "$loc" "$loc"
    done
} > "$OUT"
