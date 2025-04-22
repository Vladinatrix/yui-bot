#!/bin/bash
#
# maketherpmsfromscratch.sh
# Automates the RPM build process for yui-bot from a clean source state.
# Run this script from the root of the extracted source directory.

# Exit on error, treat unset variables as error, prevent pipeline errors masking
set -euo pipefail

# --- Configuration ---
SPEC_FILE="rpm/yui-bot.spec"
CONFIGURE_FLAGS="--prefix=/usr" # Standard prefix for system RPMs
# List essential commands needed by this script and the build process
REQUIRED_COMMANDS=(
    "autoconf"
    "automake"
    "make"
    "gcc" # Often needed by configure checks
    "rpmbuild"
    "git" # Needed by autoreconf sometimes if using git versions
    "tar"
    "gzip"
    "sed"
    "grep"
    "cat"
)
RPMBUILD_DIR="$HOME/rpmbuild"

# --- Helper Functions ---
msg_info() { echo "[INFO] $1"; }
msg_pass() { echo "[PASS] $1"; }
msg_fail() { echo "[FAIL] $1" >&2; } # Changed to >&2 for errors
msg_error() { echo "[ERROR] $1" >&2; } # Changed to >&2 for errors
ask_confirm() {
    local prompt_msg="$1"
    while true; do
        read -p "$prompt_msg [y/N]: " yn
        case $yn in
            [Yy]* ) return 0;; # Success (Yes)
            [Nn]* | "" ) return 1;; # Failure (No or Enter)
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
}

# --- Prerequisite Check Function ---
check_prerequisites_and_confirm() {
    local prereq_met=true
    msg_info "Checking required tools and environment..."
    echo "Required commands:"
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            echo "  [✓] $cmd"
        else
            echo "  [✗] $cmd  <-- MISSING!"
            prereq_met=false
        fi
    done

    echo "Required RPM build directory structure:"
    if [[ -d "$RPMBUILD_DIR/SPECS" && -d "$RPMBUILD_DIR/SOURCES" ]]; then
        echo "  [✓] $RPMBUILD_DIR/{SPECS,SOURCES} found."
    else
        echo "  [✗] $RPMBUILD_DIR/{SPECS,SOURCES} <-- MISSING!"
        echo "      (Run 'rpmdev-setuptree' to create it)"
        prereq_met=false
    fi

    echo "Required source files:"
    if [[ -f "configure.ac" && -f "Makefile.am" && -f "$SPEC_FILE" ]]; then
         echo "  [✓] configure.ac, Makefile.am, $SPEC_FILE found."
    else
         echo "  [✗] configure.ac, Makefile.am, or $SPEC_FILE <-- MISSING!"
         echo "      (Ensure you are in the correct source directory)"
         prereq_met=false
    fi
    echo "---------------------------------------------"

    if [[ "$prereq_met" = false ]]; then
        msg_error "One or more prerequisites are missing. Please install/create them and re-run."
        exit 1
    fi

    msg_success "All prerequisite checks passed."
    echo "This script will perform the following main steps:"
    echo "  1. Clean previous build artifacts ('make distclean')."
    echo "  2. Regenerate build system ('autoreconf -fi')."
    echo "  3. Run configure script ('./configure ${CONFIGURE_FLAGS}')."
    echo "  4. Ask for manual verification of the generated systemd file."
    echo "  5. Prompt to update the RPM Release number in '$SPEC_FILE'."
    echo "  6. Build the RPM package ('make rpm')."
    echo "---------------------------------------------"

    if ! ask_confirm "Do you want to proceed with these steps?"; then
        msg_info "User chose not to proceed. Exiting."
        exit 0 # Graceful exit if user bails out
    fi
    msg_info "Proceeding with build..."
}


# ============================================================================
# --- Main Script Execution ---
# ============================================================================

# --- Step 0: Prerequisite Check and Confirmation ---
check_prerequisites_and_confirm
echo "============================================="


# --- Step 1: Clean ---
msg_info "Step 1: Cleaning previous build artifacts ('make distclean')..."
if make distclean; then
    msg_success "Cleanup successful."
else
    # If make fails here, it might be because Makefile doesn't exist yet, which is okay after distclean
    msg_info "Cleanup command finished (ignore 'No rule to make target' if it occurred)."
fi
echo "---------------------------------------------"

# --- Step 2: Regenerate Build System ---
msg_info "Step 2: Regenerating build system ('autoreconf -fi')..."
if autoreconf --install --force --verbose; then
    msg_success "autoreconf successful."
else
    msg_error "autoreconf failed. Please check configure.ac/Makefile.am and output."
    exit 1
fi
echo "---------------------------------------------"

# --- Step 3: Configure ---
msg_info "Step 3: Running configure script (using ${CONFIGURE_FLAGS})..."
if ./configure ${CONFIGURE_FLAGS}; then
    msg_success "Configure successful."
    msg_info "Configure output finished. Please carefully review the 'Paths' summary printed by configure."
else
    msg_error "Configure failed. Please check config.log and configure output."
    exit 1
fi
echo "---------------------------------------------"

# --- Step 4: Manual Verification ---
msg_info "Step 4: Verification - Please check the generated systemd service file."
echo "--- Contents of service/yui-bot.service ---"
if ! cat service/yui-bot.service; then
    msg_error "Could not display service/yui-bot.service"
    exit 1;
fi
echo "-------------------------------------------"
if ! ask_confirm "VERIFY: Do 'WorkingDirectory' and 'ExecStart' above contain correct ABSOLUTE paths (e.g., /usr/share/..., /usr/bin/...) and look right?"; then
    msg_error "Verification failed by user. Aborting build."
    msg_error "Please fix configure.ac or service/yui-bot.service.in, then re-run this script."
    exit 1
fi
msg_success "User verification passed."
echo "---------------------------------------------"

# --- Step 5: Update RPM Release Number ---
msg_info "Step 5: Update RPM Release number in $SPEC_FILE"
CURRENT_RELEASE_LINE=$(grep -E '^Release:\s+' "$SPEC_FILE")
# Extract just the number part (handle potential %{?dist})
CURRENT_RELEASE_NUM=$(echo "$CURRENT_RELEASE_LINE" | sed -E 's/^Release:\s+([0-9]+).*/\1/')
if ! [[ "$CURRENT_RELEASE_NUM" =~ ^[0-9]+$ ]]; then
    msg_error "Could not automatically detect current release number from: $CURRENT_RELEASE_LINE"
    ask_confirm "Do you want to manually edit $SPEC_FILE now to set the Release number?"
    if [[ $? -eq 0 ]]; then
        # Try common editors, fallback to nano if EDITOR not set
        "${EDITOR:-nano}" "$SPEC_FILE"
    else
        msg_error "Aborting. Please manually update the Release number in $SPEC_FILE."
        exit 1
    fi
else
    echo "Current Release line: $CURRENT_RELEASE_LINE"
    echo "Detected current release number: $CURRENT_RELEASE_NUM"
    NEW_RELEASE_NUM=""
    DEFAULT_NEW_RELEASE=$((CURRENT_RELEASE_NUM + 1))
    while [[ -z "$NEW_RELEASE_NUM" ]]; do
        read -p "Enter the NEW release number [Default: $DEFAULT_NEW_RELEASE]: " NEW_RELEASE_NUM
        # If user presses Enter, use default
        if [[ -z "$NEW_RELEASE_NUM" ]]; then
            NEW_RELEASE_NUM=$DEFAULT_NEW_RELEASE
        fi
        # Basic validation: check if it's a number
        if ! [[ "$NEW_RELEASE_NUM" =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Please enter a number."
            NEW_RELEASE_NUM="" # Force loop to repeat
        elif [[ "$NEW_RELEASE_NUM" -le "$CURRENT_RELEASE_NUM" ]]; then
             ask_confirm "WARN: New release ($NEW_RELEASE_NUM) is not greater than current ($CURRENT_RELEASE_NUM). Continue anyway?"
             if [[ $? -ne 0 ]]; then
                 NEW_RELEASE_NUM="" # Force loop to repeat
             fi
        fi
    done

    if ! ask_confirm "Update Release in $SPEC_FILE to '$NEW_RELEASE_NUM%{?dist}'?"; then
        msg_error "Aborting build. Release number not updated."
        exit 1
    fi

    # Use sed to replace the release number - make backup just in case
    sed -i.rpmbuild.bak -E "s/^(Release:\s+)[0-9]+(.*)/\1$NEW_RELEASE_NUM\2/" "$SPEC_FILE"
    if [[ $? -ne 0 ]]; then
        msg_error "Failed to update Release in $SPEC_FILE using sed."
        # Optional: restore backup? mv "$SPEC_FILE.rpmbuild.bak" "$SPEC_FILE"
        exit 1
    fi
    rm -f "$SPEC_FILE.rpmbuild.bak" # Clean up backup on success
    msg_success "Release number updated in $SPEC_FILE to $NEW_RELEASE_NUM."
    msg_info "NOTE: Remember to manually add a corresponding %changelog entry later."
fi
echo "---------------------------------------------"

# --- Step 6: Build RPM ---
msg_info "Step 6: Building the RPM package with 'make rpm'..."
# Run make rpm. Output will go to stdout/stderr.
if make rpm; then
    msg_success "RPM build completed successfully!"
    msg_info "Output RPMs should be located in your rpmbuild directory ($RPMBUILD_DIR/RPMS/noarch and $RPMBUILD_DIR/SRPMS)."
else
    msg_error "'make rpm' failed. Please check the build output above for errors."
    exit 1
fi
echo "============================================="
msg_success "Script finished."
exit 0
