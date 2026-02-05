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
  log_info "✓ Multi-Worktree Agent System setup complete!"
  log_info ""
  log_info "Workspace structure:"
  log_info "  Shogun: ${SHOGUN_WORKTREE}"
  log_info "  Karo:   ${KARO_WORKTREE}"
  log_info ""
  log_info "Symlinks:"
  log_info "  ${SHOGUN_QUEUE_SYMLINK} → Karo's shared_context/"
  log_info "  ${SHOGUN_DASHBOARD_SYMLINK} → Karo's dashboard.md"
  log_info ""
  log_info "Next steps:"
  log_info "  1. cd ${SHOGUN_WORKTREE} (Shogun workspace)"
  log_info "  2. cd ${KARO_WORKTREE} (Karo workspace)"
  log_info ""
}

# Run main function
main "$@"
