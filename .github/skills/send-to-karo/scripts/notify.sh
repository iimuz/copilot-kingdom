#!/usr/bin/env bash
# send-to-karo notification script
# Notifies karo agent that new tasks are available in the queue

set -euo pipefail

# Validate environment variables
if [[ -z "${AGENT_SESSION:-}" ]]; then
  echo "Error: AGENT_SESSION environment variable not set" >&2
  exit 1
fi

if [[ -z "${AGENT_PANE_KARO:-}" ]]; then
  echo "Error: AGENT_PANE_KARO environment variable not set" >&2
  exit 1
fi

# Notification message
readonly MESSAGE="New task available. Check shared_context/shogun_to_karo.yaml and execute."

# Send notification to karo's pane (two-step: message + enter)
tmux send-keys -t "${AGENT_SESSION}:0.${AGENT_PANE_KARO}" "$MESSAGE"
sleep 1
tmux send-keys -t "${AGENT_SESSION}:0.${AGENT_PANE_KARO}" Enter

echo "✓ Notification sent to karo (session: ${AGENT_SESSION}, pane: ${AGENT_PANE_KARO})"
