#!/bin/bash

# Profile Validation Script - Flosum-style Enhanced Validation
# Usage: profile_validation.sh <delta_dir> <target_org>
# This script provides comprehensive profile validation including:
# 1. Dependency checking (field/object access validation)
# 2. Permission conflict detection
# 3. Impact analysis
# 4. Compliance rule verification

set -e

DELTA_DIR="$1"
TARGET_ORG="$2"

if [ -z "$DELTA_DIR" ] || [ -z "$TARGET_ORG" ]; then
    echo "Usage: $0 <delta_directory> <target_org>"
    echo "Example: $0 changed-sources targetOrg"
    exit 1
fi

echo "🔍 Enhanced Profile Validation (Flosum-style)"
echo "Delta directory: $DELTA_DIR"
echo "Target org: $TARGET_ORG"
echo ""

# Check if we have profile deltas to validate
if [ ! -f "$DELTA_DIR/has_profile_deltas.flag" ] || [ "$(cat "$DELTA_DIR/has_profile_deltas.flag")" != "true" ]; then
    echo "✅ No profile changes detected - validation not needed"
    exit 0
fi

echo "📋 Profile changes detected - running enhanced validation..."
echo ""

# Initialize validation results
VALIDATION_ERRORS=""
VALIDATION_WARNINGS=""
VALIDATION_PASSED=true

# Function to add error
add_error() {
    local error_msg="$1"
    VALIDATION_ERRORS="${VALIDATION_ERRORS}\n❌ $error_msg"
    VALIDATION_PASSED=false
    echo "❌ $error_msg"
}

# Function to add warning
add_warning() {
    local warning_msg="$1"
    VALIDATION_WARNINGS="${VALIDATION_WARNINGS}\n⚠️  $warning_msg"
    echo "⚠️  $warning_msg"
}

# Function to add success message
add_success() {
    local success_msg="$1"
    echo "✅ $success_msg"
}

echo "🔬 Running validation checks..."
echo ""

# 1. FIELD/OBJECT DEPENDENCY VALIDATION
echo "📊 Check 1: Field/Object Dependency Validation"
echo "   Validating that field permissions have corresponding object access..."

for profile_dir in "$DELTA_DIR/profile-deltas"/*; do
    if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
        PROFILE_NAME=$(basename "$profile_dir")

        # Find the profile file (delta or full)
        PROFILE_FILE=""
        if [ -f "$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml"
        elif [ -f "$profile_dir/${PROFILE_NAME}.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}.profile-meta.xml"
        else
            add_error "Profile file not found for $PROFILE_NAME"
            continue
        fi

        echo "   🔍 Validating profile: $PROFILE_NAME"

        # Extract field permissions
        if grep -q "<fieldPermissions>" "$PROFILE_FILE"; then
            # Get unique objects from field permissions
            FIELD_OBJECTS=$(grep -A 3 "<fieldPermissions>" "$PROFILE_FILE" | grep "<field>" | sed 's/.*<field>\([^.]*\)\..*/\1/' | sort -u)

            if [ -n "$FIELD_OBJECTS" ]; then
                echo "      📋 Field permissions found for objects: $(echo "$FIELD_OBJECTS" | tr '\n' ' ')"

                # Check if corresponding object permissions exist (in the profile file or org)
                while IFS= read -r object_name; do
                    if [ -n "$object_name" ]; then
                        # Check if object permissions exist in the profile
                        if grep -q "<object>$object_name</object>" "$PROFILE_FILE"; then
                            add_success "Object permission found for $object_name"
                        else
                            # This might be OK if object permissions already exist in the org
                            add_warning "Field permissions for $object_name but no object permissions in delta (may already exist in org)"
                        fi
                    fi
                done <<< "$FIELD_OBJECTS"
            fi
        fi

        # Check for orphaned object permissions (objects that don't exist)
        if grep -q "<objectPermissions>" "$PROFILE_FILE"; then
            PROFILE_OBJECTS=$(grep -A 7 "<objectPermissions>" "$PROFILE_FILE" | grep "<object>" | sed 's/.*<object>\(.*\)<\/object>.*/\1/' | sort -u)

            if [ -n "$PROFILE_OBJECTS" ]; then
                echo "      📋 Object permissions found for: $(echo "$PROFILE_OBJECTS" | tr '\n' ' ')"

                # Note: In a full implementation, we would query the org to check if these objects exist
                # For now, we'll just report what we found
                while IFS= read -r object_name; do
                    if [ -n "$object_name" ]; then
                        # Check for common invalid object patterns
                        if [[ "$object_name" =~ ^[a-z] ]]; then
                            add_warning "Object name '$object_name' starts with lowercase (check naming convention)"
                        fi

                        if [[ "$object_name" == *" "* ]]; then
                            add_error "Object name '$object_name' contains spaces (invalid)"
                        fi
                    fi
                done <<< "$PROFILE_OBJECTS"
            fi
        fi
    fi
done

echo ""

# 2. PERMISSION CONFLICT DETECTION
echo "📊 Check 2: Permission Conflict Detection"
echo "   Checking for potentially conflicting permissions within profiles..."

for profile_dir in "$DELTA_DIR/profile-deltas"/*; do
    if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
        PROFILE_NAME=$(basename "$profile_dir")

        # Find the profile file
        PROFILE_FILE=""
        if [ -f "$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml"
        elif [ -f "$profile_dir/${PROFILE_NAME}.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}.profile-meta.xml"
        fi

        if [ -n "$PROFILE_FILE" ]; then
            echo "   🔍 Checking conflicts in: $PROFILE_NAME"

            # Check for Read without Edit conflicts (Edit=true but Read=false)
            if grep -q "<fieldPermissions>" "$PROFILE_FILE"; then
                # Extract field permission blocks and check for logical conflicts
                field_conflicts=$(grep -A 3 "<fieldPermissions>" "$PROFILE_FILE" | grep -B 3 -A 3 "<editable>true</editable>" | grep -B 6 "<readable>false</readable>" || true)

                if [ -n "$field_conflicts" ]; then
                    add_error "Field permission conflict in $PROFILE_NAME: editable=true but readable=false"
                fi
            fi

            # Check for conflicting user permissions
            if grep -q "<userPermissions>" "$PROFILE_FILE"; then
                # Look for potentially conflicting admin vs limited user permissions
                has_modify_all=$(grep -A 2 "<userPermissions>" "$PROFILE_FILE" | grep -B 2 "<name>ModifyAllData</name>" | grep "<enabled>true</enabled>" || true)
                has_view_all=$(grep -A 2 "<userPermissions>" "$PROFILE_FILE" | grep -B 2 "<name>ViewAllData</name>" | grep "<enabled>true</enabled>" || true)

                if [ -n "$has_modify_all" ]; then
                    add_warning "Profile $PROFILE_NAME has ModifyAllData permission (high privilege)"
                fi

                if [ -n "$has_view_all" ]; then
                    add_warning "Profile $PROFILE_NAME has ViewAllData permission (broad access)"
                fi
            fi
        fi
    fi
done

echo ""

# 3. PROFILE COMPLETENESS VALIDATION
echo "📊 Check 3: Profile Completeness Validation"
echo "   Ensuring profile changes are complete and properly structured..."

for profile_dir in "$DELTA_DIR/profile-deltas"/*; do
    if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
        PROFILE_NAME=$(basename "$profile_dir")

        # Check if package.xml exists
        if [ ! -f "$profile_dir/package.xml" ]; then
            add_error "Missing package.xml for profile $PROFILE_NAME"
        else
            # Validate package.xml structure
            if ! grep -q "<name>Profile</name>" "$profile_dir/package.xml"; then
                add_error "Invalid package.xml for $PROFILE_NAME - missing Profile metadata type"
            fi

            if ! grep -q "<members>$PROFILE_NAME</members>" "$profile_dir/package.xml"; then
                add_error "Invalid package.xml for $PROFILE_NAME - profile not listed as member"
            fi
        fi

        # Find and validate profile file
        PROFILE_FILE=""
        if [ -f "$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml"
            echo "   📊 Delta profile: $PROFILE_NAME (selective deployment)"
        elif [ -f "$profile_dir/${PROFILE_NAME}.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}.profile-meta.xml"
            echo "   📦 Full profile: $PROFILE_NAME (complete deployment)"
        else
            add_error "Profile file not found for $PROFILE_NAME"
            continue
        fi

        # Validate XML structure
        if ! head -1 "$PROFILE_FILE" | grep -q "<?xml"; then
            add_error "Profile $PROFILE_NAME missing XML declaration"
        fi

        if ! grep -q "<Profile xmlns=" "$PROFILE_FILE"; then
            add_error "Profile $PROFILE_NAME missing proper Profile root element"
        fi

        if ! grep -q "</Profile>" "$PROFILE_FILE"; then
            add_error "Profile $PROFILE_NAME missing closing Profile tag"
        fi

        # Count permission types in the profile (clean variables)
        FIELD_PERMS=$(grep -c "<fieldPermissions>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        OBJECT_PERMS=$(grep -c "<objectPermissions>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        USER_PERMS=$(grep -c "<userPermissions>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        CLASS_ACCESS=$(grep -c "<classAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        APP_VIS=$(grep -c "<applicationVisibilities>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        TAB_VIS=$(grep -c "<tabVisibilities>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        RECORD_TYPE_VIS=$(grep -c "<recordTypeVisibilities>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        PAGE_ACCESS=$(grep -c "<pageAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        FLOW_ACCESS=$(grep -c "<flowAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        CUSTOM_SETTING_ACCESS=$(grep -c "<customSettingAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        LOGIN_HOURS=$(grep -c "<loginHours>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        LOGIN_IP_RANGES=$(grep -c "<loginIpRanges>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        SESSION_TIMEOUT=$(grep -c "<sessionTimeout>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
        EXT_DATA_SOURCE=$(grep -c "<externalDataSourceAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)

        echo "      📈 Permission summary:"
        echo "         • Field permissions: $FIELD_PERMS"
        echo "         • Object permissions: $OBJECT_PERMS"
        echo "         • User permissions: $USER_PERMS"
        echo "         • Apex class access: $CLASS_ACCESS"
        echo "         • App visibility: $APP_VIS"
        echo "         • Tab visibility: $TAB_VIS"
        echo "         • Record Type visibility: $RECORD_TYPE_VIS"
        echo "         • Visualforce page access: $PAGE_ACCESS"
        echo "         • Flow access: $FLOW_ACCESS"
        echo "         • Custom setting access: $CUSTOM_SETTING_ACCESS"
        echo "         • Login hours: $LOGIN_HOURS"
        echo "         • Login IP ranges: $LOGIN_IP_RANGES"
        echo "         • Session timeout: $SESSION_TIMEOUT"
        echo "         • External data source access: $EXT_DATA_SOURCE"

        # Calculate total permissions (with robust parameter expansion)
        TOTAL_PERMISSIONS=$(( ${FIELD_PERMS:-0} + ${OBJECT_PERMS:-0} + ${USER_PERMS:-0} + ${CLASS_ACCESS:-0} + ${APP_VIS:-0} + ${TAB_VIS:-0} + ${RECORD_TYPE_VIS:-0} + ${PAGE_ACCESS:-0} + ${FLOW_ACCESS:-0} + ${CUSTOM_SETTING_ACCESS:-0} + ${LOGIN_HOURS:-0} + ${LOGIN_IP_RANGES:-0} + ${SESSION_TIMEOUT:-0} + ${EXT_DATA_SOURCE:-0} ))
        echo "         📊 Total profile elements: $TOTAL_PERMISSIONS"

        if [ "${TOTAL_PERMISSIONS:-0}" -eq 0 ]; then
            add_error "Profile $PROFILE_NAME appears to be empty (no permissions found)"
        fi
    fi
done

echo ""

# 4. IMPACT ANALYSIS
echo "📊 Check 4: Impact Analysis"
echo "   Analyzing potential impact of profile changes..."

TOTAL_PROFILES=$(find "$DELTA_DIR/profile-deltas" -maxdepth 1 -type d | grep -v "/profile-deltas$" | wc -l | tr -d '\n\r')
echo "   📋 Total profiles being modified: $TOTAL_PROFILES"

for profile_dir in "$DELTA_DIR/profile-deltas"/*; do
    if [ -d "$profile_dir" ] && [ "$(basename "$profile_dir")" != "has_profile_changes.flag" ]; then
        PROFILE_NAME=$(basename "$profile_dir")

        # Find the profile file
        PROFILE_FILE=""
        if [ -f "$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}-delta.profile-meta.xml"
        elif [ -f "$profile_dir/${PROFILE_NAME}.profile-meta.xml" ]; then
            PROFILE_FILE="$profile_dir/${PROFILE_NAME}.profile-meta.xml"
        fi

        if [ -n "$PROFILE_FILE" ]; then
            echo "   🎯 Impact analysis for: $PROFILE_NAME"

            # Analyze permission grants vs restrictions (clean variables)
            ENABLED_PERMS=$(grep -c "<enabled>true</enabled>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            DISABLED_PERMS=$(grep -c "<enabled>false</enabled>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            READABLE_FIELDS=$(grep -c "<readable>true</readable>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            EDITABLE_FIELDS=$(grep -c "<editable>true</editable>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)

            echo "      📊 Permission changes:"
            echo "         • Enabled permissions: $ENABLED_PERMS"
            echo "         • Disabled permissions: $DISABLED_PERMS"
            echo "         • Readable fields: $READABLE_FIELDS"
            echo "         • Editable fields: $EDITABLE_FIELDS"

            if [ "${DISABLED_PERMS:-0}" -gt 0 ]; then
                add_warning "Profile $PROFILE_NAME removes/restricts $DISABLED_PERMS permissions (may impact users)"
            fi

            if [ "${ENABLED_PERMS:-0}" -gt 0 ]; then
                add_success "Profile $PROFILE_NAME grants $ENABLED_PERMS new permissions"
            fi

            # Check for high-impact permission changes
            if grep -q "<name>ModifyAllData</name>" "$PROFILE_FILE"; then
                add_warning "High-impact change: ModifyAllData permission modified in $PROFILE_NAME"
            fi

            if grep -q "<name>ViewAllData</name>" "$PROFILE_FILE"; then
                add_warning "High-impact change: ViewAllData permission modified in $PROFILE_NAME"
            fi

            if grep -q "<name>ManageUsers</name>" "$PROFILE_FILE"; then
                add_warning "High-impact change: ManageUsers permission modified in $PROFILE_NAME"
            fi

            # Check for specific high-impact changes with new elements (clean variables)
            RECORD_TYPE_CHANGES=$(grep -c "<recordTypeVisibilities>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            VF_PAGE_CHANGES=$(grep -c "<pageAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            FLOW_CHANGES=$(grep -c "<flowAccesses>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
            LOGIN_SETTING_CHANGES=$(grep -c "<loginHours>\|<loginIpRanges>\|<sessionTimeout>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)

            if [ "${RECORD_TYPE_CHANGES:-0}" -gt 0 ]; then
                add_success "Profile $PROFILE_NAME includes $RECORD_TYPE_CHANGES record type visibility changes"
            fi

            if [ "${VF_PAGE_CHANGES:-0}" -gt 0 ]; then
                add_success "Profile $PROFILE_NAME includes $VF_PAGE_CHANGES Visualforce page access changes"
            fi

            if [ "${FLOW_CHANGES:-0}" -gt 0 ]; then
                add_success "Profile $PROFILE_NAME includes $FLOW_CHANGES Flow access changes"
            fi

            if [ "${LOGIN_SETTING_CHANGES:-0}" -gt 0 ]; then
                add_warning "High-impact change: Login/Session settings modified in $PROFILE_NAME (security implications)"
            fi

            # Check for potentially restrictive changes
            if grep -q "<visible>false</visible>" "$PROFILE_FILE"; then
                HIDDEN_ELEMENTS=$(grep -c "<visible>false</visible>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
                add_warning "Profile $PROFILE_NAME hides $HIDDEN_ELEMENTS elements from users"
            fi

            if grep -q "<enabled>false</enabled>" "$PROFILE_FILE"; then
                DISABLED_ACCESS=$(grep -c "<enabled>false</enabled>" "$PROFILE_FILE" 2>/dev/null | tr -d '\n\r' || echo 0)
                add_warning "Profile $PROFILE_NAME disables access to $DISABLED_ACCESS elements"
            fi
        fi
    fi
done

echo ""

# 5. VALIDATION SUMMARY
echo "🎯 VALIDATION SUMMARY"
echo "===================="

if [ "$VALIDATION_PASSED" = true ]; then
    echo "✅ All profile validation checks passed!"
    echo ""
    echo "🚀 Profile deployment recommendations:"
    echo "   • Profiles are ready for deployment"
    echo "   • Monitor deployment for any unexpected issues"
    echo "   • Consider user communication if permissions change significantly"

    if [ -n "$VALIDATION_WARNINGS" ]; then
        echo ""
        echo "⚠️  Warnings to consider:"
        echo -e "$VALIDATION_WARNINGS"
        echo ""
        echo "📋 These warnings don't block deployment but should be reviewed."
    fi
else
    echo "❌ Profile validation failed!"
    echo ""
    echo "🔧 Errors that must be fixed:"
    echo -e "$VALIDATION_ERRORS"

    if [ -n "$VALIDATION_WARNINGS" ]; then
        echo ""
        echo "⚠️  Additional warnings:"
        echo -e "$VALIDATION_WARNINGS"
    fi

    echo ""
    echo "🚫 Please fix the errors above before proceeding with deployment."

    exit 1
fi

echo ""
echo "✅ Enhanced profile validation completed successfully!"