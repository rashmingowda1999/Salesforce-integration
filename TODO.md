# CI/CD Pipeline Implementation TODO

## Status: In Progress

### Phase 1: Setup (✅ Completed)
- [x] Create TODO.md
- [x] Create scripts/deploy/ directory and scripts: auth-jwt.sh, generate-delta.sh, deploy-delta.sh, retrieve-profile-delta.sh
- [ ] Enhance existing scripts/apex/run-impacted-tests-coverage.sh and check_coverage.sh for pipeline

### Phase 2: Workflow & Configs
- [ ] Create .github/workflows/salesforce-delta-deploy.yml
- [ ] Update package.json to include sfdx-git-delta dependency
- [ ] Add .forceignore entries for managed packages if needed

### Phase 2: Workflow & Configs
- [ ] Create .github/workflows/salesforce-delta-deploy.yml
- [ ] Update package.json to include sfdx-git-delta dependency
- [ ] Add .forceignore entries for managed packages if needed

### Phase 3: Testing & Validation
- [ ] Install dependencies: npm install, sf plugins install sfdx-git-delta
- [ ] Local test: ./scripts/deploy/auth-jwt.sh && ./scripts/deploy/generate-delta.sh
- [ ] Push to trigger GitHub Actions

### Phase 4: Documentation
- [ ] Update README.md with pipeline usage/secrets setup
- [ ] attempt_completion with full explanation

**Next Step: Create scripts/deploy/ files**

