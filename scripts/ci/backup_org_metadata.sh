#!/usr/bin/env bash
# backup_org_metadata.sh <manifest-path>
set -euo pipefail
MANIFEST="$1"
OUT_DIR="backups/backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$OUT_DIR"
if [ ! -f "$MANIFEST" ]; then
  echo "Manifest $MANIFEST not found; skipping metadata backup."; exit 0
fi

# Try sf project retrieve if available
if command -v sf >/dev/null 2>&1; then
  echo "Retrieving metadata via sf project retrieve start"
  sf project retrieve start --manifest "$MANIFEST" --target-org ${TARGET_ORG_ALIAS:-targetOrg} --output-dir "$OUT_DIR" || true
else
  echo "sf CLI not available; cannot retrieve metadata"; exit 1
fi

# Zip the backup
ZIPFILE="$OUT_DIR.zip"
zip -r "$ZIPFILE" "$OUT_DIR" >/dev/null
echo "Backup created: $ZIPFILE"
# Optionally upload as artifact (workflow will handle upload)
