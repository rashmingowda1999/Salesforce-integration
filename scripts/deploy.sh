#!/bin/bash
# scripts/deploy.sh
# Deploys Salesforce metadata with correct ordering and destructive changes
# Usage: ./deploy.sh [delta|full] [testLevel] [specifiedTests]
# Handles:
#   - Destructive changes (pre/post)
#   - Permission sets after base metadata
#   - Profiles last
#   - Test level and specified tests
#   - Option A: Only deploy profiles/permsets if changed in repo
set -e

PACKAGE_DIR=${1:-delta/package}
TEST_LEVEL=${2:-NoTestRun}
SPECIFIED_TESTS=${3:-}

# If skip_deploy.flag exists, exit
if [ -f delta/skip_deploy.flag ]; then
  echo "No changes to deploy. Skipping deployment."
  exit 0
fi

# Deploy destructiveChangesPre.xml if exists
if [ -f delta/destructiveChangesPre.xml ]; then
  echo "Deploying destructiveChangesPre.xml..."
  sf project deploy start --target-org ci_org --manifest delta/destructiveChangesPre.xml --ignore-warnings --wait 30
fi

# Deploy base metadata (excluding permsets/profiles)
find "$PACKAGE_DIR" -type f ! -path "*/profiles/*" ! -path "*/permissionsets/*" > base_files.txt
if [ -s base_files.txt ]; then
  echo "Deploying base metadata..."
  sf project deploy start --target-org ci_org --source-path $(cat base_files.txt | xargs) --test-level $TEST_LEVEL ${SPECIFIED_TESTS:+--tests "$SPECIFIED_TESTS"} --ignore-warnings --wait 30
fi

# Deploy permission sets
find "$PACKAGE_DIR" -type f -path "*/permissionsets/*" > permset_files.txt
if [ -s permset_files.txt ]; then
  echo "Deploying permission sets..."
  sf project deploy start --target-org ci_org --source-path $(cat permset_files.txt | xargs) --ignore-warnings --wait 30
fi

# Deploy profiles last
find "$PACKAGE_DIR" -type f -path "*/profiles/*" > profile_files.txt
if [ -s profile_files.txt ]; then
  echo "Deploying profiles..."
  sf project deploy start --target-org ci_org --source-path $(cat profile_files.txt | xargs) --ignore-warnings --wait 30
fi

# Deploy destructiveChangesPost.xml if exists
if [ -f delta/destructiveChangesPost.xml ]; then
  echo "Deploying destructiveChangesPost.xml..."
  sf project deploy start --target-org ci_org --manifest delta/destructiveChangesPost.xml --ignore-warnings --wait 30
fi

echo "Deployment complete."

# Option B: To enable safe profile/permset augmentation, see script comments for guidance.
