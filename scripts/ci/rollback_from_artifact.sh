#!/usr/bin/env bash
# rollback_from_artifact.sh <artifact-zip-path> <target-org-alias>
set -euo pipefail
ZIP="$1"
TARGET_ORG_ALIAS="${2:-targetOrg}"
if [ ! -f "$ZIP" ]; then
  echo "Artifact $ZIP not found"; exit 1
fi
TMP="rollback-unpack-$(date +%s)"
mkdir -p "$TMP"
unzip -q "$ZIP" -d "$TMP"
# attempt to find a source directory inside and redeploy
SRC_DIR=$(find "$TMP" -maxdepth 2 -type d -name "force-app" -print -quit || true)
if [ -z "$SRC_DIR" ]; then
  # fallback: look for any directory with metadata
  SRC_DIR=$(find "$TMP" -maxdepth 2 -type d -print -quit || true)
fi
if [ -z "$SRC_DIR" ]; then
  echo "No source found in backup"; exit 1
fi
sf project deploy start --source-dir "$SRC_DIR" --target-org "$TARGET_ORG_ALIAS" --test-level NoTestRun --json > rollback-deploy.json || true
cat rollback-deploy.json || true
