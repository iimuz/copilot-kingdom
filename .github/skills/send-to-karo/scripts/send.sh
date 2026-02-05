#!/bin/bash
# send-to-karo notification script
# Notifies Karo agent that new tasks are available in the queue

set -e

# Validate environment
if [ -z "$AGENT_SESSION" ]; then
  echo "Error: AGENT_SESSION environment variable not set"
  exit 1
fi

if [ -z "$AGENT_PANE_KARO" ]; then
  echo "Error: AGENT_PANE_KARO environment variable not set"
  exit 1
fi

# Notification message
MESSAGE="New task available. Check shared_context/shogun_to_karo.yaml and execute."

# Send notification to Karo's pane (two-step: message + enter)
tmux send-keys -t "${AGENT_SESSION}:0.${AGENT_PANE_KARO}" "$MESSAGE"
sleep 1
tmux send-keys -t "${AGENT_SESSION}:0.${AGENT_PANE_KARO}" Enter

echo "✓ Notification sent to Karo (pane ${AGENT_PANE_KARO})"
