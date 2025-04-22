# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
dnl Process this file with autoconf to produce a configure script.
#
AC_PREREQ([2.69])
# Initialize package info (Updated version for spec file install fix)
AC_INIT([yui-bot], [1.3.17], [stacy@guppylog.com]) # << UPDATED VERSION
AC_CONFIG_SRCDIR([yui_bot.py])
AM_INIT_AUTOMAKE([-Wall -Werror foreign]) # <<< Ensure this is present and correct
dnl AC_CONFIG_MACRO_DIRS([m4])

# --- Checks for Programs ---
AC_PROG_INSTALL
AC_PROG_MKDIR_P

AC_CHECK_PROG([PYTHON3], [python3], [python3], [], [/usr/bin:/usr/local/bin])
if test "x$PYTHON3" = "x"; then echo "configure: error: python3 interpreter not found" >&2; exit 1; fi

AC_CHECK_PROG([PIP3], [pip3], [pip3], [], [/usr/bin:/usr/local/bin])
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
AM_CONDITIONAL([HAVE_SYSTEMD], [test "x$have_systemd" = "xyes"]) # <<< Ensure this is present and correct

# --- Define Installation User/Group ---
AC_ARG_WITH([user], [AS_HELP_STRING([--with-user=USER], [Runtime user (default: yui-bot)])], [installuser="$withval"], [installuser="yui-bot"])
AC_ARG_WITH([group], [AS_HELP_STRING([--with-group=GROUP], [Runtime group (default: yui-bot)])], [installgroup="$withval"], [installgroup="yui-bot"])
AC_SUBST([installuser])
AC_SUBST([installgroup])

# --- Define Installation Paths ---
AC_PREFIX_DEFAULT([/usr])
AC_PROG_LN_S
# AC_PATH_PROG_PREPARE # Keep commented out as it causes errors on this system

# Force evaluation of standard directories using eval into temporary vars
# This ensures ${prefix}, ${datarootdir} etc. are resolved *now*.
eval "evaluated_prefix=$prefix"
eval "evaluated_exec_prefix=$exec_prefix"
eval "evaluated_sysconfdir=$sysconfdir"
eval "evaluated_localstatedir=$localstatedir"
eval "evaluated_datarootdir=$datarootdir"
# Explicitly eval datadir using the evaluated datarootdir/prefix
eval "evaluated_datadir=$datadir"
eval "evaluated_libdir=$libdir"
# Ensure runstatedir is derived correctly *after* localstatedir is evaluated
AS_IF([test "x$runstatedir" = 'x${localstatedir}/run'],
      [evaluated_runstatedir="${evaluated_localstatedir}/run"],
      [eval "evaluated_runstatedir=$runstatedir"]) # Eval potential prefix in runstatedir too

# Override key directories if prefix is /usr (use evaluated values)
AS_IF([test "x$evaluated_prefix" = "x/usr"],
      [ evaluated_sysconfdir="/etc"
        evaluated_localstatedir="/var"
        evaluated_runstatedir="/var/run"
        evaluated_datadir="/usr/share" # Explicitly set datadir for /usr prefix
       ]) # <<< Fixed missing bracket here previously

# Define final application paths using the fully evaluated base paths
final_pkgdatadir="${evaluated_datadir}/${PACKAGE_NAME}"

# Define runtime/config directories, allowing overrides
final_apprundir_default="${evaluated_runstatedir}/${PACKAGE_NAME}"
final_appconfdir_default="${evaluated_sysconfdir}/${PACKAGE_NAME}"
AC_ARG_WITH([rundir], [AS_HELP_STRING([--with-rundir=DIR], [Runtime dir (default based on prefix)])],
            [final_apprundir="$withval"], [final_apprundir="$final_apprundir_default"])
AC_ARG_WITH([confdir], [AS_HELP_STRING([--with-confdir=DIR], [Config dir (default based on prefix)])],
            [final_appconfdir="$withval"], [final_appconfdir="$final_appconfdir_default"])

# Expand potential variables in user overrides (needed if user uses e.g. --with-rundir=$myvar)
eval "final_apprundir=$final_apprundir"
eval "final_appconfdir=$final_appconfdir"

# Calculate derived paths based on the final app paths
final_pidfile="${final_apprundir}/${PACKAGE_NAME}.pid"
final_envfile="${final_appconfdir}/.env"

# Substitute the final, fully calculated paths using unique names
AC_SUBST([FINAL_PKG_DATA_DIR], [$final_pkgdatadir])
AC_SUBST([FINAL_APPRUN_DIR], [$final_apprundir])
AC_SUBST([FINAL_APPCONF_DIR], [$final_appconfdir])
AC_SUBST([FINAL_PID_FILE], [$final_pidfile])
AC_SUBST([FINAL_ENV_FILE], [$final_envfile])
AC_SUBST([FINAL_PYTHON_EXEC], [$PYTHON3])

# --- Systemd Unit Directory (Still needed for spec file) ---
# Use evaluated libdir
systemd_unitdir_value="";
if test "x$have_systemd" = "xyes"; then
    systemd_unitdir_value=`$PKG_CONFIG --variable=systemdsystemunitdir systemd`
    if test "x$systemd_unitdir_value" = "x"; then
        systemd_unitdir_value="${evaluated_libdir}/systemd/system"
    fi
else
    systemd_unitdir_value="${evaluated_libdir}/systemd/system"
fi
eval "final_systemd_unitdir=$systemd_unitdir_value" # Eval just in case path contained vars
AC_SUBST([FINAL_SYSTEMD_UNITDIR], [$final_systemd_unitdir]) # Use unique name

# --- Output Files ---
AC_CONFIG_FILES([ Makefile service/yui-bot.service service/yui-bot.initd ])
AC_OUTPUT
AC_MSG_NOTICE([ Configuration Summary: ... (output reflects chosen options) ... ])
# Print the FINAL variables that will be substituted into .in files
AC_MSG_NOTICE([ Paths Substituted into Service Files (Check these carefully!): ])
AC_MSG_NOTICE([  Working Dir (@FINAL_PKG_DATA_DIR@): $final_pkgdatadir ])
AC_MSG_NOTICE([  App Run Dir (@FINAL_APPRUN_DIR@):   $final_apprundir ])
AC_MSG_NOTICE([  App Conf Dir (@FINAL_APPCONF_DIR@): $final_appconfdir ])
AC_MSG_NOTICE([  PID File (@FINAL_PID_FILE@):       $final_pidfile ])
AC_MSG_NOTICE([  Env File (@FINAL_ENV_FILE@):       $final_envfile ])
AC_MSG_NOTICE([  Python Exec (@FINAL_PYTHON_EXEC@): $PYTHON3 ])
