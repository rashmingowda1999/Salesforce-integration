#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

MODE=${1:-validate}

log "Deploying delta package ($MODE)..."

PKG_DIR="$TMP_DIR"
PKG_XML="$PKG_DIR/package.xml"

if [ ! -f "$PKG_XML" ]; then
  log "No package.xml found, nothing to deploy."
  exit 0
fi

# Deploy using sf CLI and capture deployment id
if [ "$MODE" = "validate" ]; then
  log "Validating deployment..."
  DEPLOY_OUT=$(sf project deploy start --manifest "$PKG_XML" --dry-run --json)
else
  log "Performing actual deployment..."
  DEPLOY_OUT=$(sf project deploy start --manifest "$PKG_XML" --json)
fi

DEPLOY_ID=$(echo "$DEPLOY_OUT" | grep -o '"id":"[^"]*"' | head -1 | cut -d':' -f2 | tr -d '"')

if [ -n "$DEPLOY_ID" ]; then
  echo "Deployment initiated. Deployment ID: $DEPLOY_ID"
  echo "$DEPLOY_ID" > "$TMP_DIR/deployment_id.txt"
else
  echo "Failed to retrieve Deployment ID."
fi
