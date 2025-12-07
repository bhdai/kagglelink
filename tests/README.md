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
│   ├── test_url_validation.bats   # URL format checks
│   └── test_logging.bats          # Log output functions
├── integration/                   # Integration tests (Docker)
│   ├── test_ssh_setup.bats        # SSH directory and config
│   ├── test_package_install.bats  # Apt package installation
│   ├── test_idempotency.bats      # Re-run safety
│   └── fixtures/                  # Test data and configs
│       ├── sample_authorized_keys
│       └── sample_sshd_config
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

## CI Integration

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

Since bats doesn't have built-in coverage, we track coverage manually:

| Script | Unit Tests | Integration Tests | E2E |
|--------|------------|-------------------|-----|
| `setup.sh` | Partial | Planned | Planned |
| `setup_kaggle_zrok.sh` | Planned | Planned | Planned |
| `start_zrok.sh` | Planned | Planned | Planned |
| `install_extensions.sh` | N/A | Planned | N/A |

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
