#!/bin/bash
# scripts/backup.sh
# Optional: Retrieve org metadata and upload as artifact
# Usage: ./backup.sh
set -e

BACKUP_DIR=backup_$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"

# Retrieve metadata (customize as needed)
sf project retrieve start --target-org ci_org --manifest manifest/package.xml --output-dir "$BACKUP_DIR"

# Compress backup
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"

echo "Backup complete: $BACKUP_DIR.tar.gz"
