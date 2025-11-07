#!/bin/bash

set -e

echo "===================================="
echo "kagglelink setup tool"
echo "For more information check out: https://github.com/bhdai/kagglelink"
echo "===================================="

# Default repository URL and branch
REPO_URL="https://github.com/bhdai/kagglelink.git"
INSTALL_DIR="/tmp/kagglelink"

# Function to display usage information
usage() {
    echo "Usage: curl -sS https://raw.githubusercontent.com/bhdai/kagglelink/refs/heads/main/setup.sh | bash -s -- -k <your_public_key_url> -t <your_zrok_token>"
    echo ""
    echo "Options:"
    echo "  -k, --keys-url URL    URL to your authorized_keys file"
    echo "  -t, --token TOKEN     Your zrok token"
    echo "  -h, --help            Display this help message"
    exit 1
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

git clone "$REPO_URL" "$INSTALL_DIR"

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
