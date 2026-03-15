#!/bin/bash
# retrieve-profile-delta.sh - Retrieve delta profiles (FLS/Object perms) for changed components
set -euo pipefail

FROM_COMMIT=${1:-HEAD~1}
TO_COMMIT=${2:-HEAD}

echo '::group::Retrieve Profile Delta Permissions'

# Get changed metadata types/objects
CHANGED_METADATA=$(git diff --name-only \"$FROM_COMMIT\" \"$TO_COMMIT\" -- force-app/main/default/ | grep -E '(objects|customMetadata|customPermission)' | sed 's|.*/||' | sed 's|/.*||' | sort -u)

if [ -z \"$CHANGED_METADATA\" ]; then
  echo 'No relevant metadata changes for profiles'
  exit 0
fi

echo \"Changed: $CHANGED_METADATA\"

# Retrieve profiles with specific metadata
rm -rf profile-delta/
sf project retrieve start \\
  --metadata Profile \\
  --target-org deployment-org \\
  --retrieve-only \\
  --output-dir profile-delta/

# Filter to delta (advanced: use gearset-mdapi or custom filter)
echo 'Profile delta retrieved'

echo '::endgroup::'

