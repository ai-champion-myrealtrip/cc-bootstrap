#!/bin/bash
#
# Claude Code Bootstrap Agent - Claude Code Installation Library
#
# This module handles Claude Code CLI installation and configuration.
#

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../scripts/common.sh" ]; then
    source "$SCRIPT_DIR/../scripts/common.sh"
fi

# =============================================================================
# Configuration
# =============================================================================
CLAUDE_PACKAGE="@anthropic-ai/claude-code"
CLAUDE_NPM_URL="https://www.npmjs.com/package/@anthropic-ai/claude-code"

# =============================================================================
# Pre-installation Checks
# =============================================================================

# Check npm global packages location
get_npm_global_prefix() {
    npm config get prefix 2>/dev/null || echo ""
}

# Check if Claude Code is installed globally
is_claude_installed_globally() {
    npm list -g "$CLAUDE_PACKAGE" &>/dev/null
}

# Get Claude Code installation path
get_claude_path() {
    if command_exists claude; then
        which claude
    else
        echo "not installed"
    fi
}

# Get installed Claude Code version
get_installed_claude_version() {
    if command_exists claude; then
        claude --version 2>/dev/null || echo "unknown"
    else
        echo "not installed"
    fi
}

# Check for available update
check_claude_update() {
    if ! is_claude_installed_globally; then
        echo "not_installed"
        return
    fi

    local current=$(npm list -g "$CLAUDE_PACKAGE" --depth=0 2>/dev/null | grep "$CLAUDE_PACKAGE" | sed 's/.*@//')
    local latest=$(npm show "$CLAUDE_PACKAGE" version 2>/dev/null)

    if [ -z "$current" ] || [ -z "$latest" ]; then
        echo "unknown"
    elif [ "$current" = "$latest" ]; then
        echo "up_to_date"
    else
        echo "update_available:$latest"
    fi
}

# =============================================================================
# Installation Functions
# =============================================================================

# Install Claude Code globally via npm
install_claude_code() {
    # Check prerequisites
    if ! command_exists npm; then
        log_error "npm is not installed. Please install Node.js first."
        return 1
    fi

    # Check if already installed
    if check_claude; then
        local current_version=$(get_installed_claude_version)
        log_success "Claude Code already installed ($current_version)"

        # Check for updates
        log_info "Checking for updates..."
        update_claude_code
        return $?
    fi

    log_info "Installing Claude Code..."

    # Install globally
    if npm install -g "$CLAUDE_PACKAGE"; then
        # Verify installation
        if check_claude; then
            local version=$(get_installed_claude_version)
            log_success "Claude Code installed successfully ($version)"
            return 0
        else
            # Command not in PATH - provide guidance
            log_warning "Claude Code installed but 'claude' command not found in PATH"
            provide_path_guidance
            return 0
        fi
    else
        log_error "Failed to install Claude Code via npm"
        log_info "Try running: npm install -g $CLAUDE_PACKAGE"
        return 1
    fi
}

# Update Claude Code to latest version
update_claude_code() {
    if ! is_claude_installed_globally; then
        log_info "Claude Code not installed globally, nothing to update"
        return 1
    fi

    local update_status=$(check_claude_update)

    case "$update_status" in
        up_to_date)
            log_info "Claude Code is already at the latest version"
            return 0
            ;;
        update_available:*)
            local new_version="${update_status#update_available:}"
            log_info "Updating Claude Code to v$new_version..."

            if npm update -g "$CLAUDE_PACKAGE"; then
                log_success "Claude Code updated to v$new_version"
                return 0
            else
                log_error "Failed to update Claude Code"
                return 1
            fi
            ;;
        *)
            log_info "Update check inconclusive, attempting update..."
            npm update -g "$CLAUDE_PACKAGE" 2>/dev/null || true
            return 0
            ;;
    esac
}

# Uninstall Claude Code
uninstall_claude_code() {
    if ! is_claude_installed_globally; then
        log_info "Claude Code is not installed globally"
        return 0
    fi

    log_info "Uninstalling Claude Code..."

    if npm uninstall -g "$CLAUDE_PACKAGE"; then
        log_success "Claude Code uninstalled"
        return 0
    else
        log_error "Failed to uninstall Claude Code"
        return 1
    fi
}

# =============================================================================
# PATH Configuration
# =============================================================================

# Provide guidance for PATH configuration
provide_path_guidance() {
    local npm_prefix=$(get_npm_global_prefix)
    local npm_bin="$npm_prefix/bin"

    echo ""
    log_info "To use the 'claude' command, you need to add npm's bin directory to your PATH."
    echo ""
    echo "  npm global bin: $npm_bin"
    echo ""

    local shell=$(detect_shell)
    local config_file=$(get_shell_config)

    echo "  Add this line to your $config_file:"
    echo ""

    case "$shell" in
        zsh|bash)
            echo "    export PATH=\"$npm_bin:\$PATH\""
            ;;
        fish)
            echo "    set -gx PATH $npm_bin \$PATH"
            ;;
        *)
            echo "    export PATH=\"$npm_bin:\$PATH\""
            ;;
    esac

    echo ""
    echo "  Then reload your shell or run:"
    echo ""
    echo "    source $config_file"
    echo ""
}

# Configure PATH for npm global binaries
configure_claude_path() {
    local npm_prefix=$(get_npm_global_prefix)
    local npm_bin="$npm_prefix/bin"

    # Check if already in PATH
    if [[ ":$PATH:" == *":$npm_bin:"* ]]; then
        log_debug "npm bin already in PATH"
        return 0
    fi

    # Add to shell config
    local shell=$(detect_shell)
    local path_line

    case "$shell" in
        fish)
            path_line="set -gx PATH $npm_bin \$PATH"
            ;;
        *)
            path_line="export PATH=\"$npm_bin:\$PATH\""
            ;;
    esac

    if add_to_shell_config "$path_line"; then
        log_info "Added npm bin to PATH in $(get_shell_config)"
        # Update current session
        export PATH="$npm_bin:$PATH"
    fi
}

# =============================================================================
# Verification
# =============================================================================

# Verify Claude Code installation
verify_claude_installation() {
    local status=0

    echo ""
    log_info "Verifying Claude Code installation..."

    # Check npm global package
    if is_claude_installed_globally; then
        local npm_version=$(npm list -g "$CLAUDE_PACKAGE" --depth=0 2>/dev/null | grep "$CLAUDE_PACKAGE" | sed 's/.*@//')
        log_success "npm package: $CLAUDE_PACKAGE@$npm_version"
    else
        log_error "npm package not found globally"
        status=1
    fi

    # Check claude command
    if command_exists claude; then
        local claude_path=$(which claude)
        local claude_version=$(claude --version 2>/dev/null || echo "unknown")
        log_success "claude command: $claude_path"
        log_success "version: $claude_version"
    else
        log_warning "claude command not in PATH"
        provide_path_guidance
    fi

    return $status
}

# =============================================================================
# Diagnostic Functions
# =============================================================================

# Run Claude Code diagnostics
diagnose_claude() {
    echo ""
    echo "Claude Code Diagnostics"
    echo "======================="
    echo ""

    echo "npm configuration:"
    echo "  prefix: $(npm config get prefix 2>/dev/null)"
    echo "  global bin: $(npm bin -g 2>/dev/null)"
    echo ""

    echo "Installation status:"
    echo "  globally installed: $(is_claude_installed_globally && echo 'yes' || echo 'no')"
    echo "  command available: $(command_exists claude && echo 'yes' || echo 'no')"
    echo ""

    if command_exists claude; then
        echo "Claude Code:"
        echo "  path: $(which claude)"
        echo "  version: $(claude --version 2>/dev/null || echo 'error getting version')"
    fi

    echo ""
    echo "PATH entries containing 'npm' or 'node':"
    echo "$PATH" | tr ':' '\n' | grep -E '(npm|node)' | sed 's/^/  /'
    echo ""

    echo "Update status: $(check_claude_update)"
    echo ""
}

# =============================================================================
# Main (for standalone testing)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    case "${1:-}" in
        --install)
            install_claude_code
            verify_claude_installation
            ;;
        --update)
            update_claude_code
            ;;
        --uninstall)
            uninstall_claude_code
            ;;
        --diagnose)
            diagnose_claude
            ;;
        *)
            echo "Claude Code Installation Module"
            echo ""
            echo "Current status:"
            echo "  Installed: $(check_claude && echo 'yes' || echo 'no')"
            echo "  Version: $(get_installed_claude_version)"
            echo "  Path: $(get_claude_path)"
            echo ""
            echo "Commands:"
            echo "  --install   Install Claude Code"
            echo "  --update    Update to latest version"
            echo "  --uninstall Remove Claude Code"
            echo "  --diagnose  Run diagnostics"
            ;;
    esac
fi
