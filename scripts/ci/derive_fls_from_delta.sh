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

# Collect all <members> values under <types><name>CustomObject</name> and <name>CustomField</name>
# NOTE: In package.xml, <members> always appears BEFORE <name> within a <types> block.
# So we buffer members per block and emit them only when </types> confirms the type name.
mapfile -t OBJECTS < <(awk '
  /<types>/        { buf=""; tname="" }
  /<members>/      { m=$0; gsub(/^[[:space:]]*<members>|<\/members>[[:space:]]*$/, "", m); buf = buf ? buf "\n" m : m }
  /<name>/         { n=$0; gsub(/^[[:space:]]*<name>|<\/name>[[:space:]]*$/, "", n); tname=n }
  /<\/types>/      { if (tname == "CustomObject" && buf != "") print buf }
' "$PKG")

mapfile -t FIELDS < <(awk '
  /<types>/        { buf=""; tname="" }
  /<members>/      { m=$0; gsub(/^[[:space:]]*<members>|<\/members>[[:space:]]*$/, "", m); buf = buf ? buf "\n" m : m }
  /<name>/         { n=$0; gsub(/^[[:space:]]*<name>|<\/name>[[:space:]]*$/, "", n); tname=n }
  /<\/types>/      { if (tname == "CustomField" && buf != "") print buf }
' "$PKG")

PERM_FILE="$OUT_DIR/Generated_FLS.permissionset-meta.xml"
cat > "$PERM_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
  <label>Generated FLS from delta</label>
  <hasActivationRequired>false</hasActivationRequired>
EOF

# objectPermissions — one block per detected CustomObject
for obj in "${OBJECTS[@]}"; do
  obj=$(echo "$obj" | xargs)
  [ -z "$obj" ] && continue
  cat >> "$PERM_FILE" <<OBJ
  <objectPermissions>
    <object>$obj</object>
    <allowCreate>true</allowCreate>
    <allowDelete>true</allowDelete>
    <allowEdit>true</allowEdit>
    <allowRead>true</allowRead>
    <modifyAllRecords>false</modifyAllRecords>
    <viewAllRecords>false</viewAllRecords>
  </objectPermissions>
OBJ
done

# fieldPermissions — one block per detected CustomField (format: Object.Field__c)
for field in "${FIELDS[@]}"; do
  field=$(echo "$field" | xargs)
  [ -z "$field" ] && continue
  cat >> "$PERM_FILE" <<FLD
  <fieldPermissions>
    <field>$field</field>
    <editable>true</editable>
    <readable>true</readable>
  </fieldPermissions>
FLD
done

cat >> "$PERM_FILE" <<EOF
</PermissionSet>
EOF

echo "Generated permission set: $PERM_FILE"
echo "  Objects: ${#OBJECTS[@]}, Fields: ${#FIELDS[@]}"
