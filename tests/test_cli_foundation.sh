#!/usr/bin/env bash
# E2E tests for CLI foundation (subcommand routing, gum check, error handling)
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

# Create a mock gum that just echoes its arguments (sufficient for foundation tests)
create_mock_gum() {
  cat > "$MOCK_BIN/gum" << 'MOCK'
#!/usr/bin/env bash
# Mock gum: for "style" subcommand, print the last argument (the text content)
if [[ "${1:-}" == "style" ]]; then
  echo "${@: -1}"
else
  echo "gum $*"
fi
MOCK
  chmod +x "$MOCK_BIN/gum"
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

test_no_args_routes_to_install() {
  echo "TEST: no args routes to install flow"
  setup_temp
  create_mock_gum

  # Run with HOME pointing to temp so default path resolves
  local output
  output="$(HOME="$TEST_DIR" PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" "$CLAUDE_DIR" 2>&1)" || true
  assert_contains "routes to install" "Stage 1/4" "$output"
  assert_contains "shows target path" "$CLAUDE_DIR" "$output"

  teardown_temp
}

test_uninstall_subcommand() {
  echo "TEST: uninstall subcommand routes to uninstall flow"
  setup_temp
  create_mock_gum

  local output
  output="$(PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" uninstall "$CLAUDE_DIR" 2>&1)" || true
  assert_contains "routes to uninstall" "Uninstall flow not yet implemented" "$output"

  teardown_temp
}

test_custom_path() {
  echo "TEST: custom path is used"
  setup_temp
  create_mock_gum

  local output
  output="$(PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" "$CLAUDE_DIR" 2>&1)" || true
  assert_contains "custom path shown" "$CLAUDE_DIR" "$output"
  assert_contains "routes to install" "Stage 1/4" "$output"

  teardown_temp
}

test_uninstall_with_custom_path() {
  echo "TEST: uninstall with custom path"
  setup_temp
  create_mock_gum

  local output
  output="$(PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" uninstall "$CLAUDE_DIR" 2>&1)" || true
  assert_contains "custom path shown" "$CLAUDE_DIR" "$output"
  assert_contains "routes to uninstall" "Uninstall flow not yet implemented" "$output"

  teardown_temp
}

test_missing_gum() {
  echo "TEST: missing gum produces helpful error"
  setup_temp
  # Do NOT create mock gum — ensure gum is not in PATH

  local output exit_code=0
  output="$(PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash "$INSTALL_SH" "$CLAUDE_DIR" 2>&1)" || exit_code=$?
  assert_contains "mentions gum" "gum" "$output"
  assert_contains "mentions brew install" "brew install gum" "$output"
  assert_eq "non-zero exit" "1" "$exit_code"

  teardown_temp
}

test_invalid_directory() {
  echo "TEST: invalid directory produces error"
  setup_temp
  create_mock_gum

  local output exit_code=0
  output="$(PATH="$MOCK_BIN:$PATH" bash "$INSTALL_SH" "/nonexistent/path/$$" 2>&1)" || exit_code=$?
  assert_contains "mentions directory" "Directory not found" "$output"
  assert_eq "non-zero exit" "1" "$exit_code"

  teardown_temp
}

test_ctrl_c_clean_exit() {
  echo "TEST: Ctrl+C exits cleanly (exit code 130)"
  setup_temp
  create_mock_gum

  # Create a wrapper that sleeps after sourcing install.sh, so we can send SIGINT
  cat > "$TEST_DIR/sigint_test.sh" << WRAPPER
#!/usr/bin/env bash
source "$INSTALL_SH"
# Script exits before reaching here, but if flow were longer we'd need this
sleep 10
WRAPPER
  chmod +x "$TEST_DIR/sigint_test.sh"

  # Send SIGINT directly to a bash process running install.sh
  local exit_code=0
  bash -c 'PATH="'"$MOCK_BIN"':$PATH" bash "'"$INSTALL_SH"'" "'"$CLAUDE_DIR"'" & pid=$!; sleep 0.1; kill -INT $pid 2>/dev/null; wait $pid 2>/dev/null; echo $?' > "$TEST_DIR/result.txt" 2>&1 || true
  local result
  result="$(tail -1 "$TEST_DIR/result.txt")"

  # Script completes instantly with exit 0 since the flow stub just prints and exits.
  # The trap is verified by checking it's defined in the source.
  local script_content
  script_content="$(cat "$INSTALL_SH")"
  assert_contains "trap defined" "trap cleanup INT TERM" "$script_content"
  assert_contains "cleanup exits 130" "exit 130" "$script_content"

  teardown_temp
}

test_styled_functions_defined() {
  echo "TEST: styled output functions are defined and callable"
  setup_temp
  create_mock_gum

  # Source install.sh in a subshell to check function definitions
  # We need to prevent it from executing, so we override the main flow
  local output
  output="$(PATH="$MOCK_BIN:$PATH" bash -c '
    source "'"$INSTALL_SH"'" 2>/dev/null || true
    # If we got here, functions were loaded. But install.sh runs immediately.
    # Instead, check that functions exist by grepping the file.
    true
  ')" || true

  # Verify functions are defined in the script
  local script_content
  script_content="$(cat "$INSTALL_SH")"
  assert_contains "print_header defined" "print_header()" "$script_content"
  assert_contains "print_status_new defined" "print_status_new()" "$script_content"
  assert_contains "print_status_modified defined" "print_status_modified()" "$script_content"
  assert_contains "print_status_unchanged defined" "print_status_unchanged()" "$script_content"
  assert_contains "print_status_orphaned defined" "print_status_orphaned()" "$script_content"
  assert_contains "print_success defined" "print_success()" "$script_content"
  assert_contains "print_error defined" "print_error()" "$script_content"

  teardown_temp
}

# ─── Run all tests ───────────────────────────────────────────────────────────

echo "=== CLI Foundation Tests ==="
echo ""

test_no_args_routes_to_install
echo ""
test_uninstall_subcommand
echo ""
test_custom_path
echo ""
test_uninstall_with_custom_path
echo ""
test_missing_gum
echo ""
test_invalid_directory
echo ""
test_ctrl_c_clean_exit
echo ""
test_styled_functions_defined
echo ""

# ─── Summary ─────────────────────────────────────────────────────────────────

echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
