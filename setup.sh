#!/bin/bash

set -e

# Version and branch configuration
KAGGLELINK_VERSION="1.0.0"
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
usage() {
    echo "Usage: curl -sS https://raw.githubusercontent.com/bhdai/kagglelink/refs/heads/${KAGGLELINK_BRANCH}/setup.sh | bash -s -- -k <your_public_key_url> -t <your_zrok_token>"
    echo ""
    echo "Options:"
    echo "  -k, --keys-url URL    URL to your authorized_keys file"
    echo "  -t, --token TOKEN     Your zrok token"
    echo "  -h, --help            Display this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BRANCH                Override default branch (current: ${KAGGLELINK_BRANCH})"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
    -k | --keys-url)
        AUTH_KEYS_URL="$2"
        shift 2
        ;;
    -t | --token)
        ZROK_TOKEN="$2"
        shift 2
        ;;
    -h | --help)
        usage
        ;;
    *)
        echo "Unknown option: $1"
        usage
        ;;
    esac
done

# Check for required parameters
if [ -z "$AUTH_KEYS_URL" ]; then
    echo "Error: Public key URL (-k or --keys-url) is required"
    usage
fi

if [ -z "$ZROK_TOKEN" ]; then
    echo "Error: zrok token (-t or --token) is required"
    usage
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
