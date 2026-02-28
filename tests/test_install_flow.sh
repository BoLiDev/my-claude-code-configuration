#!/usr/bin/env bash
# E2E tests for interactive install flow
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
  TEST_REPO="$TEST_DIR/repo"
  mkdir -p "$MOCK_BIN" "$CLAUDE_DIR" "$TEST_REPO"
}

teardown_temp() {
  rm -rf "$TEST_DIR"
}

# Mock gum that handles style, choose, and confirm subcommands.
# - style: prints the last argument (text content)
# - choose --no-limit: returns all --selected items (simulates user accepting defaults)
# - confirm: always accepts (exit 0)
create_mock_gum() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
elif [[ "${1:-}" == "choose" ]]; then
  # Collect all --selected values and output them
  shift  # skip "choose"
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

# Mock gum that rejects confirmation (simulates user cancelling).
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

# Mock gum that selects nothing from choose (simulates user deselecting all).
create_mock_gum_select_none() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
elif [[ "${1:-}" == "choose" ]]; then
  # Output nothing — user deselected all
  exit 0
elif [[ "${1:-}" == "confirm" ]]; then
  exit 0
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
}

setup_test_repo() {
  # CLAUDE.md
  echo "# Project Config" > "$TEST_REPO/CLAUDE.md"

  # Agents
  mkdir -p "$TEST_REPO/agents"
  echo "agent-one content" > "$TEST_REPO/agents/agent-one.md"
  echo "agent-two content" > "$TEST_REPO/agents/agent-two.md"

  # Commands
  mkdir -p "$TEST_REPO/commands"
  echo "command-one content" > "$TEST_REPO/commands/command-one.md"

  # Skills
  mkdir -p "$TEST_REPO/skills/my-skill"
  echo "skill content" > "$TEST_REPO/skills/my-skill/SKILL.md"
}

run_install_flow() {
  local commands="$1"
  PATH="$MOCK_BIN:$PATH" bash -c '
    source "'"$INSTALL_SH"'"
    CLAUDE_DIR="'"$CLAUDE_DIR"'"
    REPO_DIR="'"$TEST_REPO"'"
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

test_fresh_install_copies_all_items() {
  echo "TEST: fresh install with no existing items copies everything"
  setup_temp
  create_mock_gum
  setup_test_repo

  local output
  output="$(run_install_flow 'install_flow')"

  # Verify files were copied
  assert_file_exists "claude.md installed" "$CLAUDE_DIR/claude.md"
  assert_file_exists "agent-one installed" "$CLAUDE_DIR/agents/agent-one.md"
  assert_file_exists "agent-two installed" "$CLAUDE_DIR/agents/agent-two.md"
  assert_file_exists "command-one installed" "$CLAUDE_DIR/commands/command-one.md"
  assert_file_exists "skill directory installed" "$CLAUDE_DIR/skills/my-skill/SKILL.md"

  # Verify file contents match repo
  assert_eq "claude.md content" "# Project Config" "$(cat "$CLAUDE_DIR/claude.md")"
  assert_eq "agent-one content" "agent-one content" "$(cat "$CLAUDE_DIR/agents/agent-one.md")"

  # Verify completion message
  assert_contains "shows installed count" "installed" "$output"

  teardown_temp
}

test_manifest_updated_after_install() {
  echo "TEST: manifest is updated with entries for all installed items"
  setup_temp
  create_mock_gum
  setup_test_repo

  run_install_flow 'install_flow' > /dev/null

  local manifest
  manifest="$(cat "$CLAUDE_DIR/.claude-sync-manifest.json")"

  local key_count
  key_count="$(echo "$manifest" | jq 'keys | length')"
  assert_eq "manifest has 5 entries" "5" "$key_count"

  # Check specific keys exist
  local has_claude has_agent has_command has_skill
  has_claude="$(echo "$manifest" | jq 'has("claude-md:CLAUDE.md")')"
  has_agent="$(echo "$manifest" | jq 'has("agent:agent-one")')"
  has_command="$(echo "$manifest" | jq 'has("command:command-one")')"
  has_skill="$(echo "$manifest" | jq 'has("skill:my-skill")')"
  assert_eq "manifest has claude-md entry" "true" "$has_claude"
  assert_eq "manifest has agent entry" "true" "$has_agent"
  assert_eq "manifest has command entry" "true" "$has_command"
  assert_eq "manifest has skill entry" "true" "$has_skill"

  # Each entry has hash and installed_at
  local hash_present ts_present
  hash_present="$(echo "$manifest" | jq '."claude-md:CLAUDE.md" | has("hash")')"
  ts_present="$(echo "$manifest" | jq '."claude-md:CLAUDE.md" | has("installed_at")')"
  assert_eq "entry has hash" "true" "$hash_present"
  assert_eq "entry has installed_at" "true" "$ts_present"

  teardown_temp
}

test_unchanged_items_not_preselected() {
  echo "TEST: unchanged items are not preselected (user deselects all → nothing happens)"
  setup_temp
  create_mock_gum_select_none
  setup_test_repo

  # Pre-install all items so they're unchanged
  mkdir -p "$CLAUDE_DIR/agents" "$CLAUDE_DIR/commands" "$CLAUDE_DIR/skills/my-skill"
  cp "$TEST_REPO/CLAUDE.md" "$CLAUDE_DIR/claude.md"
  cp "$TEST_REPO/agents/agent-one.md" "$CLAUDE_DIR/agents/agent-one.md"
  cp "$TEST_REPO/agents/agent-two.md" "$CLAUDE_DIR/agents/agent-two.md"
  cp "$TEST_REPO/commands/command-one.md" "$CLAUDE_DIR/commands/command-one.md"
  cp -r "$TEST_REPO/skills/my-skill" "$CLAUDE_DIR/skills/my-skill"

  # Create manifest entries for all items
  run_install_flow '
    manifest_set "claude-md:CLAUDE.md" "$(content_hash "'"$TEST_REPO"'/CLAUDE.md")"
    manifest_set "agent:agent-one" "$(content_hash "'"$TEST_REPO"'/agents/agent-one.md")"
    manifest_set "agent:agent-two" "$(content_hash "'"$TEST_REPO"'/agents/agent-two.md")"
    manifest_set "command:command-one" "$(content_hash "'"$TEST_REPO"'/commands/command-one.md")"
    manifest_set "skill:my-skill" "$(content_hash "'"$TEST_REPO"'/skills/my-skill")"
  ' > /dev/null

  local output
  output="$(run_install_flow 'install_flow')"

  # Should say nothing to do since everything is unchanged and user selected nothing
  assert_contains "no items selected message" "No items selected" "$output"

  teardown_temp
}

test_modified_items_detected_and_updated() {
  echo "TEST: modified items are detected and updated when selected"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Pre-install agent-one with different content
  mkdir -p "$CLAUDE_DIR/agents"
  echo "old agent-one content" > "$CLAUDE_DIR/agents/agent-one.md"
  run_install_flow '
    manifest_set "agent:agent-one" "$(content_hash "'"$CLAUDE_DIR"'/agents/agent-one.md")"
  ' > /dev/null

  local output
  output="$(run_install_flow 'install_flow')"

  # agent-one should be updated to new content
  assert_eq "agent-one updated" "agent-one content" "$(cat "$CLAUDE_DIR/agents/agent-one.md")"

  teardown_temp
}

test_orphaned_items_removed() {
  echo "TEST: orphaned items are removed when selected"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Install an extra agent that is NOT in the repo (orphaned)
  mkdir -p "$CLAUDE_DIR/agents"
  echo "orphan content" > "$CLAUDE_DIR/agents/old-agent.md"
  run_install_flow '
    manifest_set "agent:old-agent" "somehash123"
  ' > /dev/null

  local output
  output="$(run_install_flow 'install_flow')"

  # The orphaned agent should be removed
  assert_file_not_exists "orphaned agent removed" "$CLAUDE_DIR/agents/old-agent.md"

  # Verify manifest no longer has the orphan
  local manifest has_orphan
  manifest="$(cat "$CLAUDE_DIR/.claude-sync-manifest.json")"
  has_orphan="$(echo "$manifest" | jq 'has("agent:old-agent")')"
  assert_eq "orphan removed from manifest" "false" "$has_orphan"

  # Verify completion mentions removal
  assert_contains "shows removed count" "removed" "$output"

  teardown_temp
}

test_confirmation_rejection_makes_no_changes() {
  echo "TEST: rejecting confirmation makes no file changes"
  setup_temp
  create_mock_gum_reject
  setup_test_repo

  local output
  output="$(run_install_flow 'install_flow')"

  # No files should have been copied
  assert_file_not_exists "claude.md not installed" "$CLAUDE_DIR/claude.md"
  assert_file_not_exists "agents dir not created" "$CLAUDE_DIR/agents/agent-one.md"

  # Should show cancelled message
  assert_contains "cancelled message" "Cancelled" "$output"

  teardown_temp
}

test_four_stages_displayed() {
  echo "TEST: all four stages are displayed in order"
  setup_temp
  create_mock_gum
  setup_test_repo

  local output
  output="$(run_install_flow 'install_flow')"

  assert_contains "stage 1 shown" "Stage 1/4: CLAUDE.md" "$output"
  assert_contains "stage 2 shown" "Stage 2/4: Agents" "$output"
  assert_contains "stage 3 shown" "Stage 3/4: Commands" "$output"
  assert_contains "stage 4 shown" "Stage 4/4: Skills" "$output"

  teardown_temp
}

test_empty_repo_nothing_to_sync() {
  echo "TEST: empty repo shows nothing to sync"
  setup_temp
  create_mock_gum

  # TEST_REPO exists but has no items
  local output
  output="$(run_install_flow 'install_flow')"

  assert_contains "nothing to sync" "Nothing to sync" "$output"

  teardown_temp
}

test_skill_directory_copied_correctly() {
  echo "TEST: skill directory is copied as a directory, not a file"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Add a second file to the skill directory
  echo "extra content" > "$TEST_REPO/skills/my-skill/README.md"

  run_install_flow 'install_flow' > /dev/null

  assert_file_exists "skill SKILL.md copied" "$CLAUDE_DIR/skills/my-skill/SKILL.md"
  assert_file_exists "skill README.md copied" "$CLAUDE_DIR/skills/my-skill/README.md"
  assert_eq "skill SKILL.md content" "skill content" "$(cat "$CLAUDE_DIR/skills/my-skill/SKILL.md")"
  assert_eq "skill README.md content" "extra content" "$(cat "$CLAUDE_DIR/skills/my-skill/README.md")"

  teardown_temp
}

test_idempotent_reinstall() {
  echo "TEST: running install twice with no changes is idempotent"
  setup_temp
  create_mock_gum
  setup_test_repo

  # First install
  run_install_flow 'install_flow' > /dev/null

  # Second install — everything should be unchanged
  # Use select-none mock since unchanged items aren't preselected
  create_mock_gum_select_none
  local output
  output="$(run_install_flow 'install_flow')"

  assert_contains "nothing selected on second run" "No items selected" "$output"

  # Files should still exist from first install
  assert_file_exists "claude.md still exists" "$CLAUDE_DIR/claude.md"
  assert_file_exists "agent still exists" "$CLAUDE_DIR/agents/agent-one.md"

  teardown_temp
}

# ─── Run all tests ──────────────────────────────────────────────────────────

echo "=== Install Flow Tests ==="
echo ""

test_fresh_install_copies_all_items
echo ""
test_manifest_updated_after_install
echo ""
test_unchanged_items_not_preselected
echo ""
test_modified_items_detected_and_updated
echo ""
test_orphaned_items_removed
echo ""
test_confirmation_rejection_makes_no_changes
echo ""
test_four_stages_displayed
echo ""
test_empty_repo_nothing_to_sync
echo ""
test_skill_directory_copied_correctly
echo ""
test_idempotent_reinstall
echo ""

echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
