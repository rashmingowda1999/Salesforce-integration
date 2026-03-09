# Salesforce Production CI/CD Pipeline

## Overview
Production-grade CI/CD pipeline for enterprise Salesforce DX implementations.

## Pipeline Stages
1. **Pre-Deployment** - Detect changes, generate delta package
2. **Auth & Backup** - JWT auth, metadata backup with 90-day retention
3. **Pre-Destructive** - Deploy destructiveChanges.xml (if any)
4. **Validation** - Validate deployment (checkOnly), capture validation ID
5. **Apex Tests** - Run tests if Apex changed, verify 85% coverage
6. **Quick Deploy** - Deploy using validation ID
7. **Post-Destructive** - Deploy destructiveChangesPost.xml (if any)
8. **Summary** - Generate deployment report

## GitHub Secrets
| Secret | Description |
|--------|-------------|
| CONSUMER_KEY | Connected App Consumer Key |
| DEPLOYMENT_USER_NAME | Salesforce username |
| JWT_SERVER_KEY | Private key (.pem) |

## Variables
| Variable | Description |
|----------|-------------|
| INSTANCE_URL | Salesforce instance URL |

## Environment Variables
- SF_API_VERSION: 58.0
- MIN_COVERAGE: 85%
- BACKUP_RETENTION_DAYS: 90

## Best Practices
1. Use parallel job execution
2. Cache Salesforce CLI
3. Run only relevant tests
4. Use delta deployments
5. Deploy delta profiles only
6. Set up monitoring alerts
7. Schedule during off-peak hours

## Security
- Never expose credentials in logs
- Use GitHub secrets
- Rotate JWT certificates
- Enable 2FA for deployment users
