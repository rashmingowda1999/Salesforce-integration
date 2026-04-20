# 🚨 EMERGENCY ROLLBACK QUICK REFERENCE

**Print this and keep it handy!**

---

## 🔥 EMERGENCY ROLLBACK (5 MINUTES)

### 1. IDENTIFY (30 seconds)
```bash
git log -1 --oneline           # Copy commit SHA
ls -lht backups/ | head -1      # Find latest backup
```

### 2. TRIGGER (1 minute)
```
GitHub → Actions → "Complete Rollback (Git + Salesforce)"
→ Run workflow

Fill in:
- Commit SHA: [from step 1]
- Backup: backups/[timestamp]
- Org: targetOrg
- Create Branch: NO (emergency mode)
- Skip Tests: YES
```

### 3. MONITOR (3-5 minutes)
```
Watch workflow progress
Wait for ✅ green checkmark
```

### 4. VERIFY (2 minutes)
```
□ Test in Salesforce org
□ Check git log
□ Post in #deployments
```

---

## 📞 EMERGENCY CONTACTS

| Contact | Slack |
|---------|-------|
| DevOps Lead | @devops-lead |
| Salesforce Admin | @sf-admin |
| Manager | @eng-manager |

**Channels:**
- `#deployments` (normal)
- `#incidents` (critical)

---

## 🎯 DECISION TREE

```
Is production down or unusable?
├─ YES → EMERGENCY ROLLBACK (no branch)
└─ NO → Can you fix in < 15 min?
    ├─ YES → Fix forward
    └─ NO → STANDARD ROLLBACK (with branch)
```

---

## 📋 STANDARD ROLLBACK (15 MINUTES)

Same as emergency, but:
- **Create Branch:** YES
- **Skip Tests:** NO (if time permits)
- Review PR before merging

---

## 🔍 FIND BACKUP

**GitHub Artifacts:**
```
Actions → Find deployment run → Artifacts section
Download: salesforce-backup-[SHA].zip
```

**Local:**
```
ls -lht backups/
```

---

## ⚡ COMMON ISSUES

### Backup Not Found
```
→ Download from GitHub Artifacts
→ Extract to backups/
→ Retry
```

### Workflow Skipped
```
→ Check workflow file has:
  if: github.event_name == 'workflow_dispatch'
```

### Tests Failing
```
→ Re-run with Skip Tests: YES
→ Fix tests after rollback
```

---

## 📝 QUICK COMMUNICATION TEMPLATE

```
🚨 ROLLBACK IN PROGRESS

Issue: [Brief description]
Commit: [SHA]  
Org: targetOrg
ETA: 15 minutes
By: @[your-name]
```

**After:**
```
✅ ROLLBACK COMPLETE

Duration: [X] minutes
Status: Service restored
Audit: rollbacks/complete-rollback-[timestamp].log
```

---

## 🛠️ USEFUL COMMANDS

```bash
# View recent commits
git log --oneline -5

# List backups
ls -lht backups/

# Check workflow status
gh run list

# Manual revert
git revert [commit-sha]
git push
```

---

## 📖 FULL PLAYBOOK

For detailed procedures, see:
**`docs/ROLLBACK-PLAYBOOK.md`**

---

**Last Updated:** 2026-04-20  
**Version:** 1.0
