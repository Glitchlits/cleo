#!/usr/bin/env bash
# =============================================================================
# fixtures.bash - Test data generators for claude-todo BATS tests
# =============================================================================
# DRY: Parameterized fixture generators avoid duplication in test files.
# All fixtures use consistent JSON structure matching claude-todo schema.
# =============================================================================

# Base meta block used in all todo.json fixtures
_todo_meta() {
    cat << 'EOF'
  "_meta": {"version": "2.1.0", "checksum": "test123"},
EOF
}

# =============================================================================
# Empty/Minimal Fixtures
# =============================================================================

# Create empty todo.json (no tasks)
create_empty_todo() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0"},
  "tasks": [],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# =============================================================================
# Basic Task Fixtures
# =============================================================================

# Create todo.json with independent tasks (no dependencies)
create_independent_tasks() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0", "checksum": "45d3a950c7012ac9"},
  "tasks": [
    {"id": "T001", "title": "First task", "description": "Task one", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T10:00:00Z"},
    {"id": "T002", "title": "Second task", "description": "Task two", "status": "pending", "priority": "high", "createdAt": "2025-12-01T11:00:00Z"},
    {"id": "T003", "title": "Third task", "description": "Task three", "status": "pending", "priority": "low", "createdAt": "2025-12-01T12:00:00Z"}
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# Create todo.json with a completed task
create_tasks_with_completed() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0"},
  "tasks": [
    {"id": "T001", "title": "Completed task", "description": "Done", "status": "done", "priority": "high", "createdAt": "2025-12-01T10:00:00Z", "completedAt": "2025-12-10T12:00:00Z"},
    {"id": "T002", "title": "Pending task", "description": "Not done", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T11:00:00Z"}
  ],
  "focus": {},
  "lastUpdated": "2025-12-10T12:00:00Z"
}
EOF
}

# =============================================================================
# Dependency Chain Fixtures
# =============================================================================

# Create simple linear dependency chain: T001 <- T002 <- T003
create_linear_chain() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0", "checksum": "test123"},
  "tasks": [
    {"id": "T001", "title": "Foundation task", "description": "Base", "status": "pending", "priority": "high", "createdAt": "2025-12-01T10:00:00Z"},
    {"id": "T002", "title": "Depends on T001", "description": "Middle", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T11:00:00Z", "depends": ["T001"]},
    {"id": "T003", "title": "Depends on T002", "description": "End", "status": "pending", "priority": "low", "createdAt": "2025-12-01T12:00:00Z", "depends": ["T002"]}
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# Create complex dependency graph with multiple roots
create_complex_deps() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0"},
  "tasks": [
    {"id": "T001", "title": "Core module", "description": "Core", "status": "pending", "priority": "critical", "createdAt": "2025-12-01T10:00:00Z"},
    {"id": "T002", "title": "Auth module", "description": "Auth", "status": "pending", "priority": "high", "createdAt": "2025-12-01T11:00:00Z"},
    {"id": "T003", "title": "Depends on T001 and T002", "description": "Combined", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T12:00:00Z", "depends": ["T001", "T002"]},
    {"id": "T004", "title": "Depends on T003", "description": "Final", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T13:00:00Z", "depends": ["T003"]},
    {"id": "T005", "title": "Independent task", "description": "Alone", "status": "pending", "priority": "low", "createdAt": "2025-12-01T14:00:00Z"}
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T14:00:00Z"
}
EOF
}

# =============================================================================
# Blocked Task Fixtures
# =============================================================================

# Create todo.json with blocked tasks
create_blocked_tasks() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0", "checksum": "test123"},
  "tasks": [
    {"id": "T001", "title": "Foundation task", "description": "Base", "status": "pending", "priority": "high", "createdAt": "2025-12-01T10:00:00Z"},
    {"id": "T002", "title": "Blocked by T001", "description": "Waiting", "status": "blocked", "priority": "medium", "createdAt": "2025-12-01T11:00:00Z", "depends": ["T001"], "blockedBy": "Waiting for T001"},
    {"id": "T003", "title": "Blocked by T002", "description": "Waiting more", "status": "blocked", "priority": "low", "createdAt": "2025-12-01T12:00:00Z", "depends": ["T002"], "blockedBy": "Waiting for T002"}
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# Create todo.json with task blocked by multiple dependencies
create_multi_blocker_tasks() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0", "checksum": "test123"},
  "tasks": [
    {"id": "T001", "title": "First dependency", "description": "Dep 1", "status": "pending", "priority": "high", "createdAt": "2025-12-01T10:00:00Z"},
    {"id": "T002", "title": "Second dependency", "description": "Dep 2", "status": "pending", "priority": "high", "createdAt": "2025-12-01T11:00:00Z"},
    {"id": "T003", "title": "Blocked by T001 and T002", "description": "Multi-blocked", "status": "blocked", "priority": "medium", "createdAt": "2025-12-01T12:00:00Z", "depends": ["T001", "T002"], "blockedBy": "Waiting for T001 and T002"}
  ],
  "focus": {},
  "lastUpdated": "2025-12-01T12:00:00Z"
}
EOF
}

# Create todo.json with completed blocker (task should be unblocked)
create_completed_blocker() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0"},
  "tasks": [
    {"id": "T001", "title": "Completed blocker", "description": "Done", "status": "done", "priority": "high", "createdAt": "2025-12-01T10:00:00Z", "completedAt": "2025-12-10T12:00:00Z"},
    {"id": "T002", "title": "Was blocked by T001", "description": "Now unblocked", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T11:00:00Z", "depends": ["T001"]}
  ],
  "focus": {}
}
EOF
}

# =============================================================================
# Circular Dependency Fixtures (for validation testing)
# =============================================================================

# Create todo.json with direct circular dependency (invalid state)
create_circular_deps() {
    local dest="${1:-$TODO_FILE}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0"},
  "tasks": [
    {"id": "T001", "title": "A depends on B", "description": "Circular A", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T10:00:00Z", "depends": ["T002"]},
    {"id": "T002", "title": "B depends on A", "description": "Circular B", "status": "pending", "priority": "medium", "createdAt": "2025-12-01T11:00:00Z", "depends": ["T001"]}
  ],
  "focus": {}
}
EOF
}

# =============================================================================
# Parameterized Fixture Generators
# =============================================================================

# Create a task with specific properties
create_task_with_props() {
    local id="$1"
    local title="$2"
    local status="${3:-pending}"
    local priority="${4:-medium}"
    local depends="${5:-}"

    local deps_json="null"
    if [[ -n "$depends" ]]; then
        deps_json=$(echo "$depends" | jq -R 'split(",")')
    fi

    jq --arg id "$id" \
       --arg title "$title" \
       --arg status "$status" \
       --arg priority "$priority" \
       --argjson depends "$deps_json" \
       '.tasks += [{
         "id": $id,
         "title": $title,
         "description": ($title + " description"),
         "status": $status,
         "priority": $priority,
         "createdAt": "2025-12-01T10:00:00Z"
       } + (if $depends then {"depends": $depends} else {} end)]' \
       "$TODO_FILE" > "${TODO_FILE}.tmp" && mv "${TODO_FILE}.tmp" "$TODO_FILE"
}

# Add a single task to existing todo.json
add_task_to_fixture() {
    local id="$1"
    local title="$2"
    local status="${3:-pending}"

    jq --arg id "$id" \
       --arg title "$title" \
       --arg status "$status" \
       '.tasks += [{
         "id": $id,
         "title": $title,
         "description": ($title + " description"),
         "status": $status,
         "priority": "medium",
         "createdAt": "2025-12-01T10:00:00Z"
       }]' "$TODO_FILE" > "${TODO_FILE}.tmp" && mv "${TODO_FILE}.tmp" "$TODO_FILE"
}

# Add dependency to existing task
add_dependency_to_fixture() {
    local task_id="$1"
    local dep_id="$2"

    jq --arg id "$task_id" \
       --arg dep "$dep_id" \
       '(.tasks[] | select(.id == $id) | .depends) += [$dep]' \
       "$TODO_FILE" > "${TODO_FILE}.tmp" && mv "${TODO_FILE}.tmp" "$TODO_FILE"
}

# =============================================================================
# Archive Fixtures
# =============================================================================

# Create empty archive file
create_empty_archive() {
    local dest="${1:-${ARCHIVE_FILE:-${TEST_TEMP_DIR}/.claude/todo-archive.json}}"
    cat > "$dest" << 'EOF'
{
  "_meta": {"version": "2.1.0", "checksum": "test123"},
  "archivedTasks": [],
  "lastArchived": null
}
EOF
}
