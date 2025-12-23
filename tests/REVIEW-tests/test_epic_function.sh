#!/usr/bin/env bash

# Test get_task_epic function
set -e

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
    }
  ],
  "focus": {"currentTask": "T001"},
  "labels": {},
  "lastUpdated": "2025-12-01T10:03:00Z"
}
EOF

# Source the get_task_epic function from next.sh
get_task_epic() {
  local task_id="$1"
  local todo_file="$2"
  local current_id="$task_id"
  local max_depth=5
  local depth=0

  while [[ $depth -lt $max_depth ]]; do
    local task_data=$(jq --arg id "$current_id" '.tasks[] | select(.id == $id)' "$todo_file")
    local task_type=$(echo "$task_data" | jq -r '.type // "task"')
    local parent_id=$(echo "$task_data" | jq -r '.parentId // ""')

    if [[ "$task_type" == "epic" ]]; then
      echo "$current_id"
      return
    fi

    if [[ -z "$parent_id" || "$parent_id" == "null" ]]; then
      break
    fi

    current_id="$parent_id"
    ((depth++))
  done

  echo ""  # No epic found
}

echo "Testing get_task_epic function..."
echo "T001 epic: $(get_task_epic "T001" test_todo.json)"
echo "T002 task: $(get_task_epic "T002" test_todo.json)"

# Test with focus
echo ""
echo "Testing focus epic detection..."
focus_task=$(jq -r '.focus.currentTask // ""' test_todo.json)
echo "Focus task: $focus_task"
focus_epic=$(get_task_epic "$focus_task" test_todo.json)
echo "Focus epic: $focus_epic"

# Test task epic
echo ""
echo "Testing task epic detection..."
task_epic=$(get_task_epic "T002" test_todo.json)
echo "Task T002 epic: $task_epic"