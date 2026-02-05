#!/usr/bin/env bash

# PHASE-1: Multi-Worktree Agent System Foundation Setup
# Creates git worktrees for Shogun and Karo agents with shared context via symlinks

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Worktree paths (configurable via environment variables)
WORKTREE_BASE="${WORKTREE_BASE:-./worktrees}"
SHOGUN_WORKTREE="${SHOGUN_WORKTREE:-${WORKTREE_BASE}/shogun}"
KARO_WORKTREE="${KARO_WORKTREE:-${WORKTREE_BASE}/karo-1}"

# Shared context paths
KARO_SHARED_CONTEXT="${KARO_WORKTREE}/shared_context"
KARO_DASHBOARD="${KARO_WORKTREE}/dashboard.md"

# Symlink paths in Shogun workspace
SHOGUN_QUEUE_SYMLINK="${SHOGUN_WORKTREE}/queue"
SHOGUN_DASHBOARD_SYMLINK="${SHOGUN_WORKTREE}/dashboard.md"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_symlink() {
  local symlink_path="$1"
  local expected_target="$2"

  if [[ ! -L "${symlink_path}" ]]; then
    log_error "Symlink does not exist: ${symlink_path}"
    return 1
  fi

  if [[ ! -e "${symlink_path}" ]]; then
    log_error "Symlink is broken: ${symlink_path}"
    return 1
  fi

  local actual_target
  actual_target=$(readlink "${symlink_path}")

  if [[ "${actual_target}" != "${expected_target}" ]]; then
    log_error "Symlink target mismatch: ${symlink_path}"
    log_error "  Expected: ${expected_target}"
    log_error "  Actual: ${actual_target}"
    return 1
  fi

  log_info "Symlink valid: ${symlink_path} → ${expected_target}"
  return 0
}

validate_all_symlinks() {
  log_info "Validating symlinks..."

  local all_valid=true

  # Convert to absolute paths for validation
  local abs_karo_shared_context
  abs_karo_shared_context=$(cd "$(dirname "${KARO_SHARED_CONTEXT}")" && pwd)/$(basename "${KARO_SHARED_CONTEXT}")

  local abs_karo_dashboard
  abs_karo_dashboard=$(cd "$(dirname "${KARO_DASHBOARD}")" && pwd)/$(basename "${KARO_DASHBOARD}")

  if ! validate_symlink "${SHOGUN_QUEUE_SYMLINK}" "${abs_karo_shared_context}"; then
    all_valid=false
  fi

  if ! validate_symlink "${SHOGUN_DASHBOARD_SYMLINK}" "${abs_karo_dashboard}"; then
    all_valid=false
  fi

  if [[ "${all_valid}" == true ]]; then
    log_info "All symlinks validated successfully"
    return 0
  else
    log_error "Symlink validation failed"
    return 1
  fi
}

# ============================================================================
# Worktree Creation Functions
# ============================================================================

create_worktree() {
  local worktree_path="$1"
  local base_branch="$2"

  log_info "Creating worktree: ${worktree_path}"

  # Create worktree directory if it doesn't exist
  local worktree_dir
  worktree_dir=$(dirname "${worktree_path}")
  mkdir -p "${worktree_dir}"

  # Check if worktree already exists
  if git worktree list | grep -q "${worktree_path}"; then
    log_warn "Worktree already exists: ${worktree_path}"
    return 0
  fi

  # Create the worktree with --detach option to avoid branch conflicts
  if git worktree add --detach "${worktree_path}" "${base_branch}"; then
    log_info "Worktree created successfully: ${worktree_path}"
    return 0
  else
    log_error "Failed to create worktree: ${worktree_path}"
    return 1
  fi
}

# ============================================================================
# Directory and File Initialization
# ============================================================================

initialize_karo_workspace() {
  log_info "Initializing Karo workspace..."

  # Create shared_context directory
  if [[ ! -d "${KARO_SHARED_CONTEXT}" ]]; then
    mkdir -p "${KARO_SHARED_CONTEXT}"
    log_info "Created shared_context directory: ${KARO_SHARED_CONTEXT}"
  else
    log_warn "shared_context directory already exists: ${KARO_SHARED_CONTEXT}"
  fi

  # Initialize shogun_to_karo.yaml
  local yaml_file="${KARO_SHARED_CONTEXT}/shogun_to_karo.yaml"
  if [[ ! -f "${yaml_file}" ]]; then
    cat >"${yaml_file}" <<EOF
# Communication channel: Shogun → Karo
# This file is written by Shogun and read by Karo
# Format: YAML

status: idle
timestamp: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
message: "Initialization complete"
task: null
EOF
    log_info "Initialized YAML file: ${yaml_file}"
  else
    log_warn "YAML file already exists: ${yaml_file}"
  fi

  # Initialize dashboard.md
  if [[ ! -f "${KARO_DASHBOARD}" ]]; then
    cat >"${KARO_DASHBOARD}" <<EOF
# Multi-Agent Dashboard

**Last Updated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## System Status

- **Shogun**: Idle
- **Karo**: Idle

## Active Tasks

None

## Recent Activity

- System initialized

---

*This dashboard is managed by Karo and accessible to Shogun via symlink.*
EOF
    log_info "Initialized dashboard: ${KARO_DASHBOARD}"
  else
    log_warn "Dashboard already exists: ${KARO_DASHBOARD}"
  fi
}

# ============================================================================
# Symlink Creation
# ============================================================================

create_symlinks() {
  log_info "Creating symlinks from Shogun to Karo workspace..."

  # Get absolute paths for symlink targets
  local abs_karo_shared_context
  abs_karo_shared_context=$(cd "${KARO_WORKTREE}" && pwd)/shared_context

  local abs_karo_dashboard
  abs_karo_dashboard=$(cd "${KARO_WORKTREE}" && pwd)/dashboard.md

  # Create queue symlink
  if [[ -L "${SHOGUN_QUEUE_SYMLINK}" ]] || [[ -e "${SHOGUN_QUEUE_SYMLINK}" ]]; then
    log_warn "Removing existing queue path: ${SHOGUN_QUEUE_SYMLINK}"
    rm -rf "${SHOGUN_QUEUE_SYMLINK}"
  fi

  ln -s "${abs_karo_shared_context}" "${SHOGUN_QUEUE_SYMLINK}"
  log_info "Created symlink: ${SHOGUN_QUEUE_SYMLINK} → ${abs_karo_shared_context}"

  # Create dashboard symlink
  if [[ -L "${SHOGUN_DASHBOARD_SYMLINK}" ]] || [[ -e "${SHOGUN_DASHBOARD_SYMLINK}" ]]; then
    log_warn "Removing existing dashboard path: ${SHOGUN_DASHBOARD_SYMLINK}"
    rm -rf "${SHOGUN_DASHBOARD_SYMLINK}"
  fi

  ln -s "${abs_karo_dashboard}" "${SHOGUN_DASHBOARD_SYMLINK}"
  log_info "Created symlink: ${SHOGUN_DASHBOARD_SYMLINK} → ${abs_karo_dashboard}"
}

# ============================================================================
# Tmux Session Management (PHASE-4)
# ============================================================================

create_tmux_session() {
  log_info "Creating tmux session with 1x2 layout..."

  # Check if running inside tmux
  local inside_tmux=false
  if [[ -n "$TMUX" ]]; then
    inside_tmux=true
  fi

  # TASK-026: Create 1x2 tmux grid (not 3x3)
  if [[ "${inside_tmux}" == true ]]; then
    AGENT_SESSION=$(tmux display-message -p "#{session_name}")
    CURRENT_WINDOW=$(tmux display-message -p "#{window_name}")
    AGENT_WINDOW="${CURRENT_WINDOW}-agents"
    tmux new-window -t "$AGENT_SESSION" -n "$AGENT_WINDOW"
    log_info "Running inside tmux, created new window: ${AGENT_WINDOW}"
  else
    AGENT_SESSION="multi"
    AGENT_WINDOW="agents"
    tmux new-session -d -s "$AGENT_SESSION" -n "$AGENT_WINDOW"
    log_info "Created new tmux session: ${AGENT_SESSION}"
  fi

  # Create 1x2 grid: split horizontally once
  tmux split-window -h -t "$AGENT_SESSION:$AGENT_WINDOW"

  # Set pane titles
  tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.0" -T "shogun"
  tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.1" -T "karo"

  log_info "Created 1x2 tmux grid successfully"
}

configure_pane_environment() {
  local pane_index="$1"
  local pane_name="$2"
  local worktree_path="$3"
  local other_pane_index="$4"
  local other_pane_name="$5"

  log_info "Configuring ${pane_name} pane (${pane_index})..."

  # Get absolute worktree path
  local abs_worktree_path
  abs_worktree_path=$(cd "$(dirname "${worktree_path}")" && pwd)/$(basename "${worktree_path}")

  # TASK-027/TASK-028: cd to worktree
  # TASK-029/TASK-030: Set environment variables
  local env_vars="export AGENT_SESSION=${AGENT_SESSION} AGENT_PANE_${other_pane_name^^}=${other_pane_index}"

  tmux send-keys -t "$AGENT_SESSION:$AGENT_WINDOW.${pane_index}" \
    "cd ${abs_worktree_path} && ${env_vars} && clear" Enter

  log_info "  Environment configured for ${pane_name}"
}

launch_copilot_cli() {
  local pane_index="$1"
  local agent_name="$2"

  log_info "Launching Copilot CLI for ${agent_name}..."

  # TASK-031/TASK-032: Launch Copilot CLI with --agent flag
  tmux send-keys -t "$AGENT_SESSION:$AGENT_WINDOW.${pane_index}" \
    "copilot --agent ${agent_name} --model claude-haiku-4.5 --allow-all-tools" Enter

  log_info "  Copilot CLI launched for ${agent_name}"
}

validate_copilot_startup() {
  log_info "Validating Copilot CLI startup..."

  # TASK-033: Wait for Copilot CLI to be ready
  local max_wait=30
  local waited=0

  while [[ ${waited} -lt ${max_wait} ]]; do
    if tmux capture-pane -t "$AGENT_SESSION:$AGENT_WINDOW.0" -p | grep -q "cycle mode"; then
      log_info "  Shogun Copilot CLI ready (${waited}s)"
      break
    fi
    sleep 1
    ((waited++))
  done

  if [[ ${waited} -ge ${max_wait} ]]; then
    log_warn "Copilot CLI startup validation timeout (${max_wait}s)"
    log_warn "Copilot may still be initializing"
  else
    log_info "Copilot CLI startup validated successfully"
  fi
}

# ============================================================================
# Main Setup Flow
# ============================================================================

main() {
  log_info "Starting Multi-Worktree Agent System setup..."
  log_info "Configuration:"
  log_info "  Worktree base: ${WORKTREE_BASE}"
  log_info "  Shogun worktree: ${SHOGUN_WORKTREE}"
  log_info "  Karo worktree: ${KARO_WORKTREE}"

  # Ensure we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not a git repository. Please run this script from the repository root."
    exit 1
  fi

  # Get current branch
  local current_branch
  current_branch=$(git branch --show-current)
  log_info "Current branch: ${current_branch}"

  # TASK-002: Create Shogun worktree
  if ! create_worktree "${SHOGUN_WORKTREE}" "${current_branch}"; then
    log_error "Failed to create Shogun worktree"
    exit 1
  fi

  # TASK-003: Create Karo worktree
  if ! create_worktree "${KARO_WORKTREE}" "${current_branch}"; then
    log_error "Failed to create Karo worktree"
    exit 1
  fi

  # TASK-004, TASK-007, TASK-008: Initialize Karo workspace
  if ! initialize_karo_workspace; then
    log_error "Failed to initialize Karo workspace"
    exit 1
  fi

  # TASK-005: Create symlinks
  if ! create_symlinks; then
    log_error "Failed to create symlinks"
    exit 1
  fi

  # TASK-006: Validate symlinks
  if ! validate_all_symlinks; then
    log_error "Symlink validation failed"
    exit 1
  fi

  log_info ""
  log_info "Workspace setup complete"
  log_info ""

  # PHASE-4: Create tmux session and launch agents
  if ! create_tmux_session; then
    log_error "Failed to create tmux session"
    exit 1
  fi

  # TASK-027, TASK-029: Configure Shogun pane
  configure_pane_environment 0 "shogun" "${SHOGUN_WORKTREE}" 1 "karo"

  # TASK-028, TASK-030: Configure Karo pane
  configure_pane_environment 1 "karo" "${KARO_WORKTREE}" 0 "shogun"

  # TASK-031: Launch Copilot CLI in Shogun pane
  launch_copilot_cli 0 "shogun"

  # TASK-032: Launch Copilot CLI in Karo pane
  launch_copilot_cli 1 "karo"

  # TASK-033: Validate startup
  validate_copilot_startup

  log_info ""
  log_info "Multi-Worktree Agent System deployment complete"
  log_info ""
  log_info "Workspace structure:"
  log_info "  Shogun: ${SHOGUN_WORKTREE}"
  log_info "  Karo:   ${KARO_WORKTREE}"
  log_info ""
  log_info "Symlinks:"
  log_info "  ${SHOGUN_QUEUE_SYMLINK} → Karo's shared_context/"
  log_info "  ${SHOGUN_DASHBOARD_SYMLINK} → Karo's dashboard.md"
  log_info ""
  log_info "Tmux session:"
  log_info "  Session: ${AGENT_SESSION}"
  log_info "  Window: ${AGENT_WINDOW}"
  log_info "  Panes: 2 (shogun, karo)"
  log_info ""
  log_info "Connect with: tmux attach-session -t ${AGENT_SESSION}"
  log_info ""
}

# Run main function
main "$@"
