#!/bin/bash
#
# Claude Code Bootstrap Agent - Unified Entry Point
# One-shot setup for macOS/Linux/Windows
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/{user}/cc-bootstrap/main/install.sh | bash
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
# Banner
# =============================================================================
print_banner() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}         ${BOLD}Claude Code Bootstrap Agent${NC}                       ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}         ${CYAN}One-shot Setup for All Platforms${NC}                  ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# OS Detection
# =============================================================================
detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

# =============================================================================
# Architecture Detection
# =============================================================================
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "x64" ;;
        amd64)   echo "x64" ;;
        arm64)   echo "arm64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "unknown" ;;
    esac
}

# =============================================================================
# Shell Detection
# =============================================================================
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        echo "sh"
    fi
}

# =============================================================================
# Environment Info Display
# =============================================================================
show_environment() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    local shell=$(detect_shell)

    echo -e "${MAGENTA}Environment Detected:${NC}"
    echo -e "  • OS:           ${BOLD}$os${NC}"
    echo -e "  • Architecture: ${BOLD}$arch${NC}"
    echo -e "  • Shell:        ${BOLD}$shell${NC}"
    echo ""
}

# =============================================================================
# Script Directory Detection
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if running from local files or remote
is_local_install() {
    [ -f "$SCRIPT_DIR/scripts/setup-mac.sh" ]
}

# =============================================================================
# Main Logic
# =============================================================================
main() {
    print_banner
    show_environment

    local os=$(detect_os)

    case $os in
        macos|linux)
            log_step "Starting installation for $os..."
            echo ""

            if is_local_install; then
                # Local installation
                log_info "Running local setup script..."
                bash "$SCRIPT_DIR/scripts/setup-mac.sh"
            else
                # Remote installation (when piped from curl)
                log_info "Downloading and running setup script..."

                # Create temp directory
                TEMP_DIR=$(mktemp -d)
                trap "rm -rf $TEMP_DIR" EXIT

                # For remote execution, embed the setup script directly
                # This allows the script to work when piped from curl
                run_embedded_setup_mac
            fi
            ;;
        windows)
            echo ""
            log_error "Windows detected via bash emulation."
            log_info "For Windows, please use PowerShell:"
            echo ""
            echo -e "  ${CYAN}irm https://raw.githubusercontent.com/{user}/cc-bootstrap/main/scripts/setup-win.ps1 | iex${NC}"
            echo ""
            exit 1
            ;;
        *)
            log_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

# =============================================================================
# Embedded macOS/Linux Setup (for remote curl execution)
# =============================================================================
run_embedded_setup_mac() {
    # This function contains the full setup logic for when running remotely

    local ARCH=$(uname -m)
    log_info "Architecture: $ARCH"
    echo ""

    # -------------------------------------------------------------------------
    # 1. Homebrew Installation (macOS only)
    # -------------------------------------------------------------------------
    install_homebrew() {
        if [ "$(detect_os)" != "macos" ]; then
            return 0
        fi

        if command -v brew &> /dev/null; then
            log_success "Homebrew already installed ($(brew --version | head -1))"
        else
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

            # Apple Silicon PATH setup
            if [[ "$ARCH" == "arm64" ]]; then
                echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
            log_success "Homebrew installed"
        fi
    }

    # -------------------------------------------------------------------------
    # 2. Node.js Installation
    # -------------------------------------------------------------------------
    install_node() {
        if command -v node &> /dev/null; then
            local NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
            if [[ $NODE_VERSION -ge 18 ]]; then
                log_success "Node.js $(node -v) already installed"
                return 0
            else
                log_warning "Node.js version too old ($(node -v)), upgrading..."
            fi
        fi

        log_info "Installing Node.js..."

        if [ "$(detect_os)" == "macos" ]; then
            if command -v brew &> /dev/null; then
                brew install node
            else
                log_error "Homebrew not found. Please install Homebrew first."
                exit 1
            fi
        else
            # Linux - use NodeSource repository
            if command -v apt-get &> /dev/null; then
                curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
                sudo apt-get install -y nodejs
            elif command -v dnf &> /dev/null; then
                curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
                sudo dnf install -y nodejs
            elif command -v yum &> /dev/null; then
                curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
                sudo yum install -y nodejs
            else
                log_error "Unsupported Linux distribution. Please install Node.js manually."
                exit 1
            fi
        fi

        log_success "Node.js $(node -v) installed"
    }

    # -------------------------------------------------------------------------
    # 3. npm Verification
    # -------------------------------------------------------------------------
    verify_npm() {
        if command -v npm &> /dev/null; then
            log_success "npm $(npm -v) available"
        else
            log_error "npm not found. This should have been installed with Node.js."
            exit 1
        fi
    }

    # -------------------------------------------------------------------------
    # 4. Claude Code Installation
    # -------------------------------------------------------------------------
    install_claude_code() {
        if command -v claude &> /dev/null; then
            log_success "Claude Code already installed"
            log_info "Checking for updates..."
            npm update -g @anthropic-ai/claude-code 2>/dev/null || true
        else
            log_info "Installing Claude Code..."
            npm install -g @anthropic-ai/claude-code
            log_success "Claude Code installed"
        fi
    }

    # -------------------------------------------------------------------------
    # 5. Installation Verification
    # -------------------------------------------------------------------------
    verify_installation() {
        echo ""
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}              Installation Complete!                       ${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}Installed versions:${NC}"
        echo -e "  • Node.js:     $(node -v 2>/dev/null || echo 'not found')"
        echo -e "  • npm:         $(npm -v 2>/dev/null || echo 'not found')"

        # Claude Code version check
        local claude_version
        if command -v claude &> /dev/null; then
            claude_version=$(claude --version 2>/dev/null || echo 'installed')
            echo -e "  • Claude Code: $claude_version"
        else
            echo -e "  • Claude Code: ${YELLOW}not in PATH (restart terminal)${NC}"
        fi

        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo "  1. Open a new terminal (to refresh PATH)"
        echo "  2. Run 'claude' to start Claude Code"
        echo "  3. Follow the authentication prompts"
        echo "  4. Start coding with AI!"
        echo ""
        echo -e "${CYAN}Tip: Run 'claude --help' to see all available options${NC}"
        echo ""
    }

    # Execute all steps
    install_homebrew
    install_node
    verify_npm
    install_claude_code
    verify_installation
}

# =============================================================================
# Execute Main
# =============================================================================
main "$@"
