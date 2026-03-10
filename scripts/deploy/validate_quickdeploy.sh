#!/bin/bash
# ============================================================================
# validate_quickdeploy.sh - Quick Deploy using validation ID
# ============================================================================
# This script performs a quick deploy using a previously successful
# validation, which is faster than a full deployment.
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${2:-tmp_delta}"

echo "=============================================="
echo "  Quick Deploy"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "=============================================="

# Check for validation ID
VALIDATION_ID_FILE="$DELTA_DIR/deployment_id.txt"
VALIDATION_ID=""

# Try to get validation ID from various sources
if [ -f "$VALIDATION_ID_FILE" ]; then
    VALIDATION_ID=$(cat "$VALIDATION_ID_FILE")
    echo "Found validation ID from file: $VALIDATION_ID"
elif [ -n "$DEPLOYMENT_ID" ]; then
    VALIDATION_ID="$DEPLOYMENT_ID"
    echo "Found validation ID from environment: $VALIDATION_ID"
fi

# If no validation ID, perform full deployment
if [ -z "$VALIDATION_ID" ]; then
    echo ""
    echo "⚠️  No validation ID found"
    echo "Performing full deployment instead..."
    
    if [ -f "$DELTA_DIR/package.xml" ]; then
        sf project deploy start \
            --manifest "$DELTA_DIR/package.xml" \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --verbose
    else
        echo "No package.xml found - nothing to deploy"
        exit 0
    fi
else
    echo ""
    echo "Validation ID: $VALIDATION_ID"
    
    # Check validation status before quick deploy
    echo ""
    echo "Checking validation status..."
    
    sf project deploy report \
        --job-id "$VALIDATION_ID" \
        --target-org "$TARGET_ORG" \
        --wait 30
    
    # Execute quick deploy
    echo ""
    echo "Executing quick deploy..."
    
    sf project deploy quick \
        --validation-id "$VALIDATION_ID" \
        --target-org "$TARGET_ORG" \
        --wait 30 \
        --verbose
fi

DEPLOYMENT_STATUS=$?

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo ""
    echo "✅ Quick Deploy completed successfully!"
else
    echo ""
    echo "❌ Quick Deploy failed with status: $DEPLOYMENT_STATUS"
    exit $DEPLOYMENT_STATUS
fi

exit 0

