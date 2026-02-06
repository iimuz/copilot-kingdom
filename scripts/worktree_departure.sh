#!/usr/bin/env bash

# PHASE-1: Multi-Worktree Agent System Foundation Setup
# Creates git worktrees for Karo agents with shared context via symlinks

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Context paths (fixed at repo root)
CONTEXT_BASE=".agent/kingdom"

# Optional external configuration file (sourced when set)
WORKTREE_CONFIG_FILE="${WORKTREE_CONFIG_FILE:-}"

# Inline configuration (can be overridden by WORKTREE_CONFIG_FILE)
SHOGUN_PATH="${SHOGUN_PATH:-}"
KARO_COUNT="${KARO_COUNT:-}"
if [[ -z "${KARO_PATHS+x}" ]]; then
  KARO_PATHS=()
fi

# Example configuration:
# SHOGUN_PATH="/path/to/shogun"
# KARO_PATHS=("/path/to/karo-1" "/path/to/karo-2")
# KARO_COUNT=1

# Runtime state
DRY_RUN=false
EFFECTIVE_KARO_COUNT=0

# Derived paths (initialized after resolution)
REPO_ROOT=""
REPO_NAME=""
ABS_SHOGUN_PATH=""
ABS_SHOGUN_CONTEXT=""
SHOGUN_SHARED_CONTEXT=""
SHOGUN_DASHBOARD=""
RESOLVED_KARO_PATHS=()
ACTIVE_KARO_PATHS=()

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
# Configuration and Validation Functions
# ============================================================================

parse_args() {
  for arg in "$@"; do
    case "${arg}" in
    --check | --dry-run)
      DRY_RUN=true
      ;;
    *)
      log_error "Unknown argument: ${arg}"
      exit 1
      ;;
    esac
  done
}

load_external_configuration() {
  if [[ -n "${WORKTREE_CONFIG_FILE}" ]]; then
    if [[ ! -f "${WORKTREE_CONFIG_FILE}" ]]; then
      log_error "WORKTREE_CONFIG_FILE not found: ${WORKTREE_CONFIG_FILE}"
      exit 1
    fi
    # Check ownership and permissions
    if [[ -O "${WORKTREE_CONFIG_FILE}" ]]; then
      local perms
      perms=$(stat -f "%Lp" "${WORKTREE_CONFIG_FILE}" 2>/dev/null || stat -c "%a" "${WORKTREE_CONFIG_FILE}" 2>/dev/null)
      if [[ "${perms: -2:1}" != "0" ]] || [[ "${perms: -1:1}" != "0" ]]; then
        log_error "Config file has unsafe permissions (group/world writable): ${WORKTREE_CONFIG_FILE}"
        return 1
      fi
    else
      log_warn "Config file not owned by current user: ${WORKTREE_CONFIG_FILE}"
    fi
    log_info "Sourcing configuration from ${WORKTREE_CONFIG_FILE}"
    # shellcheck source=/dev/null
    source "${WORKTREE_CONFIG_FILE}"
  fi
}

apply_legacy_configuration() {
  if [[ -n "${SHOGUN_PATH}" || ${#KARO_PATHS[@]} -gt 0 ]]; then
    return 0
  fi

  if [[ -z "${WORKTREE_BASE:-}" && "${WORKTREE_BASE_OVERRIDE:-}" != "true" ]]; then
    return 0
  fi

  log_warn "WORKTREE_BASE compatibility is deprecated and will be removed after 2026-06-01."
  log_warn "Migrate to SHOGUN_PATH/KARO_PATHS or WORKTREE_CONFIG_FILE."

  local legacy_repo_root
  if ! legacy_repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    log_error "Legacy WORKTREE_BASE requires running from a git repository."
    exit 1
  fi

  local legacy_repo_name
  legacy_repo_name=$(basename "${legacy_repo_root}")

  local legacy_override=false
  if [[ -n "${WORKTREE_BASE:-}" || "${WORKTREE_BASE_OVERRIDE:-}" == "true" ]]; then
    legacy_override=true
  fi

  local legacy_base
  if [[ "${legacy_override}" == true ]]; then
    if [[ -z "${WORKTREE_BASE:-}" ]]; then
      log_error "WORKTREE_BASE_OVERRIDE requires WORKTREE_BASE to be set."
      exit 1
    fi
    legacy_base="${WORKTREE_BASE}"
    SHOGUN_PATH="${legacy_repo_root}"
  else
    legacy_base="$(cd "${legacy_repo_root}/.." && pwd -P)"
    SHOGUN_PATH="${legacy_base}/wt-${legacy_repo_name}-shogun"
  fi

  local legacy_count="${KARO_COUNT:-1}"
  local legacy_karo_paths=()
  local index
  for ((index = 1; index <= legacy_count; index++)); do
    if [[ "${legacy_override}" == true ]]; then
      legacy_karo_paths+=("${legacy_base}/karo-${index}")
    else
      legacy_karo_paths+=("${legacy_base}/wt-${legacy_repo_name}-karo-${index}")
    fi
  done
  KARO_PATHS=("${legacy_karo_paths[@]}")
}

validate_configuration() {
  if [[ -z "${SHOGUN_PATH}" ]]; then
    log_error "SHOGUN_PATH is required and must point to an existing directory."
    exit 1
  fi

  if [[ ${#KARO_PATHS[@]} -eq 0 ]]; then
    log_error "KARO_PATHS must include at least one path."
    exit 1
  fi

  if [[ -n "${KARO_COUNT}" ]]; then
    if [[ ! "${KARO_COUNT}" =~ ^[0-9]+$ ]]; then
      log_error "KARO_COUNT must be a non-negative integer."
      exit 1
    fi
    EFFECTIVE_KARO_COUNT="${KARO_COUNT}"
  else
    EFFECTIVE_KARO_COUNT="${#KARO_PATHS[@]}"
  fi

  if [[ "${EFFECTIVE_KARO_COUNT}" -lt 1 ]]; then
    log_error "EFFECTIVE_KARO_COUNT must be at least 1."
    exit 1
  fi

  if [[ "${EFFECTIVE_KARO_COUNT}" -gt "${#KARO_PATHS[@]}" ]]; then
    log_error "KARO_COUNT (${EFFECTIVE_KARO_COUNT}) exceeds KARO_PATHS length (${#KARO_PATHS[@]})."
    exit 1
  fi
}

resolve_path() {
  local input="$1"
  if [[ -z "${input}" ]]; then
    return 1
  fi

  local parent
  local base
  if [[ "${input}" == /* ]]; then
    if [[ -e "${input}" ]]; then
      (cd "${input}" && pwd -P)
      return 0
    fi
    parent=$(dirname "${input}")
    base=$(basename "${input}")
  else
    if [[ -e "${input}" ]]; then
      (cd "${input}" && pwd -P)
      return 0
    fi
    parent=$(dirname "${input}")
    base=$(basename "${input}")
  fi

  if [[ -d "${parent}" ]]; then
    (cd "${parent}" && printf "%s/%s" "$(pwd -P)" "${base}")
    return 0
  fi

  return 1
}

resolve_paths() {
  local resolved_shogun
  if ! resolved_shogun=$(resolve_path "${SHOGUN_PATH}"); then
    log_error "Unable to resolve SHOGUN_PATH: ${SHOGUN_PATH}"
    exit 1
  fi
  ABS_SHOGUN_PATH="${resolved_shogun}"

  RESOLVED_KARO_PATHS=()
  local karo_path
  for karo_path in "${KARO_PATHS[@]}"; do
    local resolved_karo
    if ! resolved_karo=$(resolve_path "${karo_path}"); then
      log_error "Unable to resolve KARO_PATH: ${karo_path}"
      exit 1
    fi
    RESOLVED_KARO_PATHS+=("${resolved_karo}")
  done

  ACTIVE_KARO_PATHS=("${RESOLVED_KARO_PATHS[@]:0:${EFFECTIVE_KARO_COUNT}}")
  ABS_SHOGUN_CONTEXT="${ABS_SHOGUN_PATH}/${CONTEXT_BASE}/shogun"
  SHOGUN_SHARED_CONTEXT="${ABS_SHOGUN_CONTEXT}/shared_context"
  SHOGUN_DASHBOARD="${ABS_SHOGUN_CONTEXT}/dashboard.md"
}

detect_duplicates() {
  local paths=("$@")
  local count=${#paths[@]}
  local i
  local j
  for ((i = 0; i < count; i++)); do
    for ((j = i + 1; j < count; j++)); do
      if [[ "${paths[$i]}" == "${paths[$j]}" ]]; then
        log_error "Duplicate path detected: ${paths[$i]}"
        return 1
      fi
    done
  done
  return 0
}

ensure_writable_parent() {
  local target="$1"
  local parent
  parent=$(dirname "${target}")

  while [[ ! -d "${parent}" && "${parent}" != "/" ]]; do
    parent=$(dirname "${parent}")
  done

  if [[ ! -d "${parent}" ]]; then
    log_error "No existing parent directory for ${target}"
    return 1
  fi

  if [[ ! -w "${parent}" ]]; then
    log_error "No write permission for ${parent} (needed for ${target})"
    return 1
  fi

  return 0
}

git_common_dir_abs() {
  local path="$1"
  local common_dir
  if ! common_dir=$(git -C "${path}" rev-parse --git-common-dir 2>/dev/null); then
    return 1
  fi

  if ! (cd "${path}" && cd "${common_dir}" && pwd -P); then
    return 1
  fi

  return 0
}

validate_paths() {
  if [[ ! -d "${ABS_SHOGUN_PATH}" ]]; then
    log_error "SHOGUN_PATH does not exist or is not a directory: ${ABS_SHOGUN_PATH}"
    exit 1
  fi

  if ! git -C "${ABS_SHOGUN_PATH}" rev-parse --git-dir >/dev/null 2>&1; then
    log_error "SHOGUN_PATH is not a git repository: ${ABS_SHOGUN_PATH}"
    exit 1
  fi

  if ! ensure_writable_parent "${ABS_SHOGUN_CONTEXT}"; then
    exit 1
  fi

  local all_paths=("${ABS_SHOGUN_PATH}" "${RESOLVED_KARO_PATHS[@]}")
  if ! detect_duplicates "${all_paths[@]}"; then
    exit 1
  fi

  local shogun_common_dir
  if ! shogun_common_dir=$(git_common_dir_abs "${ABS_SHOGUN_PATH}"); then
    log_error "Unable to determine SHOGUN_PATH git common dir: ${ABS_SHOGUN_PATH}"
    exit 1
  fi

  local karo_path
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    if [[ -e "${karo_path}" && ! -d "${karo_path}" ]]; then
      log_error "Karo path exists but is not a directory: ${karo_path}"
      exit 1
    fi

    if ! ensure_writable_parent "${karo_path}"; then
      exit 1
    fi

    if [[ -d "${karo_path}" ]]; then
      if ! git -C "${karo_path}" rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Karo path exists but is not a git worktree: ${karo_path}"
        exit 1
      fi

      local karo_common_dir
      if karo_common_dir=$(git_common_dir_abs "${karo_path}"); then
        if [[ "${karo_common_dir}" != "${shogun_common_dir}" ]]; then
          log_warn "Karo path uses a different git repository: ${karo_path}"
        fi
      fi
    fi
  done
}

log_planned_actions() {
  log_info "Dry-run enabled. No changes will be made."
  log_info "Planned actions:"
  log_info "  Initialize Shogun workspace: ${ABS_SHOGUN_CONTEXT}"

  local worktree_list
  worktree_list=$(git -C "${ABS_SHOGUN_PATH}" worktree list)

  local index=0
  local karo_path
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    index=$((index + 1))
    if echo "${worktree_list}" | grep -F -q "${karo_path}"; then
      log_info "  Reuse Karo worktree (${index}): ${karo_path}"
    else
      log_info "  Create Karo worktree (${index}): ${karo_path}"
    fi
    log_info "  Create symlink: ${karo_path}/.agent/kingdom → ${ABS_SHOGUN_CONTEXT}"
  done

  log_info "  Create tmux session with ${EFFECTIVE_KARO_COUNT} Karo pane(s)"
  log_info "  Launch Copilot CLI in each Karo pane"
}

# ============================================================================
# Symlink Validation
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

  local karo_path
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    local karo_symlink="${karo_path}/.agent/kingdom"
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
  if git -C "${ABS_SHOGUN_PATH}" worktree list | grep -F -q "${worktree_path}"; then
    log_warn "Worktree already exists: ${worktree_path}"
    return 0
  fi

  if git -C "${ABS_SHOGUN_PATH}" show-ref --verify --quiet "refs/heads/${branch_name}"; then
    log_info "Branch already exists: ${branch_name}"
    if git -C "${ABS_SHOGUN_PATH}" worktree add "${worktree_path}" "${branch_name}"; then
      log_info "Worktree created successfully: ${worktree_path}"
      return 0
    else
      log_error "Failed to create worktree: ${worktree_path}"
      return 1
    fi
  fi

  if git -C "${ABS_SHOGUN_PATH}" worktree add -b "${branch_name}" "${worktree_path}" "${base_branch}"; then
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

  if [[ -L "${karo_symlink}" ]]; then
    log_warn "Removing existing kingdom path: ${karo_symlink}"
    unlink "${karo_symlink}"
  elif [[ -e "${karo_symlink}" ]]; then
    log_error "Expected symlink but found regular file/directory: ${karo_symlink}"
    return 1
  fi

  ln -s "${abs_shogun_context}" "${karo_symlink}"
  log_info "Created symlink: ${karo_symlink} → ${abs_shogun_context}"
}

# ============================================================================
# Tmux Session Management (PHASE-4)
# ============================================================================

create_tmux_session() {
  local total_panes="${EFFECTIVE_KARO_COUNT}"

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

  # Create 1xN grid: split horizontally for each Karo instance
  if [[ "${total_panes}" -gt 1 ]]; then
    for ((i = 1; i < total_panes; i++)); do
      tmux split-window -h -t "$AGENT_SESSION:$AGENT_WINDOW"
      tmux select-layout -t "$AGENT_SESSION:$AGENT_WINDOW" even-horizontal
    done
  fi

  # Set pane titles
  for ((i = 1; i <= EFFECTIVE_KARO_COUNT; i++)); do
    local pane_index=$((i - 1))
    tmux select-pane -t "$AGENT_SESSION:$AGENT_WINDOW.${pane_index}" -T "karo-${i}"
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
  abs_worktree_path=$(cd "${worktree_path}" && pwd -P)

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
      log_info "  Karo Copilot CLI ready (${waited}s)"
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
  parse_args "$@"

  log_info "Starting Multi-Worktree Agent System setup..."

  load_external_configuration
  apply_legacy_configuration
  validate_configuration
  resolve_paths
  validate_paths

  REPO_ROOT=$(git -C "${ABS_SHOGUN_PATH}" rev-parse --show-toplevel)
  REPO_NAME=$(basename "${REPO_ROOT}")

  log_info "Configuration:"
  log_info "  Shogun path: ${ABS_SHOGUN_PATH}"
  log_info "  Karo count: ${EFFECTIVE_KARO_COUNT}"
  if [[ -n "${WORKTREE_CONFIG_FILE}" ]]; then
    log_info "  Config file: ${WORKTREE_CONFIG_FILE}"
  fi
  local index=0
  local karo_path
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    index=$((index + 1))
    log_info "  Karo-${index}: ${karo_path}"
  done
  log_info "  Example:"
  log_info "    SHOGUN_PATH=\"/path/to/shogun\""
  log_info "    KARO_PATHS=(\"/path/to/karo-1\" \"/path/to/karo-2\")"
  log_info "    KARO_COUNT=1"
  log_info "    WORKTREE_CONFIG_FILE=\"/path/to/worktree-config.sh\""

  if [[ "${DRY_RUN}" == true ]]; then
    log_planned_actions
    exit 0
  fi

  # Get current branch
  local current_branch
  current_branch=$(git -C "${ABS_SHOGUN_PATH}" branch --show-current)
  log_info "Current branch: ${current_branch}"

  # TASK-004, TASK-007, TASK-008: Initialize Shogun workspace
  if ! initialize_shogun_workspace; then
    log_error "Failed to initialize Shogun workspace"
    exit 1
  fi

  # TASK-003: Create Karo worktrees
  index=0
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    index=$((index + 1))
    local karo_branch="worktree/karo-${index}"
    if ! create_worktree "${karo_path}" "${current_branch}" "${karo_branch}"; then
      log_error "Failed to create Karo worktree"
      exit 1
    fi
  done

  # TASK-005: Create symlinks
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
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

  # TASK-028, TASK-030: Configure Karo panes
  index=0
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    index=$((index + 1))
    local pane_index=$((index - 1))
    configure_pane_environment "${pane_index}" "karo-${index}" "${karo_path}" "AGENT_PANE_SHOGUN=0"
  done

  # TASK-032: Launch Copilot CLI in Karo pane
  for ((i = 1; i <= EFFECTIVE_KARO_COUNT; i++)); do
    local pane_index=$((i - 1))
    launch_copilot_cli "${pane_index}" "karo"
  done

  # TASK-033: Validate startup
  # validate_copilot_startup
  sleep 10

  log_info ""
  log_info "Multi-Worktree Agent System deployment complete"
  log_info ""
  log_info "Workspace structure:"
  log_info "  Shogun: ${ABS_SHOGUN_PATH}"
  index=0
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    index=$((index + 1))
    log_info "  Karo-${index}:   ${karo_path}"
  done
  log_info ""
  log_info "Symlinks:"
  for karo_path in "${ACTIVE_KARO_PATHS[@]}"; do
    log_info "  ${karo_path}/.agent/kingdom → ${ABS_SHOGUN_CONTEXT}"
  done
  log_info ""
  log_info "Tmux session:"
  log_info "  Session: ${AGENT_SESSION}"
  log_info "  Window: ${AGENT_WINDOW}"
  log_info "  Panes: ${EFFECTIVE_KARO_COUNT} (karo-1..karo-${EFFECTIVE_KARO_COUNT})"
  log_info ""
  log_info "Connect with: tmux attach-session -t ${AGENT_SESSION}"
  log_info ""
}

# Run main function
main "$@"
