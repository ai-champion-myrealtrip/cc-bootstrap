#!/bin/bash
#
# Claude Code Bootstrap Agent - Common Utilities
#
# This file contains shared functions used across installation scripts.
# Source this file: source "$(dirname "$0")/common.sh"
#

# =============================================================================
# Color Definitions
# =============================================================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m' # No Color
export BOLD='\033[1m'
export DIM='\033[2m'

# =============================================================================
# Configuration
# =============================================================================
export MIN_NODE_VERSION=18
export CLAUDE_PACKAGE="@anthropic-ai/claude-code"

# =============================================================================
# Logging Functions
# =============================================================================

# Info message (blue)
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Success message (green with checkmark)
log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Warning message (yellow with exclamation)
log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Error message (red with X)
log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Step indicator (cyan)
log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Debug message (dim, only if DEBUG=1)
log_debug() {
    if [ "${DEBUG:-0}" = "1" ]; then
        echo -e "${DIM}[DEBUG] $1${NC}"
    fi
}

# =============================================================================
# OS Detection Functions
# =============================================================================

# Detect operating system
# Returns: macos, linux, windows, or unknown
detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

# Detect CPU architecture
# Returns: x64, arm64, or unknown
detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  echo "x64" ;;
        arm64|aarch64) echo "arm64" ;;
        armv7l)        echo "arm" ;;
        i686|i386)     echo "x86" ;;
        *)             echo "unknown" ;;
    esac
}

# Detect current shell
# Returns: zsh, bash, fish, or sh
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    elif [ -n "$FISH_VERSION" ]; then
        echo "fish"
    else
        echo "sh"
    fi
}

# Detect Linux distribution
# Returns: debian, ubuntu, fedora, centos, arch, alpine, or unknown
detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu|linuxmint|pop) echo "debian" ;;
            fedora|rhel|centos|rocky|alma) echo "fedora" ;;
            arch|manjaro) echo "arch" ;;
            alpine) echo "alpine" ;;
            opensuse*|sles) echo "suse" ;;
            *) echo "unknown" ;;
        esac
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

# =============================================================================
# Dependency Check Functions
# =============================================================================

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Check if Homebrew is installed
check_homebrew() {
    command_exists brew
}

# Check if Node.js is installed with minimum version
check_node() {
    if command_exists node; then
        local version
        version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        [ "$version" -ge "$MIN_NODE_VERSION" ]
    else
        return 1
    fi
}

# Get Node.js version string
get_node_version() {
    if command_exists node; then
        node -v
    else
        echo "not installed"
    fi
}

# Check if npm is installed
check_npm() {
    command_exists npm
}

# Get npm version string
get_npm_version() {
    if command_exists npm; then
        npm -v
    else
        echo "not installed"
    fi
}

# Check if Claude Code is installed
check_claude() {
    command_exists claude
}

# Get Claude Code version string
get_claude_version() {
    if command_exists claude; then
        claude --version 2>/dev/null || echo "installed"
    else
        echo "not installed"
    fi
}

# =============================================================================
# Shell Configuration Functions
# =============================================================================

# Get shell config file path
get_shell_config() {
    local shell_type
    shell_type=$(detect_shell)

    case "$shell_type" in
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
        fish)
            echo "$HOME/.config/fish/config.fish"
            ;;
        *)
            echo "$HOME/.profile"
            ;;
    esac
}

# Add line to shell config if not already present
add_to_shell_config() {
    local line="$1"
    local config_file
    config_file=$(get_shell_config)

    if ! grep -qF "$line" "$config_file" 2>/dev/null; then
        echo "" >> "$config_file"
        echo "$line" >> "$config_file"
        log_debug "Added to $config_file: $line"
        return 0
    else
        log_debug "Already in $config_file: $line"
        return 1
    fi
}

# =============================================================================
# Network Functions
# =============================================================================

# Check internet connectivity
check_internet() {
    if command_exists curl; then
        curl -s --head --connect-timeout 5 https://www.google.com > /dev/null 2>&1
    elif command_exists wget; then
        wget -q --spider --timeout=5 https://www.google.com > /dev/null 2>&1
    else
        # Assume connected if we can't check
        return 0
    fi
}

# Download file with progress
download_file() {
    local url="$1"
    local output="$2"

    if command_exists curl; then
        curl -fsSL "$url" -o "$output"
    elif command_exists wget; then
        wget -q "$url" -O "$output"
    else
        log_error "Neither curl nor wget found"
        return 1
    fi
}

# =============================================================================
# Utility Functions
# =============================================================================

# Compare semantic versions
# Returns: 0 if $1 >= $2, 1 otherwise
version_gte() {
    local v1="$1"
    local v2="$2"

    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"

    # Compare using sort -V
    [ "$(printf '%s\n' "$v2" "$v1" | sort -V | head -n1)" = "$v2" ]
}

# Create temporary directory
create_temp_dir() {
    mktemp -d 2>/dev/null || mktemp -d -t 'cc-bootstrap'
}

# Cleanup function for trap
cleanup() {
    local temp_dir="$1"
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi
}

# Print a horizontal line
print_line() {
    local char="${1:--}"
    local width="${2:-60}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# Ask yes/no question
confirm() {
    local prompt="$1"
    local default="${2:-y}"

    if [ "$default" = "y" ]; then
        prompt="$prompt [Y/n] "
    else
        prompt="$prompt [y/N] "
    fi

    read -p "$prompt" -n 1 -r
    echo

    if [ -z "$REPLY" ]; then
        REPLY="$default"
    fi

    [[ $REPLY =~ ^[Yy]$ ]]
}

# =============================================================================
# Export all functions for subshells
# =============================================================================
export -f log_info log_success log_warning log_error log_step log_debug
export -f detect_os detect_arch detect_shell detect_linux_distro
export -f command_exists check_homebrew check_node check_npm check_claude
export -f get_node_version get_npm_version get_claude_version
export -f get_shell_config add_to_shell_config
export -f check_internet download_file
export -f version_gte create_temp_dir cleanup print_line confirm
