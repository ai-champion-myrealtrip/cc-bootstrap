#!/bin/bash
#
# Claude Code Bootstrap Agent - macOS/Linux Setup Script
#
# This script installs all dependencies required for Claude Code:
# - Homebrew (macOS only)
# - Node.js (v18+)
# - npm
# - Claude Code CLI
#
set -e

# =============================================================================
# Color Definitions
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =============================================================================
# Logging Functions
# =============================================================================
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${CYAN}[STEP]${NC} $1"; }

# =============================================================================
# Global Variables
# =============================================================================
ARCH=$(uname -m)
OS_TYPE="unknown"
MIN_NODE_VERSION=18

# =============================================================================
# OS Detection
# =============================================================================
detect_os() {
    case "$(uname -s)" in
        Darwin*)  OS_TYPE="macos" ;;
        Linux*)   OS_TYPE="linux" ;;
        *)        OS_TYPE="unknown" ;;
    esac
    echo "$OS_TYPE"
}

# =============================================================================
# Dependency Check Functions
# =============================================================================

# Check if Homebrew is installed
check_homebrew() {
    command -v brew &> /dev/null
}

# Check if Node.js is installed and version is sufficient
check_node() {
    if command -v node &> /dev/null; then
        local version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        [ "$version" -ge "$MIN_NODE_VERSION" ]
    else
        return 1
    fi
}

# Check if npm is installed
check_npm() {
    command -v npm &> /dev/null
}

# Check if Claude Code is installed
check_claude() {
    command -v claude &> /dev/null
}

# =============================================================================
# Installation Functions
# =============================================================================

# Install Homebrew (macOS only)
install_homebrew() {
    if [ "$OS_TYPE" != "macos" ]; then
        return 0
    fi

    log_step "Checking Homebrew..."

    if check_homebrew; then
        local brew_version=$(brew --version | head -1)
        log_success "Homebrew already installed ($brew_version)"
        return 0
    fi

    log_info "Homebrew not found. Installing..."

    # Run Homebrew installer
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Configure PATH for Apple Silicon
    if [[ "$ARCH" == "arm64" ]]; then
        log_info "Configuring Homebrew for Apple Silicon..."

        # Add to .zprofile if it exists or create it
        local shell_config="$HOME/.zprofile"
        if [ -f "$HOME/.zshrc" ]; then
            shell_config="$HOME/.zshrc"
        fi

        if ! grep -q '/opt/homebrew/bin/brew' "$shell_config" 2>/dev/null; then
            echo '' >> "$shell_config"
            echo '# Homebrew' >> "$shell_config"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_config"
        fi

        # Load for current session
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if check_homebrew; then
        log_success "Homebrew installed successfully"
    else
        log_error "Homebrew installation failed"
        exit 1
    fi
}

# Install Node.js
install_node() {
    log_step "Checking Node.js..."

    if check_node; then
        log_success "Node.js $(node -v) already installed (>= v$MIN_NODE_VERSION)"
        return 0
    fi

    if command -v node &> /dev/null; then
        log_warning "Node.js $(node -v) is installed but version is below v$MIN_NODE_VERSION"
        log_info "Upgrading Node.js..."
    else
        log_info "Node.js not found. Installing..."
    fi

    case "$OS_TYPE" in
        macos)
            if check_homebrew; then
                brew install node
            else
                log_error "Homebrew is required to install Node.js on macOS"
                exit 1
            fi
            ;;
        linux)
            install_node_linux
            ;;
        *)
            log_error "Unsupported OS for Node.js installation"
            exit 1
            ;;
    esac

    # Verify installation
    if check_node; then
        log_success "Node.js $(node -v) installed successfully"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

# Install Node.js on Linux
install_node_linux() {
    # Detect package manager and install accordingly
    if command -v apt-get &> /dev/null; then
        log_info "Using apt (Debian/Ubuntu)..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
    elif command -v dnf &> /dev/null; then
        log_info "Using dnf (Fedora/RHEL)..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo dnf install -y nodejs
    elif command -v yum &> /dev/null; then
        log_info "Using yum (CentOS/RHEL)..."
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
        sudo yum install -y nodejs
    elif command -v pacman &> /dev/null; then
        log_info "Using pacman (Arch)..."
        sudo pacman -S --noconfirm nodejs npm
    elif command -v apk &> /dev/null; then
        log_info "Using apk (Alpine)..."
        sudo apk add --no-cache nodejs npm
    else
        log_error "No supported package manager found"
        log_info "Please install Node.js v$MIN_NODE_VERSION+ manually: https://nodejs.org"
        exit 1
    fi
}

# Verify npm is available
verify_npm() {
    log_step "Checking npm..."

    if check_npm; then
        log_success "npm $(npm -v) available"
    else
        log_error "npm not found. This should be included with Node.js."
        log_info "Try reinstalling Node.js or install npm manually."
        exit 1
    fi
}

# =============================================================================
# PATH Configuration
# =============================================================================

# Get shell config file
get_shell_config() {
    local shell_name=$(basename "$SHELL")
    case "$shell_name" in
        zsh)
            if [ -f "$HOME/.zshrc" ]; then
                echo "$HOME/.zshrc"
            else
                echo "$HOME/.zprofile"
            fi
            ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.bash_profile"
            fi
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

# Add npm global bin to PATH
setup_npm_path() {
    log_step "Checking npm global path..."

    # Get npm global bin path
    local npm_bin
    if command -v npm &> /dev/null; then
        npm_bin="$(npm config get prefix)/bin"
    else
        # Default paths
        if [ "$OS_TYPE" == "macos" ]; then
            npm_bin="/usr/local/bin"
        else
            npm_bin="$HOME/.npm-global/bin"
        fi
    fi

    # Check if already in PATH
    if echo "$PATH" | grep -q "$npm_bin"; then
        log_success "npm global path already in PATH"
        return 0
    fi

    log_info "Adding npm global path to PATH..."

    # Add to current session
    export PATH="$npm_bin:$PATH"

    # Add to shell config for persistence
    local shell_config=$(get_shell_config)

    if [ -f "$shell_config" ]; then
        if ! grep -q "npm.*bin" "$shell_config" 2>/dev/null; then
            echo '' >> "$shell_config"
            echo '# npm global bin' >> "$shell_config"
            echo "export PATH=\"$npm_bin:\$PATH\"" >> "$shell_config"
            log_success "Added npm path to $shell_config"
        fi
    fi

    log_success "npm global path configured"
}

# Install Claude Code
install_claude_code() {
    log_step "Checking Claude Code..."

    if check_claude; then
        local current_version=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code already installed ($current_version)"

        log_info "Checking for updates..."
        if npm update -g @anthropic-ai/claude-code 2>/dev/null; then
            local new_version=$(claude --version 2>/dev/null || echo "unknown")
            if [ "$new_version" != "$current_version" ]; then
                log_success "Claude Code updated to $new_version"
            else
                log_info "Already at latest version"
            fi
        fi
        return 0
    fi

    log_info "Installing Claude Code..."

    # Install globally
    npm install -g @anthropic-ai/claude-code

    # Verify installation
    if check_claude; then
        local version=$(claude --version 2>/dev/null || echo "installed")
        log_success "Claude Code installed successfully ($version)"
    else
        log_warning "Claude Code installed but not in PATH"
        log_info "You may need to restart your terminal or add npm global bin to PATH"

        # Show npm global bin path
        local npm_bin=$(npm config get prefix)/bin
        log_info "npm global bin: $npm_bin"
    fi
}

# =============================================================================
# Post-Installation Verification
# =============================================================================
verify_installation() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}              Installation Complete!                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "${BOLD}System Information:${NC}"
    echo -e "  • OS:           $OS_TYPE"
    echo -e "  • Architecture: $ARCH"
    echo ""

    echo -e "${BOLD}Installed Components:${NC}"

    # Homebrew (macOS only)
    if [ "$OS_TYPE" == "macos" ]; then
        if check_homebrew; then
            echo -e "  • Homebrew:    ${GREEN}$(brew --version | head -1 | cut -d' ' -f2)${NC}"
        else
            echo -e "  • Homebrew:    ${RED}not installed${NC}"
        fi
    fi

    # Node.js
    if check_node; then
        echo -e "  • Node.js:     ${GREEN}$(node -v)${NC}"
    else
        echo -e "  • Node.js:     ${RED}not installed or version too old${NC}"
    fi

    # npm
    if check_npm; then
        echo -e "  • npm:         ${GREEN}$(npm -v)${NC}"
    else
        echo -e "  • npm:         ${RED}not installed${NC}"
    fi

    # Claude Code
    if check_claude; then
        local claude_ver=$(claude --version 2>/dev/null || echo "installed")
        echo -e "  • Claude Code: ${GREEN}$claude_ver${NC}"
    else
        echo -e "  • Claude Code: ${YELLOW}installed (restart terminal to use)${NC}"
    fi

    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Next Steps:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  1. Open a new terminal window (to refresh PATH)"
    echo ""
    echo "  2. Run Claude Code:"
    echo -e "     ${CYAN}claude${NC}"
    echo ""
    echo "  3. Follow the authentication prompts to log in"
    echo ""
    echo "  4. Start coding with AI assistance!"
    echo ""
    echo -e "${CYAN}Useful commands:${NC}"
    echo "  claude --help     Show all options"
    echo "  claude --version  Show version info"
    echo ""
}

# =============================================================================
# Error Handler
# =============================================================================
handle_error() {
    local line_no=$1
    log_error "Installation failed at line $line_no"
    log_info "Please check the error messages above and try again."
    log_info "For manual installation, visit: https://docs.anthropic.com/claude-code"
    exit 1
}

trap 'handle_error $LINENO' ERR

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo ""
    log_info "Starting Claude Code setup..."
    log_info "Architecture: $ARCH"
    echo ""

    # Detect OS
    detect_os > /dev/null

    # Run installation steps
    install_homebrew
    install_node
    verify_npm
    setup_npm_path
    install_claude_code
    verify_installation
}

# Run main
main "$@"
