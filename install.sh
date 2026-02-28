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

# ─── Install helpers ──────────────────────────────────────────────────────────
# Copy a single item from repo to machine, creating parent directories as needed.

apply_install_item() {
  local type="$1" name="$2"
  local src dst
  src="$(repo_source_path "$type" "$name")"
  dst="$(machine_target_path "$type" "$name")"

  mkdir -p "$(dirname "$dst")"
  if [[ "$type" == "skill" ]]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
  else
    cp "$src" "$dst"
  fi

  local hash
  hash="$(content_hash "$src")"
  manifest_set "${type}:${name}" "$hash"
}

apply_remove_item() {
  local type="$1" name="$2"
  local dst
  dst="$(machine_target_path "$type" "$name")"

  if [[ "$type" == "skill" ]]; then
    rm -rf "$dst"
  else
    rm -f "$dst"
  fi

  manifest_remove "${type}:${name}"
}

# Format a diff item for gum choose display. Encodes key in brackets for parsing.
format_choice_label() {
  local key="$1" name="$2" status="$3"
  case "$status" in
    new)       echo "[$key] [new] $name" ;;
    modified)  echo "[$key] [modified] $name" ;;
    unchanged) echo "[$key] [unchanged] $name" ;;
    orphaned)  echo "[$key] [orphaned — will be removed] $name" ;;
  esac
}

# Extract the key from a gum choose output line.
parse_choice_key() {
  local line="$1"
  echo "$line" | sed 's/^\[\([^]]*\)\].*/\1/'
}

# ─── Install flow ─────────────────────────────────────────────────────────────
# 4-stage interactive wizard: CLAUDE.md → Agents → Commands → Skills

install_flow() {
  manifest_cleanup

  local diff_json
  diff_json="$(diff_detect)"

  local total
  total="$(echo "$diff_json" | jq 'length')"
  if [[ "$total" -eq 0 ]]; then
    print_success "Nothing to sync — repo and machine are identical."
    return
  fi

  # Collect planned actions across all stages
  local install_keys="" remove_keys=""
  local count_install=0 count_update=0 count_remove=0

  # ── Stage 1: CLAUDE.md ──────────────────────────────────────────────────

  local claude_item
  claude_item="$(echo "$diff_json" | jq -r '.[] | select(.type == "claude-md")')"

  if [[ -n "$claude_item" ]]; then
    local claude_status claude_diff
    claude_status="$(echo "$claude_item" | jq -r '.status')"

    print_header "Stage 1/4: CLAUDE.md"

    case "$claude_status" in
      new)
        print_status_new "CLAUDE.md — will be installed"
        install_keys+="claude-md:CLAUDE.md"$'\n'
        count_install=$((count_install + 1))
        ;;
      modified)
        print_status_modified "CLAUDE.md — will be updated"
        claude_diff="$(echo "$claude_item" | jq -r '.diff')"
        if [[ -n "$claude_diff" ]]; then
          echo "$claude_diff" | head -30
          local diff_lines
          diff_lines="$(echo "$claude_diff" | wc -l | tr -d ' ')"
          if [[ "$diff_lines" -gt 30 ]]; then
            gum style --foreground 245 "  ... ($((diff_lines - 30)) more lines)"
          fi
        fi
        install_keys+="claude-md:CLAUDE.md"$'\n'
        count_update=$((count_update + 1))
        ;;
      unchanged)
        print_status_unchanged "CLAUDE.md — no changes"
        ;;
    esac
    echo ""
  fi

  # ── Stages 2-4: Agents, Commands, Skills ────────────────────────────────

  local stage_num=2
  local stage_type stage_label
  for stage_type in agent command skill; do
    case "$stage_type" in
      agent)   stage_label="Agents" ;;
      command) stage_label="Commands" ;;
      skill)   stage_label="Skills" ;;
    esac

    local stage_items
    stage_items="$(echo "$diff_json" | jq -c "[.[] | select(.type == \"$stage_type\")]")"
    local stage_count
    stage_count="$(echo "$stage_items" | jq 'length')"

    print_header "Stage $stage_num/4: $stage_label"

    if [[ "$stage_count" -eq 0 ]]; then
      gum style --foreground 245 "  No ${stage_label,,} found in repo."
      echo ""
      stage_num=$((stage_num + 1))
      continue
    fi

    # Build gum choose arguments
    local choices="" preselected=""
    local i=0
    while [[ "$i" -lt "$stage_count" ]]; do
      local item key name status label
      item="$(echo "$stage_items" | jq -c ".[$i]")"
      key="$(echo "$item" | jq -r '.key')"
      name="$(echo "$item" | jq -r '.name')"
      status="$(echo "$item" | jq -r '.status')"
      label="$(format_choice_label "$key" "$name" "$status")"

      choices+="$label"$'\n'
      if [[ "$status" == "new" || "$status" == "modified" || "$status" == "orphaned" ]]; then
        preselected+="$label"$'\n'
      fi
      i=$((i + 1))
    done

    # Remove trailing newlines
    choices="${choices%$'\n'}"
    preselected="${preselected%$'\n'}"

    if [[ -z "$choices" ]]; then
      echo ""
      stage_num=$((stage_num + 1))
      continue
    fi

    # Run gum choose with pre-selected items
    local selected=""
    if [[ -n "$preselected" ]]; then
      local gum_args=("--no-limit")
      while IFS= read -r line; do
        [[ -n "$line" ]] && gum_args+=("--selected" "$line")
      done <<< "$preselected"

      selected="$(echo "$choices" | gum choose "${gum_args[@]}")" || true
    else
      selected="$(echo "$choices" | gum choose --no-limit)" || true
    fi

    # Parse selected items
    if [[ -n "$selected" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local sel_key
        sel_key="$(parse_choice_key "$line")"
        local sel_status
        sel_status="$(echo "$stage_items" | jq -r --arg k "$sel_key" '.[] | select(.key == $k) | .status')"

        if [[ "$sel_status" == "orphaned" ]]; then
          remove_keys+="$sel_key"$'\n'
          count_remove=$((count_remove + 1))
        else
          install_keys+="$sel_key"$'\n'
          if [[ "$sel_status" == "new" ]]; then
            count_install=$((count_install + 1))
          else
            count_update=$((count_update + 1))
          fi
        fi
      done <<< "$selected"
    fi

    echo ""
    stage_num=$((stage_num + 1))
  done

  # ── Summary + Confirmation ──────────────────────────────────────────────

  # Remove trailing newlines
  install_keys="${install_keys%$'\n'}"
  remove_keys="${remove_keys%$'\n'}"

  if [[ -z "$install_keys" && -z "$remove_keys" ]]; then
    print_success "No items selected — nothing to do."
    return
  fi

  print_header "Summary"

  if [[ -n "$install_keys" ]]; then
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      local stype sname
      stype="${key%%:*}"
      sname="${key#*:}"
      local sstatus
      sstatus="$(echo "$diff_json" | jq -r --arg k "$key" '.[] | select(.key == $k) | .status')"
      case "$sstatus" in
        new)      print_status_new "$sname" ;;
        modified) print_status_modified "$sname" ;;
        *)        gum style --foreground 245 "  [install] $sname" ;;
      esac
    done <<< "$install_keys"
  fi

  if [[ -n "$remove_keys" ]]; then
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      local rname
      rname="${key#*:}"
      print_status_orphaned "$rname — remove"
    done <<< "$remove_keys"
  fi

  echo ""
  if ! gum confirm "Apply these changes?"; then
    gum style --foreground 245 "Cancelled — no changes made."
    return
  fi

  # ── Apply changes ───────────────────────────────────────────────────────

  if [[ -n "$install_keys" ]]; then
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      local atype aname
      atype="${key%%:*}"
      aname="${key#*:}"
      apply_install_item "$atype" "$aname"
    done <<< "$install_keys"
  fi

  if [[ -n "$remove_keys" ]]; then
    while IFS= read -r key; do
      [[ -z "$key" ]] && continue
      local rtype rname
      rtype="${key%%:*}"
      rname="${key#*:}"
      apply_remove_item "$rtype" "$rname"
    done <<< "$remove_keys"
  fi

  # ── Completion ──────────────────────────────────────────────────────────

  echo ""
  local parts=""
  [[ "$count_install" -gt 0 ]] && parts+="${count_install} installed"
  [[ "$count_update" -gt 0 ]] && { [[ -n "$parts" ]] && parts+=", "; parts+="${count_update} updated"; }
  [[ "$count_remove" -gt 0 ]] && { [[ -n "$parts" ]] && parts+=", "; parts+="${count_remove} removed"; }
  print_success "Done — $parts."
}

# ─── Defaults ───────────────────────────────────────────────────────────────
# Set here so they're available when sourced for testing.

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"

# ─── Main entrypoint ────────────────────────────────────────────────────────
# Guarded so sourcing the script only loads functions without executing.

main() {
  local subcommand="install"

  if [[ $# -ge 1 && "$1" == "uninstall" ]]; then
    subcommand="uninstall"
    shift
  fi

  if [[ $# -ge 1 ]]; then
    CLAUDE_DIR="$1"
  fi

  require_gum
  require_jq

  if [[ ! -d "$CLAUDE_DIR" ]]; then
    print_error "Directory not found: $CLAUDE_DIR"
    exit 1
  fi

  print_header "Claude Config Sync"
  echo "  Target: $CLAUDE_DIR"
  echo ""

  case "$subcommand" in
    install)
      install_flow
      ;;
    uninstall)
      # Will be implemented in "Build uninstall flow" task
      echo "Uninstall flow not yet implemented."
      ;;
  esac
}

# Run main only when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
