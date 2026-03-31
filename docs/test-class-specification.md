# Test Class Specification Guide

This guide explains how to specify additional test classes to run during Salesforce deployments beyond the auto-discovered tests.

## Overview

The CI/CD pipeline automatically discovers test classes using these patterns:
- `AccountService.cls` → looks for `AccountServiceTest.cls` or `TestAccountService.cls`
- Changed test classes are automatically included

However, you can specify **additional test classes** in three ways:

---

## Method 1: PR Description (Recommended for Pull Requests)

### How It Works
When creating a pull request, specify additional test classes in the PR description.

### Steps

1. **Create or edit your PR**
2. **Fill in the "Additional Test Classes" section** of the PR template:

```markdown
## Additional Test Classes
IntegrationTest, FrameworkTest, AccountHelperTest
```

3. **Submit the PR**

The validation workflow will automatically:
- Auto-discover test classes for changed Apex files
- Add the test classes you specified in the PR description
- Run all combined tests during validation

### Example

**PR Description:**
```markdown
## Description
Updated AccountService to handle new business logic

## Additional Test Classes
IntegrationTest, AccountHelperTest

## Testing
- [x] All tests pass locally
- [x] Verified in sandbox
```

**Result:**
```
Auto-discovered: AccountServiceTest
PR-specified: IntegrationTest, AccountHelperTest
Final test list: AccountServiceTest, IntegrationTest, AccountHelperTest
```

---

## Method 2: Commit Message (For Direct Pushes)

### How It Works
When pushing directly to the `test` branch, include test class specifications in your commit message.

### Syntax
Use square brackets with `[test:` or `[tests:` followed by comma-separated class names:

```
[test:IntegrationTest,FrameworkTest]
```

### Example

```bash
git commit -m "Update AccountService logic

Added new validation method to handle edge cases.

[test:IntegrationTest,AccountHelperTest]

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

git push origin test
```

**Result:**
```
Auto-discovered: AccountServiceTest
Commit-specified: IntegrationTest, AccountHelperTest
Final test list: AccountServiceTest, IntegrationTest, AccountHelperTest
```

### Alternative Syntax
Both work:
- `[test:Class1,Class2]`
- `[tests:Class1,Class2]`

---

## Method 3: Manual Workflow Dispatch (For On-Demand Deployments)

### How It Works
Manually trigger the workflow from GitHub Actions UI with custom test class input.

### Steps

1. **Go to GitHub Actions tab**
   - Navigate to your repository
   - Click "Actions" tab
   - Select "Salesforce CI/CD Pipeline"

2. **Click "Run workflow" button** (top right)

3. **Fill in the form:**
   ```
   Use workflow from: test  (select branch)

   Additional test classes to run:
   ┌─────────────────────────────────────┐
   │ IntegrationTest,FrameworkTest       │
   └─────────────────────────────────────┘

   Branch to deploy:
   ┌─────────────────────────────────────┐
   │ test                                │
   └─────────────────────────────────────┘
   ```

4. **Click "Run workflow"**

### When to Use
- Emergency deployments with specific test requirements
- Testing different test class combinations
- Overriding auto-discovery for troubleshooting

---

## Priority and Combination

All three methods can work together and are **additive**:

### Priority Flow
```
Auto-Discovery
    ↓
  [adds]
    ↓
PR Description / Commit Message
    ↓
  [adds]
    ↓
Manual Workflow Dispatch
    ↓
  [results in]
    ↓
Final Combined Test List
```

### Example: All Three Combined

**Scenario:**
- Changed file: `AccountService.cls`
- PR description: `IntegrationTest`
- Commit message: `[test:FrameworkTest]`
- Manual dispatch: `CustomTest`

**Result:**
```
Auto-discovered:    AccountServiceTest
PR-specified:       IntegrationTest
Commit-specified:   FrameworkTest
Manual-specified:   CustomTest

Final test list: AccountServiceTest,IntegrationTest,FrameworkTest,CustomTest
```

---

## Best Practices

### ✅ Do

- Use **PR description** for PRs (most visible and reviewable)
- Use **commit message** for direct pushes to test branch
- Use **manual dispatch** for emergencies or testing
- List only additional tests (auto-discovery handles most cases)
- Use comma-separated format: `Class1, Class2, Class3`

### ❌ Don't

- Don't list auto-discovered tests again (they're already included)
- Don't use spaces around class names (they're trimmed automatically, but better to avoid)
- Don't specify test classes for non-Apex changes (coverage only needed for Apex/Triggers)

---

## Workflow Behavior

### For Apex/Trigger Changes
```
Tests Found → Run specified tests → Validate 85% coverage
```

### For Non-Apex Changes (profiles, objects, fields, flows)
```
No Apex/Triggers → NoTestRun → No coverage requirement
```

### Coverage Validation
- **Threshold**: 85% test run coverage
- **Scope**: Coverage from the specific tests that run
- **Failure**: Deployment fails if coverage < 85%

---

## Examples by Use Case

### Use Case 1: Standard Deployment
**Scenario:** Changed `AccountService.cls`, auto-discovery works fine

**Action:** None needed
```
Auto-discovers: AccountServiceTest
Runs: AccountServiceTest
```

---

### Use Case 2: Integration Tests Needed
**Scenario:** Changed `AccountService.cls`, also need `IntegrationTest`

**Action:** Add to PR description
```markdown
## Additional Test Classes
IntegrationTest
```

**Result:**
```
Runs: AccountServiceTest, IntegrationTest
```

---

### Use Case 3: Framework Tests Required
**Scenario:** Changed trigger, need framework and helper tests

**Action:** Use commit message
```bash
git commit -m "Update AccountTrigger

[test:TriggerFrameworkTest,AccountHelperTest]"
```

**Result:**
```
Runs: AccountTriggerTest, TriggerFrameworkTest, AccountHelperTest
```

---

### Use Case 4: Emergency Deployment
**Scenario:** Need to deploy immediately with specific tests

**Action:** Manual workflow dispatch
```
Actions → Run workflow → Enter: "EmergencyTest,CriticalTest"
```

**Result:**
```
Runs: Auto-discovered tests + EmergencyTest + CriticalTest
```

---

## Troubleshooting

### Tests Not Running?

**Check:**
1. Class names spelled correctly (case-sensitive)
2. Comma-separated format (no semicolons or other separators)
3. Workflow logs show "Additional test classes specified: ..."

### Coverage Still Failing?

**Remember:**
- Additional tests ADD to auto-discovered tests
- Coverage threshold is 85% across all specified tests
- Check individual class coverage in deployment logs

### Manual Dispatch Not Working?

**Verify:**
1. Using correct branch
2. Test class names are valid
3. Check workflow run logs for input parsing

---

## Related Documentation

- [Workflow Configuration](.github/workflows/salesforce_deploy_21_mar.yml)
- [PR Template](.github/pull_request_template.md)
- [Coverage Validation](scripts/ci/check_changed_apex_coverage.sh)

---

## Support

If you encounter issues:
1. Check workflow run logs in GitHub Actions
2. Verify test class names in Salesforce org
3. Review this documentation
4. Contact DevOps team for assistance
