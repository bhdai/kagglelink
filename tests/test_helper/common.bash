#!/bin/bash
# Common test helper functions for bats tests
# Source this file in your test setup

# Get the project root directory
export PROJECT_ROOT="${BATS_TEST_DIRNAME}/../.."

# Colors for output (disabled in CI)
if [[ -z "$CI" ]]; then
    export RED='\033[0;31m'
    export GREEN='\033[0;32m'
    export YELLOW='\033[0;33m'
    export NC='\033[0m' # No Color
else
    export RED=''
    export GREEN=''
    export YELLOW=''
    export NC=''
fi

# Load bats helper libraries if available
load_bats_helpers() {
    # Try system locations first (Arch Linux: /usr/lib/bats-*)
    if [[ -d "/usr/lib/bats-support" ]]; then
        load "/usr/lib/bats-support/load"
    elif [[ -d "${BATS_TEST_DIRNAME}/../test_helper/bats-support" ]]; then
        load "${BATS_TEST_DIRNAME}/../test_helper/bats-support/load"
    fi
    
    if [[ -d "/usr/lib/bats-assert" ]]; then
        load "/usr/lib/bats-assert/load"
    elif [[ -d "${BATS_TEST_DIRNAME}/../test_helper/bats-assert" ]]; then
        load "${BATS_TEST_DIRNAME}/../test_helper/bats-assert/load"
    fi
    
    if [[ -d "/usr/lib/bats-file" ]]; then
        load "/usr/lib/bats-file/load"
    elif [[ -d "${BATS_TEST_DIRNAME}/../test_helper/bats-file" ]]; then
        load "${BATS_TEST_DIRNAME}/../test_helper/bats-file/load"
    fi
}

# Create a temporary directory for test artifacts
create_test_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    export TEST_TEMP_DIR="$temp_dir"
    echo "Created temp dir: $TEST_TEMP_DIR" >&3
}

# Cleanup temporary directory
cleanup_test_dir() {
    if [[ -n "$TEST_TEMP_DIR" && -d "$TEST_TEMP_DIR" ]]; then
        rm -rf "$TEST_TEMP_DIR"
    fi
}

# Skip test if not running in Docker
skip_if_not_docker() {
    if [[ ! -f /.dockerenv ]]; then
        skip "This test requires Docker environment"
    fi
}

# Skip test if Docker is not available
skip_if_no_docker() {
    if ! command -v docker &> /dev/null; then
        skip "Docker is not installed"
    fi
    if ! docker info &> /dev/null; then
        skip "Docker is not running"
    fi
}

# Assert that a file exists with specific permissions
assert_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    
    if [[ ! -e "$file" ]]; then
        echo "File does not exist: $file" >&2
        return 1
    fi
    
    local actual_perms
    actual_perms=$(stat -c '%a' "$file" 2>/dev/null || stat -f '%Lp' "$file" 2>/dev/null)
    if [[ "$actual_perms" != "$expected_perms" ]]; then
        echo "Permission mismatch for $file: expected $expected_perms, got $actual_perms" >&2
        return 1
    fi
}

# Assert that output does not contain sensitive patterns (tokens, passwords)
assert_no_secrets_in_output() {
    local output="$1"
    
    # Check for common secret patterns
    # Zrok tokens typically look like: zrok_xxxxx
    if echo "$output" | grep -qE 'zrok_[A-Za-z0-9]{20,}'; then
        echo "ERROR: Output contains potential Zrok token!" >&2
        return 1
    fi
    
    # Check for SSH private key markers
    if echo "$output" | grep -q "PRIVATE KEY"; then
        echo "ERROR: Output contains private key!" >&2
        return 1
    fi
    
    return 0
}

# Wait for a condition with timeout
wait_for() {
    local condition="$1"
    local timeout="${2:-30}"
    local interval="${3:-1}"
    
    local elapsed=0
    while ! eval "$condition"; do
        sleep "$interval"
        elapsed=$((elapsed + interval))
        if [[ $elapsed -ge $timeout ]]; then
            echo "Timeout waiting for: $condition" >&2
            return 1
        fi
    done
    return 0
}

# Mock curl for tests that shouldn't make real HTTP requests
mock_curl() {
    curl() {
        echo "MOCKED_CURL_RESPONSE"
        return 0
    }
    export -f curl
}

# Mock git for tests that shouldn't clone repositories
mock_git() {
    git() {
        case "$1" in
            clone)
                mkdir -p "$3"
                echo "MOCKED_GIT_CLONE"
                return 0
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
}

# Mock apt-get for tests that shouldn't install packages
mock_apt_get() {
    apt-get() {
        echo "MOCKED_APT_GET: $*"
        return 0
    }
    export -f apt-get
}

# Restore all mocks
restore_mocks() {
    unset -f curl git apt-get 2>/dev/null || true
}

# Print test context for debugging
debug_context() {
    echo "=== Debug Context ===" >&3
    echo "BATS_TEST_NAME: $BATS_TEST_NAME" >&3
    echo "BATS_TEST_FILENAME: $BATS_TEST_FILENAME" >&3
    echo "PROJECT_ROOT: $PROJECT_ROOT" >&3
    echo "PWD: $PWD" >&3
    echo "===================" >&3
}
