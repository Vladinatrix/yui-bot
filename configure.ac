# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
dnl Process this file with autoconf to produce a configure script.
#
AC_PREREQ([2.69])
# Initialize package info (Version 1.3.21 - Fix python script errors)
AC_INIT([yui-bot], [1.3.21], [stacy@guppylog.com]) # << UPDATED VERSION
AC_CONFIG_SRCDIR([yui_bot.py])
AM_INIT_AUTOMAKE([-Wall -Werror foreign])
dnl AC_CONFIG_MACRO_DIRS([m4])

# --- Checks for Programs ---
AC_PROG_INSTALL
AC_PROG_MKDIR_P
AC_PROG_LN_S

AC_CHECK_PROG([PYTHON3], [python3], [python3], [], [/usr/bin:/usr/local/bin])
if test "x$PYTHON3" = "x"; then echo "configure: error: python3 interpreter not found" >&2; exit 1; fi
AC_CHECK_PROG([PIP3], [pip3], [pip3], [], [/usr/bin:/usr/local/bin])
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

# --- Define and Evaluate Installation Paths ---
AC_PREFIX_DEFAULT([/usr])
AC_SUBST([prefix])
AC_SUBST([exec_prefix])
AC_SUBST([sysconfdir])
AC_SUBST([localstatedir])
AC_SUBST([runstatedir])
AC_SUBST([libdir])
AC_SUBST([datadir])
AC_SUBST([datarootdir])
eval eval_prefix=\"$prefix\"
eval eval_exec_prefix=\"$exec_prefix\"
eval eval_sysconfdir=\"$sysconfdir\"
eval eval_localstatedir=\"$localstatedir\"
eval eval_runstatedir=\"$runstatedir\"
eval eval_libdir=\"$libdir\"
eval eval_datarootdir=\"$datarootdir\"
eval eval_datadir=\"$datadir\"
AS_IF([test "x$eval_prefix" = "x/usr"],
      [ eval_sysconfdir="/etc"
        eval_localstatedir="/var"
        eval_runstatedir='${eval_localstatedir}/run'; eval eval_runstatedir=\"<span class="math-inline">eval\_runstatedir\\"
eval\_datadir\='</span>{eval_datarootdir}'; eval eval_datadir=\"<span class="math-inline">eval\_datadir\\"
\]\)
final\_pkgdatadir\="</span>{eval_datadir}/<span class="math-inline">\{PACKAGE\_NAME\}"
final\_appconfdir\_default\="</span>{eval_sysconfdir}/<span class="math-inline">\{PACKAGE\_NAME\}"
final\_apprundir\_default\="</span>{eval_runstatedir}/${PACKAGE_NAME}"
AC_ARG_WITH([rundir], [AS_HELP_STRING([--with-rundir=DIR], [Runtime dir (default based on prefix)])],
            [final_apprundir_arg="$withval"], [final_apprundir_arg="$final_apprundir_default"])
AC_ARG_WITH([confdir], [AS_HELP_STRING([--with-confdir=DIR], [Config dir (default based on prefix)])],
            [final_appconfdir_arg="$withval"], [final_appconfdir_arg="$final_appconfdir_default"])
eval final_apprundir=\"$final_apprundir_arg\"
eval final_appconfdir=\"<span class="math-inline">final\_appconfdir\_arg\\"
final\_pidfile\="</span>{final_apprundir}/<span class="math-inline">\{PACKAGE\_NAME\}\.pid"
final\_envfile\="</span>{final_appconfdir}/
