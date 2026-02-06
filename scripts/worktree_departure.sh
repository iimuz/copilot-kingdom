#!/usr/bin/env bash

# PHASE-1: Multi-Worktree Agent System Foundation Setup
# Creates git worktrees for Karo agents with shared context via symlinks

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# SHOGUN_WORKTREE="$HOME/src/github.com/iimuz/wt-copilot-kingdom-shogun"
# KARO_WORKTREE="$HOME/src/github.com/iimuz/wt-copilot-kingdom-karo"

# Context paths (fixed at repo root)
CONTEXT_BASE=".agent/kingdom"

# Worktree paths (configurable via environment variables)
WORKTREE_BASE="${WORKTREE_BASE:-./worktrees}"
KARO_COUNT="${KARO_COUNT:-1}"

# Derived paths (initialized after repo root detection)
REPO_ROOT=""
ABS_CONTEXT_BASE=""
ABS_SHOGUN_CONTEXT=""
SHOGUN_WORKTREE=""
SHOGUN_CONTEXT=""
SHOGUN_SHARED_CONTEXT=""
SHOGUN_DASHBOARD=""

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
  local resolved_target
  actual_target=$(readlink "${symlink_path}")

  if ! resolved_target=$(cd "$(dirname "${symlink_path}")" && cd "${actual_target}" && pwd -P); then
    log_error "Failed to resolve symlink target: ${symlink_path}"
    return 1
  fi

  if [[ "${resolved_target}" != "${expected_target}" ]]; then
    log_error "Symlink target mismatch: ${symlink_path}"
    log_error "  Expected: ${expected_target}"
    log_error "  Actual: ${actual_target}"
    log_error "  Resolved: ${resolved_target}"
    return 1
  fi

  log_info "Symlink valid: ${symlink_path} → ${expected_target}"
  return 0
}

validate_all_symlinks() {
  log_info "Validating symlinks..."

  local all_valid=true

  for ((i = 1; i <= KARO_COUNT; i++)); do
    local karo_worktree="${WORKTREE_BASE}/karo-${i}"
    local karo_symlink="${karo_worktree}/.agent/kingdom"
    if ! validate_symlink "${karo_symlink}" "${ABS_SHOGUN_CONTEXT}"; then
      all_valid=false
    fi
  done

  if [[ "${all_valid}" == true ]]; then
    log_info "All symlinks validated successfully"
    return 0
  else
    log_error "Symlink validation failed"
    return 1
  fi
}

# ============================================================================
# Worktree Creation Functions (Karo only)
# ============================================================================

create_worktree() {
  local worktree_path="$1"
  local base_branch="$2"
  local branch_name="$3"

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

  if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
    log_info "Branch already exists: ${branch_name}"
    if git worktree add "${worktree_path}" "${branch_name}"; then
      log_info "Worktree created successfully: ${worktree_path}"
      return 0
    else
      log_error "Failed to create worktree: ${worktree_path}"
      return 1
    fi
  fi

  if git worktree add -b "${branch_name}" "${worktree_path}" "${base_branch}"; then
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

initialize_shogun_workspace() {
  log_info "Initializing Shogun workspace..."

  # Create shared_context directory in Shogun context
  if [[ ! -d "${SHOGUN_SHARED_CONTEXT}" ]]; then
    mkdir -p "${SHOGUN_SHARED_CONTEXT}"
    log_info "Created shared_context directory: ${SHOGUN_SHARED_CONTEXT}"
  else
    log_warn "shared_context directory already exists: ${SHOGUN_SHARED_CONTEXT}"
  fi

  # Initialize shogun_to_karo.yaml
  local yaml_file="${SHOGUN_SHARED_CONTEXT}/shogun_to_karo.yaml"
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

  # Initialize dashboard.md in Shogun workspace
  if [[ ! -f "${SHOGUN_DASHBOARD}" ]]; then
    cat >"${SHOGUN_DASHBOARD}" <<EOF
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

*This dashboard is managed by Shogun and accessible to Karo via symlink.*
EOF
    log_info "Initialized dashboard: ${SHOGUN_DASHBOARD}"
  else
    log_warn "Dashboard already exists: ${SHOGUN_DASHBOARD}"
  fi
}

# ============================================================================
# Symlink Creation
# ============================================================================

create_symlinks() {
  local karo_worktree="$1"
  local karo_symlink="${karo_worktree}/.agent/kingdom"

  log_info "Creating symlink from Karo worktree to Shogun context..."

  local abs_shogun_context="${ABS_SHOGUN_CONTEXT}"

  mkdir -p "$(dirname "${karo_symlink}")"

  if [[ -L "${karo_symlink}" ]]; then
    local existing_target
    if existing_target=$(cd "$(dirname "${karo_symlink}")" && cd "$(readlink "${karo_symlink}")" && pwd -P); then
      if [[ "${existing_target}" == "${abs_shogun_context}" ]]; then
        log_info "Symlink already valid: ${karo_symlink} → ${abs_shogun_context}"
        return 0
      fi
    fi
  fi

  if [[ -L "${karo_symlink}" ]] || [[ -e "${karo_symlink}" ]]; then
    log_warn "Removing existing kingdom path: ${karo_symlink}"
    rm -rf "${karo_symlink}"
  fi

  ln -s "${abs_shogun_context}" "${karo_symlink}"
  log_info "Created symlink: ${karo_symlink} → ${abs_shogun_context}"
}

# ============================================================================
# Tmux Session Management (PHASE-4)
# ============================================================================

create_tmux_session() {
  local total_panes=$((KARO_COUNT + 1))

  log_info "Creating tmux session with 1x${total_panes} layout..."

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

  # Create 1x(N+1) grid: split horizontally for each Karo instance
  for ((i = 1; i <= KARO_COUNT; i++)); do
    tmux split-window -h -t "$AGENT_SESSION:$AGENT_WINDOW"
    tmux select-layout -t "$AGENT_SESSION:$AGENT_WINDOW" even-horizontal
  done

  # Set pane titles
  tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.0" -T "shogun"
  for ((i = 1; i <= KARO_COUNT; i++)); do
    tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.$i" -T "karo-$i"
  done

  log_info "Created 1x${total_panes} tmux grid successfully"
}

configure_pane_environment() {
  local pane_index="$1"
  local pane_name="$2"
  local worktree_path="$3"
  local extra_env_vars="${4:-}"

  log_info "Configuring ${pane_name} pane (${pane_index})..."

  # Get absolute worktree path
  local abs_worktree_path
  abs_worktree_path=$(cd "$(dirname "${worktree_path}")" && pwd)/$(basename "${worktree_path}")

  # TASK-027/TASK-028: cd to worktree
  # TASK-029/TASK-030: Set environment variables
  local env_vars="export AGENT_SESSION=${AGENT_SESSION}${extra_env_vars:+ ${extra_env_vars}}"

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
    if tmux capture-pane -t "$AGENT_SESSION:$AGENT_WINDOW.0" -p | grep -q "GitHub Copilot"; then
      log_info "  Shogun Copilot CLI ready (${waited}s)"
      break
    fi
    sleep 1
    echo "wait ...."
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

  # Ensure we're in a git repository
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not a git repository. Please run this script from the repository root."
    exit 1
  fi

  REPO_ROOT=$(git rev-parse --show-toplevel)
  ABS_CONTEXT_BASE="${REPO_ROOT}/${CONTEXT_BASE}"
  SHOGUN_WORKTREE="${REPO_ROOT}"
  SHOGUN_CONTEXT="${ABS_CONTEXT_BASE}/shogun"
  ABS_SHOGUN_CONTEXT="$(cd "${SHOGUN_WORKTREE}" && pwd -P)/${CONTEXT_BASE}/shogun"
  SHOGUN_SHARED_CONTEXT="${SHOGUN_CONTEXT}/shared_context"
  SHOGUN_DASHBOARD="${SHOGUN_CONTEXT}/dashboard.md"

  log_info "  Context base: ${CONTEXT_BASE}"
  log_info "  Worktree base: ${WORKTREE_BASE}"
  log_info "  Shogun worktree: ${SHOGUN_WORKTREE}"
  log_info "  Karo count: ${KARO_COUNT}"

  # Get current branch
  local current_branch
  current_branch=$(git branch --show-current)
  log_info "Current branch: ${current_branch}"

  # TASK-003: Create Karo worktrees
  for ((i = 1; i <= KARO_COUNT; i++)); do
    local karo_path="${WORKTREE_BASE}/karo-${i}"
    local karo_branch="worktree/karo-${i}"
    if ! create_worktree "${karo_path}" "${current_branch}" "${karo_branch}"; then
      log_error "Failed to create Karo worktree"
      exit 1
    fi
  done

  # TASK-004, TASK-007, TASK-008: Initialize Shogun workspace
  if ! initialize_shogun_workspace; then
    log_error "Failed to initialize Shogun workspace"
    exit 1
  fi

  # TASK-005: Create symlinks
  for ((i = 1; i <= KARO_COUNT; i++)); do
    local karo_path="${WORKTREE_BASE}/karo-${i}"
    if ! create_symlinks "${karo_path}"; then
      log_error "Failed to create symlinks"
      exit 1
    fi
  done

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
  local karo_env_vars
  karo_env_vars=$(
    printf 'AGENT_PANE_KARO=1'
    for ((i = 1; i <= KARO_COUNT; i++)); do printf ' AGENT_PANE_KARO_%s=%s' "$i" "$i"; done
  )
  configure_pane_environment 0 "shogun" "${SHOGUN_WORKTREE}" "${karo_env_vars}"

  # TASK-028, TASK-030: Configure Karo panes
  for ((i = 1; i <= KARO_COUNT; i++)); do
    local pane_index=$i
    local karo_path="${WORKTREE_BASE}/karo-${i}"
    configure_pane_environment "${pane_index}" "karo-${i}" "${karo_path}" "AGENT_PANE_SHOGUN=0"
  done

  # TASK-031: Launch Copilot CLI in Shogun pane
  launch_copilot_cli 0 "shogun"

  # TASK-032: Launch Copilot CLI in Karo pane
  for ((i = 1; i <= KARO_COUNT; i++)); do
    local pane_index=$i
    launch_copilot_cli "${pane_index}" "karo"
  done

  # TASK-033: Validate startup
  # validate_copilot_startup
  sleep 10

  log_info ""
  log_info "Multi-Worktree Agent System deployment complete"
  log_info ""
  log_info "Workspace structure:"
  log_info "  Shogun: ${SHOGUN_WORKTREE}"
  for ((i = 1; i <= KARO_COUNT; i++)); do
    log_info "  Karo-${i}:   ${WORKTREE_BASE}/karo-${i}"
  done
  log_info ""
  log_info "Symlinks:"
  for ((i = 1; i <= KARO_COUNT; i++)); do
    log_info "  ${WORKTREE_BASE}/karo-${i}/.agent/kingdom → ${SHOGUN_CONTEXT}"
  done
  log_info ""
  log_info "Tmux session:"
  log_info "  Session: ${AGENT_SESSION}"
  log_info "  Window: ${AGENT_WINDOW}"
  log_info "  Panes: $((KARO_COUNT + 1)) (shogun, karo-1..karo-${KARO_COUNT})"
  log_info ""
  log_info "Connect with: tmux attach-session -t ${AGENT_SESSION}"
  log_info ""
}

# Run main function
main "$@"
