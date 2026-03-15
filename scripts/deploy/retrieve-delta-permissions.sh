#!/usr/bin/env bash
set -euo pipefail

# Retrieve profile permissions for changed objects/fields from delta package
# Usage: ./retrieve-delta-permissions.sh <delta_dir> <target_org> [output_dir]
# Example: ./retrieve-delta-permissions.sh delta deployment-org permissions/

DELTA_DIR=${1:?Error: delta_dir required (with package.xml)}
TARGET_ORG=${2:?Error: target_org required}
OUTPUT_DIR=${3:-permissions}

if [[ ! -f "$DELTA_DIR/package.xml" ]]; then
  echo "Error: $DELTA_DIR/package.xml not found" >&2
  exit 1
fi

echo "Extracting changed objects/fields from $DELTA_DIR/package.xml"

# Parse package.xml for CustomObject and CustomField members
OBJECTS=()
FIELDS=()

while IFS= read -r line; do
  if echo "$line" | grep -q '^<members>'; then
    MEMBER=$(echo "$line" | sed 's/.*<members>\([^<]*\).*/\1/')
    if [[ "$MEMBER" =~ \. ]]; then
      # Field: Object.Field
      FIELDS+=("$MEMBER")
    else
      # Object
      OBJECTS+=("$MEMBER")
    fi
  fi
done < <(grep '^ *<members>' "$DELTA_DIR/package.xml")

if [[ ${#OBJECTS[@]} -eq 0 && ${#FIELDS[@]} -eq 0 ]]; then
  echo "No objects/fields found in delta - nothing to retrieve"
  exit 0
fi

echo "Objects: ${OBJECTS[*]}"
echo "Fields:  ${FIELDS[*]}"

# Generate retrieve package.xml with Profiles/* + changed metadata
cat > retrieve-package.xml << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
  <types>
    <members>*</members>
    <name>Profile</name>
  </types>
EOF

if [[ ${#OBJECTS[@]} -gt 0 ]]; then
  cat >> retrieve-package.xml << EOF
  <types>
EOF
  printf '    <members>%s</members>\n' "${OBJECTS[@]}" >> retrieve-package.xml
  echo '    <name>CustomObject</name>' >> retrieve-package.xml
  echo '  </types>' >> retrieve-package.xml
fi

if [[ ${#FIELDS[@]} -gt 0 ]]; then
  cat >> retrieve-package.xml << EOF
  <types>
EOF
  printf '    <members>%s</members>\n' "${FIELDS[@]}" >> retrieve-package.xml
  echo '    <name>CustomField</name>' >> retrieve-package.xml
  echo '  </types>' >> retrieve-package.xml
fi

echo '  <version>65.0</version>' >> retrieve-package.xml
echo '</Package>' >> retrieve-package.xml

echo "Retrieve package generated. Running sf project retrieve..."
echo "Target: $TARGET_ORG"
echo "Output: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"
sf project retrieve start \
  --target-org "$TARGET_ORG" \
  --manifest retrieve-package.xml \
  --output-dir "$OUTPUT_DIR" \
  --ignore-conflicts

rm retrieve-package.xml

echo ""
echo "✅ Retrieved permissions to $OUTPUT_DIR/"
echo "Contains updated Profile metadata with permissions for changed objects/fields."
ls -la "$OUTPUT_DIR/force-app/main/default/profiles/"

