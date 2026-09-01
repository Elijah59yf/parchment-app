#!/usr/bin/env bash
#
# scaffold_new_files.sh — creates empty files (and any missing parent
# directories) for a batch of new file paths, so dropping in the real
# content afterward is a straight paste rather than also having to
# mkdir -p and touch things by hand first.
#
# Only ever creates directories and empty (zero-byte) files. Never
# overwrites, moves, or deletes anything that already exists — an
# existing path is reported and skipped, not touched.
#
# Usage:
#   ./scripts/scaffold_new_files.sh path/one.dart path/two.js
#   ./scripts/scaffold_new_files.sh -f scripts/new_files_manifest.txt
#   cat paths.txt | ./scripts/scaffold_new_files.sh -f -
#
#   Args (one or more paths), OR
#   -f FILE   read paths from FILE, one per line. '-' reads stdin.
#             Blank lines and lines starting with # are ignored, so a
#             manifest can carry comments/section headers.
#
# Run from whichever repo root the paths are relative to (the app
# repo for lib/... paths, the backend repo for src/... paths, etc.)
# — this script doesn't assume which one, it just goes off cwd.

set -euo pipefail

usage() {
  echo "Usage: $0 <path> [path ...]" >&2
  echo "       $0 -f <manifest-file>   (use - for stdin)" >&2
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

PATHS=()

if [[ "$1" == "-f" ]]; then
  [[ $# -eq 2 ]] || usage
  MANIFEST="$2"

  read_manifest() {
    while IFS= read -r line || [[ -n "$line" ]]; do
      # Strip trailing carriage return (manifest edited on Windows)
      # and surrounding whitespace.
      line="${line%$'\r'}"
      line="$(echo -n "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
      [[ -z "$line" ]] && continue
      [[ "$line" == \#* ]] && continue
      PATHS+=("$line")
    done
  }

  if [[ "$MANIFEST" == "-" ]]; then
    read_manifest
  else
    if [[ ! -f "$MANIFEST" ]]; then
      echo "Error: manifest file '$MANIFEST' not found." >&2
      exit 1
    fi
    read_manifest < "$MANIFEST"
  fi
else
  PATHS=("$@")
fi

if [[ ${#PATHS[@]} -eq 0 ]]; then
  echo "No paths given — nothing to do."
  exit 0
fi

created=0
skipped=0

for path in "${PATHS[@]}"; do
  if [[ -e "$path" ]]; then
    echo "  exists, skipped:  $path"
    skipped=$((skipped + 1))
    continue
  fi

  dir="$(dirname "$path")"
  mkdir -p "$dir"
  touch "$path"
  echo "  created:          $path"
  created=$((created + 1))
done

echo
echo "Done — $created created, $skipped already existed."
