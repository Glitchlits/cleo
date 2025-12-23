#!/usr/bin/env bash

# Test hierarchy scoring functionality
set -e

# Source the next.sh script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Create a test todo with hierarchy
cat > test_todo.json << 'EOF'
{
  "version": "2.3.0",
  "project": {
    "name": "test",
    "currentPhase": "core"
  },
  "_meta": {"version": "2.3.0"},
  "tasks": [
    {
      "id": "T001",
      "title": "Epic 1",
      "description": "First epic",
      "status": "pending",
      "priority": "medium",
      "type": "epic",
      "phase": "core",
      "createdAt": "2025-12-01T10:00:00Z"
    },
    {
      "id": "T002",
      "title": "Task in Epic 1",
      "description": "Task",
      "status": "pending",
      "priority": "medium",
      "type": "task",
      "parentId": "T001",
      "phase": "core",
      "createdAt": "2025-12-01T10:01:00Z"
    },
    {
      "id": "T003",
      "title": "Epic 2",
      "description": "Second epic",
      "status": "pending",
      "priority": "medium",
      "type": "epic",
      "phase": "core",
      "createdAt": "2025-12-01T10:02:00Z"
    },
    {
      "id": "T004",
      "title": "Task in Epic 2",
      "description": "Task",
      "status": "pending",
      "priority": "medium",
      "type": "task",
      "parentId": "T003",
      "phase": "core",
      "createdAt": "2025-12-01T10:03:00Z"
    }
  ],
  "focus": {"currentTask": "T001"},
  "labels": {},
  "lastUpdated": "2025-12-01T10:03:00Z"
}
EOF

# Test with focused epic
echo "Testing with focused epic T001..."
TODO_FILE=test_todo.json bash scripts/next.sh --explain

echo ""
echo "Testing JSON output..."
TODO_FILE=test_todo.json bash scripts/next.sh --format json