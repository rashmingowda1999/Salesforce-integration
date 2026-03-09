# Salesforce DX Project with CI/CD Pipeline

![Salesforce](https://img.shields.io/badge/Salesforce-CI%2FCD-blue)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Production-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Overview

This is a production-ready Salesforce DX project with a comprehensive CI/CD pipeline built on GitHub Actions. The pipeline implements enterprise-grade deployment patterns including delta deployment, automated backups, and thorough testing.

## Features

- **Delta Deployment**: Only deploy changed metadata components using sfdx-git-delta
- **JWT Authentication**: Secure server-to-server authentication with Salesforce
- **Automated Backup**: Pre-deployment metadata backup with 90-day retention
- **Validate → Quick Deploy**: Efficient deployment pattern for faster releases
- **Apex Test Coverage**: 85% minimum code coverage threshold
- **Destructive Changes**: Support for pre and post deployment deletions
- **Profile Delta Strategy**: Deploy only required profile permissions
- **Managed Package Filtering**: Exclude managed package components from deployment

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── salesforce-production-cicd.yml    # Main production pipeline
│       └── BB_salesforce.yml                 # Legacy workflow
├── docs/
│   ├── PIPELINE_DOCUMENTATION.md            # Pipeline details
│   └── REPOSITORY_STRUCTURE.md              # Project structure
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/                      # Apex classes
│           ├── objects/                     # Custom objects
│           ├── profiles/                   # Profile metadata
│           └── ...
├── scripts/
│   └── deploy/
│       ├── backup.sh                        # Backup script
│       ├── generate_delta.sh               # Delta generation
│       ├── run_tests.sh                     # Apex tests
│       └── ...
├── sfdx-project.json
└── package.json
```

## Getting Started

### Prerequisites

- GitHub repository with GitHub Actions enabled
- Salesforce org (Sandbox or Production)
- Connected App with OAuth enabled for JWT flow

### Configuration

1. **Create a Connected App in Salesforce**:
   - Enable OAuth Settings
   - Enable OAuth for JWT Flow
   - Note the Consumer Key

2. **Configure GitHub Secrets**:

   | Secret | Description |
   |--------|-------------|
   | `CONSUMER_KEY` | Salesforce Connected App Consumer Key |
   | `DEPLOYMENT_USER_NAME` | Salesforce username |
   | `JWT_SERVER_KEY` | Private key (.pem file content) |

3. **Configure GitHub Variables**:

   | Variable | Description |
   |----------|-------------|
   | `INSTANCE_URL` | Salesforce instance URL |

### Pipeline Triggers

The pipeline runs on:
- Push to `main` or `develop` branches
- Pull requests to `main` branch
- Manual trigger (`workflow_dispatch`)

## Pipeline Stages

1. **Pre-Deployment**: Generate delta package from git changes
2. **Authentication & Backup**: JWT auth + backup target org metadata
3. **Pre-Destructive**: Deploy deletions before main deployment (optional)
4. **Validation**: Validate deployment without making changes
5. **Apex Tests**: Run tests if Apex classes changed
6. **Quick Deploy**: Execute validated deployment
7. **Post-Destructive**: Deploy deletions after main deployment (optional)
8. **Summary**: Generate deployment report

## Scripts

### Delta Generation

```bash
./scripts/deploy/generate_delta.sh
```

Generates a delta package containing only changed metadata components.

### Backup

```bash
./scripts/deploy/backup.sh
```

Retrieves metadata from the target org and backs it up with 90-day retention.

### Run Tests

```bash
./scripts/deploy/run_tests.sh
```

Runs Apex tests and verifies 85% code coverage threshold.

### Validate & Quick Deploy

```bash
./scripts/deploy/validate_quickdeploy.sh --checkonly
./scripts/deploy/validate_quickdeploy.sh --quickdeploy <validation_id>
```

Validates deployment and performs quick deploy using the validation ID.

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    GITHUB ACTIONS                          │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  1. PRE-DEPLOYMENT                                          │
│     • Detect changes in force-app/                         │
│     • Generate delta package (package.xml)                  │
│     • Filter managed packages                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. AUTH & BACKUP                                           │
│     • JWT authentication to Salesforce                      │
│     • Retrieve and backup target org metadata               │
│     • Apply 90-day retention policy                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  3. PRE-DESTRUCTIVE (optional)                              │
│     • Deploy destructiveChanges.xml                        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  4. VALIDATION                                              │
│     • Validate deployment (checkOnly)                       │
│     • Capture validation ID                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  5. APEX TESTS (if Apex changed)                            │
│     • Run tests for changed classes                         │
│     • Verify 85% code coverage                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  6. QUICK DEPLOY                                            │
│     • Deploy using validation ID                            │
│     • Faster than full deployment                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  7. POST-DESTRUCTIVE (optional)                             │
│     • Deploy destructiveChangesPost.xml                    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  8. SUMMARY                                                 │
│     • Generate deployment report                            │
│     • Upload artifacts                                      │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SF_API_VERSION` | 58.0 | Salesforce API version |
| `MIN_COVERAGE` | 85 | Minimum code coverage % |
| `BACKUP_RETENTION_DAYS` | 90 | Backup retention period |

## Security

 stored in GitHub Secrets
- JWT- All credentials keys never exposed in logs
- Credentials cleaned up after use
- Production deployments require approval

## Best Practices

1. **Always use feature branches** for development
2. **Write comprehensive Apex tests** with >85% coverage
3. **Review changes** via pull requests before merging
4. **Test in sandbox** before production deployment
5. **Monitor deployments** using the summary logs

## Troubleshooting

### Authentication Failed
- Verify JWT key format (PEM)
- Check Consumer Key is correct
- Ensure user has API Enabled permission

### Coverage Below Threshold
- Add more test cases
- Check for untested exception handling

### Validation Fails
- Check for missing dependencies
- Verify field-level security settings
- Ensure profiles have required permissions

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues or questions, please open a GitHub issue.

---

**Note**: This project is designed for enterprise Salesforce implementations. Adjust configurations as needed for your specific organization requirements.

