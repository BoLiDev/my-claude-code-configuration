#!/usr/bin/env bash
# E2E tests for sync manifest read/write operations
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

# Source install.sh in a subprocess to get manifest functions, then run commands.
# All install.sh startup output (header, stub) is suppressed.
run_with_manifest() {
  local commands="$1"
  PATH="$MOCK_BIN:$PATH" bash -c '
    source "'"$INSTALL_SH"'" "'"$CLAUDE_DIR"'" > /dev/null 2>&1
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

test_first_run_creates_manifest() {
  echo "TEST: first manifest_set creates manifest file"
  setup_temp
  create_mock_gum

  assert_eq "no manifest initially" "false" \
    "$([[ -f "$CLAUDE_DIR/.claude-sync-manifest.json" ]] && echo true || echo false)"

  run_with_manifest 'manifest_set "agent:code-reviewer" "abc123"'

  assert_eq "manifest created" "true" \
    "$([[ -f "$CLAUDE_DIR/.claude-sync-manifest.json" ]] && echo true || echo false)"

  teardown_temp
}

test_entry_records_correct_fields() {
  echo "TEST: manifest entry records hash and installed_at"
  setup_temp
  create_mock_gum

  run_with_manifest 'manifest_set "agent:code-reviewer" "abc123hash"'

  local manifest
  manifest="$(cat "$CLAUDE_DIR/.claude-sync-manifest.json")"

  local hash
  hash="$(echo "$manifest" | jq -r '.["agent:code-reviewer"].hash')"
  assert_eq "hash recorded" "abc123hash" "$hash"

  local installed_at
  installed_at="$(echo "$manifest" | jq -r '.["agent:code-reviewer"].installed_at')"
  assert_contains "timestamp is ISO format" "T" "$installed_at"
  assert_contains "timestamp ends with Z" "Z" "$installed_at"

  teardown_temp
}

test_manifest_is_valid_json() {
  echo "TEST: manifest with multiple entries is valid JSON"
  setup_temp
  create_mock_gum

  run_with_manifest '
    manifest_set "agent:a1" "hash1"
    manifest_set "command:c1" "hash2"
    manifest_set "skill:s1" "hash3"
  '

  local exit_code=0
  jq . "$CLAUDE_DIR/.claude-sync-manifest.json" > /dev/null 2>&1 || exit_code=$?
  assert_eq "valid JSON" "0" "$exit_code"

  local count
  count="$(jq 'keys | length' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "3 entries" "3" "$count"

  teardown_temp
}

test_manifest_remove() {
  echo "TEST: manifest_remove deletes entry and keeps others"
  setup_temp
  create_mock_gum

  run_with_manifest '
    manifest_set "agent:test" "hash1"
    manifest_set "command:keep" "hash2"
    manifest_remove "agent:test"
  '

  local has_removed has_kept
  has_removed="$(jq 'has("agent:test")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  has_kept="$(jq 'has("command:keep")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "removed entry gone" "false" "$has_removed"
  assert_eq "other entry kept" "true" "$has_kept"

  teardown_temp
}

test_manifest_read_no_file() {
  echo "TEST: manifest_read returns empty object when no manifest exists"
  setup_temp
  create_mock_gum

  local output
  output="$(run_with_manifest 'manifest_read')"
  assert_eq "empty object" "{}" "$output"

  teardown_temp
}

test_cleanup_removes_orphaned_entries() {
  echo "TEST: manifest_cleanup removes entries for deleted files"
  setup_temp
  create_mock_gum

  mkdir -p "$CLAUDE_DIR/agents"
  echo "# kept" > "$CLAUDE_DIR/agents/keep.md"

  run_with_manifest '
    manifest_set "agent:keep" "hash1"
    manifest_set "agent:deleted" "hash2"
    manifest_cleanup
  '

  local has_keep has_deleted
  has_keep="$(jq 'has("agent:keep")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  has_deleted="$(jq 'has("agent:deleted")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "existing file entry kept" "true" "$has_keep"
  assert_eq "missing file entry removed" "false" "$has_deleted"

  teardown_temp
}

test_cleanup_handles_all_asset_types() {
  echo "TEST: manifest_cleanup handles claude-md, agent, command, skill types"
  setup_temp
  create_mock_gum

  # Create real files for entries that should survive
  echo "# claude" > "$CLAUDE_DIR/claude.md"
  mkdir -p "$CLAUDE_DIR/agents"
  echo "# agent" > "$CLAUDE_DIR/agents/real-agent.md"
  mkdir -p "$CLAUDE_DIR/commands"
  echo "# command" > "$CLAUDE_DIR/commands/real-cmd.md"
  mkdir -p "$CLAUDE_DIR/skills/real-skill"
  echo "# skill" > "$CLAUDE_DIR/skills/real-skill/SKILL.md"

  run_with_manifest '
    manifest_set "claude-md:CLAUDE.md" "h1"
    manifest_set "agent:real-agent" "h2"
    manifest_set "command:real-cmd" "h3"
    manifest_set "skill:real-skill" "h4"
    manifest_set "agent:ghost-agent" "h5"
    manifest_set "command:ghost-cmd" "h6"
    manifest_set "skill:ghost-skill" "h7"
    manifest_cleanup
  '

  local count
  count="$(jq 'keys | length' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "4 entries survive cleanup" "4" "$count"

  assert_eq "ghost agent removed" "false" \
    "$(jq 'has("agent:ghost-agent")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "ghost command removed" "false" \
    "$(jq 'has("command:ghost-cmd")' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "ghost skill removed" "false" \
    "$(jq 'has("skill:ghost-skill")' "$CLAUDE_DIR/.claude-sync-manifest.json")"

  teardown_temp
}

test_atomic_write_pattern() {
  echo "TEST: manifest_write uses atomic temp-file-then-mv pattern"
  setup_temp
  create_mock_gum

  local script_content
  script_content="$(cat "$INSTALL_SH")"
  assert_contains "uses mktemp for temp file" "mktemp" "$script_content"
  assert_contains "uses mv for atomic rename" 'mv "$tmpfile" "$mpath"' "$script_content"

  teardown_temp
}

test_content_hash_file() {
  echo "TEST: content_hash produces consistent SHA-256 for files"
  setup_temp
  create_mock_gum

  echo "hello world" > "$TEST_DIR/hashme.txt"

  local hash
  hash="$(run_with_manifest 'content_hash "'"$TEST_DIR"'/hashme.txt"')"
  assert_eq "SHA-256 is 64 chars" "64" "${#hash}"

  local hash2
  hash2="$(run_with_manifest 'content_hash "'"$TEST_DIR"'/hashme.txt"')"
  assert_eq "hash is deterministic" "$hash" "$hash2"

  teardown_temp
}

test_content_hash_directory() {
  echo "TEST: content_hash works for directories and detects changes"
  setup_temp
  create_mock_gum

  mkdir -p "$TEST_DIR/skill_dir"
  echo "# Skill" > "$TEST_DIR/skill_dir/SKILL.md"
  echo "extra" > "$TEST_DIR/skill_dir/helper.sh"

  local hash
  hash="$(run_with_manifest 'content_hash "'"$TEST_DIR"'/skill_dir"')"
  assert_eq "directory hash is 64 chars" "64" "${#hash}"

  echo "modified" >> "$TEST_DIR/skill_dir/helper.sh"
  local hash2
  hash2="$(run_with_manifest 'content_hash "'"$TEST_DIR"'/skill_dir"')"

  if [[ "$hash" != "$hash2" ]]; then
    echo "  PASS: hash changes when content changes"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: hash should change when content changes"
    FAIL=$((FAIL + 1))
  fi

  teardown_temp
}

test_multiple_install_uninstall_cycles() {
  echo "TEST: manifest survives multiple install/uninstall cycles"
  setup_temp
  create_mock_gum

  # Cycle 1: install two items
  run_with_manifest '
    manifest_set "agent:a1" "hash1"
    manifest_set "command:c1" "hash2"
  '

  # Cycle 2: remove one, add another
  run_with_manifest '
    manifest_remove "agent:a1"
    manifest_set "skill:s1" "hash3"
  '

  # Cycle 3: update existing entry
  run_with_manifest 'manifest_set "command:c1" "hash2-updated"'

  local count
  count="$(jq 'keys | length' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "2 entries remain" "2" "$count"

  assert_eq "removed entry stays gone" "false" \
    "$(jq 'has("agent:a1")' "$CLAUDE_DIR/.claude-sync-manifest.json")"

  local updated_hash
  updated_hash="$(jq -r '.["command:c1"].hash' "$CLAUDE_DIR/.claude-sync-manifest.json")"
  assert_eq "hash was updated" "hash2-updated" "$updated_hash"

  local exit_code=0
  jq . "$CLAUDE_DIR/.claude-sync-manifest.json" > /dev/null 2>&1 || exit_code=$?
  assert_eq "valid JSON after 3 cycles" "0" "$exit_code"

  teardown_temp
}

test_require_jq_defined() {
  echo "TEST: require_jq dependency check is defined"
  setup_temp

  local script_content
  script_content="$(cat "$INSTALL_SH")"
  assert_contains "require_jq defined" "require_jq()" "$script_content"
  assert_contains "checks for jq" "command -v jq" "$script_content"
  assert_contains "suggests brew install jq" "brew install jq" "$script_content"

  teardown_temp
}

# ─── Run all tests ───────────────────────────────────────────────────────────

echo "=== Sync Manifest Tests ==="
echo ""

test_first_run_creates_manifest
echo ""
test_entry_records_correct_fields
echo ""
test_manifest_is_valid_json
echo ""
test_manifest_remove
echo ""
test_manifest_read_no_file
echo ""
test_cleanup_removes_orphaned_entries
echo ""
test_cleanup_handles_all_asset_types
echo ""
test_atomic_write_pattern
echo ""
test_content_hash_file
echo ""
test_content_hash_directory
echo ""
test_multiple_install_uninstall_cycles
echo ""
test_require_jq_defined
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────

echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
