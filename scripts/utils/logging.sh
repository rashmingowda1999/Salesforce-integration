#!/bin/bash
# ============================================================================
# logging.sh - Logging utilities for deployment pipeline
# ============================================================================
# This script provides logging functions for the deployment pipeline.
# ============================================================================

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Default log level
CURRENT_LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Timestamp format
TIMESTAMP_FORMAT="%Y-%m-%d %H:%M:%S"

log_debug() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_DEBUG" ]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date +"$TIMESTAMP_FORMAT") - $1"
    fi
}

log_info() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_INFO" ]; then
        echo -e "${GREEN}[INFO]${NC}  $(date +"$TIMESTAMP_FORMAT") - $1"
    fi
}

log_warn() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_WARN" ]; then
        echo -e "${YELLOW}[WARN]${NC}  $(date +"$TIMESTAMP_FORMAT") - $1"
    fi
}

log_error() {
    if [ "$CURRENT_LOG_LEVEL" -le "$LOG_LEVEL_ERROR" ]; then
        echo -e "${RED}[ERROR]${NC} $(date +"$TIMESTAMP_FORMAT") - $1"
    fi
}

log_section() {
    echo ""
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo ""
}

log_subsection() {
    echo ""
    echo "--- $1 ---"
}

# Log deployment start
log_deployment_start() {
    log_section "SALESFORCE DEPLOYMENT STARTED"
    log_info "Workflow: ${WORKFLOW_NAME:-CI/CD}"
    log_info "Run ID: ${RUN_ID:-N/A}"
    log_info "Trigger: ${TRIGGER:-manual}"
    log_info "Commit: ${COMMIT_SHA:-N/A}"
}

# Log deployment end
log_deployment_end() {
    local status=$1
    log_section "SALESFORCE DEPLOYMENT $status"
    log_info "Duration: ${DURATION:-N/A}"
    log_info "Completed at: $(date +"$TIMESTAMP_FORMAT")"
}

# Export functions for use in other scripts
export -f log_debug
export -f log_info
export -f log_warn
export -f log_error
export -f log_section
export -f log_subsection
export -f log_deployment_start
export -f log_deployment_end

