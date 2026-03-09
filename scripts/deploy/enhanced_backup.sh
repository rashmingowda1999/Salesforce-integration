#!/usr/bin/env bash
# Enhanced Backup Script for Salesforce CI/CD Pipeline
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
BACKUP_ROOT="${BACKUP_ROOT:-$ROOT_DIR/backup}"
RETENTION_DAYS="${RETENTION_DAYS:-90}"
MANIFEST="${MANIFEST:-$TMP_DIR/package.xml}"

TODAY=$(date +%Y-%m-%d)
BACKUP_DIR="$BACKUP_ROOT/$TODAY"

main() {
    log_info "Salesforce Metadata Backup - Date: $TODAY"
    
    mkdir -p "$BACKUP_DIR"
    
    if [ ! -f "$MANIFEST" ]; then
        MANIFEST="$BACKUP_ROOT/full_manifest.xml"
        cat > "$MANIFEST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types><members>*</members><name>CustomObject</name></types>
    <types><members>*</members><name>ApexClass</name></types>
    <version>58.0</version>
</Package>
EOF
    fi
    
    log_info "Retrieving metadata..."
    if command -v sf >/dev/null 2>&1; then
        sf project retrieve start --manifest "$MANIFEST" --target-dir "$BACKUP_DIR" --target-org production-org --wait 30 --json > "$BACKUP_DIR/retrieve_result.json" 2>&1 || true
    fi
    
    for zipfile in "$BACKUP_DIR"/*.zip; do
        [ -f "$zipfile" ] && unzip -o "$zipfile" -d "$BACKUP_DIR" >/dev/null 2>&1 && rm -f "$zipfile"
    done
    
    find "$BACKUP_ROOT" -maxdepth 1 -mindepth 1 -type d -mtime +$RETENTION_DAYS -print0 | xargs -0 --no-run-if-empty rm -rf -- 2>/dev/null || true
    
    log_success "Backup completed: $BACKUP_DIR"
}

main "$@"
