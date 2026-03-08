#!/usr/bin/env bash
set -euo pipefail

MODE=${1:-pre}
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/tmp_delta"

if [ "$MODE" = "pre" ]; then
  DESTRUCTIVE_FILE="$TMP_DIR/pre-destructiveChanges.xml"
else
  DESTRUCTIVE_FILE="$TMP_DIR/post-destructiveChanges.xml"
fi

if [ -f "$DESTRUCTIVE_FILE" ]; then
  echo "Deploying $DESTRUCTIVE_FILE..."
  sf project deploy start --manifest "$DESTRUCTIVE_FILE" --ignore-warnings --wait 10
else
  echo "No $DESTRUCTIVE_FILE found, skipping destructive changes."
fi
