#!/bin/bash
# Shared logging utilities for kagglelink scripts
#
# This library provides consistent logging functions with emojis,
# timestamps, and error categorization for all kagglelink scripts.
#
# Usage:
#   source logging_utils.sh
#   log_info "Starting operation..."
#   log_success "Operation completed"
#   log_error "Something went wrong"

# Store step start times for elapsed time calculation
declare -A _STEP_START_TIMES

# Log an informational message with ⏳ emoji and timestamp
# Args:
#   $1: Message to log
# Output: Formatted message to stdout
log_info() {
    echo "⏳ [$(date +%H:%M:%S)] $1"
}

# Log a success message with ✅ emoji and timestamp
# Args:
#   $1: Message to log
# Output: Formatted message to stdout
log_success() {
    echo "✅ [$(date +%H:%M:%S)] $1"
}

# Log an error message with ❌ emoji and timestamp to stderr
# Args:
#   $1: Message to log
# Output: Formatted error message to stderr
log_error() {
    echo "❌ [$(date +%H:%M:%S)] ERROR: $1" >&2
}

# Start tracking a step for elapsed time calculation
# Args:
#   $1: Step name
# Output: Informational log message
log_step_start() {
    local step_name="$1"
    _STEP_START_TIMES["$step_name"]=$(date +%s)
    log_info "$step_name..."
}

# Complete a step and display elapsed time
# Args:
#   $1: Step name
# Output: Success message with elapsed time
log_step_complete() {
    local step_name="$1"
    local start_time="${_STEP_START_TIMES[$step_name]}"
    if [ -n "$start_time" ]; then
        local elapsed=$(($(date +%s) - start_time))
        log_success "$step_name completed (${elapsed}s)"
    else
        log_success "$step_name completed"
    fi
}

# Categorize and display error with contextual guidance
# Args:
#   $1: Error type (prerequisite, network, upstream)
#   $2: Error message
#   $3: Suggested action
# Output: Formatted error with category-specific emoji and guidance to stderr
categorize_error() {
    local error_type="$1"
    local message="$2"
    local suggestion="$3"

    case "$error_type" in
    "prerequisite")
        log_error "$message"
        echo "   💡 Action required: $suggestion" >&2
        ;;
    "network")
        log_error "$message"
        echo "   🌐 Check connectivity: $suggestion" >&2
        ;;
    "upstream")
        log_error "$message"
        echo "   🔧 Upstream issue: $suggestion" >&2
        ;;
    *)
        log_error "$message"
        ;;
    esac
}

# Display success banner with Zrok share token and connection instructions
# Args:
#   $1: Zrok share token
# Output: Formatted success banner to stdout
show_success_banner() {
    local share_token="$1"

    if command -v gum &>/dev/null; then
        local header
        header=$(gum style --border double --padding "1 2" --align center --width 60 "✅ Setup Complete!")
        local message
        message=$(gum style --align center --width 60 "Your Kaggle instance is ready for remote access!")

        local token_label
        token_label=$(gum style "📡 Zrok Share Token:")
        local token_value
        token_value=$(gum style --bold "$share_token")
        local token_section
        token_section=$(gum join --vertical --align center "$token_label" "$token_value")
        local token_box
        token_box=$(gum style --border rounded --padding "1 2" --width 60 --align center "$token_section")

        local instr_label
        instr_label=$(gum style "🖥️  On your LOCAL machine, run:")
        local cmd1
        cmd1=$(gum style "zrok access private $share_token")
        local cmd2_label
        cmd2_label=$(gum style "Then connect via SSH:")
        local cmd2
        cmd2=$(gum style "ssh -p 9191 root@127.0.0.1")

        local cmds_content
        cmds_content=$(gum join --vertical --align center "$instr_label" " " "$cmd1" " " "$cmd2_label" " " "$cmd2")
        local cmds_box
        cmds_box=$(gum style --border rounded --padding "1 2" --width 60 --align center "$cmds_content")

        printf "\n"
        gum join --vertical --align center "$header" " " "$message" " " "$token_box" " " "$cmds_box"
    else
        echo ""
        echo "╔════════════════════════════════════════════════════════════════╗"
        echo "║                   ✅ Setup Complete!                          ║"
        echo "╠════════════════════════════════════════════════════════════════╣"
        echo "║                                                                ║"
        echo "║  Your Kaggle instance is ready for remote access!             ║"
        echo "║                                                                ║"
        echo "║  📡 Zrok Share Token: $share_token"
        echo "║                                                                ║"
        echo "║  🖥️  On your LOCAL machine, run:                              ║"
        echo "║                                                                ║"
        echo "║      zrok access private $share_token"
        echo "║                                                                ║"
        echo "║  Then connect via SSH:                                        ║"
        echo "║                                                                ║"
        echo "║      ssh -p 9191 root@127.0.0.1                               ║"
        echo "║                                                                ║"
        echo "╚════════════════════════════════════════════════════════════════╝"
        echo ""
    fi
}
