<!-- CLAUDE-TODO:START -->
## Task Management (claude-todo CLI)

Use the `claude-todo` CLI for **all** task operations. Never read or edit `.claude/*.json` files directly.

### Quick Reference
```bash
claude-todo list                    # View tasks
claude-todo add "Task title"        # Create task
claude-todo complete <task-id>      # Mark done
claude-todo focus set <task-id>     # Set focus (marks active)
claude-todo focus show              # Show current focus
claude-todo session start           # Start session
claude-todo session end             # End session
claude-todo validate                # Check file integrity
claude-todo archive                 # Archive completed tasks
claude-todo stats                   # Show statistics
claude-todo log --action <type>     # Add log entry
claude-todo help                    # All commands
```

### Session Protocol

**START** (beginning of work session):
```bash
claude-todo session start           # Logs session, shows context
claude-todo list                    # See pending tasks
claude-todo focus show              # Check last focus/notes
```

**WORK** (during session):
```bash
claude-todo focus set <task-id>     # Set focus (one task only)
claude-todo add "Subtask"           # Add new tasks as needed
claude-todo focus note "Progress"   # Update session note
claude-todo focus next "Next step"  # Set next action hint
```

**END** (before ending session):
```bash
claude-todo complete <task-id>      # Complete finished tasks
claude-todo archive                 # Clean up old completed tasks
claude-todo focus note "Status..."  # Save context for next session
claude-todo session end             # End session with optional note
```

### Task Commands
```bash
# Add task with options
claude-todo add "Task title" \
  --status pending \
  --priority high \
  --description "Details" \
  --labels "backend,api"

# Complete task
claude-todo complete <task-id>

# List with filters
claude-todo list --status pending --priority high
```

### Focus Commands
```bash
claude-todo focus set <task-id>     # Set focus + mark active
claude-todo focus clear             # Clear focus
claude-todo focus show              # Show focus state
claude-todo focus note "text"       # Set progress note
claude-todo focus next "action"     # Set next action
```

### Session Commands
```bash
claude-todo session start           # Start new session
claude-todo session end             # End session
claude-todo session end --note "..."# End with note
claude-todo session status          # Check session state
claude-todo session info            # Detailed info
```

### Status Values
- `pending` - Not yet started
- `active` - Currently working (limit: ONE)
- `blocked` - Waiting on dependency
- `done` - Completed

### Anti-Hallucination Rules

**CRITICAL - ALWAYS FOLLOW:**
- **CLI only** - Never read/edit `.claude/*.json` files directly
- **One active task** - Use `claude-todo focus set` (enforces single active)
- **Verify state** - Use `claude-todo list` to confirm, don't assume
- **Session discipline** - Start/end sessions properly
- **Archive is immutable** - Never try to modify archived tasks

### Aliases (installed automatically)
```bash
ct          # claude-todo
ct-add      # claude-todo add
ct-list     # claude-todo list
ct-done     # claude-todo complete
ct-focus    # claude-todo focus
```

### Error Recovery
```bash
claude-todo validate --fix          # Fix issues
claude-todo restore <backup>        # Restore from backup
ls .claude/.backups/                # List backups
```
<!-- CLAUDE-TODO:END -->
