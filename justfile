# MoonBit Project Commands

# Default target (native for CLI tool)
target := "native"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Check formatting without rewriting files
fmt-check:
    moon fmt --check

# Type check
check:
    moon check --deny-warn --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Run main
run:
    moon run cmd/bm --target {{target}}

# Generate type definition files
info:
    moon info

# Verify generated type definition files are up to date
info-check:
    moon info
    test -z "`git status --porcelain -- ':(glob)**/*.generated.mbti'`"

# Clean build artifacts
clean:
    moon clean

# Run E2E tests
e2e:
    bash scripts/e2e_test.sh

# Pre-release check
release-check: fmt info check test

# CI checks for the default target on a clean worktree
ci: fmt-check info-check check test
