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

require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required but not installed." >&2
    echo "  Install it with: brew install jq" >&2
    exit 1
  fi
}

# ─── Manifest operations ─────────────────────────────────────────────────────
# Manages <claude-dir>/.claude-sync-manifest.json — a JSON object keyed by
# "type:name" (e.g., "agent:code-reviewer") with value objects containing
# hash and installed_at fields.

manifest_path() {
  echo "$CLAUDE_DIR/.claude-sync-manifest.json"
}

manifest_read() {
  local mpath
  mpath="$(manifest_path)"
  if [[ ! -f "$mpath" ]]; then
    echo "{}"
    return
  fi
  cat "$mpath"
}

manifest_write() {
  local mpath tmpfile content="$1"
  mpath="$(manifest_path)"
  tmpfile="$(mktemp "${mpath}.tmp.XXXXXX")"
  if echo "$content" | jq . > "$tmpfile" 2>/dev/null; then
    mv "$tmpfile" "$mpath"
  else
    rm -f "$tmpfile"
    print_error "Failed to write manifest — invalid JSON"
    return 1
  fi
}

manifest_set() {
  local key="$1" hash="$2"
  local current entry
  current="$(manifest_read)"
  entry="$(jq -n --arg h "$hash" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{hash: $h, installed_at: $t}')"
  current="$(echo "$current" | jq --arg k "$key" --argjson v "$entry" '. + {($k): $v}')"
  manifest_write "$current"
}

manifest_remove() {
  local key="$1"
  local current
  current="$(manifest_read)"
  current="$(echo "$current" | jq --arg k "$key" 'del(.[$k])')"
  manifest_write "$current"
}

manifest_cleanup() {
  local current keys key type name target
  current="$(manifest_read)"
  keys="$(echo "$current" | jq -r 'keys[]')"
  [[ -z "$keys" ]] && return
  local dirty=false
  while IFS= read -r key; do
    type="${key%%:*}"
    name="${key#*:}"
    case "$type" in
      claude-md)
        target="$CLAUDE_DIR/claude.md"
        [[ -f "$target" ]] || { current="$(echo "$current" | jq --arg k "$key" 'del(.[$k])')"; dirty=true; }
        ;;
      agent)
        target="$CLAUDE_DIR/agents/${name}.md"
        [[ -f "$target" ]] || { current="$(echo "$current" | jq --arg k "$key" 'del(.[$k])')"; dirty=true; }
        ;;
      command)
        target="$CLAUDE_DIR/commands/${name}.md"
        [[ -f "$target" ]] || { current="$(echo "$current" | jq --arg k "$key" 'del(.[$k])')"; dirty=true; }
        ;;
      skill)
        target="$CLAUDE_DIR/skills/${name}"
        [[ -d "$target" ]] || { current="$(echo "$current" | jq --arg k "$key" 'del(.[$k])')"; dirty=true; }
        ;;
    esac
  done <<< "$keys"
  if [[ "$dirty" == true ]]; then
    manifest_write "$current"
  fi
}

content_hash() {
  local path="$1"
  if [[ -d "$path" ]]; then
    find "$path" -type f | sort | xargs cat | shasum -a 256 | awk '{print $1}'
  else
    shasum -a 256 "$path" | awk '{print $1}'
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
require_jq

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
