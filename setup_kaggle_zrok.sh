#!/bin/bash

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: ./setup_kaggle_zrok.sh <authorized_keys_url>"
    exit 1
fi

AUTH_KEYS_URL=$1

setup_ssh_directory() {
    echo "Setting up SSH directory in user's home..."
    # If running as root, $HOME/.ssh becomes /root/.ssh
    local ssh_dir_path="$HOME/.ssh"
    mkdir -p "$ssh_dir_path"
    if wget -qO "$ssh_dir_path/authorized_keys" "$AUTH_KEYS_URL"; then
        chmod 700 "$ssh_dir_path"
        chmod 600 "$ssh_dir_path/authorized_keys"
        echo "SSH directory and authorized_keys set up in $ssh_dir_path"
    else
        echo "Failed to download authorized keys from $AUTH_KEYS_URL to $ssh_dir_path/authorized_keys."
        exit 1
    fi
}

copy_vscode_dir() {
    local vscode_dir_in_repo="/tmp/kagglelink/.vscode"
    if [ -d "$vscode_dir_in_repo" ]; then
        [ -d "/kaggle/.vscode" ] && rm -rf "/kaggle/.vscode"
        mkdir -p "/kaggle/.vscode"
        cp -r "$vscode_dir_in_repo/"* "/kaggle/.vscode/"
        echo ".vscode folder copied to /kaggle directory."

        mkdir -p "/kaggle/tmp"
        [ -d "/kaggle/working/.vscode" ] && rm -rf "/kaggle/working/.vscode"
        mkdir -p "/kaggle/working/.vscode"
        cp -r "$vscode_dir_in_repo/"* "/kaggle/working/.vscode/"
        echo ".vscode folder copied to /kaggle/working directory."

        echo "Contents of /kaggle/.vscode:"
        ls -l "/kaggle/.vscode"
        echo "Contents of /kaggle/working/.vscode:"
        ls -l "/kaggle/working/.vscode"
    else
        echo ".vscode directory not found in repository at $vscode_dir_in_repo."
    fi
}

configure_sshd() {
    mkdir -p /var/run/sshd
    echo "Configuring sshd..."
    cat <<EOF >>/etc/ssh/sshd_config
Port 22
Protocol 2
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile %h/.ssh/authorized_keys
TCPKeepAlive yes
X11Forwarding yes
X11DisplayOffset 10
IgnoreRhosts yes
HostbasedAuthentication no
PrintLastLog yes
ChallengeResponseAuthentication no
UsePAM yes
AcceptEnv LANG LC_*
AllowTcpForwarding yes
GatewayPorts yes
PermitTunnel yes
ClientAliveInterval 60
ClientAliveCountMax 2
EOF
    echo "" >>/etc/ssh/sshd_config
    echo "sshd_config updated. Note: Appended settings. Ensure no conflicting duplicates exist if run multiple times."

    echo "Configuring debconf for non-interactive mode..."
    echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
    echo "debconf configured to use Noninteractive frontend."

    # Disable pam_systemd for container compatibility
    echo "Disabling pam_systemd..."
    sed -i 's/^session.*pam_systemd.so/#&/' /etc/pam.d/common-session

    # Disable man-db postinst to prevent crashes
    echo "Disabling man-db postinst script..."
    dpkg-divert --quiet --local --rename --add /var/lib/dpkg/info/man-db.postinst
    ln -sf /bin/true /var/lib/dpkg/info/man-db.postinst

    echo "Container compatibility fixes applied."
}

setup_environment_variables() {
    echo "Appending current environment variables to /root/.bashrc..."
    {
        echo ""
        echo "# Added by setup_kaggle_zrok.sh: Kaggle instance environment variables"
        printenv | while IFS='=' read -r key value; do
            # Skip PWD and OLDPWD to avoid setting working directory
            # Skip interactive/session-specific variables that break SSH sessions
            # Skip bash internal variables (BASH_*) which can't be exported properly
            if [[ "$key" == "PWD" || "$key" == "OLDPWD" || "$key" == "TERM" ||
                "$key" == "DEBIAN_FRONTEND" || "$key" == "SHELL" ||
                "$key" == "_" || "$key" == "SHLVL" || "$key" == "HOSTNAME" ||
                "$key" == "JPY_PARENT_PID" || "$key" =~ ^COLAB_ || "$key" =~ ^BASH_ ]]; then
                continue
            fi
            # Properly escape single quotes for bash export
            escaped_value_final=$(printf "%s" "$value" | sed "s/'/'\\\''/g")
            echo "export ${key}='${escaped_value_final}'"
        done
        echo "export MPLBACKEND=Agg"
        echo "# End of Kaggle instance environment variables"

        echo "# Directory navigation aliases"
        {
            echo "alias ..='cd ..'"
            echo "alias ...='cd ../..'" 
            echo "alias .3='cd ../../..'"
            echo "alias .4='cd ../../../..'"
            echo "alias .5='cd ../../../../..'"
        } >>/root/.bashrc

        echo "# Dynamic VS Code server path resolution"
        cat <<'EOT'
# Dynamic VS Code server path resolution
if [ -d "$HOME/.vscode-server" ]; then
  # Find the most recent VS Code server directory
  VSCODE_SERVER_DIR=$(find $HOME/.vscode-server/cli/servers -type d -name "Stable-*" | sort | tail -n 1)
  if [ -n "$VSCODE_SERVER_DIR" ]; then
    export PATH="$VSCODE_SERVER_DIR/server/bin/remote-cli:$PATH"
  fi
fi
EOT
        echo ""
    } >>/root/.bashrc

    echo "Sourcing /root/.bashrc for current script session (best effort)..."
    # shellcheck disable=SC1091
    source /root/.bashrc || echo "Warning: Sourcing /root/.bashrc encountered an issue. SSH sessions should still inherit env vars."
}

install_packages() {
    echo "Installing openssh-server..."
    sudo apt-get update
    sudo apt-get install -y openssh-server nvtop screen lshw

    curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_zrok() {
    echo "Downloading latest zrok release"
    curl -s https://api.github.com/repos/openziti/zrok/releases/latest |
        grep "browser_download_url.*linux_amd64.tar.gz" |
        cut -d : -f 2,3 |
        tr -d \" |
        wget -qi -

    echo "Extracting Zrok"
    if ! tar -xzf zrok_*_linux_amd64.tar.gz -C /usr/local/bin/; then
        echo "ERROR: Failed to extract Zrok"
        exit 1
    fi
    rm zrok_*_linux_amd64.tar.gz

    # check if zrok is installed correctly
    if ! zrok version &>/dev/null; then
        echo "Error: Zrok install failed"
        exit 1
    fi

    echo "Zrok installed successfully:"
    zrok version
}

setup_install_extensions_command() {
    echo "Setting up 'install_extensions' command..."
    # SCRIPT_DIR will point to the directory where setup_kaggle_zrok.sh is located
    local SCRIPT_DIR
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
    local install_script_source="$SCRIPT_DIR/install_extensions.sh"
    local install_script_target="/usr/local/bin/install_extensions"

    if [ -f "$install_script_source" ]; then
        mkdir -p /usr/local/bin # Ensure target directory exists
        cp "$install_script_source" "$install_script_target"
        chmod +x "$install_script_target"
        echo "'install_extensions' command is now available from $install_script_target."
        echo "You can run 'install_extensions' in your terminal after SSHing."
    else
        echo "Warning: $install_script_source not found. 'install_extensions' command not set up."
    fi
}

start_ssh_service() {
    service ssh start
    echo "SSH service should be running."
}

copy_screenrc() {
    local src="/tmp/kagglelink/.screenrc"
    local dest="$HOME/.screenrc"
    if [ -f "$src" ]; then
        cp "$src" "$dest"
        echo ".screenrc installed to $dest"
    else
        echo "Warning: $src not found; skipping .screenrc install."
    fi
}

(
    setup_environment_variables
    install_packages
    install_zrok
    setup_ssh_directory # run sequentially
    configure_sshd      # run sequentially
    copy_vscode_dir &
    copy_screenrc &
    setup_install_extensions_command
    wait # for copy_vscode_dir and copy_screenrc
    start_ssh_service
)

echo "Setup script completed. SSH service is running. Use start_zrok.sh to start zrok service."
