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

# ─── Path resolution ────────────────────────────────────────────────────────
# Maps asset type + name to filesystem paths in repo and on machine.

repo_source_path() {
  local type="$1" name="$2"
  case "$type" in
    claude-md) echo "$REPO_DIR/CLAUDE.md" ;;
    agent)     echo "$REPO_DIR/agents/${name}.md" ;;
    command)   echo "$REPO_DIR/commands/${name}.md" ;;
    skill)     echo "$REPO_DIR/skills/${name}" ;;
  esac
}

machine_target_path() {
  local type="$1" name="$2"
  case "$type" in
    claude-md) echo "$CLAUDE_DIR/claude.md" ;;
    agent)     echo "$CLAUDE_DIR/agents/${name}.md" ;;
    command)   echo "$CLAUDE_DIR/commands/${name}.md" ;;
    skill)     echo "$CLAUDE_DIR/skills/${name}" ;;
  esac
}

# ─── Diff detection ─────────────────────────────────────────────────────────
# Compares repo items against machine state to classify each as:
#   new | modified | unchanged | orphaned
# Returns a JSON array of {key, type, name, status, diff} objects.

diff_item_exists() {
  local type="$1" path="$2"
  if [[ "$type" == "skill" ]]; then
    [[ -d "$path" ]]
  else
    [[ -f "$path" ]]
  fi
}

diff_classify() {
  local type="$1" name="$2"
  local machine_path repo_path
  machine_path="$(machine_target_path "$type" "$name")"
  repo_path="$(repo_source_path "$type" "$name")"

  if ! diff_item_exists "$type" "$machine_path"; then
    echo "new"
    return
  fi

  local repo_hash machine_hash
  repo_hash="$(content_hash "$repo_path")"
  machine_hash="$(content_hash "$machine_path")"

  if [[ "$repo_hash" == "$machine_hash" ]]; then
    echo "unchanged"
  else
    echo "modified"
  fi
}

diff_unified() {
  local type="$1" name="$2"
  local repo_path machine_path
  repo_path="$(repo_source_path "$type" "$name")"
  machine_path="$(machine_target_path "$type" "$name")"

  if [[ "$type" == "skill" ]]; then
    diff -ru "$machine_path" "$repo_path" 2>/dev/null || true
  else
    diff -u "$machine_path" "$repo_path" 2>/dev/null || true
  fi
}

diff_item_to_json() {
  local key="$1" type="$2" name="$3"
  local status diff_text=""
  status="$(diff_classify "$type" "$name")"
  [[ "$status" == "modified" ]] && diff_text="$(diff_unified "$type" "$name")"
  jq -n --arg k "$key" --arg t "$type" --arg n "$name" \
    --arg s "$status" --arg d "$diff_text" \
    '{key: $k, type: $t, name: $n, status: $s, diff: $d}'
}

diff_detect() {
  local manifest items=""
  manifest="$(manifest_read)"

  # Classify items from repo
  [[ -f "$REPO_DIR/CLAUDE.md" ]] && \
    items+="$(diff_item_to_json "claude-md:CLAUDE.md" "claude-md" "CLAUDE.md")"$'\n'

  local f name
  for f in "$REPO_DIR"/agents/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .md)"
    items+="$(diff_item_to_json "agent:$name" "agent" "$name")"$'\n'
  done

  for f in "$REPO_DIR"/commands/*.md; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .md)"
    items+="$(diff_item_to_json "command:$name" "command" "$name")"$'\n'
  done

  local d
  for d in "$REPO_DIR"/skills/*/; do
    [[ -d "$d" ]] || continue
    name="$(basename "$d")"
    items+="$(diff_item_to_json "skill:$name" "skill" "$name")"$'\n'
  done

  # Orphaned items: in manifest but no longer in repo
  local keys key type oname
  keys="$(echo "$manifest" | jq -r 'keys[]' 2>/dev/null)" || keys=""
  if [[ -n "$keys" ]]; then
    while IFS= read -r key; do
      type="${key%%:*}"
      oname="${key#*:}"
      local repo_path
      repo_path="$(repo_source_path "$type" "$oname")"
      if ! diff_item_exists "$type" "$repo_path"; then
        items+="$(jq -n --arg k "$key" --arg t "$type" --arg n "$oname" \
          '{key: $k, type: $t, name: $n, status: "orphaned", diff: ""}')"$'\n'
      fi
    done <<< "$keys"
  fi

  if [[ -n "$items" ]]; then
    echo "$items" | jq -s '.'
  else
    echo "[]"
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
