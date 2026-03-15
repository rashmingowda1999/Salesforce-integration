#!/usr/bin/env bash
# deploy_wrapper.sh <manifest-path> <test-level> <target-org-alias>
set -euo pipefail
MANIFEST="$1"
TEST_LEVEL="${2:-RunLocalTests}"
TARGET_ORG_ALIAS="${3:-targetOrg}"
OUT_JSON="deploy-result.json"

if [ ! -f "$MANIFEST" ]; then
  echo "Manifest $MANIFEST not found; aborting."; exit 1
fi

# Validation dry-run
echo "Starting validation dry-run..."
sf project deploy start --manifest "$MANIFEST" --target-org "$TARGET_ORG_ALIAS" --test-level "$TEST_LEVEL" --dry-run --json > validate.json || true
cat validate.json || true

# If dry-run indicates failures, fail early
VALIDATION_STATUS=$(jq -r '.result.status // empty' validate.json 2>/dev/null || true)
if [ -n "$VALIDATION_STATUS" ] && [ "$VALIDATION_STATUS" != "Succeeded" ]; then
  echo "Validation status: $VALIDATION_STATUS — aborting deployment."; exit 1
fi

# Actual deploy
echo "Starting actual deploy..."
sf project deploy start --manifest "$MANIFEST" --target-org "$TARGET_ORG_ALIAS" --test-level "$TEST_LEVEL" --json > "$OUT_JSON" || true
cat "$OUT_JSON" || true

# Extract coverage (best-effort)
COVERAGE=$(jq -r '.result.details.runTestResult.summary.orgWideCoverage // .result.details.runTestResult.summary.orgWideCoveragePercent // empty' "$OUT_JSON" 2>/dev/null || true)
if [ -n "$COVERAGE" ]; then
  echo "Detected org-wide coverage: $COVERAGE"
else
  echo "No coverage info available in $OUT_JSON"
fi

# Exit status depends on deploy success
DEPLOY_STATUS=$(jq -r '.result.status // empty' "$OUT_JSON" 2>/dev/null || true)
if [ -z "$DEPLOY_STATUS" ]; then
  echo "Could not determine deploy status. Please inspect $OUT_JSON"; exit 1
fi
if [ "$DEPLOY_STATUS" != "Succeeded" ]; then
  echo "Deploy finished with status $DEPLOY_STATUS"; exit 1
fi

echo "Deploy succeeded."