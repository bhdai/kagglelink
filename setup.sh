#!/bin/bash

set -e

# Version and branch configuration
KAGGLELINK_VERSION="1.1.0"
KAGGLELINK_BRANCH="${BRANCH:-main}"

# Security: Validate KAGGLELINK_BRANCH to prevent argument injection
# Branch names must not start with '-' to prevent git argument injection
if [[ "$KAGGLELINK_BRANCH" =~ ^- ]]; then
    echo "❌ Error: Invalid branch name '$KAGGLELINK_BRANCH'"
    echo "   Branch names cannot start with '-' (security: prevents argument injection)"
    exit 1
fi

# Reliability: Check for git installation
if ! command -v git &> /dev/null; then
    echo "❌ Error: git is not installed"
    echo "   Please install git and try again"
    echo "   - Debian/Ubuntu: sudo apt-get install git"
    echo "   - RHEL/CentOS: sudo yum install git"
    echo "   - macOS: brew install git"
    exit 1
fi

echo "===================================="
echo "kagglelink setup tool"
echo "Version: ${KAGGLELINK_VERSION} (branch: ${KAGGLELINK_BRANCH})"
echo "For more information check out: https://github.com/bhdai/kagglelink"
echo "===================================="

# Default repository URL and branch
REPO_URL="https://github.com/bhdai/kagglelink.git"
INSTALL_DIR="/tmp/kagglelink"

# Function to display usage information
# Takes optional exit code parameter (default: 1 for errors, 0 for help)
usage() {
    local exit_code="${1:-1}"
    echo "Usage: curl -sS https://raw.githubusercontent.com/bhdai/kagglelink/refs/heads/${KAGGLELINK_BRANCH}/setup.sh | bash -s -- -k <your_public_key_url> -t <your_zrok_token>"
    echo ""
    echo "Options:"
    echo "  -k, --keys-url URL    URL to your authorized_keys file"
    echo "  -t, --token TOKEN     Your zrok token"
    echo "  -h, --help            Display this help message"
    echo ""
    echo "Environment Variables (fallback when CLI flags not provided):"
    echo "  KAGGLELINK_KEYS_URL   URL to your authorized_keys file"
    echo "  KAGGLELINK_TOKEN      Your zrok token"
    echo "  BRANCH                Override default branch (current: ${KAGGLELINK_BRANCH})"
    exit "$exit_code"
}

# Parse command line arguments
# Initialize source tracking variables
AUTH_KEYS_SOURCE=""
ZROK_TOKEN_SOURCE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -k | --keys-url)
            AUTH_KEYS_URL="$2"
            AUTH_KEYS_SOURCE="CLI argument"
            shift 2
            ;;
        -t | --token)
            ZROK_TOKEN="$2"
            ZROK_TOKEN_SOURCE="CLI argument"
            shift 2
            ;;
        -h | --help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Apply environment variable fallback if CLI args not provided
if [ -z "$AUTH_KEYS_URL" ] && [ -n "$KAGGLELINK_KEYS_URL" ]; then
    AUTH_KEYS_URL="$KAGGLELINK_KEYS_URL"
    AUTH_KEYS_SOURCE="KAGGLELINK_KEYS_URL env var"
fi

if [ -z "$ZROK_TOKEN" ] && [ -n "$KAGGLELINK_TOKEN" ]; then
    ZROK_TOKEN="$KAGGLELINK_TOKEN"
    ZROK_TOKEN_SOURCE="KAGGLELINK_TOKEN env var"
fi

# Log configuration source for transparency
if [ -n "$AUTH_KEYS_URL" ]; then
    echo "ℹ️  Using keys URL from: $AUTH_KEYS_SOURCE"
fi
if [ -n "$ZROK_TOKEN" ]; then
    echo "ℹ️  Using token from: $ZROK_TOKEN_SOURCE"
fi

# Check for required parameters
if [ -z "$AUTH_KEYS_URL" ]; then
    echo "Error: Public key URL is required"
    echo "       Provide via: -k <url> or --keys-url <url>"
    echo "       Or set: KAGGLELINK_KEYS_URL environment variable"
    echo "       Run with --help for more information"
    exit 1
fi

if [ -z "$ZROK_TOKEN" ]; then
    echo "Error: zrok token is required"
    echo "       Provide via: -t <token> or --token <token>"
    echo "       Or set: KAGGLELINK_TOKEN environment variable"
    echo "       Run with --help for more information"
    exit 1
fi

# Validate that AUTH_KEYS_URL uses HTTPS (security requirement)
if [[ ! "$AUTH_KEYS_URL" =~ ^https:// ]]; then
    echo "❌ Error: Keys URL must use HTTPS (not HTTP)"
    echo "   Insecure URL: $AUTH_KEYS_URL"
    if [[ "$AUTH_KEYS_URL" =~ ^http:// ]]; then
        echo "   Use: ${AUTH_KEYS_URL/http:/https:}"
    else
        echo "   URL must start with https://"
    fi
    exit 1
fi

echo "⏳ Cloning repository..."
if [ -d "$INSTALL_DIR" ]; then
    echo "Repository directory already exists. Removing it..."
    rm -rf "$INSTALL_DIR"
fi

if ! git clone -b "$KAGGLELINK_BRANCH" "$REPO_URL" "$INSTALL_DIR"; then
    echo "❌ Error: Failed to clone branch '$KAGGLELINK_BRANCH'"
    echo "   Possible reasons:"
    echo "   - Branch does not exist"
    echo "   - Network connectivity issues"
    echo "   - GitHub is unreachable"
    exit 1
fi
echo "✅ Cloned repository (branch: ${KAGGLELINK_BRANCH})"

echo "⏳ Changing to repository directory..."
cd "$INSTALL_DIR"

echo "⏳ Making scripts executable..."
chmod +x setup_kaggle_zrok.sh start_zrok.sh

echo "⏳ Setting up SSH with your public keys..."
./setup_kaggle_zrok.sh "$AUTH_KEYS_URL"

echo "⏳ Starting zrok service with your token..."
./start_zrok.sh "$ZROK_TOKEN"

echo "✅ Setup complete!"
echo "✅ You should now be able to connect to your Kaggle instance via SSH."
echo "✅ If you see a URL above, use that to connect from your local machine."
echo "✅ For more information, visit: https://github.com/bhdai/kagglelink"
