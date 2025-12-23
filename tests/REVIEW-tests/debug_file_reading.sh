#!/usr/bin/env bash

# Debug file reading
set -e

echo "Current directory: $(pwd)"
echo "TODO_FILE path: $TODO_FILE"
echo "Script dir: $(dirname scripts/next.sh)"

# Create absolute path test
cat > /tmp/debug_todo_abs.json << 'EOF'
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

echo "Using absolute path..."
TODO_FILE=/tmp/debug_todo_abs.json bash scripts/next.sh --count 4 --format json | jq '.suggestions[] | {taskId: .taskId, title: .title, priority: .priority}'

echo ""
echo "Verifying file contents..."
cat /tmp/debug_todo_abs.json | jq '.tasks[] | {id: .id, title: .title, priority: .priority}'