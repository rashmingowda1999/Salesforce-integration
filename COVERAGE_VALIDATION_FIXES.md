# Salesforce Coverage Validation Fixes

## Issues Resolved

### 1. Apex Class Not Being Recognized ✅ FIXED
**Problem**: Workflow was checking for `changed-sources/package.xml` but sfdx-git-delta creates `changed-sources/package/package.xml`

**Solution**:
- Updated workflow to check correct path: `${{ env.DELTA_DIR }}/package/package.xml`
- Updated coverage script to look for Apex classes in `changed-sources/force-app/` instead of `changed-sources/`
- Updated sfdx-git-delta command to use non-deprecated flags: `--output-dir` and `--source-dir`

### 2. Async Test Execution Issue ✅ FIXED
**Problem**: SF CLI was running tests asynchronously and only returning test run ID instead of full coverage results

**Solution**:
- Added `--wait 10` flag to make tests run synchronously (wait up to 10 minutes)
- Added fallback logic to detect async execution and fetch results using test run ID
- Enhanced error handling and debugging for test result parsing

### 3. Coverage Data Extraction ✅ IMPROVED
**Problem**: Script only looked for `.result.coverage` in JSON response

**Solution**:
- Added multiple coverage data path checks: `.result.coverage`, `.result.tests.coverage`, `.result.codecoverage`
- Added debugging output to show JSON structure for troubleshooting
- Improved error messages when coverage data cannot be found

### 4. Test Class Coverage Validation ✅ NEW FEATURE
**Enhancement**: Added validation for test class coverage in addition to main class coverage

**What it does**:
- When `AccountDescriptionUpdater.cls` changes → validates coverage for BOTH `AccountDescriptionUpdater` AND `TestAccountDescriptionUpdater`
- Ensures both business logic and test code maintain quality coverage standards
- Provides clear labeling in output to distinguish "Main class" vs "Test class" results
- Comprehensive coverage summary shows all classes being validated

**Example Output**:
```
📊 COVERAGE VALIDATION SUMMARY:
Test classes to execute: TestAccountDescriptionUpdater
Classes requiring 85% coverage: AccountDescriptionUpdater,TestAccountDescriptionUpdater

Main class: AccountDescriptionUpdater | Coverage: 95% | Threshold: 85% ✅
Test class: TestAccountDescriptionUpdater | Coverage: 88% | Threshold: 85% ✅
```

## Current Workflow

1. **Detects changed files** using `git diff HEAD~1 HEAD`
2. **Generates delta package** using sfdx-git-delta
3. **Finds changed Apex classes** in `changed-sources/force-app/main/default/classes/`
4. **Identifies test classes** using naming conventions (`TestClassName`, `ClassNameTest`, etc.)
5. **Runs targeted tests** with coverage using SF CLI
6. **Validates coverage** meets 85% threshold for BOTH changed classes AND their test classes
7. **Reports results** with ✅ PASS or ❌ FAIL status

## Test Class Auto-Discovery

The script automatically finds test classes using these patterns:
- `Test{ClassName}` (e.g., `TestAccountDescriptionUpdater`)
- `{ClassName}Test` (e.g., `AccountDescriptionUpdaterTest`)
- `{ClassName}Tests` (e.g., `AccountDescriptionUpdaterTests`)
- `Test{ClassName}s` (e.g., `TestAccountDescriptionUpdaters`)

## Files Modified

- `.github/workflows/salesforce_deploy_21_mar.yml` - Fixed package.xml path and sfdx-git-delta flags
- `scripts/ci/check_changed_apex_coverage.sh` - Added async handling and improved coverage extraction

## Commits

1. **3a5e09b** - Fix Apex class recognition in coverage workflow
2. **17b0bf0** - Improve async test execution handling in coverage script
3. **9f52d25** - Enhance coverage data parsing with comprehensive debugging
4. **4c923ab** - Handle both regular class and test class changes in coverage validation
5. **b073ebc** - Add test class coverage validation to deployment process