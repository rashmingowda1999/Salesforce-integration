#!/bin/bash
# ============================================================================
# handle_destructive.sh - Handle destructive changes (pre/post deployment)
# ============================================================================
# This script handles the deployment of destructiveChanges.xml files
# for removing metadata components from Salesforce org.
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${2:-tmp_delta}"
TIMING="${3:-pre}"  # pre or post

echo "=============================================="
echo "  Handling Destructive Changes"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "Timing:     $TIMING"
echo "=============================================="

# Determine which destructive file to process
case "$TIMING" in
    pre)
        DESTRUCTIVE_FILE="$DELTA_DIR/destructiveChanges.xml"
        TIMING_DESC="Pre-Destructive Changes"
        ;;
    post)
        DESTRUCTIVE_FILE="$DELTA_DIR/destructiveChangesPost.xml"
        TIMING_DESC="Post-Destructive Changes"
        ;;
    *)
        echo "❌ Invalid timing: $TIMING (must be 'pre' or 'post')"
        exit 1
        ;;
esac

echo ""
echo "=== $TIMING_DESC ==="

# Check if destructive file exists
if [ -f "$DESTRUCTIVE_FILE" ]; then
    echo "Found: $DESTRUCTIVE_FILE"
    echo ""
    echo "Contents:"
    cat "$DESTRUCTIVE_FILE"
    
    # Check if file has content
    if [ -s "$DESTRUCTIVE_FILE" ]; then
        echo ""
        echo "Deploying $TIMING_DESC..."
        
        sf project deploy start \
            --manifest "$DESTRUCTIVE_FILE" \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --verbose
        
        if [ $? -eq 0 ]; then
            echo ""
            echo "✅ $TIMING_DESC deployed successfully!"
        else
            echo ""
            echo "❌ $TIMING_DESC deployment failed!"
            exit 1
        fi
    else
        echo ""
        echo "⚠️  $DESTRUCTIVE_FILE is empty - skipping"
    fi
else
    echo "No $TIMING_DESC file found - skipping"
fi

exit 0

