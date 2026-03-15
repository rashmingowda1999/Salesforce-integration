#!/usr/bin/env bash
set -euo pipefail

# Script to generate Salesforce delta package using sfdx-git-delta between two git commits
# Usage: ./generate-delta.sh <from_commit> <to_commit> [output_dir]
# Example: ./generate-delta.sh HEAD~1 HEAD delta-package

# Default values
FROM_COMMIT=${1:?Error: From commit is required}
TO_COMMIT=${2:?Error: To commit is required}
OUTPUT_DIR=${3:-delta}

# Ensure we're in the Salesforce project root
if [[ ! -f sfdx-project.json ]]; then
  echo "Error: sfdx-project.json not found. Run from Salesforce project root." >&2
  exit 1
fi

# Check if sfdx-git-delta is installed
if ! sfdx plugins | grep -q "sfdx-git-delta"; then
  echo "Installing sfdx-git-delta plugin..."
  sfdx plugins:install sfdx-git-delta@latest
fi

echo "Generating delta package from $FROM_COMMIT to $TO_COMMIT, output: $OUTPUT_DIR"

# Generate delta
npx sfdx-git-delta generate \
  --from "$FROM_COMMIT" \
  --to "$TO_COMMIT" \
  --output "$OUTPUT_DIR" \
  --source "force-app"

if [[ -d "$OUTPUT_DIR" ]]; then
  echo "Delta package generated successfully in $OUTPUT_DIR/"
  echo "Contains:"
  ls -la "$OUTPUT_DIR/"
else
  echo "Error: Delta generation failed" >&2
  exit 1
fi

