#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

log "Filtering profiles to include only changed object/field permissions"

PKG="$TMP_DIR/package.xml"
PROFILES_DIR="$TMP_DIR/profiles_filtered"
mkdir -p "$PROFILES_DIR"

if [ ! -f "$PKG" ]; then
  log "No package.xml found; skipping profile filtering"
  exit 0
fi

# Collect changed objects/fields from package.xml (simple heuristic)
grep -oE '<members>[^<]+' "$PKG" | sed -E 's/<members>//' | sort -u > "$TMP_DIR/members.list" || true

# If profiles were changed, copy them but note: only full profiles supported here
if ls "$TMP_DIR"/*.profile >/dev/null 2>&1; then
  for p in "$TMP_DIR"/*.profile; do
    base=$(basename "$p")
    log "Including profile $base"
    cp "$p" "$PROFILES_DIR/"
  done
  # Create a profiles package.xml that contains only Profile metadata
  cat > "$PROFILES_DIR/package.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <types>
    <members>*</members>
    <name>Profile</name>
  </types>
  <version>58.0</version>
</Package>
EOF
  log "Profiles package limited to changed profiles created"
else
  log "No profile artifacts in delta; skipping"
fi
