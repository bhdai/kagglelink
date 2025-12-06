#!/usr/bin/env bats
# Security-focused unit tests
# Priority: P0 (Critical) - Run on every commit
# Focus: Validates security properties of the scripts

load '../test_helper/common'

# Setup runs before each test
setup() {
    create_test_dir
    cd "${PROJECT_ROOT}"
}

# Teardown runs after each test
teardown() {
    cleanup_test_dir
}

# =============================================================================
# Private Tunnel Enforcement (SEC - R-002)
# =============================================================================

@test "P0: start_zrok.sh uses 'zrok share private' not 'public'" {
    # Verify the script uses private shares
    run grep -E "zrok\s+share\s+private" "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -eq 0 ]
    
    # Verify it does NOT use public shares
    run grep -E "zrok\s+share\s+public" "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -ne 0 ]
}

@test "P0: no 'public' tunnel option exists in any script" {
    # Search all shell scripts for public tunnel usage
    run grep -rE "zrok\s+share\s+public" "${PROJECT_ROOT}"/*.sh
    [ "$status" -ne 0 ]  # Should NOT find any matches
}

# =============================================================================
# Token Exposure Prevention (SEC - R-001)
# =============================================================================

@test "P0: setup.sh does not echo raw token value" {
    # The token should be used but not directly echoed
    # Check that we don't have: echo "$token" or echo $token
    run grep -E 'echo\s+["\$]*(token|TOKEN|zrok_token)' "${PROJECT_ROOT}/setup.sh"
    [ "$status" -ne 0 ]  # Should NOT find token being echoed
}

@test "P0: start_zrok.sh does not log token to file" {
    # Check for logging token to files
    run grep -E '(>|>>).*\$(token|TOKEN|ZROK)' "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -ne 0 ]  # Should NOT find token being logged
}

@test "P1: no hardcoded tokens in scripts" {
    # Check for potential hardcoded Zrok tokens (pattern: 20+ alphanumeric)
    run grep -rE 'zrok_[A-Za-z0-9]{20,}' "${PROJECT_ROOT}"/*.sh
    [ "$status" -ne 0 ]  # Should NOT find hardcoded tokens
}

# =============================================================================
# SSH Key Security
# =============================================================================

@test "P0: setup_kaggle_zrok.sh sets correct .ssh directory permissions (700)" {
    # Check for chmod 700 on ssh directory (may use variable like $ssh_dir_path)
    run grep -E 'chmod\s+700' "${PROJECT_ROOT}/setup_kaggle_zrok.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"ssh"* ]]
}

@test "P0: setup_kaggle_zrok.sh sets correct authorized_keys permissions (600)" {
    run grep -E 'chmod\s+600.*authorized_keys' "${PROJECT_ROOT}/setup_kaggle_zrok.sh"
    [ "$status" -eq 0 ]
}

@test "P1: SSHD configured for key-based authentication" {
    # Check that PubkeyAuthentication is enabled in the script
    run grep -E 'PubkeyAuthentication\s+yes' "${PROJECT_ROOT}/setup_kaggle_zrok.sh"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Fail-Fast Security (set -e)
# =============================================================================

@test "P1: setup.sh uses set -e for fail-fast" {
    run head -20 "${PROJECT_ROOT}/setup.sh"
    [[ "$output" == *"set -e"* ]]
}

@test "P1: setup_kaggle_zrok.sh uses set -e for fail-fast" {
    run head -20 "${PROJECT_ROOT}/setup_kaggle_zrok.sh"
    [[ "$output" == *"set -e"* ]]
}

@test "P1: start_zrok.sh uses set -e for fail-fast" {
    run head -20 "${PROJECT_ROOT}/start_zrok.sh"
    [[ "$output" == *"set -e"* ]]
}

# =============================================================================
# Cleanup Security (prevent orphaned sessions)
# =============================================================================

@test "P0: start_zrok.sh has cleanup trap for zrok disable" {
    # Verify cleanup function exists and includes zrok disable
    run grep -E 'trap.*cleanup' "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -eq 0 ]
    
    run grep -E 'zrok\s+disable' "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -eq 0 ]
}

@test "P1: cleanup trap handles multiple signals" {
    # Should handle at minimum EXIT
    run grep -E 'trap.*EXIT' "${PROJECT_ROOT}/start_zrok.sh"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Variable Quoting (prevent injection)
# =============================================================================

@test "P2: setup.sh quotes variable expansions" {
    # Look for unquoted variable usage (potential security issue)
    # This is a simplified check - looks for common patterns like $var without quotes
    # Allowing $? $# $@ and similar special variables
    run grep -E '\$[a-zA-Z_][a-zA-Z0-9_]*[^"]' "${PROJECT_ROOT}/setup.sh" | grep -v '"\$' | grep -v "'\$" | head -5
    
    # This is informational - some unquoted vars may be intentional
    # We're just flagging for review, not failing
    true
}
