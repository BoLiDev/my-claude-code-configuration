#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Dependency check ────────────────────────────────────────────────────────

require_gum() {
  if ! command -v gum &>/dev/null; then
    echo "Error: gum is required but not installed." >&2
    echo "  Install it with: brew install gum" >&2
    exit 1
  fi
}

# ─── Styled output helpers ───────────────────────────────────────────────────

print_header() {
  gum style --bold --foreground 212 "─── $1 ───"
}

print_status_new() {
  gum style --foreground 46 "  [new] $1"
}

print_status_modified() {
  gum style --foreground 214 "  [modified] $1"
}

print_status_unchanged() {
  gum style --foreground 245 "  [unchanged] $1"
}

print_status_orphaned() {
  gum style --foreground 196 "  [orphaned] $1"
}

print_success() {
  gum style --bold --foreground 46 "✓ $1"
}

print_error() {
  echo "✗ $1" >&2
}

# ─── Cleanup trap ────────────────────────────────────────────────────────────
# Later tasks (install flow, uninstall flow) will expand this to undo partial
# file operations. The foundation ensures Ctrl+C always triggers cleanup.

cleanup() {
  exit 130
}
trap cleanup INT TERM

# ─── Argument parsing ────────────────────────────────────────────────────────
# Usage: ./install.sh [subcommand] [target-path]
#   subcommand: "uninstall" or omitted (defaults to install)
#   target-path: defaults to ~/.claude

SUBCOMMAND="install"
CLAUDE_DIR="$HOME/.claude"

if [[ $# -ge 1 ]]; then
  if [[ "$1" == "uninstall" ]]; then
    SUBCOMMAND="uninstall"
    shift
  fi
fi

if [[ $# -ge 1 ]]; then
  CLAUDE_DIR="$1"
fi

# ─── Startup checks ─────────────────────────────────────────────────────────

require_gum

if [[ ! -d "$CLAUDE_DIR" ]]; then
  print_error "Directory not found: $CLAUDE_DIR"
  exit 1
fi

# ─── Display target ─────────────────────────────────────────────────────────

print_header "Claude Config Sync"
echo "  Target: $CLAUDE_DIR"
echo ""

# ─── Route to flow ───────────────────────────────────────────────────────────

case "$SUBCOMMAND" in
  install)
    # Will be implemented in "Build interactive install flow" task
    echo "Install flow not yet implemented."
    ;;
  uninstall)
    # Will be implemented in "Build uninstall flow" task
    echo "Uninstall flow not yet implemented."
    ;;
esac
