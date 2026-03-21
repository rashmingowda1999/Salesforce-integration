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
    for class_file in $CHANGED_APEX_CLASSES; do
        # Extract class name from file path (remove .cls extension)
        class_name=$(basename "$class_file" .cls)

        # Add to classes we need to check coverage for
        if [ -z "$CLASSES_TO_CHECK" ]; then
            CLASSES_TO_CHECK="$class_name"
        else
            CLASSES_TO_CHECK="$CLASSES_TO_CHECK,$class_name"
        fi

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
                echo "Found test class for $class_name: $pattern"
                if [ -z "$TEST_CLASSES_TO_RUN" ]; then
                    TEST_CLASSES_TO_RUN="$pattern"
                else
                    TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$pattern"
                fi
                found_test=true
                break
            fi
        done

        if [ "$found_test" = false ]; then
            echo "WARNING: No test class found for $class_name using standard naming conventions"
            echo "  Checked patterns: ${test_class_patterns[*]}"
        fi
    done
fi

# Process test classes
if [ -n "$CHANGED_TEST_CLASSES" ]; then
    echo "Processing changed test classes..."
    for test_file in $CHANGED_TEST_CLASSES; do
        # Extract test class name from file path (remove .cls extension)
        test_class_name=$(basename "$test_file" .cls)

        # Add test class to run list
        if [ -z "$TEST_CLASSES_TO_RUN" ]; then
            TEST_CLASSES_TO_RUN="$test_class_name"
        else
            TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$test_class_name"
        fi

        # Determine what main class this test is for
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
                echo "Test class $test_class_name tests main class: $main_class_name"

                # Add to coverage check list if not already there
                if [[ ",$CLASSES_TO_CHECK," != *",$main_class_name,"* ]]; then
                    if [ -z "$CLASSES_TO_CHECK" ]; then
                        CLASSES_TO_CHECK="$main_class_name"
                    else
                        CLASSES_TO_CHECK="$CLASSES_TO_CHECK,$main_class_name"
                    fi
                fi
            else
                echo "WARNING: Test class $test_class_name doesn't seem to have a corresponding main class ($main_class_name not found)"
            fi
        else
            echo "WARNING: Could not determine main class for test class $test_class_name"
        fi
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

# Run the specific test classes and get coverage
echo "Running tests and collecting coverage..."
TEST_RESULT_FILE="test-result-$(date +%s).json"

# Try to run tests synchronously first
sf apex run test \
    --target-org "$TARGET_ORG_ALIAS" \
    --class-names "$TEST_CLASSES_TO_RUN" \
    --code-coverage \
    --result-format json \
    --wait 10 \
    --json > "$TEST_RESULT_FILE"

echo "Test execution completed. Results saved to $TEST_RESULT_FILE"

# Check if test execution was successful
if [ $? -ne 0 ]; then
    echo "Test execution failed!"
    cat "$TEST_RESULT_FILE"
    exit 1
fi

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

# Extract coverage data
COVERAGE_DATA=$(jq -r '.result.coverage' "$TEST_RESULT_FILE" 2>/dev/null || echo "")

if [ -z "$COVERAGE_DATA" ] || [ "$COVERAGE_DATA" = "null" ]; then
    echo "Could not extract coverage data from test results"
    echo "Test result content:"
    cat "$TEST_RESULT_FILE"
    exit 1
fi

# Debug: Show coverage data structure
echo "[DEBUG] Coverage data structure:"
echo "$COVERAGE_DATA" | jq -r '.' 2>/dev/null || echo "Could not parse coverage data"
echo "[DEBUG] Available class names in coverage data:"
echo "$COVERAGE_DATA" | jq -r '.[].name // .[].Name // .[].apexClassOrTriggerName // empty' 2>/dev/null || echo "Could not extract class names"

# Check coverage for each changed class
COVERAGE_FAILURES=""
IFS=',' read -ra CLASS_ARRAY <<< "$CLASSES_TO_CHECK"

for class_name in "${CLASS_ARRAY[@]}"; do
    echo "[DEBUG] Looking for coverage data for class: $class_name"

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

    echo "Class: $class_name | Coverage: $COVERAGE_PERCENT% | Threshold: $COVERAGE_THRESHOLD%"

    if [ "$COVERAGE_INT" -lt "$COVERAGE_THRESHOLD" ]; then
        echo "FAIL: $class_name coverage ($COVERAGE_PERCENT%) is below threshold ($COVERAGE_THRESHOLD%)"
        COVERAGE_FAILURES="$COVERAGE_FAILURES\n- $class_name: $COVERAGE_PERCENT% (below $COVERAGE_THRESHOLD%)"
    else
        echo "PASS: $class_name coverage ($COVERAGE_PERCENT%) meets threshold"
    fi
done

# Report results
if [ -n "$COVERAGE_FAILURES" ]; then
    echo ""
    echo "❌ COVERAGE CHECK FAILED!"
    echo "The following classes do not meet the $COVERAGE_THRESHOLD% coverage requirement:"
    echo -e "$COVERAGE_FAILURES"
    echo ""
    echo "Please add or improve test coverage for these classes."

    # Clean up
    rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE"
    exit 1
else
    echo ""
    echo "✅ COVERAGE CHECK PASSED!"
    echo "All changed Apex classes meet the $COVERAGE_THRESHOLD% coverage requirement."
fi

# Clean up
rm -f "$TEST_RESULT_FILE" "$FINAL_RESULT_FILE"
echo "Coverage validation completed successfully."