# NOTE: If running in GitHub Actions, ensure this script is executable:
#   - name: Make scripts executable
#     run: chmod +x ./scripts/*.sh
#!/bin/bash
# scripts/auth.sh
# Authenticate to Salesforce using JWT or SFDX Auth URL
# Requires env vars: CONSUMER_KEY, DEPLOYMENT_USER_NAME, JWT_SERVER_KEY, INSTANCE_URL
# Optionally: SFDX_AUTH_URL
set -e

if [ -n "$INSTANCE_URL" ]; then
  echo "Authenticating using SFDX Auth URL..."
  echo $INSTANCE_URL > sfdx_auth_url.txt
  sf org login sfdx-url --sfdx-url-file sfdx_auth_url.txt --set-default --alias ci_org
  rm sfdx_auth_url.txt
else
  echo "Authenticating using JWT..."
  echo "$JWT_SERVER_KEY" > server.key
  sf org login jwt \
    --client-id "$CONSUMER_KEY" \
    --jwt-key-file server.key \
    --username "$DEPLOYMENT_USER_NAME" \
    --instance-url "$INSTANCE_URL" \
    --set-default --alias ci_org
  rm server.key
fi

echo "Auth successful."
