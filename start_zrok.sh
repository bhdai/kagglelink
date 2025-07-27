#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./start_zrok.sh <zrok_token>"
    exit 1
fi

ZROK_TOKEN=$1

cleanup() {
    echo "Disabling zrok environment..."
    zrok disable
    echo "Cleanup complete."
}

# trap the exit signal to run the cleanup function
trap cleanup EXIT

echo "Starting zrok service..."
if [ -z "$ZROK_TOKEN" ]; then
    echo "Error: ZROK_TOKEN not provided."
    exit 1
fi

echo "Enabling zrok with provided token..."
zrok enable "$ZROK_TOKEN" || {
    echo "Failed to enable zrok with provided token."
    exit 1
}

echo "Starting zrok share in headless mode..."
echo "Starting zrok share now..."
zrok share private --headless --backend-mode tcpTunnel localhost:22

