#!/bin/bash

# Profile Delta Handler - Flosum-style Selective Profile Deployment
# Usage: profile_delta_handler.sh <delta_dir> <git_from> <git_to>
# This script implements selective profile deployment by:
# 1. Detecting profile changes
# 2. Creating profile delta packages with only changed elements
# 3. Validating profile dependencies

set -e

DELTA_DIR="$1"
GIT_FROM="$2"
GIT_TO="$3"

if [ -z "$DELTA_DIR" ] || [ -z "$GIT_FROM" ] || [ -z "$GIT_TO" ]; then
    echo "Usage: $0 <delta_directory> <git_from> <git_to>"
    echo "Example: $0 changed-sources HEAD~1 HEAD"
    exit 1
fi

echo "🔍 Profile Delta Handler - Flosum-style Selective Deployment"
echo "Delta directory: $DELTA_DIR"
echo "Git range: $GIT_FROM → $GIT_TO"
echo ""

# Create profile-specific directories
PROFILE_DELTA_DIR="$DELTA_DIR/profile-deltas"
mkdir -p "$PROFILE_DELTA_DIR"

# Detect changed profile files
echo "📋 Detecting profile changes..."
CHANGED_PROFILES=$(git diff --name-only "$GIT_FROM" "$GIT_TO" | grep "\.profile-meta\.xml$" || true)

if [ -z "$CHANGED_PROFILES" ]; then
    echo "✅ No profile changes detected"
    echo "false" > "$PROFILE_DELTA_DIR/has_profile_changes.flag"
    exit 0
fi

echo "🎯 Profile files changed:"
echo "$CHANGED_PROFILES" | sed 's/^/   • /'
echo ""

# Flag that we have profile changes
echo "true" > "$PROFILE_DELTA_DIR/has_profile_changes.flag"

# Process each changed profile
PROFILE_COUNT=0
while IFS= read -r profile_file; do
    if [ -z "$profile_file" ]; then
        continue
    fi

    PROFILE_COUNT=$((PROFILE_COUNT + 1))
    PROFILE_NAME=$(basename "$profile_file" .profile-meta.xml)

    echo "🔄 Processing profile: $PROFILE_NAME"
    echo "   File: $profile_file"

    # Check if this is a new profile (added) or modified profile
    if ! git cat-file -e "$GIT_FROM:$profile_file" 2>/dev/null; then
        echo "   📝 Status: NEW profile (full deployment needed)"

        # For new profiles, copy the entire file
        PROFILE_OUTPUT_DIR="$PROFILE_DELTA_DIR/$PROFILE_NAME"
        mkdir -p "$PROFILE_OUTPUT_DIR"

        if [ -f "$profile_file" ]; then
            cp "$profile_file" "$PROFILE_OUTPUT_DIR/${PROFILE_NAME}.profile-meta.xml"
            echo "   ✅ Full profile copied for deployment"
        else
            echo "   ❌ Profile file not found: $profile_file"
            continue
        fi
    else
        echo "   📝 Status: MODIFIED profile (delta extraction needed)"

        # Extract delta for modified profile
        OLD_PROFILE_CONTENT=$(git show "$GIT_FROM:$profile_file")
        NEW_PROFILE_CONTENT=$(cat "$profile_file" 2>/dev/null || echo "")

        if [ -z "$NEW_PROFILE_CONTENT" ]; then
            echo "   ❌ Could not read new profile content"
            continue
        fi

        # Create delta profile directory
        PROFILE_OUTPUT_DIR="$PROFILE_DELTA_DIR/$PROFILE_NAME"
        mkdir -p "$PROFILE_OUTPUT_DIR"

        # Generate delta profile XML
        DELTA_PROFILE="$PROFILE_OUTPUT_DIR/${PROFILE_NAME}-delta.profile-meta.xml"

        echo "   🔬 Extracting profile delta..."

        # Call the profile delta extraction function
        if extract_profile_delta "$OLD_PROFILE_CONTENT" "$NEW_PROFILE_CONTENT" "$DELTA_PROFILE" "$PROFILE_NAME"; then
            echo "   ✅ Profile delta extracted successfully"
        else
            echo "   ⚠️  Delta extraction failed - deploying full profile as fallback"
            cp "$profile_file" "$PROFILE_OUTPUT_DIR/${PROFILE_NAME}.profile-meta.xml"
        fi
    fi

    # Create package.xml for this profile
    create_profile_package_xml "$PROFILE_OUTPUT_DIR" "$PROFILE_NAME"

    echo "   📦 Profile package created: $PROFILE_OUTPUT_DIR"
    echo ""

done <<< "$CHANGED_PROFILES"

echo "📊 Profile Delta Summary:"
echo "   • Profiles processed: $PROFILE_COUNT"
echo "   • Delta packages created in: $PROFILE_DELTA_DIR"
echo ""

# Create master profile package.xml if we have multiple profiles
if [ "$PROFILE_COUNT" -gt 1 ]; then
    echo "🔗 Creating master profile package for multi-profile deployment..."
    create_master_profile_package "$PROFILE_DELTA_DIR" "$PROFILE_COUNT"
fi

echo "✅ Profile delta processing completed successfully"

# Function to extract delta between two profile XML files
extract_profile_delta() {
    local old_content="$1"
    local new_content="$2"
    local output_file="$3"
    local profile_name="$4"

    # Create temporary files for comparison
    local temp_old="/tmp/profile_old_$$.xml"
    local temp_new="/tmp/profile_new_$$.xml"

    echo "$old_content" > "$temp_old"
    echo "$new_content" > "$temp_new"

    # Start building delta profile
    cat > "$output_file" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
EOF

    local has_changes=false

    # Extract field permissions that changed
    if extract_changed_field_permissions "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract object permissions that changed
    if extract_changed_object_permissions "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract apex class access that changed
    if extract_changed_apex_access "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract user permissions that changed
    if extract_changed_user_permissions "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract application visibility that changed
    if extract_changed_application_visibility "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract tab visibility that changed
    if extract_changed_tab_visibility "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Close the profile XML
    echo "</Profile>" >> "$output_file"

    # Clean up temp files
    rm -f "$temp_old" "$temp_new"

    if [ "$has_changes" = true ]; then
        echo "      🎯 Delta contains: $(grep -c '<.*Permissions>' "$output_file" 2>/dev/null || echo 0) permission changes"
        return 0
    else
        echo "      📋 No significant changes detected"
        rm -f "$output_file"
        return 1
    fi
}

# Function to extract changed field permissions
extract_changed_field_permissions() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking field permissions..."

    # Get all field permissions from new file
    # Use a more robust XML parsing approach
    local new_fields=$(grep -A 3 "<fieldPermissions>" "$new_file" | grep "<field>" | sed 's/.*<field>\(.*\)<\/field>.*/\1/' | sort)
    local old_fields=$(grep -A 3 "<fieldPermissions>" "$old_file" | grep "<field>" | sed 's/.*<field>\(.*\)<\/field>.*/\1/' | sort)

    # Compare field permissions
    while IFS= read -r field_name; do
        if [ -n "$field_name" ]; then
            # Extract the complete fieldPermissions block for this field from new file
            local new_field_block=$(sed -n "/<fieldPermissions>/,/<\/fieldPermissions>/p" "$new_file" | sed -n "/<field>$field_name<\/field>/,/<\/fieldPermissions>/p")
            local old_field_block=$(sed -n "/<fieldPermissions>/,/<\/fieldPermissions>/p" "$old_file" | sed -n "/<field>$field_name<\/field>/,/<\/fieldPermissions>/p")

            # Check if this field permission is new or changed
            if [ -z "$old_field_block" ] || [ "$new_field_block" != "$old_field_block" ]; then
                echo "         • $field_name (changed/new)"
                # Add the complete fieldPermissions block
                echo "    <fieldPermissions>" >> "$output_file"
                echo "$new_field_block" | grep -v "<fieldPermissions>" | grep -v "</fieldPermissions>" >> "$output_file"
                echo "    </fieldPermissions>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_fields"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed object permissions
extract_changed_object_permissions() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking object permissions..."

    local new_objects=$(grep -A 7 "<objectPermissions>" "$new_file" | grep "<object>" | sed 's/.*<object>\(.*\)<\/object>.*/\1/' | sort)

    while IFS= read -r object_name; do
        if [ -n "$object_name" ]; then
            local new_object_block=$(sed -n "/<objectPermissions>/,/<\/objectPermissions>/p" "$new_file" | sed -n "/<object>$object_name<\/object>/,/<\/objectPermissions>/p")
            local old_object_block=$(sed -n "/<objectPermissions>/,/<\/objectPermissions>/p" "$old_file" | sed -n "/<object>$object_name<\/object>/,/<\/objectPermissions>/p")

            if [ -z "$old_object_block" ] || [ "$new_object_block" != "$old_object_block" ]; then
                echo "         • $object_name (changed/new)"
                echo "    <objectPermissions>" >> "$output_file"
                echo "$new_object_block" | grep -v "<objectPermissions>" | grep -v "</objectPermissions>" >> "$output_file"
                echo "    </objectPermissions>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_objects"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed Apex class access
extract_changed_apex_access() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking Apex class access..."

    local new_classes=$(grep -A 2 "<classAccesses>" "$new_file" | grep "<apexClass>" | sed 's/.*<apexClass>\(.*\)<\/apexClass>.*/\1/' | sort)

    while IFS= read -r class_name; do
        if [ -n "$class_name" ]; then
            local new_class_block=$(sed -n "/<classAccesses>/,/<\/classAccesses>/p" "$new_file" | sed -n "/<apexClass>$class_name<\/apexClass>/,/<\/classAccesses>/p")
            local old_class_block=$(sed -n "/<classAccesses>/,/<\/classAccesses>/p" "$old_file" | sed -n "/<apexClass>$class_name<\/apexClass>/,/<\/classAccesses>/p")

            if [ -z "$old_class_block" ] || [ "$new_class_block" != "$old_class_block" ]; then
                echo "         • $class_name (changed/new)"
                echo "    <classAccesses>" >> "$output_file"
                echo "$new_class_block" | grep -v "<classAccesses>" | grep -v "</classAccesses>" >> "$output_file"
                echo "    </classAccesses>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_classes"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed user permissions
extract_changed_user_permissions() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking user permissions..."

    local new_user_perms=$(grep -A 2 "<userPermissions>" "$new_file" | grep "<name>" | sed 's/.*<name>\(.*\)<\/name>.*/\1/' | sort)

    while IFS= read -r perm_name; do
        if [ -n "$perm_name" ]; then
            local new_perm_block=$(sed -n "/<userPermissions>/,/<\/userPermissions>/p" "$new_file" | sed -n "/<name>$perm_name<\/name>/,/<\/userPermissions>/p")
            local old_perm_block=$(sed -n "/<userPermissions>/,/<\/userPermissions>/p" "$old_file" | sed -n "/<name>$perm_name<\/name>/,/<\/userPermissions>/p")

            if [ -z "$old_perm_block" ] || [ "$new_perm_block" != "$old_perm_block" ]; then
                echo "         • $perm_name (changed/new)"
                echo "    <userPermissions>" >> "$output_file"
                echo "$new_perm_block" | grep -v "<userPermissions>" | grep -v "</userPermissions>" >> "$output_file"
                echo "    </userPermissions>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_user_perms"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed application visibility
extract_changed_application_visibility() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking application visibility..."

    local new_apps=$(grep -A 3 "<applicationVisibilities>" "$new_file" | grep "<application>" | sed 's/.*<application>\(.*\)<\/application>.*/\1/' | sort)

    while IFS= read -r app_name; do
        if [ -n "$app_name" ]; then
            local new_app_block=$(sed -n "/<applicationVisibilities>/,/<\/applicationVisibilities>/p" "$new_file" | sed -n "/<application>$app_name<\/application>/,/<\/applicationVisibilities>/p")
            local old_app_block=$(sed -n "/<applicationVisibilities>/,/<\/applicationVisibilities>/p" "$old_file" | sed -n "/<application>$app_name<\/application>/,/<\/applicationVisibilities>/p")

            if [ -z "$old_app_block" ] || [ "$new_app_block" != "$old_app_block" ]; then
                echo "         • $app_name (changed/new)"
                echo "    <applicationVisibilities>" >> "$output_file"
                echo "$new_app_block" | grep -v "<applicationVisibilities>" | grep -v "</applicationVisibilities>" >> "$output_file"
                echo "    </applicationVisibilities>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_apps"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed tab visibility
extract_changed_tab_visibility() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking tab visibility..."

    local new_tabs=$(grep -A 2 "<tabVisibilities>" "$new_file" | grep "<tab>" | sed 's/.*<tab>\(.*\)<\/tab>.*/\1/' | sort)

    while IFS= read -r tab_name; do
        if [ -n "$tab_name" ]; then
            local new_tab_block=$(sed -n "/<tabVisibilities>/,/<\/tabVisibilities>/p" "$new_file" | sed -n "/<tab>$tab_name<\/tab>/,/<\/tabVisibilities>/p")
            local old_tab_block=$(sed -n "/<tabVisibilities>/,/<\/tabVisibilities>/p" "$old_file" | sed -n "/<tab>$tab_name<\/tab>/,/<\/tabVisibilities>/p")

            if [ -z "$old_tab_block" ] || [ "$new_tab_block" != "$old_tab_block" ]; then
                echo "         • $tab_name (changed/new)"
                echo "    <tabVisibilities>" >> "$output_file"
                echo "$new_tab_block" | grep -v "<tabVisibilities>" | grep -v "</tabVisibilities>" >> "$output_file"
                echo "    </tabVisibilities>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_tabs"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to create package.xml for a profile
create_profile_package_xml() {
    local profile_dir="$1"
    local profile_name="$2"

    cat > "$profile_dir/package.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
        <members>$profile_name</members>
        <name>Profile</name>
    </types>
    <version>65.0</version>
</Package>
EOF
}

# Function to create master package.xml for multiple profiles
create_master_profile_package() {
    local profile_delta_dir="$1"
    local profile_count="$2"

    local master_package="$profile_delta_dir/package.xml"

    cat > "$master_package" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Package xmlns="http://soap.sforce.com/2006/04/metadata">
    <types>
EOF

    # Add all profile names
    for profile_dir in "$profile_delta_dir"/*; do
        if [ -d "$profile_dir" ]; then
            local profile_name=$(basename "$profile_dir")
            echo "        <members>$profile_name</members>" >> "$master_package"
        fi
    done

    cat >> "$master_package" << 'EOF'
        <name>Profile</name>
    </types>
    <version>65.0</version>
</Package>
EOF

    echo "   📦 Master package.xml created with $profile_count profiles"
}