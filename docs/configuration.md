# Configuration Guide

Advanced configuration options for the multi-worktree agent system.

## Environment Variables

### Worktree Paths

Configuration requires explicit paths:

- `SHOGUN_PATH`: existing directory for the Shogun workspace
- `KARO_PATHS`: bash array of Karo worktree paths
- `KARO_COUNT`: optional cap (defaults to all `KARO_PATHS` entries)
- `WORKTREE_CONFIG_FILE`: optional config file sourced before validation

```bash
export SHOGUN_PATH="/path/to/shogun"
export KARO_PATHS=("/path/to/karo-1" "/path/to/karo-2")
export KARO_COUNT=1
export WORKTREE_CONFIG_FILE="/path/to/worktree-config.sh" # optional

./scripts/worktree_departure.sh --check
./scripts/worktree_departure.sh
```

#### External Config Precedence

If `WORKTREE_CONFIG_FILE` is set, it is sourced after the inline defaults. Values in the file override inline configuration.

#### Migration from Legacy Base Configuration (Deprecated)

If `SHOGUN_PATH` and `KARO_PATHS` are unset, the script will map legacy base settings for backward compatibility:

| Legacy Input        | New Mapping                                                                               |
| ------------------- | ----------------------------------------------------------------------------------------- |
| Base unset          | `SHOGUN_PATH="<parent>/wt-<repo>-shogun"`, `KARO_PATHS=("<parent>/wt-<repo>-karo-1" ...)` |
| Base set to `/path` | `SHOGUN_PATH="<repo root>"`, `KARO_PATHS=("/path/karo-1" ...)`                            |

This compatibility shim is temporary and will be removed after **2026-06-01**. Migrate to explicit `SHOGUN_PATH` and `KARO_PATHS` as soon as possible.

#### Absolute vs Relative Paths

- **Absolute paths** (recommended): `/home/user/agents/shogun`
  - Work reliably across shells and contexts
  - Symlinks remain valid regardless of current directory
- **Relative paths**: `../wt-{repo}-shogun`
  - Relative to repository root
  - May break if scripts are run from different directories

**Best practice**: Use absolute paths in production, relative paths for local development.

### Tmux Session Configuration

```bash
# Default session name
AGENT_SESSION="multi"

# Override session name
export TMUX_SESSION_NAME="my-agents"
# Note: Requires script modification to honor this variable
```

### Model Selection

Models are configured in agent instruction files, not environment variables. See [Agent Instructions](#agent-instructions) below.

## Agent Instructions

Agent behavior is controlled by instruction files in `.github/agents/`.

### Creating Agent Instructions

Agent instruction files are created in the worktrees at runtime. To customize:

1. Create instruction files in the main repository:

```bash
mkdir -p .github/agents
```

2. Create `shogun.md`:

```markdown
# Shogun Agent Instructions

You are a strategic planning agent responsible for:

- Analyzing user requests
- Planning execution strategies
- Executing simple tasks directly
- Delegating complex tasks to Karo

## Model Configuration

Prefer claude-sonnet-4.5 or claude-opus-4.5 for complex reasoning.

## Work Distribution

- Simple tasks (< 5 steps): Execute directly
- Complex tasks (> 5 steps): Delegate to Karo
- Parallel tasks: Delegate to Karo

## Communication

Use the send-to-karo skill to delegate tasks.
```

3. Create `karo.md`:

```markdown
# Karo Agent Instructions

You are a task orchestration agent responsible for:

- Receiving delegated tasks from Shogun
- Breaking down tasks into subtasks
- Creating subagents using the task tool
- Aggregating results
- Updating dashboard

## Model Configuration

Use claude-haiku-4.5 for efficiency in orchestration.

## Subagent Usage

Use the task tool with agent_type="general-purpose" for complex subtasks.
```

### Model Configuration in Instructions

Specify model preferences within agent instructions:

```markdown
## Preferred Models

Primary: claude-sonnet-4.5 (balanced performance/cost)
Fallback: claude-haiku-4.5 (if speed needed)
Premium: claude-opus-4.5 (for complex reasoning)
```

The Copilot CLI will use these hints when available, though actual model selection may vary based on availability.

## Tmux Layout Customization

### Window Layout

Default: 1x2 horizontal split (side-by-side panes)

To modify the layout, edit `scripts/worktree_departure.sh`:

```bash
# Current (horizontal split)
tmux split-window -h -t "$AGENT_SESSION:$AGENT_WINDOW"

# Alternative: Vertical split (stacked panes)
tmux split-window -v -t "$AGENT_SESSION:$AGENT_WINDOW"

# Custom dimensions (e.g., 70/30 split)
tmux split-window -h -p 30 -t "$AGENT_SESSION:$AGENT_WINDOW"
```

### Pane Titles

Modify pane titles in `create_tmux_session()`:

```bash
tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.0" -T "Strategic Agent"
tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.1" -T "Task Manager"
```

## Skill Configuration

Skills are shared across agents via `.github/skills/`.

### Custom Skills

Create a new skill for Shogun:

1. Create skill directory:

```bash
mkdir -p .github/skills/my-custom-skill
```

2. Create `SKILL.md`:

```markdown
# My Custom Skill

Description of what this skill does.

## Usage

Invoke with: "Use my-custom-skill to..."

## Parameters

- param1: Description
- param2: Description
```

3. Create execution script (if needed):

```bash
mkdir -p .github/skills/my-custom-skill/scripts
touch .github/skills/my-custom-skill/scripts/execute.sh
chmod +x .github/skills/my-custom-skill/scripts/execute.sh
```

### Skill Availability

Skills in `.github/skills/` are automatically available to all agents in all worktrees via symlinks.

## Communication File Configuration

### YAML File Structure

Default: `shogun_to_karo.yaml`

Custom structure can be defined in `initialize_communication_files()` in the departure script:

```yaml
# Custom task structure
task:
  id: 'task-001'
  type: 'analysis'
  priority: 'high'
  description: 'Task description'
  requirements:
    - requirement 1
    - requirement 2
  context:
    files: []
    references: []
status: 'pending'
created_at: '2026-02-05T00:00:00Z'
```

### Dashboard Configuration

Customize dashboard format in Karo's instructions:

```markdown
## Dashboard Updates

Update dashboard.md with this structure:

# Multi-Agent Dashboard

**Last Updated**: [timestamp]

## System Status

- Shogun: [status]
- Karo: [status]

## Active Tasks

[task list]

## Recent Activity

[activity log]

## Performance Metrics

- Tasks completed: X
- Average completion time: Y
- Success rate: Z%
```

## Git Configuration

### Worktree Branch Strategy

Default: Both worktrees use the current branch

To use different branches:

```bash
# Modify create_worktree() in departure script
git -C "${SHOGUN_PATH}" worktree add "/path/to/karo-1" main
```

### Gitignore Patterns

Add to `.gitignore` to exclude worktree artifacts:

```gitignore
# Worktree directories
/worktrees/

# Agent-specific ignores
**/shared_context/
**/dashboard.md

# Temporary files
**/*.log
**/copilot.log
```

## Advanced Configurations

### Multiple Karo Instances

To scale to multiple Karo agents, provide multiple paths and optionally cap with `KARO_COUNT`:

```bash
export KARO_PATHS=("/path/to/karo-1" "/path/to/karo-2" "/path/to/karo-3")
export KARO_COUNT=2
```

### Custom Notification System

Replace tmux send-keys with alternative notification:

Options:

1. File watchers (inotify, fswatch)
2. WebSocket connections
3. Message queue (Redis, RabbitMQ)

Example with fswatch:

```bash
# In Karo pane, watch for file changes
fswatch -o /path/to/karo-1/.agent/kingdom/shared_context/shogun_to_karo.yaml | \
  xargs -n1 -I{} echo "New task detected"
```

### Workspace Isolation Levels

Current: Git worktrees (shared git history, separate working directories)

Alternatives:

1. **Separate git clones**: Full isolation, more disk space
2. **Docker containers**: Complete environment isolation
3. **Bare repositories**: Multiple working directories without worktree

## Security Configuration

### Preventing Credential Leakage

Ensure worktree directories don't expose sensitive data:

```bash
# Add to .gitignore
**/.agent/kingdom/shared_context/
**/.agent/kingdom/dashboard.md

# Set restrictive permissions
chmod 700 "$SHOGUN_PATH"
chmod 700 "/path/to/karo-1"
```

### Sandboxing

For untrusted task execution:

```bash
# Run worktrees in restricted directories
export SHOGUN_PATH="/tmp/sandboxed/shogun"
export KARO_PATHS=("/tmp/sandboxed/karo-1")
# Use filesystem permissions to limit access
mkdir -p /tmp/sandboxed
chmod 755 /tmp/sandboxed
```

## Performance Tuning

### Filesystem Optimization

For SSD/NVMe:

- Use direct paths, avoid excessive symlinks
- Enable TRIM/discard
- Use modern filesystem (ext4, XFS, APFS)

For HDD:

- Minimize random I/O
- Keep worktrees on same partition as repository

### Model Selection for Performance

Agent efficiency by model:

| Model      | Speed  | Quality   | Cost   | Best For                         |
| ---------- | ------ | --------- | ------ | -------------------------------- |
| Haiku 4.5  | Fast   | Good      | Low    | Orchestration, simple tasks      |
| Sonnet 4.5 | Medium | Excellent | Medium | General purpose, complex logic   |
| Opus 4.5   | Slow   | Superior  | High   | Critical decisions, architecture |

**Recommendation**: Karo → Haiku, Shogun → Sonnet, Subagents → context-dependent

### Resource Limits

Limit Copilot CLI resource usage:

```bash
# In departure script, before launching CLI
ulimit -v 2097152  # 2GB virtual memory
ulimit -n 1024     # Max 1024 open files
```

## Examples

### Production Configuration

```bash
#!/usr/bin/env bash
# production-config.sh

export SHOGUN_PATH="/opt/copilot-agents/shogun"
export KARO_PATHS=("/opt/copilot-agents/karo-1")

# Security
umask 077

# Performance
ulimit -n 4096

# Launch
./scripts/worktree_departure.sh
```

### Development Configuration

```bash
#!/usr/bin/env bash
# dev-config.sh

export SHOGUN_PATH="./dev-worktrees/shogun"
export KARO_PATHS=("./dev-worktrees/karo-1")

# Use verbose logging
set -x

# Launch
./scripts/worktree_departure.sh
```

### CI/CD Configuration

```bash
#!/usr/bin/env bash
# ci-config.sh

export SHOGUN_PATH="/tmp/ci-agents-$BUILD_ID/shogun"
export KARO_PATHS=("/tmp/ci-agents-$BUILD_ID/karo-1")
export AGENT_SESSION="ci-$BUILD_ID"

# Non-interactive mode
export COPILOT_NON_INTERACTIVE=1

# Cleanup on exit
trap 'git -C "$SHOGUN_PATH" worktree remove --force "${KARO_PATHS[0]}"' EXIT

# Launch
./scripts/worktree_departure.sh
```

## Configuration File Support

Provide a shell config file and point `WORKTREE_CONFIG_FILE` at it:

```bash
# worktree-config.sh
SHOGUN_PATH="/opt/copilot-agents/shogun"
KARO_PATHS=("/opt/copilot-agents/karo-1" "/opt/copilot-agents/karo-2")
KARO_COUNT=1
```

```bash
export WORKTREE_CONFIG_FILE="/path/to/worktree-config.sh"
./scripts/worktree_departure.sh --check
./scripts/worktree_departure.sh
```
