#!/usr/bin/env bash

# Debug suggestions
set -e

# Create a test todo with two epics and tasks with same priority
cat > debug_todo.json << 'EOF'
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

echo "All pending tasks:"
jq '.tasks[] | select(.status == "pending") | {id: .id, title: .title, priority: .priority, type: .type, parentId: .parentId}' debug_todo.json

echo ""
echo "Testing with count 4 to see all suggestions..."
TODO_FILE=debug_todo.json bash scripts/next.sh --count 4 --format json | jq '.suggestions[] | {taskId: .taskId, title: .title, score: .score, scoring: .scoring}'

echo ""
echo "Testing dependency check for T002..."
bash -c 'source scripts/next.sh && TODO_FILE=debug_todo.json && check_dependencies_satisfied "T002"'