#!/usr/bin/env bash
# E2E tests for diff detection engine
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SH="$REPO_DIR/install.sh"

PASS=0
FAIL=0

# ─── Helpers ─────────────────────────────────────────────────────────────────

setup_temp() {
  TEST_DIR="$(mktemp -d)"
  MOCK_BIN="$TEST_DIR/mock_bin"
  CLAUDE_DIR="$TEST_DIR/claude_home"
  TEST_REPO="$TEST_DIR/repo"
  mkdir -p "$MOCK_BIN" "$CLAUDE_DIR"
}

teardown_temp() {
  rm -rf "$TEST_DIR"
}

create_mock_gum() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
}

setup_test_repo() {
  mkdir -p "$TEST_REPO/agents" "$TEST_REPO/commands" "$TEST_REPO/skills/test-skill"
  echo "# CLAUDE config" > "$TEST_REPO/CLAUDE.md"
  echo "# Agent Alpha" > "$TEST_REPO/agents/alpha.md"
  echo "# Command Beta" > "$TEST_REPO/commands/beta.md"
  echo "# Test Skill" > "$TEST_REPO/skills/test-skill/SKILL.md"
}

# Source install.sh with overridden REPO_DIR for controlled testing.
run_with_diff() {
  local commands="$1"
  PATH="$MOCK_BIN:$PATH" bash -c '
    source "'"$INSTALL_SH"'"
    CLAUDE_DIR="'"$CLAUDE_DIR"'"
    REPO_DIR="'"$TEST_REPO"'"
    '"$commands"'
  ' 2>&1
}

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

# ─── Tests ───────────────────────────────────────────────────────────────────

test_new_items_detected() {
  echo "TEST: items in repo but not on machine are classified as 'new'"
  setup_temp
  create_mock_gum
  setup_test_repo

  local result
  result="$(run_with_diff 'diff_detect')"

  local count
  count="$(echo "$result" | jq '[.[] | select(.status == "new")] | length')"
  assert_eq "all 4 items are new" "4" "$count"

  local claude_status
  claude_status="$(echo "$result" | jq -r '.[] | select(.type == "claude-md") | .status')"
  assert_eq "CLAUDE.md is new" "new" "$claude_status"

  local agent_status
  agent_status="$(echo "$result" | jq -r '.[] | select(.type == "agent") | .status')"
  assert_eq "agent is new" "new" "$agent_status"

  local command_status
  command_status="$(echo "$result" | jq -r '.[] | select(.type == "command") | .status')"
  assert_eq "command is new" "new" "$command_status"

  local skill_status
  skill_status="$(echo "$result" | jq -r '.[] | select(.type == "skill") | .status')"
  assert_eq "skill is new" "new" "$skill_status"

  teardown_temp
}

test_unchanged_items_detected() {
  echo "TEST: identical items on repo and machine are classified as 'unchanged'"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Copy repo items to machine (with CLAUDE.md → claude.md case change)
  echo "# CLAUDE config" > "$CLAUDE_DIR/claude.md"
  mkdir -p "$CLAUDE_DIR/agents"
  cp "$TEST_REPO/agents/alpha.md" "$CLAUDE_DIR/agents/alpha.md"
  mkdir -p "$CLAUDE_DIR/commands"
  cp "$TEST_REPO/commands/beta.md" "$CLAUDE_DIR/commands/beta.md"
  mkdir -p "$CLAUDE_DIR/skills/test-skill"
  cp "$TEST_REPO/skills/test-skill/SKILL.md" "$CLAUDE_DIR/skills/test-skill/SKILL.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local count
  count="$(echo "$result" | jq '[.[] | select(.status == "unchanged")] | length')"
  assert_eq "all 4 items are unchanged" "4" "$count"

  teardown_temp
}

test_modified_items_detected() {
  echo "TEST: items with different content are classified as 'modified'"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Copy repo items to machine, then modify
  echo "# OLD CLAUDE config" > "$CLAUDE_DIR/claude.md"
  mkdir -p "$CLAUDE_DIR/agents"
  echo "# OLD Agent Alpha" > "$CLAUDE_DIR/agents/alpha.md"
  mkdir -p "$CLAUDE_DIR/commands"
  echo "# OLD Command Beta" > "$CLAUDE_DIR/commands/beta.md"
  mkdir -p "$CLAUDE_DIR/skills/test-skill"
  echo "# OLD Test Skill" > "$CLAUDE_DIR/skills/test-skill/SKILL.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local count
  count="$(echo "$result" | jq '[.[] | select(.status == "modified")] | length')"
  assert_eq "all 4 items are modified" "4" "$count"

  teardown_temp
}

test_modified_includes_diff() {
  echo "TEST: modified items include non-empty unified diff"
  setup_temp
  create_mock_gum
  setup_test_repo

  mkdir -p "$CLAUDE_DIR/agents"
  echo "# OLD Agent Alpha" > "$CLAUDE_DIR/agents/alpha.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local diff_text
  diff_text="$(echo "$result" | jq -r '.[] | select(.key == "agent:alpha") | .diff')"
  assert_contains "diff contains --- header" "---" "$diff_text"
  assert_contains "diff contains +++ header" "+++" "$diff_text"
  assert_contains "diff contains old content" "OLD Agent Alpha" "$diff_text"
  assert_contains "diff contains new content" "Agent Alpha" "$diff_text"

  teardown_temp
}

test_new_items_have_empty_diff() {
  echo "TEST: new items have empty diff field"
  setup_temp
  create_mock_gum
  setup_test_repo

  local result
  result="$(run_with_diff 'diff_detect')"

  local diff_text
  diff_text="$(echo "$result" | jq -r '.[] | select(.key == "agent:alpha") | .diff')"
  assert_eq "new item has empty diff" "" "$diff_text"

  teardown_temp
}

test_orphaned_items_detected() {
  echo "TEST: manifest entries with no repo source are classified as 'orphaned'"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Pre-populate manifest with entries for items not in repo
  run_with_diff '
    manifest_set "agent:deleted-agent" "oldhash1"
    manifest_set "command:deleted-cmd" "oldhash2"
  '

  local result
  result="$(run_with_diff 'diff_detect')"

  local orphan_count
  orphan_count="$(echo "$result" | jq '[.[] | select(.status == "orphaned")] | length')"
  assert_eq "2 orphaned items" "2" "$orphan_count"

  local agent_orphan
  agent_orphan="$(echo "$result" | jq -r '.[] | select(.key == "agent:deleted-agent") | .status')"
  assert_eq "deleted agent is orphaned" "orphaned" "$agent_orphan"

  local cmd_orphan
  cmd_orphan="$(echo "$result" | jq -r '.[] | select(.key == "command:deleted-cmd") | .status')"
  assert_eq "deleted command is orphaned" "orphaned" "$cmd_orphan"

  teardown_temp
}

test_non_manifest_machine_items_ignored() {
  echo "TEST: items on machine not in manifest and not in repo are excluded"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Put extra files on machine that have no repo counterpart and no manifest entry
  mkdir -p "$CLAUDE_DIR/agents"
  echo "# Local only agent" > "$CLAUDE_DIR/agents/local-only.md"
  mkdir -p "$CLAUDE_DIR/commands"
  echo "# Local only command" > "$CLAUDE_DIR/commands/local-only.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local local_agent
  local_agent="$(echo "$result" | jq '[.[] | select(.name == "local-only")] | length')"
  assert_eq "local-only items not in output" "0" "$local_agent"

  teardown_temp
}

test_claude_md_case_difference() {
  echo "TEST: CLAUDE.md (repo) maps to claude.md (machine) transparently"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Machine has lowercase claude.md with same content
  echo "# CLAUDE config" > "$CLAUDE_DIR/claude.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local claude_status
  claude_status="$(echo "$result" | jq -r '.[] | select(.type == "claude-md") | .status')"
  assert_eq "CLAUDE.md matches claude.md" "unchanged" "$claude_status"

  teardown_temp
}

test_mixed_statuses() {
  echo "TEST: different items can have different statuses in one detection"
  setup_temp
  create_mock_gum
  setup_test_repo

  # CLAUDE.md: unchanged (copy exactly)
  echo "# CLAUDE config" > "$CLAUDE_DIR/claude.md"

  # Agent: modified (different content)
  mkdir -p "$CLAUDE_DIR/agents"
  echo "# Modified Agent" > "$CLAUDE_DIR/agents/alpha.md"

  # Command: new (not on machine — no action needed)

  # Skill: unchanged (copy exactly)
  mkdir -p "$CLAUDE_DIR/skills/test-skill"
  cp "$TEST_REPO/skills/test-skill/SKILL.md" "$CLAUDE_DIR/skills/test-skill/SKILL.md"

  # Orphan: in manifest but not in repo
  run_with_diff 'manifest_set "agent:removed" "oldhash"'

  local result
  result="$(run_with_diff 'diff_detect')"

  assert_eq "CLAUDE.md unchanged" "unchanged" \
    "$(echo "$result" | jq -r '.[] | select(.type == "claude-md") | .status')"

  assert_eq "agent modified" "modified" \
    "$(echo "$result" | jq -r '.[] | select(.key == "agent:alpha") | .status')"

  assert_eq "command new" "new" \
    "$(echo "$result" | jq -r '.[] | select(.key == "command:beta") | .status')"

  assert_eq "skill unchanged" "unchanged" \
    "$(echo "$result" | jq -r '.[] | select(.key == "skill:test-skill") | .status')"

  assert_eq "removed agent orphaned" "orphaned" \
    "$(echo "$result" | jq -r '.[] | select(.key == "agent:removed") | .status')"

  teardown_temp
}

test_each_item_has_exactly_one_status() {
  echo "TEST: every item is classified into exactly one of the four statuses"
  setup_temp
  create_mock_gum
  setup_test_repo

  local result
  result="$(run_with_diff 'diff_detect')"

  local valid_statuses invalid_count
  invalid_count="$(echo "$result" | jq '[.[] | select(.status != "new" and .status != "modified" and .status != "unchanged" and .status != "orphaned")] | length')"
  assert_eq "no invalid statuses" "0" "$invalid_count"

  local total
  total="$(echo "$result" | jq 'length')"
  local has_status
  has_status="$(echo "$result" | jq '[.[] | select(.status != null and .status != "")] | length')"
  assert_eq "every item has a status" "$total" "$has_status"

  teardown_temp
}

test_skill_directory_hash_comparison() {
  echo "TEST: skills compare full directory content, not just SKILL.md"
  setup_temp
  create_mock_gum
  setup_test_repo

  # Add an extra file to repo skill
  echo "helper code" > "$TEST_REPO/skills/test-skill/helper.sh"

  # Copy only SKILL.md to machine (missing helper.sh → different hash)
  mkdir -p "$CLAUDE_DIR/skills/test-skill"
  cp "$TEST_REPO/skills/test-skill/SKILL.md" "$CLAUDE_DIR/skills/test-skill/SKILL.md"

  local result
  result="$(run_with_diff 'diff_detect')"

  local skill_status
  skill_status="$(echo "$result" | jq -r '.[] | select(.key == "skill:test-skill") | .status')"
  assert_eq "skill with missing file is modified" "modified" "$skill_status"

  teardown_temp
}

test_output_is_valid_json_array() {
  echo "TEST: diff_detect output is a valid JSON array"
  setup_temp
  create_mock_gum
  setup_test_repo

  local result
  result="$(run_with_diff 'diff_detect')"

  local is_array
  is_array="$(echo "$result" | jq 'type')"
  assert_eq "output is array" '"array"' "$is_array"

  local has_required_fields
  has_required_fields="$(echo "$result" | jq '[.[] | select(has("key") and has("type") and has("name") and has("status") and has("diff"))] | length')"
  local total
  total="$(echo "$result" | jq 'length')"
  assert_eq "all items have required fields" "$total" "$has_required_fields"

  teardown_temp
}

test_empty_repo_returns_empty_array() {
  echo "TEST: repo with no syncable items returns empty array"
  setup_temp
  create_mock_gum

  # Create empty repo (no CLAUDE.md, no agents, commands, or skills)
  mkdir -p "$TEST_REPO"

  local result
  result="$(run_with_diff 'diff_detect')"

  local count
  count="$(echo "$result" | jq 'length')"
  assert_eq "empty array for empty repo" "0" "$count"

  teardown_temp
}

# ─── Run all tests ───────────────────────────────────────────────────────────

echo "=== Diff Detection Tests ==="
echo ""

test_new_items_detected
echo ""
test_unchanged_items_detected
echo ""
test_modified_items_detected
echo ""
test_modified_includes_diff
echo ""
test_new_items_have_empty_diff
echo ""
test_orphaned_items_detected
echo ""
test_non_manifest_machine_items_ignored
echo ""
test_claude_md_case_difference
echo ""
test_mixed_statuses
echo ""
test_each_item_has_exactly_one_status
echo ""
test_skill_directory_hash_comparison
echo ""
test_output_is_valid_json_array
echo ""
test_empty_repo_returns_empty_array
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────

echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
