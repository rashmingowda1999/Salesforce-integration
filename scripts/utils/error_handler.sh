#!/bin/bash
# ============================================================================
# error_handler.sh - Error handling utilities for deployment pipeline
# ============================================================================
# This script provides error handling functions and cleanup routines.
# ============================================================================

# Exit on error
set -e

# Error tracking
ERROR_COUNT=0
ERROR_LOG="errors.log"

# Capture errors
trap 'capture_error $?' ERR

capture_error() {
    local exit_code=$1
    local line_number=$2
    
    ERROR_COUNT=$((ERROR_COUNT + 1))
    
    echo ""
    echo "=============================================="
    echo "  ERROR DETECTED"
    echo "=============================================="
    echo "Exit Code: $exit_code"
    echo "Line: $line_number"
    echo "Command: ${BASH_COMMAND}"
    echo "=============================================="
    
    # Log error
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] Error $exit_code at line $line_number: ${BASH_COMMAND}" >> "$ERROR_LOG"
    
    # Send alert (if configured)
    send_alert "Deployment failed with error code: $exit_code"
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    echo ""
    echo "=============================================="
    echo "  CLEANUP ROUTINE"
    echo "=============================================="
    
    # Clean up temporary files
    if [ -d "tmp_delta" ]; then
        echo "Cleaning up temporary delta files..."
        rm -rf tmp_delta 2>/dev/null || true
    fi
    
    # Clean up retrieved files
    if [ -d "retrieved_changes" ]; then
        echo "Cleaning up retrieved metadata..."
        rm -rf retrieved_changes 2>/dev/null || true
    fi
    
    if [ $exit_code -ne 0 ]; then
        echo ""
        echo "❌ Deployment failed with exit code: $exit_code"
        echo "Check $ERROR_LOG for details"
        
        # Upload error logs as artifact
        if [ -f "$ERROR_LOG" ]; then
            echo ""
            echo "Error log contents:"
            cat "$ERROR_LOG"
        fi
    else
        echo ""
        echo "✅ Deployment completed successfully"
        rm -f "$ERROR_LOG" 2>/dev/null || true
    fi
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT

# Send alert function (can be extended for Slack, email, etc.)
send_alert() {
    local message="$1"
    
    echo ""
    echo "=============================================="
    echo "  SENDING ALERT"
    echo "=============================================="
    echo "Message: $message"
    echo "=============================================="
    
    # Extend this function to integrate with:
    # - Slack webhooks
    # - Email notifications
    # - PagerDuty
    # - Microsoft Teams
    
    # Example: Slack webhook (commented out)
    # if [ -n "$SLACK_WEBHOOK_URL" ]; then
    #     curl -X POST -H 'Content-type: application/json' \
    #         --data "{\"text\":\"Salesforce Deployment Alert: $message\"}" \
    #         "$SLACK_WEBHOOK_URL"
    # fi
}

# Retry function
retry_command() {
    local max_attempts=$1
    local delay=$2
    local command="${@:3}"
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt of $max_attempts: $command"
        
        if eval "$command"; then
            echo "Command succeeded"
            return 0
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Command failed. Retrying in $delay seconds..."
            sleep $delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    echo "Command failed after $max_attempts attempts"
    return 1
}

# Validate required environment variables
validate_env_vars() {
    local missing_vars=()
    
    for var in "$@"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo ""
        echo "=============================================="
        echo "  MISSING ENVIRONMENT VARIABLES"
        echo "=============================================="
        echo "Missing variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo "=============================================="
        
        send_alert "Deployment failed: Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

# Export functions
export -f capture_error
export -f cleanup
export -f send_alert
export -f retry_command
export -f validate_env_vars

