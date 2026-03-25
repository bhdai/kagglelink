#!/usr/bin/env bats

load '../test_helper/common.bash'

setup() {
    create_test_dir

    export ORIGINAL_PATH="$PATH"
    export MOCK_BIN_DIR="$TEST_TEMP_DIR/mock-bin"
    export MOCK_LOG="$TEST_TEMP_DIR/mock.log"
    export MOCK_INSTALLED_BIN="$TEST_TEMP_DIR/installed/zrok"

    mkdir -p "$MOCK_BIN_DIR"
    mkdir -p "$(dirname "$MOCK_INSTALLED_BIN")"

    export PATH="$MOCK_BIN_DIR:$ORIGINAL_PATH"

    create_mock_commands
    create_install_harness
}

teardown() {
    export PATH="$ORIGINAL_PATH"
    cleanup_test_dir
}

create_mock_commands() {
    cat > "$MOCK_BIN_DIR/curl" << 'EOF'
#!/bin/bash

echo "curl:$*" >> "$MOCK_LOG"

case "${MOCK_CURL_MODE:-success}" in
    fail)
        exit 22
        ;;
    missing_asset)
        cat << 'JSON'
{"assets":[{"browser_download_url":"https://github.com/openziti/zrok/releases/download/v1.1.11/zrok_1.1.11_windows_amd64.zip"}]}
JSON
        ;;
    non_https_asset)
        cat << 'JSON'
{"assets":[{"browser_download_url":"http://example.com/zrok_1.1.11_linux_amd64.tar.gz"}]}
JSON
        ;;
    *)
        cat << 'JSON'
{"assets":[{"browser_download_url":"https://github.com/openziti/zrok/releases/download/v1.1.11/zrok_1.1.11_linux_amd64.tar.gz"}]}
JSON
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/curl"

    cat > "$MOCK_BIN_DIR/wget" << 'EOF'
#!/bin/bash

output_path=""
url=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -qO)
            output_path="$2"
            shift 2
            ;;
        *)
            url="$1"
            shift
            ;;
    esac
done

echo "wget:${url}:${output_path}" >> "$MOCK_LOG"

if [ "${MOCK_WGET_MODE:-success}" = "fail" ]; then
    exit 1
fi

: > "$output_path"
exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/wget"

    cat > "$MOCK_BIN_DIR/tar" << 'EOF'
#!/bin/bash

extract_dir=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -C)
            extract_dir="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "tar:${extract_dir}" >> "$MOCK_LOG"

case "${MOCK_TAR_MODE:-success}" in
    fail)
        exit 2
        ;;
    multi)
        mkdir -p "$extract_dir/release/bin"
        mkdir -p "$extract_dir/other/bin"
        printf '#!/bin/bash\necho "zrok version v1.1.11"\n' > "$extract_dir/release/bin/zrok"
        printf '#!/bin/bash\necho "zrok version v1.1.11"\n' > "$extract_dir/other/bin/zrok"
        chmod +x "$extract_dir/release/bin/zrok"
        chmod +x "$extract_dir/other/bin/zrok"
        ;;
    *)
        mkdir -p "$extract_dir/release/bin"
        printf '#!/bin/bash\necho "zrok version v1.1.11"\n' > "$extract_dir/release/bin/zrok"
        chmod +x "$extract_dir/release/bin/zrok"
        ;;
esac
EOF
    chmod +x "$MOCK_BIN_DIR/tar"

    cat > "$MOCK_BIN_DIR/install" << 'EOF'
#!/bin/bash

echo "install:$*" >> "$MOCK_LOG"

if [ "${MOCK_INSTALL_MODE:-success}" = "fail" ]; then
    exit 1
fi

if [ "$1" = "-m" ]; then
    src="$3"
    dest="$4"
else
    src="$1"
    dest="$2"
fi

mkdir -p "$(dirname "$dest")"

if [ "${MOCK_ZROK_MODE:-success}" = "fail" ]; then
    printf '#!/bin/bash\nexit 1\n' > "$dest"
else
    cp "$src" "$dest"
fi

chmod +x "$dest"

if [ -n "$MOCK_INSTALLED_BIN" ]; then
    cp "$dest" "$MOCK_INSTALLED_BIN"
    chmod +x "$MOCK_INSTALLED_BIN"
fi

exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/install"

    cat > "$MOCK_BIN_DIR/zrok" << 'EOF'
#!/bin/bash

if [ "${MOCK_ZROK_MODE:-success}" = "fail" ]; then
    exit 1
fi

if [ "$1" = "version" ]; then
    echo "zrok version v1.1.11"
fi

exit 0
EOF
    chmod +x "$MOCK_BIN_DIR/zrok"
}

create_install_harness() {
    local function_body
    function_body=$(awk '/^install_zrok\(\)/,/^}/' "$PROJECT_ROOT/setup_kaggle_zrok.sh")

    cat > "$TEST_TEMP_DIR/install_zrok_harness.sh" << EOF
#!/bin/bash
set -e

source "$PROJECT_ROOT/logging_utils.sh"

${function_body}

install_zrok
EOF

    chmod +x "$TEST_TEMP_DIR/install_zrok_harness.sh"
}

@test "P0: install_zrok happy path uses pinned tag and installs zrok" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=success \
        MOCK_TAR_MODE=success \
        MOCK_INSTALL_MODE=success \
        MOCK_ZROK_MODE=success \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -eq 0 ]
    [ -x "$MOCK_INSTALLED_BIN" ]
    grep -q "releases/tags/v1.1.11" "$MOCK_LOG"
    grep -q "linux_amd64.tar.gz" "$MOCK_LOG"
    grep -q "install:-m 0755" "$MOCK_LOG"
}

@test "P0: install_zrok fails with metadata fetch error when API call fails" {
    run env \
        MOCK_CURL_MODE=fail \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to fetch Zrok release metadata"* ]]
    [[ "$output" == *"v1.1.11"* ]]
}

@test "P0: install_zrok fails when pinned tag has no linux amd64 asset" {
    run env \
        MOCK_CURL_MODE=missing_asset \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to resolve linux amd64 asset"* ]]
    [[ "$output" == *"v1.1.11"* ]]
}

@test "P0: install_zrok fails when resolved asset URL is not HTTPS" {
    run env \
        MOCK_CURL_MODE=non_https_asset \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Resolved Zrok asset URL is not HTTPS"* ]]
}

@test "P0: install_zrok fails with extraction error when tar extraction fails" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=success \
        MOCK_TAR_MODE=fail \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to extract Zrok archive"* ]]
}

@test "P0: install_zrok fails when multiple zrok binaries are found" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=success \
        MOCK_TAR_MODE=multi \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Multiple zrok binaries found"* ]]
}

@test "P0: install_zrok fails with download error when archive fetch fails" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=fail \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to download Zrok archive"* ]]
}

@test "P0: install_zrok fails when binary install command fails" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=success \
        MOCK_TAR_MODE=success \
        MOCK_INSTALL_MODE=fail \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Failed to install zrok binary"* ]]
}

@test "P0: install_zrok fails with post-install validation error when zrok version fails" {
    run env \
        MOCK_CURL_MODE=success \
        MOCK_WGET_MODE=success \
        MOCK_TAR_MODE=success \
        MOCK_INSTALL_MODE=success \
        MOCK_ZROK_MODE=fail \
        MOCK_LOG="$MOCK_LOG" \
        MOCK_INSTALLED_BIN="$MOCK_INSTALLED_BIN" \
        PATH="$PATH" \
        bash "$TEST_TEMP_DIR/install_zrok_harness.sh"

    [ "$status" -ne 0 ]
    [[ "$output" == *"Post-install validation failed"* ]]
}
