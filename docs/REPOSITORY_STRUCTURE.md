# Repository Structure

## Example Folder Structure

```
salesforce-dx-project/
├── .github/
│   └── workflows/
│       ├── salesforce-production-cicd.yml    # Main production pipeline
│       └── salesforce-validate-pr.yml       # PR validation
├── docs/
│   ├── PIPELINE_DOCUMENTATION.md            # Pipeline details
│   └── REPOSITORY_STRUCTURE.md              # This file
├── force-app/
│   └── main/
│       └── default/
│           ├── classes/                      # Apex classes
│           ├── objects/                      # Custom objects
│           ├── profiles/                     # Profile metadata
│           └── ...
├── scripts/
│   └── deploy/
│       ├── backup.sh                         # Backup script
│       ├── enhanced_backup.sh               # Enhanced backup
│       ├── enhanced_delta.sh                # Delta generation
│       ├── enhanced_deploy.sh               # Validate + Quick Deploy
│       ├── enhanced_test_runner.sh          # Apex tests
│       ├── profile_delta.sh                 # Profile filtering
│       └── ...
├── backup/                                   # Backup storage (generated)
│   └── YYYY-MM-DD/
├── sfdx-project.json
└── package.json
```

## Key Files

### Workflows
- `.github/workflows/salesforce-production-cicd.yml` - Main CI/CD pipeline

### Scripts
| Script | Purpose |
|--------|---------|
| `enhanced_delta.sh` | Generate delta package |
| `enhanced_backup.sh` | Backup target org metadata |
| `enhanced_test_runner.sh` | Run Apex tests with coverage |
| `enhanced_deploy.sh` | Validate + Quick Deploy |
| `profile_delta.sh` | Filter profile permissions |

## Best Practices

1. **Source Control**: Commit often with meaningful messages
2. **Metadata Organization**: Group related metadata together
3. **Testing**: Maintain 85%+ code coverage
4. **Backup Strategy**: Always backup before deployment
5. **Security**: Never commit credentials
