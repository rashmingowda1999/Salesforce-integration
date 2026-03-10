#!/bin/bash
# ============================================================================
# generate_delta.sh - Generate delta package using sfdx-git-delta
# ============================================================================
# This script detects changes between commits and generates a delta package
# for deployment, reducing deployment time for large enterprise orgs.
# ============================================================================

set -e

# Configuration
DELTA_DIR="${DELTA_DIR:-tmp_delta}"
SOURCE_DIR="${SOURCE_DIR:-force-app}"

# Get commit references
if [ -n "$GITHUB_BASE_REF" ]; then
    FROM_COMMIT="$GITHUB_BASE_REF"
else
    FROM_COMMIT="${1:-HEAD~1}"
fi

TO_COMMIT="${2:-$GITHUB_SHA}"

echo "=============================================="
echo "  Generating Delta Package"
echo "=============================================="
echo "From: $FROM_COMMIT"
echo "To:   $TO_COMMIT"
echo "=============================================="

# Create delta directory
mkdir -p "$DELTA_DIR"

# Generate delta package using sfdx-git-delta
echo "Running sfdx-git-delta to detect changes..."

sfdx git:delta \
    --from "$FROM_COMMIT" \
    --to "$TO_COMMIT" \
    --output "$DELTA_DIR" \
    --generate-package

# Check if package was generated
if [ -f "$DELTA_DIR/package.xml" ]; then
    echo ""
    echo "=== Delta Package Contents ==="
    cat "$DELTA_DIR/package.xml"
    echo ""
    
    # Count components
    COMPONENT_COUNT=$(grep -c '<members>' "$DELTA_DIR/package.xml" || echo "0")
    echo "Total components to deploy: $COMPONENT_COUNT"
    
    echo ""
    echo "✅ Delta package generated successfully!"
    
    # Check for destructive changes
    if [ -f "$DELTA_DIR/destructiveChanges.xml" ]; then
        echo ""
        echo "=== Pre-Destructive Changes Detected ==="
        cat "$DELTA_DIR/destructiveChanges.xml"
    fi
    
    if [ -f "$DELTA_DIR/destructiveChangesPost.xml" ]; then
        echo ""
        echo "=== Post-Destructive Changes Detected ==="
        cat "$DELTA_DIR/destructiveChangesPost.xml"
    fi
else
    echo ""
    echo "⚠️  No delta package generated (no changes detected)"
    # Create empty package.xml to prevent build failures
    echo '<?xml version="1.0" encoding="UTF-8"?><Package xmlns="http://soap.sforce.com/2006/04/metadata"></Package>' > "$DELTA_DIR/package.xml"
fi

echo ""
echo "Delta package location: $DELTA_DIR/"
ls -la "$DELTA_DIR/"

exit 0

