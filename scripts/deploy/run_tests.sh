#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

log "Running Apex tests (if applicable) and checking code coverage"

if [ -f "$TMP_DIR/apex_changed.flag" ]; then
  log "Apex changes detected, executing tests"
  # Run tests and request code coverage
  # Use sfdx legacy command for broader compatibility and JSON parsing
  sfdx force:apex:test:run --resultformat human --codecoverage --wait 10 --json > "$TMP_DIR/test_result.json" || true

  if [ -f "$TMP_DIR/test_result.json" ]; then
    COVERAGE=$(jq -r '.result.summary.codeCoverage || .result.codeCoverage' "$TMP_DIR/test_result.json" 2>/dev/null || true)
    if [ -z "$COVERAGE" ] || [ "$COVERAGE" = "null" ]; then
      # Try to compute from aggregateCoverage
      COVERAGE=$(jq -r '.result.summary.coverage' "$TMP_DIR/test_result.json" 2>/dev/null || true)
    fi
    if [ -n "$COVERAGE" ]; then
      # normalize numeric
      COVERAGE_NUM=$(echo "$COVERAGE" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || true)
      log "Detected coverage: $COVERAGE_NUM%"
      MIN=${MIN_COVERAGE:-85}
      cmp=$(awk "BEGIN{print ($COVERAGE_NUM >= $MIN)}")
      if [ "$cmp" -eq 1 ]; then
        log "Coverage check passed ($COVERAGE_NUM >= $MIN)"
      else
        echo "Code coverage $COVERAGE_NUM% is below minimum $MIN%" >&2
        exit 1
      fi
    else
      echo "Unable to determine code coverage from test run output" >&2
      exit 1
    fi
  else
    echo "Test run output missing" >&2
    exit 1
  fi
else
  log "No Apex changes detected; skipping tests"
fi
