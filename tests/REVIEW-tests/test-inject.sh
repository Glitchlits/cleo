#!/bin/bash
set -e

# Create test environment like the test does
export TEST_TEMP_DIR=$(mktemp -d)
cd "$TEST_TEMP_DIR"

# Create the test fixture like in the test
cat > todo.json << 'EOF'
{
  "version": "2.2.0",
  "project": {
    "name": "todowrite-sync-test",
    "currentPhase": "core",
    "phases": {
      "setup": {
        "order": 1,
        "name": "Setup",
        "status": "completed",
        "startedAt": "2025-12-14T09:00:00Z",
        "completedAt": "2025-12-14T12:00:00Z"
      },
      "core": {
        "order": 2,
        "name": "Core",
        "status": "active",
        "startedAt": "2025-12-14T12:00:00Z"
      },
      "polish": {
        "order": 3,
        "name": "Polish",
        "status": "pending"
      }
    }
  },
  "_meta": {
    "checksum": "test123",
    "configVersion": "2.0.0",
    "activeSession": "session_test_001"
  },
  "lastUpdated": "2025-12-15T14:00:00Z",
  "tasks": [
    {
      "id": "T001",
      "title": "High priority task",
      "description": "This is a high priority task for testing",
      "status": "active",
      "priority": "high",
      "phase": "core",
      "createdAt": "2025-12-15T10:00:00Z"
    },
    {
      "id": "T002",
      "title": "Blocked task",
      "description": "This task is blocked by something",
      "status": "blocked",
      "priority": "medium",
      "phase": "core",
      "blockedBy": "Waiting for API access",
      "createdAt": "2025-12-15T10:00:00Z"
    },
    {
      "id": "T003",
      "title": "Pending low priority",
      "description": "Low priority pending task",
      "status": "pending",
      "priority": "low",
      "phase": "core",
      "createdAt": "2025-12-15T10:00:00Z"
    },
    {
      "id": "T004",
      "title": "Already completed",
      "description": "This was already done",
      "status": "done",
      "priority": "medium",
      "phase": "setup",
      "createdAt": "2025-12-14T10:00:00Z",
      "completedAt": "2025-12-14T15:00:00Z"
    }
  ],
  "focus": {
    "currentTask": "T001",
    "currentPhase": "core",
    "blockedUntil": null,
    "sessionNote": null,
    "nextAction": null
  }
}
EOF

mkdir -p .claude
export TODO_FILE=".claude/todo.json"
cp todo.json "$TODO_FILE"
export SYNC_SCRIPT="/mnt/projects/claude-todo/scripts/sync-todowrite.sh"
export INJECT_SCRIPT="/mnt/projects/claude-todo/scripts/inject-todowrite.sh"
export EXTRACT_SCRIPT="/mnt/projects/claude-todo/scripts/extract-todowrite.sh"

# Run the inject script
echo "Running inject script..."
output=$(bash "$INJECT_SCRIPT" --quiet 2>&1) || echo "Script failed with exit code: $?"
echo "OUTPUT:"
echo "$output"
echo ""

# Try the jq query
echo "Testing jq query..."
blocked_item=$(echo "$output" | jq '.injected.todos[] | select(.content | contains("T002"))')
echo "BLOCKED ITEM: $blocked_item"

# Cleanup
cd /
rm -rf "$TEST_TEMP_DIR"