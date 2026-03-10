#!/bin/bash
# ============================================================================
# backup.sh - Backup changed metadata from target org
# ============================================================================
# This script retrieves metadata from the target Salesforce org before
# deployment, ensuring we can rollback if needed.
# ============================================================================

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-Backup/backupChanges}"
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${DELTA_DIR:-tmp_delta}"

echo "=============================================="
echo "  Backing Up Changed Metadata"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "Backup Dir: $BACKUP_DIR"
echo "=============================================="

# Create timestamped backup directory
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
mkdir -p "$BACKUP_PATH"

# Create manifest from delta package if it exists
if [ -f "$DELTA_DIR/package.xml" ]; then
    echo ""
    echo "Using delta package.xml for retrieval..."
    cp "$DELTA_DIR/package.xml" "$BACKUP_PATH/package.xml"
    
    # Retrieve metadata from target org
    echo ""
    echo "Retrieving metadata from target org..."
    
    sf project retrieve start \
        --manifest "$DELTA_DIR/package.xml" \
        --target-org "$TARGET_ORG" \
        --output-dir "$BACKUP_PATH/retrieved" \
        --wait 30
    
    if [ -d "$BACKUP_PATH/retrieved" ]; then
        echo ""
        echo "=== Backup Contents ==="
        find "$BACKUP_PATH/retrieved" -type f -name "*.xml" | head -20
        
        # Count backed up files
        FILE_COUNT=$(find "$BACKUP_PATH/retrieved" -type f | wc -l)
        echo ""
        echo "Total files backed up: $FILE_COUNT"
    fi
else
    echo ""
    echo "⚠️  No delta package found - skipping backup"
    echo "This could mean no changes were detected"
fi

# Save backup metadata
cat > "$BACKUP_PATH/backup_info.json" << EOF
{
    "timestamp": "$TIMESTAMP",
    "target_org": "$TARGET_ORG",
    "commit_sha": "$GITHUB_SHA",
    "workflow_run_id": "$GITHUB_RUN_ID",
    "backup_path": "$BACKUP_PATH"
}
EOF

echo ""
echo "✅ Backup completed successfully!"
echo "Backup location: $BACKUP_PATH"

exit 0

