#!/bin/bash
# ============================================================================
# run-impacted-tests-coverage.sh - Run impacted Apex tests + coverage check
# ============================================================================
# Detects changed Apex classes and runs corresponding tests with coverage.
# Fails if coverage < 85%.
# Usage: ./run-impacted-tests-coverage.sh [target_org] [from_commit] [to_commit]
# ============================================================================

set -euo pipefail

# Configuration
TARGET_ORG=${1:-deployment-org}
FROM_COMMIT=${2:-HEAD~1}
TO_COMMIT=${3:-HEAD}
SOURCE_DIR=${SOURCE_DIR:-force-app}
MIN_COVERAGE=85
RESULT_JSON=result.json

echo "=============================================="
echo "  Running Impacted Apex Tests + Coverage"
echo "=============================================="
echo "Target Org:    $TARGET_ORG"
echo "Commits:       $FROM_COMMIT..$TO_COMMIT"
echo "Min Coverage:  $MIN_COVERAGE%"
echo "=============================================="

# Detect changed Apex files (.cls, .trigger)
CHANGED_APEX=$(git diff --name-only "$FROM_COMMIT" "$TO_COMMIT" -- "$SOURCE_DIR/main/default/classes/" "$SOURCE_DIR/main/default/triggers/" | grep -E '\.(cls|trigger)$' || true)

if [[ -z "$CHANGED_APEX" ]]; then
  echo "✅ No Apex changes detected - skipping tests"
  exit 0
fi

echo ""
echo "=== Changed Apex Files ==="
echo "$CHANGED_APEX"

# Find impacted test classes
TEST_CLASSES=()
while IFS= read -r file; do
  if [[ -n "$file" ]]; then
    CLASS_NAME=$(basename "$file" .cls | basename "$file" .trigger)
    # Find test classes matching pattern
    TEST_FILE=$(find "$SOURCE_DIR" -name "${CLASS_NAME}*" -o -name "*${CLASS_NAME}*" -o -name "*Test*" | grep -E '\.cls$' | grep -i test | head -1)
    if [[ -n "$TEST_FILE" ]]; then
      TEST_CLASS=$(basename "$TEST_FILE" .cls)
      TEST_CLASSES+=("$TEST_CLASS")
    fi
  fi
done <<< "$CHANGED_APEX"

if [[ ${#TEST_CLASSES[@]} -eq 0 ]]; then
  echo "No matching test classes found - running all local tests"
  sf apex test run \
    --target-org "$TARGET_ORG" \
    --test-level RunLocalTests \
    --result-format json \
    --coverage-format json \
    --code-coverage \
    --wait 10 \
    --result-file "$RESULT_JSON"
else
  echo "Running impacted tests: ${TEST_CLASSES[*]}"
  sf apex test run \
    --target-org "$TARGET_ORG" \
    --class-names "${TEST_CLASSES[*]}" \
    --result-format json \
    --coverage-format json \
    --code-coverage \
    --wait 10 \
    --result-file "$RESULT_JSON"
fi

  # Check coverage with local script and org query
  ../apex/check_coverage.sh "$TARGET_ORG" "$MIN_COVERAGE"

echo ""
echo "✅ Impacted tests passed with >=${MIN_COVERAGE}% coverage"

exit 0

