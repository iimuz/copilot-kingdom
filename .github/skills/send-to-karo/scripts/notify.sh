#!/usr/bin/env bash
# send-to-karo notification script
# Notifies karo agent that new tasks are available in the queue
#
# Usage: notify.sh <karo_pane_number>
# Example: notify.sh 1  (targets karo-1)

set -euo pipefail

# Validate arguments
if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename "$0") <karo_pane_number>" >&2
  echo "Example: $(basename "$0") 1" >&2
  exit 1
fi

readonly karo_pane_number="$1"

if ! [[ "${karo_pane_number}" =~ ^[0-9]+$ ]]; then
  echo "Error: karo_pane_number must be a numeric integer >= 0, got: ${karo_pane_number}" >&2
  exit 1
fi

# Detect tmux session and window
if [[ -n "${TMUX:-}" ]]; then
  AGENT_SESSION=$(tmux display-message -p "#{session_name}")
  readonly AGENT_SESSION
  AGENT_WINDOW=$(tmux display-message -p "#{window_name}")
  AGENT_WINDOW="${AGENT_WINDOW}-agents"
  readonly AGENT_WINDOW
else
  readonly AGENT_SESSION="multi"
  readonly AGENT_WINDOW="agents"
fi

readonly TARGET="${AGENT_SESSION}:${AGENT_WINDOW}.${karo_pane_number}"
readonly MESSAGE="New task available. Check shared_context/shogun_to_karo.yaml and execute."

# Send notification to karo's pane (two-step: message + enter)
tmux send-keys -t "${TARGET}" "$MESSAGE"
sleep 1
tmux send-keys -t "${TARGET}" Enter

echo "Notification sent to karo (target: ${TARGET})"
