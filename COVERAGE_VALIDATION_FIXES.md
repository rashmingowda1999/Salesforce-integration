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

### 4. Test Class Coverage Validation ✅ FOCUSED VALIDATION
**Enhancement**: Uses testRunCoverage from summary for validation instead of individual class coverage

**What it does**:
- When any Apex class changes → runs corresponding test classes → validates **testRunCoverage ≥ 85%**
- Uses the `testRunCoverage` percentage from the test result summary (e.g., `"testRunCoverage": "100%"`)
- Much simpler and more accurate than trying to find individual test class coverage data

**Why this approach**:
- Test classes don't appear in the coverage array because they're the ones doing the testing
- The coverage array only contains coverage for main classes being tested
- `testRunCoverage` gives the overall coverage percentage for the entire test run

**Example Output**:
```
📊 TEST RUN COVERAGE VALIDATION:
Overall test run coverage: 100% | Threshold: 85%

✅ COVERAGE CHECK PASSED!
Test run coverage (100%) meets the 85% requirement.
```

### 5. TestRunCoverage Validation Fix ✅ CRITICAL FIX
**Problem**: Script was looking for individual test class coverage in the coverage array, but test classes don't appear there

**Root Cause**:
- Test classes don't appear in the coverage data because they're the ones doing the testing
- The coverage array only contains coverage for main classes being tested (like `AccountDescriptionUpdater`)
- Script was trying to find `TestAccountDescriptionUpdater` in coverage data, which doesn't exist

**Solution**:
- Use `testRunCoverage` from the summary section instead (e.g., `"testRunCoverage": "100%"`)
- This represents the overall coverage percentage for the entire test run
- Much more reliable and accurate approach

## Current Workflow

1. **Detects changed files** using `git diff HEAD~1 HEAD`
2. **Generates delta package** using sfdx-git-delta
3. **Finds changed Apex classes** in `changed-sources/force-app/main/default/classes/`
4. **Identifies test classes** using naming conventions (`TestClassName`, `ClassNameTest`, etc.)
5. **Runs targeted tests** with coverage using SF CLI
6. **Validates testRunCoverage** meets 85% threshold using summary data
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
6. **c44b6db** - Simplify coverage validation to test classes only
7. **8645dbe** - Fix coverage validation to use testRunCoverage from summary