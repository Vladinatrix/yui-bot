#!/bin/bash
#
# apply-final-fixes.sh
# Overwrites key yui-bot project files with the final corrected versions
# corresponding to v1.3.18 state after troubleshooting.
# Run this script from the project's root directory.

set -euo pipefail

# --- Helper Functions ---
msg_info() { echo "[INFO] $1"; }
msg_pass() { echo "[PASS] $1"; }
msg_error() { echo "[ERROR] $1" >&2; }
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

# --- Confirmation ---
echo "*** WARNING: This script will overwrite the following files ***"
echo "    configure.ac"
echo "    Makefile.am"
echo "    rpm/yui-bot.spec"
echo "    service/yui-bot.service.in"
echo "    service/yui-bot.initd.in"
echo "    configure-yui-bot.py"
echo "    test-project.sh"
echo "    README.md"
echo "in the current directory: $PWD"
echo "Make sure you have backed up any custom changes!"
echo ""
if ! ask_confirm "Do you want to proceed?"; then
    msg_info "Aborted by user."
    exit 1
fi

# --- Create directories if they don't exist ---
msg_info "Ensuring rpm and service directories exist..."
mkdir -p rpm service

# --- Overwrite Files ---

# configure.ac (Version 1.3.18 - Includes RuntimeDirectory logic support)
msg_info "Writing configure.ac (v1.3.18)..."
cat > configure.ac << 'EOF'
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
dnl Process this file with autoconf to produce a configure script.
#
AC_PREREQ([2.69])
# Initialize package info (Version 1.3.18 - RuntimeDirectory fix)
AC_INIT([yui-bot], [1.3.18], [stacy@guppylog.com])
AC_CONFIG_SRCDIR([yui_bot.py])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
dnl AC_CONFIG_MACRO_DIRS([m4]) # Not using custom macros

# --- Checks for Programs ---
AC_PROG_INSTALL
AC_PROG_MKDIR_P

AC_CHECK_PROG([PYTHON3], [python3], [python3], [], [/usr/bin:/usr/local/bin])
if test "x$PYTHON3" = "x"; then echo "configure: error: python3 interpreter not found" >&2; exit 1; fi

AC_CHECK_PROG([PIP3], [pip3], [pip3], [], [/usr/bin:/usr/local/bin])
# Optional: uncomment error if pip3 becomes essential for build/install
# if test "x$PIP3" = "x"; then echo "configure: error: pip3 command not found" >&2; exit 1; fi

AC_CHECK_PROG([GROUPADD], [groupadd], [/usr/sbin/groupadd])
if test "x$GROUPADD" = "x"; then echo "configure: error: groupadd command not found" >&2; exit 1; fi

AC_CHECK_PROG([USERADD], [useradd], [/usr/sbin/useradd])
if test "x$USERADD" = "x"; then echo "configure: error: useradd command not found" >&2; exit 1; fi

AC_CHECK_PROG([PKG_CONFIG], [pkg-config], [pkg-config])

# --- Systemd Check ---
have_systemd=no
if test "x$PKG_CONFIG" != "x"; then
    PKG_CHECK_MODULES([SYSTEMD], [systemd], [have_systemd=yes], [AC_MSG_WARN([systemd pkg-config files not found, systemd support may be limited])])
fi
AM_CONDITIONAL([HAVE_SYSTEMD], [test "x$have_systemd" = "xyes"])

# --- Define Installation User/Group ---
AC_ARG_WITH([user], [AS_HELP_STRING([--with-user=USER], [Runtime user (default: yui-bot)])], [installuser="$withval"], [installuser="yui-bot"])
AC_ARG_WITH([group], [AS_HELP_STRING([--with-group=GROUP], [Runtime group (default: yui-bot)])], [installgroup="$withval"], [installgroup="yui-bot"])
AC_SUBST([installuser])
AC_SUBST([installgroup])

# --- Define Installation Paths ---
AC_PREFIX_DEFAULT([/usr])
AC_PROG_LN_S # Needed for AC_SUBST(LN_S) below

# Define standard directories based on prefix/defaults
AC_SUBST([sysconfdir])
AC_SUBST([localstatedir])
AC_SUBST([runstatedir])
AC_SUBST([libdir])
AC_SUBST([datadir])
AC_SUBST([datarootdir])

# Adjust standard directories if prefix is /usr
AS_IF([test "x$prefix" = "x/usr" || test "x${prefix}" = "xNONE"],
      [ AC_SUBST([sysconfdir], [/etc])
        AC_SUBST([localstatedir], [/var])
        AC_SUBST([runstatedir], ['${localstatedir}/run']) ])

# Define application-specific directories based on standard ones
# Use simple substitution variables that templates will use
pkgdatadir='${datadir}/${PACKAGE_NAME}'
AC_SUBST([pkgdatadir])

AC_ARG_WITH([rundir], [AS_HELP_STRING([--with-rundir=DIR], [Runtime dir (default: ${runstatedir}/${PACKAGE_NAME})])], [apprundir_arg="$withval"], [apprundir_arg='${runstatedir}/${PACKAGE_NAME}'])
AC_SUBST([apprundir], [$apprundir_arg]) # Substitute the final value

AC_ARG_WITH([confdir], [AS_HELP_STRING([--with-confdir=DIR], [Config dir (default: ${sysconfdir}/${PACKAGE_NAME})])], [appconfdir_arg="$withval"], [appconfdir_arg='${sysconfdir}/${PACKAGE_NAME}'])
AC_SUBST([appconfdir], [$appconfdir_arg]) # Substitute the final value

pidfile='${apprundir}/${PACKAGE_NAME}.pid' # Define using the shell variable that gets substituted
envfile='${appconfdir}/.env' # Define using the shell variable that gets substituted
AC_SUBST([pidfile], [$pidfile])
AC_SUBST([envfile], [$envfile])

# Substitute other needed variables
AC_SUBST([PYTHON3])
AC_SUBST([LN_S])

# --- Systemd Unit Directory (Variable still needed for spec file/hooks) ---
systemd_unitdir=""; if test "x$have_systemd" = "xyes"; then systemd_unitdir=`$PKG_CONFIG --variable=systemdsystemunitdir systemd`; if test "x$systemd_unitdir" = "x"; then systemd_unitdir="${libdir}/systemd/system"; fi; else systemd_unitdir="${libdir}/systemd/system"; fi
AC_SUBST([systemd_unitdir])

# --- Output Files ---
AC_CONFIG_FILES([ Makefile service/yui-bot.service service/yui-bot.initd ])
AC_OUTPUT

# --- Final Summary Output ---
# Evaluate paths fully after substitutions are prepared
eval eval_pkgdatadir=$pkgdatadir
eval eval_apprundir=$apprundir
eval eval_appconfdir=$appconfdir
eval eval_pidfile=$pidfile
eval eval_envfile=$envfile
eval eval_systemd_unitdir=$systemd_unitdir

AC_MSG_NOTICE([ ])
AC_MSG_NOTICE([=======================================================])
AC_MSG_NOTICE([ yui-bot ${VERSION} Configuration Summary])
AC_MSG_NOTICE([=======================================================])
AC_MSG_NOTICE([ Installation prefix:       ${prefix}])
AC_MSG_NOTICE([ Data directory (@pkgdatadir@):    ${eval_pkgdatadir}])
AC_MSG_NOTICE([ Config directory (@appconfdir@): ${eval_appconfdir}])
AC_MSG_NOTICE([ Runtime directory (@apprundir@): ${eval_apprundir}])
AC_MSG_NOTICE([ PID file (@pidfile@):        ${eval_pidfile}])
AC_MSG_NOTICE([ Environment file (@envfile@): ${eval_envfile}])
AC_MSG_NOTICE([ Systemd unit directory:    ${eval_systemd_unitdir} (if enabled)])
AC_MSG_NOTICE([ Python executable (@PYTHON3@): ${PYTHON3}])
AC_MSG_NOTICE([ Run user/group:            ${installuser} / ${installgroup}])
AC_MSG_NOTICE([-------------------------------------------------------])
AC_MSG_NOTICE([ Run 'make rpm' to build the RPM package.])
AC_MSG_NOTICE([=======================================================])
EOF
msg_pass "configure.ac written."

# Makefile.am (Version 1.3.17 logic - install service to pkgdata, fixed echoes)
msg_info "Writing Makefile.am..."
cat > Makefile.am << 'EOF'
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# Process this file with automake to produce Makefile.in

ACLOCAL_AMFLAGS = -I m4

# --- Explicit Default Target ---
all:

# --- Files to be installed ---
pkgdatadir = $(datarootdir)/$(PACKAGE_NAME)
dist_pkgdata_SCRIPTS = yui_bot.py
# Add the *generated* service file to pkgdata if systemd is enabled
if HAVE_SYSTEMD
dist_pkgdata_DATA = requirements.txt yui-bot.env.example LICENSE README.md service/yui-bot.service
else
dist_pkgdata_DATA = requirements.txt yui-bot.env.example LICENSE README.md
endif

# Install the Python configuration helper script to sbin
sbin_SCRIPTS = configure-yui-bot.py

# --- Files included in dist tarball ---
EXTRA_DIST = \
    configure.ac \
    Makefile.am \
    service/yui-bot.service.in \
    service/yui-bot.initd.in \
    rpm/yui-bot.spec \
    LICENSE \
    README.md \
    configure-yui-bot.py \
    test-project.sh \
    INSTALL-howto.txt \
    privacypolicy.txt \
    TermsOfService.txt \
    maketherpmsfromscratch.sh \
    diagnose-spec-v*.sh

# --- Cleanup ---
CLEANFILES = service/yui-bot.service \
             service/yui-bot.initd

# --- Custom Check Target ---
check-deps:
	@echo "Checking Python dependencies from requirements.txt..."
	@$(PIP3) install --dry-run -r $(srcdir)/requirements.txt

# --- Custom Smoke Check Target ---
smokecheck:
	@echo "--- Running Project Smoke Checks (Syntax, Build, Lint) ---"
	$(SHELL) $(top_srcdir)/test-project.sh
	@echo "--- Smoke Checks Complete ---"

# --- RPM Building Targets ---
RPM_BUILD_DIR ?= $(HOME)/rpmbuild
RPMBUILD ?= rpmbuild
RPM_SOURCES_DIR = $(RPM_BUILD_DIR)/SOURCES
RPM_SPECS_DIR = $(RPM_BUILD_DIR)/SPECS
RPM_SPEC_FILE = $(top_srcdir)/rpm/@PACKAGE_NAME@.spec
DIST_TARBALL = $(PACKAGE_TARNAME)-$(PACKAGE_VERSION).tar.gz

srpm: dist
	@echo "--- Building SRPM ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -bs..."
	spec_basename=$$(basename "$(RPM_SPEC_FILE)"); \
	$(RPMBUILD) -bs "$(RPM_SPECS_DIR)/$$spec_basename"
	@echo "---------------------"
	@echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"
	@echo "---------------------"

rpm: dist
	@echo "--- Building RPMs (Binary & Source) ---"
	$(MKDIR_P) "$(RPM_SOURCES_DIR)" "$(RPM_SPECS_DIR)"
	@echo "Copying Source Tarball '$(top_builddir)/$(DIST_TARBALL)' to $(RPM_SOURCES_DIR)/"
	cp -f "$(top_builddir)/$(DIST_TARBALL)" "$(RPM_SOURCES_DIR)/"
	@echo "Copying Spec File '$(RPM_SPEC_FILE)' to $(RPM_SPECS_DIR)/"
	cp -f "$(RPM_SPEC_FILE)" "$(RPM_SPECS_DIR)/"
	@echo "Running $(RPMBUILD) -ba..."
	spec_basename=$$(basename "$(RPM_SPEC_FILE)"); \
	$(RPMBUILD) -ba "$(RPM_SPECS_DIR)/$$spec_basename"
	@echo "---------------------"
	@echo "Binary RPM(s) should be in $(RPM_BUILD_DIR)/RPMS/"
	@echo "SRPM should be in $(RPM_BUILD_DIR)/SRPMS/"
	@echo "---------------------"

# Declare phony targets
.PHONY: check-deps rpm srpm smokecheck all

EOF
msg_pass "Makefile.am written."

# service/yui-bot.service.in (Version 1.3.18 - Includes RuntimeDirectory)
msg_info "Writing service/yui-bot.service.in..."
cat > service/yui-bot.service.in << 'EOF'
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# Systemd Unit File Template for @PACKAGE_NAME@
# Processed by configure script.

[Unit]
Description=Yui Discord Bot Service (@PACKAGE_NAME@)
After=network.target

[Service]
Type=simple
User=@installuser@
Group=@installgroup@
WorkingDirectory=@pkgdatadir@

# Let systemd manage the runtime directory under /run
RuntimeDirectory=%n # %n expands to the service name (yui-bot)
RuntimeDirectoryMode=0750
PIDFile=@pidfile@ # PIDFile path now uses the managed RuntimeDirectory

# --- Execution ---
ExecStart=@PYTHON3@ @pkgdatadir@/yui_bot.py --config @envfile@ --pidfile @pidfile@ --log-level INFO
Restart=on-failure
RestartSec=5s

# --- Environment ---
Environment=PYTHONUNBUFFERED=1

# --- Security Hardening (Split for readability) ---
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=@apprundir@ # Grant access to the path systemd creates
ProtectControlGroups=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged ~@resources ~@raw-io ~@reboot @swap

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
msg_pass "service/yui-bot.service.in written."

# service/yui-bot.initd.in (Uses standard variables)
msg_info "Writing service/yui-bot.initd.in..."
cat > service/yui-bot.initd.in << 'EOF'
#!/bin/sh
#
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# SysVinit Script Template for @PACKAGE_NAME@
# Processed by configure script. Provides an example.

### BEGIN INIT INFO
# Provides:          @PACKAGE_NAME@
# Required-Start:    $remote_fs $network $syslog
# Required-Stop:     $remote_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop the @PACKAGE_NAME@
# Description:       Runs the Yui Discord Bot (@PACKAGE_NAME@) as a daemon. (SysVinit Example)
### END INIT INFO

PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Yui Discord Bot (@PACKAGE_NAME@)"
NAME=@PACKAGE_NAME@
PYTHON_EXEC=@PYTHON3@
DAEMON_USER=@installuser@
DAEMON_GROUP=@installgroup@
INSTALL_DIR=@pkgdatadir@
DAEMON_SCRIPT="$INSTALL_DIR/yui_bot.py"
CONFIG_FILE="@envfile@"
PID_DIR="@apprundir@" # Directory where PID file should live
PID_FILE="@pidfile@"
DAEMON_ARGS="--config $CONFIG_FILE --pidfile $PID_FILE --log-level INFO"
SSD_NAME=$(basename $PYTHON_EXEC) # Used by start-stop-daemon if available

# Source LSB function library if available
if [ -f /lib/lsb/init-functions ]; then
    . /lib/lsb/init-functions
else
    # Provide simple fallback implementations
    log_daemon_msg() { echo -n "$1: $2"; }
    log_end_msg() { [ $1 -eq 0 ] && echo "." || echo " failed."; return $1; }
    log_progress_msg() { echo -n " $1"; }
    log_warning_msg() { echo " Warn: $1"; }
    log_failure_msg() { echo " Err: $1"; }
    pidofproc() { pgrep -u "$DAEMON_USER" -f "$DAEMON_SCRIPT"; } # Example using pgrep
    status_of_proc() { # Simple pidfile check
        local _pidfile="$1"
        local _daemon_name="$2" # Unused in this simple version
        if [ -f "$_pidfile" ]; then
             read pid < "$_pidfile"
             if [ -n "$pid" ] && ps -p "$pid" > /dev/null 2>&1; then
                 # Check if the command matches roughly (adjust pattern if needed)
                 if ps -p "$pid" -o comm= | grep -q -E "(python|${SSD_NAME})"; then
                    return 0 # Running
                 else
                    log_warning_msg "PID file $_pidfile found, but process $pid has wrong name?"
                    return 1 # Program is dead and /var/run pid file exists
                 fi
             else
                log_warning_msg "PID file $_pidfile found, but process $pid is dead."
                return 1 # Program is dead and /var/run pid file exists
             fi
        else
            return 3 # Program is not running
        fi
    }
fi

# Check daemon executable exists
[ -x "$DAEMON_SCRIPT" ] || { log_failure_msg "$DAEMON_SCRIPT missing/not executable."; exit 1; }

# Check required user/group exist
check_user_group() {
    if ! id "$DAEMON_USER" > /dev/null 2>&1; then log_failure_msg "User $DAEMON_USER missing."; return 1; fi
    if ! getent group "$DAEMON_GROUP" > /dev/null 2>&1; then log_failure_msg "Group $DAEMON_GROUP missing."; return 1; fi
    return 0
}

# Function to start the daemon
do_start() {
    check_user_group || return 2

    # Create rundir if it doesn't exist (needed for SysV init)
    if [ ! -d "$PID_DIR" ]; then
        mkdir -p "$PID_DIR" || { log_failure_msg "Failed to create $PID_DIR"; return 1; }
        chown "$DAEMON_USER":"$DAEMON_GROUP" "$PID_DIR" || { log_failure_msg "Failed to chown $PID_DIR"; return 1; }
        chmod 750 "$PID_DIR" || { log_failure_msg "Failed to chmod $PID_DIR"; return 1; }
        log_progress_msg "(created $PID_DIR)"
    fi

    # Use start-stop-daemon if available (preferred)
    if command -v start-stop-daemon > /dev/null 2>&1; then
        # Check if already running based on pidfile
        if start-stop-daemon --start --quiet --pidfile "$PID_FILE" --chuid "$DAEMON_USER":"$DAEMON_GROUP" --exec "$PYTHON_EXEC" --test > /dev/null; then
            # Start the daemon
            start-stop-daemon --start --quiet --pidfile "$PID_FILE" --make-pidfile \
                --background --chuid "$DAEMON_USER":"$DAEMON_GROUP" \
                --chdir "$INSTALL_DIR" --exec "$PYTHON_EXEC" -- $DAEMON_SCRIPT $DAEMON_ARGS || return 2
            return 0 # Success
        else
            log_progress_msg "(already running?)"
            # Double check status
            if status_of_proc "$PID_FILE" "$SSD_NAME"; then return 1; else return 2; fi # Already running or failed test
        fi
    else
        # Fallback: Basic background start (less robust)
        log_warning_msg "start-stop-daemon not found, using basic start."
        if status_of_proc "$PID_FILE" "$SSD_NAME"; then log_progress_msg "(already running?)"; return 1; fi
        su -s /bin/sh -c "cd \"$INSTALL_DIR\" && \"$PYTHON_EXEC\" \"$DAEMON_SCRIPT\" $DAEMON_ARGS & echo \$! > \"$PID_FILE\"" "$DAEMON_USER" || return 2
        # Need short delay to check if it started okay? Usually not done in basic scripts.
        return 0
    fi
}

# Function to stop the daemon
do_stop() {
    if command -v start-stop-daemon > /dev/null 2>&1; then
        start-stop-daemon --stop --quiet --retry=TERM/10/KILL/5 --pidfile "$PID_FILE" --name "$SSD_NAME"
        local RETVAL="$?"
        # Check if process is really gone
        sleep 1
        if ! status_of_proc "$PID_FILE" "$SSD_NAME"; then
            rm -f "$PID_FILE"
        fi
        return $RETVAL
    else
        # Fallback: Basic kill based on PID file
        log_warning_msg "start-stop-daemon not found, using basic kill."
        if [ ! -f "$PID_FILE" ]; then log_progress_msg "(not running?)"; return 0; fi
        read pid < "$PID_FILE"
        if [ -z "$pid" ]; then log_progress_msg "(pidfile empty?)"; rm -f "$PID_FILE"; return 0; fi
        if ps -p "$pid" > /dev/null 2>&1; then
            kill "$pid" # TERM signal
            sleep 2
            if ps -p "$pid" > /dev/null 2>&1; then
                log_progress_msg "(still running, sending KILL)"
                kill -9 "$pid"
                sleep 1
            fi
        fi
        if ! ps -p "$pid" > /dev/null 2>&1; then
            rm -f "$PID_FILE"
            return 0
        else
            log_failure_msg "Could not stop process $pid"
            return 1
        fi
    fi
}

# --- Main Script Logic ---
case "$1" in
  start)
    log_daemon_msg "Starting $DESC" "$NAME"
    do_start
    log_end_msg $?
    ;;
  stop)
    log_daemon_msg "Stopping $DESC" "$NAME"
    do_stop
    log_end_msg $?
    ;;
  status)
    status_of_proc "$PID_FILE" "$SSD_NAME" "$NAME"
    exit $?
    ;;
  restart|force-reload)
    log_daemon_msg "Restarting $DESC" "$NAME"
    do_stop
    # Give it a moment to release resources if needed
    sleep 1
    do_start
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart|force-reload}" >&2
    exit 3
    ;;
esac

exit 0
EOF
msg_pass "service/yui-bot.initd.in written."

# rpm/yui-bot.spec (Version 1.3.18-1 - Includes RuntimeDirectory logic)
msg_info "Writing rpm/yui-bot.spec (v1.3.18-1)..."
cat > rpm/yui-bot.spec << 'EOF'
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# RPM Spec file for yui-bot

%global app_name yui-bot
%global app_user yui-bot
%global app_group yui-bot
%global app_confdir %{_sysconfdir}/%{app_name}
%global app_rundir %{_localstatedir}/run/%{app_name} # Base path used by systemd RuntimeDirectory
%global app_datadir %{_datadir}/%{app_name}
%global app_config_script configure-%{app_name}.py

Name:           %{app_name}
Version:        1.3.18
Release:        1%{?dist}
Summary:        Discord bot (Yui) interfacing with Google Gemini AI
License:        BSD-2-Clause
# Project homepage URL
URL:            https://guppylog.com/software/yui-bot
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

# Build time dependencies
BuildRequires:  autoconf automake
BuildRequires:  python3-devel python3-pip
BuildRequires:  pkgconfig(systemd) systemd
BuildRequires:  findutils make
BuildRequires:  shadow-utils
# For smokecheck/distcheck if run during build
BuildRequires:  rpmlint git bash

# Runtime dependencies
Requires:       python3 >= 3.8
Requires:       systemd-libs
Requires(pre):  shadow-utils
Requires(post): shadow-utils
Requires(postun): shadow-utils
Requires:       python3-google-generativeai >= 0.5.0
Requires:       python3-dotenv >= 1.0.1
Requires:       python3-pidfile >= 3.0.0
Requires:       python3-psutil >= 5.9.0
Requires:       python3-discord.py >= 2.3.2

%description
A Discord bot named Yui that uses the Google Gemini AI API to respond
to user prompts, fetch man pages, and maintain limited conversation
history. Includes systemd integration for running as a service on RHEL 9+.
Also includes a Python helper script (%{_sbindir}/%{app_config_script})
to assist with initial configuration, API key validation, and model selection.

%prep
%autosetup -n %{name}-%{version} -p1

%build
# Configure the package
%configure --with-user=%{app_user} --with-group=%{app_group} --with-rundir=%{app_rundir} --with-confdir=%{app_confdir}
# Run make
make %{?_smp_mflags}

%install
# Run make install
%make_install

# Create ONLY the config directory with correct group ownership and permissions
# Runtime directory (/run/yui-bot) is now managed by systemd via RuntimeDirectory= in service file
install -dpm 750 -g %{app_group} %{buildroot}%{app_confdir}

# Install example config file
install -Dpm 640 %{buildroot}%{app_datadir}/yui-bot.env.example %{buildroot}%{app_confdir}/.env.example

# Install example init.d script
install -dpm 755 %{buildroot}%{app_datadir}/examples
install -m 644 %{_builddir}/%{name}-%{version}/service/yui-bot.initd %{buildroot}%{app_datadir}/examples/yui-bot.initd

# Move the installed systemd service file to the correct location
install -dpm 755 %{buildroot}%{_unitdir}
mv %{buildroot}%{app_datadir}/yui-bot.service %{buildroot}%{_unitdir}/%{name}.service


%pre -p /bin/sh
# Create group/user only
getent group %{app_group} >/dev/null || groupadd -r %{app_group}
getent passwd %{app_user} >/dev/null || useradd -r -g %{app_group} -d %{app_datadir} -s /sbin/nologin -c "Yui Discord Bot Service Account" %{app_user}
exit 0

%post -p /bin/sh
# Handle systemd service activation post-install
%systemd_post %{name}.service
# Provide post-install instructions
echo "----------------------------------------------------------------------"
echo " yui-bot has been installed."
echo " IMPORTANT: You must configure API keys before starting the service."
echo "  1. Run 'sudo %{_sbindir}/%{app_config_script}' (interactive or with args)"
echo "     to validate keys, select model, and create '%{app_confdir}/.env'."
echo "  2. OR manually create/edit '%{app_confdir}/.env' based on the example,"
echo "     then ensure ownership '%{app_user}:%{app_group}' and permissions '640'."
echo "  3. Ensure Python dependencies are met (check Requires section in spec or"
echo "     run 'sudo python3 -m pip install -r %{app_datadir}/requirements.txt')."
echo "  4. Then, start the service: 'sudo systemctl start %{name}.service'"
echo "----------------------------------------------------------------------"

%preun -p /bin/sh
# Handle systemd service deactivation pre-uninstall
%systemd_preun %{name}.service

%postun -p /bin/sh
# Handle systemd service cleanup post-uninstall (if upgrading)
%systemd_postun_with_restart %{name}.service
# Remove user/group only on final package removal ($1 == 0)
if [ $1 -eq 0 ] ; then
    # Final removal
    getent passwd %{app_user} >/dev/null && userdel %{app_user} || :
    getent group %{app_group} >/dev/null && groupdel %{app_group} || :
fi
exit 0

%files
%license %attr(0644, root, root) LICENSE
%doc README.md
%dir %attr(0755, root, root) %{app_datadir}
%dir %attr(0755, root, root) %{app_datadir}/examples
%doc %attr(0644, root, root) %{app_datadir}/examples/yui-bot.initd
%attr(0755, root, root) %{app_datadir}/yui_bot.py
%attr(0644, root, root) %{app_datadir}/requirements.txt
%attr(0644, root, root) %{app_datadir}/yui-bot.env.example
%dir %attr(0750, root, %{app_group}) %{app_confdir} # Owned root:yui-bot usually
%config(noreplace) %attr(0640, %{app_user}, %{app_group}) %{app_confdir}/.env
%attr(0644, root, root) %{app_confdir}/.env.example
# Runtime directory is no longer packaged, systemd manages it
%attr(0644, root, root) %{_unitdir}/%{name}.service
# Python configuration script
%attr(0755, root, root) %{_sbindir}/%{app_config_script}


%changelog
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-1
- fix: Use RuntimeDirectory= in systemd unit instead of packaging /run dir.
- build: Remove install of runtime dir from spec %install.
- build: Remove runtime dir from spec %files list.
- build: Ensure config dir group is set correctly in spec %install.
# Add previous relevant entries below if desired
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-5
- build: Correctly remove *all* inline comments from spec file tags (Release, URL).
EOF
msg_pass "rpm/yui-bot.spec written."

# configure-yui-bot.py (Version 1.3.8 - Syntax fix)
msg_info "Writing configure-yui-bot.py..."
cat > configure-yui-bot.py << 'EOF'
#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# Configuration helper script for the yui-bot service. (Python Version)
# Sets up the .env file, verifies API key, and selects model.
# Must be run with sudo from a non-root user account.

import os
import sys
import argparse
import getpass
import pwd
import grp
import tempfile
from datetime import datetime

# --- Attempt to import required libraries ---
try: from dotenv import set_key, find_dotenv
except ImportError: print("Error: 'python-dotenv' not found.\nInstall: sudo python3 -m pip install python-dotenv", file=sys.stderr); sys.exit(1)
try: import google.generativeai as genai; from google.api_core import exceptions as google_api_exceptions
except ImportError: print("Error: 'google-generativeai' not found.\nInstall: sudo python3 -m pip install google-generativeai", file=sys.stderr); sys.exit(1)

# --- Configuration ---
APP_NAME = "yui-bot"
CONFIG_DIR = f"/etc/{APP_NAME}"
ENV_FILE = os.path.join(CONFIG_DIR, ".env")
SERVICE_USER = "yui-bot"
SERVICE_GROUP = "yui-bot"
ENV_PERMS = 0o640 # rw-r----- (Octal)
DEFAULT_TIMEOUT_SECS = "3600"
DEFAULT_MODEL_NAME = "gemini-1.5-flash"

# --- Privilege Check ---
def check_privileges():
    """Checks for correct sudo execution."""
    if os.geteuid() != 0:
        print(f"Error: Script needs root privileges.\nPlease run using 'sudo {sys.argv[0]}'.", file=sys.stderr); sys.exit(1)
    if not os.environ.get("SUDO_USER"):
        print("Error: Please run this script using 'sudo' from your regular user account,", file=sys.stderr)
        print("       instead of running it directly as root (e.g., via 'su -' or root login).", file=sys.stderr)
        print("\n  Why use 'sudo'? Better accountability, limited privilege scope, reduced risk.", file=sys.stderr); sys.exit(1)
    print("--> Running with required sudo privileges.")

# --- Get UID/GID ---
def get_service_ids():
    """Gets UID and GID for the service user/group."""
    try:
        uid = pwd.getpwnam(SERVICE_USER).pw_uid
        gid = grp.getgrnam(SERVICE_GROUP).gr_gid
        print(f"--> Found UID={uid}, GID={gid} for {SERVICE_USER}:{SERVICE_GROUP}")
        return uid, gid
    except KeyError as e:
        print(f"Error: Service user '{SERVICE_USER}' or group '{SERVICE_GROUP}' not found: {e}", file=sys.stderr)
        print("       Ensure the yui-bot RPM package is installed correctly.", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error getting service UID/GID: {e}", file=sys.stderr); sys.exit(1)

# --- Fetch Available Models ---
def get_available_models(api_key):
    """Connects to Gemini API and returns list of usable model names."""
    print("--> Verifying API key and fetching available models...")
    try:
        genai.configure(api_key=api_key)
        models = genai.list_models()
        usable_models = sorted([m.name for m in models if 'generateContent' in m.supported_generation_methods])
        if not usable_models:
            print("Error: No models supporting content generation found with this API key.", file=sys.stderr)
            return None, "No usable models found."
        print(f"--> Found {len(usable_models)} usable model(s).")
        model_ids = [name.replace('models/', '') for name in usable_models]
        return model_ids, None
    except (google_api_exceptions.PermissionDenied, google_api_exceptions.Unauthenticated):
        return None, "API Key is invalid or lacks permissions."
    except google_api_exceptions.GoogleAPIError as e:
         return None, f"Error connecting to Google API: {e}"
    except Exception as e:
        return None, f"Unexpected error connecting to Gemini API: {type(e).__name__}"

# --- Main Function ---
def main():
    check_privileges()
    uid, gid = get_service_ids()

    parser = argparse.ArgumentParser(
        description=f"Configure {ENV_FILE} for {APP_NAME}.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument('--token', help="Discord Bot Token")
    parser.add_argument('--apikey', help="Gemini API Key")
    parser.add_argument('--author-id', help="Author's Discord ID (for -dono)")
    parser.add_argument('--timeout', default=DEFAULT_TIMEOUT_SECS, help="Conversation timeout (seconds)")
    parser.add_argument('--model', help=f"Gemini model name (will be validated; default: {DEFAULT_MODEL_NAME})")
    parser.add_argument('--non-interactive', '-y', action='store_true',
                        help="Run non-interactively (requires --token and --apikey)")
    parser.add_argument('--force', '-f', action='store_true',
                        help="Force overwrite of existing .env file without prompting")
    args = parser.parse_args()

    # Determine Mode & Get Values
    discord_token = args.token
    gemini_api_key = args.apikey
    author_id = args.author_id
    timeout_secs = args.timeout
    model_name_arg = args.model

    if args.non_interactive:
        print("--> Running in non-interactive mode.")
        if not discord_token or not gemini_api_key:
            parser.error("--token and --apikey are required for non-interactive mode.")
        model_name_arg = model_name_arg or DEFAULT_MODEL_NAME
        author_id = author_id or ""
        timeout_secs = timeout_secs or DEFAULT_TIMEOUT_SECS
    else: # Interactive Mode
        print(f"--- {APP_NAME} Interactive Configuration ---")
        print(f"Configuring: {ENV_FILE}")
        if os.path.exists(ENV_FILE) and not args.force:
            print(f"\nWarning: Config file '{ENV_FILE}' exists.")
            confirm = input("Overwrite? (y/N): ").strip().lower()
            if confirm != 'y':
                print("Aborting."); sys.exit(0)
        elif os.path.exists(ENV_FILE) and args.force:
             print(f"Warning: Config file '{ENV_FILE}' exists. --force specified, overwriting.")

        print("\nEnter required information (input hidden for secrets):")
        while not discord_token: discord_token = getpass.getpass("Discord Bot Token: ")
        while not gemini_api_key: gemini_api_key = getpass.getpass("Gemini API Key:    ")

        print("\nEnter optional information (press Enter for default/skip):")
        author_id = input(f"Author Discord ID (for -dono) [Optional]: ").strip()
        input_timeout = input(f"Conversation Timeout [{DEFAULT_TIMEOUT_SECS}s]: ").strip()
        timeout_secs = input_timeout or DEFAULT_TIMEOUT_SECS
        # Model selected after validation below

    # Validate Timeout
    try:
        timeout_int = int(timeout_secs)
        if timeout_int <= 0: raise ValueError("Timeout must be positive")
        timeout_secs = str(timeout_int)
    except (ValueError, TypeError):
        print(f"Warning: Invalid timeout '{timeout_secs}'. Using default {DEFAULT_TIMEOUT_SECS}s.")
        timeout_secs = DEFAULT_TIMEOUT_SECS

    # Verify API Key & Get Models
    available_models, error = get_available_models(gemini_api_key)
    if error:
        print(f"\nError: {error}\nConfiguration aborted.", file=sys.stderr); sys.exit(1)
    if not available_models: # Should be caught by error above, but double-check
        print("\nError: Could not retrieve usable models.\nConfiguration aborted.", file=sys.stderr); sys.exit(1)
    print("--> API Key verified.")

    # Select/Validate Model
    final_model_name = ""
    # Non-interactive: Use provided or default, must be valid
    if args.non_interactive:
        if model_name_arg in available_models:
            final_model_name = model_name_arg
            print(f"--> Using specified model: {final_model_name}")
        else:
            print(f"Error: Specified/Default model '{model_name_arg}' unavailable or invalid.", file=sys.stderr)
            print(f"Available models: {', '.join(available_models)}", file=sys.stderr); sys.exit(1)
    # Interactive: Let user choose from list
    else:
        print("\nAvailable Gemini Models:")
        for i, m_name in enumerate(available_models): print(f"  {i+1}) {m_name}")

        default_model_to_try = model_name_arg or DEFAULT_MODEL_NAME
        default_choice_num = -1
        if default_model_to_try in available_models:
            try:
                default_choice_num = available_models.index(default_model_to_try) + 1
            except ValueError: pass # Should not happen if check above passed

        prompt_suffix = f" [{default_model_to_try}]" if default_choice_num != -1 else ""
        prompt = f"Select model number to use{prompt_suffix}: "

        while not final_model_name:
            try:
                choice_str = input(prompt).strip()
                if not choice_str and default_choice_num != -1:
                    choice = default_choice_num # Use default if Enter pressed and default is valid
                elif not choice_str and default_choice_num == -1:
                    choice = 1 # Fallback to first model if Enter pressed and default isn't valid
                else:
                    choice = int(choice_str)

                if 1 <= choice <= len(available_models):
                    final_model_name = available_models[choice - 1]
                    print(f"Selected model: {final_model_name}")
                else:
                    print(f"Invalid selection. Enter a number between 1 and {len(available_models)}.")
            except ValueError:
                print("Invalid input. Please enter a number.")

    # Final Confirmation (Interactive only)
    if not args.non_interactive:
        print("\n--- Configuration Summary ---")
        print(f"Discord Token:       [REDACTED]")
        print(f"Gemini API Key:      [REDACTED]")
        print(f"Author Discord ID:   {author_id or '<Not Set>'}")
        print(f"Timeout Seconds:     {timeout_secs}")
        print(f"Gemini Model:        {final_model_name}")
        print(f"Target File:         {ENV_FILE}")
        print(f"Owner/Permissions:   {SERVICE_USER}:{SERVICE_GROUP} / {oct(ENV_PERMS)[2:]}")
        confirm_write = input("\nProceed with writing this configuration? (y/N): ").strip().lower()
        if confirm_write != 'y': print("Configuration aborted."); sys.exit(0)

    # Write .env File atomically
    print(f"\nWriting configuration to {ENV_FILE}...")
    temp_path = None # Define temp_path outside try for cleanup
    try:
        # Ensure config dir exists (RPM should create it, but good fallback)
        # Set permissions carefully if we create it (though group might be root initially)
        if not os.path.isdir(CONFIG_DIR):
             os.makedirs(CONFIG_DIR, mode=0o750, exist_ok=True)
             try: # Attempt to set group ownership if we created it
                 os.chown(CONFIG_DIR, 0, gid) # owner root, group yui-bot
                 os.chmod(CONFIG_DIR, 0o750) # Ensure correct perms
             except OSError as ch_err:
                  print(f"Warning: Could not set group ownership/perms on created {CONFIG_DIR}: {ch_err}", file=sys.stderr)

        # Use temp file in the same directory for atomic replace
        temp_fd, temp_path = tempfile.mkstemp(dir=CONFIG_DIR, prefix=".env.tmp")
        with os.fdopen(temp_fd, 'w') as f:
            f.write(f"# Configuration for {APP_NAME} - Generated by configuration script\n")
            f.write(f"# {datetime.now().isoformat()}\n\n")
            f.write("# Required: Discord Bot Token\n")
            f.write(f"DISCORD_BOT_TOKEN={discord_token}\n\n")
            f.write("# Required: Google Generative AI (Gemini) API Key\n")
            f.write(f"GEMINI_API_KEY={gemini_api_key}\n\n")
            f.write("# Gemini Model to use (verified available)\n")
            f.write(f"GEMINI_MODEL_NAME={final_model_name}\n\n")
            f.write("# Conversation history timeout in seconds\n")
            f.write(f"CONVERSATION_TIMEOUT_SECONDS={timeout_secs}\n\n")
            f.write("# Optional: Author's Discord User ID for '-dono' honorific\n")
            f.write(f"AUTHOR_DISCORD_ID={author_id}\n")

        # Set ownership and permissions on the temporary file *before* replacing
        os.chown(temp_path, uid, gid)
        os.chmod(temp_path, ENV_PERMS)

        # Atomically replace the old file with the new one
        os.replace(temp_path, ENV_FILE)
        print(f"Successfully wrote configuration to {ENV_FILE}")
        print("Final permissions/ownership:")
        os.system(f"ls -lZ {ENV_FILE}") # Use ls -lZ for SELinux context
        temp_path = None # Prevent cleanup if successful

    except Exception as e:
        print(f"\nError writing configuration file: {e}", file=sys.stderr)
        # Clean up temp file if it still exists after failure
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
                print(f"Cleaned up temporary file: {temp_path}")
            except OSError as rm_err:
                print(f"Warning: Could not remove temporary file {temp_path}: {rm_err}", file=sys.stderr)
        sys.exit(1) # Exit with error code

    print("\nConfiguration complete!")
    print("You may need to (re)start the service if it was already running:")
    print(f"  sudo systemctl restart {APP_NAME}.service")
    sys.exit(0) # Exit cleanly

if __name__ == "__main__":
    main()
EOF
msg_pass "configure-yui-bot.py written."

# test-project.sh (Version 1.3.7 - Includes sudo dnf, user/group check for config test)
msg_info "Writing test-project.sh..."
cat > test-project.sh << 'EOF'
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
    fi

    # 4. Cleanup
    log_info "Running 'make clean'..."
    make clean > /dev/null
    return 0 # Return success if it reached here
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
EOF
msg_pass "test-project.sh written."

# README.md (Final version)
msg_info "Writing README.md..."
cat > README.md << 'EOF'
# yui-bot Discord Bot (GuppyGirl Genetics Software)

## Overview

This project provides a Discord bot named **yui-bot**, interfacing with the Google Gemini AI API. It allows users to interact with the AI by mentioning the bot, maintains limited conversation history, and includes features for fetching Linux/Unix man pages.

This bot is designed to run as a system service on RHEL 9+ systems, packaged as an RPM using Autotools for build standardization.

**Features:**

* Responds to @Mentions with queries to the Gemini AI.
* `man <command>` command to fetch man pages via AI.
* `man @BotName` command for detailed bot help (replace @BotName with the bot's actual Discord name, likely 'yui-bot').
* `help` command alias pointing to `man @BotName`.
* `botsnack` or `bot snack` command for a fun response.
* Configurable, user/channel-specific conversation history timeout.
* Uses Japanese honorifics (`-dono`, `-chan`, `-san`).
* Runs as a systemd service under a dedicated user (`yui-bot`).
* Logging to syslog with multiple levels.
* PID file management to prevent multiple instances.
* RPM package (`yui-bot`) for easy installation on RHEL 9+.
* Includes Python-based configuration helper script (`/usr/sbin/configure-yui-bot.py`).
* Includes basic build/syntax/packaging checks via `make smokecheck`.

## License

This project is licensed under the BSD-2-Clause license. See the `LICENSE` file for details.
Copyright (c) 2025 Guppy Girl Genetics Software.

## Prerequisites (Runtime)

* Python 3.8+
* Required Python libraries: `discord.py`, `google-generativeai`, `python-dotenv`, `python-pidfile`, `psutil` (see `requirements.txt`)
* Access to Discord API (Bot Token)
* Access to Google Gemini API (API Key)
* A running syslog daemon (like rsyslog or systemd-journald)
* RHEL 9+ or compatible system with systemd.

## Prerequisites (Build - for RPM & Testing)

* RHEL 9+ build environment or compatible (e.g., CentOS Stream 9, Fedora).
* `rpm-build`, `rpmdevtools`
* `autoconf`, `automake`
* `python3-devel`, `python3-pip`
* `pkgconfig(systemd)`, `systemd-devel` (provides the pkg-config file)
* `make`, `findutils`
* `shadow-utils` (provides `useradd`/`groupadd` - usually present)
* `rpmlint`, `git`, `tar`, `gzip`, `gcc` (for running `make smokecheck` or `make distcheck`)

## Build Instructions (RPM)

These steps are performed on your build machine starting from the source code.

1.  **Setup Build Environment (If first time):**
    * Install required build tools:
      ```bash
      sudo dnf install rpm-build rpmdevtools autoconf automake make gcc python3-devel python3-pip systemd-devel shadow-utils rpmlint git tar gzip -y
      ```
    * Create RPM build directories:
      ```bash
      rpmdev-setuptree
      ```

2.  **Prepare Build System:** Navigate to the project source directory (`cd /path/to/yui-bot`) and run:
    ```bash
    autoreconf --install --force
    ```

3.  **Configure:** Run the configure script. Using `--prefix=/usr` is recommended for packages intended for system installation via RPM.
    ```bash
    ./configure --prefix=/usr
    ```
    *(Review the configuration summary output.)*

4.  **Build RPMs:** Use the `make rpm` target. This builds the source tarball, copies files, and runs `rpmbuild`.
    ```bash
    make rpm
    ```
    *(Alternatively, run `make distcheck` first for extra validation.)*

5.  **Locate RPMs:** The finished packages will be in your home directory:
    * `~/rpmbuild/RPMS/noarch/yui-bot-*.noarch.rpm`
    * `~/rpmbuild/SRPMS/yui-bot-*.src.rpm`

## Installation (RPM)

These steps are performed on the target RHEL 9+ system where the bot will run.

1.  **Transfer RPM:** Copy the built binary RPM (e.g., `yui-bot-1.3.18-1.el9.noarch.rpm`) to the target system.
2.  **Install RPM:**
    ```bash
    sudo dnf install ./yui-bot-*.noarch.rpm
    ```
    *(Confirm dependencies if prompted. This runs the %pre scriptlet creating the `yui-bot` user/group.)*
3.  **Install Python Dependencies:** The required Python libraries are listed in the RPM `Requires:` tags but might not be available in standard OS repos. Install them using pip:
    ```bash
    sudo python3 -m pip install -r /usr/share/yui-bot/requirements.txt
    ```
4.  **Configure Bot:** Run the configuration helper script with `sudo` to set API keys and choose the AI model. It saves settings to `/etc/yui-bot/.env` with correct permissions.
    ```bash
    sudo /usr/sbin/configure-yui-bot.py --interactive
    ```
    *(Follow prompts for Discord Token, Gemini API Key, etc.)*
5.  **Start & Enable Service:**
    ```bash
    sudo systemctl enable --now yui-bot.service
    ```
    *(The `--now` flag enables the service for boot and starts it immediately. Systemd automatically creates `/run/yui-bot` due to `RuntimeDirectory=`)*
6.  **Verify Status:**
    ```bash
    sudo systemctl status yui-bot.service
    ```
    *(Check for `Active: active (running)`)*
7.  **Check Logs:**
    ```bash
    sudo journalctl -u yui-bot.service -f
    ```

## Usage

* Invite the bot (likely named "yui-bot" in Discord) to your server.
* Mention the bot: `@yui-bot <your question>`
* Get help: `@yui-bot man @yui-bot` or `@yui-bot help`
* Get man pages: `@yui-bot man <command>`
* Give the bot a snack: `@yui-bot botsnack` (or `@yui-bot bot snack`)

## Service Management

* Start: `sudo systemctl start yui-bot`
* Stop: `sudo systemctl stop yui-bot`
* Restart: `sudo systemctl restart yui-bot`
* Status: `sudo systemctl status yui-bot`
* Logs: `sudo journalctl -u yui-bot -f` or `sudo journalctl -u yui-bot -e`
EOF
msg_pass "README.md written."

# --- Final Diagnostics ---
msg_info "Running final checks..."
FINAL_CHECK_FAIL=0

# Check Python syntax
msg_info "Checking Python syntax..."
if ! python3 -m py_compile yui_bot.py; then
    msg_error "Syntax error in yui_bot.py"
    FINAL_CHECK_FAIL=1
fi
if ! python3 -m py_compile configure-yui-bot.py; then
     msg_error "Syntax error in configure-yui-bot.py"
     FINAL_CHECK_FAIL=1
fi

# Check Shell syntax
msg_info "Checking shell script syntax..."
if ! bash -n test-project.sh; then
    msg_error "Syntax error in test-project.sh"
    FINAL_CHECK_FAIL=1
fi
if ! bash -n service/yui-bot.initd.in; then
     msg_error "Syntax error in service/yui-bot.initd.in"
     FINAL_CHECK_FAIL=1
fi

# Check Autotools generation (autoreconf only, configure/make checked by smokecheck)
msg_info "Running 'autoreconf -fi' to check configure.ac/Makefile.am..."
set +e
autoreconf -fi > /dev/null 2>&1
AUTORECONF_STATUS=$?
set -e
if [ $AUTORECONF_STATUS -ne 0 ]; then
    msg_error "autoreconf -fi failed! Check configure.ac and Makefile.am."
    FINAL_CHECK_FAIL=1
fi

# Run make smokecheck (includes distcheck)
msg_info "Running 'make smokecheck' (this includes make distcheck and may take a while)..."
set +e
# Need to configure first before make smokecheck
if [ $AUTORECONF_STATUS -eq 0 ]; then
    ./configure --prefix=/usr --quiet
    if [ $? -eq 0 ]; then
        make smokecheck
        SMOKECHECK_STATUS=$?
    else
        msg_error "./configure failed before smokecheck."
        SMOKECHECK_STATUS=1 # Mark as failed
    fi
else
    msg_error "Skipping smokecheck because autoreconf failed."
    SMOKECHECK_STATUS=1 # Mark as failed
fi
set -e

if [ $SMOKECHECK_STATUS -ne 0 ]; then
    msg_error "'make smokecheck' failed! Review output and logs."
    FINAL_CHECK_FAIL=1
fi

echo "---"
if [ $FINAL_CHECK_FAIL -eq 0 ]; then
    msg_pass "All file updates applied and basic diagnostic checks passed."
    msg_info "The codebase should be in a consistent, buildable state (v1.3.18)."
else
    msg_error "Some files were updated, but subsequent diagnostic checks failed. Please review errors above."
    exit 1
fi

exit 0
