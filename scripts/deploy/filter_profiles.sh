#!/bin/bash
# ============================================================================
# filter_profiles.sh - Filter and deploy only delta profile changes
# ============================================================================
# This script extracts only the changed permissions from profiles,
# avoiding full profile deployments which can cause conflicts.
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${2:-tmp_delta}"
SOURCE_DIR="${SOURCE_DIR:-force-app}"

echo "=============================================="
echo "  Filtering Delta Profiles"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "Delta Dir:  $DELTA_DIR"
echo "=============================================="

# Check if profiles exist in delta
PROFILE_DIR="$SOURCE_DIR/main/default/profiles"

if [ ! -d "$PROFILE_DIR" ]; then
    echo "No profiles directory found - skipping profile filtering"
    exit 0
fi

# Get changed profile files
if [ -n "$GITHUB_BASE_REF" ]; then
    FROM_COMMIT="$GITHUB_BASE_REF"
else
    FROM_COMMIT="${FROM_COMMIT:-HEAD~1}"
fi
TO_COMMIT="${TO_COMMIT:-$GITHUB_SHA}"

CHANGED_PROFILES=$(git diff --name-only "$FROM_COMMIT" "$TO_COMMIT" -- "$PROFILE_DIR" | grep '\.profile-meta\.xml$' || echo "")

if [ -z "$CHANGED_PROFILES" ]; then
    echo ""
    echo "No profile changes detected - skipping profile filtering"
    exit 0
fi

echo ""
echo "=== Changed Profile Files ==="
echo "$CHANGED_PROFILES"

# Create filtered profiles directory
FILTERED_DIR="$DELTA_DIR/filtered_profiles"
mkdir -p "$FILTERED_DIR"

echo ""
echo "Processing changed profiles..."

for profile_file in $CHANGED_PROFILES; do
    if [ -f "$profile_file" ]; then
        PROFILE_NAME=$(basename "$profile_file" .profile-meta.xml)
        echo "Processing profile: $PROFILE_NAME"
        
        # Copy profile to filtered directory
        cp "$profile_file" "$FILTERED_DIR/"
    fi
done

# Create package.xml for filtered profiles
cat > "$FILTERED_DIR/package.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>*</members>
        <name>Profile</name>
    </types>
    <version>65.0</version>
</Package>
EOF

echo ""
echo "Filtered profiles location: $FILTERED_DIR/"
ls -la "$FILTERED_DIR/"

# Deploy filtered profiles
echo ""
echo "Deploying filtered profiles..."

sf project deploy start \
    --manifest "$FILTERED_DIR/package.xml" \
    --source-dir "$FILTERED_DIR" \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    --verbose

echo ""
echo "✅ Delta profiles deployed successfully!"

exit 0

