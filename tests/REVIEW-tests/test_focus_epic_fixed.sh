#!/usr/bin/env bash

# Test focus epic preference with same priority
set -e

# Create a test todo with two epics and tasks with same priority
cat > test_focus_todo_fixed.json << 'EOF'
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

echo "Testing with focus on T001 (Epic 1) and same priority..."
echo "Expected: Should prefer T002 (task in Epic 1) over T004 (task in Epic 2)"
echo ""

TODO_FILE=test_focus_todo_fixed.json bash scripts/next.sh --explain --format text