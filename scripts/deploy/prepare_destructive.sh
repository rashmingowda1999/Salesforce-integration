#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

log "Preparing destructive changes"

# If sgd produced destructiveChanges*.xml, move them into deploy folder
for f in "$TMP_DIR"/destructiveChanges*.xml; do
  if [ -f "$f" ]; then
    log "Found $f -> moving to backup and deploy folder"
    cp "$f" "$BACKUP_DIR/" || true
    cp "$f" . || true
  fi
done
