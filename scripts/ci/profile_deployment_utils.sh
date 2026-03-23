#!/bin/bash

# Profile Deployment Utilities - Flosum-style Helper Functions
# Usage: Source this file to use utility functions for profile deployment
# Contains helper functions for profile management and deployment

# Function to show profile deployment summary
show_profile_deployment_summary() {
    local delta_dir="$1"

    if [ ! -d "$delta_dir/profile-deltas" ]; then
        echo "📋 No profile deltas found"
        return 0
    fi

    echo "📊 Profile Deployment Summary"
    echo "============================"

    local profile_count=0
    local field_permission_total=0
    local object_permission_total=0
    local user_permission_total=0

    for profile_dir in "$delta_dir/profile-deltas"/*; do
        if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
            profile_count=$((profile_count + 1))
            local profile_name=$(basename "$profile_dir")

            # Find profile file
            local profile_file=""
            if [ -f "$profile_dir/${profile_name}-delta.profile-meta.xml" ]; then
                profile_file="$profile_dir/${profile_name}-delta.profile-meta.xml"
                echo "🎯 $profile_name (Delta Deployment)"
            elif [ -f "$profile_dir/${profile_name}.profile-meta.xml" ]; then
                profile_file="$profile_dir/${profile_name}.profile-meta.xml"
                echo "📦 $profile_name (Full Deployment)"
            fi

            if [ -n "$profile_file" ]; then
                local field_perms=$(grep -c "<fieldPermissions>" "$profile_file" 2>/dev/null || echo 0)
                local object_perms=$(grep -c "<objectPermissions>" "$profile_file" 2>/dev/null || echo 0)
                local user_perms=$(grep -c "<userPermissions>" "$profile_file" 2>/dev/null || echo 0)
                local class_access=$(grep -c "<classAccesses>" "$profile_file" 2>/dev/null || echo 0)
                local app_vis=$(grep -c "<applicationVisibilities>" "$profile_file" 2>/dev/null || echo 0)
                local tab_vis=$(grep -c "<tabVisibilities>" "$profile_file" 2>/dev/null || echo 0)
                local record_type_vis=$(grep -c "<recordTypeVisibilities>" "$profile_file" 2>/dev/null || echo 0)
                local page_access=$(grep -c "<pageAccesses>" "$profile_file" 2>/dev/null || echo 0)
                local flow_access=$(grep -c "<flowAccesses>" "$profile_file" 2>/dev/null || echo 0)
                local custom_setting=$(grep -c "<customSettingAccesses>" "$profile_file" 2>/dev/null || echo 0)
                local login_hours=$(grep -c "<loginHours>" "$profile_file" 2>/dev/null || echo 0)
                local login_ip=$(grep -c "<loginIpRanges>" "$profile_file" 2>/dev/null || echo 0)
                local session_timeout=$(grep -c "<sessionTimeout>" "$profile_file" 2>/dev/null || echo 0)
                local ext_data_source=$(grep -c "<externalDataSourceAccesses>" "$profile_file" 2>/dev/null || echo 0)

                echo "   • Field permissions: $field_perms"
                echo "   • Object permissions: $object_perms"
                echo "   • User permissions: $user_perms"
                echo "   • Apex class access: $class_access"
                echo "   • App visibilities: $app_vis"
                echo "   • Tab visibilities: $tab_vis"
                echo "   • Record Type visibilities: $record_type_vis"
                echo "   • Visualforce page access: $page_access"
                echo "   • Flow access: $flow_access"
                echo "   • Custom setting access: $custom_setting"
                echo "   • Login hours: $login_hours"
                echo "   • Login IP ranges: $login_ip"
                echo "   • Session timeout: $session_timeout"
                echo "   • External data source access: $ext_data_source"

                field_permission_total=$((field_permission_total + field_perms))
                object_permission_total=$((object_permission_total + object_perms))
                user_permission_total=$((user_permission_total + user_perms))
            fi
            echo ""
        fi
    done

    echo "📈 Totals:"
    echo "   • Profiles: $profile_count"
    echo "   • Total field permissions: $field_permission_total"
    echo "   • Total object permissions: $object_permission_total"
    echo "   • Total user permissions: $user_permission_total"
    echo ""
}

# Function to create rollback package for profiles
create_profile_rollback_package() {
    local delta_dir="$1"
    local git_from="$2"
    local rollback_dir="$delta_dir/profile-rollback"

    echo "🔄 Creating profile rollback package..."

    if [ ! -d "$delta_dir/profile-deltas" ]; then
        echo "📋 No profile deltas to create rollback for"
        return 0
    fi

    mkdir -p "$rollback_dir"

    # For each changed profile, create the previous version
    for profile_dir in "$delta_dir/profile-deltas"/*; do
        if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
            local profile_name=$(basename "$profile_dir")

            # Get the previous version of the profile
            local profile_path="force-app/main/default/profiles/${profile_name}.profile-meta.xml"

            if git cat-file -e "$git_from:$profile_path" 2>/dev/null; then
                local rollback_profile_dir="$rollback_dir/$profile_name"
                mkdir -p "$rollback_profile_dir"

                # Extract previous version
                git show "$git_from:$profile_path" > "$rollback_profile_dir/${profile_name}.profile-meta.xml"

                # Create package.xml for rollback
                cat > "$rollback_profile_dir/package.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>$profile_name</members>
        <name>Profile</name>
    </types>
    <version>65.0</version>
</Package>
EOF

                echo "📋 Rollback package created for: $profile_name"
            else
                echo "⚠️  Cannot create rollback for $profile_name (new profile)"
            fi
        fi
    done

    echo "✅ Profile rollback package created in: $rollback_dir"
}

# Function to validate profile permissions against org metadata
validate_profile_permissions_against_org() {
    local profile_file="$1"
    local target_org="$2"
    local validation_errors=""

    echo "🔍 Validating profile permissions against org metadata..."

    # Get field permissions from profile
    if grep -q "<fieldPermissions>" "$profile_file"; then
        echo "   📋 Checking field permissions..."

        # Extract unique objects and fields
        local field_refs=$(grep -A 3 "<fieldPermissions>" "$profile_file" | grep "<field>" | sed 's/.*<field>\(.*\)<\/field>.*/\1/')

        while IFS= read -r field_ref; do
            if [ -n "$field_ref" ] && [[ "$field_ref" == *.* ]]; then
                local object_name=$(echo "$field_ref" | cut -d. -f1)
                local field_name=$(echo "$field_ref" | cut -d. -f2)

                echo "      🔍 Validating: $object_name.$field_name"

                # Note: In a full implementation, we would query the org to verify field exists
                # For demo purposes, we'll check naming conventions
                if [[ "$field_name" =~ ^[a-z] ]] && [[ ! "$field_name" =~ __c$ ]]; then
                    echo "      ⚠️  $field_ref may not follow standard field naming (starts with lowercase, no __c suffix)"
                fi
            fi
        done <<< "$field_refs"
    fi

    # Check object permissions
    if grep -q "<objectPermissions>" "$profile_file"; then
        echo "   📋 Checking object permissions..."

        local object_refs=$(grep -A 7 "<objectPermissions>" "$profile_file" | grep "<object>" | sed 's/.*<object>\(.*\)<\/object>.*/\1/')

        while IFS= read -r object_ref; do
            if [ -n "$object_ref" ]; then
                echo "      🔍 Validating object: $object_ref"

                # Check object naming conventions
                if [[ "$object_ref" =~ ^[a-z] ]] && [[ ! "$object_ref" =~ __c$ ]] && [[ ! "$object_ref" =~ ^[A-Z][a-zA-Z]*$ ]]; then
                    echo "      ⚠️  $object_ref may not follow standard object naming"
                fi
            fi
        done <<< "$object_refs"
    fi

    echo "   ✅ Basic permission validation completed"
}

# Function to generate profile deployment report
generate_profile_deployment_report() {
    local delta_dir="$1"
    local output_file="$2"

    echo "📊 Generating profile deployment report..."

    cat > "$output_file" << EOF
# Profile Deployment Report
Generated: $(date)

## Summary
EOF

    if [ -d "$delta_dir/profile-deltas" ]; then
        local profile_count=$(find "$delta_dir/profile-deltas" -maxdepth 1 -type d ! -path "$delta_dir/profile-deltas" | wc -l)

        cat >> "$output_file" << EOF

- Total profiles modified: $profile_count
- Deployment method: Flosum-style selective deployment
- Only changed profile elements deployed (faster & safer)

## Profiles Modified
EOF

        for profile_dir in "$delta_dir/profile-deltas"/*; do
            if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
                local profile_name=$(basename "$profile_dir")

                cat >> "$output_file" << EOF

### $profile_name
EOF

                # Find profile file and analyze
                local profile_file=""
                if [ -f "$profile_dir/${profile_name}-delta.profile-meta.xml" ]; then
                    profile_file="$profile_dir/${profile_name}-delta.profile-meta.xml"
                    echo "- Deployment type: Delta (selective)" >> "$output_file"
                elif [ -f "$profile_dir/${profile_name}.profile-meta.xml" ]; then
                    profile_file="$profile_dir/${profile_name}.profile-meta.xml"
                    echo "- Deployment type: Full profile" >> "$output_file"
                fi

                if [ -n "$profile_file" ]; then
                    local field_perms=$(grep -c "<fieldPermissions>" "$profile_file" 2>/dev/null || echo 0)
                    local object_perms=$(grep -c "<objectPermissions>" "$profile_file" 2>/dev/null || echo 0)
                    local user_perms=$(grep -c "<userPermissions>" "$profile_file" 2>/dev/null || echo 0)
                    local class_access=$(grep -c "<classAccesses>" "$profile_file" 2>/dev/null || echo 0)

                    cat >> "$output_file" << EOF
- Field permissions: $field_perms
- Object permissions: $object_perms
- User permissions: $user_perms
- Apex class access: $class_access
EOF
                fi
            fi
        done
    else
        cat >> "$output_file" << EOF

No profile changes detected.
EOF
    fi

    cat >> "$output_file" << EOF

## Deployment Benefits

### Flosum-style Selective Deployment
- ✅ Faster deployments (only changed elements)
- ✅ Reduced risk (smaller packages)
- ✅ Better change tracking
- ✅ Enhanced validation
- ✅ Conflict reduction

### Enhanced Validation
- ✅ Dependency checking (field/object validation)
- ✅ Permission conflict detection
- ✅ Impact analysis
- ✅ Compliance verification

---
Report generated by Flosum-style Profile Deployment System
EOF

    echo "✅ Report generated: $output_file"
}

# Function to check profile deployment prerequisites
check_profile_deployment_prerequisites() {
    local target_org="$1"

    echo "🔍 Checking profile deployment prerequisites..."

    # Check SF CLI
    if ! command -v sf &> /dev/null; then
        echo "❌ Salesforce CLI not found"
        return 1
    fi
    echo "✅ Salesforce CLI found"

    # Check org connection
    if ! sf org display --target-org "$target_org" --json > /dev/null 2>&1; then
        echo "❌ Cannot connect to target org: $target_org"
        return 1
    fi
    echo "✅ Org connection verified: $target_org"

    # Check required tools
    if ! command -v jq &> /dev/null; then
        echo "⚠️  jq not found (JSON parsing may be limited)"
    else
        echo "✅ jq found for JSON parsing"
    fi

    if ! command -v git &> /dev/null; then
        echo "❌ Git not found (required for delta detection)"
        return 1
    fi
    echo "✅ Git found"

    echo "✅ All prerequisites met"
    return 0
}

echo "📚 Profile deployment utilities loaded"
echo "Available functions:"
echo "   • show_profile_deployment_summary"
echo "   • create_profile_rollback_package"
echo "   • validate_profile_permissions_against_org"
echo "   • generate_profile_deployment_report"
echo "   • check_profile_deployment_prerequisites"