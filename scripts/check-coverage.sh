#!/bin/bash
# scripts/check-coverage.sh
# Checks org-wide Apex coverage if Apex classes/triggers changed
# Fails if coverage <85%
# Usage: ./check-coverage.sh [delta/package]
set -e

PACKAGE_DIR=${1:-delta/package}

# Check if any Apex classes or triggers changed
APEX_CHANGED=$(find "$PACKAGE_DIR" -type f \( -name '*.cls' -o -name '*.trigger' \) | wc -l)
if [ "$APEX_CHANGED" -eq 0 ]; then
  echo "No Apex changes detected. Skipping coverage check."
  exit 0
fi

echo "Apex changes detected. Checking org-wide coverage..."

# Run coverage check
COVERAGE=$(sf apex run test --target-org ci_org --test-level RunLocalTests --code-coverage --json | jq '.result.coverage.coverage' || echo 0)
COVERAGE=${COVERAGE%.*}

if [ "$COVERAGE" -lt 85 ]; then
  echo "Org-wide coverage is $COVERAGE%. Minimum required is 85%. Failing."
  exit 1
else
  echo "Org-wide coverage is $COVERAGE%."
fi
