#!/usr/bin/env bats

# Unit Tests for Logging Utilities
# Story: 1-3-unified-logging-and-user-feedback-system
# Tests AC1-3 and AC5

load '../test_helper/common.bash'

setup() {
    # Create temporary test directory
    TEST_TEMP_DIR="$(mktemp -d)"
    
    # Set PROJECT_ROOT for sourcing
    PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_TEMP_DIR"
}

# Task 7.1: Test log_info outputs ⏳ emoji and timestamp
@test "P0: log_info should include ⏳ emoji and timestamp" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run log_info "Test message"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"⏳"* ]]
    [[ "$output" =~ \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
    [[ "$output" == *"Test message"* ]]
}

# Task 7.2: Test log_success outputs ✅ emoji
@test "P0: log_success should include ✅ emoji and timestamp" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run log_success "Operation completed"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅"* ]]
    [[ "$output" =~ \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
    [[ "$output" == *"Operation completed"* ]]
}

# Task 7.3: Test log_error outputs ❌ emoji to stderr
@test "P0: log_error should output ❌ emoji to stderr" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run bash -c "source ${PROJECT_ROOT}/logging_utils.sh; log_error 'Error occurred' 2>&1 1>/dev/null"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"❌"* ]]
    [[ "$output" == *"ERROR:"* ]]
    [[ "$output" == *"Error occurred"* ]]
}

# Task 7.4: Test elapsed time calculation
@test "P0: log_step_start and log_step_complete should calculate elapsed time" {
    # Run in a bash subshell to maintain context between start and complete
    run bash -c "
        source ${PROJECT_ROOT}/logging_utils.sh
        log_step_start 'Test Step' > /dev/null
        sleep 1
        log_step_complete 'Test Step'
    "
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅"* ]]
    [[ "$output" == *"Test Step completed"* ]]
    [[ "$output" =~ \([0-9]+s\) ]]
}

# Test categorize_error function with different types
@test "P0: categorize_error should format prerequisite errors" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run bash -c "source ${PROJECT_ROOT}/logging_utils.sh; categorize_error 'prerequisite' 'git is not installed' 'Install git: apt-get install git' 2>&1"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"❌"* ]]
    [[ "$output" == *"git is not installed"* ]]
    [[ "$output" == *"💡 Action required:"* ]]
    [[ "$output" == *"Install git: apt-get install git"* ]]
}

@test "P0: categorize_error should format network errors" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run bash -c "source ${PROJECT_ROOT}/logging_utils.sh; categorize_error 'network' 'Failed to download keys' 'Check URL is accessible' 2>&1"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"❌"* ]]
    [[ "$output" == *"Failed to download keys"* ]]
    [[ "$output" == *"🌐 Check connectivity:"* ]]
    [[ "$output" == *"Check URL is accessible"* ]]
}

@test "P0: categorize_error should format upstream errors" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    run bash -c "source ${PROJECT_ROOT}/logging_utils.sh; categorize_error 'upstream' 'Zrok API failed' 'Try again later' 2>&1"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"❌"* ]]
    [[ "$output" == *"Zrok API failed"* ]]
    [[ "$output" == *"🔧 Upstream issue:"* ]]
    [[ "$output" == *"Try again later"* ]]
}

# Task 7.5: Test success banner format
@test "P0: show_success_banner should display formatted banner with token" {
    source "${PROJECT_ROOT}/logging_utils.sh"
    
    test_token="abc123xyz"
    run show_success_banner "$test_token"
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ Setup Complete!"* ]]
    [[ "$output" == *"$test_token"* ]]
    [[ "$output" == *"zrok access private $test_token"* ]]
    [[ "$output" == *"ssh -p 9191 root@127.0.0.1"* ]]
    [[ "$output" == *"╔"* ]]  # Box drawing characters
    [[ "$output" == *"╚"* ]]
}
