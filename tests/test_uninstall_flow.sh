#!/usr/bin/env bash
# E2E tests for uninstall flow
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_DIR/install.sh"

PASS=0
FAIL=0

# ─── Test fixtures ──────────────────────────────────────────────────────────

setup_temp() {
  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/mock_bin"
  CLAUDE_DIR="$TEST_DIR/claude_home"
  mkdir -p "$MOCK_BIN" "$CLAUDE_DIR"
}

teardown_temp() {
  rm -rf "$TEST_DIR"
}

# Mock gum that accepts all pre-selected items and confirms.
create_mock_gum() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
elif [[ "${1:-}" == "choose" ]]; then
  shift
  selected=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-limit) shift ;;
      --selected)
        shift
        selected+=("$1")
        shift
        ;;
      *) shift ;;
    esac
  done
  for item in "${selected[@]}"; do
    echo "$item"
  done
elif [[ "${1:-}" == "confirm" ]]; then
  exit 0
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
}

# Mock gum that rejects confirmation.
create_mock_gum_reject() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
elif [[ "${1:-}" == "choose" ]]; then
  shift
  selected=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-limit) shift ;;
      --selected)
        shift
        selected+=("$1")
        shift
        ;;
      *) shift ;;
    esac
  done
  for item in "${selected[@]}"; do
    echo "$item"
  done
elif [[ "${1:-}" == "confirm" ]]; then
  exit 1
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
}

# Mock gum that selects nothing from choose.
create_mock_gum_select_none() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
elif [[ "${1:-}" == "choose" ]]; then
  exit 0
elif [[ "${1:-}" == "confirm" ]]; then
  exit 0
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
}

# Populate CLAUDE_DIR with installed items and a manifest tracking them.
setup_installed_state() {
  # CLAUDE.md
  echo "# Project Config" > "$CLAUDE_DIR/claude.md"

  # Agents
  mkdir -p "$CLAUDE_DIR/agents"
  echo "agent-one content" > "$CLAUDE_DIR/agents/agent-one.md"
  echo "agent-two content" > "$CLAUDE_DIR/agents/agent-two.md"

  # Commands
  mkdir -p "$CLAUDE_DIR/commands"
  echo "command-one content" > "$CLAUDE_DIR/commands/command-one.md"

  # Skills
  mkdir -p "$CLAUDE_DIR/skills/my-skill"
  echo "skill content" > "$CLAUDE_DIR/skills/my-skill/SKILL.md"

  # Create manifest entries for all items
  run_uninstall '
    manifest_set "claude-md:CLAUDE.md" "hash-claude"
    manifest_set "agent:agent-one" "hash-a1"
    manifest_set "agent:agent-two" "hash-a2"
    manifest_set "command:command-one" "hash-c1"
    manifest_set "skill:my-skill" "hash-s1"
  ' > /dev/null
}

run_uninstall() {
  local commands="$1"
  PATH="$MOCK_BIN:$PATH" bash -c '
    source "'"$INSTALL_SH"'"
    CLAUDE_DIR="'"$CLAUDE_DIR"'"
    '"$commands"'
  ' 2>&1
}

# ─── Assertions ─────────────────────────────────────────────────────────────

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    echo "    actual output:       $haystack"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [[ -e "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (file not found: $path)"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_not_exists() {
  local label="$1" path="$2"
  if [[ ! -e "$path" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label (file should not exist: $path)"
    FAIL=$((FAIL + 1))
  fi
}

# ─── Tests ──────────────────────────────────────────────────────────────────

test_empty_manifest_exits_gracefully() {
  echo "TEST: empty manifest prints nothing-managed message"
  setup_temp
  create_mock_gum

  local output
  output="$(run_uninstall 'uninstall_flow')"

  assert_contains "nothing managed message" "Nothing is managed" "$output"

  teardown_temp
}

test_missing_manifest_exits_gracefully() {
  echo "TEST: missing manifest file prints nothing-managed message"
  setup_temp
  create_mock_gum

  # No manifest file at all — manifest_read returns {}
  local output
  output="$(run_uninstall 'uninstall_flow')"

  assert_contains "nothing managed message" "Nothing is managed" "$output"

  teardown_temp
}

test_claude_md_excluded_from_uninstall() {
  echo "TEST: CLAUDE.md is not shown in uninstall stages"
  setup_temp
  create_mock_gum

  # Only install CLAUDE.md
  echo "# Config" > "$CLAUDE_DIR/claude.md"
  run_uninstall 'manifest_set "claude-md:CLAUDE.md" "hash-claude"' > /dev/null

  local output
  output="$(run_uninstall 'uninstall_flow')"

  # Only claude-md in manifest → nothing to uninstall
  assert_contains "nothing managed message" "Nothing is managed" "$output"

  # CLAUDE.md should still exist
  assert_file_exists "claude.md preserved" "$CLAUDE_DIR/claude.md"

  teardown_temp
}

test_uninstall_removes_selected_items() {
  echo "TEST: uninstall removes all selected items"
  setup_temp
  create_mock_gum
  setup_installed_state

  local output
  output="$(run_uninstall 'uninstall_flow')"

  # Agents, commands, skills should be removed
  assert_file_not_exists "agent-one removed" "$CLAUDE_DIR/agents/agent-one.md"
  assert_file_not_exists "agent-two removed" "$CLAUDE_DIR/agents/agent-two.md"
  assert_file_not_exists "command-one removed" "$CLAUDE_DIR/commands/command-one.md"
  assert_file_not_exists "skill directory removed" "$CLAUDE_DIR/skills/my-skill"

  # CLAUDE.md should still exist (excluded from uninstall)
  assert_file_exists "claude.md preserved" "$CLAUDE_DIR/claude.md"

  # Completion message shows count
  assert_contains "shows removed count" "removed" "$output"

  teardown_temp
}

test_manifest_updated_after_uninstall() {
  echo "TEST: manifest entries removed after uninstall"
  setup_temp
  create_mock_gum
  setup_installed_state

  run_uninstall 'uninstall_flow' > /dev/null

  local manifest
  manifest="$(cat "$CLAUDE_DIR/.claude-sync-manifest.json")"

  # Only claude-md should remain
  local key_count
  key_count="$(echo "$manifest" | jq 'keys | length')"
  assert_eq "manifest has 1 entry (claude-md only)" "1" "$key_count"

  local has_claude
  has_claude="$(echo "$manifest" | jq 'has("claude-md:CLAUDE.md")')"
  assert_eq "claude-md still in manifest" "true" "$has_claude"

  local has_agent
  has_agent="$(echo "$manifest" | jq 'has("agent:agent-one")')"
  assert_eq "agent removed from manifest" "false" "$has_agent"

  teardown_temp
}

test_confirmation_rejection_makes_no_changes() {
  echo "TEST: rejecting confirmation makes no changes"
  setup_temp
  create_mock_gum_reject
  setup_installed_state

  local output
  output="$(run_uninstall 'uninstall_flow')"

  # All files should still exist
  assert_file_exists "agent-one preserved" "$CLAUDE_DIR/agents/agent-one.md"
  assert_file_exists "command-one preserved" "$CLAUDE_DIR/commands/command-one.md"
  assert_file_exists "skill preserved" "$CLAUDE_DIR/skills/my-skill/SKILL.md"

  assert_contains "cancelled message" "Cancelled" "$output"

  # Manifest should be unchanged
  local key_count
  key_count="$(run_uninstall 'manifest_read | jq "keys | length"')"
  assert_eq "manifest unchanged" "5" "$key_count"

  teardown_temp
}

test_skill_directory_fully_removed() {
  echo "TEST: skill uninstall removes entire directory, not just SKILL.md"
  setup_temp
  create_mock_gum

  # Install a skill with multiple files
  mkdir -p "$CLAUDE_DIR/skills/my-skill"
  echo "skill content" > "$CLAUDE_DIR/skills/my-skill/SKILL.md"
  echo "extra content" > "$CLAUDE_DIR/skills/my-skill/README.md"
  run_uninstall 'manifest_set "skill:my-skill" "hash-s1"' > /dev/null

  run_uninstall 'uninstall_flow' > /dev/null

  # Entire skill directory should be gone
  assert_file_not_exists "skill dir removed" "$CLAUDE_DIR/skills/my-skill"
  assert_file_not_exists "SKILL.md removed" "$CLAUDE_DIR/skills/my-skill/SKILL.md"
  assert_file_not_exists "README.md removed" "$CLAUDE_DIR/skills/my-skill/README.md"

  teardown_temp
}

test_three_stages_displayed() {
  echo "TEST: three stages are displayed (Agents, Commands, Skills)"
  setup_temp
  create_mock_gum
  setup_installed_state

  local output
  output="$(run_uninstall 'uninstall_flow')"

  assert_contains "stage 1 shown" "Stage 1/3: Agents" "$output"
  assert_contains "stage 2 shown" "Stage 2/3: Commands" "$output"
  assert_contains "stage 3 shown" "Stage 3/3: Skills" "$output"

  teardown_temp
}

test_deselect_all_does_nothing() {
  echo "TEST: deselecting all items does nothing"
  setup_temp
  create_mock_gum_select_none
  setup_installed_state

  local output
  output="$(run_uninstall 'uninstall_flow')"

  assert_contains "no items selected" "No items selected" "$output"

  # All files should still exist
  assert_file_exists "agent-one preserved" "$CLAUDE_DIR/agents/agent-one.md"
  assert_file_exists "command-one preserved" "$CLAUDE_DIR/commands/command-one.md"

  teardown_temp
}

test_locally_created_items_not_shown() {
  echo "TEST: locally-created items (not in manifest) are not affected"
  setup_temp
  create_mock_gum

  # Install one agent via manifest
  mkdir -p "$CLAUDE_DIR/agents"
  echo "managed agent" > "$CLAUDE_DIR/agents/managed.md"
  run_uninstall 'manifest_set "agent:managed" "hash-m"' > /dev/null

  # Create a local agent NOT in manifest
  echo "local agent" > "$CLAUDE_DIR/agents/local-only.md"

  run_uninstall 'uninstall_flow' > /dev/null

  # Managed agent should be removed
  assert_file_not_exists "managed agent removed" "$CLAUDE_DIR/agents/managed.md"

  # Local agent should still exist
  assert_file_exists "local agent preserved" "$CLAUDE_DIR/agents/local-only.md"

  teardown_temp
}

# ─── Run all tests ──────────────────────────────────────────────────────────

echo "=== Uninstall Flow Tests ==="
echo ""

test_empty_manifest_exits_gracefully
echo ""
test_missing_manifest_exits_gracefully
echo ""
test_claude_md_excluded_from_uninstall
echo ""
test_uninstall_removes_selected_items
echo ""
test_manifest_updated_after_uninstall
echo ""
test_confirmation_rejection_makes_no_changes
echo ""
test_skill_directory_fully_removed
echo ""
test_three_stages_displayed
echo ""
test_deselect_all_does_nothing
echo ""
test_locally_created_items_not_shown
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
