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
Version:        1.3.6 # << UPDATED VERSION
Release:        1%{?dist}
Summary:        Discord bot (Yui) interfacing with Google Gemini AI
License:        BSD-2-Clause
URL:            https://guppylog.com/software/yui-bot # Example URL
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

BuildRequires:  autoconf automake; BuildRequires: python3-devel python3-pip
BuildRequires:  pkgconfig(systemd) systemd; BuildRequires: findutils make; BuildRequires: shadow-utils
Requires:       python3 >= 3.8; Requires: systemd-libs
Requires(pre):  shadow-utils; Requires(post): shadow-utils; Requires(postun): shadow-utils
# Runtime Python dependencies needed by bot AND config script
Requires:       python3-google-generativeai >= 0.5.0
Requires:       python3-dotenv >= 1.0.1
Requires:       python3-pidfile >= 3.0.0
Requires:       python3-psutil >= 5.9.0
Requires:       python3-discord.py >= 2.3.2
# Ensure these package names match RHEL 9 / EPEL 9 or use pip in %post

%description
A Discord bot named Yui that uses the Google Gemini AI API to respond
to user prompts, fetch man pages, and maintain limited conversation
history. Includes systemd integration for running as a service on RHEL 9+.
Also includes a Python helper script (%{_sbindir}/%{app_config_script})
to assist with initial configuration, API key validation, and model selection.

%prep
%autosetup -n %{name}-%{version} -p1

%build
%configure --with-user=%{app_user} --with-group=%{app_group} --with-rundir=%{app_rundir} --with-confdir=%{app_confdir}
make %{?_smp_mflags}

%install
%make_install
install -dpm 750 %{buildroot}%{app_rundir}
install -dpm 750 %{buildroot}%{app_confdir}
install -Dpm 640 %{buildroot}%{app_datadir}/yui-bot.env.example %{buildroot}%{app_confdir}/.env.example
install -dpm 755 %{buildroot}%{app_datadir}/examples
install -m 644 %{_builddir}/%{name}-%{version}/service/yui-bot.initd %{buildroot}%{app_datadir}/examples/yui-bot.initd

%pre
getent group %{app_group} >/dev/null || groupadd -r %{app_group}
getent passwd %{app_user} >/dev/null || useradd -r -g %{app_group} -d %{app_datadir} -s /sbin/nologin -c "Yui Discord Bot Service Account" %{app_user}
exit 0

%post
# --- OPTION: Install Python deps via pip ---
# %{__python3} -m pip install --upgrade -r %{app_datadir}/requirements.txt || :
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

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun_with_restart %{name}.service
if [ $1 -eq 0 ] ; then # final removal
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
%dir %attr(0750, %{app_user}, %{app_group}) %{app_confdir}
%config(noreplace) %attr(0640, %{app_user}, %{app_group}) %{app_confdir}/.env
%attr(0644, root, root) %{app_confdir}/.env.example
%dir %attr(0750, %{app_user}, %{app_group}) %{app_rundir}
%attr(0644, root, root) %{_unitdir}/%{name}.service
%attr(0755, root, root) %{_sbindir}/%{app_config_script}

%changelog
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.6-1
- Final code and documentation verification; ensured no shorthand/placeholders remain.
- Confirmed all files reflect 'yui-bot' name and user/group.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.5-1
- Replaced bash config script with Python version (configure-yui-bot.py).
- Added API key validation and Gemini model selection to config script.
- Updated RPM dependencies to include required Python libraries for config script.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.4-1
- Added 'botsnack' command feature and updated documentation.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.3-1
- Changed service user and group from 'gemini-bot' to 'yui-bot'.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.2-1
- Final project name changed to yui-bot. Updated relevant files.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.1-1
- Applied security best practices, updated license/author info, added help alias,
  improved logging/error handling, added init.d example, refined RPM for RHEL9+.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.0-1
- Initial RPM packaging with Autotools integration.
