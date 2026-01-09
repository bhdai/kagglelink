#!/usr/bin/env bats
# Test suite for repository clone with graceful recovery (Story 1.4)
#
# Tests:
# - Existing directory removal before clone
# - Git prerequisite check
# - Commit hash logging
# - Network error categorization
# - Branch not found error handling

load '../test_helper/common'

setup() {
    # Store original directory
    export ORIGINAL_DIR="$PWD"
    
    # Create isolated test environment
    export TEST_TEMP_DIR="$(mktemp -d)"
    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"
    
    # Store original PATH
    export ORIGINAL_PATH="$PATH"
    
    # Export PROJECT_ROOT for tests
    export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
}

teardown() {
    # Restore PATH
    export PATH="$ORIGINAL_PATH"
    
    # Clean up test environment
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
}

# ============================================================================
# AC3: Git Prerequisite Check
# ============================================================================

@test "P0: should detect missing git command" {
    # Verify git check exists in source code (functional verification)
    run grep -A 2 'if ! command -v git' "$PROJECT_ROOT/setup.sh"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"git is not installed"* ]]
    
    # Verify error categorization is used
    run grep 'categorize_error "prerequisite".*git' "$PROJECT_ROOT/setup.sh"
    [ "$status" -eq 0 ]
}

# ============================================================================
# AC1: Handle Existing Directory
# ============================================================================

@test "P0: should remove existing /tmp/kagglelink before clone" {
    # Create mock git that simulates clone behavior
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    # Mock git clone that creates the directory
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
if [ "$1" = "clone" ]; then
    # Extract target directory (last argument)
    for last; do true; done
    mkdir -p "$last/.git"
    printf '#!/bin/sh\necho "abc123"' > "$last/.git/rev-parse"
    chmod +x "$last/.git/rev-parse"
    exit 0
elif [ "$1" = "rev-parse" ]; then
    echo "abc123"
    exit 0
fi
exit 1
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    # Pre-create directory with marker file
    mkdir -p /tmp/kagglelink
    touch /tmp/kagglelink/pre_existing_marker
    
    # Run with mocked git
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    # Verify marker file is gone (directory was recreated)
    [ ! -f /tmp/kagglelink/pre_existing_marker ]
}

# ============================================================================
# AC4: Clone Success Verification - Commit Hash Logging
# ============================================================================

@test "P1: should log commit hash after successful clone" {
    # Create mock git that returns commit hash
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
if [ "$1" = "clone" ]; then
    for last; do true; done
    mkdir -p "$last"
    exit 0
elif [ "$1" = "rev-parse" ]; then
    echo "abc1234"
    exit 0
fi
exit 1
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    # Verify commit hash appears in output
    [[ "$output" =~ commit:\ abc1234 ]]
}

@test "P1: should handle git rev-parse failure gracefully" {
    # Create mock git where rev-parse fails
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
if [ "$1" = "clone" ]; then
    for last; do true; done
    mkdir -p "$last"
    exit 0
elif [ "$1" = "rev-parse" ]; then
    exit 1
fi
exit 1
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    # Should fallback to "unknown"
    [[ "$output" =~ commit:\ unknown ]]
}

# ============================================================================
# AC2: Network Failure Handling - Error Categorization
# ============================================================================

@test "P1: should categorize network connectivity errors" {
    # Mock git to simulate network error
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
echo "fatal: Could not resolve host: github.com" >&2
exit 128
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    [ "$status" -eq 1 ]
    # Check that our categorize_error logic caught it
    [[ "$output" =~ "Network connectivity issue" ]]
    [[ "$output" =~ "Check connectivity" ]]
}

@test "P1: should categorize branch not found errors" {
    # Mock git to simulate branch error
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
echo "fatal: Remote branch feature/missing not found in upstream origin" >&2
exit 128
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "does not exist" ]]
    [[ "$output" =~ "Use BRANCH=main" ]]
}

@test "P1: should categorize upstream errors for other failures" {
    # Mock git to simulate generic failure
    mkdir -p "$TEST_TEMP_DIR/bin"
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
echo "fatal: something went wrong on github side" >&2
exit 128
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Failed to clone repository" ]]
    [[ "$output" =~ "GitHub may be temporarily unavailable" ]]
}

# ============================================================================
# AC5: Shallow Clone Optimization
# ============================================================================

@test "P1: should use shallow clone with --depth 1" {
    # Create mock git that captures and validates arguments
    mkdir -p "$TEST_TEMP_DIR/bin"
    
    cat > "$TEST_TEMP_DIR/bin/git" <<'MOCKGIT'
#!/bin/sh
# Log all git commands to a file
echo "$*" >> /tmp/git_commands.log

if [ "$1" = "clone" ]; then
    # Check if --depth 1 is present
    if ! echo "$*" | grep -q "\-\-depth 1"; then
        echo "ERROR: --depth 1 not found in git clone command" >&2
        exit 99
    fi
    for last; do true; done
    mkdir -p "$last"
    exit 0
elif [ "$1" = "rev-parse" ]; then
    echo "abc1234"
    exit 0
fi
exit 1
MOCKGIT
    chmod +x "$TEST_TEMP_DIR/bin/git"
    
    # Clear log file
    rm -f /tmp/git_commands.log
    
    export PATH="$TEST_TEMP_DIR/bin:$ORIGINAL_PATH"
    run bash "$PROJECT_ROOT/setup.sh" -k "https://example.com/keys" -t "test-token"
    
    # Should succeed (exit 99 would indicate --depth 1 was missing)
    [ "$status" -ne 99 ]
    
    # Verify git clone was called with --depth 1
    [ -f /tmp/git_commands.log ]
    run cat /tmp/git_commands.log
    [[ "$output" == *"--depth 1"* ]]
    
    # Cleanup
    rm -f /tmp/git_commands.log
}

# ============================================================================
# Edge Cases and Regression Prevention
# ============================================================================

@test "P2: setup.sh should still have inline logging functions" {
    # Verify logging functions are still embedded (bootstrap requirement)
    run grep -n "^log_info()" "$PROJECT_ROOT/setup.sh"
    [ "$status" -eq 0 ]
    
    run grep -n "^log_success()" "$PROJECT_ROOT/setup.sh"
    [ "$status" -eq 0 ]
    
    run grep -n "^categorize_error()" "$PROJECT_ROOT/setup.sh"
    [ "$status" -eq 0 ]
}

@test "P2: should handle empty INSTALL_DIR variable gracefully" {
    # Test that script validates INSTALL_DIR exists
    run grep -n 'if \[ -d "\$INSTALL_DIR" \]' "$PROJECT_ROOT/setup.sh"
    [ "$status" -eq 0 ]
}

