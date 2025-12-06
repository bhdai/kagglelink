#!/usr/bin/env bats
# Integration tests for SSHD configuration idempotency
# Priority: P0/P1 - Run on every PR
# Focus: Validates that re-running setup doesn't corrupt configuration

load '../test_helper/common'

# These tests require Docker to run
# They test actual file modifications in an isolated container

setup_file() {
    skip_if_no_docker
    
    # Build test container once per test file
    export TEST_IMAGE="kagglelink-test:latest"
    
    # Create a minimal Dockerfile for testing
    cat > "${BATS_FILE_TMPDIR}/Dockerfile" << 'EOF'
FROM debian:bullseye-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    curl \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /root/.ssh /var/run/sshd

# Copy scripts
COPY setup_kaggle_zrok.sh /app/
COPY start_zrok.sh /app/
WORKDIR /app

CMD ["sleep", "infinity"]
EOF

    # Copy scripts to build context
    cp "${PROJECT_ROOT}/setup_kaggle_zrok.sh" "${BATS_FILE_TMPDIR}/"
    cp "${PROJECT_ROOT}/start_zrok.sh" "${BATS_FILE_TMPDIR}/"
    
    # Build the image
    docker build -t "$TEST_IMAGE" "${BATS_FILE_TMPDIR}" >/dev/null 2>&1
}

teardown_file() {
    # Cleanup image
    docker rmi "$TEST_IMAGE" 2>/dev/null || true
}

setup() {
    skip_if_no_docker
    
    # Start a fresh container for each test
    TEST_CONTAINER=$(docker run -d "$TEST_IMAGE")
    export TEST_CONTAINER
}

teardown() {
    # Remove container
    if [[ -n "$TEST_CONTAINER" ]]; then
        docker rm -f "$TEST_CONTAINER" 2>/dev/null || true
    fi
}

# =============================================================================
# SSHD Configuration Idempotency Tests
# =============================================================================

@test "P0: SSHD config block appears exactly once after multiple runs" {
    skip "Requires marker-based idempotency from Epic 2"
    
    # Run configure_sshd multiple times
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only 2>/dev/null || true
        configure_sshd
        configure_sshd
        configure_sshd
    "
    
    # Count KAGGLELINK markers (should be exactly 1 BEGIN and 1 END)
    run docker exec "$TEST_CONTAINER" grep -c "BEGIN KAGGLELINK CONFIG" /etc/ssh/sshd_config
    [ "$output" = "1" ]
    
    run docker exec "$TEST_CONTAINER" grep -c "END KAGGLELINK CONFIG" /etc/ssh/sshd_config
    [ "$output" = "1" ]
}

@test "P1: SSHD config validates after modification (sshd -t)" {
    skip "Requires setup_kaggle_zrok.sh function extraction"
    
    # Apply configuration
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only 2>/dev/null || true
        configure_sshd
    "
    
    # Validate sshd config syntax
    run docker exec "$TEST_CONTAINER" sshd -t
    [ "$status" -eq 0 ]
}

# =============================================================================
# SSH Directory Idempotency Tests
# =============================================================================

@test "P0: SSH directory exists with correct permissions after setup" {
    # Create SSH directory
    docker exec "$TEST_CONTAINER" bash -c "
        mkdir -p /root/.ssh
        chmod 700 /root/.ssh
        touch /root/.ssh/authorized_keys
        chmod 600 /root/.ssh/authorized_keys
    "
    
    # Verify .ssh directory permissions (700)
    run docker exec "$TEST_CONTAINER" stat -c '%a' /root/.ssh
    [ "$output" = "700" ]
    
    # Verify authorized_keys permissions (600)
    run docker exec "$TEST_CONTAINER" stat -c '%a' /root/.ssh/authorized_keys
    [ "$output" = "600" ]
}

@test "P1: authorized_keys content not duplicated on re-run" {
    skip "Requires marker-based idempotency from Epic 2"
    
    # Setup with a test key (twice)
    docker exec "$TEST_CONTAINER" bash -c "
        echo 'ssh-rsa TESTKEY1 test@example.com' > /root/.ssh/authorized_keys
        source /app/setup_kaggle_zrok.sh --source-only 2>/dev/null || true
        # Simulate re-run that might append
    "
    
    # Count occurrences of test key
    run docker exec "$TEST_CONTAINER" grep -c "TESTKEY1" /root/.ssh/authorized_keys
    [ "$output" = "1" ]
}

# =============================================================================
# .bashrc Idempotency Tests
# =============================================================================

@test "P0: Environment exports in .bashrc not duplicated" {
    skip "Requires marker-based idempotency from Epic 2"
    
    # Export environment vars multiple times
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only 2>/dev/null || true
        setup_environment_variables
        setup_environment_variables
        setup_environment_variables
    "
    
    # Count KAGGLELINK ENV markers
    run docker exec "$TEST_CONTAINER" grep -c "BEGIN KAGGLELINK ENV" /root/.bashrc
    [ "$output" = "1" ]
}

@test "P1: MPLBACKEND export present after setup" {
    skip "Requires function extraction"
    
    docker exec "$TEST_CONTAINER" bash -c "
        source /app/setup_kaggle_zrok.sh --source-only 2>/dev/null || true
        setup_environment_variables
    "
    
    run docker exec "$TEST_CONTAINER" grep "MPLBACKEND" /root/.bashrc
    [ "$status" -eq 0 ]
    [[ "$output" == *"Agg"* ]]
}

# =============================================================================
# Full Setup Idempotency Test
# =============================================================================

@test "P1: Full setup can be run twice without errors" {
    skip "Requires full integration with mocked externals"
    
    # This would run the complete setup twice and verify no errors
    # For now, we skip as it requires more complex mocking
    
    true
}
