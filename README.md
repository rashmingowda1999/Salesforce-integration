# Salesforce DX Project with Delta CI/CD Pipeline

## CI/CD Pipeline

Production-ready GitHub Actions workflow using Salesforce CLI (sf) and sfdx-git-delta for delta deployments.

### Setup GitHub Secrets & Vars
Repository Settings > Secrets and variables > Actions:

**Secrets:**
- `CONSUMER_KEY`: Salesforce Connected App Consumer Key (Client ID)
- `DEPLOYMENT_USER_NAME`: Permission set license user email
- `JWT_SERVER_KEY`: Multi-line private key from Connected App

**Variables:**
- `INSTANCE_URL`: https://your-instance.my.salesforce.com

### Triggers
- Push/PR to branches matching `github_copilot_*`

### Flow
1. JWT Auth (`sf org login jwt`)
2. Apex tests/coverage if changed (85% min)
3. Generate delta package (changed metadata only)
4. Profile FLS delta if relevant
5. Deploy (dry-run on PR, full on push)
6. Post-destructives

See `.github/workflows/salesforce-delta-deploy.yml` and `scripts/deploy/`.

## Local Development
```bash
cd Salesforce-integration
npm install
sf plugins install sfdx-git-delta
git checkout -b github_copilot_test
# make changes
./scripts/deploy/generate-delta.sh HEAD~1
./scripts/deploy/deploy-delta.sh true  # dry-run
```

