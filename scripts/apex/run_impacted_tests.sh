#!/bin/bash
# ============================================================================
# run_impacted_tests.sh - Run Apex tests for impacted code
# ============================================================================
# This script detects changed Apex classes and triggers appropriate tests.
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
DELTA_DIR="${2:-tmp_delta}"
SOURCE_DIR="${SOURCE_DIR:-force-app}"

echo "=============================================="
echo "  Running Impacted Apex Tests"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "=============================================="

# Get commit references for change detection
if [ -n "$GITHUB_BASE_REF" ]; then
    FROM_COMMIT="$GITHUB_BASE_REF"
else
    FROM_COMMIT="${FROM_COMMIT:-HEAD~1}"
fi
TO_COMMIT="${TO_COMMIT:-$GITHUB_SHA}"

echo "Detecting changed Apex files between $FROM_COMMIT and $TO_COMMIT..."

# Find changed Apex classes
CHANGED_APEX=$(git diff --name-only "$FROM_COMMIT" "$TO_COMMIT" -- "$SOURCE_DIR" | grep -E '\.(cls|trigger)$' || echo "")

if [ -n "$CHANGED_APEX" ]; then
    echo ""
    echo "=== Changed Apex Files ==="
    echo "$CHANGED_APEX"
    
    # Extract class names (without .cls extension)
    TEST_CLASSES=""
    for file in $CHANGED_APEX; do
        CLASS_NAME=$(basename "$file" .cls)
        
        # Find corresponding test class
        TEST_FILE=$(find "$SOURCE_DIR" -name "*${CLASS_NAME}Test*" -o -name "Test${CLASS_NAME}*" 2>/dev/null | head -1)
        
        if [ -n "$TEST_FILE" ]; then
            TEST_CLASS_NAME=$(basename "$TEST_FILE" .cls)
            TEST_CLASSES="$TEST_CLASSES $TEST_CLASS_NAME"
        fi
    done
    
    echo ""
    echo "Test classes to run:$TEST_CLASSES"
    
    if [ -n "$TEST_CLASSES" ]; then
        # Run specific test classes
        for test_class in $TEST_CLASSES; do
            echo ""
            echo "Running test class: $test_class"
            
            sf apex test run \
                --class-names "$test_class" \
                --target-org "$TARGET_ORG" \
                --wait 30 \
                --result-format human \
                --output-dir test-results
        done
    else
        echo ""
        echo "No test classes found - running all tests"
        sf apex test run \
            --target-org "$TARGET_ORG" \
            --wait 30 \
            --result-format human \
            --output-dir test-results \
            --test-level RunLocalTests
    fi
else
    echo ""
    echo "No Apex changes detected - running all tests..."
    
    sf apex test run \
        --target-org "$TARGET_ORG" \
        --wait 30 \
        --result-format human \
        --output-dir test-results \
        --test-level RunLocalTests
fi

echo ""
echo "✅ Apex tests completed"

exit 0

