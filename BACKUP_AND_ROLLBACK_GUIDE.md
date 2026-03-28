# Backup and Rollback System Guide

## Overview
Your CI/CD workflow now includes an **automatic backup system** that creates snapshots before every deployment and preserves them for 30 days. If a deployment causes issues, you can easily rollback to the previous state.

---

## How Backups Work

### Automatic Backup Creation

**When:** Every deployment to the test branch (on merge/push)

**What happens:**
1. **Before deployment** starts, workflow retrieves current state from org
2. Only backs up **components that will be changed** (not entire org)
3. Creates timestamped backup directory: `backups/20260328-143025/`
4. Uploads backup as **GitHub Actions artifact**
5. **Preserves backup for 30 days**
6. Then proceeds with actual deployment

**Backup Contents:**
```
backups/20260328-143025/
├── force-app/
│   └── main/default/
│       ├── classes/
│       │   ├── MyClass.cls
│       │   └── MyClass.cls-meta.xml
│       ├── profiles/
│       │   └── Admin.profile-meta.xml
│       └── objects/Account/fields/
│           └── CustomField__c.field-meta.xml
└── backup-info.txt  ← Metadata (commit, actor, date, etc.)
```

---

## Viewing Backups

### Option 1: Via GitHub Actions UI

1. Go to your repository on GitHub
2. Click **Actions** tab
3. Click on the deployment workflow run
4. Scroll to **Artifacts** section at bottom
5. You'll see: `salesforce-backup-abc123def`

**Example:**
```
Artifacts produced during runtime
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 salesforce-backup-7222555abc123def456
   Size: 2.3 MB
   Expires: April 27, 2026
```

### Option 2: Via GitHub CLI

```bash
# List recent workflow runs
gh run list --workflow="Salesforce CI/CD Pipeline" --limit 10

# View artifacts for a specific run
gh run view 9876543210 --log

# Download backup artifact
gh run download 9876543210 -n salesforce-backup-7222555abc123def456
```

---

## Rollback Methods

### Method 1: Manual UI Rollback (Recommended)

**Step 1: Find the Backup**
1. Go to GitHub → **Actions**
2. Find the **failed or problematic deployment** workflow run
3. Note the **commit SHA** (e.g., `7222555`)
4. Note the **backup artifact name**: `salesforce-backup-7222555abc123def456`

**Step 2: Trigger Rollback**
1. Go to **Actions** → **🔄 Rollback Deployment**
2. Click **Run workflow** (top right)
3. Fill in the form:

```yaml
Backup directory: backups/20260328-143025
Target Salesforce Org: targetOrg  # or production, staging
Reason for rollback: Deployment caused validation rule issues
Skip test execution: Yes (or No for safety)
```

4. Click **Run workflow**
5. Watch the rollback progress in real-time

**Step 3: Verify**
1. Rollback creates audit log: `rollbacks/rollback-20260328-152030.log`
2. Check Salesforce org to verify components restored
3. Review deployment ID in workflow output

---

### Method 2: Script-Based Rollback

**Step 1: Download Backup Artifact**

```bash
# Find the workflow run ID
gh run list --workflow="Salesforce CI/CD Pipeline" --limit 5

# Example output:
# ✓  main  Salesforce CI/CD Pipeline  completed  9876543210

# Download the backup artifact
gh run download 9876543210 -n salesforce-backup-7222555abc123def456

# This creates a directory with the backup
ls salesforce-backup-7222555abc123def456/
```

**Step 2: Run Rollback Script**

```bash
# Navigate to your project
cd Salesforce-integration/

# Run rollback script (uses the downloaded backup)
./scripts/ci/rollback_from_artifact.sh \
  salesforce-backup-7222555abc123def456.zip \
  targetOrg
```

**Script Output:**
```
Extracting backup...
Found source directory: force-app/
🚀 Starting rollback deployment...
✅ Rollback completed successfully!
📋 Deployment ID: 0Afxxx000009876
```

---

### Method 3: Manual Salesforce CLI Rollback

**For advanced users who want full control:**

```bash
# Step 1: Download and extract backup
gh run download 9876543210 -n salesforce-backup-7222555abc123def456
cd salesforce-backup-7222555abc123def456/backups/20260328-143025/

# Step 2: Review what will be restored
cat backup-info.txt
ls -R force-app/

# Step 3: Authenticate to Salesforce
sf org login jwt \
  --username your-username@org.com \
  --jwt-key-file ~/server.key \
  --client-id YOUR_CONSUMER_KEY \
  --alias targetOrg

# Step 4: Deploy the backup (restore)
sf project deploy start \
  --source-dir force-app \
  --target-org targetOrg \
  --test-level NoTestRun

# Optional: Run tests after restore
sf project deploy start \
  --source-dir force-app \
  --target-org targetOrg \
  --test-level RunLocalTests
```

---

## Real-World Scenarios

### Scenario 1: Deployment Caused Production Bug

**Timeline:**
```
10:00 AM - Deploy profile changes to production
10:15 AM - Users report they can't see Account records
10:20 AM - Decision: ROLLBACK NOW!
```

**Action:**
1. Go to GitHub → Actions → "🔄 Rollback Deployment"
2. Run workflow:
   - Backup: `backups/20260328-100000`
   - Org: `production`
   - Reason: "Profile changes broke Account visibility"
   - Skip tests: `Yes` (urgent!)
3. Rollback completes in 3 minutes
4. Users confirm Account records visible again ✅

**Follow-up:**
- Review audit log: `rollbacks/rollback-20260328-102000.log`
- Fix the profile issue in feature branch
- Re-deploy after fix is validated

---

### Scenario 2: Need to Revert Last Week's Deployment

**Timeline:**
```
March 21 - Deployed new validation rules
March 28 - Discover validation rules too strict
         - Need to rollback to pre-March 21 state
```

**Action:**
1. Find March 21 workflow run in GitHub Actions
2. Check if backup artifact still exists (30-day retention)
3. Download artifact: `salesforce-backup-march21.zip`
4. Run rollback script:
   ```bash
   ./scripts/ci/rollback_from_artifact.sh \
     salesforce-backup-march21.zip \
     targetOrg
   ```
5. Verify validation rules reverted ✅

---

### Scenario 3: Partial Rollback (Only Some Components)

**What:** You want to rollback ONLY the profile changes, not the Apex classes

**Action:**
```bash
# Download backup
gh run download 9876543210 -n salesforce-backup-7222555

# Extract and edit the backup
cd salesforce-backup-7222555/backups/20260328-143025/

# Remove Apex classes (keep only profiles)
rm -rf force-app/main/default/classes/

# Deploy only the profiles
sf project deploy start \
  --source-dir force-app/main/default/profiles \
  --target-org targetOrg
```

---

## Backup Metadata File

Each backup includes `backup-info.txt` with critical information:

```
Backup Information
==================
Created: Fri Mar 28 14:30:25 UTC 2026
Branch: refs/heads/test
Commit: 7222555abc123def456789
Workflow Run: 9876543210
Actor: rnagaraj
Target Org: targetOrg
```

**Why This Matters:**
- **Created:** When backup was taken
- **Branch:** Which branch triggered deployment
- **Commit:** Exact commit SHA (link to code changes)
- **Workflow Run:** Direct link to GitHub Actions run
- **Actor:** Who triggered the deployment
- **Target Org:** Which Salesforce org was backed up

---

## Audit Trail

### Rollback Audit Logs

Every rollback creates an audit log for compliance and tracking:

**Location:** `rollbacks/rollback-YYYYMMDD-HHMMSS.log`

**Contents:**
```
=====================================
ROLLBACK AUDIT LOG
=====================================
Date: Fri Mar 28 15:20:00 UTC 2026
Performer: rnagaraj
Target Org: targetOrg
Backup Used: backups/20260328-143025
Reason: Deployment caused validation rule issues
Deployment ID: 0Afxxx000009876
Workflow Run: https://github.com/org/repo/actions/runs/9876543210

DEPLOYMENT RESULT:
{
  "status": 0,
  "result": {
    "id": "0Afxxx000009876",
    "status": "Succeeded",
    "numberComponentsDeployed": 12,
    ...
  }
}
=====================================
```

**Audit logs are automatically committed to the repository** for permanent record.

---

## Backup Retention and Cleanup

### Automatic Retention
- **Artifacts:** Kept for **30 days**
- **After 30 days:** Automatically deleted by GitHub
- **Audit logs:** Kept forever (in Git)

### Manual Cleanup

**Clean up old artifacts via CLI:**
```bash
# List all artifacts
gh api repos/{owner}/{repo}/actions/artifacts | jq '.artifacts[] | {name, created_at, expired}'

# Delete specific artifact (if needed before 30 days)
gh api -X DELETE repos/{owner}/{repo}/actions/artifacts/{artifact_id}
```

**Clean up audit logs:**
```bash
# Review old audit logs
ls -lht rollbacks/

# Archive logs older than 90 days
find rollbacks/ -name "*.log" -mtime +90 -exec tar -czf archived-rollbacks.tar.gz {} \;

# Remove archived logs
find rollbacks/ -name "*.log" -mtime +90 -delete
```

---

## Backup Limitations

### What Backups DO Include:
- ✅ Metadata changed in the deployment
- ✅ Apex classes, triggers
- ✅ Profiles (current state from org)
- ✅ Custom objects, fields
- ✅ Workflows, flows
- ✅ Validation rules, field updates

### What Backups DON'T Include:
- ❌ **Data records** (only metadata)
- ❌ Components not in the deployment package
- ❌ Org-wide settings (like org preferences)
- ❌ Manually created components (not in Git)
- ❌ Permission sets assigned to users
- ❌ Email templates, reports, dashboards (unless in deployment)

### Backup Failures

If backup fails, workflow continues with warning:
```
⚠️  Backup failed, but continuing deployment...
```

**Reasons backup might fail:**
- API rate limits
- Network timeout
- Insufficient org permissions
- Component already deleted from org

**Mitigation:**
- Deployment continues (doesn't block)
- Manual backup recommended before critical deployments
- Consider using versioned releases for high-risk changes

---

## Best Practices

### 1. Verify Backups Regularly
```bash
# Monthly: Check that backups are being created
gh run list --workflow="Salesforce CI/CD Pipeline" --limit 5
# Verify artifacts exist for recent runs
```

### 2. Test Rollback Process
```bash
# Quarterly: Practice rollback in sandbox
1. Deploy test changes to sandbox
2. Download backup artifact
3. Run rollback script
4. Verify restoration
```

### 3. Document Critical Rollbacks
```bash
# After major rollback, document in project docs:
- What went wrong
- Why rollback was needed
- Which backup was used
- Lessons learned
```

### 4. Pre-Deployment Checklist for High-Risk Changes
```markdown
Before deploying to production:
- [ ] Validated in sandbox
- [ ] Dry run passed with tests
- [ ] Team reviewed changes
- [ ] Manual backup taken (belt + suspenders)
- [ ] Rollback plan documented
- [ ] Stakeholders notified
```

### 5. Monitor Artifact Storage
```bash
# GitHub has storage limits for artifacts
# Monitor usage: Settings → Billing → Storage

# Current usage:
gh api /repos/{owner}/{repo}/actions/cache/usage
```

---

## Notifications (Optional Enhancement)

### Slack Rollback Notifications

The rollback workflow includes **optional Slack notifications**:

**Setup:**
1. Create Slack webhook: https://api.slack.com/messaging/webhooks
2. Add to GitHub Secrets: `SLACK_WEBHOOK_URL`
3. Rollback workflow automatically sends notifications

**Success Notification:**
```
✅ Rollback Completed

Org: production
By: rnagaraj
Backup: backups/20260328-143025
Deployment ID: 0Afxxx000009876

Reason: Deployment caused validation rule issues
```

**Failure Notification:**
```
❌ Rollback Failed

Rollback to production failed!

By: rnagaraj
Backup: backups/20260328-143025

[View Logs]
```

---

## Troubleshooting

### Problem: Can't Find Backup Artifact

**Symptom:** Artifact not showing in GitHub Actions

**Solutions:**
1. Check if deployment completed successfully
2. Verify `HAS_BACKUP=true` in workflow logs
3. Check if more than 30 days have passed (expired)
4. Try GitHub CLI: `gh run download <run-id>`

---

### Problem: Rollback Workflow Can't Find Backup Directory

**Symptom:** Error: `Backup directory not found!`

**Cause:** Trying to use repository path instead of artifact

**Solutions:**
1. Use **artifact-based rollback** (Method 2) instead
2. Download artifact first, then provide path
3. Or commit backups to Git (requires workflow modification)

---

### Problem: Rollback Fails with "Component Not Found"

**Symptom:** Rollback deployment fails, component doesn't exist

**Cause:** Component was deleted from org after backup

**Solutions:**
1. Review backup contents: `cat backup-info.txt`
2. Manually create missing components first
3. Or use partial rollback (exclude missing components)

---

### Problem: Backup Takes Too Long / Times Out

**Symptom:** Backup step exceeds timeout

**Cause:** Large deployment package, slow API response

**Solutions:**
1. Split large deployments into smaller batches
2. Increase timeout in workflow (max 360 minutes)
   ```yaml
   - name: 'Create backup'
     timeout-minutes: 30  # Default is 360
   ```
3. Consider backing up only critical components

---

## Summary

### What You Have Now:

✅ **Automatic backups** before every deployment
✅ **30-day retention** via GitHub artifacts
✅ **Three rollback methods** (UI, script, manual)
✅ **Audit trail** for compliance
✅ **Slack notifications** (optional)
✅ **Complete safety net** for risky deployments

### Quick Reference Card:

| Action | Command |
|--------|---------|
| **View backups** | GitHub → Actions → Workflow → Artifacts |
| **Trigger UI rollback** | Actions → "🔄 Rollback Deployment" → Run workflow |
| **Download artifact** | `gh run download <run-id> -n salesforce-backup-<sha>` |
| **Script rollback** | `./scripts/ci/rollback_from_artifact.sh backup.zip targetOrg` |
| **Manual rollback** | `sf project deploy start --source-dir <backup>/force-app` |
| **View audit logs** | `cat rollbacks/rollback-*.log` |

---

## Next Steps

1. **Test the system**
   - Make a small test deployment
   - Verify artifact is created
   - Practice downloading and restoring

2. **Train your team**
   - Share this guide with team members
   - Run rollback drills in sandbox
   - Document team-specific procedures

3. **Monitor and maintain**
   - Check artifacts are being created weekly
   - Review audit logs monthly
   - Clean up old artifacts if needed

4. **Enhance (optional)**
   - Add Slack webhook for notifications
   - Implement automated rollback on failure
   - Add data backup strategy (records, not just metadata)

---

**Need help?** Check workflow logs in GitHub Actions for detailed error messages.
