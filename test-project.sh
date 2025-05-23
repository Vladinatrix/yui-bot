#!/bin/bash
#
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# Test script for the yui-bot project.
# Runs syntax checks, build checks, packaging checks,
# and attempts to install missing prerequisites via 'sudo dnf'.
# Run this script from the project's root directory.

# Exit immediately if a command exits with a non-zero status (except where handled).
set -e
# Treat unset variables as an error.
set -u
# Prevent errors in pipelines from being masked.
set -o pipefail

# --- Helper Functions ---
log_info() { echo "[INFO] $1"; }
log_pass() { echo "[PASS] $1"; }
log_fail() { echo "[FAIL] $1" >&2; }
log_warn() { echo "[WARN] $1"; }

# --- Configuration ---
PYTHON_SCRIPT="yui_bot.py"
CONFIG_SCRIPT="configure-yui-bot.py"
SPEC_FILE="rpm/yui-bot.spec"
REQ_FILE="requirements.txt"
CONFIGURE_SCRIPT="./configure" # Generated by autoreconf
TEST_FAILURES=0

# --- Prerequisite Checks & Installation ---
# Associative array for command-to-package mapping (Requires Bash 4+)
declare -A CMD_TO_PKG
CMD_TO_PKG=(
    [python3]="python3"
    [pip3]="python3-pip"
    [autoconf]="autoconf"
    [automake]="automake"
    [make]="make"
    [gcc]="gcc" # Often needed for configure/make checks
    [rpmlint]="rpmlint"
    [pkg-config]="pkgconf-pkg-config" # Provides pkg-config on RHEL/Fedora
    [git]="git" # Needed for some git commands in other scripts
    [tar]="tar" # Needed for make distcheck
    [gzip]="gzip" # Needed for make distcheck
)

check_and_install_command() {
    local cmd="$1"
    local pkg="${CMD_TO_PKG[$cmd]:-}" # Use :- to avoid error if key not found

    # Check if command exists
    if command -v "$cmd" > /dev/null 2>&1; then
        log_info "Prerequisite '$cmd' found."
        return 0 # Command exists
    fi

    # Command not found, attempt install
    if [ -z "$pkg" ]; then
        log_fail "Required command '$cmd' not found, and package name unknown. Please install manually."
        TEST_FAILURES=$((TEST_FAILURES + 1))
        return 1
    fi

    log_warn "Prerequisite '$cmd' not found. Attempting installation of '$pkg' using 'sudo dnf'."
    echo "--> This script will now run 'sudo dnf -y install $pkg'."
    echo "--> You may be prompted for your sudo password if not recently entered."
    sleep 2 # Brief pause for user to see message

    # Temporarily disable exit on error for the sudo command
    set +e
    sudo dnf -y install "$pkg"
    local INSTALL_STATUS=$?
    set -e # Re-enable exit on error

    if [ $INSTALL_STATUS -eq 0 ]; then
        # Verify command exists *now* after installation
        if command -v "$cmd" > /dev/null 2>&1; then
            log_pass "Successfully installed '$pkg' providing '$cmd'."
            return 0
        else
            log_fail "Package '$pkg' installed, but command '$cmd' still not found in PATH immediately after. Check package contents or PATH."
            TEST_FAILURES=$((TEST_FAILURES + 1))
            return 1
        fi
    else
        log_fail "Failed to install '$pkg' using 'sudo dnf' (Exit Status: $INSTALL_STATUS)."
        log_fail "Please try installing '$pkg' manually and ensure user has sudo privileges for dnf."
        TEST_FAILURES=$((TEST_FAILURES + 1))
        return 1
    fi
}

log_info "Checking prerequisites and attempting auto-install if needed..."
ALL_PREREQS_MET=true
# Check commands in a sensible order
for cmd in python3 pip3 git autoconf automake make gcc pkg-config rpmlint tar gzip; do
    if ! check_and_install_command "$cmd"; then
        ALL_PREREQS_MET=false
    fi
done

if ! $ALL_PREREQS_MET; then
    log_fail "One or more prerequisites could not be found or installed. Aborting tests."
    exit 1
fi
log_pass "All checked prerequisites appear to be met."
echo "-------------------------------------"


# --- Python Syntax and Basic Checks ---
test_python_syntax() {
    log_info "Checking Python script syntax..."
    local check_failed=0
    if ! python3 -m py_compile "$PYTHON_SCRIPT"; then
        log_fail "Syntax check failed for $PYTHON_SCRIPT"
        check_failed=1
    fi
    if ! python3 -m py_compile "$CONFIG_SCRIPT"; then
        log_fail "Syntax check failed for $CONFIG_SCRIPT"
        check_failed=1
    fi
    if [ $check_failed -eq 0 ]; then
        log_pass "Python syntax checks passed."
    else
        TEST_FAILURES=$((TEST_FAILURES + 1))
    fi

    log_info "Checking Python dependency consistency..."
    if pip3 check &> /dev/null; then # Suppress normal output unless error
         log_pass "pip check reported no major inconsistencies."
    else
         log_warn "pip check reported potential dependency inconsistencies. Run 'pip3 check' manually."
         # Don't fail test script for this
    fi
}

# --- Autotools Build System Checks ---
run_autotools_checks() {
    log_info "Running Autotools checks (autoreconf, configure, make distcheck)..."
    # 1. Regenerate build system files
    log_info "Running autoreconf..."
    if autoreconf --install --force --verbose; then
        log_pass "autoreconf completed."
    else
        log_fail "autoreconf failed. Check configure.ac and Makefile.am."
        TEST_FAILURES=$((TEST_FAILURES + 1)); return 1
    fi

    # 2. Run configure
    log_info "Running configure..."
    if "$CONFIGURE_SCRIPT" --quiet; then
         log_pass "configure completed."
    else
         log_fail "configure failed. Check config.log for details."
         TEST_FAILURES=$((TEST_FAILURES + 1)); return 1
    fi

    # 3. Run make distcheck
    log_info "Running 'make distcheck' (This may take a while)..."
    if make distcheck; then
    log_pass "'make distcheck' completed successfully."
    else
    log_fail "'make distcheck' failed. Review output above for errors."
    TEST_FAILURES=$((TEST_FAILURES + 1))
    # Cleanup before returning failure
    log_info "Running 'make clean' after distcheck failure..."
    make clean > /dev/null 2>&1 || true # Try to clean, ignore errors
    return 1 # <--- Return 1 on failure
    fi
    # Cleanup on success
    log_info "Running 'make clean' after successful distcheck..."
    make clean > /dev/null
    return 0 # Return 0 on success
}

# --- RPM Spec File Linting ---
check_specfile() {
    log_info "Checking RPM spec file syntax with rpmlint..."
    if [ ! -f "$SPEC_FILE" ]; then log_fail "RPM Spec file '$SPEC_FILE' not found"; TEST_FAILURES=$((TEST_FAILURES + 1)); return; fi

    # Ignore exit status 1 which often means only warnings were found
    if RPMLINT_OUTPUT=$(rpmlint "$SPEC_FILE" 2>&1); then
        log_pass "rpmlint check passed for $SPEC_FILE (or only warnings)."
    elif [ $? -eq 1 ]; then
         log_warn "rpmlint check for $SPEC_FILE produced warnings. Review output:"
         echo "$RPMLINT_OUTPUT"
    else
        RPMLINT_STATUS=$?
        log_fail "rpmlint check failed for $SPEC_FILE (Exit Status: $RPMLINT_STATUS)."
        echo "--- rpmlint Output ---"; echo "$RPMLINT_OUTPUT"; echo "----------------------"
        TEST_FAILURES=$((TEST_FAILURES + 1))
    fi
}

# --- Configuration Script Basic Checks ---
check_config_script() {
     log_info "Performing basic checks on configuration script ($CONFIG_SCRIPT)..."

     # --- Ensure User/Group Exist for Test ---
     log_info "Ensuring prerequisite user/group 'yui-bot' exists for test..."
     local CREATE_FAILED=0
     set +e # Disable exit on error for checks and potential sudo commands
     getent group yui-bot > /dev/null
     if [ $? -ne 0 ]; then
         log_info "Group 'yui-bot' not found, attempting creation..."
         sudo groupadd -r yui-bot
         if [ $? -ne 0 ]; then log_fail "Failed to create group 'yui-bot'."; CREATE_FAILED=1; fi
     fi
     if [ $CREATE_FAILED -eq 0 ]; then
         getent passwd yui-bot > /dev/null
         if [ $? -ne 0 ]; then
             log_info "User 'yui-bot' not found, attempting creation..."
             sudo useradd -r -g yui-bot -s /sbin/nologin -c "Yui Bot Test Account" yui-bot
             if [ $? -ne 0 ]; then log_fail "Failed to create user 'yui-bot'."; CREATE_FAILED=1; fi
         fi
     fi
     set -e # Re-enable exit on error
     if [ $CREATE_FAILED -ne 0 ]; then
         log_fail "Could not ensure user/group prerequisites for config script test. Skipping execution test."
         TEST_FAILURES=$((TEST_FAILURES + 1))
         return # Skip the actual test run
     fi
     # --- End User/Group Creation ---

     # Check if it runs and prints help message *with sudo* as intended
     log_info "Running config script --help check with sudo..."
     set +e
     # Run python3 directly as sudo can change PATH/environment
     SUDO_PYTHON=$(command -v python3)
     sudo "$SUDO_PYTHON" "$CONFIG_SCRIPT" --help > /dev/null 2>&1
     local HELP_EXIT_CODE=$?
     set -e

     if [ $HELP_EXIT_CODE -eq 0 ]; then
         log_pass "$CONFIG_SCRIPT --help executes successfully with sudo."
     else
         log_fail "$CONFIG_SCRIPT --help failed to execute with sudo (Exit Code: $HELP_EXIT_CODE)."
         TEST_FAILURES=$((TEST_FAILURES + 1))
     fi
}


# --- Run Tests ---
log_info "Starting Project Tests for ${PWD##*/}"
echo "====================================="

test_python_syntax
echo "====================================="

# Run autotools checks - capture overall result
AUTOTOOLS_OK=true
if ! run_autotools_checks; then
    AUTOTOOLS_OK=false # Error already logged by function
fi
echo "====================================="

check_specfile
echo "====================================="

check_config_script
echo "====================================="

# --- Final Summary ---
log_info "Test Execution Summary"
if [ $TEST_FAILURES -eq 0 ] && $AUTOTOOLS_OK; then
    log_pass "All checks passed!"
    exit 0
else
    log_fail "${TEST_FAILURES} explicit check(s) failed. Autotools checks also may have failed (review output)."
    exit 1
fi
