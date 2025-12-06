#!/usr/bin/env bats
# Unit tests for CLI argument parsing
# Priority: P0 (Critical) - Run on every commit
# Focus: Validates setup.sh argument handling

load '../test_helper/common'

# Setup runs before each test
setup() {
    create_test_dir
    # Copy setup.sh to temp dir for isolated testing
    cp "${PROJECT_ROOT}/setup.sh" "${TEST_TEMP_DIR}/"
    cd "${TEST_TEMP_DIR}"
}

# Teardown runs after each test
teardown() {
    cleanup_test_dir
    restore_mocks
}

# =============================================================================
# Missing Argument Tests
# =============================================================================

@test "P0: should show usage when no arguments provided" {
    run bash setup.sh
    [ "$status" -ne 0 ]
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"-k"* ]] || [[ "$output" == *"--keys-url"* ]]
}

@test "P0: should fail when --keys-url is missing" {
    run bash setup.sh -t "test-token"
    [ "$status" -ne 0 ]
}

@test "P0: should fail when --token is missing" {
    run bash setup.sh -k "https://example.com/keys"
    [ "$status" -ne 0 ]
}

# =============================================================================
# Valid Argument Tests
# =============================================================================

@test "P0: should accept short flags (-k, -t)" {
    # Mock external commands to prevent actual execution
    mock_git
    mock_curl
    
    # The script will still fail at some point (git clone), but should parse args first
    run timeout 5 bash setup.sh -k "https://example.com/keys" -t "test-token" 2>&1 || true
    
    # Should not fail on argument parsing (look for specific error messages)
    [[ "$output" != *"Unknown option"* ]]
    [[ "$output" != *"Usage"* ]] || [ "$status" -eq 0 ]
}

@test "P0: should accept long flags (--keys-url, --token)" {
    mock_git
    mock_curl
    
    run timeout 5 bash setup.sh --keys-url "https://example.com/keys" --token "test-token" 2>&1 || true
    
    [[ "$output" != *"Unknown option"* ]]
}

# =============================================================================
# Invalid Argument Tests
# =============================================================================

@test "P1: should reject unknown flags" {
    run bash setup.sh --unknown-flag "value"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Unknown"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "P1: should show help with -h flag" {
    run bash setup.sh -h
    # Help should exit with 0 and show usage
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"-k"* ]] || [[ "$output" == *"help"* ]]
}

@test "P1: should show help with --help flag" {
    run bash setup.sh --help
    [[ "$output" == *"Usage"* ]] || [[ "$output" == *"-k"* ]] || [[ "$output" == *"help"* ]]
}

# =============================================================================
# URL Validation Tests (Future - when URL validation is implemented)
# =============================================================================

@test "P2: should accept HTTPS URLs for keys" {
    skip "URL validation not yet implemented in setup.sh"
    
    mock_git
    mock_curl
    
    run bash setup.sh -k "https://secure.example.com/keys" -t "test-token"
    # Should not fail on URL validation
    [[ "$output" != *"invalid URL"* ]]
}

@test "P2: should reject HTTP URLs for keys (security)" {
    skip "URL validation not yet implemented in setup.sh"
    
    run bash setup.sh -k "http://insecure.example.com/keys" -t "test-token"
    [ "$status" -ne 0 ]
    [[ "$output" == *"https"* ]]
}
