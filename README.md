# Copilot Kingdom

Multi-agent system using GitHub Copilot CLI with git worktree isolation for parallel task execution.

## Overview

Copilot Kingdom is a multi-agent architecture that enables GitHub Copilot CLI instances to work collaboratively on complex tasks. Unlike traditional single-agent approaches, this system uses git worktrees to provide workspace isolation while maintaining shared communication through symlinks.

## Architecture

### System Design

```
User
  │
  ▼ Command
┌─────────────────────┐
│  SHOGUN (Pane 0)   │ ← Strategic agent: planning + execution + delegation
│  /worktrees/shogun/ │   Works directly on simple tasks
│  ├─ queue/ ────────┼─→ Symlink to Karo's shared_context/
│  └─ dashboard.md ──┼─→ Symlink to Karo's dashboard.md
└──────────┬──────────┘
           │ YAML communication
           ▼
┌─────────────────────┐
│  KARO (Pane 1)     │ ← Orchestrator: task distribution via subagents
│  /worktrees/karo-1/ │   Uses task tool for on-demand workers
│  ├─ shared_context/ │   (Real directory, symlink target)
│  │  └─ shogun_to_karo.yaml
│  └─ dashboard.md    │   (Real file, owned by Karo)
└──────────┬──────────┘
           │ task tool
           ▼
    ┌─────────────┐
    │ Subagents   │ ← On-demand workers (no persistent instances)
    │ (task tool) │   Created as needed, disposed after completion
    └─────────────┘
```

### Key Differences from Original multi-agent-sample

| Aspect             | Original (multi-agent-sample)                 | New (Copilot Kingdom)                       |
| ------------------ | --------------------------------------------- | ------------------------------------------- |
| **Workspace**      | Single shared directory                       | Separate git worktrees per agent            |
| **Agent Count**    | 9 instances (1 Shogun + 1 Karo + 7 Ashigaru)  | 2 instances (Shogun + Karo)                 |
| **Worker Model**   | Persistent Ashigaru instances in tmux panes   | On-demand subagents via task tool           |
| **Shogun Role**    | Delegation only (prohibited from direct work) | Direct work + delegation                    |
| **Communication**  | YAML files in shared directory                | YAML files + symlinks across worktrees      |
| **Tmux Layout**    | 3x3 grid (9 panes)                            | 1x2 grid (2 panes)                          |
| **Personality**    | Feudal Japanese style (戦国風)                | Professional, no personality overlay        |
| **Resource Usage** | High (9 CLI instances)                        | Low (2 CLI instances + ephemeral subagents) |

## Installation

### Requirements

- **Git** 2.5+ (with worktree support)
- **tmux** 2.0+
- **GitHub Copilot CLI** with --agent flag support
- **Bash** 4.0+
- **Filesystem** with symlink support

### Setup

1. Clone the repository:

```bash
git clone https://github.com/iimuz/copilot-kingdom.git
cd copilot-kingdom
```

2. Ensure GitHub Copilot CLI is installed and authenticated:

```bash
gh auth status
```

## Quick Start

### Starting the System

```bash
./scripts/worktree_departure.sh
```

This script will:

1. Create git worktrees for Shogun and Karo at `./worktrees/`
2. Set up symlinks from Shogun to Karo's shared context
3. Initialize communication files (YAML, dashboard)
4. Launch a tmux session with 2 panes
5. Start Copilot CLI instances in each pane

### Connecting to the Session

If you started from outside tmux:

```bash
tmux attach-session -t multi
```

If you started from within tmux, switch to the new window created.

### Interacting with Agents

Pane 0 (Shogun) is your primary interface. Give commands such as:

```
Analyze the codebase structure and create a dependency diagram
```

Shogun will decide whether to:

- Execute directly (simple tasks)
- Delegate to Karo (complex/parallel tasks)

Pane 1 (Karo) monitors for delegated tasks and uses subagents to execute them.

### Stopping the System

1. Exit Copilot CLI instances (Ctrl+C or type `exit`)
2. Kill the tmux session:

```bash
tmux kill-session -t multi
```

3. Clean up worktrees (optional):

```bash
git worktree remove worktrees/shogun
git worktree remove worktrees/karo-1
rm -rf worktrees/
```

## Configuration

### Custom Worktree Paths

Set environment variables before running the departure script:

```bash
# Use different base directory
export WORKTREE_BASE="/tmp/agents"
./scripts/worktree_departure.sh

# Or specify individual paths
export SHOGUN_WORKTREE="/path/to/shogun"
export KARO_WORKTREE="/path/to/karo"
./scripts/worktree_departure.sh
```

### Model Configuration

Edit agent definition files in `.github/agents/` to specify models:

- Shogun: Typically uses higher-tier models (Sonnet, Opus)
- Karo: Can use efficient models (Haiku) for orchestration

## Agents

This system uses an **agent-based architecture** where agents are loaded automatically with the `--agent` flag. Agents have persistent context and can access specialized tools and workflows.

### Available Agents

- **shogun** (`.github/agents/shogun.md`)
  - Strategic coordinator
  - Handles both direct work and delegation
  - Decides task complexity and routing
  - Auto-loaded in Shogun's worktree
- **karo** (`.github/agents/karo.md`)
  - Task orchestrator
  - Decomposes complex tasks
  - Manages subagent execution via task tool
  - Auto-loaded in Karo's worktree

### Supporting Skills

- **send-to-karo** (`.github/skills/send-to-karo/`)
  - Notification skill for tmux send-keys
  - Wakes up Karo when new tasks are queued
  - Event-driven communication

### Using the System

Agents are automatically loaded when Copilot CLI starts with the `--agent` flag:

```bash
# In Shogun's workspace - shogun agent auto-loads
gh copilot --agent shogun

# In Karo's workspace - karo agent auto-loads
gh copilot --agent karo
```

The `send-to-karo` skill is invoked explicitly when needed:

```bash
# Notify Karo after writing tasks
skill send-to-karo
```

## Project Structure

```
copilot-kingdom/
├── .github/
│   ├── agents/                   # Agent definitions
│   │   ├── shogun.md             # Shogun agent (strategic coordinator)
│   │   └── karo.md               # Karo agent (task orchestrator)
│   └── skills/                   # Skill definitions
│       └── send-to-karo/         # Notification skill
│           ├── skill.md
│           └── scripts/send.sh
├── scripts/
│   └── worktree_departure.sh     # System startup script
├── worktrees/                    # Created at runtime
│   ├── shogun/                   # Shogun's workspace
│   │   ├── queue/ → ../karo-1/shared_context/
│   │   └── dashboard.md → ../karo-1/dashboard.md
│   └── karo-1/                   # Karo's workspace
│       ├── shared_context/       # Real directory
│       │   └── shogun_to_karo.yaml
│       └── dashboard.md          # Real file
└── multi-agent-sample/           # Original reference implementation
```

## Communication Flow

1. **Shogun receives user request** in `/worktrees/shogun/`
2. **Shogun decides**:
   - Simple task → Execute directly
   - Complex task → Write to `queue/shogun_to_karo.yaml` (via symlink)
3. **Karo detects new task** by monitoring `shared_context/shogun_to_karo.yaml`
4. **Karo creates subagents** using the task tool
5. **Subagents execute** and return results to Karo
6. **Karo updates dashboard.md** with progress/results
7. **Shogun reads dashboard** (via symlink) to see status

## Documentation

- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [Configuration Guide](docs/configuration.md) - Advanced configuration options
- [Karo Subagent Patterns](docs/karo-subagents.md) - Best practices for task delegation

## Acknowledgments

Based on [yohey-w/multi-agent-shogun](https://github.com/yohey-w/multi-agent-shogun) - reimplemented for GitHub Copilot CLI with worktree isolation and subagent architecture.

## License

MIT License - see [LICENSE](LICENSE) file for details.
