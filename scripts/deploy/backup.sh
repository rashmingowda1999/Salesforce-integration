#!/usr/bin/env bash
set -euo pipefail

LOG() { echo "[backup] $(date +%FT%T%z) $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
BACKUP_ROOT="${BACKUP_ROOT:-$ROOT_DIR/backup}"
TODAY="$(date +%F)"
DEST_DIR="$BACKUP_ROOT/$TODAY"
MANIFEST="$TMP_DIR/package.xml"

cleanup_on_error() {
  LOG "An error occurred. Exiting."
}
trap cleanup_on_error ERR

LOG "Creating backup folders if missing"
mkdir -p "$DEST_DIR"

if [ ! -f "$MANIFEST" ]; then
  LOG "Manifest not found at $MANIFEST - nothing to retrieve. Exiting successfully."
  exit 0
fi

LOG "Retrieving metadata defined in $MANIFEST to $DEST_DIR"

# Prefer 'sf' if available; fall back to 'sfdx force:mdapi:retrieve'
if command -v sf >/dev/null 2>&1; then
  LOG "Attempting retrieval with 'sf'"
  if sf metadata retrieve --manifest "$MANIFEST" --target-dir "$DEST_DIR" --json > "$DEST_DIR/retrieve.json" 2>&1; then
    LOG "Retrieved metadata with 'sf'"
  else
    LOG "'sf metadata retrieve' failed or unsupported; falling back to 'sfdx'"
    if command -v sfdx >/dev/null 2>&1; then
      LOG "Retrieving with 'sfdx force:mdapi:retrieve'"
      sfdx force:mdapi:retrieve -k "$MANIFEST" -r "$DEST_DIR" --wait 10 --json > "$DEST_DIR/retrieve.json" || true
    else
      LOG "Neither 'sf' nor 'sfdx' are available - cannot retrieve metadata"
      exit 2
    fi
  fi
else
  LOG "'sf' not found; attempting 'sfdx'"
  if command -v sfdx >/dev/null 2>&1; then
    sfdx force:mdapi:retrieve -k "$MANIFEST" -r "$DEST_DIR" --wait 10 --json > "$DEST_DIR/retrieve.json" || true
  else
    LOG "Neither 'sf' nor 'sfdx' are available - cannot retrieve metadata"
    exit 2
  fi
fi

# If an mdapi zip was created, unzip it into the dated folder
ZIPFILE="$(find "$DEST_DIR" -maxdepth 1 -type f -name '*.zip' | head -n1 || true)"
if [ -n "$ZIPFILE" ]; then
  LOG "Unzipping $ZIPFILE"
  unzip -o "$ZIPFILE" -d "$DEST_DIR" >/dev/null 2>&1 || true
  rm -f "$ZIPFILE"
fi

LOG "Applying retention policy: removing backups older than 90 days"
if [ -d "$BACKUP_ROOT" ]; then
  find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -mtime +90 -print0 | xargs -0 --no-run-if-empty rm -rf --
fi

LOG "Backup completed: $DEST_DIR"

exit 0
