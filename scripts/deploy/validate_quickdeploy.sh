#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/utils.sh"

ensure_dirs

usage() { echo "Usage: $0 [--checkonly] [--quickdeploy <validatedRequestId>]"; exit 1; }

if [ "$#" -eq 0 ]; then
  usage
fi

if [ "$1" = "--checkonly" ]; then
  log "Validating deployment (checkOnly) using MDAPI deploy"
  if [ -d "$TMP_DIR" ]; then
    sfdx force:mdapi:deploy -d "$TMP_DIR" --checkonly --wait 10 --json > "$TMP_DIR/deploy_validate.json" || true
    REQ_ID=$(jq -r '.result.id // ""' "$TMP_DIR/deploy_validate.json" 2>/dev/null || echo "")
    echo "request_id=$REQ_ID"
    # expose as output for workflow
    echo "::set-output name=request_id::$REQ_ID"
  else
    log "No tmp delta dir found for validation"
    exit 1
  fi
elif [ "$1" = "--quickdeploy" ]; then
  REQ_ID="$2"
  if [ -z "$REQ_ID" ]; then
    echo "No validated request id provided" >&2
    exit 1
  fi
  log "Performing quick deploy using validated request id: $REQ_ID"
  sfdx force:mdapi:deploy --validateddeployrequestid "$REQ_ID" --wait 10 --json > "$TMP_DIR/quickdeploy.json" || true
  jq -r '.status' "$TMP_DIR/quickdeploy.json" || true
else
  usage
fi
