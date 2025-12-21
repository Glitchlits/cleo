# Task Management Instructions (CLEO)

Use `cleo` CLI for **all** task operations. Single source of truth for persistent task tracking.

## Data Integrity Rules

| Rule | Reason |
|------|--------|
| **CLI only** - Never read/edit `.cleo/*.json` directly | Prevents staleness in multi-writer environment; ensures validation, checksums |
| **One active task** - Use `focus set` (enforces single active) | Prevents context confusion |
| **Verify state** - Use `list` before assuming task state | No stale data |
| **Session discipline** - Start/end sessions properly | Audit trail, recovery |
| **Validate after errors** - Run `validate` if something fails | Integrity check |

**Note**: Direct file reads can lead to stale data. CLI commands always read fresh data from disk.

## Command Reference

### Core Operations
```bash
cleo add "Task title" [OPTIONS]     # Create task
cleo update <id> [OPTIONS]          # Update task fields
cleo complete <id>                  # Mark done
cleo list [--status STATUS]         # View tasks
cleo show <id>                      # View single task details
```

### Focus & Session
```bash
cleo focus set <id>                 # Set active task (marks active)
cleo focus show                     # Show current focus
cleo focus clear                    # Clear focus
cleo focus note "Progress text"     # Set session progress note
cleo focus next "Next action"       # Set suggested next action
cleo session start                  # Begin work session
cleo session end                    # End session
cleo session status                 # Show session info
```

### Buffer Sync (Active Memory)
Sync persistent tasks with your agent's ephemeral memory (TodoWrite, Scratchpad, etc.):
```bash
cleo sync --inject                  # Push active tasks to agent memory (session start)
cleo sync --inject --focused-only   # Push only focused task
cleo sync --extract <file>          # Pull memory state back to CLEO (session end)
cleo sync --extract --dry-run <file> # Preview changes without applying
cleo sync --status                  # Show sync session state
```

### Analysis & Planning
```bash
cleo analyze                        # Task triage with leverage scoring
cleo analyze --json                 # Machine-readable triage output
cleo analyze --auto-focus           # Analyze and auto-set focus to top task
cleo dash                           # Project dashboard overview
cleo dash --compact                 # Single-line status summary
cleo next                           # Suggest next task (priority + deps)
cleo next --explain                 # Show suggestion reasoning
cleo phases                         # List phases with progress bars
cleo phases show <phase>            # Tasks in specific phase
cleo phases stats                   # Detailed phase statistics
cleo labels                         # List all labels with counts
cleo labels show <label>            # Tasks with specific label
cleo deps                           # Dependency overview
cleo deps <id>                      # Dependencies for task
cleo deps tree                      # Full dependency tree
cleo blockers                       # Show blocked tasks
cleo blockers analyze               # Critical path analysis
```

### Research
```bash
cleo research "query"               # Multi-source web research
cleo research --library NAME -t X   # Library docs via Context7
cleo research --reddit "topic" -s S # Reddit discussions via Tavily
cleo research --url URL [URL...]    # Extract from specific URLs
cleo research -d deep               # Deep research (15-25 sources)
cleo research --link-task T001      # Link research to task
```

**Aliases**: `dig` → `research`

**Output**: Creates `.cleo/research/research_[id].json` + `.md` files with citations.

### Task Inspection
```bash
cleo show <id>                      # Full task details view
cleo show <id> --history            # Include task history from log
cleo show <id> --related            # Show related tasks (same labels)
cleo show <id> --include-archive    # Search archive if not found
cleo show <id> --format json        # JSON output for scripting
```

### Task Search
```bash
cleo find <query>                   # Fuzzy search tasks by title/description
cleo find --id 37                   # Find tasks with ID prefix T37*
cleo find "exact title" --exact     # Exact match mode
cleo find "test" --status pending   # Filter by status
cleo find "api" --field title       # Search specific fields
cleo find "task" --format json      # JSON output for scripting
cleo find "old" --include-archive   # Include archived tasks
```

**Aliases**: `search` → `find`

### Hierarchy
```bash
# Create with hierarchy
cleo add "Epic" --type epic --size large
cleo add "Task" --parent T001 --size medium
cleo add "Subtask" --parent T002 --type subtask --size small

# List with hierarchy filters
cleo list --type epic               # Filter by type (epic|task|subtask)
cleo list --parent T001             # Tasks with specific parent
cleo list --children T001           # Direct children of task
cleo list --tree                    # Hierarchical tree view
```

**Constraints**: max depth 3 (epic→task→subtask), max 7 siblings per parent.

### Maintenance
```bash
cleo validate                       # Check file integrity
cleo validate --fix                 # Fix checksum issues
cleo exists <id>                    # Check if task ID exists (exit code 0/1)
cleo exists <id> --quiet            # Silent check for scripting
cleo exists <id> --include-archive  # Search archive too
cleo archive                        # Archive completed tasks
cleo stats                          # Show statistics
cleo backup                         # Create backup
cleo backup --list                  # List available backups
cleo restore [backup]               # Restore from backup
cleo migrate status                 # Check schema versions
cleo migrate run                    # Run schema migrations
cleo migrate-backups --detect       # List legacy backups
cleo migrate-backups --run          # Migrate to new taxonomy
cleo export --format todowrite      # Export to Agent Buffer format
cleo export --format csv            # Export to CSV
cleo init --update-docs             # Update instruction injection (idempotent)
cleo config show                    # View current configuration
cleo config set <key> <value>       # Update configuration
cleo config get <key>               # Get specific config value
cleo log                            # View recent audit log entries
cleo log --limit 20                 # Limit entries shown
cleo log --operation create         # Filter by operation type
cleo log --task T001                # Filter by task ID
```

### History & Analytics
```bash
cleo history                        # Recent completion timeline (30 days)
cleo history --days 7               # Last week's completions
cleo history --since 2025-12-01     # Since specific date
cleo history --format json          # JSON output for scripting
```

## Agent Instruction Integration

### Update Instructions
When CLEO is upgraded, update your project's agent instructions (e.g., CLAUDE.md, GEMINI.md):

```bash
# Update existing instructions to latest template
cleo init --update-docs
```

This command:
- Detects your agent type (Claude, Gemini, etc.)
- Replaces content between `<!-- CLEO-AGENT:START -->` and `<!-- CLEO-AGENT:END -->`
- Adds injection if not present
- Safe to run anytime (idempotent)

### When to Update
Run `init --update-docs` after:
- Upgrading CLEO to a new version
- Template improvements are released
- You notice outdated instructions in your agent docs

### Check Current Version
```bash
# Compare injection to installed template
diff <(sed -n '/CLEO-AGENT:START/,/CLEO-AGENT:END/p' CLAUDE.md) \
     ~/.cleo/templates/AGENT-INJECTION.md
```

## Task Options

### Add/Update Options
| Option | Values | Purpose |
|--------|--------|---------|
| `--status` | pending, active, blocked, done | Task state (use focus for active) |
| `--priority` | critical, high, medium, low | Urgency level |
| `--labels` | comma-separated | Tags: `bug,security,sprint-12` |
| `--depends` | task IDs | Dependencies: `T001,T002` |
| `--description` | text | Detailed description |
| `--notes` | text | Add timestamped note to task |
| `--phase` | slug | Project phase: `setup`, `core`, `polish` |
| `--blocked-by` | reason | Why blocked (sets status=blocked) |

### List Filters
```bash
cleo list --status pending          # Filter by status
cleo list --priority high           # Filter by priority
cleo list --label bug               # Filter by label
cleo list --phase core              # Filter by phase
cleo list --format json             # Output format (text|json|jsonl|markdown|table)
```

### Agent-First Output

**JSON is automatic** when piped (non-TTY). No `--format` flag needed:
```bash
cleo list | jq '.tasks[0]'      # Auto-JSON when piped
cleo analyze                     # JSON by default (use --human for text)
```

**Prefer native filters over jq** (fewer tokens, no shell quoting issues):
```bash
# ✅ NATIVE (recommended)
cleo list --status pending       # Built-in filter
cleo find "auth"                 # Fuzzy search (99% less context)
cleo list --label bug --phase core  # Combined filters

# ⚠️ JQ (only when native filters insufficient)
# Use SINGLE quotes to avoid shell interpretation
cleo list | jq '.tasks[] | select(.type != "epic")'
#                    ^ single quotes prevent bash ! expansion
```

**JSON envelope structure**: `{ "_meta": {...}, "summary": {...}, "tasks": [...] }`

## Session Protocol

### START
```bash
cleo session start
cleo list                           # See current task state
cleo dash                           # Overview of project state
cleo focus show                     # Check current focus
```

### WORK
```bash
cleo focus set <task-id>            # ONE task only
cleo next                           # Get task suggestion
cleo add "Subtask" --depends T045   # Add related tasks
cleo update T045 --notes "Progress" # Add task notes
cleo focus note "Working on X"      # Update session note
```

### END
```bash
cleo complete <task-id>
cleo archive                        # Optional: clean up old done tasks
cleo session end
```

## Task Organization

### Labels (Categorization)
Use labels for grouping and filtering:
```bash
# Feature tracking
cleo add "JWT middleware" --labels feature-auth,backend

# Find all auth tasks
cleo list --label feature-auth
cleo labels                         # See all labels with counts
cleo labels show feature-auth       # All tasks with label
```

### Phases (Workflow Stages)
Predefined project phases (setup → core → polish):
```bash
cleo add "Implement API" --phase core
cleo list --phase core              # Filter by phase
cleo phases                         # See phase progress
cleo phases stats                   # Detailed breakdown
```

### Dependencies (Task Ordering)
Block tasks until prerequisites complete:
```bash
cleo add "Write tests" --depends T001,T002
# Task stays pending until T001, T002 are done
cleo deps T001                      # What depends on T001
cleo blockers                       # What's blocking progress
cleo blockers analyze               # Critical path analysis
```

### Planning Pattern
```bash
# Phase 1 tasks
cleo add "Design API" --phase setup --priority high
cleo add "Create schema" --phase setup --depends T050

# Phase 2 tasks (blocked until phase 1)
cleo add "Implement endpoints" --phase core --depends T050,T051
```

## Notes: focus.note vs update --notes

| Command | Purpose | Storage |
|---------|---------|---------|
| `focus note "text"` | Session-level progress | `.focus.sessionNote` (replaces) |
| `update T001 --notes "text"` | Task-specific notes | `.tasks[].notes[]` (appends with timestamp) |

## Task Validation & Scripting

### Check Task Existence
Use `exists` command for validation in scripts and automation:

```bash
# Basic check (exit code 0 = exists, 1 = not found)
cleo exists T001

# Silent check for scripting (no output)
if cleo exists T001 --quiet; then
  echo "Task exists"
fi

# Check archive too
cleo exists T001 --include-archive

# Get detailed info with verbose mode
cleo exists T001 --verbose
```

### Script Examples
```bash
# Validate before update
if cleo exists T042 --quiet; then
  cleo update T042 --priority high
else
  echo "ERROR: Task T042 not found"
  exit 1
fi

# Validate dependencies exist
DEPS=("T001" "T002" "T005")
for dep in "${DEPS[@]}"; do
  if ! cleo exists "$dep" --quiet; then
    echo "ERROR: Dependency $dep not found"
    exit 1
  fi
done

# JSON output for complex logic
EXISTS=$(cleo exists T001 --format json | jq -r '.exists')
if [[ "$EXISTS" == "true" ]]; then
  # Process task
fi
```

### Exit Codes
| Code | Meaning | Use Case |
|------|---------|----------|
| `0` | Task exists | Success condition |
| `1` | Task not found | Expected failure |
| `2` | Invalid task ID format | Input validation error |
| `3` | File read error | System error |

## Error Recovery

| Problem | Solution |
|---------|----------|
| Checksum mismatch | `cleo validate --fix` |
| Task not found | `cleo list --all` (check archive) |
| Multiple active tasks | `cleo focus set <correct-id>` (resets others) |
| Corrupted JSON | `cleo restore` or `backup --list` then restore |
| Session already active | `cleo session status` then `session end` |
| Schema outdated | `cleo migrate run` |

## Command Aliases (v0.6.0+)

Built-in CLI aliases for faster workflows:
```bash
cleo ls              # list
cleo done T001       # complete T001
cleo new "Task"      # add "Task"
cleo edit T001       # update T001
cleo rm              # archive
cleo check           # validate
cleo tags            # labels
cleo overview        # dash
cleo dig "query"     # research
```

## Shell Aliases
```bash
ct              # cleo
ct-add          # cleo add
ct-list         # cleo list
ct-done         # cleo complete
ct-focus        # cleo focus
```

## Debug & Validation
```bash
cleo --validate      # Check CLI integrity
cleo --list-commands # Show all commands
cleo help <command>  # Detailed command help
```

### Command Discovery (v0.21.0+)
```bash
cleo commands                   # List all commands (JSON by default)
cleo commands --human           # Human-readable list
cleo commands -r critical       # Filter by agent relevance
cleo commands -c write          # Filter by category
cleo commands add               # Details for specific command
cleo commands --workflows       # Agent workflow sequences
cleo commands --lookup          # Intent-to-command mapping
```

**No jq required** - use native `--category` and `--relevance` filters instead.

## vs Agent Buffer (e.g. TodoWrite)

| System | Purpose | Persistence |
|--------|---------|-------------|
| **CLEO** | Durable task tracking | Survives sessions, full metadata |
| **Buffer** | Ephemeral session tasks | Session-only, simplified format |

**Workflows:**
- One-way export: `cleo export --format todowrite`
- Bidirectional sync: `cleo sync --inject` (start) and `sync --extract` (end)

---
*Full documentation: `cleo help <command>` or `~/.cleo/docs/`*
