#!/bin/bash

set -e

# Source logging utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging_utils.sh"

if [ "$#" -ne 1 ]; then
    echo "Usage: ./start_zrok.sh <zrok_token>"
    exit 1
fi

ZROK_TOKEN=$1

cleanup() {
    log_info "Disabling zrok environment..."
    zrok disable
    log_success "Cleanup complete."
}

# trap the exit signal to run the cleanup function
trap cleanup EXIT

log_info "Starting zrok service..."
if [ -z "$ZROK_TOKEN" ]; then
    categorize_error "prerequisite" "ZROK_TOKEN not provided" "Provide token via -t flag"
    exit 1
fi

log_step_start "Enabling zrok with provided token"
if ! zrok enable "$ZROK_TOKEN"; then
    categorize_error "upstream" "Failed to enable zrok with provided token" "Verify token is valid or try again later"
    exit 1
fi
log_step_complete "Enabling zrok with provided token"

# CRITICAL: Start zrok share in background to capture token BEFORE blocking
log_info "Starting zrok tunnel (capturing share token)..."
SHARE_OUTPUT=$(mktemp)
# Redirect both stdout and stderr, but filter out verbose INFO logs
zrok share private --headless --backend-mode tcpTunnel localhost:22 2>&1 | grep -v "^\[.*INFO.*\]" > "$SHARE_OUTPUT" &
ZROK_PID=$!

# Poll for share token with timeout (max 30 seconds)
SHARE_TOKEN=""
for i in {1..30}; do
    # Look for the access command pattern in output
    SHARE_TOKEN=$(grep -oP 'access your share with.*zrok access private \K\S+' "$SHARE_OUTPUT" 2>/dev/null || true)
    if [ -n "$SHARE_TOKEN" ]; then
        break
    fi
    sleep 1
done

# Clean up temp file
rm -f "$SHARE_OUTPUT"

if [ -z "$SHARE_TOKEN" ]; then
    categorize_error "upstream" "Failed to capture share token within timeout" "Check Zrok service status and logs"
    kill $ZROK_PID 2>/dev/null || true
    exit 1
fi

# Display success banner NOW (before blocking on tunnel)
show_success_banner "$SHARE_TOKEN"

# Keep tunnel alive - wait on background process (blocks here)
log_info "Tunnel is active..."
wait $ZROK_PID

