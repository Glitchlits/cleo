<!-- CLEO-AGENT:START v1.0.0 -->
## Task Logistics (CLEO)

Use `cleo` (Comprehensive Logistics & Execution Orchestrator) for all task operations.
Full docs: `~/.cleo/docs/CLEO_Task_Management.md`

### Essential Commands
```bash
cleo list                    # View tasks (JSON when piped)
cleo find "query"            # Fuzzy search (99% less context than list)
cleo show <id>               # View single task details (use this first!)
cleo add "Task"              # Create task
cleo update <id> [OPTIONS]   # Update task fields
cleo done <id>               # Complete task
cleo focus set <id>          # Set active task
cleo focus show              # Show current focus
cleo session start|end       # Session lifecycle
cleo exists <id>             # Verify task exists
cleo dash                    # Project overview
cleo analyze                 # Task triage (JSON default)
cleo commands                # List all commands (JSON)
```

### Update Options
```bash
cleo update <id> --priority high       # Change priority
cleo update <id> --status blocked      # Change status
cleo update <id> --labels bug,urgent   # Append labels
cleo update <id> --notes "Progress"    # Add timestamped note
cleo update <id> --depends T001,T002   # Add dependencies
```

### Research
```bash
cleo research "query"                  # Multi-source web research
cleo research --url URL [URL...]       # Extract from specific URLs
cleo research --link-task T001         # Link research to task
```

### Phase Tracking
```bash
cleo phases                  # List phases with progress
cleo phase set <slug>        # Set current project phase
cleo list --phase core       # Filter tasks by phase
```

### Agent-First Design
- **JSON auto-detection**: Piped output → JSON
- **Native filters**: Use `--status`, `--label`, `--phase`
- **Context-efficient**: Prefer `find` over `list`
- **Command discovery**: `cleo commands -r critical`

### Data Integrity
- **CLI only** - Never edit `.cleo/*.json` directly
- **Verify state** - Use `cleo show <id>` or `cleo list` before assuming
- **Session discipline** - Start/end sessions properly
<!-- CLEO-AGENT:END -->
