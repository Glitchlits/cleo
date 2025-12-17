#!/usr/bin/env bash

#####################################################################
# analyze.sh - Task Analysis and Prioritization Command
#
# Analyzes task dependencies to identify high-leverage work:
# - Calculates task leverage (how many tasks each unblocks)
# - Identifies bottlenecks (tasks blocking the most others)
# - Tiers tasks by strategic value
# - Provides actionable recommendations
#
# Usage:
#   analyze.sh [OPTIONS]
#
# Options:
#   --full            Show comprehensive analysis with all tiers
#   --json            Output in machine-readable JSON format
#   --auto-focus      Automatically set focus to recommended task
#   -h, --help        Show this help message
#
# Output Modes:
#   Brief (default):  Top leverage tasks, bottlenecks, tier summary
#   Full:             Complete analysis with all tiers and metrics
#   JSON:             Structured data for scripting/automation
#
# Version: 0.15.0
# Part of: claude-todo Advanced Analysis System
#####################################################################

set -euo pipefail

# Script and library paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/../lib"
CLAUDE_TODO_HOME="${CLAUDE_TODO_HOME:-$HOME/.claude-todo}"

# Source library functions
if [[ -f "${LIB_DIR}/file-ops.sh" ]]; then
  source "${LIB_DIR}/file-ops.sh"
elif [[ -f "$CLAUDE_TODO_HOME/lib/file-ops.sh" ]]; then
  source "$CLAUDE_TODO_HOME/lib/file-ops.sh"
fi

if [[ -f "${LIB_DIR}/logging.sh" ]]; then
  source "${LIB_DIR}/logging.sh"
elif [[ -f "$CLAUDE_TODO_HOME/lib/logging.sh" ]]; then
  source "$CLAUDE_TODO_HOME/lib/logging.sh"
fi

if [[ -f "${LIB_DIR}/output-format.sh" ]]; then
  source "${LIB_DIR}/output-format.sh"
elif [[ -f "$CLAUDE_TODO_HOME/lib/output-format.sh" ]]; then
  source "$CLAUDE_TODO_HOME/lib/output-format.sh"
fi

if [[ -f "${LIB_DIR}/analysis.sh" ]]; then
  source "${LIB_DIR}/analysis.sh"
elif [[ -f "$CLAUDE_TODO_HOME/lib/analysis.sh" ]]; then
  source "$CLAUDE_TODO_HOME/lib/analysis.sh"
fi

# Default configuration
OUTPUT_MODE="brief"
AUTO_FOCUS=false

# File paths
CLAUDE_DIR=".claude"
TODO_FILE="${CLAUDE_DIR}/todo.json"

#####################################################################
# Usage
#####################################################################

usage() {
  cat << 'EOF'
Usage: claude-todo analyze [OPTIONS]

Analyze task dependencies and identify high-leverage work.

Options:
    --full          Show comprehensive analysis with all tiers
    --json          Output in machine-readable JSON format
    --auto-focus    Automatically set focus to recommended task
    -h, --help      Show this help message

Analysis Components:
    Leverage:       How many tasks each task unblocks
    Bottlenecks:    Tasks blocking the most others
    Tiers:          Strategic grouping (1=Unblock, 2=Critical, 3=Progress, 4=Routine)
    Recommendation: Suggested next task to maximize impact

Output Modes:
    Brief (default):  Summary with top tasks and recommendation
    Full (--full):    Complete analysis with all tiers
    JSON (--json):    Structured data for automation

Examples:
    claude-todo analyze                    # Brief analysis
    claude-todo analyze --full             # Comprehensive report
    claude-todo analyze --json             # JSON output
    claude-todo analyze --auto-focus       # Analyze and set focus

Exit Codes:
    0:  Success
    1:  Error (file not found, jq missing)
    2:  No tasks to analyze
EOF
  exit 0
}

#####################################################################
# Helper Functions
#####################################################################

# Get ANSI color codes (respects NO_COLOR)
get_colors() {
  if detect_color_support 2>/dev/null; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
  else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' BOLD='' DIM='' NC=''
  fi
}

# Build leverage map (task_id -> count of tasks it unblocks)
build_leverage_map() {
  local todo_file="$1"

  # Build dependency graph: task -> [tasks that depend on it]
  jq -r '
    # Build adjacency list
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
    ) |
    # Count direct + transitive dependents
    to_entries |
    map({
      id: .key,
      unlocks: (.value | length)
    })
  ' "$todo_file"
}

# Calculate leverage scores with transitive dependencies
calculate_leverage_scores() {
  local todo_file="$1"

  # Build dependency graph: task -> [tasks that depend on it]
  local dep_graph
  if declare -f build_dependency_graph >/dev/null 2>&1; then
    dep_graph=$(build_dependency_graph "$todo_file")
  else
    # Fallback: build inline
    dep_graph=$(jq -r '
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
    ' "$todo_file")
  fi

  # For each pending task, count transitive dependents
  jq -r --argjson graph "$dep_graph" '
    [.tasks[] |
     select(.status == "pending" or .status == "active") |
     {
       id,
       title,
       priority,
       status,
       unlocks: ($graph[.id] // [] | length)
     }
    ] | sort_by(-.unlocks)
  ' "$todo_file"
}

# Identify bottlenecks (use existing function from analysis.sh)
get_bottlenecks() {
  local todo_file="$1"

  if declare -f find_bottlenecks >/dev/null 2>&1; then
    find_bottlenecks "$todo_file" | jq -r '[.[] | select(.blocks_count > 0)] | sort_by(-.blocks_count) | .[0:5]'
  else
    echo "[]"
  fi
}

# Categorize tasks into tiers
tier_tasks() {
  local todo_file="$1"

  local leverage_scores
  leverage_scores=$(calculate_leverage_scores "$todo_file")

  local bottlenecks
  bottlenecks=$(get_bottlenecks "$todo_file")

  # Tier logic:
  # Tier 1: Unlocks 5+ tasks OR is a top-3 bottleneck
  # Tier 2: High/critical priority AND unlocks 2-4 tasks
  # Tier 3: Medium priority OR unlocks 1 task
  # Tier 4: Low priority, no dependencies

  jq -n \
    --argjson scores "$leverage_scores" \
    --argjson bottlenecks "$bottlenecks" \
    '{
      tier1: ($scores | map(select(.unlocks >= 5)) + ($bottlenecks | .[0:3] | map({id, title, unlocks: .blocks_count, priority})) | unique_by(.id)),
      tier2: ($scores | map(select(.unlocks >= 2 and .unlocks < 5 and (.priority == "high" or .priority == "critical")))),
      tier3: ($scores | map(select(.unlocks == 1 or .priority == "medium"))),
      tier4: ($scores | map(select(.unlocks == 0 and .priority == "low")))
    }'
}

# Get recommendation
get_recommendation() {
  local tiers="$1"

  # Prefer Tier 1, then Tier 2
  local recommended
  recommended=$(echo "$tiers" | jq -r '
    if (.tier1 | length) > 0 then
      .tier1[0] | {task: .id, reason: "Unlocks \(.unlocks) tasks"}
    elif (.tier2 | length) > 0 then
      .tier2[0] | {task: .id, reason: "High priority with dependencies"}
    elif (.tier3 | length) > 0 then
      .tier3[0] | {task: .id, reason: "Progress task"}
    else
      null
    end
  ')

  echo "$recommended"
}

#####################################################################
# Output Formatters
#####################################################################

# Output brief format
output_brief() {
  get_colors

  local todo_file="$1"
  local pending_count
  pending_count=$(jq -r '[.tasks[] | select(.status == "pending")] | length' "$todo_file")

  if [[ "$pending_count" -eq 0 ]]; then
    echo ""
    echo -e "${YELLOW}No pending tasks to analyze.${NC}"
    echo ""
    exit 2
  fi

  local unicode
  detect_unicode_support 2>/dev/null && unicode="true" || unicode="false"

  local leverage_scores
  leverage_scores=$(calculate_leverage_scores "$todo_file")

  local bottlenecks
  bottlenecks=$(get_bottlenecks "$todo_file")

  local tiers
  tiers=$(tier_tasks "$todo_file")

  local recommendation
  recommendation=$(get_recommendation "$tiers")

  echo ""
  if [[ "$unicode" == "true" ]]; then
    echo -e "${BOLD}⚡ TASK ANALYSIS${NC} ${DIM}($pending_count pending)${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo -e "${BOLD}TASK ANALYSIS${NC} ${DIM}($pending_count pending)${NC}"
    echo -e "========================================"
  fi
  echo ""

  # Highest Leverage
  echo -e "${BOLD}${CYAN}🎯 HIGHEST LEVERAGE${NC}"
  local top_leverage
  top_leverage=$(echo "$leverage_scores" | jq -c '.[0:2]')
  if [[ "$(echo "$top_leverage" | jq 'length')" -gt 0 ]]; then
    echo "$top_leverage" | jq -c '.[]' | while read -r task; do
      local id title unlocks
      id=$(echo "$task" | jq -r '.id')
      title=$(echo "$task" | jq -r '.title')
      unlocks=$(echo "$task" | jq -r '.unlocks')

      if [[ "$unlocks" -gt 0 ]]; then
        # Truncate title if too long
        if [[ ${#title} -gt 50 ]]; then
          title="${title:0:47}..."
        fi
        echo -e "  ${BOLD}$id${NC} → Unlocks $unlocks tasks ${DIM}($title)${NC}"
      fi
    done
  else
    echo -e "  ${DIM}No tasks unblock others${NC}"
  fi
  echo ""

  # Bottlenecks
  local bottleneck_count
  bottleneck_count=$(echo "$bottlenecks" | jq 'length')
  if [[ "$bottleneck_count" -gt 0 ]]; then
    echo -e "${BOLD}${RED}🚨 BOTTLENECKS${NC}"
    echo "$bottlenecks" | jq -c '.[0:2]' | jq -c '.[]' | while read -r task; do
      local id title blocks_count blocked_tasks
      id=$(echo "$task" | jq -r '.id')
      title=$(echo "$task" | jq -r '.title')
      blocks_count=$(echo "$task" | jq -r '.blocks_count')
      blocked_tasks=$(echo "$task" | jq -r '.blocked_tasks | join(",") | split(",") | .[0:11] | join(",")')

      if [[ ${#title} -gt 40 ]]; then
        title="${title:0:37}..."
      fi

      echo -e "  ${BOLD}$id${NC} blocks: ${YELLOW}$blocked_tasks${NC}${DIM}...${NC} ${DIM}($blocks_count total)${NC}"
    done
    echo ""
  fi

  # Tier Summary
  echo -e "${BOLD}${BLUE}📊 TIERS${NC}"
  local tier1_count tier2_count tier3_count tier4_count
  tier1_count=$(echo "$tiers" | jq '.tier1 | length')
  tier2_count=$(echo "$tiers" | jq '.tier2 | length')
  tier3_count=$(echo "$tiers" | jq '.tier3 | length')
  tier4_count=$(echo "$tiers" | jq '.tier4 | length')

  echo -e "  ${BOLD}Tier 1${NC} (Unblock): ${CYAN}$tier1_count${NC} task(s)"
  if [[ "$tier1_count" -gt 0 ]]; then
    echo "$tiers" | jq -r '.tier1[0:3] | .[] | "    \(.id)"'
  fi

  echo -e "  ${BOLD}Tier 2${NC} (Critical): ${YELLOW}$tier2_count${NC} task(s)"
  if [[ "$tier2_count" -gt 0 ]]; then
    echo "$tiers" | jq -r '.tier2[0:3] | .[] | "    \(.id)"'
  fi

  echo -e "  ${BOLD}Tier 3${NC} (Progress): ${GREEN}$tier3_count${NC} task(s)"
  echo -e "  ${BOLD}Tier 4${NC} (Routine): ${DIM}$tier4_count${NC} task(s)"
  echo ""

  # Recommendation
  if [[ -n "$recommendation" && "$recommendation" != "null" ]]; then
    local rec_task rec_reason
    rec_task=$(echo "$recommendation" | jq -r '.task')
    rec_reason=$(echo "$recommendation" | jq -r '.reason')

    echo -e "${BOLD}${GREEN}→ RECOMMENDED${NC}: ${CYAN}ct focus set $rec_task${NC}"
    echo -e "  ${DIM}$rec_reason${NC}"
  else
    echo -e "${BOLD}${GREEN}→ RECOMMENDED${NC}: ${DIM}Work on highest priority task${NC}"
  fi

  echo ""
}

# Output full format
output_full() {
  output_brief "$1"

  get_colors

  local todo_file="$1"
  local tiers
  tiers=$(tier_tasks "$todo_file")

  echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
  echo -e "${BOLD}DETAILED TIER BREAKDOWN${NC}"
  echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}"
  echo ""

  # Tier 1
  echo -e "${BOLD}${CYAN}Tier 1 - Unblock${NC} ${DIM}(High leverage - unblocks multiple tasks)${NC}"
  local tier1
  tier1=$(echo "$tiers" | jq -c '.tier1[]')
  if [[ -n "$tier1" ]]; then
    echo "$tier1" | while read -r task; do
      local id title unlocks priority
      id=$(echo "$task" | jq -r '.id')
      title=$(echo "$task" | jq -r '.title')
      unlocks=$(echo "$task" | jq -r '.unlocks')
      priority=$(echo "$task" | jq -r '.priority')

      if [[ ${#title} -gt 55 ]]; then
        title="${title:0:52}..."
      fi

      echo -e "  ${BOLD}$id${NC} [$priority] $title ${DIM}(unlocks: $unlocks)${NC}"
    done
  else
    echo -e "  ${DIM}None${NC}"
  fi
  echo ""

  # Tier 2
  echo -e "${BOLD}${YELLOW}Tier 2 - Critical${NC} ${DIM}(High priority with dependencies)${NC}"
  local tier2
  tier2=$(echo "$tiers" | jq -c '.tier2[]')
  if [[ -n "$tier2" ]]; then
    echo "$tier2" | while read -r task; do
      local id title priority
      id=$(echo "$task" | jq -r '.id')
      title=$(echo "$task" | jq -r '.title')
      priority=$(echo "$task" | jq -r '.priority')

      if [[ ${#title} -gt 55 ]]; then
        title="${title:0:52}..."
      fi

      echo -e "  ${BOLD}$id${NC} [$priority] $title"
    done
  else
    echo -e "  ${DIM}None${NC}"
  fi
  echo ""

  # Tier 3
  echo -e "${BOLD}${GREEN}Tier 3 - Progress${NC} ${DIM}(Standard work)${NC}"
  local tier3_count
  tier3_count=$(echo "$tiers" | jq '.tier3 | length')
  echo -e "  ${tier3_count} task(s) - Use ${CYAN}ct list --priority medium${NC} to view"
  echo ""

  # Tier 4
  echo -e "${BOLD}${DIM}Tier 4 - Routine${NC} ${DIM}(Low priority, no dependencies)${NC}"
  local tier4_count
  tier4_count=$(echo "$tiers" | jq '.tier4 | length')
  echo -e "  ${tier4_count} task(s) - Use ${CYAN}ct list --priority low${NC} to view"
  echo ""
}

# Output JSON format
output_json() {
  local todo_file="$1"
  local pending_count
  pending_count=$(jq -r '[.tasks[] | select(.status == "pending")] | length' "$todo_file")

  local leverage_scores
  leverage_scores=$(calculate_leverage_scores "$todo_file")

  local bottlenecks
  bottlenecks=$(get_bottlenecks "$todo_file")

  local tiers
  tiers=$(tier_tasks "$todo_file")

  local recommendation
  recommendation=$(get_recommendation "$tiers")

  local tier1_count tier2_count tier3_count tier4_count
  tier1_count=$(echo "$tiers" | jq '.tier1 | length')
  tier2_count=$(echo "$tiers" | jq '.tier2 | length')
  tier3_count=$(echo "$tiers" | jq '.tier3 | length')
  tier4_count=$(echo "$tiers" | jq '.tier4 | length')

  local unblocked_count
  unblocked_count=$(jq -r '[.tasks[] | select(.status == "pending") | select((.depends // [] | length) == 0)] | length' "$todo_file")

  local blocked_count
  blocked_count=$(jq -r '[.tasks[] | select(.status == "blocked")] | length' "$todo_file")

  jq -n \
    --argjson pending "$pending_count" \
    --argjson blocked "$blocked_count" \
    --argjson unblocked "$unblocked_count" \
    --argjson leverage "$leverage_scores" \
    --argjson bottlenecks "$bottlenecks" \
    --argjson tiers "$tiers" \
    --argjson recommendation "$recommendation" \
    '{
      "_meta": {
        "version": "0.15.0",
        "generated": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
      },
      "summary": {
        "pending": $pending,
        "blocked": $blocked,
        "unblocked": $unblocked
      },
      "leverage": ($leverage | map(select(.unlocks > 0)) | sort_by(-.unlocks)),
      "bottlenecks": $bottlenecks,
      "tiers": {
        "1": $tiers.tier1,
        "2": $tiers.tier2,
        "3": $tiers.tier3,
        "4": $tiers.tier4
      },
      "recommendation": (if $recommendation then {
        "task": $recommendation.task,
        "reason": $recommendation.reason,
        "command": ("ct focus set " + $recommendation.task)
      } else null end)
    }'
}

#####################################################################
# Argument Parsing
#####################################################################

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --full)
        OUTPUT_MODE="full"
        shift
        ;;
      --json)
        OUTPUT_MODE="json"
        shift
        ;;
      --auto-focus)
        AUTO_FOCUS=true
        shift
        ;;
      --help|-h)
        usage
        ;;
      *)
        echo "[ERROR] Unknown option: $1" >&2
        echo "Run 'claude-todo analyze --help' for usage"
        exit 1
        ;;
    esac
  done
}

#####################################################################
# Main Execution
#####################################################################

main() {
  parse_arguments "$@"

  # Check if in a todo-enabled project
  if [[ ! -f "$TODO_FILE" ]]; then
    echo "[ERROR] Todo file not found: $TODO_FILE" >&2
    echo "Run 'claude-todo init' first" >&2
    exit 1
  fi

  # Check required commands
  if ! command -v jq &>/dev/null; then
    echo "[ERROR] jq is required but not installed" >&2
    exit 1
  fi

  # Output in requested format
  case "$OUTPUT_MODE" in
    json)
      output_json "$TODO_FILE"
      ;;
    full)
      output_full "$TODO_FILE"
      ;;
    brief)
      output_brief "$TODO_FILE"
      ;;
  esac

  # Auto-focus if requested
  if [[ "$AUTO_FOCUS" == "true" && "$OUTPUT_MODE" != "json" ]]; then
    local tiers
    tiers=$(tier_tasks "$TODO_FILE")
    local recommendation
    recommendation=$(get_recommendation "$tiers")

    if [[ -n "$recommendation" && "$recommendation" != "null" ]]; then
      local rec_task
      rec_task=$(echo "$recommendation" | jq -r '.task')

      echo ""
      echo "Setting focus to $rec_task..."
      "$SCRIPT_DIR/focus-command.sh" set "$rec_task"
    fi
  fi
}

main "$@"
