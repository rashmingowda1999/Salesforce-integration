#!/bin/bash
# generate-delta.sh - Generate delta package using sfdx-git-delta
set -euo pipefail

FROM_COMMIT=${1:-HEAD~1}
TO_COMMIT=${2:-HEAD}

echo '::group::Generate Delta Package'
echo \"Git diff: $FROM_COMMIT..$TO_COMMIT\"

# Install if not present
sf plugins install sfdx-git-delta@latest || true

# Generate delta
rm -rf delta/
sfdx-git-delta generate \\
  --from \"$FROM_COMMIT\" \\
  --to \"$TO_COMMIT\" \\
  --output delta/ \\
  --ignore .forceignore

# Handle destructive changes
if [ -f pre-destructiveChanges.xml ]; then
  cp pre-destructiveChanges.xml delta/
  echo 'Pre-destructiveChanges.xml included'
fi

if [ -f post-destructiveChanges.xml ]; then
  cp post-destructiveChanges.xml delta/
  echo 'Post-destructiveChanges.xml included'
fi

# Permission sets auto-included if changed

echo 'Delta package generated:'
ls -la delta/
echo '::endgroup::'

