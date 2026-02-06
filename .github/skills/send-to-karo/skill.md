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
2. Invoke: skill send-to-karo <karo_pane_number>
3. Karo receives notification and processes task
```

**Do NOT use this skill:**

- Before writing to the queue file
- Multiple times for the same task
- To wake karo without a queued task

## How It Works

The skill executes `scripts/notify.sh` which:

1. Detects tmux session/window from `$TMUX` (falls back to `multi:agents` when not in tmux)
2. Accepts karo pane number as positional argument
3. Sends message to karo's tmux pane via `tmux send-keys`
4. Uses two-step sending (message + Enter after delay)

**Two-step sending prevents message loss:**

- Step 1: Send message text
- Step 2: Wait 1 second, send Enter key
- Ensures message is processed even if karo is mid-execution

**Invocation:**

```
notify.sh <karo_pane_number>
```

Example:

```
notify.sh 1
```

## Requirements

**Prerequisites:**

- Must be invoked from shogun's workspace
- Karo must be running in tmux session
- Must know karo's pane number (typically 1, 2, etc.)
- Task must be written to queue before notification
- Tmux session detection is automatic

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

# Step 3: Find karo pane if unknown
tmux list-panes -F "#{pane_index}: #{pane_current_command}"

# Step 4: Notify karo (pane 1)
skill send-to-karo 1

# Step 5: Monitor dashboard.md for progress
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

### Missing Argument

```
Error: karo_pane_number argument is required
```

**Solution:** Provide karo's pane number:

```bash
skill send-to-karo 1
```

### Invalid Argument

```
Error: karo_pane_number must be a number
```

**Solution:** Use a numeric pane value (e.g., 1, 2).

### Karo Not Responding

If karo doesn't respond after notification:

1. **Check karo is running:**

   ```bash
   tmux list-panes
   ```

2. **Verify queue file written:**

   ```bash
   cat queue/shogun_to_karo.yaml
   ```

3. **Retry notification:**

   ```
   skill send-to-karo <karo_pane_number>
   ```

4. **Check dashboard for blockers:**
   ```bash
   tail dashboard.md
   ```

## Resources

### scripts/notify.sh

Bash script that performs the tmux notification. Includes:

- Two-step message sending
- Error reporting

The script is automatically executed when the skill is invoked.
