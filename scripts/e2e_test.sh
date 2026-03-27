#!/bin/bash
# E2E Test Script for beads_mbt
# Run with: bash scripts/e2e_test.sh
# Note: Must be run from project root directory

set -e

PROJECT_DIR="$(pwd)"
BEADS_DIR="$PROJECT_DIR/.beads"

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

# Cleanup function
cleanup() {
    log_info "Cleaning up test database..."
    rm -rf "$BEADS_DIR"
}

# Setup test environment
setup() {
    log_info "Setting up test environment..."
    rm -rf "$BEADS_DIR"
}

# Run a command and capture output
run_cmd() {
    moon run cmd/main -- "$@" 2>&1
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

test_help() {
    test_start "Test: help command"
    
    output=$(run_cmd --help)
    
    if echo "$output" | grep -q "Commands:"; then
        test_pass "help shows commands"
    else
        test_fail "help should show commands"
    fi
}

test_version() {
    test_start "Test: version command"
    
    output=$(run_cmd --version)
    
    if echo "$output" | grep -q "beads"; then
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
