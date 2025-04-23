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

# Create config directory with correct group ownership and permissions
# Runtime directory (/run/yui-bot) is now managed by systemd via RuntimeDirectory= in service file
# install -dpm 750 %{buildroot}%{app_rundir} # REMOVED
install -dpm 750 -g %{app_group} %{buildroot}%{app_confdir} # Ensure group is set correctly

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
# Removed %dir line for %{app_rundir}
%attr(0644, root, root) %{_unitdir}/%{name}.service
# Python configuration script
%attr(0755, root, root) %{_sbindir}/%{app_config_script}


%changelog
* Wed Apr 23 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.18-1
- fix: Use RuntimeDirectory= in systemd unit instead of packaging /run dir.
- build: Remove install of runtime dir from spec %install.
- build: Remove runtime dir from spec %files list.
- build: Ensure config dir group is set correctly in spec %install.
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-5
- build: Correctly remove *all* inline comments from spec file tags (Release, URL).
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.17-4
- build: Remove accidentally duplicated %install directive in spec file.
# ... (rest of changelog omitted for brevity) ...
