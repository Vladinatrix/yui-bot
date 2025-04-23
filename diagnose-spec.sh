#!/bin/bash
#
# diagnose-spec-v6.sh
# Attempts to isolate rpmbuild parsing errors by incrementally rebuilding
# the spec file, replacing minimal sections with full sections one by one,
# using corrected section extraction logic.
# Assumes it's run from the yui-bot project root.

set -euo pipefail

SPEC_SOURCE_FILE="rpm/yui-bot.spec" # User's current file
SPEC_FULL_BACKUP="rpm/yui-bot.spec.full_backup" # Backup of user's file
SPEC_MINIMAL_FILE="rpm/yui-bot.spec.minimal_backup" # Backup of minimal spec
SPEC_TEST_FILE="rpm/yui-bot.spec.test" # File we modify and test
# Adjust version if needed, should match Source0 in your full spec
# Use the version from the last known good full spec (1.3.17-5)
SOURCE_TARBALL_VERSION="1.3.17"
SOURCE_TARBALL_PATTERN="$HOME/rpmbuild/SOURCES/yui-bot-${SOURCE_TARBALL_VERSION}.tar.gz"
RPMBUILD="rpmbuild"

# --- Helper Functions ---
msg_info() { echo "[INFO] $1"; }
msg_pass() { echo "[PASS] $1"; }
msg_fail() { echo "[FAIL] $1" >&2; }
msg_error() { echo "[ERROR] $1" >&2; }

# --- Check Prerequisites ---
msg_info "Checking prerequisites..."
if ! command -v "$RPMBUILD" &>/dev/null; then
    msg_error "'rpmbuild' command not found. Please install rpm-build."
    exit 1
fi
if ! ls $SOURCE_TARBALL_PATTERN &>/dev/null; then
    msg_error "Source tarball matching '$SOURCE_TARBALL_PATTERN' not found."
    msg_error "Please ensure 'make dist' has run and the tarball is in ~/rpmbuild/SOURCES/."
    exit 1
fi
if [ ! -f "$SPEC_SOURCE_FILE" ]; then
     msg_error "Source spec file '$SPEC_SOURCE_FILE' not found."
     exit 1
fi
msg_info "Backing up current '$SPEC_SOURCE_FILE' to '$SPEC_FULL_BACKUP' (if different)..."
if ! cmp -s "$SPEC_SOURCE_FILE" "$SPEC_FULL_BACKUP" &>/dev/null ; then
    cp -f "$SPEC_SOURCE_FILE" "$SPEC_FULL_BACKUP"
    msg_info "Backup created/updated."
else
    msg_info "Backup '$SPEC_FULL_BACKUP' already matches current spec."
fi

# --- Define Content Blocks (Minimal - Adjusted for Correct Initial Structure) ---
MIN_GLOBALS=$(cat << 'EOF'
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# Minimal RPM Spec file for yui-bot

%global app_name yui-bot
EOF
)
MIN_HEADER=$(cat << EOF
Name:           %{app_name}
Version:        ${SOURCE_TARBALL_VERSION}
Release:        99%{?dist}
Summary:        Minimal test
License:        BSD-2-Clause
Source0:        %{name}-%{version}.tar.gz
BuildArch:      noarch
EOF
)
MIN_BUILDREQ=""
MIN_REQ=""
MIN_DESC=$(cat << 'EOF'
%description
Minimal test spec.
EOF
)
MIN_PREP=$(cat << 'EOF'
%prep
%autosetup -n %{name}-%{version} -p1
EOF
)
MIN_BUILD=$(cat << 'EOF'
%build
# Minimal build section - echo only
echo "Minimal build section for test"
EOF
)
MIN_INSTALL=$(cat << 'EOF'
%install
# Minimal install section - create buildroot, copy README
rm -rf %{buildroot}
mkdir -p %{buildroot}%{_docdir}/%{app_name}/
# Use _builddir macro which rpmbuild defines internally
install -m 644 %{_builddir}/%{name}-%{version}/README.md %{buildroot}%{_docdir}/%{app_name}/
EOF
)
MIN_SCRIPTLETS="" # Minimal spec has no scriptlets between %install and %files
MIN_FILES=$(cat << 'EOF'
%files
%doc %{_docdir}/%{app_name}/README.md
EOF
)
MIN_CHANGELOG=$(cat << 'EOF'
%changelog
* Sun Apr 20 2025 Test User <test@example.com> - 1.3.17-99
- Minimal spec for testing rpmbuild parsing.
EOF
)
# Save this minimal version content to the backup minimal file
{
    printf '%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n\n%s\n' \
        "$MIN_GLOBALS" "$MIN_HEADER" "$MIN_BUILDREQ" "$MIN_REQ" \
        "$MIN_DESC" "$MIN_PREP" "$MIN_BUILD" "$MIN_INSTALL" \
        "$MIN_SCRIPTLETS" "$MIN_FILES" "$MIN_CHANGELOG"
} > "$SPEC_MINIMAL_FILE"
msg_pass "Minimal spec structure generated and saved to $SPEC_MINIMAL_FILE."
echo "---"


# --- Define Content Blocks (Full - Target Version 1.3.18 logic) ---
# Extract content from the FULL backup file using corrected AWK patterns

msg_info "Extracting sections from full spec file '$SPEC_FULL_BACKUP'..."
FULL_GLOBALS=$(awk '/^# Copyright/,!/^%global/ {next} /^%global/ {p=1} /^Name:/ {p=0} p' "$SPEC_FULL_BACKUP")
FULL_HEADER=$(awk '/^Name:/,/^BuildArch:/ {print}' "$SPEC_FULL_BACKUP")
FULL_BUILDREQ=$(awk '/^# Build time dependencies/,/^# Runtime dependencies/ { if ($0 !~ /^# Build time/ && $0 !~ /^# Runtime/) print }' "$SPEC_FULL_BACKUP")
FULL_REQ=$(awk '/^# Runtime dependencies/,/^%description/ { if ($0 !~ /^# Runtime/ && $0 !~ /^%description/) print }' "$SPEC_FULL_BACKUP")
# Corrected extraction for sections needing the marker
FULL_DESC=$(awk '/^%description$/{p=1} /^%prep$/{p=0} p && !/^%prep$/' "$SPEC_FULL_BACKUP")
FULL_PREP=$(awk '/^%prep$/{p=1} /^%build$/{p=0} p && !/^%build$/' "$SPEC_FULL_BACKUP")
FULL_BUILD=$(awk '/^%build$/{p=1} /^%install$/{p=0} p && !/^%install$/' "$SPEC_FULL_BACKUP")
FULL_INSTALL=$(awk '/^%install$/{p=1} /^%pre[[:space:]]/{p=0} p && $0 !~ /^%pre[[:space:]]/' "$SPEC_FULL_BACKUP") # Stop before %pre line
FULL_SCRIPTLETS=$(awk '/^%pre[[:space:]]/{p=1} /^%files$/{p=0} p && !/^%files$/' "$SPEC_FULL_BACKUP") # Include %pre, stop before %files
FULL_FILES=$(awk '/^%files$/{p=1} /^%changelog$/{p=0} p && !/^%changelog$/' "$SPEC_FULL_BACKUP")
FULL_CHANGELOG=$(awk '/^%changelog$/ { f=1 } f' "$SPEC_FULL_BACKUP") # Corrected AWK command
msg_pass "Section extraction complete."
echo "---"


# --- Array defining the order and content mapping ---
declare -a SECTIONS_ORDER=(
    "Header Globals"
    "Header Tags"
    "BuildRequires"
    "Requires"
    "%description"
    "%prep"
    "%build"
    "%install"
    "Scriptlets" # Combined %pre, %post, %preun, %postun
    "%files"
    "%changelog"
)

declare -A CURRENT_CONTENT # Holds the content for the current test iteration

# Initialize with minimal content first
CURRENT_CONTENT["Header Globals"]="$MIN_GLOBALS"
CURRENT_CONTENT["Header Tags"]="$MIN_HEADER"
CURRENT_CONTENT["BuildRequires"]="$MIN_BUILDREQ"
CURRENT_CONTENT["Requires"]="$MIN_REQ"
CURRENT_CONTENT["%description"]="$MIN_DESC"
CURRENT_CONTENT["%prep"]="$MIN_PREP"
CURRENT_CONTENT["%build"]="$MIN_BUILD"
CURRENT_CONTENT["%install"]="$MIN_INSTALL"
CURRENT_CONTENT["Scriptlets"]="$MIN_SCRIPTLETS"
CURRENT_CONTENT["%files"]="$MIN_FILES"
CURRENT_CONTENT["%changelog"]="$MIN_CHANGELOG"

# --- Function to Build and Test Spec ---
build_and_test() {
    local test_description="$1"
    msg_info "Testing spec configuration: $test_description"

    # Assemble the spec file content for this test
    echo -n "" > "$SPEC_TEST_FILE" # Clear the test file
    for section_key in "${SECTIONS_ORDER[@]}"; do
        # Add section content only if it's not empty for this test stage
        if [[ -n "${CURRENT_CONTENT[$section_key]}" ]]; then
             # Add extra newline between sections for clarity
             printf '%s\n\n' "${CURRENT_CONTENT[$section_key]}" >> "$SPEC_TEST_FILE"
        fi
    done
    # Remove potentially excessive trailing newlines
    perl -i -pe 'chomp if eof' "$SPEC_TEST_FILE"

    # Run rpmbuild -bs
    set +e
    local build_output
    build_output=$($RPMBUILD -bs "$SPEC_TEST_FILE" 2>&1) # Capture stdout and stderr
    local build_status=$?
    set -e

    if [ $build_status -eq 0 ]; then
        msg_pass "SUCCESS: Spec parsed correctly with '$test_description'."
        return 0
    else
        msg_error ">>> FAILED while parsing spec with '$test_description'! (Exit Status: $build_status) <<<"
        msg_error "The error likely relates to the content of section '$test_description' or its interaction."
        msg_error "Problematic spec file content is in '$SPEC_TEST_FILE'."
         if [ -n "$build_output" ]; then
             echo "--- rpmbuild Output ---" >&2
             echo "$build_output" >&2
             echo "---------------------------" >&2
         fi
        # Restore original file from backup before exiting
        msg_info "Restoring original spec file from '$SPEC_FULL_BACKUP'..."
        cp -f "$SPEC_FULL_BACKUP" "$SPEC_SOURCE_FILE"
        # Keep the failed test file for inspection
        return 1
    fi
}

# --- Main Test Loop ---
msg_info "Starting incremental spec file reconstruction test..."
echo "Will replace minimal sections with full sections one by one and run 'rpmbuild -bs'."
echo "---"

# Baseline check with minimal content assembled
build_and_test "Baseline Minimal Spec" || exit 1
echo "---"

# Loop through sections, replacing minimal with full one at a time
BUILD_OK=true
for section in "${SECTIONS_ORDER[@]}"; do
    # Determine the correct variable name for the full content
    full_content_var_name=""
     case "$section" in
        "Header Globals") full_content_var_name="FULL_GLOBALS" ;;
        "Header Tags") full_content_var_name="FULL_HEADER" ;;
        "BuildRequires") full_content_var_name="FULL_BUILDREQ" ;;
        "Requires") full_content_var_name="FULL_REQ" ;;
        "%description") full_content_var_name="FULL_DESC" ;;
        "%prep") full_content_var_name="FULL_PREP" ;;
        "%build") full_content_var_name="FULL_BUILD" ;;
        "%install") full_content_var_name="FULL_INSTALL" ;;
        "Scriptlets") full_content_var_name="FULL_SCRIPTLETS" ;;
        "%files") full_content_var_name="FULL_FILES" ;;
        "%changelog") full_content_var_name="FULL_CHANGELOG" ;;
        *) msg_error "Unknown section name '$section' in loop!"; exit 1 ;;
    esac
    full_content="${!full_content_var_name}" # Indirect variable expansion

    msg_info "Replacing content for section '$section' with full version..."

    # Replace content in our test array
    CURRENT_CONTENT["$section"]="$full_content"

    # Test the build with the newly replaced section
    if ! build_and_test "$section"; then
        BUILD_OK=false
        break # Stop on first failure
    fi
    echo "---"
done

# --- Final Outcome ---
echo "============================================="
if $BUILD_OK; then
    msg_pass "Successfully replaced all sections - the full spec file parsed correctly with 'rpmbuild -bs'."
    msg_info "The file '$SPEC_TEST_FILE' contains the reconstructed, working content."
    msg_info "You can now copy '$SPEC_TEST_FILE' to '$SPEC_SOURCE_FILE' and run 'make rpm'."
    msg_info "Replacing '$SPEC_SOURCE_FILE' with the successful test version..."
    cp -f "$SPEC_TEST_FILE" "$SPEC_SOURCE_FILE"
    rm -f "$SPEC_TEST_FILE" # Clean up test file on success
else
    msg_fail "Incremental build failed. Problem section identified above."
    msg_info "The file '$SPEC_TEST_FILE' contains the spec content *up to the point of failure*."
fi
 msg_info "(Your original spec file is backed up as '$SPEC_FULL_BACKUP')"
echo "============================================="

exit 0
