#!/bin/bash
# deploy-delta.sh - Deploy delta package with sf project deploy start
set -euo pipefail

DRY_RUN=${1:-false}

echo '::group::Deploy Delta Package'
if [ \"$DRY_RUN\" = \"true\" ]; then
  echo 'Running DRY-RUN deployment...'
  sf project deploy start \\
    --source-dir delta/ \\
    --target-org deployment-org \\
    --dry-run \\
    --wait 10 \\
    --loglevel debug
else
  echo 'Running FULL deployment...'
  sf project deploy start \\
    --source-dir delta/ \\
    --target-org deployment-org \\
    --wait 10 \\
    --loglevel debug
fi

if [ $? -eq 0 ]; then
  echo '✅ Delta deployment successful'
else
  echo '❌ Delta deployment failed'
  exit 1
fi

# Post-destructive if exists
if [ -f delta/post-destructiveChanges.xml ]; then
  echo 'Applying post-destructive changes...'
  sf project deploy destructive \\
    --manifest delta/post-destructiveChanges.xml \\
    --target-org deployment-org \\
    --wait 10
fi
echo '::endgroup::'

