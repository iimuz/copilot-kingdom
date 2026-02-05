# send-to-karo

## Purpose

Notify Karo agent via tmux send-keys that a new task is available in the queue.

## When to Use This Skill

After Shogun writes a new task to `queue/shogun_to_karo.yaml`, use this skill to wake up Karo and notify them to check the queue.

## Usage

```
skill send-to-karo
```

The skill will:

1. Send a notification message to Karo's tmux pane
2. Include a prompt to check `shared_context/shogun_to_karo.yaml`

## Requirements

- Must be run from Shogun's workspace
- `AGENT_SESSION` environment variable must be set (tmux session name)
- `AGENT_PANE_KARO` environment variable must be set (Karo's pane number)
- Karo must be running in the tmux session

## How It Works

The skill uses tmux send-keys in two steps:

1. First send: Message text
2. Second send (after 1s delay): Enter key

This two-step approach prevents the message from being lost if Karo is in the middle of processing.

## Example Workflow

```bash
# 1. Shogun writes task to queue
cat > queue/shogun_to_karo.yaml <<EOF
queue:
  - id: cmd_001
    timestamp: "2026-02-05T05:00:00"
    command: "Implement user authentication"
    priority: high
    status: pending
EOF

# 2. Notify Karo
skill send-to-karo

# 3. Karo receives notification and reads shared_context/shogun_to_karo.yaml
```

## Notes

- Event-driven notification (no polling)
- Karo checks the file path relative to their workspace: `shared_context/shogun_to_karo.yaml`
- Shogun writes to path relative to their workspace: `queue/shogun_to_karo.yaml` (symlinked)
