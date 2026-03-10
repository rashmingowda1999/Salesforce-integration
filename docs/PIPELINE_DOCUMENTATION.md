# Salesforce Production CI/CD Pipeline

## Overview
Production-grade CI/CD pipeline for enterprise Salesforce DX implementations using GitHub Actions and Salesforce CLI (sf commands).

## Pipeline Features
- **JWT Authentication**: Secure authentication using `sf auth jwt grant`
- **Delta Deployment**: Intelligent change detection using sfdx-git-delta
- **Quick Deploy**: Faster deployments using validation IDs
- **Apex Testing**: Automated test execution with coverage checks
- **Backup & Rollback**: Metadata backup before deployment
- **Destructive Changes**: Support for pre/post deployment metadata removal

## Pipeline Stages

### 1. Pre-Deployment Analysis
- Detect changes between commits using sfdx-git-delta
- Generate delta package (package.xml) for changed components
- Identify changed metadata types (Apex, Custom Fields, Objects, etc.)

### 2. Authentication
Uses Salesforce CLI JWT authentication:
```bash
sf auth jwt grant \
  --client-id "${{ secrets.CONSUMER_KEY }}" \
  --username "${{ vars.DEPLOYMENT_USER_NAME }}" \
  --jwt-key-file ~/.jwt/server.key \
  --instance-url "${{ vars.INSTANCE_URL }}" \
  --set-default \
  --alias deployment-org
```

### 3. Backup
- Retrieve metadata from target org before deployment
- Create timestamped backups
- Store backup information for rollback

### 4. Validation Deployment
- Deploy delta package in check-only mode (validation)
- Capture validation ID for quick deploy
- Run Apex tests if Apex code changed

### 5. Apex Tests
- Detect changed Apex classes and triggers
- Run impacted test classes
- Verify minimum 85% code coverage

### 6. Quick Deploy
- Use validation ID for faster deployment
- Fallback to full deployment if no validation ID

### 7. Post-Destructive Changes
- Deploy destructiveChangesPost.xml if needed
- Clean up removed metadata components

### 8. Deployment Summary
- Generate deployment report
- Send notifications (configurable)

## GitHub Secrets & Variables

### Secrets (Sensitive Data)
| Secret | Description | Required |
|--------|-------------|----------|
| CONSUMER_KEY | Connected App Consumer Key | Yes |
| DEPLOYMENT_USER_NAME | Salesforce username for deployment | Yes |
| JWT_SERVER_KEY | Private key (.pem) for JWT auth | Yes |

### Variables (Non-Sensitive)
| Variable | Description | Default |
|----------|-------------|---------|
| INSTANCE_URL | Salesforce instance URL | https://login.salesforce.com |

## Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| SF_API_VERSION | Salesforce API version | 65.0 |
| MIN_COVERAGE | Minimum code coverage % | 85 |
| BACKUP_RETENTION_DAYS | Days to retain backups | 90 |

## Trigger Events
- **Push to main**: Auto-deploy changes in force-app/
- **Pull Request**: Validate changes before merge
- **Manual**: Workflow dispatch for full control

## Usage

### Manual Trigger
```bash
gh workflow run BB_salesforce.yml -f deployment_type=delta -f target_org=production -f run_tests=true
```

### Workflow Inputs
| Input | Description | Default |
|-------|-------------|---------|
| deployment_type | delta or full | delta |
| target_org | Target org alias | production |
| run_tests | Run Apex tests | true |

## Scripts

### Deployment Scripts (`scripts/deploy/`)
| Script | Purpose |
|--------|---------|
| generate_delta.sh | Generate delta package using sfdx-git-delta |
| backup.sh | Backup changed metadata from target org |
| deploy_delta.sh | Deploy delta package (validate/quickdeploy/deploy) |
| handle_destructive.sh | Handle pre/post destructive changes |
| filter_profiles.sh | Filter and deploy only delta profile changes |
| validate_quickdeploy.sh | Quick Deploy using validation ID |

### Apex Scripts (`scripts/apex/`)
| Script | Purpose |
|--------|---------|
| run_impacted_tests.sh | Run tests for changed Apex classes |
| check_coverage.sh | Verify code coverage meets minimum |

### Utility Scripts (`scripts/utils/`)
| Script | Purpose |
|--------|---------|
| logging.sh | Logging utilities for pipeline |
| error_handler.sh | Error handling and cleanup routines |

## Best Practices

### Security
1. Never expose credentials in logs
2. Use GitHub secrets for all sensitive data
3. Rotate JWT certificates regularly
4. Enable 2FA for deployment users
5. Use branch protection rules

### Performance
1. Use delta deployments to reduce deployment time
2. Cache Salesforce CLI between runs
3. Run only impacted tests
4. Use parallel job execution where possible

### Reliability
1. Always backup before deployment
2. Use validation + quick deploy pattern
3. Set up deployment monitoring alerts
4. Schedule deployments during off-peak hours
5. Maintain 85%+ code coverage

## Repository Structure

```
salesforce-dx-project/
├── .github/
│   └── workflows/
│       └── BB_salesforce.yml      # Main CI/CD pipeline
├── docs/
│   ├── PIPELINE_DOCUMENTATION.md # This file
│   └── REPOSITORY_STRUCTURE.md   # Repository structure
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/           # Apex classes
│           ├── objects/           # Custom objects
│           └── ...
├── scripts/
│   ├── deploy/                    # Deployment scripts
│   ├── apex/                      # Apex test scripts
│   └── utils/                     # Utility scripts
├── sfdx-project.json
└── package.json
```

## Troubleshooting

### Common Issues
1. **JWT Authentication Failed**: Verify CONSUMER_KEY and JWT_SERVER_KEY
2. **Delta Package Empty**: Check that force-app/ has changes
3. **Test Failures**: Review test logs and fix failing tests
4. **Coverage Below Minimum**: Add more test cases

### Logs
- GitHub Actions logs for pipeline execution
- Salesforce Setup > Deployment Status for deployment details
- Artifacts: delta-package, test-results, metadata-backup

## Support
For issues or questions, please refer to:
- [Salesforce CLI Documentation](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [sfdx-git-delta GitHub](https://github.com/scolladon/sfdx-git-delta)

