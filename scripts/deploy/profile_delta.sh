#!/usr/bin/env bash
# Profile Delta Deployment Script
set -euo pipefail

log_info() { echo "[INFO] $*"; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
PROFILES_FILTERED="${PROFILES_FILTERED:-$TMP_DIR/profiles_filtered}"

main() {
    log_info "Profile Delta Deployment"
    mkdir -p "$PROFILES_FILTERED"
    
    [ ! -f "$TMP_DIR/profiles_changed.flag" ] && [ ! -f "$TMP_DIR/changed_files.txt" ] && log_info "No profile changes" && exit 0
    
    for profile_file in "$TMP_DIR"/*.profile; do
        [ -f "$profile_file" ] && cp "$profile_file" "$PROFILES_FILTERED/"
    done
    
    if ls "$PROFILES_FILTERED"/*.profile >/dev/null 2>&1; then
        cat > "$PROFILES_FILTERED/package.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <types><members>*</members><name>Profile</name></types>
  <version>58.0</version>
</Package>
EOF
    fi
}

main "$@"
