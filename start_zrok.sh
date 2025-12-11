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
SHARE_OUTPUT_RAW=$(mktemp)

# Redirect all output to raw file for debugging
zrok share private --headless --backend-mode tcpTunnel localhost:22 > "$SHARE_OUTPUT_RAW" 2>&1 &
ZROK_PID=$!

# Give zrok more time to establish tunnel and output token (increased from 2s to 8s)
sleep 8

# Poll for share token with timeout (max 60 seconds)
SHARE_TOKEN=""
for i in {1..60}; do
    # Copy current output for parsing
    cp "$SHARE_OUTPUT_RAW" "$SHARE_OUTPUT" 2>/dev/null || true
    
    # Try multiple regex patterns to find the token
    # Pattern 1: JSON format (non-TTY) - look inside "msg" field for "zrok access private TOKEN"
    SHARE_TOKEN=$(grep -oP '"msg":"[^"]*zrok access private \K[a-zA-Z0-9]+' "$SHARE_OUTPUT" 2>/dev/null || true)
    
    # Pattern 2: Plain text format (TTY) - look for "zrok access private TOKEN" 
    if [ -z "$SHARE_TOKEN" ]; then
        SHARE_TOKEN=$(grep -oP 'zrok access private \K[a-zA-Z0-9]+' "$SHARE_OUTPUT" 2>/dev/null || true)
    fi
    
    # Pattern 3: Look for token on line containing "allow other to access"
    if [ -z "$SHARE_TOKEN" ]; then
        SHARE_TOKEN=$(grep "allow other to access" "$SHARE_OUTPUT" 2>/dev/null | grep -oP 'zrok access private \K[a-zA-Z0-9]+' || true)
    fi
    
    if [ -n "$SHARE_TOKEN" ]; then
        log_success "Token captured: $SHARE_TOKEN (attempt $i)"
        break
    fi
    
    # Debug output every 10 seconds
    if [ $((i % 10)) -eq 0 ]; then
        log_info "Still waiting for token... (${i}s elapsed)"
        log_info "DEBUG: Output file size: $(wc -l < "$SHARE_OUTPUT" 2>/dev/null || echo 0) lines"
        log_info "DEBUG: Full raw output so far:"
        cat "$SHARE_OUTPUT" 2>/dev/null | while read line; do
            log_info "  > $line"
        done
    fi
    
    sleep 1
done

# Clean up temp files
rm -f "$SHARE_OUTPUT" "$SHARE_OUTPUT_RAW"

if [ -z "$SHARE_TOKEN" ]; then
    categorize_error "upstream" "Failed to capture share token within timeout" "Check Zrok service status and logs"
    kill $ZROK_PID 2>/dev/null || true
    exit 1
fi

# Display success banner NOW (before blocking on tunnel)
show_success_banner "$SHARE_TOKEN"

# Keep tunnel alive - wait on background process (blocks here)
log_info "Tunnel is active. Keeping connection alive..."
log_info "Press Ctrl+C to stop the tunnel and clean up."
wait $ZROK_PID

