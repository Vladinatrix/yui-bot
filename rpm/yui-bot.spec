# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
# RPM Spec file for yui-bot

%global app_name yui-bot
%global app_user yui-bot
%global app_group yui-bot
%global app_confdir %{_sysconfdir}/%{app_name}
%global app_rundir %{_localstatedir}/run/%{app_name}
%global app_datadir %{_datadir}/%{app_name}
%global app_config_script configure-%{app_name}.py

Name:           %{app_name}
Version:        1.3.20
Release:        6%{?dist}
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
# Core requirements provided by the OS
Requires:       python3 >= 3.8
Requires:       systemd-libs
# Scriptlets need shadow-utils during install/uninstall phases
Requires(pre):  shadow-utils
Requires(post): shadow-utils
Requires(postun): shadow-utils
# REMOVED: Specific Python library Requires - these will be installed via pip
# Requires:       python3-google-generativeai >= 0.5.0
# Requires:       python3-dotenv >= 1.0.1
# Requires:       python3-pidfile >= 3.0.0
# Requires:       python3-psutil >= 5.9.0
# Requires:       python3-discord.py >= 2.3.2

%description
A Discord bot named Yui that uses the Google Gemini AI API to respond
to user prompts, fetch man pages, and maintain limited conversation
history. Includes systemd integration for running as a service on RHEL 9+.
Also includes a Python helper script (%{_sbindir}/%{app_config_script})
to assist with initial configuration, API key validation, and model selection.

NOTE: Requires manual installation of Python dependencies via pip after
installing this package (see %post instructions or README.md).

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
# Create config directory
install -dpm 750 %{buildroot}%{app_confdir}
# Install example config file
install -Dpm 640 %{buildroot}%{app_datadir}/yui-bot.env.example %{buildroot}%{app_confdir}/.env.example
# Install example init.d script
install -dpm 755 %{buildroot}%{app_datadir}/examples
install -m 644 %{_builddir}/%{name}-%{version}/service/yui-bot.initd %{buildroot}%{app_datadir}/examples/yui-bot.initd
# Move the installed systemd service file
install -dpm 755 %{buildroot}%{_unitdir}
mv %{buildroot}%{app_datadir}/yui-bot.service %{buildroot}%{_unitdir}/%{name}.service

%pre -p /bin/sh
getent group %{app_group} >/dev/null || groupadd -r %{app_group}
getent passwd %{app_user} >/dev/null || useradd -r -g %{app_group} -d %{app_datadir} -s /sbin/nologin -c "Yui Discord Bot Service Account" %{app_user}
exit 0

%post -p /bin/sh
%systemd_post %{name}.service
echo "----------------------------------------------------------------------"
echo " yui-bot has been installed."
echo " IMPORTANT: You must install Python dependencies AND configure API keys"
echo "            before starting the service."
echo "  1. Install Python dependencies:"
echo "     sudo python3 -m pip install -r %{app_datadir}/requirements.txt"
echo "  2. Run 'sudo %{_sbindir}/%{app_config_script}' (interactive or with args)"
echo "     to validate keys, select model, and create '%{app_confdir}/.env'."
echo "  3. OR manually create/edit '%{app_confdir}/.env' based on the example,"
echo "     then ensure ownership '%{app_user}:%{app_group}' and permissions '640'."
echo "  4. Then, start the service: 'sudo systemctl start %{name}.service'"
echo "----------------------------------------------------------------------"

%preun -p /bin/sh
%systemd_preun %{name}.service

%postun -p /bin/sh
%systemd_postun_with_restart %{name}.service
if [ $1 -eq 0 ] ; then
    # Final removal
    getent passwd %{app_user} >/dev/null && userdel %{app_user} || :
    getent group %{app_group} >/dev/null && groupdel %{app_group} || :
fi
exit 0

%files
%license LICENSE
%doc README.md
%dir %attr(0755, root, root) %{app_datadir}
%dir %attr(0755, root, root) %{app_datadir}/examples
%doc %attr(0644, root, root) %{app_datadir}/examples/yui-bot.initd
%attr(0755, root, root) %{app_datadir}/yui_bot.py
# requirements.txt is needed for pip install post-install
%attr(0644, root, root) %{app_datadir}/requirements.txt
%attr(0644, root, root) %{app_datadir}/yui-bot.env.example
%dir %attr(0750, root, %{app_group}) %{app_confdir}
%attr(0644, root, root) %{app_confdir}/.env.example
%attr(0644, root, root) %{_unitdir}/%{name}.service
%attr(0755, root, root) %{_sbindir}/%{app_config_script}


%changelog
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.20-3
- build: Remove Requires for Python libs; handled by pip post-install.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.20-2
- build: Remove unpackaged LICENSE/README from install section.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.20-1
- build: Prevent LICENSE/README from being installed by make install.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.19-2
- build: Remove actual .env file from spec files list (created post-install).
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.19-1
- build: Correct path evaluation and substitution logic in configure.ac.
- fix: Ensure service templates use standard @variable@ substitutions.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-4
- build: Reword changelog descriptions to avoid rpmlint macro warnings.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-3
- build: Remove group ownership setting from spec install section for config dir.
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-2
- build: Remove diagnostic scripts from Makefile.am EXTRA_DIST.
- build: Reword changelog entries to avoid rpmlint macro warnings (Initial pass).
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-1
- fix: Use RuntimeDirectory= in systemd unit instead of packaging /run dir.
- build: Remove install of runtime dir from spec install section.
- build: Remove runtime dir from spec files list.
- build: Ensure config dir group is set correctly in spec install section (Attempt 1).
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-5
- build: Correctly remove *all* inline comments from spec file tags (Release, URL).
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-4
- build: Remove accidentally duplicated install directive in spec file.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-1
- build: Install systemd file to pkgdatadir via Makefile.am, move in spec install section.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.16-1
- build: Use install/uninstall hooks for systemd file to respect DESTDIR (Failed).
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.15-1
- build: Place all Autoconf macros on separate lines in configure.ac.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.14-1
- build: Separate macros in configure.ac onto own lines to fix syntax error.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.13-1
- build: Remove stray semicolon after PKG_CHECK_MODULES in configure.ac.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.12-1
- build: Fix non-POSIX var/comment and systemd dir var in Makefile.am.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.11-1
- build: Fix unportable '#' comments inside Makefile.am rpm/srpm rules.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.10-1
- build: Use shell echo/exit instead of AC_MSG_FAILURE in configure.ac.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.9-1
- build: Replace AC_MSG_ERROR with AC_MSG_FAILURE in configure.ac workaround.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.8-1
- fix: Corrected syntax error in configure-yui-bot.py cleanup logic.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.7-1
- Added 'make smokecheck' target to execute test-project.sh.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.6-1
- Final code/doc verification; ensured no shorthand/placeholders remain.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.5-1
- Replaced bash config script with Python version; added API validation/model select.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.4-1
- Added 'botsnack' command feature and updated documentation.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.3-1
- Changed service user and group from 'gemini-bot' to 'yui-bot'.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.2-1
- Final project name changed to yui-bot. Updated relevant files.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.1-1
- Applied security best practices, license/author info, help alias, logging, etc.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.0-1
- Initial RPM packaging with Autotools integration.
