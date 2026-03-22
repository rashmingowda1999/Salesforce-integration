#!/bin/bash

# Pre-destructive changes validation script
# Usage: pre_destructive_validation.sh <delta_dir>

set -e

DELTA_DIR="$1"

if [ -z "$DELTA_DIR" ]; then
    echo "Usage: $0 <delta_directory>"
    exit 1
fi

echo "🔍 Pre-deployment validation for destructive changes..."

# Initialize flags
HAS_DESTRUCTIVE=false
HAS_PRE_DESTRUCTIVE=false
HAS_POST_DESTRUCTIVE=false

# Check for destructive changes files
if [ -f "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" ]; then
  HAS_DESTRUCTIVE=true
  echo "🚨 Destructive changes detected!"
fi

if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" ]; then
  HAS_PRE_DESTRUCTIVE=true
  echo "🚨 Pre-destructive changes detected!"
fi

if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" ]; then
  HAS_POST_DESTRUCTIVE=true
  echo "🚨 Post-destructive changes detected!"
fi

if [ "$HAS_DESTRUCTIVE" = true ] || [ "$HAS_PRE_DESTRUCTIVE" = true ] || [ "$HAS_POST_DESTRUCTIVE" = true ]; then
  echo ""
  echo "⚠️  DESTRUCTIVE CHANGES SAFETY CHECKLIST:"
  echo "   📋 Components will be DELETED from the target org"
  echo "   💾 Ensure you have proper backups before proceeding"
  echo "   🔄 Consider impact on dependent components"
  echo "   👥 Verify with team members if shared components are affected"
  echo "   🧪 Test in a sandbox environment first"
  echo ""

  # Show what will be deleted
  if [ "$HAS_PRE_DESTRUCTIVE" = true ]; then
    echo "🗂️  PRE-DESTRUCTIVE COMPONENTS TO DELETE:"
    grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*/   • /' || echo "   (Unable to parse components)"
    echo ""
  fi

  if [ "$HAS_DESTRUCTIVE" = true ]; then
    echo "🗂️  COMPONENTS TO DELETE:"
    grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*/   • /' || echo "   (Unable to parse components)"
    echo ""
  fi

  if [ "$HAS_POST_DESTRUCTIVE" = true ]; then
    echo "🗂️  POST-DESTRUCTIVE COMPONENTS TO DELETE:"
    grep -E '<name>.*</name>' "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" | sed 's/<name>//g; s/<\/name>//g; s/^[[:space:]]*/   • /' || echo "   (Unable to parse components)"
    echo ""
  fi

  echo "🔒 DEPLOYMENT WILL CONTINUE WITH DESTRUCTIVE CHANGES"
  echo "   If this is unexpected, stop the deployment and review your changes."
  echo ""

  # Export flags for use by deployment script (optional)
  echo "export HAS_DESTRUCTIVE=$HAS_DESTRUCTIVE" > /tmp/destructive_flags.env
  echo "export HAS_PRE_DESTRUCTIVE=$HAS_PRE_DESTRUCTIVE" >> /tmp/destructive_flags.env
  echo "export HAS_POST_DESTRUCTIVE=$HAS_POST_DESTRUCTIVE" >> /tmp/destructive_flags.env
else
  echo "✅ No destructive changes detected - deployment is additive only"

  # Create empty flags file
  echo "export HAS_DESTRUCTIVE=false" > /tmp/destructive_flags.env
  echo "export HAS_PRE_DESTRUCTIVE=false" >> /tmp/destructive_flags.env
  echo "export HAS_POST_DESTRUCTIVE=false" >> /tmp/destructive_flags.env
fi

echo "Pre-destructive validation completed successfully."