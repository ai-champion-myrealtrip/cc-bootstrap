#!/bin/bash
#
# Claude Code Bootstrap Agent - Environment Detection Library
#
# This module provides functions for detecting the system environment
# and checking installed dependencies.
#

# Source common utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/../scripts/common.sh" ]; then
    source "$SCRIPT_DIR/../scripts/common.sh"
fi

# =============================================================================
# System Detection
# =============================================================================

# Get full system information as JSON-like output
get_system_info() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    local shell=$(detect_shell)

    echo "{"
    echo "  \"os\": \"$os\","
    echo "  \"arch\": \"$arch\","
    echo "  \"shell\": \"$shell\","

    if [ "$os" = "linux" ]; then
        local distro=$(detect_linux_distro)
        echo "  \"distro\": \"$distro\","
    fi

    if [ "$os" = "macos" ]; then
        local macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
        echo "  \"macos_version\": \"$macos_version\","
    fi

    echo "  \"user\": \"$(whoami)\","
    echo "  \"home\": \"$HOME\""
    echo "}"
}

# =============================================================================
# Package Manager Detection
# =============================================================================

# Detect available package manager
# Returns: homebrew, apt, dnf, yum, pacman, apk, or none
detect_package_manager() {
    local os=$(detect_os)

    case "$os" in
        macos)
            if check_homebrew; then
                echo "homebrew"
            else
                echo "none"
            fi
            ;;
        linux)
            if command_exists apt-get; then
                echo "apt"
            elif command_exists dnf; then
                echo "dnf"
            elif command_exists yum; then
                echo "yum"
            elif command_exists pacman; then
                echo "pacman"
            elif command_exists apk; then
                echo "apk"
            elif command_exists zypper; then
                echo "zypper"
            else
                echo "none"
            fi
            ;;
        *)
            echo "none"
            ;;
    esac
}

# =============================================================================
# Dependency Status
# =============================================================================

# Get comprehensive dependency status
get_dependency_status() {
    local homebrew_status="not_applicable"
    local node_status="missing"
    local npm_status="missing"
    local claude_status="missing"

    # Homebrew (macOS only)
    if [ "$(detect_os)" = "macos" ]; then
        if check_homebrew; then
            homebrew_status="installed"
        else
            homebrew_status="missing"
        fi
    fi

    # Node.js
    if command_exists node; then
        local version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$version" -ge "$MIN_NODE_VERSION" ]; then
            node_status="installed"
        else
            node_status="outdated"
        fi
    fi

    # npm
    if check_npm; then
        npm_status="installed"
    fi

    # Claude Code
    if check_claude; then
        claude_status="installed"
    fi

    echo "{"
    echo "  \"homebrew\": \"$homebrew_status\","
    echo "  \"node\": \"$node_status\","
    echo "  \"npm\": \"$npm_status\","
    echo "  \"claude\": \"$claude_status\""
    echo "}"
}

# =============================================================================
# Installation Requirements
# =============================================================================

# Determine what needs to be installed
# Returns space-separated list of required installations
get_required_installations() {
    local required=""

    # Homebrew (macOS only)
    if [ "$(detect_os)" = "macos" ] && ! check_homebrew; then
        required="homebrew"
    fi

    # Node.js
    if ! check_node; then
        required="$required nodejs"
    fi

    # Claude Code
    if ! check_claude; then
        required="$required claude"
    fi

    # Trim leading/trailing spaces
    echo "$required" | xargs
}

# Check if any installation is required
needs_installation() {
    local required=$(get_required_installations)
    [ -n "$required" ]
}

# =============================================================================
# Version Information
# =============================================================================

# Get all version information
get_versions() {
    echo "{"
    echo "  \"node\": \"$(get_node_version)\","
    echo "  \"npm\": \"$(get_npm_version)\","
    echo "  \"claude\": \"$(get_claude_version)\""

    if [ "$(detect_os)" = "macos" ] && check_homebrew; then
        local brew_version=$(brew --version | head -1 | cut -d' ' -f2)
        echo "  ,\"homebrew\": \"$brew_version\""
    fi

    echo "}"
}

# =============================================================================
# Environment Validation
# =============================================================================

# Validate environment is suitable for installation
validate_environment() {
    local errors=0

    # Check OS support
    local os=$(detect_os)
    if [ "$os" = "unknown" ]; then
        log_error "Unsupported operating system"
        errors=$((errors + 1))
    fi

    # Check internet connectivity
    if ! check_internet; then
        log_error "No internet connection detected"
        errors=$((errors + 1))
    fi

    # Check for curl or wget
    if ! command_exists curl && ! command_exists wget; then
        log_error "Neither curl nor wget found"
        errors=$((errors + 1))
    fi

    return $errors
}

# =============================================================================
# Pretty Print Functions
# =============================================================================

# Print environment summary
print_environment_summary() {
    local os=$(detect_os)
    local arch=$(detect_arch)
    local shell=$(detect_shell)
    local pkg_mgr=$(detect_package_manager)

    echo ""
    echo -e "${MAGENTA}Environment Summary${NC}"
    echo -e "${DIM}$(print_line '-' 40)${NC}"
    echo -e "  OS:              ${BOLD}$os${NC}"
    echo -e "  Architecture:    ${BOLD}$arch${NC}"
    echo -e "  Shell:           ${BOLD}$shell${NC}"
    echo -e "  Package Manager: ${BOLD}$pkg_mgr${NC}"

    if [ "$os" = "linux" ]; then
        local distro=$(detect_linux_distro)
        echo -e "  Distribution:    ${BOLD}$distro${NC}"
    fi

    echo ""
}

# Print dependency status
print_dependency_status() {
    echo ""
    echo -e "${MAGENTA}Dependency Status${NC}"
    echo -e "${DIM}$(print_line '-' 40)${NC}"

    # Homebrew (macOS only)
    if [ "$(detect_os)" = "macos" ]; then
        if check_homebrew; then
            local brew_ver=$(brew --version | head -1 | cut -d' ' -f2)
            echo -e "  Homebrew:    ${GREEN}✓ $brew_ver${NC}"
        else
            echo -e "  Homebrew:    ${RED}✗ Not installed${NC}"
        fi
    fi

    # Node.js
    if command_exists node; then
        local node_ver=$(node -v)
        local major_ver=$(echo "$node_ver" | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$major_ver" -ge "$MIN_NODE_VERSION" ]; then
            echo -e "  Node.js:     ${GREEN}✓ $node_ver${NC}"
        else
            echo -e "  Node.js:     ${YELLOW}! $node_ver (needs v$MIN_NODE_VERSION+)${NC}"
        fi
    else
        echo -e "  Node.js:     ${RED}✗ Not installed${NC}"
    fi

    # npm
    if check_npm; then
        local npm_ver=$(npm -v)
        echo -e "  npm:         ${GREEN}✓ $npm_ver${NC}"
    else
        echo -e "  npm:         ${RED}✗ Not installed${NC}"
    fi

    # Claude Code
    if check_claude; then
        local claude_ver=$(claude --version 2>/dev/null || echo "installed")
        echo -e "  Claude Code: ${GREEN}✓ $claude_ver${NC}"
    else
        echo -e "  Claude Code: ${RED}✗ Not installed${NC}"
    fi

    echo ""
}

# =============================================================================
# Main (for standalone testing)
# =============================================================================
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    echo "Running environment detection..."
    echo ""
    print_environment_summary
    print_dependency_status

    echo "Required installations: $(get_required_installations)"
fi
