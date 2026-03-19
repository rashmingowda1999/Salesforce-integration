#!/bin/bash
# scripts/generate-delta.sh
# Generate delta package using sfdx-git-delta
# Inputs: $GITHUB_BASE_REF, $GITHUB_HEAD_REF, $deltaDeploy
# Outputs: delta/package/, destructiveChangesPre.xml, destructiveChangesPost.xml
set -e

# Install sfdx-git-delta if not present
if ! sf plugins | grep -q sfdx-git-delta; then
  echo "Installing sfdx-git-delta plugin..."
  sf plugins install sfdx-git-delta
fi

# If deltaDeploy is false, skip delta and use full package
if [ "$deltaDeploy" != "true" ]; then
  echo "Delta deploy disabled, using full package."
  mkdir -p delta/package
  cp -r force-app/main/default/* delta/package/
  exit 0
fi

# Find base and head commits
BASE_COMMIT=$(git merge-base origin/${GITHUB_BASE_REF:-main} HEAD)
HEAD_COMMIT=$(git rev-parse HEAD)

# Generate delta
sf sgd source delta --to "$HEAD_COMMIT" --from "$BASE_COMMIT" --output delta --generate-destructive-changes --ignore-whitespace

# Check if delta/package is empty
if [ ! -d delta/package ] || [ -z "$(ls -A delta/package 2>/dev/null)" ]; then
  echo "No changes detected in delta package. Skipping deployment."
  echo "skip" > delta/skip_deploy.flag
fi

# Destructive changes files are generated as delta/destructiveChangesPre.xml and delta/destructiveChangesPost.xml
