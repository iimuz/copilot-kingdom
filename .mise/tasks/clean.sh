#!/usr/bin/env bash
#MISE description="Clean."

set -Eeuo pipefail

SCRIPT_NAME=$(basename "${0}")
readonly SCRIPT_NAME

function log_info() {
  local _message="$1"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $_message" >&2
}

function log_error() {
  local _message="$1"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $_message" >&2
}

function err() {
  log_error "Line $1: $2" >&2
  exit 1
}

function cleanup() {
  log_info "$SCRIPT_NAME completed"
}

trap 'err ${LINENO} "$BASH_COMMAND"' ERR
trap cleanup EXIT

function usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} [OPTIONS]

Clean up build artifacts and dependencies.

OPTIONS:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose output

EXAMPLE:
  # Clean up build artifacts and dependencies
  $ mise run clean
EOF
}

function main() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -v | --verbose)
      set -x
      shift
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
    esac
  done

  rm -fr ./node_modules
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
