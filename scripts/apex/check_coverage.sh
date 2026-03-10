#!/bin/bash
# ============================================================================
# check_coverage.sh - Verify Apex code coverage meets minimum threshold
# ============================================================================
# This script checks that code coverage meets the minimum requirement
# (default 85% for production deployments).
# ============================================================================

set -e

# Configuration
TARGET_ORG="${1:-deployment-org}"
MIN_COVERAGE="${MIN_COVERAGE:-85}"

echo "=============================================="
echo "  Checking Code Coverage"
echo "=============================================="
echo "Target Org: $TARGET_ORG"
echo "Minimum:    $MIN_COVERAGE%"
echo "=============================================="

# Get org-wide coverage
echo ""
echo "Fetching Apex org-wide coverage..."

# Query for coverage using sf CLI
COVERAGE_OUTPUT=$(sf data query \
    --query "SELECT PercentCovered FROM ApexOrgWideCoverage" \
    --target-org "$TARGET_ORG" \
    --json 2>/dev/null || echo '{"result":{"records":[{"PercentCovered":0}]}}')

# Extract coverage percentage
COVERAGE=$(echo "$COVERAGE_OUTPUT" | grep -o '"PercentCovered":[0-9]*' | head -1 | cut -d':' -f2)

if [ -z "$COVERAGE" ]; then
    echo "⚠️  Could not retrieve coverage - checking individual class coverage"
    COVERAGE=0
fi

echo ""
echo "Current Coverage: $COVERAGE%"

# Check against minimum
if [ "$COVERAGE" -ge "$MIN_COVERAGE" ]; then
    echo ""
    echo "✅ Code coverage meets minimum requirement ($MIN_COVERAGE%)"
    exit 0
else
    echo ""
    echo "❌ Code coverage ($COVERAGE%) is below minimum ($MIN_COVERAGE%)"
    echo ""
    echo "Recommendations:"
    echo "1. Review failed tests and fix issues"
    echo "2. Add more test cases to cover edge cases"
    echo "3. Ensure all new code has corresponding tests"
    exit 1
fi

