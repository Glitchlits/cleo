#!/usr/bin/env bats
# =============================================================================
# complete-task.bats - Unit tests for complete-task.sh
# =============================================================================
# Tests completion functionality including notes feature (v0.7.2+):
# - T095: --notes flag
# - T096: Notes required by default with --skip-notes bypass
# - T097: Notes stored in task array with [COMPLETED timestamp] prefix
# =============================================================================

setup() {
    load '../test_helper/common_setup'
    load '../test_helper/assertions'
    load '../test_helper/fixtures'
    common_setup

    # Create test todo.json with tasks for completion testing
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
      "description": "Test description",
      "status": "pending",
      "priority": "medium",
      "createdAt": "2025-12-01T10:00:00Z"
    },
    {
      "id": "T002",
      "title": "Another test task",
      "description": "Another description",
      "status": "pending",
      "priority": "high",
      "createdAt": "2025-12-01T11:00:00Z"
    },
    {
      "id": "T003",
      "title": "Task with existing notes",
      "description": "Has notes already",
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

teardown() {
    common_teardown
}

# =============================================================================
# Help and Basic Tests
# =============================================================================

@test "complete --help shows usage" {
    run bash "$COMPLETE_SCRIPT" --help
    assert_shows_help
}

@test "complete -h shows usage" {
    run bash "$COMPLETE_SCRIPT" -h
    assert_shows_help
}

# =============================================================================
# T096: Notes required by default
# =============================================================================

@test "complete without notes fails by default" {
    run bash "$COMPLETE_SCRIPT" T001
    assert_failure
    [[ "$output" =~ "Completion notes required" ]]
}

@test "error message includes example usage" {
    run bash "$COMPLETE_SCRIPT" T001
    assert_failure
    [[ "$output" =~ "--notes" ]]
    [[ "$output" =~ "--skip-notes" ]]
}

@test "complete with --skip-notes succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 --skip-notes
    assert_success
    [[ "$output" =~ "marked as complete" ]]

    local status
    status=$(jq -r '.tasks[] | select(.id == "T001") | .status' "$TODO_FILE")
    [ "$status" = "done" ]
}

# =============================================================================
# T095: --notes flag
# =============================================================================

@test "complete with --notes flag succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 --notes "Test completion notes"
    assert_success
    [[ "$output" =~ "marked as complete" ]]
    [[ "$output" =~ "Notes:" ]]
}

@test "complete with -n short flag succeeds" {
    run bash "$COMPLETE_SCRIPT" T001 -n "Short flag test"
    assert_success
    [[ "$output" =~ "marked as complete" ]]
}

@test "--notes with empty string fails" {
    run bash "$COMPLETE_SCRIPT" T001 --notes ""
    assert_failure
    [[ "$output" =~ "requires a text argument" ]]
}

@test "--notes without argument fails" {
    run bash "$COMPLETE_SCRIPT" T001 --notes
    assert_failure
}

# =============================================================================
# T097: Notes stored in task array with [COMPLETED timestamp] prefix
# =============================================================================

@test "completion note stored in task notes array" {
    bash "$COMPLETE_SCRIPT" T001 --notes "My completion note"

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "[COMPLETED" ]]
    [[ "$notes" =~ "My completion note" ]]
}

@test "completion note has ISO 8601 timestamp" {
    bash "$COMPLETE_SCRIPT" T001 --notes "Timestamp test"

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ \[COMPLETED\ 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z\] ]]
}

@test "completion note appended to existing notes array" {
    bash "$COMPLETE_SCRIPT" T003 --notes "Added after existing note"

    local notes_count
    notes_count=$(jq '.tasks[] | select(.id == "T003") | .notes | length' "$TODO_FILE")
    [ "$notes_count" -eq 2 ]

    local first_note
    first_note=$(jq -r '.tasks[] | select(.id == "T003") | .notes[0]' "$TODO_FILE")
    [ "$first_note" = "Initial note from creation" ]

    local second_note
    second_note=$(jq -r '.tasks[] | select(.id == "T003") | .notes[1]' "$TODO_FILE")
    [[ "$second_note" =~ "[COMPLETED" ]]
    [[ "$second_note" =~ "Added after existing note" ]]
}

@test "skip-notes does not add to notes array" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes // empty' "$TODO_FILE")
    [ -z "$notes" ]
}

# =============================================================================
# Combined flags
# =============================================================================

@test "--notes with --skip-archive works" {
    run bash "$COMPLETE_SCRIPT" T002 --notes "No archive test" --skip-archive
    assert_success
    [[ "$output" =~ "marked as complete" ]]

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T002") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "No archive test" ]]
}

@test "--skip-notes with --skip-archive works" {
    run bash "$COMPLETE_SCRIPT" T002 --skip-notes --skip-archive
    assert_success
    [[ "$output" =~ "marked as complete" ]]
}

# =============================================================================
# Edge cases
# =============================================================================

@test "notes with special characters are preserved" {
    bash "$COMPLETE_SCRIPT" T001 --notes 'Fixed bug #123. See PR: https://github.com/example/repo/pull/456'

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "bug #123" ]]
    [[ "$notes" =~ "https://github.com" ]]
}

@test "notes with quotes are preserved" {
    bash "$COMPLETE_SCRIPT" T001 --notes 'Said "hello world"'

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ 'Said "hello world"' ]]
}

@test "long notes are stored correctly" {
    local long_note="This is a very long completion note that describes in detail what was done, how it was tested, and provides references to commits, PRs, and documentation. It should be stored correctly without truncation."
    bash "$COMPLETE_SCRIPT" T001 --notes "$long_note"

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes[0]' "$TODO_FILE")
    [[ "$notes" =~ "without truncation" ]]
}

@test "help shows notes options" {
    run bash "$COMPLETE_SCRIPT" --help
    assert_success
    [[ "$output" =~ "-n, --notes" ]]
    [[ "$output" =~ "--skip-notes" ]]
    [[ "$output" =~ "required" ]]
}

# =============================================================================
# T138: Bug fix - complete --skip-notes generates valid JSON
# =============================================================================

@test "T138: skip-notes generates valid JSON structure" {
    run bash "$COMPLETE_SCRIPT" T001 --skip-notes
    assert_success

    run jq empty "$TODO_FILE"
    assert_success
}

@test "T138: skip-notes generates valid todo.json with all required fields" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    run jq -e '._meta' "$TODO_FILE"
    assert_success

    run jq -e '.tasks' "$TODO_FILE"
    assert_success

    run jq -e '.lastUpdated' "$TODO_FILE"
    assert_success
}

@test "T138: skip-notes updates checksum correctly" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    local checksum
    checksum=$(jq -r '._meta.checksum' "$TODO_FILE")
    [[ "$checksum" =~ ^[a-f0-9]{16}$ ]]
}

@test "T138: skip-notes preserves other tasks unchanged" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    local t002_status t003_status
    t002_status=$(jq -r '.tasks[] | select(.id == "T002") | .status' "$TODO_FILE")
    [ "$t002_status" = "pending" ]

    t003_status=$(jq -r '.tasks[] | select(.id == "T003") | .status' "$TODO_FILE")
    [ "$t003_status" = "pending" ]

    local t003_notes
    t003_notes=$(jq -r '.tasks[] | select(.id == "T003") | .notes[0]' "$TODO_FILE")
    [ "$t003_notes" = "Initial note from creation" ]
}

@test "T138: skip-notes does not create empty notes array" {
    bash "$COMPLETE_SCRIPT" T001 --skip-notes

    local notes
    notes=$(jq -r '.tasks[] | select(.id == "T001") | .notes // "null"' "$TODO_FILE")
    [ "$notes" = "null" ]
}
