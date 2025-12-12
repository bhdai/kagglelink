#!/usr/bin/env bats
# Unit tests for URL validation
# Priority: P0 (Critical) - Run on every commit
# Focus: Validates setup.sh enforces HTTPS for security

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
    target="${@: -1}"
    mkdir -p "$target"
    # Copy logging_utils.sh to mocked repo directory
    cp /workspace/logging_utils.sh "$target/" 2>/dev/null || true
    echo '#!/bin/bash' > "$target/setup_kaggle_zrok.sh"
    echo 'source "$(dirname "$0")/logging_utils.sh" 2>/dev/null || true' >> "$target/setup_kaggle_zrok.sh"
    echo 'exit 0' >> "$target/setup_kaggle_zrok.sh"
    echo '#!/bin/bash' > "$target/start_zrok.sh"
    echo 'source "$(dirname "$0")/logging_utils.sh" 2>/dev/null || true' >> "$target/start_zrok.sh"
    echo 'exit 0' >> "$target/start_zrok.sh"
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
# HTTPS URL Validation Tests
# =============================================================================

@test "P0: should accept HTTPS URLs for keys" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://example.com/keys" -t "test-token"
    [ "$status" -eq 0 ]
}

@test "P0: should reject HTTP URLs for keys with security warning" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "http://example.com/keys" -t "test-token"
    [ "$status" -ne 0 ]
    [[ "$output" == *"HTTPS"* ]] || [[ "$output" == *"secure"* ]] || [[ "$output" == *"HTTP"* ]]
}

@test "P0: should reject malformed URLs" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "not-a-url" -t "test-token"
    [ "$status" -ne 0 ]
}

@test "P0: should reject empty URLs" {
    run env -u KAGGLELINK_KEYS_URL bash "${PROJECT_ROOT}/setup.sh" -k "" -t "test-token"
    [ "$status" -ne 0 ]
}

@test "P0: URL validation should run before git clone" {
    # If we pass HTTP URL, it should fail before attempting git clone
    # We can verify this by checking that git was never called
    run bash "${PROJECT_ROOT}/setup.sh" -k "http://example.com/keys" -t "test-token"
    [ "$status" -ne 0 ]
    # Should not see "Cloning repository" message
    [[ "$output" != *"Cloning repository"* ]]
}

@test "P1: error message should explain why HTTP is rejected" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "http://example.com/keys" -t "test-token"
    [ "$status" -ne 0 ]
    # Should have actionable error message (case-insensitive check for ERROR or Error)
    [[ "$output" =~ [Ee][Rr][Rr][Oo][Rr] ]]
    [[ "$output" == *"HTTPS"* ]] || [[ "$output" == *"secure"* ]]
}

@test "P1: should accept HTTPS URLs with ports" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://example.com:8443/keys" -t "test-token"
    [ "$status" -eq 0 ]
}

@test "P1: should accept HTTPS URLs with query parameters" {
    run bash "${PROJECT_ROOT}/setup.sh" -k "https://example.com/keys?version=1" -t "test-token"
    [ "$status" -eq 0 ]
}
