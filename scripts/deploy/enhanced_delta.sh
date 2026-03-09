#!/usr/bin/env bash
# Enhanced Delta Generation Script
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
SOURCE_DIR="${SOURCE_DIR:-$ROOT_DIR/force-app}"
BASE_REF="${BASE_REF:-HEAD~1}"
TO_REF="${TO_REF:-HEAD}"

main() {
    log_info "Delta Generation: $BASE_REF -> $TO_REF"
    mkdir -p "$TMP_DIR"
    
    CHANGES=$(git diff --name-only "$BASE_REF" "$TO_REF" -- "$SOURCE_DIR/" 2>/dev/null || true)
    
    if [ -z "$CHANGES" ]; then
        log_info "No changes detected"
        echo '{"no_changes":true}' > "$TMP_DIR/metadata.json"
        exit 0
    fi
    
    CHANGE_COUNT=$(echo "$CHANGES" | wc -l | tr -d ' ')
    echo "$CHANGES" > "$TMP_DIR/changed_files.txt"
    log_info "Found $CHANGE_COUNT changed files"
    
    if command -v npx >/dev/null 2>&1; then
        npx sfdx-git-delta --to "$TO_REF" --from "$BASE_REF" --output "$TMP_DIR" --source "$SOURCE_DIR" --generate-delta 2>/dev/null || true
    fi
    
    # Detect change types
    grep -qE '\.cls$' "$TMP_DIR/changed_files.txt" 2>/dev/null && touch "$TMP_DIR/apex_changed.flag"
    grep -qE 'permissionset$' "$TMP_DIR/changed_files.txt" 2>/dev/null && touch "$TMP_DIR/permissionsets_changed.flag"
    grep -qE '\.profile-meta\.xml$' "$TMP_DIR/changed_files.txt" 2>/dev/null && touch "$TMP_DIR/profiles_changed.flag"
    
    log_success "Delta generation completed"
}

main "$@"
