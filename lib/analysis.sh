#!/usr/bin/env bash
# analysis.sh - Task dependency analysis and critical path calculation
# Part of claude-todo system
# Provides critical path analysis, bottleneck identification, and impact assessment

set -euo pipefail

# ============================================================================
# LIBRARY DEPENDENCIES
# ============================================================================

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source required libraries
if [[ -f "$_LIB_DIR/platform-compat.sh" ]]; then
    # shellcheck source=lib/platform-compat.sh
    source "$_LIB_DIR/platform-compat.sh"
else
    echo "ERROR: Cannot find platform-compat.sh in $_LIB_DIR" >&2
    exit 1
fi

# ============================================================================
# CONSTANTS
# ============================================================================

# File paths
CLAUDE_DIR=".claude"
TODO_FILE="${CLAUDE_DIR}/todo.json"

# ============================================================================
# DEPENDENCY GRAPH FUNCTIONS
# ============================================================================

#######################################
# Build dependency graph from tasks
# Outputs: JSON object mapping task_id -> [dependent_task_ids]
#######################################
build_dependency_graph() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "{}"
        return
    fi

    # Build adjacency list: task_id -> tasks that depend on it
    jq -r '
        # Create adjacency list of dependencies
        .tasks |
        reduce .[] as $task (
            {};
            if $task.depends and ($task.depends | length > 0) then
                reduce $task.depends[] as $dep (
                    .;
                    .[$dep] += [$task.id]
                )
            else
                .
            end
        )
    ' "$todo_file"
}

#######################################
# Build reverse dependency graph (task -> its dependencies)
# Outputs: JSON object mapping task_id -> [dependency_task_ids]
#######################################
build_reverse_dependency_graph() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "{}"
        return
    fi

    jq -r '
        .tasks |
        reduce .[] as $task (
            {};
            if $task.depends and ($task.depends | length > 0) then
                .[$task.id] = $task.depends
            else
                .[$task.id] = []
            end
        )
    ' "$todo_file"
}

#######################################
# Get all tasks that are not completed
# Outputs: Array of task objects
#######################################
get_incomplete_tasks() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "[]"
        return
    fi

    jq -r '[.tasks[] | select(.status != "done")]' "$todo_file"
}

#######################################
# Find longest path from a given task (DFS)
# Args: $1 = task_id, $2 = dependency_graph (JSON), $3 = visited set (JSON array)
# Outputs: Length of longest path
#######################################
find_longest_path_from() {
    local task_id="$1"
    local dep_graph="$2"
    local visited="$3"

    # Check if already visited (cycle detection)
    if echo "$visited" | jq -e --arg id "$task_id" '. | index($id)' >/dev/null 2>&1; then
        echo "0"
        return
    fi

    # Add to visited
    local new_visited
    new_visited=$(echo "$visited" | jq --arg id "$task_id" '. + [$id]')

    # Get dependents (tasks that depend on this one)
    local dependents
    dependents=$(echo "$dep_graph" | jq -r --arg id "$task_id" '.[$id] // []')

    # If no dependents, path length is 1
    local dep_count
    dep_count=$(echo "$dependents" | jq -r 'length')

    if [[ "$dep_count" -eq 0 ]]; then
        echo "1"
        return
    fi

    # Find max path through dependents
    local max_length=0
    while IFS= read -r dep_id; do
        if [[ -n "$dep_id" ]]; then
            local path_length
            path_length=$(find_longest_path_from "$dep_id" "$dep_graph" "$new_visited")
            if [[ "$path_length" -gt "$max_length" ]]; then
                max_length="$path_length"
            fi
        fi
    done < <(echo "$dependents" | jq -r '.[]')

    echo "$((max_length + 1))"
}

#######################################
# Find critical path (longest dependency chain)
# Outputs: JSON object with critical path information
#######################################
find_critical_path() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo '{"path": [], "length": 0, "error": "No tasks found"}'
        return
    fi

    # Get incomplete tasks
    local incomplete_tasks
    incomplete_tasks=$(get_incomplete_tasks "$todo_file")

    local task_count
    task_count=$(echo "$incomplete_tasks" | jq -r 'length')

    if [[ "$task_count" -eq 0 ]]; then
        echo '{"path": [], "length": 0, "message": "All tasks completed"}'
        return
    fi

    # Build dependency graph
    local dep_graph
    dep_graph=$(build_dependency_graph "$todo_file")

    # Find root tasks (tasks with no dependencies or satisfied dependencies)
    local root_tasks
    root_tasks=$(jq -r '
        [.tasks[] |
         select(.status != "done") |
         select(
            (.depends == null or .depends == []) or
            (.depends | length == 0)
         ) | .id
        ]
    ' "$todo_file")

    # Find longest path from each root
    local max_path_length=0
    local max_path_start=""

    while IFS= read -r root_id; do
        if [[ -n "$root_id" ]]; then
            local path_length
            path_length=$(find_longest_path_from "$root_id" "$dep_graph" "[]")

            if [[ "$path_length" -gt "$max_path_length" ]]; then
                max_path_length="$path_length"
                max_path_start="$root_id"
            fi
        fi
    done < <(echo "$root_tasks" | jq -r '.[]')

    # Build the actual path chain
    if [[ -n "$max_path_start" && "$max_path_length" -gt 0 ]]; then
        local path_chain
        path_chain=$(build_path_chain "$max_path_start" "$dep_graph" "$todo_file")

        jq -n \
            --argjson path "$path_chain" \
            --arg length "$max_path_length" \
            '{path: $path, length: ($length | tonumber)}'
    else
        echo '{"path": [], "length": 0, "message": "No dependency chains found"}'
    fi
}

#######################################
# Build the actual path chain from a starting task
# Args: $1 = start_task_id, $2 = dependency_graph, $3 = todo_file
# Outputs: JSON array of task objects in path order
#######################################
build_path_chain() {
    local current_id="$1"
    local dep_graph="$2"
    local todo_file="$3"

    local path="[]"
    local visited="[]"

    while true; do
        # Add current task to path
        local current_task
        current_task=$(jq -r --arg id "$current_id" \
            '.tasks[] | select(.id == $id) | {id, title, status, priority}' \
            "$todo_file")

        if [[ -z "$current_task" || "$current_task" == "null" ]]; then
            break
        fi

        path=$(echo "$path" | jq --argjson task "$current_task" '. + [$task]')

        # Mark as visited
        visited=$(echo "$visited" | jq --arg id "$current_id" '. + [$id]')

        # Find next task (dependent with longest remaining path)
        local dependents
        dependents=$(echo "$dep_graph" | jq -r --arg id "$current_id" '.[$id] // []')

        local next_id=""
        local max_remaining=0

        while IFS= read -r dep_id; do
            if [[ -n "$dep_id" ]]; then
                # Skip if already visited
                if echo "$visited" | jq -e --arg id "$dep_id" '. | index($id)' >/dev/null 2>&1; then
                    continue
                fi

                local remaining
                remaining=$(find_longest_path_from "$dep_id" "$dep_graph" "$visited")

                if [[ "$remaining" -gt "$max_remaining" ]]; then
                    max_remaining="$remaining"
                    next_id="$dep_id"
                fi
            fi
        done < <(echo "$dependents" | jq -r '.[]')

        if [[ -z "$next_id" ]]; then
            break
        fi

        current_id="$next_id"
    done

    echo "$path"
}

#######################################
# Find bottleneck tasks (tasks that block the most others)
# Outputs: JSON array of {task_id, title, blocks_count, blocked_tasks}
#######################################
find_bottlenecks() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "[]"
        return
    fi

    # Build dependency graph
    local dep_graph
    dep_graph=$(build_dependency_graph "$todo_file")

    # Count how many tasks each incomplete task blocks
    jq -r --argjson graph "$dep_graph" '
        [.tasks[] |
         select(.status != "done") |
         {
            id,
            title,
            status,
            priority,
            blocks_count: ($graph[.id] // [] | length),
            blocked_tasks: ($graph[.id] // [])
         }
        ] | sort_by(-.blocks_count)
    ' "$todo_file"
}

#######################################
# Calculate impact of a task (how many tasks affected if delayed)
# Args: $1 = task_id
# Outputs: JSON object with impact information
#######################################
calculate_impact() {
    local task_id="$1"
    local todo_file="${2:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo '{"affected_count": 0, "affected_tasks": []}'
        return
    fi

    # Build dependency graph
    local dep_graph
    dep_graph=$(build_dependency_graph "$todo_file")

    # Use BFS to find all transitively dependent tasks
    local affected="[]"
    local queue="[\"$task_id\"]"
    local visited="[]"

    while true; do
        local queue_length
        queue_length=$(echo "$queue" | jq -r 'length')

        if [[ "$queue_length" -eq 0 ]]; then
            break
        fi

        # Dequeue
        local current
        current=$(echo "$queue" | jq -r '.[0]')
        queue=$(echo "$queue" | jq -r '.[1:]')

        # Skip if visited
        if echo "$visited" | jq -e --arg id "$current" '. | index($id)' >/dev/null 2>&1; then
            continue
        fi

        # Mark visited
        visited=$(echo "$visited" | jq --arg id "$current" '. + [$id]')

        # Get dependents
        local dependents
        dependents=$(echo "$dep_graph" | jq -r --arg id "$current" '.[$id] // []')

        # Add dependents to affected and queue
        while IFS= read -r dep_id; do
            if [[ -n "$dep_id" ]]; then
                affected=$(echo "$affected" | jq --arg id "$dep_id" \
                    'if (. | index($id)) then . else . + [$id] end')
                queue=$(echo "$queue" | jq --arg id "$dep_id" '. + [$id]')
            fi
        done < <(echo "$dependents" | jq -r '.[]')
    done

    # Get task details for affected tasks
    local affected_details
    affected_details=$(jq -r --argjson ids "$affected" '
        [.tasks[] | select(.id as $id | $ids | index($id)) | {id, title, status, priority}]
    ' "$todo_file")

    local affected_count
    affected_count=$(echo "$affected_details" | jq -r 'length')

    jq -n \
        --arg count "$affected_count" \
        --argjson tasks "$affected_details" \
        '{affected_count: ($count | tonumber), affected_tasks: $tasks}'
}

#######################################
# Get all blocked tasks (status=blocked or has unsatisfied dependencies)
# Outputs: JSON array of blocked task objects with blocking reasons
#######################################
get_blocked_tasks() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "[]"
        return
    fi

    jq -r '
        # Build map of task statuses
        (.tasks | map({(.id): .status}) | add) as $statuses |

        # Find tasks that are blocked
        [.tasks[] |
         select(.status != "done") |
         select(
            # Explicitly blocked status
            .status == "blocked" or
            # Has dependencies that are not done
            (
                .depends and
                (.depends | length > 0) and
                (.depends | map($statuses[.] != "done") | any)
            )
         ) |
         {
            id,
            title,
            status,
            priority,
            blocking_reason: (
                if .status == "blocked" then
                    "Explicitly blocked"
                elif .depends then
                    # Find which dependencies are incomplete
                    (.depends | map(select($statuses[.] != "done"))) as $incomplete |
                    "Waiting for: \($incomplete | join(", "))"
                else
                    "Unknown"
                end
            ),
            blocked_by: (
                if .depends then
                    (.depends | map(select($statuses[.] != "done")))
                else
                    []
                end
            )
         }
        ]
    ' "$todo_file"
}

#######################################
# Generate recommendations based on analysis
# Outputs: JSON array of recommendation objects
#######################################
generate_recommendations() {
    local todo_file="${1:-$TODO_FILE}"

    if [[ ! -f "$todo_file" ]]; then
        echo "[]"
        return
    fi

    # Get critical path
    local critical_path
    critical_path=$(find_critical_path "$todo_file")

    # Get bottlenecks
    local bottlenecks
    bottlenecks=$(find_bottlenecks "$todo_file")

    # Get blocked tasks
    local blocked_tasks
    blocked_tasks=$(get_blocked_tasks "$todo_file")

    local recommendations="[]"

    # Recommendation 1: Work on critical path
    local critical_path_length
    critical_path_length=$(echo "$critical_path" | jq -r '.length')

    if [[ "$critical_path_length" -gt 0 ]]; then
        local first_task
        first_task=$(echo "$critical_path" | jq -r '.path[0]')

        if [[ -n "$first_task" && "$first_task" != "null" ]]; then
            local task_id
            task_id=$(echo "$first_task" | jq -r '.id')
            local task_title
            task_title=$(echo "$first_task" | jq -r '.title')

            recommendations=$(jq -n \
                --argjson recs "$recommendations" \
                --arg id "$task_id" \
                --arg title "$task_title" \
                --arg length "$critical_path_length" \
                '$recs + [{
                    priority: 1,
                    type: "critical_path",
                    task_id: $id,
                    message: "Start with \($id) \"\($title)\" - first task on critical path (\($length) tasks deep)"
                }]')
        fi
    fi

    # Recommendation 2: Address top bottlenecks
    local top_bottleneck
    top_bottleneck=$(echo "$bottlenecks" | jq -r '.[0]')

    if [[ -n "$top_bottleneck" && "$top_bottleneck" != "null" ]]; then
        local blocks_count
        blocks_count=$(echo "$top_bottleneck" | jq -r '.blocks_count')

        if [[ "$blocks_count" -gt 0 ]]; then
            local task_id
            task_id=$(echo "$top_bottleneck" | jq -r '.id')
            local task_title
            task_title=$(echo "$top_bottleneck" | jq -r '.title')

            recommendations=$(jq -n \
                --argjson recs "$recommendations" \
                --arg id "$task_id" \
                --arg title "$task_title" \
                --arg count "$blocks_count" \
                '$recs + [{
                    priority: 2,
                    type: "bottleneck",
                    task_id: $id,
                    message: "Prioritize \($id) \"\($title)\" - blocks \($count) other tasks"
                }]')
        fi
    fi

    # Recommendation 3: Resolve blocked tasks
    local blocked_count
    blocked_count=$(echo "$blocked_tasks" | jq -r 'length')

    if [[ "$blocked_count" -gt 0 ]]; then
        recommendations=$(jq -n \
            --argjson recs "$recommendations" \
            --arg count "$blocked_count" \
            '$recs + [{
                priority: 3,
                type: "blocked",
                message: "\($count) tasks are blocked - review dependencies and unblock where possible"
            }]')
    fi

    # Recommendation 4: No blockers - work on high priority
    if [[ "$critical_path_length" -eq 0 && "$blocks_count" -eq 0 ]]; then
        recommendations=$(jq -n \
            --argjson recs "$recommendations" \
            '$recs + [{
                priority: 1,
                type: "priority",
                message: "No critical dependencies - focus on highest priority tasks"
            }]')
    fi

    echo "$recommendations"
}
