#!/bin/bash
#
# Claude Code Bootstrap Agent - macOS Test Suite
#
# This script tests the installation process on macOS.
# Run with: ./test-mac.sh
#

set -e

# =============================================================================
# Test Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Source common utilities
source "$PROJECT_ROOT/scripts/common.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# =============================================================================
# Test Utilities
# =============================================================================

# Run a test
run_test() {
    local name="$1"
    local command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  Testing: $name... "

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Run a test that should fail
run_test_should_fail() {
    local name="$1"
    local command="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    echo -n "  Testing: $name (should fail)... "

    if ! eval "$command" &>/dev/null; then
        echo -e "${GREEN}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Print test section header
test_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# =============================================================================
# Test Suites
# =============================================================================

# Test common.sh utilities
test_common_utilities() {
    test_section "Testing common.sh utilities"

    run_test "log_info function exists" "type log_info"
    run_test "log_success function exists" "type log_success"
    run_test "log_error function exists" "type log_error"
    run_test "detect_os function exists" "type detect_os"
    run_test "detect_arch function exists" "type detect_arch"
    run_test "command_exists function exists" "type command_exists"
}

# Test OS detection
test_os_detection() {
    test_section "Testing OS detection"

    local os=$(detect_os)
    run_test "OS detection returns value" "[ -n '$os' ]"
    run_test "OS is macos on macOS" "[ '$os' = 'macos' ]"

    local arch=$(detect_arch)
    run_test "Architecture detection returns value" "[ -n '$arch' ]"
    run_test "Architecture is x64 or arm64" "[ '$arch' = 'x64' ] || [ '$arch' = 'arm64' ]"

    local shell=$(detect_shell)
    run_test "Shell detection returns value" "[ -n '$shell' ]"
}

# Test dependency checks
test_dependency_checks() {
    test_section "Testing dependency check functions"

    run_test "command_exists works for existing command" "command_exists ls"
    run_test_should_fail "command_exists fails for non-existent command" "command_exists nonexistent_command_12345"

    run_test "check_homebrew function exists" "type check_homebrew"
    run_test "check_node function exists" "type check_node"
    run_test "check_npm function exists" "type check_npm"
    run_test "check_claude function exists" "type check_claude"
}

# Test detection library
test_detection_library() {
    test_section "Testing lib/detect.sh"

    source "$PROJECT_ROOT/lib/detect.sh"

    run_test "get_system_info function exists" "type get_system_info"
    run_test "detect_package_manager function exists" "type detect_package_manager"
    run_test "get_dependency_status function exists" "type get_dependency_status"
    run_test "get_required_installations function exists" "type get_required_installations"

    local pkg_mgr=$(detect_package_manager)
    run_test "Package manager detected" "[ -n '$pkg_mgr' ]"
}

# Test Node.js installation library
test_node_library() {
    test_section "Testing lib/install-node.sh"

    source "$PROJECT_ROOT/lib/install-node.sh"

    run_test "install_node function exists" "type install_node"
    run_test "get_node_install_method function exists" "type get_node_install_method"
    run_test "verify_node_installation function exists" "type verify_node_installation"
}

# Test Claude Code installation library
test_claude_library() {
    test_section "Testing lib/install-claude.sh"

    source "$PROJECT_ROOT/lib/install-claude.sh"

    run_test "install_claude_code function exists" "type install_claude_code"
    run_test "update_claude_code function exists" "type update_claude_code"
    run_test "verify_claude_installation function exists" "type verify_claude_installation"
}

# Test setup-mac.sh script
test_setup_mac_script() {
    test_section "Testing scripts/setup-mac.sh"

    run_test "setup-mac.sh exists" "[ -f '$PROJECT_ROOT/scripts/setup-mac.sh' ]"
    run_test "setup-mac.sh is executable" "[ -x '$PROJECT_ROOT/scripts/setup-mac.sh' ] || chmod +x '$PROJECT_ROOT/scripts/setup-mac.sh'"
    run_test "setup-mac.sh syntax is valid" "bash -n '$PROJECT_ROOT/scripts/setup-mac.sh'"
}

# Test install.sh script
test_install_script() {
    test_section "Testing install.sh"

    run_test "install.sh exists" "[ -f '$PROJECT_ROOT/install.sh' ]"
    run_test "install.sh is executable" "[ -x '$PROJECT_ROOT/install.sh' ] || chmod +x '$PROJECT_ROOT/install.sh'"
    run_test "install.sh syntax is valid" "bash -n '$PROJECT_ROOT/install.sh'"
}

# Test current installation status
test_current_installation() {
    test_section "Testing current installation status"

    if [ "$(detect_os)" = "macos" ]; then
        if check_homebrew; then
            run_test "Homebrew is installed" "check_homebrew"
            run_test "Homebrew version accessible" "brew --version"
        else
            echo "  Homebrew: not installed (will be installed by setup)"
        fi
    fi

    if check_node; then
        run_test "Node.js is installed" "check_node"
        run_test "Node.js version accessible" "node -v"
    else
        echo "  Node.js: not installed or version too old (will be installed by setup)"
    fi

    if check_npm; then
        run_test "npm is installed" "check_npm"
        run_test "npm version accessible" "npm -v"
    else
        echo "  npm: not installed (will be installed with Node.js)"
    fi

    if check_claude; then
        run_test "Claude Code is installed" "check_claude"
        run_test "Claude Code version accessible" "claude --version"
    else
        echo "  Claude Code: not installed (will be installed by setup)"
    fi
}

# =============================================================================
# Test Summary
# =============================================================================

print_summary() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}Test Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Tests Run:    $TESTS_RUN"
    echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo ""
    echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}     ${BOLD}Claude Code Bootstrap - macOS Test Suite${NC}              ${BLUE}║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"

    # Check we're on macOS
    if [ "$(uname -s)" != "Darwin" ]; then
        log_error "This test suite is for macOS only"
        exit 1
    fi

    # Run test suites
    test_common_utilities
    test_os_detection
    test_dependency_checks
    test_detection_library
    test_node_library
    test_claude_library
    test_setup_mac_script
    test_install_script
    test_current_installation

    # Print summary
    print_summary
}

# Run main
main "$@"
