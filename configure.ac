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
AC_SUBST([sysconfdir])
AC_SUBST([localstatedir])
AC_SUBST([runstatedir])
AC_SUBST([libdir])
AC_SUBST([datadir])
AC_SUBST([datarootdir])

AS_IF([test "x$prefix" = "x/usr" || test "x${prefix}" = "xNONE"],
      [ AC_SUBST([sysconfdir], [/etc])
        AC_SUBST([localstatedir], [/var])
        AC_SUBST([runstatedir], ['${localstatedir}/run']) ])

pkgdatadir='${datadir}/${PACKAGE_NAME}'
AC_SUBST([pkgdatadir])

AC_ARG_WITH([rundir], [AS_HELP_STRING([--with-rundir=DIR], [Runtime dir (default: ${runstatedir}/<pkgname>)])], [apprundir="$withval"], [apprundir="${runstatedir}/${PACKAGE_NAME}"])
AC_ARG_WITH([confdir], [AS_HELP_STRING([--with-confdir=DIR], [Config dir (default: ${sysconfdir}/<pkgname>)])], [appconfdir="$withval"], [appconfdir="${sysconfdir}/${PACKAGE_NAME}"])
pidfile="${apprundir}/${PACKAGE_NAME}.pid"; envfile="${appconfdir}/.env"
AC_SUBST([apprundir])
AC_SUBST([appconfdir])
AC_SUBST([pidfile])
AC_SUBST([envfile])
AC_SUBST([PYTHON3])

# --- Systemd Unit Directory (Still needed for spec file) ---
systemd_unitdir=""; if test "x$have_systemd" = "xyes"; then systemd_unitdir=`$PKG_CONFIG --variable=systemdsystemunitdir systemd`; if test "x$systemd_unitdir" = "x"; then systemd_unitdir="${libdir}/systemd/system"; fi; else systemd_unitdir="${libdir}/systemd/system"; fi
AC_SUBST([systemd_unitdir]) # Keep this substitution for use in the spec file

# --- Output Files ---
AC_CONFIG_FILES([ Makefile service/yui-bot.service service/yui-bot.initd ])
AC_OUTPUT
AC_MSG_NOTICE([ Configuration Summary: ... (output reflects chosen options) ... ])
