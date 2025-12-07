# KaggleLink Test Suite

**Framework:** bats-core (Bash Automated Testing System)  
**Test Environment:** Docker-isolated containers  
**Last Updated:** 2025-12-07

---

## Overview

This test suite validates the KaggleLink shell scripts for reliability, idempotency, and security. The testing strategy follows a three-layer approach with **Docker-isolated test execution** to prevent developer machine contamination.

| Level | Tool | Environment | Focus | Coverage |
|-------|------|-------------|-------|----------|
| Unit | bats-core | Docker container | Function validation, argument parsing | 30% |
| Integration | bats-core + sshd | Docker container | Script components, SSH setup | 40% |
| E2E | GitHub Actions | Kaggle notebook | Full setup flow | 30% |

---

## Quick Start

### Prerequisites

**Docker-based testing (Recommended):**
```bash
# Install Docker and Docker Compose
# macOS: Install Docker Desktop
# Linux: Install docker.io and docker-compose
# Windows: Install Docker Desktop with WSL2
```

**Legacy bare-metal testing (Not recommended):**
```bash
# Install bats-core
# Arch Linux
sudo pacman -S bats shellcheck bats-support bats-assert bats-file

# macOS
brew install bats-core shellcheck

# Ubuntu/Debian
sudo apt-get install bats shellcheck
```

### Docker-Based Testing (Recommended)

Run tests in isolated Docker container matching Kaggle's Debian environment:

```bash
# Run all tests (unit + integration)
docker-compose -f docker-compose.test.yml run --rm test

# Run only unit tests
docker-compose -f docker-compose.test.yml run --rm test bats tests/unit/*.bats

# Run only integration tests
docker-compose -f docker-compose.test.yml run --rm test bats tests/integration/*.bats

# Run shellcheck
docker-compose -f docker-compose.test.yml run --rm test shellcheck *.sh

# Interactive debugging
docker-compose -f docker-compose.test.yml run --rm test bash
```

**Benefits:**
- ✅ No sudo pollution on your machine
- ✅ Works with any shell (fish, zsh, bash)
- ✅ Identical environment to CI/CD
- ✅ True isolation for idempotency testing

### Legacy Bare-Metal Testing

**⚠️ Warning:** Running tests on bare metal can modify your system (SSH configs, environment variables). Use Docker instead.

### Install Test Helpers (Non-Arch systems, bare-metal only)

On Arch Linux, the helpers are installed system-wide via pacman. On other systems:

On Arch Linux, the helpers are installed system-wide via pacman. On other systems:

```bash
# bats-support - Common assertions
git clone https://github.com/bats-core/bats-support.git tests/test_helper/bats-support

# bats-assert - Additional assertions
git clone https://github.com/bats-core/bats-assert.git tests/test_helper/bats-assert

# bats-file - File assertions
git clone https://github.com/bats-core/bats-file.git tests/test_helper/bats-file
```

### Running Tests

```bash
# Run all tests
bats tests/

# Run specific test file
bats tests/unit/test_argument_parsing.bats

# Run with verbose output
bats --verbose-run tests/

# Run in parallel (faster)
bats --jobs 4 tests/

# Generate TAP output for CI
bats --formatter tap tests/ > test-results.tap
```

---

## Directory Structure

```
tests/
├── README.md                      # This file
├── test_helper/                   # Shared test utilities
│   ├── common.bash                # Common setup/teardown functions
│   ├── mocks.bash                 # Mock functions for external commands
│   └── bats-support/              # bats-support library (git clone)
│   └── bats-assert/               # bats-assert library (git clone)
├── unit/                          # Unit tests (fast, isolated)
│   ├── test_argument_parsing.bats # CLI argument validation
│   ├── test_env_fallback.bats     # Environment variable fallback logic
│   ├── test_env_filtering.bats    # Environment variable filtering & quote escaping
│   ├── test_security.bats         # Security requirements (tokens, private shares)
│   ├── test_ssh_permissions.bats  # SSH file permission validation  
│   ├── test_url_validation.bats   # URL format and HTTPS enforcement
│   └── test_version_tracking.bats # Version display and branch management
├── integration/                   # Integration tests (Docker)
│   ├── test_idempotency.bats      # Re-run safety
│   └── fixtures/                  # Test data and configs
│       └── sample_authorized_keys
└── e2e/                           # End-to-end tests
    └── canary_notebook.py         # Kaggle canary execution
```

---

## Test Patterns

### Unit Test Example

```bash
#!/usr/bin/env bats

# Load test helpers
load '../test_helper/common'

# Setup runs before each test
setup() {
    # Source the script functions (requires function extraction)
    source "${BATS_TEST_DIRNAME}/../../setup.sh" --source-only 2>/dev/null || true
}

@test "should reject missing --keys-url argument" {
    run ./setup.sh -t "test-token"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "should reject invalid URL scheme (http instead of https)" {
    run ./setup.sh -k "http://example.com/keys" -t "test-token"
    [ "$status" -eq 1 ]
    [[ "$output" == *"https"* ]]
}

@test "should accept valid arguments" {
    # Mock git and sub-scripts to prevent actual execution
    function git() { echo "mocked"; }
    export -f git
    
    run ./setup.sh -k "https://example.com/keys" -t "test-token" --dry-run
    [ "$status" -eq 0 ]
}
```

### Integration Test Example

```bash
#!/usr/bin/env bats

load '../test_helper/common'

# Use Docker for integration tests
setup_file() {
    # Build test container (once per file)
    docker build -t kagglelink-test -f tests/integration/Dockerfile .
}

setup() {
    # Start fresh container for each test
    TEST_CONTAINER=$(docker run -d kagglelink-test sleep infinity)
}

teardown() {
    # Cleanup container
    docker rm -f "$TEST_CONTAINER" 2>/dev/null || true
}

@test "SSH directory setup creates correct permissions" {
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only
        setup_ssh_directory 'https://example.com/keys'
    "
    
    # Verify permissions
    run docker exec "$TEST_CONTAINER" stat -c '%a' /root/.ssh
    [ "$output" = "700" ]
    
    run docker exec "$TEST_CONTAINER" stat -c '%a' /root/.ssh/authorized_keys
    [ "$output" = "600" ]
}

@test "SSHD config is idempotent" {
    # Run twice
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only
        configure_sshd
        configure_sshd
    "
    
    # Count marker occurrences (should be exactly 1)
    run docker exec "$TEST_CONTAINER" grep -c "BEGIN KAGGLELINK CONFIG" /etc/ssh/sshd_config
    [ "$output" = "1" ]
}
```

---

## Test Categories & Priorities

### P0 (Critical) - Run on Every Commit

| Test | Focus | File |
|------|-------|------|
| Argument parsing | CLI validation | `unit/test_argument_parsing.bats` |
| Private tunnel enforcement | Security | `unit/test_security.bats` |
| Token not in output | Security | `unit/test_security.bats` |

### P1 (High) - Run on PR

| Test | Focus | File |
|------|-------|------|
| SSH setup permissions | File security | `integration/test_ssh_setup.bats` |
| SSHD config idempotency | Reliability | `integration/test_idempotency.bats` |
| Package installation | Setup flow | `integration/test_package_install.bats` |

### P2 (Medium) - Run Nightly

| Test | Focus | File |
|------|-------|------|
| Full setup timing | Performance | `integration/test_performance.bats` |
| Environment variable export | Setup flow | `integration/test_env_export.bats` |

---

## Testing Patterns & Best Practices

### Environment Variable Filtering Tests

When testing functions that filter and export environment variables:

**Challenge:** Can't source scripts that require arguments  
**Solution:** Extract logic into standalone test helper script

```bash
# In setup()
cat > "${TEST_TEMP_DIR}/filter_env.sh" <<'EOF'
#!/bin/bash
TEST_BASHRC="$1"
printenv | while IFS='=' read -r key value; do
    if [[ "$key" =~ ^(PWD|BASH_|BATS_)$ ]]; then
        continue
    fi
    escaped=$(printf "%s" "$value" | sed "s/'/'\\''/g")
    echo "export ${key}='${escaped}'" >> "$TEST_BASHRC"
done
EOF
chmod +x "${TEST_TEMP_DIR}/filter_env.sh"

# In tests
bash "${TEST_TEMP_DIR}/filter_env.sh" "${TEST_BASHRC}"
```

**Key Learnings:**
- Always filter out `BASH_*` and `BATS_*` variables to prevent function exports
- Test both filtering (what's excluded) AND inclusion (what's kept)
- Verify generated exports are valid bash syntax: `bash -c "source file"`

### Quote Escaping Tests

Single quotes in bash strings require special handling:

```bash
# The sed pattern for escaping single quotes
escaped_value=$(printf "%s" "$value" | sed "s/'/'\\''/g")
echo "export VAR='${escaped_value}'"

# Transforms: has 'quote'
# Into: export VAR='has '\''quote'\'''
```

**Testing Strategy:**
- Don't test the exact escape pattern (implementation detail)
- Test that bash can source the result without errors
- Test edge cases: `'`, `"`, `$`, `\`, spaces, newlines

### SSH Permission Tests

**Use actual file operations, not grep:**

```bash
# ❌ Bad: Only checks if code exists
grep "chmod 700" script.sh

# ✅ Good: Validates actual behavior
mkdir -p "$TEST_DIR/.ssh"
chmod 700 "$TEST_DIR/.ssh"
actual=$(stat -c '%a' "$TEST_DIR/.ssh")
[ "$actual" = "700" ]
```

**Permission Testing Checklist:**
- Create files/dirs in TEST_TEMP_DIR
- Set permissions with chmod
- Verify with `stat -c '%a'` (octal) or `stat -c '%A'` (symbolic)
- Test repair scenarios (fix incorrect perms)

### Mocking Patterns

**Available Mocks (from test_helper/common.bash):**

```bash
# Mock HTTP requests
mock_curl()
curl() { echo "MOCKED_RESPONSE"; return 0; }

# Mock git operations
mock_git()
git() {
    case "$1" in
        clone) mkdir -p "$3"; echo "MOCKED_CLONE" ;;
        *) command git "$@" ;;
    esac
}

# Mock package management
mock_apt_get()
apt_get() { echo "MOCKED_APT: $*"; return 0; }

# Cleanup all mocks
restore_mocks()
```

**Creating New Mocks:**

```bash
# In test_helper/common.bash
mock_zrok() {
    zrok() {
        case "$1" in
            enable) echo "MOCK: zrok enabled" ;;
            disable) echo "MOCK: zrok disabled" ;;
            status) echo "MOCK: environment enabled" ;;
            share) echo "MOCK: tunnel started" ;;
        esac
        return 0
    }
    export -f zrok
}
```

### Test Isolation Best Practices

**Always use TEST_TEMP_DIR:**

```bash
setup() {
    create_test_dir  # Creates TEST_TEMP_DIR
    export TEST_FILE="${TEST_TEMP_DIR}/test.conf"
}

teardown() {
    cleanup_test_dir  # Removes TEST_TEMP_DIR
    restore_mocks
}
```

**Common Pitfalls:**
- ❌ Writing to `/tmp` directly (collisions between tests)
- ❌ Not cleaning up mocked functions
- ❌ Relying on test execution order
- ✅ Each test creates/destroys its own resources
- ✅ Use `setup()` and `teardown()` consistently

### Debugging Failing Tests

```bash
# Run single test with verbose output
bats -f "test name" tests/unit/test_file.bats

# Add debug output (visible with --tap)
echo "Debug: value=$value" >&3

# TAP output shows all diagnostic messages
bats --tap tests/unit/test_file.bats

# Check what's actually in generated files
@test "example" {
    run some_command
    echo "Output: $output" >&3
    cat "$TEST_FILE" >&3
}
```

### Testing Functions from Scripts That Require Arguments

**Problem:** `source script.sh` fails if script checks `$#` or `$1`

**Solutions:**

1. **Extract function to test file** (used in test_env_filtering.bats)
2. **Conditional sourcing:**
   ```bash
   # In script
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
       # Only run main logic if executed, not sourced
       main "$@"
   fi
   ```
3. **Use `--source-only` flag** (requires script modification)

### Quote Escaping Reference

| Input | Escaped Output | Notes |
|-------|----------------|-------|
| `simple` | `export VAR='simple'` | No escaping needed |
| `has 'quote'` | `export VAR='has '\''quote'\''` | Close quote, escape, reopen |
| `has "double"` | `export VAR='has "double"'` | Double quotes safe in single quotes |
| `has $var` | `export VAR='has $var'` | Dollar signs safe in single quotes |
| `has \slash` | `export VAR='has \slash'` | Backslashes safe in single quotes |

---

##  Integration

### GitHub Actions Workflow

See `.github/workflows/test.yml` for the CI configuration.

```yaml
# Runs on: push, pull_request
# Jobs: lint (shellcheck), unit-tests, integration-tests
```

### Running Locally Before Push

```bash
# Quick validation (unit tests only)
bats tests/unit/

# Full local validation
shellcheck *.sh
bats tests/unit/ tests/integration/
```

---

## Writing New Tests

### Guidelines

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up created resources in teardown
3. **Mocking**: Mock external commands (git, curl, apt-get) in unit tests
4. **Naming**: Use descriptive test names: `@test "should X when Y"`
5. **Assertions**: Use bats-assert for cleaner assertions

### Test File Template

```bash
#!/usr/bin/env bats

# Description: Tests for [component]
# Priority: P0/P1/P2
# Category: unit/integration

load '../test_helper/common'

setup() {
    # Test setup
}

teardown() {
    # Cleanup
}

@test "should [expected behavior] when [condition]" {
    # Arrange
    
    # Act
    run [command]
    
    # Assert
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

---

## Coverage Tracking

Current test coverage:

| Script | Lines | Unit Tests | Coverage | Notes |
|--------|-------|------------|----------|-------|
| `setup.sh` | 75 | 24 tests | ~85% | Argument parsing, env fallback, URL validation, git operations |
| `setup_kaggle_zrok.sh` | 225 | 18 tests | ~35% | Env filtering, SSH permissions (AC2-AC3 deferred to Epic 2) |
| `start_zrok.sh` | 40 | 3 tests | ~40% | Security checks only (tunnel management tests deferred to Epic 3) |
| `install_extensions.sh` | 15 | 0 tests | 0% | Optional functionality, low priority |

**Total Unit Tests:** 76 tests  
**Overall Coverage:** ~70% of critical paths

**Technical Debt (Planned before Epic 2):**
- SSHD configuration idempotency tests
- Environment variable export integration tests
- SSH permission repair edge cases

**Technical Debt (Planned before Epic 3):**
- Zrok tunnel management tests (enable/disable/status)
- Cleanup trap comprehensive testing
- Tunnel reconnection scenarios

---

## Troubleshooting

### Common Issues

**"bats: command not found"**
```bash
# Ensure bats is in PATH or use full path
/usr/local/bin/bats tests/
```

**Tests hang on Docker operations**
```bash
# Ensure Docker is running
docker info

# Check for orphaned containers
docker ps -a | grep kagglelink-test
```

**"source: not found" errors**
```bash
# Ensure scripts use bash shebang
head -1 setup.sh  # Should be: #!/bin/bash
```

---

## References

- [bats-core Documentation](https://bats-core.readthedocs.io/)
- [KaggleLink Test Design](../docs/test-design-system.md)
- [Shellcheck](https://www.shellcheck.net/) - Static analysis for shell scripts
