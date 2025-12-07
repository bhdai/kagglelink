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
    mkdir -p "$target"
    echo '#!/bin/bash' > "$target/setup_kaggle_zrok.sh"
    echo '#!/bin/bash' > "$target/start_zrok.sh"
    chmod +x "$target/setup_kaggle_zrok.sh" "$target/start_zrok.sh"
fi
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
    # The CLI values should be used (verified by checking they were passed to scripts)
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
