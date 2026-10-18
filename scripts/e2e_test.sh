#!/bin/bash
# E2E Test Script for beads_mbt
# Run with: bash scripts/e2e_test.sh
#
# The tests run in an isolated temporary workspace, so they never touch the
# developer's ./.beads directory and can safely run in parallel. The CLI
# resolves its database relative to the current directory, so the binary is
# built once and then executed from the temporary workspace.

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BM_BIN="$PROJECT_DIR/_build/native/debug/build/cmd/bm/bm.exe"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

test_start() {
    echo -e "\n${GREEN}▶${NC} $1"
}

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++)) || true
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++)) || true
}

# Isolated workspace created in setup()
WORKDIR=""
BEADS_DIR=""

# Cleanup function
cleanup() {
    log_info "Cleaning up test workspace..."
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
}

# Setup test environment
setup() {
    log_info "Building binary and setting up test workspace..."
    ( cd "$PROJECT_DIR" && moon build cmd/bm --target native )
    WORKDIR="$(mktemp -d)"
    BEADS_DIR="$WORKDIR/.beads"
}

# Run a command in the isolated workspace and capture output.
# Failures are expected in some tests, so a non-zero exit must not stop the run
run_cmd() {
    ( cd "$WORKDIR" && "$BM_BIN" "$@" ) 2>&1 || true
    return 0
}

# Run a command and capture stdout only, so the JSON stream stays parseable
run_cmd_stdout() {
    ( cd "$WORKDIR" && "$BM_BIN" "$@" ) 2>/dev/null || true
    return 0
}

# Run a command and print its exit code
run_cmd_status() {
    local status=0
    ( cd "$WORKDIR" && "$BM_BIN" "$@" ) >/dev/null 2>&1 || status=$?
    echo "$status"
}

# Is a helper available? Used to keep the suite usable without optional tools
have() {
    command -v "$1" >/dev/null 2>&1
}

# Validate a JSON document when an interpreter is available
valid_json() {
    if have python3; then
        echo "$1" | python3 -m json.tool >/dev/null 2>&1
    elif have jq; then
        echo "$1" | jq . >/dev/null 2>&1
    else
        true
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

test_init() {
    test_start "Test: init command"
    
    output=$(run_cmd init)
    
    if echo "$output" | grep -q "Workspace initialized"; then
        test_pass "init creates workspace"
    else
        test_fail "init should create workspace"
    fi
    
    # Verify files created
    if [ -f "$BEADS_DIR/beads.db" ]; then
        test_pass "init creates database"
    else
        test_fail "init should create beads.db"
    fi
}

test_create() {
    test_start "Test: create command"
    
    output=$(run_cmd create "Test issue")
    
    if echo "$output" | grep -q "Created:"; then
        test_pass "create creates issue"
    else
        test_fail "create should create issue"
    fi
}

test_list() {
    test_start "Test: list command"
    
    output=$(run_cmd list)
    
    if echo "$output" | grep -q "Issues:"; then
        test_pass "list shows issues"
    else
        test_fail "list should show issues"
    fi
}

test_show() {
    test_start "Test: show command"
    
    # Get the issue ID from list output (format: "  bd-xxxxxx  Title")
    issue_id=$(run_cmd list | grep "bd-" | head -1 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)
    
    if [ -n "$issue_id" ]; then
        output=$(run_cmd show "$issue_id")
        
        if echo "$output" | grep -q "Issue:"; then
            test_pass "show displays issue"
        else
            test_fail "show should display issue"
            echo "Debug: issue_id='$issue_id'"
            echo "Output: $output"
        fi
    else
        test_fail "No issue ID found for show test"
    fi
}

test_update() {
    test_start "Test: update command"
    
    issue_id=$(run_cmd list | grep "bd-" | head -1 | awk '{print $2}')
    
    if [ -n "$issue_id" ]; then
        output=$(run_cmd update "$issue_id" --title "Updated title")
        
        if echo "$output" | grep -q "Updated title"; then
            test_pass "update changes title"
        else
            test_fail "update should change title"
        fi
    else
        test_fail "No issue ID found for update test"
    fi
}

test_close() {
    test_start "Test: close command"
    
    issue_id=$(run_cmd list | grep "bd-" | head -1 | awk '{print $2}')
    
    if [ -n "$issue_id" ]; then
        output=$(run_cmd close "$issue_id")
        
        if echo "$output" | grep -q "Closed:"; then
            test_pass "close marks issue as closed"
        else
            test_fail "close should mark issue as closed"
        fi
    else
        test_fail "No issue ID found for close test"
    fi
}

test_ready() {
    test_start "Test: ready command"
    
    output=$(run_cmd ready)
    
    # Ready should show no issues (all closed) or show header
    if echo "$output" | grep -qE "(No issues|Ready to work)"; then
        test_pass "ready shows appropriate message"
    else
        test_fail "ready should show appropriate message"
        echo "Output: $output"
    fi
}

test_defer() {
    test_start "Test: defer command"
    
    # Create a new issue
    run_cmd create "Defer test" > /dev/null 2>&1
    issue_id=$(run_cmd list | grep "bd-" | tail -1 | awk '{print $2}')
    
    if [ -n "$issue_id" ]; then
        output=$(run_cmd defer "$issue_id")
        
        if echo "$output" | grep -q "Deferred:"; then
            test_pass "defer marks issue as deferred"
        else
            test_fail "defer should mark issue as deferred"
        fi
    else
        test_fail "No issue ID found for defer test"
    fi
}

test_create_flags() {
    test_start "Test: create with --priority and --type"

    output=$(run_cmd create "Flag test" --priority P0 --type bug)
    issue_id=$(echo "$output" | sed 's/Created: //')

    if [ -n "$issue_id" ]; then
        detail=$(run_cmd show "$issue_id")

        if echo "$detail" | grep -q "Priority: P0" && echo "$detail" | grep -q "Type: bug"; then
            test_pass "create applies --priority and --type"
        else
            test_fail "create should apply --priority and --type"
            echo "Output: $detail"
        fi
    else
        test_fail "create with flags should return an issue id"
    fi
}

test_create_flags_reject_invalid() {
    test_start "Test: create rejects invalid flag values"

    output=$(run_cmd create "Bad priority" --priority 9)
    if ! echo "$output" | grep -q "invalid priority"; then
        test_fail "create should reject --priority 9"
        return
    fi

    output=$(run_cmd create "Bad type" --type nonsense)
    if ! echo "$output" | grep -q "invalid type"; then
        test_fail "create should reject --type nonsense"
        return
    fi

    test_pass "create rejects invalid --priority and --type"
}

test_ready_skips_blocked() {
    test_start "Test: ready skips blocked issues"

    holder=$(run_cmd create "Holder issue" | sed 's/Created: //')
    waiting=$(run_cmd create "Waiting issue" | sed 's/Created: //')
    run_cmd dep add "$waiting" "$holder" > /dev/null

    ready_output=$(run_cmd ready)
    blocked_output=$(run_cmd blocked)

    if echo "$ready_output" | grep -q "$waiting"; then
        test_fail "ready should not list a blocked issue"
    elif ! echo "$ready_output" | grep -q "$holder"; then
        test_fail "ready should still list the unblocked holder"
    elif ! echo "$blocked_output" | grep -q "$waiting"; then
        test_fail "blocked should list the waiting issue"
    else
        test_pass "ready skips blocked issues and blocked lists them"
    fi

    # Closing the blocker releases the waiting issue.
    run_cmd close "$holder" > /dev/null

    if run_cmd ready | grep -q "$waiting"; then
        test_pass "closing the blocker makes the issue ready"
    else
        test_fail "closing the blocker should make the issue ready"
    fi
}

test_search() {
    test_start "Test: search command"

    output=$(run_cmd search "DEFER")

    if echo "$output" | grep -q "Defer test"; then
        test_pass "search matches titles ignoring case"
    else
        test_fail "search should match titles ignoring case"
        echo "Output: $output"
    fi

    output=$(run_cmd search "no-such-text-anywhere")

    if echo "$output" | grep -q "No issues found"; then
        test_pass "search reports when nothing matches"
    else
        test_fail "search should report when nothing matches"
    fi
}

test_help() {
    test_start "Test: help command"
    
    output=$(run_cmd --help)
    
    if echo "$output" | grep -q "Commands:"; then
        test_pass "help shows commands"
    else
        test_fail "help should show commands"
    fi
}

# ============================================================================
# Step 2: machine-readable output
# ============================================================================

test_json_list() {
    test_start "Test: list --json envelope"

    run_cmd create "Json subject" >/dev/null

    output=$(run_cmd_stdout list --json)

    if ! echo "$output" | grep -q '"issues"'; then
        test_fail "list --json should keep the issues key"
        echo "Output: $output"
        return
    fi
    if ! echo "$output" | grep -q '"total"' || ! echo "$output" | grep -q '"has_more"'; then
        test_fail "list --json should keep the page keys"
        echo "Output: $output"
        return
    fi
    if ! valid_json "$output"; then
        test_fail "list --json should be valid JSON"
        echo "Output: $output"
        return
    fi

    # --robot is the alias of --json, and --fields trims the projection
    robot=$(run_cmd_stdout list --robot --fields id,title)
    if ! echo "$robot" | grep -q '"title"'; then
        test_fail "list --robot --fields should project the columns"
        echo "Output: $robot"
        return
    fi
    if echo "$robot" | grep -q '"description"'; then
        test_fail "list --robot --fields should drop the unselected columns"
        return
    fi

    test_pass "list --json writes the page envelope and honors --robot/--fields"
}

test_json_ready_and_search() {
    test_start "Test: ready --json and search --json"

    run_cmd create "Json ready subject" >/dev/null

    ready_all=$(run_cmd_stdout ready --json)
    if ! echo "$ready_all" | grep -q '"description"'; then
        test_fail "ready --json should hydrate the full record"
        echo "Output: $ready_all"
        return
    fi

    ready_brief=$(run_cmd_stdout ready --brief --json)
    if echo "$ready_brief" | grep -q '"description"'; then
        test_fail "ready --brief should drop the long text columns"
        return
    fi
    if ! echo "$ready_brief" | grep -q '"issue_type"'; then
        test_fail "ready --brief should keep the columns needed to choose work"
        return
    fi
    if ! valid_json "$ready_brief"; then
        test_fail "ready --brief --json should be valid JSON"
        return
    fi

    found=$(run_cmd_stdout search "Json ready" --json)
    if ! echo "$found" | grep -q '"hidden_closed_count"'; then
        test_fail "search --json should keep the search keys"
        echo "Output: $found"
        return
    fi
    # text mode still reports the same match
    if ! run_cmd search "Json ready" | grep -q "Json ready subject"; then
        test_fail "search text output should still list the match"
        return
    fi

    test_pass "ready and search write JSON and keep text output working"
}

test_json_error_envelopes() {
    test_start "Test: JSON errors and exit codes"

    output=$(run_cmd_stdout show bd-NOTEXIST --json)
    status=$(run_cmd_status show bd-NOTEXIST --json)

    if [ "$status" != "3" ]; then
        test_fail "show of a missing issue should exit 3, got $status"
        return
    fi
    if ! echo "$output" | grep -q '"code":"ISSUE_NOT_FOUND"'; then
        test_fail "the envelope should carry ISSUE_NOT_FOUND"
        echo "Output: $output"
        return
    fi
    if ! valid_json "$output"; then
        test_fail "the error envelope should be valid JSON"
        return
    fi

    # human mode keeps the diagnostic on stderr so stdout stays clean
    human_stdout=$(run_cmd_stdout show bd-NOTEXIST)
    if [ -n "$human_stdout" ]; then
        test_fail "human mode should not write an error to stdout"
        echo "Output: $human_stdout"
        return
    fi

    if [ "$(run_cmd_status create 'Bad priority' --priority 9)" != "4" ]; then
        test_fail "an invalid priority should exit 4"
        return
    fi
    if [ "$(run_cmd_status list --sort priority)" != "4" ]; then
        test_fail "an unknown option should exit 4"
        return
    fi
    if [ "$(run_cmd_status frobnicate)" != "4" ]; then
        test_fail "an unknown command should exit 4"
        return
    fi
    if [ "$(run_cmd_status sync)" != "1" ]; then
        test_fail "the sync stub should exit 1"
        return
    fi

    test_pass "failures carry the documented exit codes and envelopes"
}

test_exclude_label() {
    test_start "Test: --exclude-label"

    hidden=$(run_cmd create "Hidden work" | sed 's/Created: //')
    shown=$(run_cmd create "Visible work" | sed 's/Created: //')
    run_cmd label add "$hidden" internal >/dev/null

    listed=$(run_cmd list --exclude-label internal)
    if echo "$listed" | grep -q "$hidden"; then
        test_fail "list --exclude-label should hide the labeled issue"
        return
    fi
    if ! echo "$listed" | grep -q "$shown"; then
        test_fail "list --exclude-label should keep unlabeled issues"
        return
    fi

    ready=$(run_cmd ready --exclude-label internal)
    if echo "$ready" | grep -q "$hidden"; then
        test_fail "ready --exclude-label should hide the labeled issue"
        return
    fi

    searched=$(run_cmd search "work" --exclude-label internal)
    if echo "$searched" | grep -q "$hidden"; then
        test_fail "search --exclude-label should hide the labeled issue"
        return
    fi

    # list and ready only: blocked has no such filter
    if [ "$(run_cmd_status blocked --exclude-label internal)" != "4" ]; then
        test_fail "blocked --exclude-label should be rejected"
        return
    fi

    test_pass "--exclude-label hides any matching issue"
}

test_show_multiple_ids() {
    test_start "Test: show with several IDs"

    first=$(run_cmd create "First shown" | sed 's/Created: //')
    second=$(run_cmd create "Second shown" | sed 's/Created: //')

    output=$(run_cmd show "$first" "$second")
    if ! echo "$output" | grep -q "First shown" || ! echo "$output" | grep -q "Second shown"; then
        test_fail "show should print every requested issue"
        echo "Output: $output"
        return
    fi

    json=$(run_cmd_stdout show "$first" "$second" --json)
    if ! valid_json "$json"; then
        test_fail "show --json should be valid JSON"
        return
    fi
    if [ "$(echo "$json" | grep -o '"id"' | wc -l)" != "2" ]; then
        test_fail "show --json should write one object per ID"
        echo "Output: $json"
        return
    fi

    # one missing ID fails the whole command, like beads_rust
    if [ "$(run_cmd_status show "$first" bd-NOTEXIST)" != "3" ]; then
        test_fail "show should fail when any ID is missing"
        return
    fi

    test_pass "show accepts several IDs and fails when one is missing"
}

test_show_planning_sections() {
    test_start "Test: show renders the planning sections"

    if ! have sqlite3; then
        test_pass "skipped: sqlite3 is not available"
        return
    fi

    issue=$(run_cmd create "Planned work" | sed 's/Created: //')
    sqlite3 "$BEADS_DIR/beads.db" \
        "UPDATE issues SET acceptance_criteria = '- [ ] green tests', prerequisites = 'needs a design' WHERE id = '$issue';"

    output=$(run_cmd show "$issue")
    if ! echo "$output" | grep -q "Prerequisites:"; then
        test_fail "show should print the Prerequisites section"
        echo "Output: $output"
        return
    fi
    if ! echo "$output" | grep -q "Acceptance Criteria:"; then
        test_fail "show should print the Acceptance Criteria section"
        return
    fi
    if ! echo "$output" | grep -q "green tests"; then
        test_fail "show should print the acceptance criteria text"
        return
    fi

    # an issue without those columns prints neither heading
    plain=$(run_cmd create "Unplanned work" | sed 's/Created: //')
    if run_cmd show "$plain" | grep -q "Prerequisites:"; then
        test_fail "show should omit an empty Prerequisites section"
        return
    fi

    test_pass "show prints the planning sections only when they have text"
}

test_version() {
    test_start "Test: version command"
    
    output=$(run_cmd --version)
    
    if echo "$output" | grep -q "bm"; then
        test_pass "version shows version"
    else
        test_fail "version should show version"
    fi
}

test_unknown_command() {
    test_start "Test: unknown command"
    
    output=$(run_cmd unknown)
    
    if echo "$output" | grep -q "unknown command"; then
        test_pass "unknown command shows error"
    else
        test_fail "unknown command should show error"
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    log_info "Starting E2E tests for beads_mbt"
    
    # Setup
    setup
    trap cleanup EXIT
    
    # Run tests
    test_init
    test_create
    test_list
    test_show
    test_update
    test_close
    test_ready
    test_defer
    test_create_flags
    test_create_flags_reject_invalid
    test_ready_skips_blocked
    test_search
    test_json_list
    test_json_ready_and_search
    test_json_error_envelopes
    test_exclude_label
    test_show_multiple_ids
    test_show_planning_sections
    test_help
    test_version
    test_unknown_command
    
    # Summary
    echo -e "\n========================================"
    echo -e "${GREEN}Passed: $PASSED${NC}"
    echo -e "${RED}Failed: $FAILED${NC}"
    echo "========================================"
    
    if [ $FAILED -gt 0 ]; then
        log_info "Some tests failed!"
        exit 1
    else
        log_info "All tests passed!"
        exit 0
    fi
}

main "$@"
