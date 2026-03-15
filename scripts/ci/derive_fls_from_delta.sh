#!/usr/bin/env bash
# Simple derivation: scan changed-sources/package.xml for object and field components
# and emit a minimal PermissionSet XML per run named Generated_FLS.permissionset-meta.xml
set -euo pipefail
DELTA_DIR="$1"
SRC_ROOT="${2:-force-app}"
OUT_DIR="$DELTA_DIR/permissions-generated"
mkdir -p "$OUT_DIR"
PKG="$DELTA_DIR/package.xml"
if [ ! -f "$PKG" ]; then
  echo "No package.xml found in $DELTA_DIR; nothing to derive.";
  exit 0
fi

# collect object and field names (very permissive parsing)
OBJECTS=$(xmllint --xpath 'string(//types[name="CustomObject"]/members)' "$PKG" 2>/dev/null || true)
FIELDS=$(grep -oPm1 "<members>.*</members>" -n "$PKG" || true)

# Fallback simple approach: create one permissive PermissionSet granting read, edit on found objects/fields
PERM_FILE="$OUT_DIR/Generated_FLS.permissionset-meta.xml"
cat > "$PERM_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
  <label>Generated FLS from delta</label>
  <hasActivationRequired>false</hasActivationRequired>
EOF

# Add objectPermissions blocks for objects detected (simple comma split)
if [ -n "$OBJECTS" ]; then
  IFS=',' read -ra OBJS <<< "$OBJECTS"
  for o in "${OBJS[@]}"; do
    o2=$(echo "$o" | xargs)
    if [ -n "$o2" ]; then
      cat >> "$PERM_FILE" <<OB
  <objectPermissions>
    <object>$o2</object>
    <allowCreate>true</allowCreate>
    <allowDelete>true</allowDelete>
    <allowEdit>true</allowEdit>
    <allowRead>true</allowRead>
    <modifyAllRecords>false</modifyAllRecords>
    <viewAllRecords>false</viewAllRecords>
  </objectPermissions>
OB
    fi
  done
fi

# Note: field-level detection requires more advanced parsing; leave placeholders
cat >> "$PERM_FILE" <<EOF
  <!-- Add <fieldPermissions> entries here as needed -->
</PermissionSet>
EOF

echo "Generated permission set: $PERM_FILE"
