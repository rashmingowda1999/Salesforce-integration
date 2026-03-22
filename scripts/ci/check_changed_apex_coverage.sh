#!/bin/bash
# scripts/ci/check_changed_apex_coverage.sh
# Checks coverage for individual changed Apex classes only
# Fails if any changed class has <85% coverage
# Usage: ./check_changed_apex_coverage.sh [delta_dir] [target_org_alias]

set -e

DELTA_DIR=${1:-"changed-sources"}
TARGET_ORG_ALIAS=${2:-"targetOrg"}
COVERAGE_THRESHOLD=${3:-85}

echo "Checking coverage for changed Apex classes..."
echo "Delta directory: $DELTA_DIR"
echo "Target org: $TARGET_ORG_ALIAS"
echo "Coverage threshold: $COVERAGE_THRESHOLD%"

# Find ALL changed Apex classes (both regular and test classes)
CHANGED_APEX_CLASSES=""
CHANGED_TEST_CLASSES=""

if [ -d "$DELTA_DIR/force-app" ]; then
    # Find regular (non-test) classes
    CHANGED_APEX_CLASSES=$(find "$DELTA_DIR/force-app" -type f -name "*.cls" ! -name "*Test*.cls" ! -name "Test*.cls" 2>/dev/null || true)
    # Find test classes
    CHANGED_TEST_CLASSES=$(find "$DELTA_DIR/force-app" -type f -name "*Test*.cls" -o -name "Test*.cls" 2>/dev/null || true)
elif [ -d "$DELTA_DIR" ]; then
    # Fallback: look in the root delta dir (for backwards compatibility)
    CHANGED_APEX_CLASSES=$(find "$DELTA_DIR" -type f -name "*.cls" ! -name "*Test*.cls" ! -name "Test*.cls" 2>/dev/null || true)
    CHANGED_TEST_CLASSES=$(find "$DELTA_DIR" -type f -name "*Test*.cls" -o -name "Test*.cls" 2>/dev/null || true)
fi

if [ -z "$CHANGED_APEX_CLASSES" ] && [ -z "$CHANGED_TEST_CLASSES" ]; then
    echo "No Apex classes (regular or test) changed. Skipping coverage check."
    exit 0
fi

echo "Processing changed Apex classes..."
if [ -n "$CHANGED_APEX_CLASSES" ]; then
    echo "Changed regular classes:"
    echo "$CHANGED_APEX_CLASSES"
fi
if [ -n "$CHANGED_TEST_CLASSES" ]; then
    echo "Changed test classes:"
    echo "$CHANGED_TEST_CLASSES"
fi
# Extract class names and find corresponding test classes
TEST_CLASSES_TO_RUN=""
CLASSES_TO_CHECK=""

# Process regular (non-test) classes
if [ -n "$CHANGED_APEX_CLASSES" ]; then
    echo "Processing regular classes to find their test classes..."
    echo ""
    for class_file in $CHANGED_APEX_CLASSES; do
        # Extract class name from file path (remove .cls extension)
        class_name=$(basename "$class_file" .cls)

        echo "🔍 Changed Apex class: $class_name"
        echo "   Searching for corresponding test class..."

        # Find corresponding test class(es) - check common naming patterns
        test_class_patterns=(
            "Test$class_name"
            "${class_name}Test"
            "${class_name}Tests"
            "Test${class_name}s"
        )

        found_test=false
        for pattern in "${test_class_patterns[@]}"; do
            # Check if test class exists in force-app
            test_file_path="force-app/main/default/classes/${pattern}.cls"
            if [ -f "$test_file_path" ]; then
                echo "   ✅ Found test class: $pattern"
                if [[ ",$TEST_CLASSES_TO_RUN," == *",$pattern,"* ]]; then
                    echo "   ⚠️  Test class $pattern already in execution list - skipping duplicate"
                else
                    echo "   📋 Deployment will run: $pattern → validates $class_name"
                fi
                if [ -z "$TEST_CLASSES_TO_RUN" ]; then
                    TEST_CLASSES_TO_RUN="$pattern"
                else
                    # Check if this test class is already in the list (avoid duplicates)
                    if [[ ",$TEST_CLASSES_TO_RUN," != *",$pattern,"* ]]; then
                        TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$pattern"
                    fi
                fi
                # Add test class to coverage check (not the main class) - avoid duplicates
                if [[ ",$CLASSES_TO_CHECK," != *",$pattern,"* ]]; then
                    if [ -z "$CLASSES_TO_CHECK" ]; then
                        CLASSES_TO_CHECK="$pattern"
                    else
                        CLASSES_TO_CHECK="$CLASSES_TO_CHECK,$pattern"
                    fi
                fi
                found_test=true
                break
            fi
        done

        if [ "$found_test" = false ]; then
            echo "   ❌ No test class found using standard naming conventions"
            echo "   🔍 Checked patterns: ${test_class_patterns[*]}"
        fi
        echo ""
    done
fi

# Process test classes
if [ -n "$CHANGED_TEST_CLASSES" ]; then
    echo "Processing changed test classes..."
    echo ""
    for test_file in $CHANGED_TEST_CLASSES; do
        # Extract test class name from file path (remove .cls extension)
        test_class_name=$(basename "$test_file" .cls)

        echo "🧪 Changed test class: $test_class_name"

        # Check if this test class is already scheduled to run
        if [[ ",$TEST_CLASSES_TO_RUN," == *",$test_class_name,"* ]]; then
            echo "   ⚠️  Test class $test_class_name already scheduled (from regular class change) - skipping duplicate"
        fi

        # Add test class to run list (avoid duplicates)
        if [ -z "$TEST_CLASSES_TO_RUN" ]; then
            TEST_CLASSES_TO_RUN="$test_class_name"
        else
            # Check if this test class is already in the list (avoid duplicates)
            if [[ ",$TEST_CLASSES_TO_RUN," != *",$test_class_name,"* ]]; then
                TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$test_class_name"
            fi
        fi

        # Add test class to coverage check list (we only check test class coverage)
        if [[ ",$CLASSES_TO_CHECK," != *",$test_class_name,"* ]]; then
            if [ -z "$CLASSES_TO_CHECK" ]; then
                CLASSES_TO_CHECK="$test_class_name"
            else
                CLASSES_TO_CHECK="$CLASSES_TO_CHECK,$test_class_name"
            fi
        fi

        # Determine what main class this test is for (for informational purposes only)
        main_class_name=""
        if [[ "$test_class_name" =~ ^Test(.+)$ ]]; then
            # Pattern: TestClassName -> ClassName
            main_class_name="${BASH_REMATCH[1]}"
        elif [[ "$test_class_name" =~ ^(.+)Test(s?)$ ]]; then
            # Pattern: ClassNameTest(s) -> ClassName
            main_class_name="${BASH_REMATCH[1]}"
        fi

        if [ -n "$main_class_name" ]; then
            # Check if the main class actually exists
            main_class_path="force-app/main/default/classes/${main_class_name}.cls"
            if [ -f "$main_class_path" ]; then
                echo "   🎯 Tests main class: $main_class_name"
                echo "   📋 Deployment will run: $test_class_name → validates test coverage"
            else
                echo "   ℹ️  No corresponding main class found ($main_class_name)"
                echo "   📋 Deployment will run: $test_class_name → validates test coverage"
            fi
        else
            echo "   ℹ️  Could not determine corresponding main class"
            echo "   📋 Deployment will run: $test_class_name → validates test coverage"
        fi
        echo ""
    done
fi

if [ -z "$TEST_CLASSES_TO_RUN" ]; then
    echo "No test classes found to run. This could happen if:"
    echo "- Changed regular classes have no corresponding test classes"
    echo "- Changed test classes don't follow naming conventions"
    echo "Changed regular classes: $CHANGED_APEX_CLASSES"
    echo "Changed test classes: $CHANGED_TEST_CLASSES"
    exit 1
fi

if [ -z "$CLASSES_TO_CHECK" ]; then
    echo "No classes found to check coverage for. This is likely an error."
    echo "Test classes to run: $TEST_CLASSES_TO_RUN"
    exit 1
fi

echo "Test classes to run: $TEST_CLASSES_TO_RUN"
echo "Classes to check coverage for: $CLASSES_TO_CHECK"
echo ""
echo "=========================================="
echo "📊 DEPLOYMENT COVERAGE VALIDATION SUMMARY"
echo "=========================================="
echo ""
IFS=',' read -ra TEST_ARRAY <<< "$TEST_CLASSES_TO_RUN"
for test_class in "${TEST_ARRAY[@]}"; do
    echo "🧪 Test class to execute: $test_class"
done
echo ""
echo "📈 Coverage validation: testRunCoverage ≥ $COVERAGE_THRESHOLD%"
echo "=========================================="
echo ""

# Pre-execution validation checks
echo "🔍 Pre-execution validation checks..."

# Check if SF CLI is available
if ! command -v sf &> /dev/null; then
    echo "❌ SF CLI not found! Please install Salesforce CLI."
    exit 1
fi
echo "✅ SF CLI found"

# Check if target org is accessible
echo "🔗 Testing connection to target org: $TARGET_ORG_ALIAS"
sf org display --target-org "$TARGET_ORG_ALIAS" --json > org_check.json 2>&1
ORG_CHECK_EXIT_CODE=$?

if [ $ORG_CHECK_EXIT_CODE -ne 0 ]; then
    echo "❌ Cannot connect to target org: $TARGET_ORG_ALIAS"
    echo "Org connection test output:"
    cat org_check.json
    rm -f org_check.json

    echo ""
    echo "🔧 Please verify:"
    echo "• Org authentication is valid"
    echo "• Org alias '$TARGET_ORG_ALIAS' exists"
    echo "• Network connectivity to Salesforce"
    exit 1
else
    echo "✅ Successfully connected to target org"
    # Show org details for confirmation
    ORG_USERNAME=$(cat org_check.json | jq -r '.result.username // "Unknown"')
    ORG_INSTANCE_URL=$(cat org_check.json | jq -r '.result.instanceUrl // "Unknown"')
    echo "   📋 Username: $ORG_USERNAME"
    echo "   🔗 Instance: $ORG_INSTANCE_URL"
fi
rm -f org_check.json

# Run the specific test classes and get coverage
echo ""
echo "🧪 Running tests and collecting coverage..."
TEST_RESULT_FILE="test-result-$(date +%s).json"
ERROR_LOG_FILE="error-log-$(date +%s).txt"

echo "[DEBUG] Executing command:"
echo "sf apex run test --target-org \"$TARGET_ORG_ALIAS\" --class-names \"$TEST_CLASSES_TO_RUN\" --code-coverage --result-format json --wait 10 --json"
echo ""

# Try to run tests synchronously first with separate error capture
set +e  # Don't exit on error
sf apex run test \
    --target-org "$TARGET_ORG_ALIAS" \
    --class-names "$TEST_CLASSES_TO_RUN" \
    --code-coverage \
    --result-format json \
    --wait 10 \
    --json > "$TEST_RESULT_FILE" 2> "$ERROR_LOG_FILE"

# Store the exit code
TEST_EXIT_CODE=$?
set -e  # Re-enable exit on error

echo "Test execution completed with exit code: $TEST_EXIT_CODE"

# Show both stdout and stderr for debugging
echo ""
echo "[DEBUG] === STDOUT (test result file) ==="
if [ -f "$TEST_RESULT_FILE" ]; then
    cat "$TEST_RESULT_FILE"
else
    echo "No test result file created"
fi

echo ""
echo "[DEBUG] === STDERR (error log) ==="
if [ -f "$ERROR_LOG_FILE" ]; then
    cat "$ERROR_LOG_FILE"
else
    echo "No error log file created"
fi
echo "[DEBUG] === End of debug output ==="

# Check if test execution was successful
if [ $TEST_EXIT_CODE -ne 0 ]; then
    echo ""
    echo "❌ TEST EXECUTION FAILED!"
    echo "Exit code: $TEST_EXIT_CODE"
    echo ""
    echo "🔍 Common causes and solutions:"
    echo "• Test classes don't exist in target org → Deploy classes first"
    echo "• Authentication expired → Re-authenticate with the org"
    echo "• Test compilation errors → Check syntax in test classes"
    echo "• Insufficient permissions → Verify user can run Apex tests"
    echo "• Org limits reached → Check test execution limits"
    echo ""
    echo "📋 Debug information above shows detailed error output."

    # Clean up
    rm -f "$TEST_RESULT_FILE" "$ERROR_LOG_FILE"
    exit 1
fi

# Clean up error log (test was successful)
rm -f "$ERROR_LOG_FILE"

# Check if we got a test run ID instead of full results (async execution)
TEST_RUN_ID=$(jq -r '.result.testRunId // empty' "$TEST_RESULT_FILE" 2>/dev/null || echo "")
COVERAGE_DATA=$(jq -r '.result.coverage // empty' "$TEST_RESULT_FILE" 2>/dev/null || echo "")

if [ -n "$TEST_RUN_ID" ] && [ -z "$COVERAGE_DATA" ]; then
    echo "Test ran asynchronously with ID: $TEST_RUN_ID"
    echo "Fetching test results..."

    # Get the full test results using the test run ID
    FINAL_RESULT_FILE="final-test-result-$(date +%s).json"
    sf apex get test --test-run-id "$TEST_RUN_ID" --target-org "$TARGET_ORG_ALIAS" --code-coverage --result-format json --json > "$FINAL_RESULT_FILE"

    if [ $? -ne 0 ]; then
        echo "Failed to retrieve test results!"
        cat "$FINAL_RESULT_FILE"
        rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE" "$ERROR_LOG_FILE"
        exit 1
    fi

    # Use the final results file for coverage analysis
    TEST_RESULT_FILE="$FINAL_RESULT_FILE"
    echo "Final test results retrieved and saved to $TEST_RESULT_FILE"
fi

# Parse test results and extract coverage for each changed class
echo "Analyzing coverage results..."

# Debug: Show the structure of the test result
echo "[DEBUG] Test result JSON structure:"
jq -r 'keys[]' "$TEST_RESULT_FILE" 2>/dev/null || echo "Could not parse JSON keys"
echo "[DEBUG] Result keys:"
jq -r '.result | keys[]' "$TEST_RESULT_FILE" 2>/dev/null || echo "Could not parse result keys"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "jq is required but not installed. Please install jq to parse JSON results."
    exit 1
fi

# Extract coverage data and test run coverage summary
COVERAGE_DATA=$(jq -r '.result.coverage' "$TEST_RESULT_FILE" 2>/dev/null || echo "")
TEST_RUN_COVERAGE=$(jq -r '.result.coverage.summary.testRunCoverage // .result.summary.testRunCoverage // empty' "$TEST_RESULT_FILE" 2>/dev/null || echo "")

if [ -z "$COVERAGE_DATA" ] || [ "$COVERAGE_DATA" = "null" ]; then
    echo "Could not extract coverage data from test results"
    echo "Test result content:"
    cat "$TEST_RESULT_FILE"
    rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE" "$ERROR_LOG_FILE"
    exit 1
fi

# Debug: Show coverage data structure
echo "[DEBUG] Coverage data structure:"
echo "$COVERAGE_DATA" | jq -r '.' 2>/dev/null || echo "Could not parse coverage data"
echo "[DEBUG] Test run coverage: $TEST_RUN_COVERAGE"

# Check if we have test run coverage summary
if [ -n "$TEST_RUN_COVERAGE" ] && [ "$TEST_RUN_COVERAGE" != "null" ]; then
    echo ""
    echo "=========================================="
    echo "📊 TEST RUN COVERAGE VALIDATION RESULTS"
    echo "=========================================="

    # Remove % sign and convert to integer for comparison
    COVERAGE_VALUE=$(echo "$TEST_RUN_COVERAGE" | sed 's/%$//')
    COVERAGE_INT=$(echo "$COVERAGE_VALUE" | cut -d. -f1)

    echo "🎯 Overall test run coverage: $TEST_RUN_COVERAGE"
    echo "📏 Required threshold: $COVERAGE_THRESHOLD%"
    echo ""

    if [ "$COVERAGE_INT" -lt "$COVERAGE_THRESHOLD" ]; then
        echo "❌ COVERAGE CHECK FAILED!"
        echo "   Test run coverage ($TEST_RUN_COVERAGE) is below the $COVERAGE_THRESHOLD% threshold."
        echo ""
        echo "🔧 Next steps:"
        echo "   • Improve test coverage in your test classes"
        echo "   • Ensure all code paths are tested"
        echo "   • Add missing test cases for edge scenarios"

        # Clean up
        rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE" "$ERROR_LOG_FILE"
        exit 1
    else
        echo "✅ COVERAGE CHECK PASSED!"
        echo "   Test run coverage ($TEST_RUN_COVERAGE) meets the $COVERAGE_THRESHOLD% requirement."
        echo ""
        echo "🚀 Deployment can proceed with confidence!"

        # Clean up
        rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE" "$ERROR_LOG_FILE"
        echo "Coverage validation completed successfully."
        exit 0
    fi
fi

# Fallback: Check individual test class coverage (original logic)
echo ""
echo "⚠️  No testRunCoverage found in summary. Falling back to individual class coverage check..."

# Check coverage for each changed class
COVERAGE_FAILURES=""
IFS=',' read -ra CLASS_ARRAY <<< "$CLASSES_TO_CHECK"

for class_name in "${CLASS_ARRAY[@]}"; do
    echo "[DEBUG] Looking for coverage data for class: $class_name"

    # Determine if this is a test class for better labeling
    class_type="Test class"
    if [[ ! "$class_name" =~ Test.*$ ]] && [[ ! "$class_name" =~ .*Test.*$ ]]; then
        class_type="Class"
        # This shouldn't happen since we only check test classes now
        echo "WARNING: Non-test class $class_name in coverage check list - this may be an error"
    fi

    # Extract coverage percentage for this specific class - try multiple field combinations
    COVERAGE_PERCENT=""

    # Try different field name combinations
    for name_field in "name" "Name" "apexClassOrTriggerName" "className"; do
        for percent_field in "coveredPercent" "percentCovered" "coverage" "coveragePercent"; do
            COVERAGE_PERCENT=$(echo "$COVERAGE_DATA" | jq -r ".[] | select(.${name_field} == \"$class_name\") | .${percent_field}" 2>/dev/null || echo "null")
            if [ "$COVERAGE_PERCENT" != "null" ] && [ -n "$COVERAGE_PERCENT" ]; then
                echo "[DEBUG] Found coverage using fields: ${name_field}=${class_name}, ${percent_field}=${COVERAGE_PERCENT}"
                break 2
            fi
        done
    done

    if [ "$COVERAGE_PERCENT" = "null" ] || [ -z "$COVERAGE_PERCENT" ]; then
        echo "ERROR: No coverage data found for class: $class_name"
        COVERAGE_FAILURES="$COVERAGE_FAILURES\n- $class_name: No coverage data found"
        continue
    fi

    # Convert to integer for comparison (remove decimal if present)
    COVERAGE_INT=$(echo "$COVERAGE_PERCENT" | cut -d. -f1)

    echo "$class_type: $class_name | Coverage: $COVERAGE_PERCENT% | Threshold: $COVERAGE_THRESHOLD%"

    if [ "$COVERAGE_INT" -lt "$COVERAGE_THRESHOLD" ]; then
        echo "FAIL: $class_name coverage ($COVERAGE_PERCENT%) is below threshold ($COVERAGE_THRESHOLD%)"
        COVERAGE_FAILURES="$COVERAGE_FAILURES\n- $class_name ($class_type): $COVERAGE_PERCENT% (below $COVERAGE_THRESHOLD%)"
    else
        echo "PASS: $class_name coverage ($COVERAGE_PERCENT%) meets threshold"
    fi
done

# Report results
if [ -n "$COVERAGE_FAILURES" ]; then
    echo ""
    echo "❌ COVERAGE CHECK FAILED!"
    echo "The following test classes do not meet the $COVERAGE_THRESHOLD% coverage requirement:"
    echo -e "$COVERAGE_FAILURES"
    echo ""
    echo "Please add or improve test coverage for these test classes."

    # Clean up
    rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE"
    exit 1
else
    echo ""
    echo "✅ COVERAGE CHECK PASSED!"
    echo "All test classes meet the $COVERAGE_THRESHOLD% coverage requirement."
fi

# Clean up
rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE" "$ERROR_LOG_FILE"
echo "Coverage validation completed successfully."