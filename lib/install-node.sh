#!/bin/bash
#
# Claude Code Bootstrap Agent - Node.js Installation Library
#
# This module handles Node.js installation across different platforms
# and package managers.
#

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../scripts/common.sh" ]; then
    source "$SCRIPT_DIR/../scripts/common.sh"
fi

# =============================================================================
# Configuration
# =============================================================================
NODE_LTS_VERSION="20"  # Latest LTS major version
NODESOURCE_URL="https://deb.nodesource.com/setup_${NODE_LTS_VERSION}.x"
NODESOURCE_RPM_URL="https://rpm.nodesource.com/setup_${NODE_LTS_VERSION}.x"

# =============================================================================
# Pre-installation Checks
# =============================================================================

# Check if Node.js upgrade is needed
needs_node_upgrade() {
    if ! command_exists node; then
        return 0  # Not installed, needs installation
    fi

    local version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    [ "$version" -lt "$MIN_NODE_VERSION" ]
}

# Get current Node.js installation method
get_node_install_method() {
    if ! command_exists node; then
        echo "none"
        return
    fi

    local node_path=$(which node)

    case "$node_path" in
        /usr/local/bin/node)
            if [ "$(detect_os)" = "macos" ] && check_homebrew; then
                echo "homebrew"
            else
                echo "manual"
            fi
            ;;
        /opt/homebrew/bin/node)
            echo "homebrew"
            ;;
        $HOME/.nvm/*)
            echo "nvm"
            ;;
        $HOME/.fnm/*)
            echo "fnm"
            ;;
        $HOME/.volta/*)
            echo "volta"
            ;;
        /usr/bin/node)
            echo "system"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# =============================================================================
# Installation Functions
# =============================================================================

# Install Node.js via Homebrew (macOS)
install_node_homebrew() {
    if ! check_homebrew; then
        log_error "Homebrew is not installed"
        return 1
    fi

    log_info "Installing Node.js via Homebrew..."

    # Update Homebrew first
    brew update 2>/dev/null || true

    # Install or upgrade Node.js
    if brew list node &>/dev/null; then
        log_info "Upgrading existing Node.js installation..."
        brew upgrade node
    else
        brew install node
    fi

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via Homebrew"
        return 0
    else
        log_error "Node.js installation via Homebrew failed"
        return 1
    fi
}

# Install Node.js via apt (Debian/Ubuntu)
install_node_apt() {
    log_info "Installing Node.js via apt (NodeSource)..."

    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    # Add NodeSource repository
    curl -fsSL "$NODESOURCE_URL" | sudo -E bash -

    # Install Node.js
    sudo apt-get install -y nodejs

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via apt"
        return 0
    else
        log_error "Node.js installation via apt failed"
        return 1
    fi
}

# Install Node.js via dnf (Fedora)
install_node_dnf() {
    log_info "Installing Node.js via dnf (NodeSource)..."

    # Add NodeSource repository
    curl -fsSL "$NODESOURCE_RPM_URL" | sudo bash -

    # Install Node.js
    sudo dnf install -y nodejs

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via dnf"
        return 0
    else
        log_error "Node.js installation via dnf failed"
        return 1
    fi
}

# Install Node.js via yum (CentOS/RHEL)
install_node_yum() {
    log_info "Installing Node.js via yum (NodeSource)..."

    # Add NodeSource repository
    curl -fsSL "$NODESOURCE_RPM_URL" | sudo bash -

    # Install Node.js
    sudo yum install -y nodejs

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via yum"
        return 0
    else
        log_error "Node.js installation via yum failed"
        return 1
    fi
}

# Install Node.js via pacman (Arch)
install_node_pacman() {
    log_info "Installing Node.js via pacman..."

    sudo pacman -Sy --noconfirm nodejs npm

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via pacman"
        return 0
    else
        log_error "Node.js installation via pacman failed"
        return 1
    fi
}

# Install Node.js via apk (Alpine)
install_node_apk() {
    log_info "Installing Node.js via apk..."

    sudo apk add --no-cache nodejs npm

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via apk"
        return 0
    else
        log_error "Node.js installation via apk failed"
        return 1
    fi
}

# Install Node.js via zypper (openSUSE)
install_node_zypper() {
    log_info "Installing Node.js via zypper..."

    sudo zypper install -y nodejs npm

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed via zypper"
        return 0
    else
        log_error "Node.js installation via zypper failed"
        return 1
    fi
}

# =============================================================================
# Main Installation Function
# =============================================================================

# Install Node.js using the appropriate method for the current system
install_node() {
    # Check if already installed with correct version
    if check_node; then
        log_success "Node.js $(node -v) is already installed (>= v$MIN_NODE_VERSION)"
        return 0
    fi

    # Report outdated version if applicable
    if command_exists node; then
        log_warning "Node.js $(node -v) is outdated (need v$MIN_NODE_VERSION+)"
        log_info "Upgrading Node.js..."
    else
        log_info "Node.js not found. Installing..."
    fi

    local os=$(detect_os)
    local pkg_mgr=$(detect_package_manager)

    case "$os" in
        macos)
            install_node_homebrew
            ;;
        linux)
            case "$pkg_mgr" in
                apt)     install_node_apt ;;
                dnf)     install_node_dnf ;;
                yum)     install_node_yum ;;
                pacman)  install_node_pacman ;;
                apk)     install_node_apk ;;
                zypper)  install_node_zypper ;;
                *)
                    log_error "No supported package manager found"
                    log_info "Please install Node.js v$MIN_NODE_VERSION+ manually"
                    log_info "Download from: https://nodejs.org"
                    return 1
                    ;;
            esac
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
}

# =============================================================================
# npm Configuration
# =============================================================================

# Configure npm for global packages without sudo
configure_npm_global() {
    # Only needed on Linux when not using nvm/volta
    if [ "$(detect_os)" != "linux" ]; then
        return 0
    fi

    local npm_prefix=$(npm config get prefix 2>/dev/null)

    # If prefix is /usr or /usr/local, configure user-local prefix
    if [[ "$npm_prefix" == "/usr"* ]]; then
        local npm_dir="$HOME/.npm-global"

        if [ ! -d "$npm_dir" ]; then
            log_info "Configuring npm for user-local global packages..."

            mkdir -p "$npm_dir"
            npm config set prefix "$npm_dir"

            # Add to PATH
            add_to_shell_config "export PATH=\"$npm_dir/bin:\$PATH\""

            # Update current session
            export PATH="$npm_dir/bin:$PATH"

            log_success "npm configured for user-local packages"
        fi
    fi
}

# =============================================================================
# Verification
# =============================================================================

# Verify complete Node.js installation
verify_node_installation() {
    local status=0

    echo ""
    log_info "Verifying Node.js installation..."

    # Check node
    if command_exists node; then
        local node_ver=$(node -v)
        local major=$(echo "$node_ver" | cut -d'v' -f2 | cut -d'.' -f1)

        if [ "$major" -ge "$MIN_NODE_VERSION" ]; then
            log_success "node: $node_ver"
        else
            log_warning "node: $node_ver (below minimum v$MIN_NODE_VERSION)"
            status=1
        fi
    else
        log_error "node: not found"
        status=1
    fi

    # Check npm
    if command_exists npm; then
        log_success "npm: $(npm -v)"
    else
        log_error "npm: not found"
        status=1
    fi

    # Check npx
    if command_exists npx; then
        log_success "npx: available"
    else
        log_warning "npx: not found"
    fi

    return $status
}

# =============================================================================
# Main (for standalone testing)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Node.js Installation Module"
    echo ""

    echo "Current status:"
    echo "  Node installed: $(command_exists node && echo 'yes' || echo 'no')"
    echo "  Node version: $(get_node_version)"
    echo "  Install method: $(get_node_install_method)"
    echo "  Needs upgrade: $(needs_node_upgrade && echo 'yes' || echo 'no')"
    echo ""

    if [ "$1" = "--install" ]; then
        install_node
        verify_node_installation
    else
        echo "Run with --install to install Node.js"
    fi
fi
