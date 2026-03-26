#!/bin/bash

# Profile Delta Handler - Intelligent Selective Profile Deployment
# Usage: profile_delta_handler.sh <delta_dir> <git_from> <git_to>
# This script implements selective profile deployment by:
# 1. Detecting profile changes
# 2. Creating profile delta packages with only changed elements
# 3. Validating profile dependencies

set -e

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

    # Extract record type visibilities that changed
    if extract_changed_record_type_visibilities "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract Visualforce page access that changed
    if extract_changed_page_access "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract flow access that changed
    if extract_changed_flow_access "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract custom setting access that changed
    if extract_changed_custom_setting_access "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract login hours that changed
    if extract_changed_login_hours "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract login IP ranges that changed
    if extract_changed_login_ip_ranges "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract session timeout that changed
    if extract_changed_session_timeout "$temp_old" "$temp_new" "$output_file"; then
        has_changes=true
    fi

    # Extract external data source access that changed
    if extract_changed_external_data_source_access "$temp_old" "$temp_new" "$output_file"; then
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

    # Create temporary files to store individual field permission blocks
    local temp_new_fields="/tmp/new_fields_$$.txt"
    local temp_old_fields="/tmp/old_fields_$$.txt"

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

    # Debug: Show temp file contents
    echo "      [DEBUG] Temp new fields:"
    while IFS='|||' read -r fname fblock; do
        field_tag=$(echo "$fblock" | sed 's/\\n/\n/g' | grep -o '<field>[^<]*</field>' || echo "N/A")
        echo "      [DEBUG]   Variable: $fname | Block tag: $field_tag"
    done < "$temp_new_fields"

    # Compare each field permission block
    while IFS='|||' read -r field_name new_block; do
        if [ -n "$field_name" ] && [ -n "$new_block" ]; then
            # Use grep -F for literal string matching (no regex interpretation)
            old_line=$(grep -F "${field_name}|||" "$temp_old_fields" | head -1)
            old_block="${old_line#*|||}"  # Remove everything up to and including first |||

            if [ -z "$old_block" ]; then
                # New field permission (didn't exist before)
                echo "         • $field_name (NEW field permission)"
                # Unescape newlines before writing to output
                echo "$new_block" | sed 's/\\n/\n/g' >> "$output_file"
                has_changes=true
            else
                # Compare semantic values (editable/readable) instead of raw XML text
                # This avoids false positives from whitespace/formatting differences
                old_unescaped=$(echo "$old_block" | sed 's/\\n/\n/g')
                new_unescaped=$(echo "$new_block" | sed 's/\\n/\n/g')

                # Extract actual permission values
                old_editable=$(echo "$old_unescaped" | grep -o '<editable>[^<]*</editable>' | sed 's/<[^>]*>//g')
                new_editable=$(echo "$new_unescaped" | grep -o '<editable>[^<]*</editable>' | sed 's/<[^>]*>//g')
                old_readable=$(echo "$old_unescaped" | grep -o '<readable>[^<]*</readable>' | sed 's/<[^>]*>//g')
                new_readable=$(echo "$new_unescaped" | grep -o '<readable>[^<]*</readable>' | sed 's/<[^>]*>//g')

                # Compare actual permission values
                if [ "$old_editable" != "$new_editable" ] || [ "$old_readable" != "$new_readable" ]; then
                    echo "         • $field_name (CHANGED permission)"

                    if [ "$old_editable" != "$new_editable" ]; then
                        echo "           └── Editable: $old_editable → $new_editable"
                    fi
                    if [ "$old_readable" != "$new_readable" ]; then
                        echo "           └── Readable: $old_readable → $new_readable"
                    fi

                    # Debug: Show what we're about to write
                    echo "      [DEBUG] Writing field: $field_name"
                    echo "      [DEBUG] Block field tag: $(echo "$new_unescaped" | grep -o '<field>[^<]*</field>')"
                    echo "      [DEBUG] Block editable: $new_editable"
                    echo "      [DEBUG] Block readable: $new_readable"

                    # Unescape newlines before writing to output
                    echo "$new_block" | sed 's/\\n/\n/g' >> "$output_file"
                    has_changes=true
                else
                    echo "         • $field_name (UNCHANGED - skipping)"
                fi
            fi
        fi
    done < "$temp_new_fields"

    # Check for deleted field permissions
    while IFS='|||' read -r field_name old_block; do
        if [ -n "$field_name" ] && [ -n "$old_block" ]; then
            # Use grep -F for literal string matching (no regex interpretation)
            new_line=$(grep -F "${field_name}|||" "$temp_new_fields" | head -1)
            # Check if this field exists in new file
            if [ -z "$new_line" ]; then
                echo "         • $field_name (REMOVED field permission)"
                # Note: For removed permissions, we would need to handle this via destructive changes
                # For now, just log it
            fi
        fi
    done < "$temp_old_fields"

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

# Function to extract changed record type visibilities
extract_changed_record_type_visibilities() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking record type visibilities..."

    local new_record_types=$(grep -A 4 "<recordTypeVisibilities>" "$new_file" | grep "<recordType>" | sed 's/.*<recordType>\(.*\)<\/recordType>.*/\1/' | sort)

    while IFS= read -r record_type; do
        if [ -n "$record_type" ]; then
            local new_rt_block=$(sed -n "/<recordTypeVisibilities>/,/<\/recordTypeVisibilities>/p" "$new_file" | sed -n "/<recordType>$record_type<\/recordType>/,/<\/recordTypeVisibilities>/p")
            local old_rt_block=$(sed -n "/<recordTypeVisibilities>/,/<\/recordTypeVisibilities>/p" "$old_file" | sed -n "/<recordType>$record_type<\/recordType>/,/<\/recordTypeVisibilities>/p")

            if [ -z "$old_rt_block" ] || [ "$new_rt_block" != "$old_rt_block" ]; then
                echo "         • $record_type (changed/new)"
                echo "    <recordTypeVisibilities>" >> "$output_file"
                echo "$new_rt_block" | grep -v "<recordTypeVisibilities>" | grep -v "</recordTypeVisibilities>" >> "$output_file"
                echo "    </recordTypeVisibilities>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_record_types"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed Visualforce page access
extract_changed_page_access() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking Visualforce page access..."

    local new_pages=$(grep -A 2 "<pageAccesses>" "$new_file" | grep "<apexPage>" | sed 's/.*<apexPage>\(.*\)<\/apexPage>.*/\1/' | sort)

    while IFS= read -r page_name; do
        if [ -n "$page_name" ]; then
            local new_page_block=$(sed -n "/<pageAccesses>/,/<\/pageAccesses>/p" "$new_file" | sed -n "/<apexPage>$page_name<\/apexPage>/,/<\/pageAccesses>/p")
            local old_page_block=$(sed -n "/<pageAccesses>/,/<\/pageAccesses>/p" "$old_file" | sed -n "/<apexPage>$page_name<\/apexPage>/,/<\/pageAccesses>/p")

            if [ -z "$old_page_block" ] || [ "$new_page_block" != "$old_page_block" ]; then
                echo "         • $page_name (changed/new)"
                echo "    <pageAccesses>" >> "$output_file"
                echo "$new_page_block" | grep -v "<pageAccesses>" | grep -v "</pageAccesses>" >> "$output_file"
                echo "    </pageAccesses>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_pages"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed flow access
extract_changed_flow_access() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking Flow access..."

    local new_flows=$(grep -A 2 "<flowAccesses>" "$new_file" | grep "<flow>" | sed 's/.*<flow>\(.*\)<\/flow>.*/\1/' | sort)

    while IFS= read -r flow_name; do
        if [ -n "$flow_name" ]; then
            local new_flow_block=$(sed -n "/<flowAccesses>/,/<\/flowAccesses>/p" "$new_file" | sed -n "/<flow>$flow_name<\/flow>/,/<\/flowAccesses>/p")
            local old_flow_block=$(sed -n "/<flowAccesses>/,/<\/flowAccesses>/p" "$old_file" | sed -n "/<flow>$flow_name<\/flow>/,/<\/flowAccesses>/p")

            if [ -z "$old_flow_block" ] || [ "$new_flow_block" != "$old_flow_block" ]; then
                echo "         • $flow_name (changed/new)"
                echo "    <flowAccesses>" >> "$output_file"
                echo "$new_flow_block" | grep -v "<flowAccesses>" | grep -v "</flowAccesses>" >> "$output_file"
                echo "    </flowAccesses>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_flows"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed custom setting access
extract_changed_custom_setting_access() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking custom setting access..."

    local new_settings=$(grep -A 2 "<customSettingAccesses>" "$new_file" | grep "<name>" | sed 's/.*<name>\(.*\)<\/name>.*/\1/' | sort)

    while IFS= read -r setting_name; do
        if [ -n "$setting_name" ]; then
            local new_setting_block=$(sed -n "/<customSettingAccesses>/,/<\/customSettingAccesses>/p" "$new_file" | sed -n "/<name>$setting_name<\/name>/,/<\/customSettingAccesses>/p")
            local old_setting_block=$(sed -n "/<customSettingAccesses>/,/<\/customSettingAccesses>/p" "$old_file" | sed -n "/<name>$setting_name<\/name>/,/<\/customSettingAccesses>/p")

            if [ -z "$old_setting_block" ] || [ "$new_setting_block" != "$old_setting_block" ]; then
                echo "         • $setting_name (changed/new)"
                echo "    <customSettingAccesses>" >> "$output_file"
                echo "$new_setting_block" | grep -v "<customSettingAccesses>" | grep -v "</customSettingAccesses>" >> "$output_file"
                echo "    </customSettingAccesses>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_settings"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed login hours
extract_changed_login_hours() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"

    echo "      🔍 Checking login hours..."

    local new_login_hours=$(grep -A 10 "<loginHours>" "$new_file" | sed -n '/<loginHours>/,/<\/loginHours>/p' | head -n -1 | tail -n +2)
    local old_login_hours=$(grep -A 10 "<loginHours>" "$old_file" | sed -n '/<loginHours>/,/<\/loginHours>/p' | head -n -1 | tail -n +2)

    if [ "$new_login_hours" != "$old_login_hours" ]; then
        echo "         • Login hours settings changed"
        echo "    <loginHours>" >> "$output_file"
        echo "$new_login_hours" >> "$output_file"
        echo "    </loginHours>" >> "$output_file"
        return 0
    else
        return 1
    fi
}

# Function to extract changed login IP ranges
extract_changed_login_ip_ranges() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking login IP ranges..."

    local new_ip_ranges=$(grep -A 3 "<loginIpRanges>" "$new_file" | grep "<startAddress>" | sed 's/.*<startAddress>\(.*\)<\/startAddress>.*/\1/' | sort)

    while IFS= read -r ip_start; do
        if [ -n "$ip_start" ]; then
            local new_ip_block=$(sed -n "/<loginIpRanges>/,/<\/loginIpRanges>/p" "$new_file" | sed -n "/<startAddress>$ip_start<\/startAddress>/,/<\/loginIpRanges>/p")
            local old_ip_block=$(sed -n "/<loginIpRanges>/,/<\/loginIpRanges>/p" "$old_file" | sed -n "/<startAddress>$ip_start<\/startAddress>/,/<\/loginIpRanges>/p")

            if [ -z "$old_ip_block" ] || [ "$new_ip_block" != "$old_ip_block" ]; then
                echo "         • IP range starting with $ip_start (changed/new)"
                echo "    <loginIpRanges>" >> "$output_file"
                echo "$new_ip_block" | grep -v "<loginIpRanges>" | grep -v "</loginIpRanges>" >> "$output_file"
                echo "    </loginIpRanges>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_ip_ranges"

    if [ "$has_changes" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to extract changed session timeout
extract_changed_session_timeout() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"

    echo "      🔍 Checking session timeout..."

    local new_session_timeout=$(grep "<sessionTimeout>" "$new_file" | sed 's/.*<sessionTimeout>\(.*\)<\/sessionTimeout>.*/\1/')
    local old_session_timeout=$(grep "<sessionTimeout>" "$old_file" | sed 's/.*<sessionTimeout>\(.*\)<\/sessionTimeout>.*/\1/')

    if [ "$new_session_timeout" != "$old_session_timeout" ]; then
        echo "         • Session timeout changed from $old_session_timeout to $new_session_timeout"
        echo "    <sessionTimeout>$new_session_timeout</sessionTimeout>" >> "$output_file"
        return 0
    else
        return 1
    fi
}

# Function to extract changed external data source access
extract_changed_external_data_source_access() {
    local old_file="$1"
    local new_file="$2"
    local output_file="$3"
    local has_changes=false

    echo "      🔍 Checking external data source access..."

    local new_data_sources=$(grep -A 2 "<externalDataSourceAccesses>" "$new_file" | grep "<externalDataSource>" | sed 's/.*<externalDataSource>\(.*\)<\/externalDataSource>.*/\1/' | sort)

    while IFS= read -r ds_name; do
        if [ -n "$ds_name" ]; then
            local new_ds_block=$(sed -n "/<externalDataSourceAccesses>/,/<\/externalDataSourceAccesses>/p" "$new_file" | sed -n "/<externalDataSource>$ds_name<\/externalDataSource>/,/<\/externalDataSourceAccesses>/p")
            local old_ds_block=$(sed -n "/<externalDataSourceAccesses>/,/<\/externalDataSourceAccesses>/p" "$old_file" | sed -n "/<externalDataSource>$ds_name<\/externalDataSource>/,/<\/externalDataSourceAccesses>/p")

            if [ -z "$old_ds_block" ] || [ "$new_ds_block" != "$old_ds_block" ]; then
                echo "         • $ds_name (changed/new)"
                echo "    <externalDataSourceAccesses>" >> "$output_file"
                echo "$new_ds_block" | grep -v "<externalDataSourceAccesses>" | grep -v "</externalDataSourceAccesses>" >> "$output_file"
                echo "    </externalDataSourceAccesses>" >> "$output_file"
                has_changes=true
            fi
        fi
    done <<< "$new_data_sources"

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

# ===== MAIN EXECUTION STARTS HERE =====

DELTA_DIR="$1"
GIT_FROM="$2"
GIT_TO="$3"

if [ -z "$DELTA_DIR" ] || [ -z "$GIT_FROM" ] || [ -z "$GIT_TO" ]; then
    echo "Usage: $0 <delta_directory> <git_from> <git_to>"
    echo "Example: $0 changed-sources HEAD~1 HEAD"
    exit 1
fi

echo "🔍 Profile Delta Handler - Intelligent Selective Deployment"
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