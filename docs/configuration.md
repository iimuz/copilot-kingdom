# Configuration Guide

Advanced configuration options for the multi-worktree agent system.

## Environment Variables

### Worktree Paths

Control where worktrees are created:

```bash
# Default locations (if not set)
WORKTREE_BASE="./worktrees"
SHOGUN_WORKTREE="${WORKTREE_BASE}/shogun"
KARO_WORKTREE="${WORKTREE_BASE}/karo-1"
```

#### Custom Base Directory

```bash
# Use /tmp for ephemeral workspaces
export WORKTREE_BASE="/tmp/copilot-agents"
./scripts/worktree_departure.sh
```

#### Individual Worktree Paths

```bash
# Place worktrees in different locations
export SHOGUN_WORKTREE="/data/agents/shogun"
export KARO_WORKTREE="/data/agents/karo"
./scripts/worktree_departure.sh
```

#### Absolute vs Relative Paths

- **Absolute paths** (recommended): `/home/user/agents/shogun`
  - Work reliably across shells and contexts
  - Symlinks remain valid regardless of current directory
- **Relative paths**: `./worktrees/shogun`
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
# Modify create_worktrees() in departure script
git worktree add "${SHOGUN_WORKTREE}" main
git worktree add "${KARO_WORKTREE}" development
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

To scale to multiple Karo agents (future enhancement):

```bash
export KARO_COUNT=3
# Script would create: karo-1, karo-2, karo-3
# Each with separate shared_context and dashboard
# Shogun would need load balancing logic
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
fswatch -o worktrees/karo-1/shared_context/shogun_to_karo.yaml | \
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
worktrees/*/secrets/
worktrees/*/.env
worktrees/*/.credentials

# Set restrictive permissions
chmod 700 worktrees/shogun
chmod 700 worktrees/karo-1
```

### Sandboxing

For untrusted task execution:

```bash
# Run worktrees in restricted directories
export WORKTREE_BASE="/tmp/sandboxed"
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

export WORKTREE_BASE="/opt/copilot-agents"
export SHOGUN_WORKTREE="/opt/copilot-agents/shogun"
export KARO_WORKTREE="/opt/copilot-agents/karo-1"

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

export WORKTREE_BASE="./dev-worktrees"

# Use verbose logging
set -x

# Launch
./scripts/worktree_departure.sh
```

### CI/CD Configuration

```bash
#!/usr/bin/env bash
# ci-config.sh

export WORKTREE_BASE="/tmp/ci-agents-$BUILD_ID"
export AGENT_SESSION="ci-$BUILD_ID"

# Non-interactive mode
export COPILOT_NON_INTERACTIVE=1

# Cleanup on exit
trap 'git worktree remove --force $SHOGUN_WORKTREE; git worktree remove --force $KARO_WORKTREE' EXIT

# Launch
./scripts/worktree_departure.sh
```

## Configuration File Support

Future enhancement: Support for configuration file (e.g., `.copilot-kingdom.yaml`):

```yaml
# .copilot-kingdom.yaml (proposed)
worktrees:
  base: './worktrees'
  shogun:
    path: 'shogun'
    branch: 'main'
    model: 'claude-sonnet-4.5'
  karo:
    path: 'karo-1'
    branch: 'main'
    model: 'claude-haiku-4.5'

tmux:
  session: 'multi'
  layout: 'horizontal'

communication:
  format: 'yaml'
  notification: 'tmux'

dashboard:
  enabled: true
  update_interval: 10
```

This would be loaded by the departure script to configure all aspects of the system.
