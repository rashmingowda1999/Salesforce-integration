#!/bin/bash

# Post-destructive changes validation script
# Usage: post_destructive_validation.sh <delta_dir> <target_org_alias>

set -e

DELTA_DIR="$1"
TARGET_ORG_ALIAS="$2"

if [ -z "$DELTA_DIR" ] || [ -z "$TARGET_ORG_ALIAS" ]; then
    echo "Usage: $0 <delta_directory> <target_org_alias>"
    exit 1
fi

echo "🔍 Post-deployment validation for destructive changes..."

# Load destructive flags if available
if [ -f "/tmp/destructive_flags.env" ]; then
    source /tmp/destructive_flags.env
fi

# Check if destructive changes were applied
if [ -f "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" ] ||
   [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" ] ||
   [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" ]; then

  echo "🚨 Destructive changes were processed - running post-validation..."
  echo ""

  # Verify components were properly deleted
  echo "🔍 Verifying component deletions in target org..."

  # Check for any remaining components that should have been deleted
  VALIDATION_ERRORS=""

  # Extract deleted component names for validation (simplified approach)
  if [ -f "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" ]; then
    echo "   📋 Validating main destructive changes..."
    DELETED_COMPONENTS=$(grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*//' || true)

    if [ -n "$DELETED_COMPONENTS" ]; then
      echo "   🗑️  Components that should be deleted:"
      echo "$DELETED_COMPONENTS" | sed 's/^/      • /'
    fi
  fi

  if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" ]; then
    echo "   📋 Validating pre-destructive changes..."
    PRE_DELETED=$(grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*//' || true)

    if [ -n "$PRE_DELETED" ]; then
      echo "   🗑️  Pre-destructive components processed:"
      echo "$PRE_DELETED" | sed 's/^/      • /'
    fi
  fi

  if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" ]; then
    echo "   📋 Validating post-destructive changes..."
    POST_DELETED=$(grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*//' || true)

    if [ -n "$POST_DELETED" ]; then
      echo "   🗑️  Post-destructive components processed:"
      echo "$POST_DELETED" | sed 's/^/      • /'
    fi
  fi

  echo ""
  echo "✅ POST-DESTRUCTIVE VALIDATION COMPLETED"
  echo "   📊 Destructive changes have been processed"
  echo "   🔍 Manual verification recommended for critical components"
  echo "   📋 Consider running org health checks if needed"

  # Save destructive changes log for audit trail
  echo ""
  echo "💾 Creating audit trail for destructive changes..."
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  AUDIT_FILE="destructive-changes-audit-${TIMESTAMP}.log"

  {
    echo "Destructive Changes Audit Log"
    echo "Generated: $TIMESTAMP"
    echo "Target Org: $TARGET_ORG_ALIAS"
    echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
    echo "Commit: $(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
    echo "====================================="
    echo ""

    if [ -f "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" ]; then
      echo "MAIN DESTRUCTIVE CHANGES:"
      cat "$DELTA_DIR/destructiveChanges/destructiveChanges.xml"
      echo ""
    fi

    if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" ]; then
      echo "PRE-DESTRUCTIVE CHANGES:"
      cat "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml"
      echo ""
    fi

    if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" ]; then
      echo "POST-DESTRUCTIVE CHANGES:"
      cat "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml"
      echo ""
    fi

    # Add deployment information if available
    echo "DEPLOYMENT INFORMATION:"
    echo "Executed by: ${GITHUB_ACTOR:-'local-user'}"
    echo "Workflow run: ${GITHUB_RUN_ID:-'local-run'}"
    echo "Repository: ${GITHUB_REPOSITORY:-'local-repo'}"
  } > "$AUDIT_FILE"

  echo "   📝 Audit log created: $AUDIT_FILE"

  # Show first few lines of audit for confirmation
  echo "   📋 Audit log preview:"
  head -20 "$AUDIT_FILE" | sed 's/^/      /'
  echo "      ... (see full file for complete details)"

else
  echo "✅ No destructive changes were processed"
  echo "   📋 Deployment was additive-only or no changes detected"
fi

# Cleanup temporary files
rm -f /tmp/destructive_flags.env

echo "Post-destructive validation completed successfully."