---
name: send-to-karo
description: This skill should be used after shogun writes a task to queue/shogun_to_karo.yaml. It sends a tmux send-keys notification to karo's pane, triggering karo to check for new tasks in shared_context/shogun_to_karo.yaml.
---

# send-to-karo

## Overview

Notify karo agent via tmux send-keys that new tasks are available. Invoke this skill immediately after writing tasks to `queue/shogun_to_karo.yaml` to trigger event-driven task processing.

## When to Use

Use this skill in the following sequence:

```
1. Write task to queue/shogun_to_karo.yaml
2. Invoke: skill send-to-karo
3. Karo receives notification and processes task
```

**Do NOT use this skill:**

- Before writing to the queue file
- Multiple times for the same task
- To wake karo without a queued task

## How It Works

The skill executes `scripts/notify.sh` which:

1. Validates environment variables (`AGENT_SESSION`, `AGENT_PANE_KARO`)
2. Sends message to karo's tmux pane via `tmux send-keys`
3. Uses two-step sending (message + Enter after delay)

**Two-step sending prevents message loss:**

- Step 1: Send message text
- Step 2: Wait 1 second, send Enter key
- Ensures message is processed even if karo is mid-execution

## Requirements

**Environment Variables (set by departure script):**

- `AGENT_SESSION` - tmux session name (e.g., "multi")
- `AGENT_PANE_KARO` - Karo's pane number (e.g., "1")

**Prerequisites:**

- Must be invoked from shogun's workspace
- Karo must be running in tmux session
- Task must be written to queue before notification

## Usage Example

Complete workflow:

```bash
# Step 1: Get timestamp
timestamp=$(date "+%Y-%m-%dT%H:%M:%S")

# Step 2: Write task to queue
cat >> queue/shogun_to_karo.yaml <<YAML_EOF
  - id: cmd_003
    timestamp: "$timestamp"
    command: "Implement user authentication"
    priority: high
    status: pending
    context: |
      OAuth2 with Google and GitHub providers.
      Include session management and token refresh.
YAML_EOF

# Step 3: Notify karo
skill send-to-karo

# Step 4: Monitor dashboard.md for progress
```

## Notification Message

The script sends:

```
New task available. Check shared_context/shogun_to_karo.yaml and execute.
```

Karo sees this in their workspace as:

```
shared_context/shogun_to_karo.yaml  # Karo's path (real file)
```

Shogun wrote to:

```
queue/shogun_to_karo.yaml  # Shogun's path (symlink)
```

Both point to the same file via symlinks.

## Error Handling

### Environment Variable Missing

```
Error: AGENT_SESSION environment variable not set
```

**Solution:** Verify departure script set environment variables:

```bash
echo $AGENT_SESSION    # Should show session name
echo $AGENT_PANE_KARO  # Should show pane number
```

### Karo Not Responding

If karo doesn't respond after notification:

1. **Check karo is running:**

   ```bash
   tmux list-panes -t $AGENT_SESSION
   ```

2. **Verify queue file written:**

   ```bash
   cat queue/shogun_to_karo.yaml
   ```

3. **Retry notification:**

   ```
   skill send-to-karo
   ```

4. **Check dashboard for blockers:**
   ```bash
   tail dashboard.md
   ```

## Resources

### scripts/notify.sh

Bash script that performs the tmux notification. Includes:

- Environment variable validation
- Two-step message sending
- Error reporting

The script is automatically executed when the skill is invoked.
