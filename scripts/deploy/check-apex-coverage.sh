#!/usr/bin/env bash
set -euo pipefail

RESULT_JSON=${1:-apex-test-result.json}
MIN_COVERAGE=${2:-85}

if [ ! -f "$RESULT_JSON" ]; then
  echo "Result file $RESULT_JSON not found" >&2
  exit 1
fi

# Extract org-wide coverage percentage from test run output
COVERAGE=$(jq -r '.result.summary.orgWideCoverage // .result.summary.coverage // .result.summary.codeCoverage?.apexCodeCoveragePercentage // 0' "$RESULT_JSON")

if [ -z "$COVERAGE" ] || [ "$COVERAGE" = "null" ]; then
  echo "Unable to read coverage from $RESULT_JSON" >&2
  exit 1
fi

echo "Org-wide Apex coverage: ${COVERAGE}% (min required: ${MIN_COVERAGE}%)"

if (( ${COVERAGE%.*} < MIN_COVERAGE )); then
  echo "Coverage gate failed: ${COVERAGE}% < ${MIN_COVERAGE}%" >&2
  exit 1
fi

echo "Coverage gate passed"
