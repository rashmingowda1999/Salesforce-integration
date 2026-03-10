#!/bin/bash
# ============================================================================
# deploy_delta.sh - Deploy delta package to Salesforce
# ============================================================================
# This script handles the deployment of delta packages using
# Salesforce CLI (sf) commands.
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${2:-tmp_delta}"
MODE="${3:-validate}"  # validate, quickdeploy, or deploy

echo "=============================================="
echo "  Deploying Delta Package"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "Delta Dir:  $DELTA_DIR"
echo "Mode:       $MODE"
echo "=============================================="

# Check if package exists
if [ ! -f "$DELTA_DIR/package.xml" ]; then
    echo ""
    echo "⚠️  No package.xml found in $DELTA_DIR"
    echo "Nothing to deploy"
    exit 0
fi

# Display package contents
echo ""
echo "=== Package Contents ==="
cat "$DELTA_DIR/package.xml"

# Determine deployment strategy
case "$MODE" in
    validate)
        echo ""
        echo "Running VALIDATION deployment (check-only)..."
        sf project deploy start \
            --manifest "$DELTA_DIR/package.xml" \
            --target-org "$TARGET_ORG" \
            --check-only \
            --wait 30 \
            --verbose
        
        # Save deployment ID if available
        echo "$DEPLOYMENT_ID" > "$DELTA_DIR/deployment_id.txt" 2>/dev/null || true
        ;;
        
    quickdeploy)
        VALIDATION_ID="${4:-}"
        if [ -z "$VALIDATION_ID" ]; then
            echo "❌ Validation ID required for quick deploy"
            exit 1
        fi
        
        echo ""
        echo "Running QUICK DEPLOY with validation ID: $VALIDATION_ID"
        sf project deploy quick \
            --validation-id "$VALIDATION_ID" \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --verbose
        ;;
        
    deploy)
        echo ""
        echo "Running FULL deployment..."
        sf project deploy start \
            --manifest "$DELTA_DIR/package.xml" \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --verbose
        ;;
        
    *)
        echo "❌ Unknown mode: $MODE"
        echo "Valid modes: validate, quickdeploy, deploy"
        exit 1
        ;;
esac

DEPLOYMENT_STATUS=$?

if [ $DEPLOYMENT_STATUS -eq 0 ]; then
    echo ""
    echo "✅ Deployment completed successfully!"
else
    echo ""
    echo "❌ Deployment failed with status: $DEPLOYMENT_STATUS"
    exit $DEPLOYMENT_STATUS
fi

exit 0

