# Salesforce Deployment Rollback Playbook

**Version:** 1.0  
**Last Updated:** 2026-04-20  
**Owner:** DevOps Team

---

## Table of Contents

1. [Overview](#overview)
2. [When to Rollback](#when-to-rollback)
3. [Rollback Types](#rollback-types)
4. [Pre-Rollback Checklist](#pre-rollback-checklist)
5. [Rollback Procedures](#rollback-procedures)
6. [Post-Rollback Verification](#post-rollback-verification)
7. [Troubleshooting](#troubleshooting)
8. [Emergency Contacts](#emergency-contacts)
9. [Example Scenarios](#example-scenarios)

---

## Overview

This playbook provides step-by-step instructions for rolling back Salesforce deployments when issues are detected. Our rollback system synchronizes both Git repository and Salesforce org state.

### Key Principles

- **Safety First**: Always verify backup exists before starting
- **Synchronized Rollback**: Git and Salesforce must stay in sync
- **Audit Trail**: Every rollback is logged and documented
- **Communication**: Notify team before and after rollback
- **Root Cause**: Always investigate why rollback was needed

### Rollback Capabilities

✅ **What We CAN Rollback:**
- Apex classes and triggers
- Visualforce pages and components
- Lightning components (Aura/LWC)
- Custom objects and fields
- Validation rules and workflows
- Profiles and permission sets
- Git commits

❌ **What We CANNOT Rollback:**
- User data (records)
- Record relationships
- Data loaded via Data Loader
- Manual configuration changes not in source control
- Changes made directly in org after deployment

---

## When to Rollback

### Immediate Rollback Required

**Execute rollback immediately if:**

🚨 **Critical Production Issues:**
- Application is down or unusable
- Data corruption detected
- Security vulnerability introduced
- Critical business process broken
- Mass user complaints

🚨 **Validation Failures:**
- Code coverage dropped below 85%
- Critical test failures
- Governor limit errors in production

🚨 **Deployment Errors:**
- Deployment partially completed with errors
- Components failed to deploy
- Unexpected behavior in critical features

### Consider Rollback

**Evaluate whether to rollback if:**

⚠️ **Minor Issues:**
- Non-critical feature not working as expected
- UI cosmetic issues
- Performance degradation (not severe)
- Single user reports issue

**Decision Process:**
1. Can issue be fixed forward quickly? (< 30 min)
   - Yes → Fix forward
   - No → Consider rollback
2. Is workaround available?
   - Yes → Apply workaround, fix in next release
   - No → Rollback
3. How many users affected?
   - Few → Consider fix forward
   - Many/All → Rollback

### Do NOT Rollback

❌ **Don't rollback if:**
- Issue is unrelated to recent deployment
- Rollback would cause more disruption than issue
- Backup doesn't exist or is corrupted
- Issue can be fixed with hotfix in < 15 minutes

---

## Rollback Types

### 1. Complete Rollback (Git + Salesforce) ⭐ RECOMMENDED

**Use when:** Normal rollback situation

**Characteristics:**
- Reverts Git commit(s)
- Restores Salesforce org from backup
- Keeps Git and Salesforce synchronized
- Prevents broken code from re-deploying

**Workflow:** `rollback_complete.yml`

---

### 2. Salesforce-Only Rollback

**Use when:** 
- Git commit was already reverted manually
- Only need to restore Salesforce org

**Characteristics:**
- Restores Salesforce org only
- Git branch unchanged
- Manual Git revert required separately

**Workflow:** `rollback.yml`

---

### 3. Git-Only Revert

**Use when:**
- Deployment hasn't started yet
- Want to prevent deployment

**Characteristics:**
- Reverts Git commit only
- No Salesforce changes

**Method:** Manual `git revert` command

---

## Pre-Rollback Checklist

### Step 1: Verify Issue (5 minutes)

```
□ Issue confirmed and documented
□ Severity level determined (Critical/High/Medium/Low)
□ Impact scope identified (# of users, business processes)
□ Recent deployment identified as root cause
□ Stakeholders notified (if critical)
```

### Step 2: Identify Rollback Details (5 minutes)

```
□ Bad commit SHA identified: _________________
□ Backup directory verified: _________________
□ Target org confirmed: prod / staging / targetOrg
□ Rollback type selected: Complete / SF-Only / Git-Only
□ Team members available for assistance
```

### Step 3: Pre-Rollback Communication (2 minutes)

**Send to:** `#deployments` Slack channel or team email

```
🚨 ROLLBACK IN PROGRESS 🚨

Issue: [Brief description]
Severity: [Critical/High/Medium/Low]
Commit: [SHA]
Org: [targetOrg/prod/staging]
ETA: [15 minutes]
Performing Rollback: [@your-name]
Tracking: [Link to GitHub Actions run]
```

### Step 4: Access Required Information

```
□ GitHub access confirmed
□ Salesforce org access confirmed
□ Backup location identified
□ Credentials available (if needed)
□ Git commit SHA copied
□ This playbook open and ready
```

---

## Rollback Procedures

### Procedure A: Complete Rollback (STANDARD)

**Duration:** 10-15 minutes  
**Workflow:** `rollback_complete.yml`

#### Step 1: Gather Information

```bash
# 1. Find the bad commit
git log --oneline -10

# Copy the commit SHA (e.g., a7a5752)

# 2. Identify backup directory
ls -lht backups/

# Should show: backups/20260419-143000/
# OR download from GitHub Actions → Artifacts
```

#### Step 2: Trigger Rollback Workflow

Navigate to: **GitHub → Actions → "Complete Rollback (Git + Salesforce)"**

Click: **"Run workflow"**

Fill in:
```
Commit to Revert: a7a5752
Backup Directory: backups/20260419-143000
Target Org: targetOrg
Reason: [Description of issue]
Skip Tests: ✓ Yes (for emergency)
Create Rollback Branch: ✓ Yes (recommended)
```

Click: **"Run workflow"**

#### Step 3: Monitor Execution (10-15 min)

Watch workflow progress:
```
✓ Display rollback plan
✓ Git rollback (creates branch + PR)
✓ Salesforce rollback (restores from backup)
✓ Verification
✓ Audit log created
```

#### Step 4: Verify Rollback Success

**Git Verification:**
```bash
# Check rollback branch created
git fetch origin
git branch -r | grep rollback

# Expected: origin/rollback/revert-a7a5752-...
```

**Salesforce Verification:**
```
1. Log into Salesforce org
2. Navigate to affected components
3. Verify old (working) code is present
4. Test affected functionality
5. Check recent deployments (Setup → Deployment Status)
```

#### Step 5: Merge Rollback (if using branch)

**If rollback branch was created:**
1. Review PR created by workflow
2. Verify changes in PR
3. Merge PR to main branch
4. Monitor auto-deployment (if enabled)

**If direct revert was used:**
- Rollback already merged to branch
- Verify with `git log`

---

### Procedure B: Emergency Rollback (FAST)

**Duration:** 5-10 minutes  
**Use:** Critical production outage  
**Workflow:** `rollback_complete.yml` (skip branch creation)

#### Quick Steps:

```
1. IDENTIFY
   git log -1 --oneline    # Get commit SHA
   ls -lht backups/ | head -1    # Get latest backup

2. TRIGGER
   Actions → Complete Rollback → Run workflow
   • Commit: [SHA]
   • Backup: [latest]
   • Create Branch: NO ← Direct revert
   • Skip Tests: YES
   
3. MONITOR
   Watch workflow (5-10 min)
   
4. VERIFY
   • Test in Salesforce org
   • Check git log
   
5. COMMUNICATE
   Post in #deployments: "Rollback complete"
```

---

### Procedure C: Rollback from GitHub Artifact

**Use when:** Local backup not available

#### Step 1: Download Backup

```
1. GitHub → Your Repo → Actions
2. Find deployment workflow run
3. Scroll to "Artifacts" section
4. Download: salesforce-backup-[SHA].zip
5. Extract to: backups/restored-[timestamp]/
```

#### Step 2: Verify Backup Contents

```bash
cd backups/restored-20260419/
ls -la

# Should contain:
# - backup-info.txt
# - force-app/ directory
# - metadata files
```

#### Step 3: Use Standard Rollback Procedure

Follow **Procedure A** using the restored backup directory.

---

## Post-Rollback Verification

### Immediate Verification (5 minutes)

```
□ Git branch shows revert commit
□ Salesforce org accessible
□ Affected components restored to old state
□ Critical functionality working
□ No new errors in logs
□ Audit log created in rollbacks/ directory
```

### Functional Testing (15 minutes)

**Test affected features:**

```
□ [Feature 1]: _____________________ ✓ / ✗
□ [Feature 2]: _____________________ ✓ / ✗
□ [Feature 3]: _____________________ ✓ / ✗
□ [Critical Path]: _________________ ✓ / ✗
```

**If tests fail:**
1. Check audit log for deployment errors
2. Verify correct backup was used
3. Verify Git and Salesforce are synchronized
4. Consider additional remediation

### Communication (Post-Rollback)

**Send update to team:**

```
✅ ROLLBACK COMPLETED

Issue: [Brief description]
Status: RESOLVED
Commit Reverted: [SHA]
Org: [targetOrg]
Duration: [X minutes]
Verified by: [@your-name]
Audit Log: rollbacks/complete-rollback-[timestamp].log

Next Steps:
- Root cause analysis scheduled
- Fix development in progress
- Re-deployment planned for [date/time]

Questions? Contact @devops-team
```

### Documentation (Within 24 hours)

```
□ Incident report created
□ Root cause identified
□ Rollback audit log reviewed
□ Lessons learned documented
□ Process improvements identified
□ Knowledge base updated
```

---

## Troubleshooting

### Issue: Workflow Shows "Skipped"

**Cause:** Job conditions not met

**Solution:**
```bash
# Verify workflow file has correct conditions
# Should show:
if: github.event_name == 'workflow_dispatch'

# If missing, update workflow and push
```

---

### Issue: Backup Directory Not Found

**Symptoms:**
```
❌ ERROR: Backup directory not found!
```

**Solutions:**

**Option 1: Use GitHub Artifact**
```
1. Actions → Find deployment run
2. Download artifact
3. Extract to backups/
4. Retry rollback
```

**Option 2: Manual Backup Retrieval**
```bash
# If backup exists in org
sf project retrieve start \
  --manifest changed-sources/package/package.xml \
  --target-org targetOrg \
  --output-dir backups/manual-backup-$(date +%Y%m%d)
```

---

### Issue: Git Revert Has Conflicts

**Symptoms:**
```
❌ Revert failed due to conflicts!
```

**Solutions:**

**Option 1: Manual Resolution**
```bash
# Clone repo locally
git clone <repo-url>
cd <repo>

# Attempt revert
git revert <commit-sha>

# Resolve conflicts
git status
# Edit conflicting files
git add .
git revert --continue

# Push
git push origin <branch>
```

**Option 2: Recreate from Backup**
```bash
# Copy files from backup to repo
cp -r backups/20260419-143000/force-app/ ./force-app/

# Commit as rollback
git add force-app/
git commit -m "Rollback: Manual restoration from backup"
git push
```

---

### Issue: Salesforce Deployment Failed

**Symptoms:**
```
❌ Salesforce restoration failed!
Error: Component failures
```

**Root Causes & Solutions:**

**1. Missing Dependencies**
```
Error: Required field XYZ not found

Solution:
- Verify backup completeness
- Retrieve full org backup
- Deploy dependencies first
```

**2. Validation Rules**
```
Error: Validation rule failed

Solution:
- Deactivate validation rules
- Deploy backup
- Reactivate validation rules
```

**3. Test Failures**
```
Error: Tests failed

Solution:
- Re-run with skip_tests: true
- Fix tests after rollback
- Or deploy with RunLocalTests
```

---

### Issue: Rollback Successful but Issues Persist

**Possible Causes:**

**1. Wrong Backup Used**
```
□ Verify backup timestamp
□ Check backup-info.txt
□ Confirm deployment ID matches
```

**2. Issue Not Caused by Recent Deployment**
```
□ Check when issue first appeared
□ Review deployment history
□ Investigate other recent changes
```

**3. Cached Data**
```
□ Clear browser cache
□ Clear Salesforce cache
□ Refresh metadata
```

**4. Partial Rollback**
```
□ Verify all components restored
□ Check deployment logs
□ Re-run rollback if needed
```

---

## Emergency Contacts

### Primary Contacts

| Role | Name | Slack | Email | Phone |
|------|------|-------|-------|-------|
| DevOps Lead | [Name] | @handle | email@company.com | +1-XXX-XXX-XXXX |
| Salesforce Admin | [Name] | @handle | email@company.com | +1-XXX-XXX-XXXX |
| Engineering Manager | [Name] | @handle | email@company.com | +1-XXX-XXX-XXXX |

### Escalation Path

```
Level 1: DevOps Team Member (0-15 min)
   ↓ (if unresolved)
Level 2: DevOps Lead (15-30 min)
   ↓ (if unresolved)
Level 3: Engineering Manager (30-60 min)
   ↓ (if critical)
Level 4: CTO / VP Engineering
```

### Communication Channels

- **Primary:** `#deployments` Slack channel
- **Urgent:** `#incidents` Slack channel
- **Email:** devops@company.com
- **On-Call:** PagerDuty (if configured)

---

## Example Scenarios

### Scenario 1: Test Failures After Deployment

**Situation:**
- Deployed commit `abc1234` to production
- Code coverage dropped to 78% (below 85% threshold)
- Several test classes failing

**Rollback Decision:** YES - Critical (blocks future deployments)

**Steps:**
```
1. Identify: Commit abc1234, Backup backups/20260419-120000
2. Trigger: Complete Rollback (create branch)
3. Monitor: 10 minutes
4. Verify: Tests passing after rollback
5. Fix: Update tests in new branch
6. Re-deploy: With passing tests
```

---

### Scenario 2: Critical Apex Class Error

**Situation:**
- Deployed new `OrderProcessor` class
- Production orders failing
- Error: "Null pointer exception in OrderProcessor.calculate()"
- 500+ users impacted

**Rollback Decision:** YES - Emergency

**Steps:**
```
1. IMMEDIATE: Trigger Emergency Rollback (no branch)
   • Commit: xyz7890
   • Backup: Latest
   • Create Branch: NO
   • Skip Tests: YES
   
2. MONITOR: 5 minutes
3. VERIFY: Orders processing again
4. COMMUNICATE: All-hands Slack
5. FIX: Debug issue offline
6. RE-DEPLOY: After thorough testing
```

**Timeline:**
- Issue detected: 2:00 PM
- Rollback started: 2:05 PM
- Rollback complete: 2:12 PM
- Service restored: 2:15 PM
- Total downtime: 15 minutes

---

### Scenario 3: Profile Changes Broke Permissions

**Situation:**
- Updated Admin profile with new field permissions
- Sales users can no longer access critical fields
- Only 20 users affected, workaround available

**Rollback Decision:** MAYBE - Evaluate

**Evaluation:**
```
Quick fix possible? NO (permissions complex)
Workaround available? YES (manual permission grant)
Users affected? 20 (manageable)
Business impact? MEDIUM (can work around)

Decision: Apply workaround, fix properly in next release
```

**Actions:**
```
1. Apply workaround: Manual permission grant
2. Schedule proper fix: Next sprint
3. No rollback needed
```

---

### Scenario 4: Wrong Files Deployed

**Situation:**
- Meant to deploy AccountHandler.cls
- Accidentally deployed ContactHandler.cls as well
- ContactHandler has unreviewed code

**Rollback Decision:** YES (partial)

**Steps:**
```
1. Use Salesforce-Only Rollback
2. Restore ContactHandler from backup
3. Keep AccountHandler (good code)
4. Manual selective restoration:
   
   sf project deploy start \
     --metadata ApexClass:ContactHandler \
     --source-dir backups/20260419-120000
```

---

## Rollback Metrics & KPIs

Track these metrics to improve rollback process:

### Performance Metrics

```
□ Time to detect issue: _____ minutes
□ Time to decide rollback: _____ minutes
□ Rollback execution time: _____ minutes
□ Total incident duration: _____ minutes
□ Target: < 30 minutes total
```

### Success Metrics

```
□ Rollback successful: YES / NO
□ Services restored: YES / NO
□ Data integrity maintained: YES / NO
□ Audit trail complete: YES / NO
```

### Improvement Areas

```
□ What went well?
□ What could be improved?
□ Process gaps identified?
□ Tool improvements needed?
```

---

## Appendix

### A. Useful Commands

**Check Deployment History:**
```bash
# Git commits
git log --oneline --graph --decorate -10

# Recent deployments in Salesforce
# Setup → Deployment Status
```

**List Available Backups:**
```bash
ls -lht backups/
```

**Download Artifact via GitHub CLI:**
```bash
gh run download <run-id> -n salesforce-backup-<sha>
```

**Manual Git Revert:**
```bash
git revert <commit-sha>
git push origin <branch>
```

**Check Workflow Status:**
```bash
gh run list --workflow="rollback_complete.yml"
gh run view <run-id>
```

---

### B. Backup Retention Policy

| Backup Type | Retention | Location |
|-------------|-----------|----------|
| GitHub Artifacts | 30 days | GitHub Actions |
| Local Backups | 90 days | backups/ directory |
| Critical Backups | 1 year | Long-term storage |
| Audit Logs | Permanent | rollbacks/ + git |

**Archive old backups:**
```bash
# Move backups older than 90 days to archive
find backups/ -type d -mtime +90 -exec mv {} archive/ \;
```

---

### C. Testing Rollback Process

**Test rollback quarterly:**

```
1. Create test deployment with known issue
2. Document deployment time and commit
3. Execute rollback following this playbook
4. Measure time and success
5. Update playbook with learnings
6. Train new team members
```

---

### D. Rollback Checklist Template

```
ROLLBACK EXECUTION CHECKLIST

□ Pre-Rollback
  □ Issue verified and documented
  □ Commit SHA identified: __________
  □ Backup verified: __________
  □ Team notified
  □ Stakeholders informed (if critical)

□ During Rollback
  □ Workflow triggered
  □ Monitoring active
  □ Communication ongoing
  □ Progress logged

□ Post-Rollback
  □ Git verified
  □ Salesforce verified
  □ Functionality tested
  □ Team updated
  □ Audit log reviewed
  □ Incident report created

□ Follow-Up
  □ Root cause identified
  □ Fix developed
  □ Re-deployment planned
  □ Lessons learned documented
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-20 | Initial playbook creation | Claude |

---

## Feedback & Improvements

This playbook is a living document. Submit improvements via:
- **Pull Request:** Add to docs/ROLLBACK-PLAYBOOK.md
- **Issue:** Create GitHub issue with label `runbook-improvement`
- **Slack:** Post in `#devops` channel

---

**Remember:** Rollbacks are a safety mechanism, not a failure. Use them confidently when needed!
