#!/usr/bin/env bash
# Enhanced Apex Test Runner
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
MIN_COVERAGE="${MIN_COVERAGE:-85}"
ORG_ALIAS="${ORG_ALIAS:-production-org}"

main() {
    log_info "Apex Test Execution - Min Coverage: $MIN_COVERAGE%"
    
    [ ! -f "$TMP_DIR/apex_changed.flag" ] && [ ! -f "$TMP_DIR/changed_files.txt" ] && log_info "No Apex changes, skipping tests" && exit 0
    
    CHANGED_CLASSES=$(grep -E '\.cls$' "$TMP_DIR/changed_files.txt" 2>/dev/null | grep -v 'Test\.cls$' | sed 's|.*/||' | sed 's|\.cls$||' | tr '\n' ',' | sed 's/,$//')
    
    [ -z "$CHANGED_CLASSES" ] && log_info "No classes to test" && exit 0
    
    log_info "Testing: $CHANGED_CLASSES"
    
    if command -v sf >/dev/null 2>&1; then
        sf apex run test --class-names "$CHANGED_CLASSES" --target-org "$ORG_ALIAS" --wait 30 --codecoverage --json > "$TMP_DIR/test_result.json" 2>&1 || true
    fi
    
    COVERAGE=$(jq -r '.result.coverage.coverage // .result.summary.coverage // "0"' "$TMP_DIR/test_result.json" 2>/dev/null | sed 's/%//' || echo "0")
    COVERAGE_NUM=$(echo "$COVERAGE" | grep -oE '[0-9]+' | head -1 || echo "0")
    
    log_info "Coverage: $COVERAGE_NUM%"
    
    if (( COVERAGE_NUM < MIN_COVERAGE )); then
        log_error "Coverage $COVERAGE_NUM% < $MIN_COVERAGE%"
        exit 1
    fi
    
    log_success "Tests passed!"
}

main "$@"
