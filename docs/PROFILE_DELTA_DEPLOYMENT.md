# Profile Delta Deployment - Technical Documentation

## Overview

This CI/CD pipeline implements **Git-based Delta Profile Deployment**, which deploys only the profile permissions that changed in your Git commits, protecting manual changes made directly in the Salesforce org.

## Key Benefits

✅ **Selective Deployment**: Only changed field/object permissions are deployed
✅ **Org Protection**: Manual org changes are preserved and not overridden
✅ **Single Deployment**: All changes (metadata + profile deltas) deploy together
✅ **Destructive Changes Support**: Works seamlessly with component deletions
✅ **Performance**: Faster deployments by deploying fewer profile elements

## How It Works

### Example Scenario

**Initial State:**
- Git: `Account.Active4__c` → editable: false, readable: false
- Git: `Account_Status__c` → editable: true, readable: true

**Manual Org Changes:**
- Someone manually changes `Account_Status__c` to editable: false, readable: false

**Your Git Commit:**
- You change `Account.Active4__c` to editable: true, readable: true
- You commit and push this change

**Deployment Result:**
- ✅ `Active4__c` is updated to editable: true, readable: true (from Git)
- ✅ `Account_Status__c` remains editable: false, readable: false (manual change preserved!)

---

## Technical Implementation

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Git Commit Detection (sfdx-git-delta)                    │
│    Identifies changed profile files                          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│ 2. Delta Extraction (profile_delta_handler.sh)              │
│    • Compares HEAD~1 vs HEAD for each profile               │
│    • Extracts only changed field/object/user permissions    │
│    • Uses semantic comparison (values, not XML text)         │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│ 3. Replace-with-Delta Strategy                              │
│    • Backup original profile to /tmp/                        │
│    • Replace original with delta profile                     │
│    • Deploy using manifest (finds delta at expected location)│
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│ 4. Deployment                                                │
│    • Salesforce CLI deploys "original" location             │
│    • But content is the delta (only changed permissions)    │
│    • Supports destructive changes via manifest               │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│ 5. Restore Original                                          │
│    • Original profile restored from backup                   │
│    • Git working directory clean                             │
└─────────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. Profile Delta Handler (`scripts/ci/profile_delta_handler.sh`)

**Key Function: `extract_changed_field_permissions()`** (Lines 121-240)

```bash
# Semantic comparison instead of text comparison
old_editable=$(extract_value "<editable>")
new_editable=$(extract_value "<editable>")

if [ "$old_editable" != "$new_editable" ]; then
    # Deploy this field permission
fi
```

**Why Semantic Comparison?**
- `git show HEAD~1:profile.xml` and current file may have whitespace differences
- XML text comparison would flag unchanged fields as "changed"
- Comparing actual values (true/false) is accurate

**Extraction Process:**
1. Extract all `<fieldPermissions>` blocks from both old and new files
2. Store in temp files with format: `FieldName|||XMLBlock`
3. Compare `editable` and `readable` values for each field
4. Include field in delta only if values changed

#### 2. Replace-with-Delta Strategy (`.github/workflows/salesforce_deploy_21_mar.yml`)

**Backup and Replace** (Lines 251-264):
```yaml
# Backup original to temp
mkdir -p "/tmp/profile-backups"
cp "$ORIGINAL_PROFILE" "/tmp/profile-backups/${PROFILE_NAME}.profile-meta.xml"

# REPLACE original with delta profile
cp "$DELTA_PROFILE" "$ORIGINAL_PROFILE"
```

**Deployment** (Line 322):
```yaml
DEPLOY_CMD="--manifest changed-sources/package/package.xml"
# CLI looks for profile at force-app/.../Admin.profile-meta.xml
# But that file now contains the delta, not the full profile!
```

**Restore** (Lines 418-426):
```yaml
# After deployment completes
cp "/tmp/profile-backups/Admin.profile-meta.xml" "$ORIGINAL_PROFILE"
```

---

## Key Technical Constraints

### Why This Approach?

**Constraint 1: Destructive Changes Require Manifest**
- `--post-destructive-changes` CLI flag REQUIRES `--manifest`
- Cannot use `--source-dir` alone when deploying deletions

**Constraint 2: Manifest Uses Project Root**
- Salesforce CLI finds `sfdx-project.json` and resolves all paths from there
- Cannot redirect to alternate directory with `cd`

**Constraint 3: Cannot Combine Flags**
- `--manifest` and `--source-dir` cannot be used together
- CLI validation rejects this combination

**Solution: Replace Instead of Redirect**
- Instead of trying to redirect CLI to delta directory
- Replace the original file temporarily with delta content
- CLI finds file at expected location, but content is delta!

### Failed Approaches (For Reference)

❌ **Attempt 1**: Use `--source-dir` with `--manifest`
```bash
sf project deploy start --source-dir changed-sources/force-app --manifest package.xml
# Error: Cannot use both flags together
```

❌ **Attempt 2**: Change directory
```bash
cd changed-sources
sf project deploy start --manifest package/package.xml
# CLI still uses project root, ignores current directory
```

❌ **Attempt 3**: Rename to .backup
```bash
mv Admin.profile-meta.xml Admin.profile-meta.xml.backup
# CLI still finds and deploys .backup file
```

❌ **Attempt 4**: Move to /tmp without replacement
```bash
mv Admin.profile-meta.xml /tmp/
# Error: "No source-backed components present in the package"
```

✅ **Working Solution**: Replace with delta, then restore
```bash
cp Admin.profile-meta.xml /tmp/backup
cp delta.profile-meta.xml Admin.profile-meta.xml
# Deploy (finds file at expected location with delta content)
cp /tmp/backup Admin.profile-meta.xml
```

---

## File Locations

| File | Purpose | Key Lines |
|------|---------|-----------|
| `.github/workflows/salesforce_deploy_21_mar.yml` | Main CI/CD workflow | 251-264 (backup/replace)<br>322 (deployment)<br>418-426 (restore) |
| `scripts/ci/profile_delta_handler.sh` | Delta extraction logic | 121-240 (field permissions)<br>188-210 (semantic comparison) |
| `scripts/ci/profile_validation.sh` | Profile validation (warning-only) | Full file |

---

## Configuration

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DELTA_DIR` | `changed-sources` | Where delta packages are created |
| `TARGET_ORG_ALIAS` | `targetOrg` | Salesforce org alias |

### Git Comparison Range

The delta extraction compares:
- **Old Version**: `HEAD~1` (previous commit)
- **New Version**: `HEAD` (current commit)

This means the pipeline detects changes made in the most recent commit.

---

## Supported Profile Elements

The delta extraction currently supports:

✅ **Field Permissions** (`<fieldPermissions>`)
- Object.FieldName
- editable (true/false)
- readable (true/false)

✅ **Object Permissions** (`<objectPermissions>`)
- allowCreate, allowDelete, allowEdit, allowRead
- modifyAllRecords, viewAllRecords

✅ **User Permissions** (`<userPermissions>`)
- System-wide permissions

✅ **Apex Class Access** (`<classAccesses>`)
- enabled (true/false)

✅ **Tab Visibility** (`<tabVisibilities>`)
- visibility (DefaultOn, DefaultOff, Hidden)

✅ **Application Visibility** (`<applicationVisibilities>`)

✅ **Record Type Visibility** (`<recordTypeVisibilities>`)

✅ **Visualforce Page Access** (`<pageAccesses>`)

✅ **Flow Access** (`<flowAccesses>`)

---

## Workflow Execution

### Trigger

The workflow runs on push to `test` branch:
```yaml
on:
  push:
    branches:
      - test
```

### Steps

1. **Checkout Code**
2. **Install Salesforce CLI and sfdx-git-delta**
3. **Generate Delta Package** - Detect changed files
4. **Process Profile Changes** - Extract deltas with semantic comparison
5. **Validate Profiles** - Warning-only dependency checks
6. **Pre-Destructive Validation** - Safety checks for deletions
7. **Authenticate** - JWT-based Salesforce authentication
8. **Deploy Changes** - Single unified deployment with:
   - Profile deltas
   - Other metadata changes
   - Destructive changes
   - Test execution (if Apex classes changed)
9. **Post-Destructive Validation** - Generate audit trail

---

## Debug Output

The workflow logs detailed debug information:

### Profile Delta Extraction
```
🔬 Extracting profile delta...
   🔍 Checking field permissions...
   [DEBUG] Temp new fields:
   [DEBUG]   Variable: Account.Active4__c | Block tag: <field>Account.Active4__c</field>
      • Account.Active1__c (UNCHANGED - skipping)
      • Account.Active4__c (CHANGED permission)
        └── Editable: false → true
   ✅ Only changed field permissions included in delta
```

### Delta Profile Contents
```
[DEBUG] COMPLETE Delta profile XML:
================================================
<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldPermissions>
        <editable>true</editable>
        <field>Account.Active4__c</field>
        <readable>true</readable>
    </fieldPermissions>
</Profile>
================================================
```

### Backup and Restore
```
[DEBUG] Moving original profile to temp location: force-app/.../Admin.profile-meta.xml
[DEBUG] Restoring original profile files from backup...
[DEBUG] Restored from backup: force-app/.../Admin.profile-meta.xml
```

---

## Testing and Verification

### How to Test

1. **Initial Setup:**
   ```bash
   # Check current field permission in org
   # Account.Status__c: editable=true, readable=true
   ```

2. **Manual Org Change:**
   ```bash
   # In Salesforce UI, manually change:
   # Account.Status__c: editable=false, readable=false
   ```

3. **Git Change:**
   ```bash
   # Edit force-app/main/default/profiles/Admin.profile-meta.xml
   # Change Account.Active4__c: editable=false → true
   git add .
   git commit -m "Update Active4__c field permission"
   git push origin test
   ```

4. **Verify After Deployment:**
   ```bash
   # Check in Salesforce org:
   # ✅ Account.Active4__c: editable=true (from Git - deployed)
   # ✅ Account.Status__c: editable=false (manual change - preserved!)
   ```

### Expected Behavior

| Field | Before Deploy | Git Value | Manual Org Change | After Deploy | ✅/❌ |
|-------|---------------|-----------|-------------------|--------------|-------|
| Active4__c | false | true | - | true | ✅ Git change deployed |
| Status__c | true | true | Changed to false | false | ✅ Manual change preserved |

---

## Troubleshooting

### Issue: All fields are being deployed

**Symptom:** Unchanged fields are being deployed, overwriting manual org changes

**Possible Causes:**
1. Semantic comparison not working properly
2. Original profile not being replaced with delta
3. Full profile being deployed instead of delta

**Debug Steps:**
```bash
# Check the debug output in workflow logs
1. Look for "COMPLETE Delta profile XML" - should show only changed fields
2. Check "Delta profile field count" - should be 1 (or number of changed fields)
3. Verify "Moving original profile to temp location" appears in logs
```

### Issue: Deployment fails with "No source-backed components"

**Symptom:** Error message about missing components

**Cause:** Original profile was moved but not replaced

**Solution:** Ensure the replace logic is working (lines 251-264 in workflow)

### Issue: Git shows uncommitted changes after deployment

**Symptom:** `git status` shows modified profile files

**Cause:** Restore logic didn't run or failed

**Solution:** Check restore logic (lines 418-426) and ensure `/tmp/profile-backups/` exists

---

## Best Practices

### For Developers

1. **Commit Profile Changes Separately**
   - Keep profile changes in isolated commits for clearer delta detection
   - Avoid combining profile and Apex changes in same commit when possible

2. **Review Delta Output**
   - Check workflow logs to verify only expected fields are in delta
   - Look for the "COMPLETE Delta profile XML" section

3. **Test in Sandbox First**
   - Always test profile changes in sandbox before production
   - Verify manual org changes are preserved

### For Org Admins

1. **Document Manual Changes**
   - Keep track of any manual profile changes made in org
   - Communicate with dev team before pipeline runs

2. **Avoid Concurrent Changes**
   - Don't modify profiles manually while pipeline is running
   - Wait for deployment to complete before making manual changes

---

## Future Enhancements

Potential improvements to consider:

- [ ] Support for custom permissions (`<customPermissions>`)
- [ ] Layout assignments (`<layoutAssignments>`)
- [ ] Login hours and IP restrictions
- [ ] Profile-level settings (e.g., session timeout)
- [ ] Configurable comparison range (e.g., compare against specific branch)
- [ ] Dry-run mode to preview what would be deployed
- [ ] Option to disable debug output in production

---

## References

- **Salesforce CLI Documentation**: https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta
- **sfdx-git-delta**: https://github.com/scolladon/sfdx-git-delta
- **Profile Metadata Type**: https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_profile.htm

---

## Support

For issues or questions:
1. Check workflow logs for detailed debug output
2. Review this documentation
3. Check git history for recent changes: `git log --oneline test`
4. Review memory file: `memory/MEMORY.md`

---

**Last Updated**: March 26, 2026
**Version**: 1.0
**Status**: ✅ Production Ready
