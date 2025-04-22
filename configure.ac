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
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
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
# Define HAVE_SYSTEMD conditional for Makefile.am
AM_CONDITIONAL([HAVE_SYSTEMD], [test "x$have_systemd" = "xyes"])

# --- Define Installation User/Group ---
AC_ARG_WITH([user], [AS_HELP_STRING([--with-user=USER], [Runtime user (default: yui-bot)])], [installuser="$withval"], [installuser="yui-bot"])
AC_ARG_WITH([group], [AS_HELP_STRING([--with-group=GROUP], [Runtime group (default: yui-bot)])], [installgroup="$withval"], [installgroup="yui-bot"])
AC_SUBST([installuser])
AC_SUBST([installgroup])

# --- Define Installation Paths ---
AC_PREFIX_DEFAULT([/usr])
# Ensure standard base directories are evaluated by configure
AC_PROG_LN_S # Needed for AC_PATH_PROG_PREPARE below
AC_PATH_PROG_PREPARE

# Get the *final evaluated* values of standard directories
final_prefix="$prefix"
final_exec_prefix="$exec_prefix"
final_sysconfdir="$sysconfdir"
final_localstatedir="$localstatedir"
final_datarootdir="$datarootdir"
final_datadir="$datadir"
final_libdir="$libdir"
# Ensure runstatedir is derived correctly
AS_IF([test "x$runstatedir" = 'x${localstatedir}/run'], [final_runstatedir="${final_localstatedir}/run"], [final_runstatedir="$runstatedir"])

# Override key directories if prefix is /usr (use final values)
AS_IF([test "x$final_prefix" = "x/usr"],
      [ final_sysconfdir="/etc"
        final_localstatedir="/var"
        final_runstatedir="/var/run" ])

# Define final application paths using the final evaluated base paths
final_pkgdatadir="${final_datadir}/${PACKAGE_NAME}"
AC_SUBST([FINAL_PKG_DATA_DIR], [$final_pkgdatadir]) # Use unique name for substitution

# Define runtime/config directories, allowing overrides
AC_ARG_WITH([rundir], [AS_HELP_STRING([--with-rundir=DIR], [Runtime dir (default depends on prefix)])],
            [apprundir_value="$withval"], [apprundir_value="${final_runstatedir}/${PACKAGE_NAME}"])
AC_ARG_WITH([confdir], [AS_HELP_STRING([--with-confdir=DIR], [Config dir (default depends on prefix)])],
            [appconfdir_value="$withval"], [appconfdir_value="${final_sysconfdir}/${PACKAGE_NAME}"])

# Expand any potential variables *within* the user-provided or default values
eval "final_apprundir=$apprundir_value"
eval "final_appconfdir=$appconfdir_value"
final_pidfile="${final_apprundir}/${PACKAGE_NAME}.pid"
final_envfile="${final_appconfdir}/.env"

# Substitute the final, fully expanded paths
AC_SUBST([FINAL_APPRUN_DIR], [$final_apprundir])
AC_SUBST([FINAL_APPCONF_DIR], [$final_appconfdir])
AC_SUBST([FINAL_PID_FILE], [$final_pidfile])
AC_SUBST([FINAL_ENV_FILE], [$final_envfile])
AC_SUBST([FINAL_PYTHON_EXEC], [$PYTHON3]) # Use unique name for python too

# --- Systemd Unit Directory (Still needed for spec file) ---
systemd_unitdir_value="";
if test "x$have_systemd" = "xyes"; then
    systemd_unitdir_value=`$PKG_CONFIG --variable=systemdsystemunitdir systemd`
    if test "x$systemd_unitdir_value" = "x"; then
        systemd_unitdir_value="${final_libdir}/systemd/system"
    fi
else
    systemd_unitdir_value="${final_libdir}/systemd/system"
fi
eval "final_systemd_unitdir=$systemd_unitdir_value"
AC_SUBST([FINAL_SYSTEMD_UNITDIR], [$final_systemd_unitdir]) # Use unique name

# --- Output Files ---
AC_CONFIG_FILES([ Makefile service/yui-bot.service service/yui-bot.initd ])
AC_OUTPUT
AC_MSG_NOTICE([ Configuration Summary: ... (output reflects chosen options) ... ])
AC_MSG_NOTICE([ Paths (Check these carefully!): ])
AC_MSG_NOTICE([  Pkg Data Dir: $final_pkgdatadir ])
AC_MSG_NOTICE([  App Run Dir:  $final_apprundir ])
AC_MSG_NOTICE([  App Conf Dir: $final_appconfdir ])
AC_MSG_NOTICE([  PID File:     $final_pidfile ])
AC_MSG_NOTICE([  Env File:     $final_envfile ])
AC_MSG_NOTICE([  Python Exec:  $PYTHON3 ])
