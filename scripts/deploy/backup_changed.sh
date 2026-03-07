#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

log "Backing up changed components"

# If tmp_delta exists, copy its contents; otherwise use git list
if [ -d "$TMP_DIR" ] && [ "$(ls -A "$TMP_DIR")" ]; then
  cp -R "$TMP_DIR"/* "$BACKUP_DIR/" || true
else
  git diff --name-only HEAD~1 HEAD | while read -r file; do
    mkdir -p "$BACKUP_DIR/$(dirname "$file")"
    cp --parents "$file" "$BACKUP_DIR/" || true
  done
fi

log "Backup stored in $BACKUP_DIR"
