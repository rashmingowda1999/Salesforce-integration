#!/bin/bash
# auth-jwt.sh - JWT Authentication for Salesforce CLI
set -euo pipefail

echo '::group::Authenticate with JWT'
echo '$SF_CLIENT_ID' | sf org login jwt \\
  --client-id \"${SF_CLIENT_ID}\" \\
  --jwt-key-file /tmp/server.key \\
  --username \"${SF_USERNAME}\" \\
  --instance-url \"${SF_INSTANCE_URL}\" \\
  --alias deployment-org \\
  --set-default \\
  --loglevel debug

if [ $? -eq 0 ]; then
  echo '✅ JWT Authentication successful'
  sf org display --target-org deployment-org --verbose
else
  echo '❌ JWT Authentication failed'
  exit 1
fi
echo '::endgroup::'

