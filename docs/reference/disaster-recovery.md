# Disaster Recovery Guide

This guide provides step-by-step recovery procedures for various failure scenarios in the claude-todo system. All procedures are designed to restore your task management data with minimal loss.

---

## Overview

The claude-todo backup system implements a **two-tier architecture** for comprehensive data protection:

| Tier | Location | Purpose | Trigger |
|------|----------|---------|---------|
| **Tier 1 (Operational)** | `.claude/.backups/` | Atomic write rollback | Automatic on every write |
| **Tier 2 (Recovery)** | `.claude/backups/{type}/` | Point-in-time snapshots | Manual, scheduled, or pre-operation |

This separation provides **defense in depth**: Tier 1 protects against individual operation failures, while Tier 2 enables full system recovery.

---

## Backup Tiers Quick Reference

### Tier 1: Operational Backups

Located in `.claude/.backups/`, these are numbered backups created automatically before every write operation:

```
.claude/.backups/
├── todo.json.1          # Most recent (newest)
├── todo.json.2
├── todo.json.3          # Oldest
├── todo-config.json.1
└── ...
```

- **Retention**: Last 10 backups per file (configurable)
- **Use Case**: Quick rollback from recent write failures
- **Recovery**: Manual copy (`cp .claude/.backups/todo.json.1 .claude/todo.json`)

### Tier 2: Typed Backups

Located in `.claude/backups/{type}/`, these are structured backups with metadata:

```
.claude/backups/
├── snapshot/            # Manual user snapshots
├── safety/              # Pre-destructive operation backups
├── archive/             # Pre-archive operation backups
└── migration/           # Pre-schema migration backups (never deleted)
```

Each backup directory contains:
- `metadata.json` - Backup info, checksums, timestamps
- `todo.json` - Active tasks
- `todo-archive.json` - Archived tasks
- `todo-config.json` - Configuration
- `todo-log.json` - Audit log

---

## Recovery Scenarios

### Scenario 1: Corrupted todo.json

The most common failure is a corrupted or malformed `todo.json` file, typically caused by interrupted writes, manual editing errors, or disk issues.

#### Symptoms

- Commands fail with: `[ERROR] Invalid JSON in .claude/todo.json`
- `jq` parsing errors when viewing the file
- `claude-todo list` returns JSON syntax error
- Validation shows: `JSON syntax error at line X`

#### Diagnosis

```bash
# Step 1: Check if JSON is parseable
jq empty .claude/todo.json
# If error, JSON is corrupted

# Step 2: Identify corruption location
jq . .claude/todo.json 2>&1 | head -5
# Shows line number and character position

# Step 3: Check file integrity
claude-todo validate --verbose
```

#### Recovery Steps

**Option A: Restore from Tier 1 (fastest, for recent corruption)**

```bash
# 1. List available Tier 1 backups
ls -la .claude/.backups/todo.json.*

# 2. Validate backup is intact
jq empty .claude/.backups/todo.json.1

# 3. Create safety copy of corrupted file
cp .claude/todo.json .claude/todo.json.corrupted

# 4. Restore from most recent backup
cp .claude/.backups/todo.json.1 .claude/todo.json

# 5. Verify restoration
claude-todo validate
claude-todo list
```

**Option B: Restore from Tier 2 (for older or comprehensive recovery)**

```bash
# 1. List available Tier 2 backups
claude-todo backup --list

# 2. Verify backup integrity
jq empty .claude/backups/snapshot/snapshot_20251213_120000/todo.json

# 3. Restore from selected backup
claude-todo restore .claude/backups/snapshot/snapshot_20251213_120000

# 4. Verify restoration
claude-todo validate
```

**Option C: Automated fix (for minor issues)**

```bash
# Try automated repair
claude-todo validate --fix

# If successful, verify
claude-todo list
```

#### Verification

```bash
# Confirm all checks pass
claude-todo validate

# Verify task count matches expectations
claude-todo stats

# Check recent log entries
claude-todo log --limit 10
```

#### Prevention

- Always use CLI commands instead of manual file edits
- Enable automatic backups (default behavior)
- Run `claude-todo validate` after any manual modifications
- Keep `maxOperationalBackups` at 10 or higher

---

### Scenario 2: Accidental Task Deletion

Tasks were inadvertently deleted through bulk operations, incorrect filtering, or user error.

#### Symptoms

- Expected tasks missing from `claude-todo list`
- Task count lower than expected in `claude-todo stats`
- Recent log shows unexpected `delete` or `complete` operations

#### Diagnosis

```bash
# Step 1: Check current task count
claude-todo stats

# Step 2: Review recent operations
claude-todo log --limit 20

# Step 3: Look for the missing task in archive
claude-todo list --include-archive | grep "task-title"

# Step 4: Check if task was completed (not deleted)
jq '.tasks[] | select(.title | contains("task-name"))' .claude/todo-archive.json
```

#### Recovery Steps

**Option A: Restore from Tier 2 backup (recommended)**

```bash
# 1. Find backup from before deletion
claude-todo backup --list
# Look for timestamp before the deletion occurred

# 2. Preview backup contents
jq '.tasks | length' .claude/backups/snapshot/snapshot_YYYYMMDD_HHMMSS/todo.json
jq '.tasks[].title' .claude/backups/snapshot/snapshot_YYYYMMDD_HHMMSS/todo.json

# 3. Create current state backup
claude-todo backup --name "before-restore"

# 4. Restore specific file (tasks only, preserve config)
claude-todo restore .claude/backups/snapshot/snapshot_YYYYMMDD_HHMMSS --file todo.json

# 5. Verify task restored
claude-todo list
claude-todo find "task-name"
```

**Option B: Selective extraction from backup**

If you only need specific tasks without full restore:

```bash
# 1. Extract task from backup
jq '.tasks[] | select(.title | contains("task-name"))' \
  .claude/backups/snapshot/snapshot_YYYYMMDD_HHMMSS/todo.json > /tmp/task.json

# 2. Get task title
TITLE=$(jq -r '.title' /tmp/task.json)

# 3. Recreate task with original details
claude-todo add "$TITLE" \
  --priority $(jq -r '.priority' /tmp/task.json) \
  --status $(jq -r '.status' /tmp/task.json)
```

**Option C: Restore from Tier 1 (for very recent deletion)**

```bash
# If deletion just happened
cp .claude/.backups/todo.json.1 .claude/todo.json
claude-todo validate
```

#### Verification

```bash
# Confirm task is present
claude-todo find "task-name"

# Verify task count
claude-todo stats

# Check task details
claude-todo show TASK_ID
```

#### Prevention

- Create named backups before bulk operations: `claude-todo backup --name "before-cleanup"`
- Use `--dry-run` flags when available
- Review operations in log after bulk changes

---

### Scenario 3: Schema Migration Failure

A schema migration failed partway through, leaving data in an inconsistent state.

#### Symptoms

- Error message: `Schema version mismatch`
- Commands fail with: `Incompatible schema version`
- `claude-todo migrate status` shows version mismatch
- Validation errors about missing or invalid fields

#### Diagnosis

```bash
# Step 1: Check current schema version
jq '.version' .claude/todo.json
jq '.version' .claude/todo-config.json

# Step 2: Check expected version
claude-todo migrate status

# Step 3: Identify migration backups
ls -la .claude/backups/migration/
```

#### Recovery Steps

**Option A: Restore from migration backup (recommended)**

Migration backups are created automatically before every schema migration and are **never automatically deleted**.

```bash
# 1. List migration backups
ls -la .claude/backups/migration/
# Example: migration_v2.1.0_to_v2.2.0_20251213_120000/

# 2. Find the pre-migration backup
# Look for the version you want to restore to

# 3. Restore from migration backup
claude-todo restore .claude/backups/migration/migration_v2.1.0_to_v2.2.0_20251213_120000

# 4. Verify restoration
claude-todo validate

# 5. Check version is correct
jq '.version' .claude/todo.json

# 6. Retry migration if desired
claude-todo migrate run --auto
```

**Option B: Repair current schema**

```bash
# 1. Create safety backup
claude-todo backup --name "before-repair"

# 2. Attempt automated repair
claude-todo migrate repair --auto

# 3. If repair fails, try fix validation
claude-todo validate --fix

# 4. Verify
claude-todo validate
```

**Option C: Manual schema fix**

For advanced users when automated tools fail:

```bash
# 1. Backup current state
cp .claude/todo.json .claude/todo.json.backup

# 2. Update version field manually
jq '.version = "2.2.0"' .claude/todo.json > .claude/todo.json.tmp
mv .claude/todo.json.tmp .claude/todo.json

# 3. Add missing required fields
claude-todo validate --fix

# 4. Verify
claude-todo validate
```

#### Verification

```bash
# Confirm schema version is correct
claude-todo migrate status

# Run full validation
claude-todo validate --verbose

# Test core functionality
claude-todo list
claude-todo stats
```

#### Prevention

- Always run `claude-todo migrate run --auto` for automated migrations
- Never manually edit version fields
- Keep migration backups indefinitely (default behavior)
- Test migrations in a copy of the project first

---

### Scenario 4: Complete Data Loss

All `.claude/` data files are missing, corrupted beyond repair, or accidentally deleted.

#### Symptoms

- `.claude/` directory is empty or missing
- All `todo*.json` files are gone
- `claude-todo list` shows no tasks or fails
- No Tier 1 backups available

#### Diagnosis

```bash
# Step 1: Check if .claude directory exists
ls -la .claude/

# Step 2: Check for any remaining files
find .claude/ -name "*.json" 2>/dev/null

# Step 3: Check for Tier 2 backups
ls -la .claude/backups/ 2>/dev/null
```

#### Recovery Steps

**Option A: Restore from Tier 2 backup**

```bash
# 1. Find available backups
# Check standard location
ls -la .claude/backups/snapshot/
ls -la .claude/backups/migration/

# 2. If backup directory exists, list backups
claude-todo backup --list

# 3. Find most recent viable backup
LATEST=$(ls -td .claude/backups/snapshot/snapshot_* 2>/dev/null | head -1)

# 4. Restore full system
claude-todo restore "$LATEST" --force

# 5. Verify restoration
claude-todo validate
claude-todo list
claude-todo stats
```

**Option B: Restore from external backup**

If you have backups stored externally (cloud, external drive):

```bash
# 1. Copy backup to local system
cp /path/to/external/backup_20251213_120000.tar.gz .claude/backups/snapshot/

# 2. Extract if compressed
cd .claude/backups/snapshot/
tar -xzf backup_20251213_120000.tar.gz

# 3. Restore
claude-todo restore .claude/backups/snapshot/backup_20251213_120000 --force

# 4. Verify
claude-todo validate
```

**Option C: Reinitialize with fresh system**

If no backups are available:

```bash
# 1. Save any recoverable data
mkdir -p ~/todo-recovery
cp .claude/*.json ~/todo-recovery/ 2>/dev/null || true

# 2. Remove corrupted directory
mv .claude .claude.corrupted

# 3. Reinitialize fresh system
claude-todo init

# 4. Manually recreate critical tasks
# Extract any readable task titles from corrupted files
jq -r '.tasks[]?.title // empty' ~/todo-recovery/todo.json 2>/dev/null | while read -r title; do
  [[ -n "$title" ]] && claude-todo add "$title"
done
```

#### Verification

```bash
# Comprehensive verification
claude-todo validate --verbose
claude-todo list
claude-todo stats
claude-todo session status
```

#### Prevention

- Configure external backup destination: `claude-todo backup --compress --destination ~/Dropbox/claude-todo`
- Schedule regular backups via cron
- Keep multiple generations of backups
- Test restore procedures periodically

---

### Scenario 5: Backup Corruption

Backup files themselves are corrupted, making restoration impossible from that backup.

#### Symptoms

- `claude-todo restore` fails with checksum mismatch
- `jq` cannot parse backup files
- Metadata.json shows verification errors
- Compressed tarballs fail to extract

#### Diagnosis

```bash
# Step 1: Verify backup integrity
claude-todo backup verify .claude/backups/snapshot/snapshot_20251213_120000

# Step 2: Test JSON parsing
jq empty .claude/backups/snapshot/snapshot_20251213_120000/todo.json

# Step 3: Check metadata checksums
jq '.checksums' .claude/backups/snapshot/snapshot_20251213_120000/metadata.json

# Step 4: Recalculate checksum and compare
sha256sum .claude/backups/snapshot/snapshot_20251213_120000/todo.json
```

#### Recovery Steps

**Option A: Use different backup**

```bash
# 1. List all available backups
claude-todo backup --list

# 2. Test each backup until finding valid one
for backup in .claude/backups/snapshot/snapshot_*; do
  echo "Testing: $backup"
  if jq empty "$backup/todo.json" 2>/dev/null; then
    echo "Valid: $backup"
    break
  fi
done

# 3. Restore from valid backup
claude-todo restore .claude/backups/snapshot/snapshot_VALID --force
```

**Option B: Skip checksum verification (use with caution)**

If the data appears valid but checksums don't match:

```bash
# 1. Manually verify backup data looks correct
jq '.tasks | length' .claude/backups/snapshot/snapshot_20251213_120000/todo.json
jq '.tasks[0]' .claude/backups/snapshot/snapshot_20251213_120000/todo.json

# 2. Manual restore (bypassing checksum)
claude-todo backup --name "before-manual-restore"
cp .claude/backups/snapshot/snapshot_20251213_120000/*.json .claude/

# 3. Validate restored files
claude-todo validate --fix

# 4. Verify
claude-todo list
```

**Option C: Partial recovery from corrupted backup**

```bash
# 1. Try to extract what's readable
# Some JSON files may be valid even if others are not
for file in todo.json todo-archive.json todo-config.json; do
  if jq empty ".claude/backups/snapshot/snapshot_20251213_120000/$file" 2>/dev/null; then
    echo "Extracting valid file: $file"
    cp ".claude/backups/snapshot/snapshot_20251213_120000/$file" ".claude/$file"
  fi
done

# 2. Initialize missing files
claude-todo validate --fix

# 3. Verify partial recovery
claude-todo validate
```

**Option D: Recover from compressed backup**

```bash
# 1. Test tarball integrity
tar -tzf .claude/backups/snapshot/snapshot_20251213_120000.tar.gz

# 2. If listing works, extract
mkdir -p /tmp/backup-test
tar -xzf .claude/backups/snapshot/snapshot_20251213_120000.tar.gz -C /tmp/backup-test

# 3. Verify extracted files
jq empty /tmp/backup-test/*.json

# 4. Copy valid files
cp /tmp/backup-test/*.json .claude/

# 5. Validate
claude-todo validate
```

#### Verification

```bash
# After any recovery
claude-todo validate --verbose
claude-todo list
claude-todo stats
```

#### Prevention

- Run `claude-todo backup verify` periodically
- Keep multiple backup copies (default: 5 snapshots)
- Use `--compress` for long-term archival
- Store backups on different physical media
- Test restore procedures quarterly

---

## Recovery Commands Reference

### Backup Management

| Command | Description |
|---------|-------------|
| `claude-todo backup` | Create manual snapshot backup |
| `claude-todo backup --name NAME` | Create named snapshot for context |
| `claude-todo backup --list` | List all available Tier 2 backups |
| `claude-todo backup --list --type snapshot` | List only snapshot backups |
| `claude-todo backup --compress` | Create compressed tarball backup |
| `claude-todo backup verify BACKUP_PATH` | Verify backup integrity |

### Restoration

| Command | Description |
|---------|-------------|
| `claude-todo restore BACKUP_PATH` | Restore from backup with confirmation |
| `claude-todo restore BACKUP_PATH --force` | Restore without confirmation |
| `claude-todo restore BACKUP_PATH --file FILE` | Restore only specific file |
| `claude-todo restore BACKUP_PATH --verbose` | Show detailed restore progress |

### Validation and Repair

| Command | Description |
|---------|-------------|
| `claude-todo validate` | Check file integrity and schema |
| `claude-todo validate --verbose` | Detailed validation output |
| `claude-todo validate --fix` | Attempt automated repairs |
| `claude-todo migrate status` | Check schema version status |
| `claude-todo migrate run --auto` | Run pending migrations |
| `claude-todo migrate repair --auto` | Repair schema structure |

### Tier 1 Manual Recovery

| Command | Description |
|---------|-------------|
| `ls -la .claude/.backups/` | List Tier 1 operational backups |
| `cp .claude/.backups/todo.json.1 .claude/todo.json` | Manual restore from Tier 1 |
| `jq empty .claude/.backups/todo.json.1` | Validate Tier 1 backup |

### Diagnosis

| Command | Description |
|---------|-------------|
| `jq empty .claude/todo.json` | Test JSON syntax |
| `jq '.version' .claude/todo.json` | Check schema version |
| `claude-todo stats` | View task counts |
| `claude-todo log --limit 20` | View recent operations |

---

## Prevention Best Practices

### Backup Schedule

| Scenario | Frequency | Method |
|----------|-----------|--------|
| Active development | Before each session | `claude-todo backup --name "session-start"` |
| Daily operations | Once per day | Automated cron with `--compress` |
| Before bulk changes | Immediately before | `claude-todo backup --name "before-X"` |
| Long-term archival | Weekly/monthly | `--compress --destination external` |

### Backup Verification

```bash
# Weekly verification script
#!/usr/bin/env bash
for backup in .claude/backups/snapshot/snapshot_*; do
  if [[ -d "$backup" ]]; then
    echo "Verifying: $backup"
    for file in "$backup"/*.json; do
      if ! jq empty "$file" 2>/dev/null; then
        echo "CORRUPT: $file"
      fi
    done
  fi
done
```

### Configuration Recommendations

```bash
# Set appropriate retention
claude-todo config set backup.maxSnapshots 10
claude-todo config set backup.maxSafetyBackups 5
claude-todo config set backup.safetyRetentionDays 14

# Verify settings
claude-todo config get backup
```

### External Backup Strategy

```bash
# Daily external backup (add to cron)
0 2 * * * cd /path/to/project && claude-todo backup --compress --destination ~/Dropbox/backups/claude-todo/

# Monthly offsite backup
0 3 1 * * cd /path/to/project && claude-todo backup --compress --name "monthly-$(date +%Y%m)" --destination /mnt/external/
```

---

## Troubleshooting

### Common Issues During Recovery

#### Issue: "Backup source does not exist"

**Cause**: Incorrect path or backup was deleted by retention policy.

**Solution**:
```bash
# Verify correct path
ls -la .claude/backups/snapshot/

# List available backups
claude-todo backup --list

# Check backup directory exists
ls -la .claude/backups/
```

#### Issue: "Checksum verification failed"

**Cause**: Backup file was modified or corrupted after creation.

**Solution**:
```bash
# Recalculate and compare checksums
sha256sum .claude/backups/snapshot/snapshot_*/todo.json
jq '.checksums."todo.json"' .claude/backups/snapshot/snapshot_*/metadata.json

# If mismatch but data looks valid, manual restore:
cp .claude/backups/snapshot/snapshot_VALID/*.json .claude/
claude-todo validate --fix
```

#### Issue: "Permission denied" during restore

**Cause**: File or directory permissions are too restrictive.

**Solution**:
```bash
# Fix directory permissions
chmod 755 .claude/
chmod 644 .claude/*.json

# Fix backup directory permissions
chmod 755 .claude/backups/
chmod 755 .claude/backups/snapshot/
chmod 644 .claude/backups/snapshot/*/*.json
```

#### Issue: "Restore rolled back" after failure

**Cause**: Post-restore validation detected issues.

**Solution**:
```bash
# Check what caused the rollback
claude-todo restore BACKUP_PATH --verbose

# If backup has issues, use different backup
claude-todo backup --list

# Check safety backup created during restore attempt
ls -la .claude/backups/safety/pre-restore_*
```

#### Issue: No backups available

**Cause**: Backups disabled, retention deleted them, or first-time use.

**Solution**:
```bash
# Check if backups are enabled
claude-todo config get backup.enabled

# Check Tier 1 backups (always created)
ls -la .claude/.backups/

# If all else fails, reinitialize
claude-todo init
```

---

## Related Documentation

- [Troubleshooting Guide](troubleshooting.md) - General troubleshooting procedures
- [Backup Command Reference](../commands/backup.md) - Detailed backup command documentation
- [Restore Command Reference](../commands/restore.md) - Detailed restore command documentation
- [Validate Command Reference](../commands/validate.md) - Validation and repair procedures
- [Backup System Specification](../specs/BACKUP-SYSTEM-SPEC.md) - Technical specification

---

## Emergency Contacts

If automated recovery fails:

1. **Save current state**: `cp -r .claude ~/claude-emergency-backup/`
2. **Collect diagnostics**: `claude-todo validate --verbose 2>&1 > ~/diagnostic.log`
3. **Check logs**: `claude-todo log --limit 50 > ~/recent-operations.log`
4. **Report issue**: Include diagnostic output and steps to reproduce

---

**Last Updated**: 2025-12-22
