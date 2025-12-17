# analyze Command

Smart task triage and prioritization using leverage scoring and bottleneck detection.

## Usage

```bash
claude-todo analyze [OPTIONS]
```

## Description

The `analyze` command provides intelligent task prioritization by calculating leverage scores, identifying bottlenecks, and detecting critical path dependencies. It combines multiple analysis dimensions to recommend the highest-impact tasks to work on next.

This command is particularly useful for:
- **LLM agents**: Token-efficient output optimized for autonomous task selection
- **Decision paralysis**: Data-driven task prioritization when multiple options exist
- **Project planning**: Understanding dependency chains and bottlenecks
- **Impact assessment**: Identifying which tasks unlock the most downstream work

Unlike the `next` command which suggests a single task based on priority and phase alignment, `analyze` provides comprehensive triage information including leverage scores, bottleneck analysis, and tier-based grouping.

## Algorithm

The analysis engine uses a multi-dimensional scoring system:

### 1. Leverage Score Calculation

Leverage measures downstream impact - how many tasks become unblocked if this task completes:

```
leverage_score = base_priority + cascade_multiplier
```

**Components**:
- **Base Priority**: Task's intrinsic priority (critical=100, high=75, medium=50, low=25)
- **Cascade Multiplier**: Number of transitively dependent tasks × 10

**Example**:
```
Task T001 (high priority) blocks T002, T003
T002 blocks T004, T005
T003 blocks T006

Leverage Score = 75 (high) + (5 tasks × 10) = 125
```

### 2. Bottleneck Detection

Bottlenecks are tasks that block the most other tasks (direct dependents only):

```bash
# Task T010 blocks 8 other tasks directly
bottleneck_score = 8 (direct dependents)
```

### 3. Critical Path Analysis

Identifies the longest dependency chain in the project:

```bash
# Chain: T001 → T002 → T003 → T004 → T005
critical_path_length = 5
```

Tasks on the critical path receive additional priority weighting.

### 4. Tier Assignment

Tasks are automatically grouped into action tiers:

| Tier | Criteria | Action |
|------|----------|--------|
| **Tier 1: Critical** | Critical priority OR bottleneck (blocks ≥3 tasks) | Start immediately |
| **Tier 2: High Impact** | High priority OR leverage score >100 | Prioritize next |
| **Tier 3: Standard** | Medium priority OR has dependencies | Normal queue |
| **Tier 4: Low Priority** | Low priority AND no dependents | Defer or delegate |

## Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--format FORMAT` | `-f` | Output format: `brief`, `full`, `json` | `brief` |
| `--auto-focus` | | Automatically set focus to top recommendation | `false` |
| `--include-blocked` | | Include blocked tasks in analysis | `false` |
| `--help` | `-h` | Show help message | |

## Output Formats

### Brief Format (Default)

Token-efficient output optimized for LLM agents:

```bash
claude-todo analyze
```

Output:
```
TASK TRIAGE ANALYSIS

Tier 1: Critical (2 tasks)
→ T015 [CRITICAL] Implement authentication | Leverage: 150 (blocks 8 tasks)
  T022 [HIGH] Fix database schema | Leverage: 120 (blocks 7 tasks)

Tier 2: High Impact (3 tasks)
  T018 [HIGH] Add error logging | Leverage: 75
  T024 [MEDIUM] Optimize queries | Leverage: 105 (blocks 5 tasks)
  T019 [HIGH] Refactor service layer | Leverage: 80 (blocks 1 task)

Tier 3: Standard (5 tasks)
Tier 4: Low Priority (2 tasks)

BOTTLENECKS:
  T015: blocks 8 tasks
  T022: blocks 7 tasks

CRITICAL PATH: 6 tasks deep
  T015 → T020 → T023 → T027 → T030 → T032

RECOMMENDATION: Start with T015 (highest leverage, critical path start)
```

### Full Format

Detailed analysis with explanations:

```bash
claude-todo analyze --format full
```

Output:
```
COMPREHENSIVE TASK ANALYSIS

PROJECT OVERVIEW
  Total Tasks: 12 (10 pending, 1 active, 1 blocked)
  Critical Path: 6 tasks deep
  Bottlenecks: 2 tasks blocking ≥5 others

TIER 1: CRITICAL (2 tasks)
─────────────────────────────────────────
→ T015 [CRITICAL] Implement user authentication
  Leverage Score: 150
  Blocks: 8 tasks (T020, T023, T027, T030, T032, T035, T038, T041)
  On critical path: YES (position 1/6)
  Phase: core

  Why critical:
  ✓ Critical priority
  ✓ Bottleneck (blocks 8 tasks)
  ✓ First task on critical path
  ✓ Highest leverage score in project

  Downstream impact:
  - Completing this task unlocks 8 immediate dependents
  - Total cascade effect: 10+ tasks become actionable

  Recommendation: START IMMEDIATELY

  T022 [HIGH] Fix database schema migration
  Leverage Score: 120
  Blocks: 7 tasks (T024, T026, T028, T031, T034, T036, T039)
  On critical path: NO
  Phase: core

  Why critical:
  ✓ High priority
  ✓ Major bottleneck (blocks 7 tasks)
  ✓ High leverage score

  Recommendation: PRIORITIZE NEXT

TIER 2: HIGH IMPACT (3 tasks)
─────────────────────────────────────────
  T018 [HIGH] Add comprehensive error logging
  Leverage Score: 75
  Blocks: 0 tasks
  Phase: core

  T024 [MEDIUM] Optimize database queries
  Leverage Score: 105
  Blocks: 5 tasks (T029, T033, T037, T040, T042)
  Phase: core

  T019 [HIGH] Refactor user service layer
  Leverage Score: 80
  Blocks: 1 task (T025)
  Phase: core

TIER 3: STANDARD (5 tasks)
  T025, T026, T028, T029, T031

TIER 4: LOW PRIORITY (2 tasks)
  T043, T044

CRITICAL PATH ANALYSIS
─────────────────────────────────────────
Longest dependency chain: 6 tasks

T015 [CRITICAL] Implement authentication
  ↓
T020 [MEDIUM] Add JWT middleware
  ↓
T023 [MEDIUM] Implement refresh tokens
  ↓
T027 [MEDIUM] Add session management
  ↓
T030 [LOW] Add remember-me feature
  ↓
T032 [LOW] Add login analytics

Impact: Completing T015 enables entire authentication feature chain

BOTTLENECK ANALYSIS
─────────────────────────────────────────
Top bottlenecks (blocking ≥3 tasks):

1. T015 - blocks 8 tasks
2. T022 - blocks 7 tasks
3. T024 - blocks 5 tasks

Resolution strategy:
- Focus on T015 first (critical path + highest block count)
- Then T022 (second-highest blocker)
- T024 can be addressed in parallel if resources available

BLOCKED TASKS
─────────────────────────────────────────
1 task currently blocked:

⊗ T045 [MEDIUM] Deploy to staging
  Blocked by: T015, T022, T024 (waiting for infrastructure)
  Reason: Depends on completed authentication and database schema

STRATEGIC RECOMMENDATION
─────────────────────────────────────────
Focus Strategy: Critical Path + Bottleneck Resolution

Next Actions:
1. T015 (Implement authentication) - START NOW
   → Unblocks 8 tasks, starts critical path

2. T022 (Fix database schema) - QUEUE NEXT
   → Unblocks 7 tasks, enables data layer work

3. T024 (Optimize queries) - PARALLEL TRACK
   → Can start concurrently if team capacity available

Avoid:
- T043, T044 (low priority, no dependents)
- T045 (blocked, wait for dependencies)

Expected Impact:
- Completing T015 + T022 unlocks 15 tasks (75% of pending work)
- Critical path reduces from 6 to 4 tasks
```

### JSON Format

Machine-readable output for scripting and integration:

```bash
claude-todo analyze --format json
```

Output structure:
```json
{
  "_meta": {
    "version": "0.15.0",
    "timestamp": "2025-12-16T10:00:00Z",
    "command": "analyze",
    "algorithm": "leverage_scoring_v1"
  },
  "summary": {
    "total_tasks": 12,
    "pending": 10,
    "active": 1,
    "blocked": 1,
    "critical_path_length": 6,
    "bottleneck_count": 2
  },
  "tiers": {
    "tier1_critical": {
      "count": 2,
      "tasks": [
        {
          "id": "T015",
          "title": "Implement user authentication",
          "status": "pending",
          "priority": "critical",
          "leverage_score": 150,
          "blocks_count": 8,
          "blocked_tasks": ["T020", "T023", "T027", "T030", "T032", "T035", "T038", "T041"],
          "on_critical_path": true,
          "critical_path_position": 1,
          "phase": "core",
          "tier_reason": "critical_priority,bottleneck,critical_path"
        }
      ]
    },
    "tier2_high_impact": {
      "count": 3,
      "tasks": []
    },
    "tier3_standard": {
      "count": 5,
      "task_ids": ["T025", "T026", "T028", "T029", "T031"]
    },
    "tier4_low_priority": {
      "count": 2,
      "task_ids": ["T043", "T044"]
    }
  },
  "critical_path": {
    "length": 6,
    "tasks": [
      {
        "id": "T015",
        "title": "Implement user authentication",
        "status": "pending",
        "priority": "critical"
      },
      {
        "id": "T020",
        "title": "Add JWT middleware",
        "status": "pending",
        "priority": "medium"
      }
    ]
  },
  "bottlenecks": [
    {
      "id": "T015",
      "title": "Implement user authentication",
      "blocks_count": 8,
      "blocked_tasks": ["T020", "T023", "T027", "T030", "T032", "T035", "T038", "T041"]
    }
  ],
  "blocked_tasks": [
    {
      "id": "T045",
      "title": "Deploy to staging",
      "status": "blocked",
      "blocked_by": ["T015", "T022", "T024"],
      "blocking_reason": "Waiting for infrastructure tasks"
    }
  ],
  "recommendation": {
    "action": "start_immediately",
    "task_id": "T015",
    "task_title": "Implement user authentication",
    "reasoning": "Highest leverage (150), blocks 8 tasks, starts critical path",
    "next_tasks": ["T022", "T024"],
    "expected_impact": "Unlocks 15 tasks (75% of pending work)"
  }
}
```

## Use Cases

### 1. Autonomous Agent Task Selection

```bash
# LLM agent gets triage, selects top task, auto-sets focus
claude-todo analyze --auto-focus
```

The `--auto-focus` flag automatically sets focus to the highest-leverage task, enabling fully autonomous workflows.

### 2. Project Planning Session

```bash
# Get comprehensive analysis for sprint planning
claude-todo analyze --format full > sprint-plan.txt
```

### 3. Daily Standup Report

```bash
# Quick triage overview
claude-todo analyze
```

### 4. CI/CD Integration

```bash
# Check for bottlenecks and critical path in pipeline
claude-todo analyze --format json | \
  jq -e '.bottlenecks | length < 5' || \
  echo "WARNING: Project has too many bottlenecks"
```

### 5. Scripting and Automation

```bash
# Extract top recommendation
TOP_TASK=$(claude-todo analyze -f json | jq -r '.recommendation.task_id')
claude-todo focus set "$TOP_TASK"

# Get all tier 1 tasks
claude-todo analyze -f json | \
  jq -r '.tiers.tier1_critical.tasks[] | "\(.id) - \(.title)"'
```

## Understanding Leverage Scores

Leverage score measures **downstream impact** - how much work becomes actionable after completing a task.

### Score Components

| Component | Weight | Purpose |
|-----------|--------|---------|
| **Base Priority** | 25-100 | Intrinsic importance |
| **Direct Dependents** | ×10 each | Immediate unblocking |
| **Transitive Dependents** | ×10 each | Cascade effect |

### Example Scenarios

**High Leverage (Score: 150+)**:
```
Task A blocks 5 tasks directly
Those 5 tasks block 10 more tasks
Total cascade: 15 tasks
Leverage: 100 (critical) + 150 (15×10) = 250
```

**Low Leverage (Score: 25-50)**:
```
Task B has no dependents
Low priority
Leverage: 25 (low priority) + 0 (no cascade) = 25
```

**Medium Leverage with High Priority (Score: 75-100)**:
```
Task C blocks 2 tasks
High priority
Leverage: 75 (high) + 20 (2×10) = 95
```

## Bottleneck Detection

A task is classified as a **bottleneck** if it blocks ≥3 other tasks.

### Bottleneck Severity Levels

| Blocks | Severity | Action |
|--------|----------|--------|
| **8+** | Critical | Immediate attention required |
| **5-7** | High | Prioritize within 24 hours |
| **3-4** | Moderate | Address within sprint |
| **1-2** | Minor | Normal prioritization |

### Resolution Strategy

```bash
# Identify all bottlenecks
claude-todo analyze --format full | grep -A5 "BOTTLENECK ANALYSIS"

# Focus on highest blocker
claude-todo analyze --auto-focus
```

## Critical Path Analysis

The **critical path** is the longest chain of dependent tasks from any root task to completion.

### Why It Matters

- **Project Timeline**: Critical path length determines minimum project duration
- **Parallelization**: Tasks off critical path can run concurrently
- **Risk Management**: Delays on critical path directly impact delivery

### Interpretation

```
Critical Path: 6 tasks deep
T001 → T002 → T003 → T004 → T005 → T006

Minimum completion time: 6 sequential task completions
Optimization: Work on T001 first to start chain
```

## Tier System

Tasks are automatically grouped into 4 action tiers:

### Tier 1: Critical
**Start immediately** - highest impact, unblock significant work

**Criteria**:
- Critical priority, OR
- Blocks ≥3 tasks (bottleneck), OR
- First task on critical path

### Tier 2: High Impact
**Prioritize next** - high value, meaningful dependencies

**Criteria**:
- High priority, OR
- Leverage score >100, OR
- Blocks 1-2 tasks with high downstream impact

### Tier 3: Standard
**Normal queue** - medium priority, some dependencies

**Criteria**:
- Medium priority, OR
- Has downstream dependencies but not bottleneck

### Tier 4: Low Priority
**Defer or delegate** - low impact, no blocking

**Criteria**:
- Low priority, AND
- No dependents (leverage score = base priority only)

## Integration Examples

### Morning Triage Script

```bash
#!/usr/bin/env bash
# morning-triage.sh

echo "=== Daily Task Triage ==="
echo ""
echo "Dashboard:"
claude-todo dash --compact
echo ""
echo "Strategic Analysis:"
claude-todo analyze
echo ""
echo "Setting focus to top recommendation..."
claude-todo analyze --auto-focus
```

### Slack/Discord Bot

```bash
# Post daily triage to team channel
ANALYSIS=$(claude-todo analyze)
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"Daily Task Triage:\n\`\`\`\n$ANALYSIS\n\`\`\`\"}"
```

### Project Health Check

```bash
# Check for project health issues
BOTTLENECKS=$(claude-todo analyze -f json | jq -r '.bottlenecks | length')
CRITICAL_PATH=$(claude-todo analyze -f json | jq -r '.critical_path.length')

if [[ "$BOTTLENECKS" -gt 5 ]]; then
  echo "WARNING: Too many bottlenecks ($BOTTLENECKS)"
fi

if [[ "$CRITICAL_PATH" -gt 10 ]]; then
  echo "WARNING: Critical path too long ($CRITICAL_PATH tasks)"
fi
```

## Comparison with Other Commands

| Command | Purpose | Use When |
|---------|---------|----------|
| **analyze** | Comprehensive triage with leverage scoring | Need strategic prioritization, understand project structure |
| **next** | Simple next-task suggestion | Quick "what should I do now?" |
| **blockers** | Show blocked tasks only | Focus on unblocking work |
| **deps** | Visualize dependencies | Understand task relationships |
| **dash** | Project overview | High-level status check |

### Workflow Recommendation

```bash
# Morning routine
claude-todo dash              # Check overall status
claude-todo analyze           # Get strategic priorities
claude-todo analyze --auto-focus  # Start top task

# During work
claude-todo next              # Quick next-task suggestions
claude-todo focus note "Progress update"

# Sprint planning
claude-todo analyze --format full > sprint-analysis.txt
claude-todo blockers analyze  # Understand blocking chains
```

## Tips

1. **Use `--auto-focus` for autonomous workflows**: Fully automate task selection for LLM agents
2. **Review full format periodically**: Deep understanding of project structure and dependencies
3. **Monitor bottlenecks**: Aim for <3 bottleneck tasks to maintain flow
4. **Track critical path changes**: As you complete tasks, critical path should decrease
5. **Combine with phases**: Use `--format json` to filter by phase for phase-focused sprints

## Related Commands

- `claude-todo next` - Simple next-task suggestion
- `claude-todo blockers analyze` - Detailed blocking chain analysis
- `claude-todo deps tree` - Full dependency visualization
- `claude-todo dash` - Project dashboard
- `claude-todo focus set ID` - Set focus to specific task

## Version History

- **v0.15.0**: Initial implementation with leverage scoring, bottleneck detection, tier system
