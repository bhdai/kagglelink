#!/usr/bin/env bats
# Unit tests for environment variable fallback
# Priority: P0 (Critical) - Run on every commit
# Focus: Validates setup.sh environment variable fallback when CLI args not provided

load '../test_helper/common'

# Setup runs before each test
setup() {
    TEST_TEMP_DIR="$(mktemp -d)"
    echo "Created temp dir: $TEST_TEMP_DIR" >&3
    
    # Create mock git to prevent actual cloning
    export PATH="$TEST_TEMP_DIR:$PATH"
    cat > "$TEST_TEMP_DIR/git" << 'EOF'
#!/bin/bash
# Mock git that creates directory and succeeds
if [[ "$*" == *"clone"* ]]; then
    # Extract the target directory (last argument)
    target="${@: -1}"
    mkdir -p "$target"
    echo '#!/bin/bash' > "$target/setup_kaggle_zrok.sh"
    echo '#!/bin/bash' > "$target/start_zrok.sh"
    chmod +x "$target/setup_kaggle_zrok.sh" "$target/start_zrok.sh"
    exit 0
fi
# For any other git command, just succeed
exit 0
EOF
    chmod +x "$TEST_TEMP_DIR/git"
    
    export TEST_TEMP_DIR
}

# Teardown runs after each test
teardown() {
    if [ -n "$TEST_TEMP_DIR" ] && [ -d "$TEST_TEMP_DIR" ]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
    unset KAGGLELINK_KEYS_URL
    unset KAGGLELINK_TOKEN
}

# =============================================================================
# Environment Variable Fallback Tests
# =============================================================================

@test "P0: should use KAGGLELINK_KEYS_URL when -k not provided" {
    export KAGGLELINK_KEYS_URL="https://example.com/keys"
    export KAGGLELINK_TOKEN="test-token"
    
    run bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -eq 0 ]
}

@test "P0: should use KAGGLELINK_TOKEN when -t not provided" {
    export KAGGLELINK_KEYS_URL="https://example.com/keys"
    export KAGGLELINK_TOKEN="test-token"
    
    run bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -eq 0 ]
}

@test "P0: should use both environment variables when no CLI args provided" {
    export KAGGLELINK_KEYS_URL="https://example.com/keys"
    export KAGGLELINK_TOKEN="test-token"
    
    run bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -eq 0 ]
}

@test "P0: CLI args should override environment variables (keys URL)" {
    export KAGGLELINK_KEYS_URL="https://env.com/keys"
    export KAGGLELINK_TOKEN="env-token"
    
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://cli.com/keys" -t "cli-token"
    [ "$status" -eq 0 ]
    # Verify CLI values are actually used by checking source logging
    [[ "$output" == *"Using keys URL from: CLI argument"* ]]
    [[ "$output" == *"Using token from: CLI argument"* ]]
}

@test "P0: should fail when both CLI and env are missing (keys URL)" {
    run env -u KAGGLELINK_KEYS_URL KAGGLELINK_TOKEN="test-token" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"key"* ]] || [[ "$output" == *"URL"* ]]
}

@test "P0: should fail when both CLI and env are missing (token)" {
    run env -u KAGGLELINK_TOKEN KAGGLELINK_KEYS_URL="https://example.com/keys" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"token"* ]]
}

@test "P1: error message should be clear when keys URL is missing" {
    run env -u KAGGLELINK_KEYS_URL KAGGLELINK_TOKEN="test-token" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    # Check for actionable error message
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"required"* ]]
}

@test "P1: error message should be clear when token is missing" {
    run env -u KAGGLELINK_TOKEN KAGGLELINK_KEYS_URL="https://example.com/keys" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    # Check for actionable error message
    [[ "$output" == *"Error"* ]] || [[ "$output" == *"required"* ]]
}

# =============================================================================
# Configuration Source Logging Tests (AC4)
# =============================================================================

@test "P0: should log CLI source when -k provided" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://example.com/keys" -t "test-token"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Using keys URL from: CLI argument"* ]]
}

@test "P0: should log CLI source when -t provided" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://example.com/keys" -t "test-token"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Using token from: CLI argument"* ]]
}

@test "P0: should log env var source when KAGGLELINK_KEYS_URL used" {
    export KAGGLELINK_KEYS_URL="https://example.com/keys"
    export KAGGLELINK_TOKEN="test-token"
    
    run bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Using keys URL from: KAGGLELINK_KEYS_URL env var"* ]]
}

@test "P0: should log env var source when KAGGLELINK_TOKEN used" {
    export KAGGLELINK_KEYS_URL="https://example.com/keys"
    export KAGGLELINK_TOKEN="test-token"
    
    run bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Using token from: KAGGLELINK_TOKEN env var"* ]]
}

@test "P0: should log CLI source when both CLI and env var provided" {
    export KAGGLELINK_KEYS_URL="https://env.com/keys"
    export KAGGLELINK_TOKEN="env-token"
    
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://cli.com/keys" -t "cli-token"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Using keys URL from: CLI argument"* ]]
    [[ "$output" == *"Using token from: CLI argument"* ]]
}

# =============================================================================
# Improved Error Messages Tests (AC5)
# =============================================================================

@test "P0: error message mentions both -k flag AND KAGGLELINK_KEYS_URL env var" {
    run env -u KAGGLELINK_KEYS_URL KAGGLELINK_TOKEN="test-token" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"-k"* ]] || [[ "$output" == *"--keys-url"* ]]
    [[ "$output" == *"KAGGLELINK_KEYS_URL"* ]]
}

@test "P0: error message mentions both -t flag AND KAGGLELINK_TOKEN env var" {
    run env -u KAGGLELINK_TOKEN KAGGLELINK_KEYS_URL="https://example.com/keys" PATH="$TEST_TEMP_DIR:$PATH" bash "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"-t"* ]] || [[ "$output" == *"--token"* ]]
    [[ "$output" == *"KAGGLELINK_TOKEN"* ]]
}

@test "P0: usage output includes environment variable documentation" {
    run bash "${PROJECT_ROOT}/setup.sh" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"KAGGLELINK_KEYS_URL"* ]]
    [[ "$output" == *"KAGGLELINK_TOKEN"* ]]
}
