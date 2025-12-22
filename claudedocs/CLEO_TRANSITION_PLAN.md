# C.L.E.O. Transition & Multi-Agent Support Plan

**Goal:** Decouple `claude-todo` from Claude-specific branding, rebrand to **CLEO (Comprehensive Logistics & Execution Orchestrator)**, and introduce multi-agent support for Gemini, Kimi, and Codex.

**Target Version:** v1.0.0
**Current Status:** PAUSED (Completing v0.24.x pre-requisites on `main`)
**Last Updated:** 2025-12-20

---

## 0. Phase 0: Pre-Requisites (Main Branch)

**Objective:** Ensure the core system is stable and feature-complete before the rebranding refactor.

| Task | Epic | Status |
|------|------|--------|
| Hierarchy System (maxSiblings/maxDepth) | T328 series | ✅ Phase 1 Complete |
| Hierarchy Phase 2 (automation) | T339 series | ⏳ Pending |
| Archive Enhancements | T429 series | ⏳ Pending |
| Smart Analyze Engine | T542 | ⏳ Pending |
| LLM-Agent-First Spec v3.0 Compliance | T481 series | ⏳ Pending |
| Phase Discipline Documentation | T457 (T458, T459) | ⏳ Pending |

---

## 1. Executive Summary

C.L.E.O. (Comprehensive Logistics & Execution Orchestrator) acts as the persistent memory and logistics layer for *any* CLI-based AI agent. The transition involves:

1. **Rebranding**: `claude-todo` → `cleo`
2. **Generalization**: Abstracting `.claude/` directories to `.cleo/`
3. **Multi-Agent Ecosystem**: Native support for **concurrent** agents (Claude, Gemini, Kimi, Codex) interacting with the same project
4. **Sync Adapters**: Agent-specific adapters for each tool's native todo API

---

## 2. Architectural Changes

### A. Configuration Schema Expansion (`schemas/config.schema.json`)

We will add an `agents` section to support multiple active agents.

```json
"agents": {
  "type": "object",
  "properties": {
    "active": {
      "type": "array",
      "items": { "type": "string", "enum": ["claude", "gemini", "kimi", "codex"] },
      "default": ["claude"],
      "description": "List of active agents enabled for this project."
    },
    "configs": {
      "type": "object",
      "properties": {
        "claude": {
          "type": "object",
          "properties": {
            "docsFile": { "const": "CLAUDE.md" },
            "syncAdapter": { "const": "todowrite" }
          }
        },
        "gemini": {
          "type": "object",
          "properties": {
            "docsFile": { "const": "AGENTS.md" },
            "syncAdapter": { "const": "write_todos" },
            "settingsPath": { "const": ".gemini/settings.json" }
          }
        },
        "kimi": {
          "type": "object",
          "properties": {
            "docsFile": { "const": "AGENTS.md" },
            "syncAdapter": { "const": "set_todolist" }
          }
        },
        "codex": {
          "type": "object",
          "properties": {
            "docsFile": { "const": "AGENTS.md" },
            "syncAdapter": { "const": "context_inject" }
          }
        }
      }
    }
  }
}
```

### B. Directory Structure & Naming

| Concept | Current | New CLEO |
|---------|---------|----------|
| **Global Home** | `~/.claude-todo` | `~/.cleo` |
| **Project Directory** | `.claude/` | `.cleo/` |
| **Active Tasks** | `.claude/todo.json` | `.cleo/todo.json` |
| **Archive** | `.claude/todo-archive.json` | `.cleo/todo-archive.json` |
| **Config** | `.claude/todo-config.json` | `.cleo/cleo-config.json` |
| **Log** | `.claude/todo-log.json` | `.cleo/cleo-log.json` |
| **Session State** | `.claude/sync/` | `.cleo/session.json` |

### C. Environment Variables

| Current | New | Fallback Behavior |
|---------|-----|-------------------|
| `CLAUDE_TODO_HOME` | `CLEO_HOME` | Check `CLEO_*` first, then `CLAUDE_TODO_*` |
| `CLAUDE_TODO_FORMAT` | `CLEO_FORMAT` | Check `CLEO_*` first, then `CLAUDE_TODO_*` |
| `CLAUDE_TODO_DEBUG` | `CLEO_DEBUG` | Check `CLEO_*` first, then `CLAUDE_TODO_*` |
| (new) | `CLEO_AGENT` | Explicit agent identity override |

### D. Documentation Files

| Agent | Docs File | Rationale |
|-------|-----------|-----------|
| **Claude** | `CLAUDE.md` | Claude Code's native context file |
| **Gemini** | `AGENTS.md` | Configurable via `.gemini/settings.json` |
| **Kimi** | `AGENTS.md` | Standard agents file (per Kimi repo pattern) |
| **Codex** | `AGENTS.md` | Standard agents file |

**Standard:** All non-Claude agents use `AGENTS.md` for consistency.

---

## 3. Implementation Phases

### Phase 1: Templating & Branding ✅ STARTED

| Task | Status |
|------|--------|
| Create `templates/AGENT-INJECTION.md` | ✅ Created |
| Create `templates/agents/GEMINI-HEADER.md` | ✅ Created |
| Create `templates/agents/KIMI-HEADER.md` | ✅ Created |
| Create `templates/agents/CODEX-HEADER.md` | ✅ Created |
| Create `docs/CLEO_Task_Management.md` | ✅ Created |

### Phase 2: Core Library Updates

| Task | Description |
|------|-------------|
| Refactor `lib/config.sh` | Implement dual-variable lookup (CLEO > CLAUDE) |
| Refactor `lib/logging.sh` | Remove hardcoded "claude" actor, use `CLEO_AGENT` |
| Create `lib/agent-detection.sh` | Agent identity resolution logic |
| Update all path references | `.claude/` → `.cleo/` with fallback |

### Phase 3: Installation & Initialization

**install.sh Changes:**
```bash
# Interactive agent selection
echo "Which agents do you use?"
echo "  [x] Claude Code (CLAUDE.md, TodoWrite)"
echo "  [ ] Gemini CLI  (AGENTS.md, write_todos)"
echo "  [ ] Kimi        (AGENTS.md, SetTodoList)"
echo "  [ ] Codex       (AGENTS.md, context injection)"
```

**init.sh Changes:**
- Create `.cleo/` directory
- Loop through `agents.active` from config
- Per-agent initialization:
  - **Claude:** Inject into `CLAUDE.md`
  - **Gemini:** Update `.gemini/settings.json`, inject into `AGENTS.md`
  - **Kimi:** Inject into `AGENTS.md`
  - **Codex:** Inject into `AGENTS.md`

### Phase 4: Migration Utility

Create `scripts/migrate-to-cleo.sh`:
1. Detect `.claude/` directory
2. Rename to `.cleo/`
3. Rename `todo-config.json` → `cleo-config.json`
4. Update `.gitignore`
5. Scan and update injection blocks in docs files
6. (Optional) Create `.claude` → `.cleo` symlink for backward compat

---

## 4. Sync System Adapters

### 4.A: Verified Agent APIs

#### Claude TodoWrite (VERIFIED ✅)
**Source:** Claude Code built-in tool
```json
{
  "content": "Task title",
  "activeForm": "Working on task",
  "status": "pending" | "in_progress" | "completed"
}
```
- **Behavior:** Direct state file manipulation
- **Constraint:** Single `in_progress` task enforced

#### Gemini write_todos (VERIFIED ✅)
**Source:** https://geminicli.com/docs/tools/todos/
```javascript
write_todos({
  todos: [
    { description: "Task title", status: "pending" | "in_progress" | "completed" | "cancelled" }
  ]
})
```
- **Behavior:** Replaces entire list
- **Constraint:** Only one `in_progress` at a time
- **UI Toggle:** `Ctrl+T` to view todo list
- **Config:** Disable via `"useWriteTodos": false` in settings.json

#### Kimi SetTodoList (VERIFIED ✅)
**Source:** https://llmmultiagents.com/en/blogs/kimi-cli-technical-deep-dive
```python
SetTodoList(todos=[
    {"content": "Task title", "status": "completed" | "in_progress"}
])
```
- **Behavior:** Replaces entire list
- **Note:** No explicit `pending` status documented

> **[RESEARCH NEEDED]:** Verify Kimi's complete status enum. Does omitting a task imply "pending"? What happens to tasks not in the list?

#### Codex CLI (VERIFIED ✅ - NO NATIVE TODO)
**Source:** https://developers.openai.com/codex/cli/
- **Status:** No built-in todo management tool
- **GitHub Issue:** #2966 suggests todo MCP integration
- **Approach:** Context file injection only

> **[RESEARCH NEEDED]:** Monitor Codex CLI for future todo tool support. Consider MCP server approach.

### 4.B: Active Agent Detection

**Problem:** How does CLEO know which agent is active during a session?

**Solution:** Agent identity stored in session state.

```bash
# Agent starts session with identity flag
cleo session start --agent gemini
```

This writes to `.cleo/session.json`:
```json
{
  "sessionId": "session_20251220_...",
  "startTime": "2025-12-20T10:00:00Z",
  "activeAgent": "gemini"
}
```

**Resolution Priority:**
1. `--agent` flag (explicit)
2. `CLEO_AGENT` environment variable
3. `.cleo/session.json` activeAgent
4. Config default (`agents.default`)
5. Fallback: `"claude"`

> **[RESEARCH NEEDED]:** Can we auto-detect agent from process tree? (e.g., parent process name contains "gemini")

### 4.C: Sync Injection Models

| Agent | Model | Description |
|-------|-------|-------------|
| **Claude** | Direct | CLEO writes to TodoWrite state file |
| **Gemini** | Instructional | CLEO outputs tool call for agent to execute |
| **Kimi** | Instructional | CLEO outputs tool call for agent to execute |
| **Codex** | Context Inject | CLEO injects state block into AGENTS.md |

**Instructional Model Example (Gemini):**
```markdown
<!-- CLEO-SYNC-INSTRUCTION -->
Execute this to sync your todo state:
```javascript
write_todos({
  todos: [
    { description: "T001: Implement auth", status: "in_progress" },
    { description: "T002: Write tests", status: "pending" }
  ]
})
```
<!-- END-CLEO-SYNC-INSTRUCTION -->
```

> **[RESEARCH NEEDED]:** Verify that Gemini/Kimi will execute tool calls from context instructions. Test with real agents.

### 4.D: Status Mapping

| CLEO Status | Claude | Gemini | Kimi | Codex |
|-------------|--------|--------|------|-------|
| `pending` | `pending` | `pending` | (omit)* | N/A |
| `active` | `in_progress` | `in_progress` | `in_progress` | N/A |
| `blocked` | `pending`** | `pending`** | (omit)* | N/A |
| `done` | `completed` | `completed` | `completed` | N/A |

*Kimi: Tasks not in list may be implicitly pending - **[RESEARCH NEEDED]**
**Downgrade: Blocker info preserved in CLEO only

### 4.E: Bidirectional Sync Feasibility

| Agent | Inject (CLEO → Agent) | Extract (Agent → CLEO) | Status |
|-------|----------------------|------------------------|--------|
| **Claude** | ✅ Direct write | ✅ Parse state file | Full sync |
| **Gemini** | ⚠️ Instructional | ❓ Unknown | **[RESEARCH NEEDED]** |
| **Kimi** | ⚠️ Instructional | ❓ Unknown | **[RESEARCH NEEDED]** |
| **Codex** | ⚠️ Context inject | ❌ No todo tool | One-way only |

> **[RESEARCH NEEDED]:**
> - Does Gemini persist todo state to a file we can read?
> - Does Kimi persist todo state to a file we can read?
> - Can we hook into their completion events?

---

## 5. Multi-Agent CLI Experience

| Feature | Claude Code | Gemini CLI | Kimi CLI | Codex CLI |
|---------|-------------|------------|----------|-----------|
| **Command** | `cleo` / `ct` | `cleo` / `ct` | `cleo` / `ct` | `cleo` / `ct` |
| **Context File** | `CLAUDE.md` | `AGENTS.md` | `AGENTS.md` | `AGENTS.md` |
| **Sync Tool** | TodoWrite | `write_todos` | `SetTodoList` | Context Inject |
| **Sync Direction** | Bidirectional | **[RESEARCH]** | **[RESEARCH]** | One-way |

---

## 6. Verification Plan

**Mock Project:** `/mnt/projects/cleo-testing`

### Test Cases

| # | Test | Verification |
|---|------|--------------|
| 1 | Multi-Agent Init | `cleo init --agents claude,gemini` updates both `CLAUDE.md` and `AGENTS.md` |
| 2 | Gemini Settings | `.gemini/settings.json` includes `AGENTS.md` in `contextFileName` |
| 3 | Agent Detection | `cleo session start --agent gemini` creates correct `session.json` |
| 4 | Migration | `.claude/` → `.cleo/` preserves all data |
| 5 | Sync Inject Claude | `cleo sync --inject` updates TodoWrite state |
| 6 | Sync Inject Gemini | `cleo sync --inject --agent gemini` outputs correct `write_todos` call |
| 7 | Backward Compat | `claude-todo` command still works (symlink) |

---

## 7. Q&A Clarifications

### Q1: Can I have Claude AND Gemini active simultaneously?
**Answer:** Yes. `cleo init` will update *both* `CLAUDE.md` and `AGENTS.md` (and `.gemini/settings.json`). This allows you to switch agents mid-project with both having full context.

### Q2: Is TodoWrite sync going away?
**Answer:** No. It's being generalized into the "Sync Adapter" system. TodoWrite becomes one of several adapters alongside Gemini, Kimi, and Codex adapters.

### Q3: How does `install.sh` work?
**Answer:** It prompts once (globally): "Select your agents: [Claude, Gemini, Kimi, Codex]". This sets your global default in `~/.cleo/config.json`. When you run `cleo init` in a project, it uses these defaults but allows override with flags.

### Q4: How does `cleo sync` work with multiple agents?
**Answer:** By default, it syncs with the active agent (from session.json or `--agent` flag). Use `cleo sync --broadcast` to inject to ALL enabled agents simultaneously.

### Q5: Why "C.L.E.O."?
**Answer:** "Comprehensive Logistics & Execution Orchestrator". The tool handles *logistics* (state, history, files) so the agent can focus on *execution* (coding).

---

## 8. Research Backlog

Items marked **[RESEARCH NEEDED]** require verification before implementation:

| # | Topic | Question | Priority |
|---|-------|----------|----------|
| 1 | Kimi Status Enum | What are all valid status values for SetTodoList? | HIGH |
| 2 | Kimi Pending | Does omitting a task imply "pending"? | HIGH |
| 3 | Gemini Extract | Does Gemini persist todo state to a readable file? | MEDIUM |
| 4 | Kimi Extract | Does Kimi persist todo state to a readable file? | MEDIUM |
| 5 | Instructional Execution | Will agents execute tool calls from context instructions? | HIGH |
| 6 | Agent Auto-Detection | Can we detect agent from process tree? | LOW |
| 7 | Codex Future | Will Codex add native todo support? | LOW |

---

## 9. Version History

| Version | Date | Changes |
|---------|------|---------|
| v1.0 | 2025-12-20 | Initial consolidated version |
| - | - | Standardized `AGENTS.md` for all non-Claude agents |
| - | - | Added verified API documentation with sources |
| - | - | Added research backlog for unverified assumptions |
| - | - | Merged agent detection mechanism (Section 4.B) |
| - | - | Fixed INSTRUCTIONS.md → AGENTS.md throughout |

---

*Document maintainer: Development Team*
*Next review: After Phase 0 prerequisites complete*
