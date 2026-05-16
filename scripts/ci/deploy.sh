#!/bin/bash

# Deployment script for Salesforce CI/CD
# Usage: deploy.sh <DELTA_DIR> <TARGET_ORG_ALIAS> <COVERAGE_THRESHOLD> [EXTRA_TESTS]

set -e

DELTA_DIR=${1:?Missing DELTA_DIR argument}
TARGET_ORG_ALIAS=${2:?Missing TARGET_ORG_ALIAS argument}
COVERAGE_THRESHOLD=${3:?Missing COVERAGE_THRESHOLD argument}
EXTRA_TESTS_INPUT=${4:-}

# Check for both additive and destructive changes
HAS_ADDITIVE=false
HAS_DESTRUCTIVE=false
HAS_PRE_DESTRUCTIVE=false
HAS_POST_DESTRUCTIVE=false

if [ -f "$DELTA_DIR/package/package.xml" ]; then
  HAS_ADDITIVE=true
  echo "✅ Additive changes detected"
fi

if [ -f "$DELTA_DIR/destructiveChanges/destructiveChanges.xml" ]; then
  HAS_DESTRUCTIVE=true
  echo "🚨 Main destructive changes detected"
fi

if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPre.xml" ]; then
  HAS_PRE_DESTRUCTIVE=true
  echo "🚨 Pre-destructive changes detected"
fi

if [ -f "$DELTA_DIR/destructiveChanges/destructiveChangesPost.xml" ]; then
  HAS_POST_DESTRUCTIVE=true
  echo "🚨 Post-destructive changes detected"
fi

# Show what we detected
echo "📊 Deployment Analysis:"
echo "   • Additive changes: $HAS_ADDITIVE"
echo "   • Destructive changes: $HAS_DESTRUCTIVE"
echo "   • Pre-destructive changes: $HAS_PRE_DESTRUCTIVE"
echo "   • Post-destructive changes: $HAS_POST_DESTRUCTIVE"

# Include profile delta changes in main deployment (always)
if [ -f "$DELTA_DIR/has_profile_deltas.flag" ] && [ "$(cat "$DELTA_DIR/has_profile_deltas.flag")" = "true" ]; then
    echo "   🎯 Profile changes: Delta profiles will be included in deployment"
    echo ""
    echo "🔄 Preparing deployment with profile delta changes..."

    # Copy profile delta files to main deployment directory
    if [ -d "$DELTA_DIR/profile-deltas" ]; then
        echo "   📦 Including profile delta changes in deployment package"

        # Debug: Show what git-delta created
        echo "   [DEBUG] Profiles in force-app (from git-delta) BEFORE overwrite:"
        if [ -d "$DELTA_DIR/force-app/main/default/profiles" ]; then
            for pf in "$DELTA_DIR/force-app/main/default/profiles"/*.profile-meta.xml; do
                if [ -f "$pf" ]; then
                    echo "      File: $(basename "$pf")"
                    echo "      Field count: $(grep -c '<fieldPermissions>' "$pf" || echo 0)"
                fi
            done
        fi

        # Copy delta profiles to force-app directory
        for profile_dir in "$DELTA_DIR/profile-deltas"/*; do
            if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "profile-deltas" ]; then
                PROFILE_NAME=$(basename "$profile_dir")

                # Skip flag files
                if [[ "$PROFILE_NAME" == *".flag" ]] || [[ "$PROFILE_NAME" == *".txt" ]]; then
                    continue
                fi

                # Use delta profile if available, otherwise full profile
                DELTA_PROFILE="$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml"
                FULL_PROFILE="$profile_dir/${PROFILE_NAME}.profile-meta.xml"

                if [ -f "$DELTA_PROFILE" ]; then
                    # Copy delta profile (only changed elements)
                    DEST_PROFILE="$DELTA_DIR/force-app/main/default/profiles/${PROFILE_NAME}.profile-meta.xml"
                    mkdir -p "$(dirname "$DEST_PROFILE")"

                    # Debug: Show what we're copying
                    echo "      • $PROFILE_NAME (delta - only changed elements)"
                    echo "      [DEBUG] Delta profile field count: $(grep -c '<fieldPermissions>' "$DELTA_PROFILE")"
                    echo "      [DEBUG] COMPLETE Delta profile XML:"
                    echo "================================================"
                    cat "$DELTA_PROFILE"
                    echo "================================================"

                    cp "$DELTA_PROFILE" "$DEST_PROFILE"

                    # Debug: Verify what was copied
                    echo "      [DEBUG] Destination field count after copy: $(grep -c '<fieldPermissions>' "$DEST_PROFILE")"
                    echo "      [DEBUG] DESTINATION FILE (what will be deployed):"
                    echo "================================================"
                    cat "$DEST_PROFILE"
                    echo "================================================"

                    # CRITICAL: Replace original profile with delta for deployment
                    ORIGINAL_PROFILE="force-app/main/default/profiles/${PROFILE_NAME}.profile-meta.xml"
                    if [ -f "$ORIGINAL_PROFILE" ]; then
                        echo "      [DEBUG] Backing up and replacing original profile with delta"
                        # Backup original to temp
                        mkdir -p "/tmp/profile-backups"
                        cp "$ORIGINAL_PROFILE" "/tmp/profile-backups/${PROFILE_NAME}.profile-meta.xml"
                        # REPLACE original with delta profile
                        cp "$DELTA_PROFILE" "$ORIGINAL_PROFILE"
                        echo "      [DEBUG] Original backed up, delta now at: $ORIGINAL_PROFILE"
                    fi
                elif [ -f "$FULL_PROFILE" ]; then
                    # Copy full profile (new profile)
                    DEST_PROFILE="$DELTA_DIR/force-app/main/default/profiles/${PROFILE_NAME}.profile-meta.xml"
                    mkdir -p "$(dirname "$DEST_PROFILE")"
                    cp "$FULL_PROFILE" "$DEST_PROFILE"
                    echo "      • $PROFILE_NAME (full - new profile)"
                fi
            fi
        done

        # Update package.xml to include profiles
        if [ -f "$DELTA_DIR/package/package.xml" ]; then
            echo "   📝 Updating package.xml to include profiles"

            # Check if Profile metadata type already exists in package.xml
            if ! grep -q "<name>Profile</name>" "$DELTA_DIR/package/package.xml"; then
                # Add Profile section to package.xml using a temp file approach
                TEMP_PKG="/tmp/package_temp_$$.xml"
                awk '/<version>/ {
                    print "    <types>"
                    print "        <members>*</members>"
                    print "        <name>Profile</name>"
                    print "    </types>"
                }
                {print}' "$DELTA_DIR/package/package.xml" > "$TEMP_PKG"
                mv "$TEMP_PKG" "$DELTA_DIR/package/package.xml"
                echo "      ✅ Added Profile metadata type to package.xml"
            else
                echo "      ✅ Profiles already included in package.xml"
            fi
        fi
    fi
else
    echo "   📋 Profile changes: None detected"
fi

echo ""
echo "💡 Deployment Strategy:"
echo "   • Profile deltas included in main deployment (git-based changes only)"
echo "   • Protects manual org changes from being overridden"
echo "   • Single unified deployment for all metadata changes"

if [ "$HAS_ADDITIVE" = false ] && [ "$HAS_DESTRUCTIVE" = false ] && [ "$HAS_PRE_DESTRUCTIVE" = false ] && [ "$HAS_POST_DESTRUCTIVE" = false ]; then
  echo "📋 No changes detected for deployment"
  exit 0
fi

echo ""
echo "🚀 Deploying changes to $TARGET_ORG_ALIAS..."

# Determine deployment strategy based on change types
DEPLOY_CMD_BASE="sf project deploy start --target-org $TARGET_ORG_ALIAS --json"

# Check if we need coverage validation (only for Apex/Trigger additive changes)
NEEDS_COVERAGE_VALIDATION=false
TEST_CLASSES_TO_RUN=""

if [ "$HAS_ADDITIVE" = true ]; then
  echo "📦 Processing additive changes..."

  # When we have destructive changes, we need to use manifest-based deployment
  if [ "$HAS_DESTRUCTIVE" = true ] || [ "$HAS_PRE_DESTRUCTIVE" = true ] || [ "$HAS_POST_DESTRUCTIVE" = true ]; then
    echo "🔄 Using manifest-based deployment (required for destructive changes)"
    DEPLOY_CMD="$DEPLOY_CMD_BASE --manifest $DELTA_DIR/package/package.xml"
  else
    echo "🔄 Using source-based deployment (no destructive changes)"
    DEPLOY_CMD="$DEPLOY_CMD_BASE --source-dir $DELTA_DIR/force-app"
  fi

  # Only check coverage for Apex classes and triggers in additive changes
  APEX_FILES=$(find $DELTA_DIR/force-app -name "*.cls" -not -name "*Test.cls" 2>/dev/null | wc -l)
  TRIGGER_FILES=$(find $DELTA_DIR/force-app -name "*.trigger" 2>/dev/null | wc -l)
  TEST_FILES=$(find $DELTA_DIR/force-app -name "*Test.cls" 2>/dev/null | wc -l)

  if [ "$APEX_FILES" -gt 0 ] || [ "$TRIGGER_FILES" -gt 0 ] || [ "$TEST_FILES" -gt 0 ]; then
    echo "📋 Found Apex/Trigger classes - coverage validation required"
    NEEDS_COVERAGE_VALIDATION=true

    echo "[DEBUG] All .cls files in delta directory:"
    find $DELTA_DIR/force-app -name "*.cls" 2>/dev/null || true

    # Find test classes for changed regular Apex classes
    for apex_file in $(find $DELTA_DIR/force-app -name "*.cls" -not -name "*Test.cls" 2>/dev/null || true); do
      CLASS_NAME=$(basename "$apex_file" .cls)
      echo "   🔍 Regular class: $CLASS_NAME"

      for pattern in "${CLASS_NAME}Test" "Test${CLASS_NAME}"; do
        # Look for test class in MAIN REPO, not delta (test may not have changed)
        TEST_FILE="force-app/main/default/classes/${pattern}.cls"
        echo "   🔍 Checking for test: $TEST_FILE"
        if [ -f "$TEST_FILE" ]; then
          echo "   ✅ Found test class: $pattern"
          if [ -z "$TEST_CLASSES_TO_RUN" ]; then
            TEST_CLASSES_TO_RUN="$pattern"
          else
            TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$pattern"
          fi
          break
        else
          echo "   ❌ Not found: $TEST_FILE"
        fi
      done
    done

    # Process test classes directly
    for test_file in $(find $DELTA_DIR/force-app -name "*Test.cls" 2>/dev/null || true); do
      TEST_CLASS_NAME=$(basename "$test_file" .cls)
      echo "   🧪 Test class: $TEST_CLASS_NAME"

      if [[ ",$TEST_CLASSES_TO_RUN," != *",$TEST_CLASS_NAME,"* ]]; then
        if [ -z "$TEST_CLASSES_TO_RUN" ]; then
          TEST_CLASSES_TO_RUN="$TEST_CLASS_NAME"
        else
          TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$TEST_CLASS_NAME"
        fi
      fi
    done

    # Parse commit message for additional test classes
    echo ""
    echo "📋 Checking commit message for additional test class specifications..."

    # Look for [test:Class1,Class2] or [tests:Class1,Class2] syntax in last commit
    COMMIT_MESSAGE=$(git log -1 --pretty=%B)
    EXTRA_TESTS=$(echo "$COMMIT_MESSAGE" | grep -oP '\[tests?:\K[^\]]+' | head -1)

    if [ -n "$EXTRA_TESTS" ]; then
      echo "   💬 Commit specifies additional test classes: $EXTRA_TESTS"

      # Add specified tests to the list
      IFS=',' read -ra TESTS <<< "$EXTRA_TESTS"
      for test in "${TESTS[@]}"; do
        test=$(echo "$test" | xargs)  # trim whitespace
        if [ -n "$test" ] && [[ ",$TEST_CLASSES_TO_RUN," != *",$test,"* ]]; then
          if [ -z "$TEST_CLASSES_TO_RUN" ]; then
            TEST_CLASSES_TO_RUN="$test"
          else
            TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$test"
          fi
        fi
      done

      echo "   ✅ Tests after commit input: $TEST_CLASSES_TO_RUN"
    else
      echo "   ℹ️  No additional test classes specified in commit message"
      echo "   💡 Tip: Use [test:Class1,Class2] in commit message to specify additional tests"
    fi
    echo ""

    # Check for manual workflow dispatch with extra tests
    if [ -n "$EXTRA_TESTS_INPUT" ]; then
      echo "🎯 Manual workflow dispatch detected"
      echo "   Additional test classes specified: $EXTRA_TESTS_INPUT"

      # Add specified tests to the list
      IFS=',' read -ra TESTS <<< "$EXTRA_TESTS_INPUT"
      for test in "${TESTS[@]}"; do
        test=$(echo "$test" | xargs)  # trim whitespace
        if [ -n "$test" ] && [[ ",$TEST_CLASSES_TO_RUN," != *",$test,"* ]]; then
          if [ -z "$TEST_CLASSES_TO_RUN" ]; then
            TEST_CLASSES_TO_RUN="$test"
          else
            TEST_CLASSES_TO_RUN="$TEST_CLASSES_TO_RUN,$test"
          fi
        fi
      done

      echo "   ✅ Tests after manual input: $TEST_CLASSES_TO_RUN"
      echo ""
    fi

    # Add test execution to deployment command
    if [ -n "$TEST_CLASSES_TO_RUN" ]; then
      echo "🧪 Running specific test classes: $TEST_CLASSES_TO_RUN"

      # Build --tests flag with proper syntax (SF CLI v2+ requires space-separated or repeated flags)
      TEST_FLAGS=""
      IFS=',' read -ra TEST_ARRAY <<< "$TEST_CLASSES_TO_RUN"
      for test_class in "${TEST_ARRAY[@]}"; do
        test_class=$(echo "$test_class" | xargs)  # trim whitespace
        if [ -n "$test_class" ]; then
          TEST_FLAGS="$TEST_FLAGS --tests \"$test_class\""
        fi
      done

      DEPLOY_CMD="$DEPLOY_CMD --test-level RunSpecifiedTests $TEST_FLAGS"
    else
      echo "⚠️  No test classes found - using RunLocalTests"
      DEPLOY_CMD="$DEPLOY_CMD --test-level RunLocalTests"
    fi
  else
    echo "📋 No Apex/Trigger classes - deploying without coverage validation"
    DEPLOY_CMD="$DEPLOY_CMD --test-level NoTestRun"
  fi
fi

# Handle destructive-only deployments
if [ "$HAS_ADDITIVE" = false ] && [ "$HAS_DESTRUCTIVE" = true ]; then
  echo "🗑️  Deploying standalone destructive changes (no coverage validation needed)"
  DEPLOY_CMD="$DEPLOY_CMD_BASE --metadata-dir $DELTA_DIR/destructiveChanges --test-level NoTestRun"
fi

# Add destructive changes parameters to additive deployments
if [ "$HAS_ADDITIVE" = true ]; then
  if [ "$HAS_PRE_DESTRUCTIVE" = true ]; then
    echo "🚨 Adding pre-destructive changes to deployment"
    DEPLOY_CMD="$DEPLOY_CMD --pre-destructive-changes $DELTA_DIR/destructiveChanges/destructiveChangesPre.xml"
  fi

  if [ "$HAS_POST_DESTRUCTIVE" = true ]; then
    echo "🚨 Adding post-destructive changes to deployment"
    DEPLOY_CMD="$DEPLOY_CMD --post-destructive-changes $DELTA_DIR/destructiveChanges/destructiveChangesPost.xml"
  fi

  # Handle main destructive changes as post-destructive if no explicit post file
  if [ "$HAS_DESTRUCTIVE" = true ] && [ "$HAS_POST_DESTRUCTIVE" = false ]; then
    echo "🚨 Adding main destructive changes as post-destructive"
    DEPLOY_CMD="$DEPLOY_CMD --post-destructive-changes $DELTA_DIR/destructiveChanges/destructiveChanges.xml"
  fi
fi

echo ""
echo "[DEBUG] Final deployment command:"
echo "$DEPLOY_CMD"
echo ""

# Execute deployment with detailed error capture
echo "🚀 Executing deployment..."

set +e  # Don't exit on error immediately
DEPLOY_RESULT=$(eval "$DEPLOY_CMD" 2>&1)
DEPLOY_EXIT_CODE=$?
set -e  # Re-enable exit on error

# Restore original profile files from temp backup
echo "[DEBUG] Restoring original profile files from backup..."
if [ -d "/tmp/profile-backups" ]; then
    for backup_file in /tmp/profile-backups/*.profile-meta.xml; do
        if [ -f "$backup_file" ]; then
            profile_name=$(basename "$backup_file")
            original_location="force-app/main/default/profiles/$profile_name"
            cp "$backup_file" "$original_location"
            echo "[DEBUG] Restored from backup: $original_location"
        fi
    done
    rm -rf /tmp/profile-backups
fi

echo "📊 Deployment completed with exit code: $DEPLOY_EXIT_CODE"

# Always show the deployment result for debugging
echo ""
echo "[DEBUG] === FULL DEPLOYMENT RESULT ==="
echo "$DEPLOY_RESULT"
echo "[DEBUG] === END DEPLOYMENT RESULT ==="
echo ""

if [ $DEPLOY_EXIT_CODE -eq 0 ]; then
  # Extract and display deployment ID
  DEPLOY_ID=$(echo "$DEPLOY_RESULT" | jq -r '.result.id // "Unknown"')
  echo "✅ Deployment completed successfully!"
  echo "📋 Deployment ID: $DEPLOY_ID"
  echo ""

  # Show deployment summary
  echo "📊 Deployment Summary:"
  echo "$DEPLOY_RESULT" | jq -r '.result | "   • Components: \(.numberComponentsTotal // "0") total, \(.numberComponentsDeployed // "0") deployed"'
  echo "$DEPLOY_RESULT" | jq -r '.result | "   • Status: \(.status // "Unknown")"'
  echo "$DEPLOY_RESULT" | jq -r '.result | "   • Start Time: \(.startDate // "Unknown")"'

  # Show test results if tests were run (only for Apex/Trigger deployments)
  if [ "$NEEDS_COVERAGE_VALIDATION" = true ]; then
    TEST_RESULTS=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult // empty')
    if [ -n "$TEST_RESULTS" ] && [ "$TEST_RESULTS" != "null" ]; then
      echo ""
      echo "🧪 Test Results:"
      echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult | "   • Tests Run: \(.numTestsRun // "0")"'
      echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult | "   • Failures: \(.numFailures // "0")"'

      # Extract testRunCoverage for validation
      TEST_RUN_COVERAGE=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.coverage.summary.testRunCoverage // .result.details.runTestResult.testRunCoverage // .result.details.runTestResult.totalCoverage // empty' 2>/dev/null || echo "")

      if [ -n "$TEST_RUN_COVERAGE" ] && [ "$TEST_RUN_COVERAGE" != "null" ]; then
        echo "   • Test Run Coverage: ${TEST_RUN_COVERAGE}%"

        # Also show individual class coverage for deployed classes if available
        echo "   📋 Individual Class Coverage:"
        echo "$DEPLOY_RESULT" | jq -r '
          .result.details.runTestResult.coverage.coverage[]? // empty |
          select(.name != null) |
          "      • \(.name): \(.coveredPercent // "N/A")%"
        ' 2>/dev/null || echo "      (Individual coverage data not available)"

        # Validate testRunCoverage meets threshold
        COVERAGE_INT=$(echo "$TEST_RUN_COVERAGE" | cut -d. -f1)
        if [ "$COVERAGE_INT" -lt "$COVERAGE_THRESHOLD" ]; then
          echo ""
          echo "❌ DEPLOYMENT FAILED - INSUFFICIENT TEST COVERAGE!"
          echo "   Code coverage is ${TEST_RUN_COVERAGE}% which is less than required ${COVERAGE_THRESHOLD}%"
          echo ""
          echo "🔧 Required Action:"
          echo "   • Improve test coverage in your test classes"
          echo "   • Ensure all code paths in your Apex classes are properly tested"
          echo "   • Test run coverage must be ≥ ${COVERAGE_THRESHOLD}%"
          echo ""
          echo "💡 Test run coverage represents the overall coverage achieved by the test classes"
          echo "   that ran for this deployment (${TEST_CLASSES_TO_RUN:-"selected tests"})"
          exit 1
        else
          echo "   ✅ Code coverage is ${TEST_RUN_COVERAGE}% which meets the required ${COVERAGE_THRESHOLD}%"
          echo "   📊 This represents coverage achieved by: ${TEST_CLASSES_TO_RUN:-"selected tests"}"
        fi
      else
        echo "   ⚠️  Test run coverage not available in deployment results"

        # Try to extract and show individual coverage as fallback
        echo "   📋 Attempting to show individual class coverage:"
        HAS_COVERAGE_DATA=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.coverage.coverage[]? // empty | select(.name != null) | .name' 2>/dev/null | head -1)

        if [ -n "$HAS_COVERAGE_DATA" ]; then
          echo "$DEPLOY_RESULT" | jq -r '
            .result.details.runTestResult.coverage.coverage[]? // empty |
            select(.name != null) |
            "      • \(.name): \(.coveredPercent // "N/A")%"
          ' 2>/dev/null

          echo ""
          echo "⚠️  Using individual class coverage validation as fallback"
          echo "   Checking that all deployed classes meet ${COVERAGE_THRESHOLD}% requirement..."

          # Validate individual classes meet threshold
          FAILED_CLASSES=""
          while IFS= read -r coverage_line; do
            if [ -n "$coverage_line" ]; then
              COVERAGE_PERCENT=$(echo "$coverage_line" | grep -o '[0-9]\+%' | sed 's/%//')
              CLASS_NAME=$(echo "$coverage_line" | sed 's/.*• \([^:]*\):.*/\1/')

              if [ -n "$COVERAGE_PERCENT" ] && [ "$COVERAGE_PERCENT" -lt "$COVERAGE_THRESHOLD" ]; then
                FAILED_CLASSES="${FAILED_CLASSES}\n   • ${CLASS_NAME}: ${COVERAGE_PERCENT}%"
              fi
            fi
          done < <(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.coverage.coverage[]? // empty | select(.name != null) | "• \(.name): \(.coveredPercent // 0)%"' 2>/dev/null)

          if [ -n "$FAILED_CLASSES" ]; then
            echo ""
            echo "❌ DEPLOYMENT FAILED - INSUFFICIENT CLASS COVERAGE!"
            echo "   The following classes do not meet the ${COVERAGE_THRESHOLD}% threshold:"
            echo -e "$FAILED_CLASSES"
            exit 1
          else
            echo "   ✅ All deployed classes meet the coverage requirement"
          fi
        else
          echo "      (No coverage data available in deployment results)"
        fi
      fi
    else
      echo ""
      echo "🧪 Test Results:"
      echo "   ⚠️  No test execution data found in deployment results"
    fi
  else
    echo ""
    echo "🎯 Coverage Validation Skipped:"
    echo "   📋 No Apex/Trigger classes in deployment"
    echo "   ✅ Coverage validation not required for this deployment type"
  fi

  # Save deployment summary for GitHub workflow to display in PR comments
  echo ""
  echo "💾 Saving deployment summary..."

  DEPLOY_ID=$(echo "$DEPLOY_RESULT" | jq -r '.result.id // "Unknown"')
  NUM_COMPONENTS=$(echo "$DEPLOY_RESULT" | jq -r '.result.numberComponentsDeployed // 0')
  NUM_TESTS=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.numTestsRun // 0' 2>/dev/null || echo "0")
  NUM_FAILURES=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.numFailures // 0' 2>/dev/null || echo "0")
  TEST_COVERAGE=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.coverage.summary.testRunCoverage // .result.details.runTestResult.testRunCoverage // "N/A"' 2>/dev/null || echo "N/A")

  cat > deployment-summary.json << EOF
{
  "deploymentId": "$DEPLOY_ID",
  "componentsDeployed": $NUM_COMPONENTS,
  "testsRun": $NUM_TESTS,
  "testFailures": $NUM_FAILURES,
  "testRunCoverage": "$TEST_COVERAGE",
  "status": "success"
}
EOF

  echo "   ✅ Deployment summary saved to deployment-summary.json"
else
  echo "❌ Deployment failed!"
  echo "Deployment output:"
  echo "$DEPLOY_RESULT"

  # Save failure summary with coverage data if available
  DEPLOY_ID=$(echo "$DEPLOY_RESULT" | jq -r '.result.id // "Unknown"' 2>/dev/null || echo "Unknown")
  NUM_TESTS=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.numTestsRun // 0' 2>/dev/null || echo "0")
  NUM_FAILURES=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.numFailures // 0' 2>/dev/null || echo "0")
  TEST_COVERAGE=$(echo "$DEPLOY_RESULT" | jq -r '.result.details.runTestResult.coverage.summary.testRunCoverage // .result.details.runTestResult.testRunCoverage // "N/A"' 2>/dev/null || echo "N/A")
  ERROR_MSG=$(echo "$DEPLOY_RESULT" | jq -r '.message // "Deployment failed - see logs for details"' 2>/dev/null || echo "Deployment failed - see logs for details")

  cat > deployment-summary.json << EOF
{
  "status": "failure",
  "deploymentId": "$DEPLOY_ID",
  "testsRun": $NUM_TESTS,
  "testFailures": $NUM_FAILURES,
  "testRunCoverage": "$TEST_COVERAGE",
  "error": "$ERROR_MSG"
}
EOF

  echo "💾 Failure summary saved to deployment-summary.json"

  exit 1
fi
