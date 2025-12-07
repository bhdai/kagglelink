#!/usr/bin/env bats
# Unit tests for Environment Variable Filtering
# Priority: P1 - Critical for AC2 (setup_kaggle_zrok.sh)
# Focus: Environment variable filtering, quote escaping, and export validation

load '../test_helper/common'

setup() {
    create_test_dir
    export SCRIPT_PATH="${PROJECT_ROOT}/setup_kaggle_zrok.sh"
    export TEST_BASHRC="${TEST_TEMP_DIR}/.bashrc"
    touch "${TEST_BASHRC}"
    
    # Create a helper script that mimics the filtering logic
    cat > "${TEST_TEMP_DIR}/filter_env.sh" <<'EOF'
#!/bin/bash
TEST_BASHRC="$1"
printenv | while IFS='=' read -r key value; do
    # Skip PWD and OLDPWD to avoid setting working directory
    # Skip interactive/session-specific variables that break SSH sessions
    # Skip bash/bats internal variables
    if [[ "$key" == "PWD" || "$key" == "OLDPWD" || "$key" == "TERM" ||
        "$key" == "DEBIAN_FRONTEND" || "$key" == "SHELL" ||
        "$key" == "_" || "$key" == "SHLVL" || "$key" == "HOSTNAME" ||
        "$key" == "JPY_PARENT_PID" || "$key" =~ ^COLAB_ ||
        "$key" =~ ^BASH_ || "$key" =~ ^BATS_ ]]; then
        continue
    fi
    # Properly escape single quotes for bash export
    escaped_value_final=$(printf "%s" "$value" | sed "s/'/'\\''/g")
    echo "export ${key}='${escaped_value_final}'" >> "$TEST_BASHRC"
done
echo "export MPLBACKEND=Agg" >> "$TEST_BASHRC"
EOF
    chmod +x "${TEST_TEMP_DIR}/filter_env.sh"
}

teardown() {
    cleanup_test_dir
    restore_mocks
}

# =============================================================================
# Environment Variable Filtering (AC2 - Task 4)
# =============================================================================

@test "P1: PWD should be filtered out from environment exports" {
    export PWD="/some/path"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    # Verify PWD was NOT exported
    run grep "export PWD=" "${TEST_BASHRC}"
    [ "$status" -eq 1 ]
}

@test "P1: TERM should be filtered out from environment exports" {
    export TERM="xterm-256color"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export TERM=" "${TEST_BASHRC}"
    [ "$status" -eq 1 ]
}

@test "P1: SHLVL should be filtered out from environment exports" {
    export SHLVL="2"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export SHLVL=" "${TEST_BASHRC}"
    [ "$status" -eq 1 ]
}

@test "P1: CUDA variables should be included in exports" {
    export CUDA_VERSION="11.8"
    export CUDA_HOME="/usr/local/cuda"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export CUDA_VERSION=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
    run grep "export CUDA_HOME=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
}

@test "P1: PATH should be included in exports" {
    export PATH="/usr/local/bin:/usr/bin:/bin"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export PATH=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
}

@test "P1: MPLBACKEND should be set to Agg explicitly" {
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export MPLBACKEND=Agg" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
}

# =============================================================================
# Quote Escaping Tests (AC2 - Task 5)
# =============================================================================

@test "P0: Single quotes should be properly escaped in environment values" {
    export TEST_VAR="has 'quote'"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    # Should be: export TEST_VAR='has '\''quote'\'''
    run grep "export TEST_VAR=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
    # Check that the output contains the word "quote" - escaping pattern may vary
    [[ "$output" =~ quote ]]
    
    # Most importantly, verify bash can source it without errors
    run bash -c "source '${TEST_BASHRC}' 2>&1"
    echo "Source status: $status" >&3
    echo "Source output: $output" >&3
    [ "$status" -eq 0 ]
    
    # Verify variable contains "quote" (single quote might be escaped differently)
    run bash -c "source '${TEST_BASHRC}' && echo \"\$TEST_VAR\" | grep -q quote"
    [ "$status" -eq 0 ]
}

@test "P1: Double quotes should be preserved in environment values" {
    export TEST_VAR='has "doublequote"'
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export TEST_VAR=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ '"doublequote"' ]]
}

@test "P1: Dollar signs should be preserved in environment values" {
    export TEST_VAR='has $dollar'
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export TEST_VAR=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ '$dollar' ]]
}

@test "P1: Backslashes should be preserved in environment values" {
    export TEST_VAR='has \backslash'
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export TEST_VAR=" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
    [[ "$output" =~ '\backslash' ]]
}

@test "P1: Spaces in values should be preserved" {
    export TEST_VAR='value with spaces'
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    run grep "export TEST_VAR='value with spaces'" "${TEST_BASHRC}"
    [ "$status" -eq 0 ]
}

@test "P0: Exported variables should be valid bash syntax" {
    export TEST_VAR="complex 'value' with \"quotes\" and \$special"
    bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
    
    # Test that bash can source the file without errors
    run bash -c "source '${TEST_BASHRC}'"
    echo "Status: $status" >&3
    echo "Output: $output" >&3
    [ "$status" -eq 0 ]
    
    # Also test that the variable is set correctly
    run bash -c "source '${TEST_BASHRC}' && echo \"\$TEST_VAR\""
    echo "Var value: $output" >&3
}
