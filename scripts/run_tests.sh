#!/bin/bash
# Test Runner for beads_mbt
# Runs both unit tests and E2E tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "========================================"
echo "Running beads_mbt Tests"
echo "========================================"

# Run E2E tests for skills
echo ""
echo "Skills E2E Tests:"
echo "----------------"
cd "$PROJECT_DIR/.skills"
bash tests/e2e/run_tests.sh

# Run project E2E tests
echo ""
echo "Project E2E Tests:"
echo "------------------"
cd "$PROJECT_DIR"
if [ -f "scripts/e2e_test.sh" ]; then
    bash scripts/e2e_test.sh
else
    echo "No project E2E tests found"
fi

echo ""
echo "========================================"
echo "All tests completed!"
echo "========================================"
