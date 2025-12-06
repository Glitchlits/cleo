# Suggested Commands

## Development Commands

### Installation and Setup
```bash
# Global installation
./install.sh

# Upgrade existing installation
./install.sh --upgrade

# Source shell config after installation
source ~/.bashrc  # or ~/.zshrc

# Initialize project
claude-todo init
```

### Task Management
```bash
# Add new task
claude-todo add "Task description"
claude-todo add "Task description" --status pending --priority high

# Complete task
claude-todo complete <task-id>
claude-todo complete <task-id> --skip-archive

# List tasks
claude-todo list
claude-todo list --status pending
claude-todo list --format json
```

### Archival and Maintenance
```bash
# Archive completed tasks (automatic based on policy)
claude-todo archive

# Preview what would be archived
claude-todo archive --dry-run

# Force archive (respects preserveRecentCount)
claude-todo archive --force

# Archive ALL completed tasks (ignores preserve)
claude-todo archive --all
```

### Validation and Health Checks
```bash
# Validate all JSON files
claude-todo validate

# Validate with automatic fixes
claude-todo validate --fix
```

### Statistics and Reporting
```bash
# Show statistics
claude-todo stats

# Statistics for specific period
claude-todo stats --period 30

# Export statistics as JSON
claude-todo stats --format json
```

### Backup and Restore
```bash
# Manual backup
claude-todo backup

# Backup to specific directory
claude-todo backup --destination /path/to/backup

# Restore from backup
claude-todo restore .claude/.backups/todo.json.1

# List available backups
ls -lh .claude/.backups/
```

### Help and Version
```bash
# Show all commands
claude-todo help

# Show command-specific help
claude-todo help archive
claude-todo help add

# Show version
claude-todo version
```

## Testing Commands

### Run Test Suite
```bash
# All tests
./tests/run-all-tests.sh

# Specific test category
./tests/test-validation.sh
./tests/test-archive.sh
./tests/test-add-task.sh
```

### Manual Testing
```bash
# Test schema validation
jq -e . schemas/todo.schema.json > /dev/null && echo "Valid JSON"

# Test jq processing
jq '.todos[] | select(.status == "completed")' .claude/todo.json

# Test atomic write
./lib/file-ops.sh atomic_write .claude/todo.json '{"todos":[]}'
```

## Utility Commands

### JSON Operations
```bash
# Pretty-print JSON
jq '.' .claude/todo.json

# Filter tasks by status
jq '.todos[] | select(.status == "pending")' .claude/todo.json

# Count tasks
jq '.todos | length' .claude/todo.json

# Extract specific field
jq -r '.todos[].content' .claude/todo.json
```

### File Operations
```bash
# Check file permissions
ls -l .claude/todo*.json

# Check file sizes
du -h .claude/*.json

# Find all todo files
find . -name "todo*.json" -type f
```

### Schema Validation (Manual)
```bash
# Using ajv (if installed)
ajv validate -s schemas/todo.schema.json -d .claude/todo.json

# Using jsonschema (Python, if installed)
jsonschema -i .claude/todo.json schemas/todo.schema.json

# Using jq (always available)
jq -e --arg schema "$(cat schemas/todo.schema.json)" 'validate($schema)' .claude/todo.json
```

### Log Analysis
```bash
# Recent operations
jq '.entries[-10:]' .claude/todo-log.json

# Filter by operation type
jq '.entries[] | select(.operation == "create")' .claude/todo-log.json

# Count operations
jq '.entries | group_by(.operation) | map({operation: .[0].operation, count: length})' .claude/todo-log.json
```

## Git Commands

### Version Control
```bash
# Initialize git (if not already)
git init

# Ensure .gitignore is correct
cat .gitignore  # Should include .claude/todo*.json

# Add system files
git add schemas/ templates/ scripts/ lib/ docs/ tests/
git commit -m "Add claude-todo system files"

# Track changes to templates/schemas
git add schemas/todo.schema.json
git commit -m "Update todo schema to v1.1.0"
```

## Environment Setup

### Configuration
```bash
# Set environment variables
export CLAUDE_TODO_ARCHIVE_DAYS=14
export CLAUDE_TODO_STRICT_MODE=true
export CLAUDE_TODO_LOG_LEVEL=debug

# Add to shell profile for persistence
echo 'export CLAUDE_TODO_ARCHIVE_DAYS=14' >> ~/.bashrc
```

### PATH Setup
```bash
# The installer automatically adds to PATH
# After installation, source your shell config:
source ~/.bashrc  # or ~/.zshrc

# Now can run directly
claude-todo add "New task"
claude-todo list
```

## Debugging Commands

### Verbose Mode
```bash
# Enable debug output
CLAUDE_TODO_LOG_LEVEL=debug claude-todo add "Test task"

# Trace script execution (for development)
bash -x ~/.claude-todo/scripts/archive.sh
```

### Validation Debugging
```bash
# Check schema structure
jq '.' schemas/todo.schema.json

# Validate specific task object
echo '{"id":"test","status":"pending","content":"Test","activeForm":"Testing"}' | \
  jq --slurpfile schema schemas/todo.schema.json 'validate($schema[0])'

# Check for duplicate IDs
jq '[.todos[].id] | group_by(.) | map(select(length > 1))' .claude/todo.json
```

## Performance Profiling

### Timing Operations
```bash
# Measure command execution time
time claude-todo archive

# Profile with detailed timing
TIMEFORMAT='Real: %R, User: %U, System: %S'
time claude-todo stats
```

### File Size Monitoring
```bash
# Check all file sizes
du -h .claude/*.json

# Monitor log growth
watch -n 60 'du -h .claude/todo-log.json'
```

## Quick Reference Aliases

### Recommended Shell Aliases (Optional)
```bash
# Add to ~/.bashrc or ~/.zshrc (claude-todo is already short)
alias ct='claude-todo'
alias ct-add='claude-todo add'
alias ct-list='claude-todo list'
alias ct-complete='claude-todo complete'
alias ct-archive='claude-todo archive'
alias ct-stats='claude-todo stats'
alias ct-validate='claude-todo validate'
```
