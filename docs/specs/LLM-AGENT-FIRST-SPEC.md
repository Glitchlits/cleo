# Claude-TODO LLM-Agent-First Specification

> **Comprehensive analysis, architecture, and implementation plan for LLM-agent-first CLI design**
>
> **Version**: 1.0 | **Target**: v0.17.0 | **Generated**: 2025-12-17
> **Analysis Scope**: 28 commands, 150+ flags, reference implementation study

---

## Executive Summary

### Mission Statement

Transform claude-todo from **human-first** (text default, JSON opt-in) to **LLM-agent-first** (JSON default, human opt-in) to enable zero-friction autonomous agent workflows.

### Current State Assessment

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Commands with JSON support | 22/28 (79%) | 28/28 (100%) | 6 commands |
| Default output format | `text` (human) | `json` (non-TTY) | Architecture change |
| Commands with `--quiet` | 5/28 (18%) | 28/28 (100%) | 23 commands |
| Commands with `--format` | 9/28 (32%) | 28/28 (100%) | 19 commands |
| Standardized error JSON | 0% | 100% | Not implemented |
| JSON envelope consistency | 73% | 100% | 27% variation |
| TTY auto-detection for format | No | Yes | Not implemented |
| Flag consistency score | 43% | 100% | Significant work |

### Critical Gaps

| Gap | Severity | Impact |
|-----|----------|--------|
| Write commands have NO JSON | 🔴 Critical | Agents must re-query after every mutation |
| TTY auto-detection not used | 🔴 Critical | Manual `--format json` required everywhere |
| No standardized error JSON | 🔴 Critical | Must parse colored text with regex |
| `phase.sh` has ZERO JSON | 🟡 High | Phase lifecycle blocked from automation |
| Flag consistency at 43% | 🟡 High | Inconsistent behavior across commands |
| Short flag conflicts (`-f`, `-n`) | 🟠 Medium | Scripting confusion |

### Reference Implementation

**`analyze.sh`** (v0.16.0) is the **gold standard** for LLM-agent-first design:
- **JSON output is DEFAULT** (`OUTPUT_MODE="json"` line 74)
- Human output requires explicit `--human` flag (opt-in for HITL)
- Comprehensive `_meta` envelope with version, timestamp, algorithm
- Structured recommendations with `action_order`, `recommendation.command`
- Exit codes documented (0=success, 1=error, 2=no tasks)

---

## Part 1: Command Analysis

### Tier 1: Production-Ready for Agents (8-10/10)

| Command | Score | JSON | Quiet | Key Strength |
|---------|-------|------|-------|--------------|
| `analyze` | **10/10** | Default | N/A | **Reference implementation** - JSON default |
| `list` | 9/10 | Full | Yes | Most comprehensive format support |
| `exists` | 9/10 | Full | Yes | Perfect exit codes (4 explicit constants) |
| `validate` | 9/10 | Full | Yes | Auto-fix with atomic writes |
| `stats` | 9/10 | Full | No | Cleanest JSON structure |
| `labels` | 9/10 | Full | No | Co-occurrence analysis |
| `blockers` | 9/10 | Full | Yes | Critical path analysis |
| `export` | 8/10 | Multi | Yes | 5 format options |

### Tier 2: Usable with Limitations (5-7/10)

| Command | Score | Issues | Fix Needed |
|---------|-------|--------|------------|
| `show` | 7/10 | No quiet mode | Add `--quiet` |
| `next` | 8/10 | No quiet mode | Add `--quiet` |
| `history` | 8/10 | Missing `_meta.timestamp` | Fix envelope |
| `deps` | 8/10 | No `--format` flag | Add `--format` |
| `dash` | 6/10 | Complex output | Add `--quiet` |
| `log` | 7/10 | Raw array, no envelope | Add `_meta` |
| `session` | 5/10 | Partial JSON (subcommands only) | Global `--format` |
| `phases` | 6/10 | Heavy human formatting | Add `--format` |

### Tier 3: Requires Enhancement (1-4/10)

| Command | Score | Critical Issues |
|---------|-------|-----------------|
| `focus` | 4/10 | Only `show` has JSON; no global `--format` |
| `backup` | 4/10 | No JSON output mode |
| `add` | **2/10** | **No JSON output** - cannot get created task |
| `update` | **1/10** | **No output control whatsoever** |
| `complete` | **2/10** | **No JSON confirmation** |
| `restore` | 3/10 | Interactive only, no dry-run |
| `migrate` | 2/10 | Text-only status |
| `init` | 2/10 | Procedural, no output |
| `phase` | **2/10** | **ZERO JSON output** in any subcommand |
| `archive` | 2/10 | Statistics as text only |

---

## Part 2: Gap Analysis

### Gap 1: Write Commands Have NO JSON Output

**Impact**: Agents must re-query after every mutation

| Command | Current Output | Agent Workaround |
|---------|----------------|------------------|
| `add` | Text + task ID | `ct show $(ct add "Task" -q) --format json` |
| `update` | Text summary | `ct list --format json` after update |
| `complete` | Text confirmation | `ct show $id --format json` after |
| `archive` | Text stats | `ct stats --format json` after |

**Required JSON Output**:

```json
// ct add "Task" --format json
{
  "_meta": {"command": "add", "timestamp": "...", "version": "..."},
  "success": true,
  "task": {"id": "T042", "title": "...", "status": "pending", "createdAt": "..."}
}

// ct update T042 --priority high --format json
{
  "_meta": {"command": "update", "timestamp": "..."},
  "success": true,
  "taskId": "T042",
  "changes": {"priority": {"before": "medium", "after": "high"}},
  "task": {/* full updated task */}
}

// ct complete T042 --format json
{
  "_meta": {"command": "complete", "timestamp": "..."},
  "success": true,
  "taskId": "T042",
  "completedAt": "2025-12-17T10:00:00Z",
  "cycleTimeDays": 3.5
}
```

### Gap 2: TTY Auto-Detection Not Used for Format

**Location**: `lib/output-format.sh` line 251

**Current**:
```bash
# Default fallback if nothing resolved
[[ -z "$resolved_format" ]] && resolved_format="text"
```

**Required**:
```bash
# Default fallback: TTY-aware auto-detection
if [[ -z "$resolved_format" ]]; then
  if [[ -t 1 ]]; then
    resolved_format="text"  # Interactive terminal
  else
    resolved_format="json"  # Pipe/redirect/agent context
  fi
fi
```

### Gap 3: No Standardized Error JSON Format

**Current**: Errors output as text regardless of `--format json`

```bash
# Current behavior
echo -e "${RED}[ERROR]${NC} Task ID required" >&2
```

**Required Error JSON**:
```json
{
  "_meta": {"command": "exists", "timestamp": "...", "version": "..."},
  "success": false,
  "error": {
    "code": "E_TASK_NOT_FOUND",
    "message": "Task T999 does not exist",
    "exitCode": 1,
    "recoverable": false,
    "suggestion": "Use 'ct exists' to verify task ID"
  }
}
```

### Gap 4: Phase Commands Have ZERO JSON Output

**`phase.sh`** subcommands (show, set, start, complete, advance, list) all output text only.

**Current**:
```bash
claude-todo phase show
# Output: "Current Phase: core\n  Name: Core Development\n  Status: active"
```

**Required**:
```json
{
  "_meta": {"command": "phase show", "timestamp": "..."},
  "success": true,
  "currentPhase": {
    "slug": "core",
    "name": "Core Development",
    "status": "active",
    "startedAt": "2025-12-10T14:30:00Z",
    "durationDays": 7.2
  }
}
```

### Gap 5: Flag Inconsistency Across Commands

**Conflict Matrix**:

| Short Flag | Conflicting Uses | Resolution |
|------------|------------------|------------|
| `-f` | `--format` (7 commands) vs `--files` (update) | Keep `-f` for `--format`, `--files` long-form only |
| `-n` | `--notes` (3 commands) vs `--count` (next) | Keep `-n` for `--notes`, use `-c` for `--count` |

**Missing Universal Flags**:

| Flag | Current Coverage | Target |
|------|-----------------|--------|
| `--format` | 9/28 (32%) | 100% |
| `--quiet` | 5/28 (18%) | 100% |
| `--verbose` | 2/28 (7%) | All display commands |
| `--dry-run` | 3/28 (11%) | All write operations |

---

## Part 3: Standardized Systems

### 3.1 Exit Code Standard

Create `lib/exit-codes.sh`:

```bash
#!/usr/bin/env bash
# lib/exit-codes.sh - Standardized exit codes for claude-todo

# SUCCESS CODES
readonly EXIT_SUCCESS=0           # Operation completed successfully

# ERROR CODES (1-99)
readonly EXIT_GENERAL_ERROR=1     # Unspecified error (backward compat)
readonly EXIT_INVALID_INPUT=2     # Invalid user input/arguments
readonly EXIT_FILE_ERROR=3        # File system operation failed
readonly EXIT_NOT_FOUND=4         # Requested resource not found
readonly EXIT_DEPENDENCY_ERROR=5  # Missing dependency (jq, etc.)
readonly EXIT_VALIDATION_ERROR=6  # Data validation failed
readonly EXIT_LOCK_TIMEOUT=7      # Failed to acquire file lock

# SPECIAL CODES (100+)
readonly EXIT_NO_DATA=100         # No data to process (not an error)
readonly EXIT_ALREADY_EXISTS=101  # Resource already exists
readonly EXIT_NO_CHANGE=102       # No changes needed/made

export EXIT_SUCCESS EXIT_GENERAL_ERROR EXIT_INVALID_INPUT EXIT_FILE_ERROR
export EXIT_NOT_FOUND EXIT_DEPENDENCY_ERROR EXIT_VALIDATION_ERROR EXIT_LOCK_TIMEOUT
export EXIT_NO_DATA EXIT_ALREADY_EXISTS EXIT_NO_CHANGE
```

### 3.2 Error JSON Library

Create `lib/error-json.sh`:

```bash
#!/usr/bin/env bash
# lib/error-json.sh - Standardized error JSON output

source "${LIB_DIR:-$(dirname "$0")}/exit-codes.sh"

# output_error - Format-aware error output
output_error() {
  local error_code="$1" message="$2" exit_code="${3:-1}"
  local recoverable="${4:-false}" suggestion="${5:-}"
  local command="${COMMAND_NAME:-unknown}"
  local version="${VERSION:-unknown}"

  if [[ "${FORMAT:-text}" == "json" ]]; then
    jq -n \
      --arg version "$version" \
      --arg command "$command" \
      --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg code "$error_code" \
      --arg msg "$message" \
      --argjson exit "$exit_code" \
      --argjson rec "$recoverable" \
      --arg sug "$suggestion" \
      '{
        "$schema": "https://claude-todo.dev/schemas/error-v1.json",
        "_meta": {"format": "json", "version": $version, "command": $command, "timestamp": $timestamp},
        "success": false,
        "error": {
          "code": $code,
          "message": $msg,
          "exitCode": $exit,
          "recoverable": $rec,
          "suggestion": (if $sug != "" then $sug else null end)
        }
      }'
  else
    echo -e "${RED:-}[ERROR]${NC:-} $message" >&2
    [[ -n "$suggestion" ]] && echo -e "${DIM:-}Suggestion: $suggestion${NC:-}" >&2
  fi
  return "$exit_code"
}

export -f output_error
```

### 3.3 JSON Envelope Standard

All JSON outputs must follow this envelope:

```json
{
  "$schema": "https://claude-todo.dev/schemas/output-v2.json",
  "_meta": {
    "format": "json",
    "version": "<version>",
    "command": "<command-name>",
    "timestamp": "<ISO-8601>",
    "checksum": "<sha256>",      // Optional
    "execution_ms": <ms>          // Optional
  },
  "success": true,
  "summary": {},
  "data": []
}
```

**Envelope Compliance Fixes Needed**:

| Command | Issue | Fix |
|---------|-------|-----|
| `analyze.sh` | Missing `_meta.format`, `_meta.command` | Add fields |
| `history.sh` | Missing `_meta.timestamp` | Add timestamp |
| All commands | Only 4/9 have `$schema` | Add schema URL |

### 3.4 Universal Flag Standard

| Flag | Long Form | Purpose | Default | Commands |
|------|-----------|---------|---------|----------|
| `-f` | `--format` | Output format | `json` (non-TTY) / `text` (TTY) | ALL |
| `-q` | `--quiet` | Suppress non-essential output | false | ALL |
| `-v` | `--verbose` | Detailed output | false | ALL read commands |
| | `--human` | Force human-readable | false | ALL |
| | `--dry-run` | Preview changes | false | ALL write commands |
| | `--force` | Skip confirmations | false | Destructive commands |

---

## Part 4: Implementation Plan

### Phase 1: Foundation (P1 - CRITICAL)

**Goal**: Enable closed-loop agent automation for all write operations.

| Task | File | Changes |
|------|------|---------|
| Create `lib/exit-codes.sh` | New file | Exit code constants |
| Create `lib/error-json.sh` | New file | Error JSON functions |
| TTY auto-detection for format | `lib/output-format.sh:251` | Modify `resolve_format()` |
| JSON output for `add` | `scripts/add-task.sh` | Add format flag, JSON output |
| JSON output for `update` | `scripts/update-task.sh` | Add format flag, diff output |
| JSON output for `complete` | `scripts/complete-task.sh` | Add format flag, JSON output |
| JSON output for `archive` | `scripts/archive.sh` | Add format flag, JSON output |
| JSON for all `phase` subcommands | `scripts/phase.sh` | Complete rewrite of output |

### Phase 2: Standardization (P2 - HIGH)

**Goal**: Consistent flags and envelopes across all commands.

| Task | Scope |
|------|-------|
| Add `--quiet` to 23 commands | All scripts without `--quiet` |
| Add `--format` to 19 commands | All scripts without `--format` |
| Fix JSON envelope inconsistencies | `analyze.sh`, `history.sh`, others |
| Add `$schema` to all JSON outputs | All commands with JSON |
| Resolve `-f` flag conflict | `update-task.sh` |
| Resolve `-n` flag conflict | `next.sh` |
| Source `exit-codes.sh` everywhere | All scripts |

### Phase 3: Polish (P3 - MEDIUM)

**Goal**: Complete LLM-agent optimization with full coverage.

| Task | Scope |
|------|-------|
| Add `--verbose` to display commands | `show.sh`, `stats.sh`, `dash.sh` |
| Add `--dry-run` to write commands | `update.sh`, `complete.sh`, `restore.sh`, `migrate.sh` |
| Add `--human` flag universally | All commands |
| Update all documentation | `docs/commands/*.md` |
| Create agent workflow examples | New documentation |
| Add JSON schema files | `schemas/` |

---

## Part 5: Command Implementation Details

### Write Commands (P1)

#### `add-task.sh` Implementation

**Add flag parsing** (after line 93):
```bash
FORMAT=""
# ... in while loop:
-f|--format) FORMAT="$2"; shift 2 ;;
--human) FORMAT="text" ;;
```

**Add format resolution**:
```bash
source "${LIB_DIR}/output-format.sh"
FORMAT=$(resolve_format "$FORMAT")
```

**Replace output** (after task creation):
```bash
if [[ "$FORMAT" == "json" ]]; then
  TASK_JSON=$(jq --arg id "$NEW_ID" '.tasks[] | select(.id == $id)' "$TODO_FILE")
  jq -n \
    --arg version "$VERSION" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson task "$TASK_JSON" \
    '{
      "$schema": "https://claude-todo.dev/schemas/output-v2.json",
      "_meta": {"format": "json", "version": $version, "command": "add", "timestamp": $timestamp},
      "success": true,
      "task": $task
    }'
elif [[ "$QUIET" == true ]]; then
  echo "$NEW_ID"
else
  echo -e "${GREEN}Task added:${NC} $NEW_ID - \"$TITLE\""
fi
```

#### `update-task.sh` Implementation

**Capture before-state** (before applying changes):
```bash
BEFORE_STATE=$(jq --arg id "$TASK_ID" '.tasks[] | select(.id == $id)' "$TODO_FILE")
```

**Track changes** (as each field is updated):
```bash
CHANGES_JSON="{}"
if [[ -n "$NEW_PRIORITY" ]]; then
  old_priority=$(echo "$BEFORE_STATE" | jq -r '.priority')
  CHANGES_JSON=$(echo "$CHANGES_JSON" | jq --arg old "$old_priority" --arg new "$NEW_PRIORITY" \
    '.priority = {before: $old, after: $new}')
fi
# ... repeat for each field
```

**JSON output**:
```bash
if [[ "$FORMAT" == "json" ]]; then
  AFTER_STATE=$(jq --arg id "$TASK_ID" '.tasks[] | select(.id == $id)' "$TODO_FILE")
  jq -n \
    --arg taskId "$TASK_ID" \
    --argjson changes "$CHANGES_JSON" \
    --argjson task "$AFTER_STATE" \
    '{
      "_meta": {...},
      "success": true,
      "taskId": $taskId,
      "changes": $changes,
      "task": $task
    }'
fi
```

#### `phase.sh` Implementation

**Add global format handling**:
```bash
FORMAT=""
parse_global_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f|--format) FORMAT="$2"; shift 2 ;;
      --human) FORMAT="text"; shift ;;
      *) break ;;
    esac
  done
}
```

**Update each subcommand** (example for `cmd_show`):
```bash
cmd_show() {
  local current_phase phase_info
  current_phase=$(get_current_phase "$TODO_FILE")

  if [[ "$FORMAT" == "json" ]]; then
    phase_info=$(get_phase "$current_phase" "$TODO_FILE")
    jq -n \
      --arg slug "$current_phase" \
      --argjson info "$phase_info" \
      '{
        "_meta": {"command": "phase show", "timestamp": (now | todate)},
        "success": true,
        "currentPhase": ($info + {slug: $slug})
      }'
  else
    echo "Current Phase: $current_phase"
    # ... existing text output
  fi
}
```

---

## Part 6: Testing Strategy

### Exit Code Testing

```bash
#!/usr/bin/env bash
# Test success
ct add "Test task" -q
[[ $? -eq 0 ]] || echo "FAIL: add should exit 0"

# Test not found
ct show T999 2>/dev/null
[[ $? -eq 4 ]] || echo "FAIL: show non-existent should exit 4"

# Test invalid input
ct add 2>/dev/null
[[ $? -eq 2 ]] || echo "FAIL: add without title should exit 2"
```

### JSON Output Testing

```bash
#!/usr/bin/env bash
# Test add returns valid JSON with task
result=$(ct add "JSON Test" --format json)
echo "$result" | jq -e '.success == true' || echo "FAIL: success should be true"
echo "$result" | jq -e '.task.id' || echo "FAIL: should have task.id"
echo "$result" | jq -e '._meta.command == "add"' || echo "FAIL: should have _meta.command"

# Test error JSON
result=$(ct show T999 --format json 2>&1)
echo "$result" | jq -e '.success == false' || echo "FAIL: should be unsuccessful"
echo "$result" | jq -e '.error.code' || echo "FAIL: should have error.code"
```

### TTY Detection Testing

```bash
#!/usr/bin/env bash
# Piped output should be JSON
format=$(ct list | jq -r '._meta.format' 2>/dev/null)
[[ "$format" == "json" ]] || echo "FAIL: piped output should default to JSON"

# Explicit --human should override
output=$(ct list --human | head -1)
[[ "$output" != "{" ]] || echo "FAIL: --human should output text"
```

---

## Part 7: Agent Integration Guide

### Environment Setup

```bash
# Agent-optimized environment
export CLAUDE_TODO_FORMAT=json
export NO_COLOR=1
export CLAUDE_TODO_AGENT_MODE=1
```

### Query Patterns (Work Today)

```bash
# Task listing
ct list --format json | jq '.tasks[]'

# Analysis (already JSON default!)
ct analyze | jq '.recommendations'

# Single task
ct show T001 --format json

# Validation
ct validate --json --quiet && echo "Valid"
```

### Write Patterns (Current Workaround)

```bash
# Create and get full task (requires 2 commands today)
task_id=$(ct add "Task" -q)
ct show "$task_id" --format json

# Update and verify
ct update T001 --priority high
ct show T001 --format json
```

### Write Patterns (After v0.17.0)

```bash
# Single command returns complete result
task_json=$(ct add "Task")
task_id=$(echo "$task_json" | jq -r '.task.id')

# Update returns changes + updated task
ct update T001 --priority high | jq '.changes'
```

---

## Part 8: Success Metrics

### Before Implementation

| Metric | Value |
|--------|-------|
| Agent workflow steps per mutation | 2x (command + verify) |
| Commands requiring `--format json` | 27/28 |
| Error parsing method | Regex on colored text |
| Write confirmation available | No |
| Average command score | 5.4/10 |

### After Implementation

| Metric | Value |
|--------|-------|
| Agent workflow steps per mutation | 1x (command with result) |
| Commands requiring `--format json` | 0/28 (auto-detect) |
| Error parsing method | JSON field access |
| Write confirmation available | Yes |
| Average command score | 10/10 |

### Quantified Impact

- **50% reduction** in agent API calls
- **100% reliability** in error handling
- **Zero manual flags** in agent context
- **100% scriptability** with documented exit codes

---

## Part 9: Complete Command Matrix

| Command | JSON | Quiet | Format | Dry-Run | Before | After |
|---------|------|-------|--------|---------|--------|-------|
| add | ❌→✅ | ✅ | ❌→✅ | ❌ | 2/10 | 10/10 |
| update | ❌→✅ | ❌→✅ | ❌→✅ | ❌→✅ | 1/10 | 10/10 |
| complete | ❌→✅ | ❌→✅ | ❌→✅ | ❌→✅ | 2/10 | 10/10 |
| archive | ❌→✅ | ❌→✅ | ❌→✅ | ✅ | 2/10 | 10/10 |
| phase | ❌→✅ | ❌→✅ | ❌→✅ | N/A | 2/10 | 10/10 |
| init | ❌→✅ | ❌→✅ | ❌→✅ | N/A | 2/10 | 10/10 |
| migrate | ❌→✅ | ❌→✅ | ❌→✅ | ❌→✅ | 2/10 | 10/10 |
| restore | ❌→✅ | ❌→✅ | ❌→✅ | ❌→✅ | 3/10 | 10/10 |
| backup | ❌→✅ | ❌→✅ | ❌→✅ | N/A | 4/10 | 10/10 |
| focus | ⚠️→✅ | ❌→✅ | ❌→✅ | N/A | 4/10 | 10/10 |
| session | ⚠️→✅ | ❌→✅ | ❌→✅ | N/A | 5/10 | 10/10 |
| phases | ⚠️→✅ | ❌→✅ | ❌→✅ | N/A | 6/10 | 10/10 |
| dash | ✅ | ❌→✅ | ✅ | N/A | 6/10 | 10/10 |
| show | ✅ | ❌→✅ | ✅ | N/A | 7/10 | 10/10 |
| log | ✅ | ❌→✅ | ❌→✅ | N/A | 7/10 | 10/10 |
| sync | ⚠️ | ✅ | ❌→✅ | ✅ | 7/10 | 10/10 |
| history | ✅ | ❌→✅ | ✅ | N/A | 8/10 | 10/10 |
| deps | ✅ | ❌→✅ | ❌→✅ | N/A | 8/10 | 10/10 |
| next | ✅ | ❌→✅ | ✅ | N/A | 8/10 | 10/10 |
| export | ✅ | ✅ | ✅ | N/A | 8/10 | 10/10 |
| blockers | ✅ | ✅ | ❌→✅ | N/A | 9/10 | 10/10 |
| labels | ✅ | ❌→✅ | ❌→✅ | N/A | 9/10 | 10/10 |
| stats | ✅ | ❌→✅ | ✅ | N/A | 9/10 | 10/10 |
| validate | ✅ | ✅ | ✅ | N/A | 9/10 | 10/10 |
| exists | ✅ | ✅ | ✅ | N/A | 9/10 | 10/10 |
| list | ✅ | ✅ | ✅ | N/A | 9/10 | 10/10 |
| analyze | ✅ | ❌→✅ | ✅ | N/A | 10/10 | 10/10 |

**Legend**: ✅ = Has | ❌ = Missing | ⚠️ = Partial | →✅ = After implementation

**Final Target: 28/28 commands at 10/10 = 100% LLM-Agent-First**

---

## Part 10: Files Reference

### New Files to Create

| File | Purpose |
|------|---------|
| `lib/exit-codes.sh` | Standardized exit code constants |
| `lib/error-json.sh` | Error JSON output functions |
| `schemas/output-v2.json` | Output JSON schema |
| `schemas/error-v1.json` | Error JSON schema |

### Files to Modify

| File | Changes |
|------|---------|
| `lib/output-format.sh:251` | TTY auto-detection in `resolve_format()` |
| `scripts/add-task.sh` | Add `--format`, JSON output |
| `scripts/update-task.sh` | Add `--format`, `--quiet`, `--dry-run`, JSON output |
| `scripts/complete-task.sh` | Add `--format`, `--quiet`, JSON output |
| `scripts/archive.sh` | Add `--format`, `--quiet`, JSON output |
| `scripts/phase.sh` | Complete JSON support for all subcommands |
| `scripts/init.sh` | Add `--format`, JSON output |
| `scripts/migrate.sh` | Add `--format`, JSON output |
| `scripts/restore.sh` | Add `--format`, `--dry-run`, JSON output |
| `scripts/backup.sh` | Add `--format`, JSON output |
| All 28 scripts | Source `exit-codes.sh`, standardize exit codes |
| 23 scripts | Add `--quiet` flag |
| 19 scripts | Add `--format` flag |

### Reference Implementations (Study These)

| File | Strength |
|------|----------|
| `scripts/analyze.sh` | **Gold standard** - JSON default, `--human` flag |
| `scripts/exists.sh` | Perfect exit codes pattern |
| `scripts/list-tasks.sh` | Comprehensive JSON envelope |
| `scripts/validate.sh` | `--fix` and JSON patterns |

---

*Specification v1.0 for claude-todo v0.17.0*
*Consolidated from analysis reports and implementation planning*
