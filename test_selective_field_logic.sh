#!/bin/bash

# Test Selective Field Permission Logic - Verify True Selectivity
# This test specifically validates that only changed field permissions are included

set -e

echo "🧪 Testing True Selective Field Permission Logic"
echo "==============================================="

TEST_DIR="./test-selective-field-permissions"
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Create test profiles to exactly match the user's scenario
echo ""
echo "1️⃣ Creating Test Scenario (Matching User's Example)"
echo "--------------------------------------------------"

# Create "old" profile with both fields having editable=true
cat > "$TEST_DIR/old_profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldPermissions>
        <editable>true</editable>
        <field>Account.Account_Status__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>true</editable>
        <field>Account.Active4__c</field>
        <readable>true</readable>
    </fieldPermissions>
</Profile>
EOF

# Create "new" profile with only Active4__c changed to editable=false
cat > "$TEST_DIR/new_profile.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldPermissions>
        <editable>true</editable>
        <field>Account.Account_Status__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Account.Active4__c</field>
        <readable>true</readable>
    </fieldPermissions>
</Profile>
EOF

echo "✅ Test profiles created:"
echo "   • Account.Account_Status__c: unchanged (editable=true)"
echo "   • Account.Active4__c: changed (editable=true → editable=false)"

echo ""
echo "2️⃣ Testing Field Permission Extraction"
echo "--------------------------------------"

# Test the field permission extraction function
OUTPUT_FILE="$TEST_DIR/delta_output.xml"

# Initialize the output file
cat > "$OUTPUT_FILE" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
EOF

# Test the extract_changed_field_permissions function
echo "🔍 Running field permission extraction..."

# Source the function from our script (extract just the function)
extract_changed_field_permissions() {
    old_file="$1"
    new_file="$2"
    output_file="$3"
    has_changes=false

    echo "      🔍 Checking field permissions..."

    # Create temporary files to store individual field permission blocks
    temp_new_fields="/tmp/new_fields_test_$$.txt"
    temp_old_fields="/tmp/old_fields_test_$$.txt"

    # Extract all field permission blocks from new file with field names as identifiers
    awk '
    /<fieldPermissions>/ { in_field=1; block=""; }
    in_field { block = block $0 "\n"; }
    /<\/fieldPermissions>/ {
        if (in_field) {
            # Extract field name from block
            if (match(block, /<field>([^<]*)<\/field>/, arr)) {
                field_name = arr[1];
                # Escape newlines so the entire block is on one line
                gsub(/\n/, "\\n", block);
                print field_name "|||" block;
            }
            in_field=0;
        }
    }
    ' "$new_file" > "$temp_new_fields"

    # Extract all field permission blocks from old file with field names as identifiers
    awk '
    /<fieldPermissions>/ { in_field=1; block=""; }
    in_field { block = block $0 "\n"; }
    /<\/fieldPermissions>/ {
        if (in_field) {
            # Extract field name from block
            if (match(block, /<field>([^<]*)<\/field>/, arr)) {
                field_name = arr[1];
                # Escape newlines so the entire block is on one line
                gsub(/\n/, "\\n", block);
                print field_name "|||" block;
            }
            in_field=0;
        }
    }
    ' "$old_file" > "$temp_old_fields"

    # Compare each field permission block
    while IFS='|||' read -r field_name new_block; do
        if [ -n "$field_name" ] && [ -n "$new_block" ]; then
            # Find corresponding block in old file using parameter expansion
            old_line=$(grep "^${field_name}|||" "$temp_old_fields")
            old_block="${old_line#*|||}"  # Remove everything up to and including first |||

            if [ -z "$old_block" ]; then
                # New field permission (didn't exist before)
                echo "         • $field_name (NEW field permission)"
                # Unescape newlines before writing to output
                echo "$new_block" | sed 's/\\n/\n/g' >> "$output_file"
                has_changes=true
            else
                # Compare the blocks (normalize whitespace but preserve structure for comparison)
                new_normalized=$(echo "$new_block" | sed 's/\\n//g' | sed 's/[[:space:]]*//g')
                old_normalized=$(echo "$old_block" | sed 's/\\n//g' | sed 's/[[:space:]]*//g')

                if [ "$new_normalized" != "$old_normalized" ]; then
                    echo "         • $field_name (CHANGED permission)"

                    # Show what changed for debugging (unescape for parsing)
                    old_unescaped=$(echo "$old_block" | sed 's/\\n/\n/g')
                    new_unescaped=$(echo "$new_block" | sed 's/\\n/\n/g')

                    old_editable=$(echo "$old_unescaped" | grep -o '<editable>[^<]*</editable>' | sed 's/<[^>]*>//g')
                    new_editable=$(echo "$new_unescaped" | grep -o '<editable>[^<]*</editable>' | sed 's/<[^>]*>//g')
                    old_readable=$(echo "$old_unescaped" | grep -o '<readable>[^<]*</readable>' | sed 's/<[^>]*>//g')
                    new_readable=$(echo "$new_unescaped" | grep -o '<readable>[^<]*</readable>' | sed 's/<[^>]*>//g')

                    if [ "$old_editable" != "$new_editable" ]; then
                        echo "           └── Editable: $old_editable → $new_editable"
                    fi
                    if [ "$old_readable" != "$new_readable" ]; then
                        echo "           └── Readable: $old_readable → $new_readable"
                    fi

                    # Unescape newlines before writing to output
                    echo "$new_block" | sed 's/\\n/\n/g' >> "$output_file"
                    has_changes=true
                else
                    echo "         • $field_name (UNCHANGED - skipping)"
                fi
            fi
        fi
    done < "$temp_new_fields"

    # Clean up temporary files
    rm -f "$temp_new_fields" "$temp_old_fields"

    if [ "$has_changes" = true ]; then
        echo "      ✅ Only changed field permissions included in delta"
        return 0
    else
        echo "      📋 No field permission changes detected"
        return 1
    fi
}

# Run the extraction
extract_changed_field_permissions "$TEST_DIR/old_profile.xml" "$TEST_DIR/new_profile.xml" "$OUTPUT_FILE"

# Close the profile XML
echo "</Profile>" >> "$OUTPUT_FILE"

echo ""
echo "3️⃣ Analyzing Results"
echo "-------------------"

echo "📊 Generated Delta Profile:"
cat "$OUTPUT_FILE"

echo ""
echo "📈 Delta Analysis:"

# Count field permissions in delta
DELTA_FIELD_COUNT=$(grep -c "<fieldPermissions>" "$OUTPUT_FILE" 2>/dev/null || echo 0)
echo "   • Field permissions in delta: $DELTA_FIELD_COUNT"

# Check which fields are in the delta
if grep -q "Account.Account_Status__c" "$OUTPUT_FILE"; then
    echo "   ❌ PROBLEM: Account.Account_Status__c found in delta (should be EXCLUDED - unchanged)"
    TEST_RESULT="FAILED"
else
    echo "   ✅ CORRECT: Account.Account_Status__c NOT in delta (unchanged field excluded)"
fi

if grep -q "Account.Active4__c" "$OUTPUT_FILE"; then
    echo "   ✅ CORRECT: Account.Active4__c found in delta (changed field included)"
else
    echo "   ❌ PROBLEM: Account.Active4__c NOT found in delta (should be INCLUDED - changed field)"
    TEST_RESULT="FAILED"
fi

# Verify the change is correct
if grep -A 3 "Account.Active4__c" "$OUTPUT_FILE" | grep -q "<editable>false</editable>"; then
    echo "   ✅ CORRECT: Active4__c has editable=false in delta (correct change)"
else
    echo "   ❌ PROBLEM: Active4__c doesn't have editable=false in delta"
    TEST_RESULT="FAILED"
fi

echo ""
echo "🎯 TEST RESULTS"
echo "=============="

if [ "$DELTA_FIELD_COUNT" -eq 1 ] && grep -q "Account.Active4__c" "$OUTPUT_FILE" && ! grep -q "Account.Account_Status__c" "$OUTPUT_FILE"; then
    echo "✅ SUCCESS: True selective deployment working correctly!"
    echo ""
    echo "📋 Verification:"
    echo "   • Only 1 field permission in delta: ✅"
    echo "   • Only changed field (Active4__c) included: ✅"
    echo "   • Unchanged field (Account_Status__c) excluded: ✅"
    echo "   • Correct change (editable=false): ✅"
    echo ""
    echo "🎉 Your pipeline will now deploy ONLY the field you actually changed!"
    echo "   Instead of: Deploying both field permissions"
    echo "   Now does: Deploys only Active4__c permission change"
else
    echo "❌ FAILED: Selective deployment not working correctly"
    echo ""
    echo "📋 Issues found:"
    if [ "$DELTA_FIELD_COUNT" -ne 1 ]; then
        echo "   • Expected 1 field permission, got $DELTA_FIELD_COUNT"
    fi
    if grep -q "Account.Account_Status__c" "$OUTPUT_FILE"; then
        echo "   • Unchanged field included (should be excluded)"
    fi
    if ! grep -q "Account.Active4__c" "$OUTPUT_FILE"; then
        echo "   • Changed field not included (should be included)"
    fi
fi

echo ""
echo "🧹 Cleaning up test files..."
rm -rf "$TEST_DIR"

if [ "$DELTA_FIELD_COUNT" -eq 1 ] && grep -q "Account.Active4__c" "$OUTPUT_FILE" && ! grep -q "Account.Account_Status__c" "$OUTPUT_FILE"; then
    echo "✅ Test completed successfully!"
    exit 0
else
    echo "❌ Test failed - needs further refinement"
    exit 1
fi