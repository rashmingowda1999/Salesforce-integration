#!/usr/bin/env bash
# Enhanced Validate and Quick Deploy Script
set -euo pipefail

log_info() { echo "[INFO] $*"; }
log_success() { echo "[SUCCESS] $*"; }
log_error() { echo "[ERROR] $*" >&2; }

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="${TMP_DIR:-$ROOT_DIR/tmp_delta}"
ORG_ALIAS="${ORG_ALIAS:-production-org}"
TEST_LEVEL="${TEST_LEVEL:-NoTestRun}"

usage() { echo "Usage: $0 <validate|quickdeploy|deploy> [args]"; exit 1; }

main() {
    [ $# -eq 0 ] && usage
    case "$1" in
        validate)    validate_deployment "$@" ;;
        quickdeploy) quick_deploy "$@" ;;
        deploy)     full_deploy "$@" ;;
        *)          usage ;;
    esac
}

validate_deployment() {
    local manifest="${2:-$TMP_DIR/package.xml}"
    log_info "Validation: $manifest"
    
    [ ! -f "$manifest" ] && log_error "Manifest not found" && exit 1
    
    local RESULT
    if command -v sf >/dev/null 2>&1; then
        RESULT=$(sf project deploy validate --manifest "$manifest" --target-org "$ORG_ALIAS" --test-level "$TEST_LEVEL" --wait 30 --json 2>&1)
    fi
    
    echo "$RESULT" > "$TMP_DIR/validate_result.json"
    local val_id=$(echo "$RESULT" | jq -r '.result.id // .id // empty' 2>/dev/null)
    
    [ -n "$val_id" ] && echo "$val_id" > "$TMP_DIR/validation_id.txt" && log_success "Validation ID: $val_id"
    log_success "Validation done"
}

quick_deploy() {
    local val_id="${2:-}"
    [ -z "$val_id" ] && [ -f "$TMP_DIR/validation_id.txt" ] && val_id=$(cat "$TMP_DIR/validation_id.txt")
    [ -z "$val_id" ] && log_error "Validation ID required" && exit 1
    
    log_info "Quick Deploy: $val_id"
    
    local RESULT
    if command -v sf >/dev/null 2>&1; then
        RESULT=$(sf project deploy quick --validated-request-id "$val_id" --target-org "$ORG_ALIAS" --wait 30 --json 2>&1)
    fi
    
    echo "$RESULT" > "$TMP_DIR/quickdeploy_result.json"
    local status=$(echo "$RESULT" | jq -r '.result.status // .status // "unknown"' 2>/dev/null)
    
    [ "$status" = "Succeeded" ] && log_success "Deploy succeeded!" || { log_error "Deploy failed: $status"; exit 1; }
}

full_deploy() {
    local manifest="${2:-$TMP_DIR/package.xml}"
    log_info "Full Deploy"
    validate_deployment "" "$manifest"
    local val_id=$(cat "$TMP_DIR/validation_id.txt" 2>/dev/null || echo "")
    [ -n "$val_id" ] && quick_deploy "" "$val_id"
}

main "$@"
