#!/usr/bin/env bats
# =============================================================================
# test-complete-task.bats - BATS tests for complete-task.sh
# =============================================================================
# Tests completion notes feature (v0.7.2+):
# - T095: --notes flag
# - T096: Notes required by default with --skip-notes bypass
# - T097: Notes stored in task array with [COMPLETED timestamp] prefix
# =============================================================================

# Setup: Create temporary test directory and files
setup() {
    export TEST_DIR="$(mktemp -d)"
    export TODO_FILE="$TEST_DIR/todo.json"
    export CONFIG_FILE="$TEST_DIR/todo-config.json"
    export BACKUPS_DIR="$TEST_DIR/.backups"
    mkdir -p "$BACKUPS_DIR"

    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../scripts" && pwd)"
    export COMPLETE_SCRIPT="$SCRIPT_DIR/complete-task.sh"

    # Create minimal config
    cat > "$CONFIG_FILE" << 'EOF'
{
  "version": "2.1.0",
  "archive": {
    "enabled": true,
    "daysUntilArchive": 7
  },
  "validation": {
    "strictMode": false
  }
}
EOF

    # Create test todo.json with a pending task
    cat > "$TODO_FILE" << 'EOF'
{
  "$schema": "../schemas/todo.schema.json",
  "_meta": {
    "version": "2.1.0",
    "checksum": "test123"
  },
  "tasks": [
    {
      "id": "T001",
      "title": "Test task for completion",
      "status": "pending",
      "priority": "medium",
      "createdAt": "2025-12-01T10:00:00Z"
    },
    {
      "id": "T002",
      "title": "Another test task",
      "status": "pending",
      "priority": "high",
      "createdAt": "2025-12-01T11:00:00Z"
    },
    {
      "id": "T003",
      "title": "Task with existing notes",
      "status": "pending",
      "priority": "low",
      "createdAt": "2025-12-01T12:00:00Z",
      "notes": ["Initial note from creation"]
    }
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# Teardown: Clean up temporary files
teardown() {
    rm -rf "$TEST_DIR"
}

# =============================================================================
# T096: Notes required by default
# =============================================================================

@test "complete without notes fails by default" {
    run bash "$COMPLETE_SCRIPT" T001
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Completion notes required" ]]
}

@test "error message includes example usage" {
    run bash "$COMPLETE_SCRIPT" T001
    [ "$status" -eq 1 ]
    [[ "$output" =~ "--notes" ]]
    [[ "$output" =~ "--skip-notes" ]]
}

@test "complete with --skip-notes succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 --skip-notes
    [ "$status" -eq 0 ]
    [[ "$output" =~ "marked as complete" ]]

    # Verify status changed
    status=$(jq -r '.tasks[] | select(.id == "T001") | .status' "$TODO_FILE")
    [ "$status" = "done" ]
}

# =============================================================================
# T095: --notes flag
# =============================================================================

@test "complete with --notes flag succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 --notes "Test completion notes"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "marked as complete" ]]
    [[ "$output" =~ "Notes:" ]]
}

@test "complete with -n short flag succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 -n "Short flag test"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "marked as complete" ]]
}

@test "--notes with empty string fails" {
    run bash "$COMPLETE_SCRIPT" T001 --notes ""
    [ "$status" -eq 1 ]
    [[ "$output" =~ "requires a text argument" ]]
}

@test "--notes without argument fails" {
    run bash "$COMPLETE_SCRIPT" T001 --notes
    [ "$status" -eq 1 ]
}

# =============================================================================
# T097: Notes stored in task array with [COMPLETED timestamp] prefix
# =============================================================================

@test "completion note stored in task notes array" {
    bash "$COMPLETE_SCRIPT" T001 --notes "My completion note"

    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "[COMPLETED" ]]
    [[ "$notes" =~ "My completion note" ]]
}

@test "completion note has ISO 8601 timestamp" {
    bash "$COMPLETE_SCRIPT" T001 --notes "Timestamp test"

    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    # Check for ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ
    [[ "$notes" =~ "[COMPLETED 20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z]" ]]
}

@test "completion note appended to existing notes array" {
    bash "$COMPLETE_SCRIPT" T003 --notes "Added after existing note"

    # Should have 2 notes now
    notes_count=$(jq '.tasks[] | select(.id == "T003") | .notes | length' "$TODO_FILE")
    [ "$notes_count" -eq 2 ]

    # First note should be original
    first_note=$(jq -r '.tasks[] | select(.id == "T003") | .notes[0]' "$TODO_FILE")
    [ "$first_note" = "Initial note from creation" ]

    # Second note should be completion note
    second_note=$(jq -r '.tasks[] | select(.id == "T003") | .notes[1]' "$TODO_FILE")
    [[ "$second_note" =~ "[COMPLETED" ]]
    [[ "$second_note" =~ "Added after existing note" ]]
}

@test "skip-notes does not add to notes array" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    # Notes should be null or empty
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes // empty' "$TODO_FILE")
    [ -z "$notes" ]
}

# =============================================================================
# Combined flags
# =============================================================================

@test "--notes with --skip-archive works" {
    run bash "$COMPLETE_SCRIPT" T002 --notes "No archive test" --skip-archive
    [ "$status" -eq 0 ]
    [[ "$output" =~ "marked as complete" ]]

    # Verify note stored
    notes=$(jq -r '.tasks[] | select(.id == "T002") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "No archive test" ]]
}

@test "--skip-notes with --skip-archive works" {
    run bash "$COMPLETE_SCRIPT" T002 --skip-notes --skip-archive
    [ "$status" -eq 0 ]
    [[ "$output" =~ "marked as complete" ]]
}

# =============================================================================
# Edge cases
# =============================================================================

@test "notes with special characters are preserved" {
    bash "$COMPLETE_SCRIPT" T001 --notes 'Fixed bug #123. See PR: https://github.com/example/repo/pull/456'

    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "bug #123" ]]
    [[ "$notes" =~ "https://github.com" ]]
}

@test "notes with quotes are preserved" {
    bash "$COMPLETE_SCRIPT" T001 --notes 'Said "hello world"'

    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ 'Said "hello world"' ]]
}

@test "long notes are stored correctly" {
    long_note="This is a very long completion note that describes in detail what was done, how it was tested, and provides references to commits, PRs, and documentation. It should be stored correctly without truncation."
    bash "$COMPLETE_SCRIPT" T001 --notes "$long_note"

    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "without truncation" ]]
}

@test "help shows notes options" {
    run bash "$COMPLETE_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "-n, --notes" ]]
    [[ "$output" =~ "--skip-notes" ]]
    [[ "$output" =~ "required" ]]
}
