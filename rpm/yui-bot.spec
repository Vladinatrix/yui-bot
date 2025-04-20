# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# RPM Spec file for yui-bot

# Define globals for user/group/dirs consistently
%global app_name yui-bot
%global app_user yui-bot # << CHANGED User
%global app_group yui-bot # << CHANGED Group
%global app_confdir %{_sysconfdir}/%{app_name}
%global app_rundir %{_localstatedir}/run/%{app_name}
%global app_datadir %{_datadir}/%{app_name}

Name:           %{app_name}
Version:        1.3.3 # << UPDATED VERSION
Release:        1%{?dist}
Summary:        Discord bot (Yui) interfacing with Google Gemini AI
License:        BSD-2-Clause
URL:            [https://guppylog.com/software/yui-bot](https://guppylog.com/software/yui-bot) # Example URL
Source0:        %{name}-%{version}.tar.gz

BuildArch:      noarch

# Build Dependencies
BuildRequires:  autoconf automake
BuildRequires:  python3-devel python3-pip
BuildRequires:  pkgconfig(systemd) systemd
BuildRequires:  findutils make
BuildRequires:  shadow-utils

# Runtime Dependencies
Requires:       python3 >= 3.8
Requires:       systemd-libs
Requires(pre):  shadow-utils
Requires(post): shadow-utils
Requires(postun): shadow-utils
# Requires(post): python3-pip # If installing deps via pip in %post

%description
A Discord bot named Yui that uses the Google Gemini AI API to respond
to user prompts, fetch man pages, and maintain limited conversation
history. Includes systemd integration for running as a service on RHEL 9+.
An example SysVinit script is also included for reference.

%prep
%autosetup -n %{name}-%{version}

%build
%configure \
    --with-user=%{app_user} \
    --with-group=%{app_group} \
    --with-rundir=%{app_rundir} \
    --with-confdir=%{app_confdir}
make %{?_smp_mflags}

%install
%make_install
install -dpm 750 %{buildroot}%{app_rundir}
install -dpm 750 %{buildroot}%{app_confdir}
install -Dpm 640 %{buildroot}%{app_datadir}/yui-bot.env.example %{buildroot}%{app_confdir}/.env.example
install -dpm 755 %{buildroot}%{app_datadir}/examples
install -m 644 %{_builddir}/%{name}-%{version}/service/yui-bot.initd %{buildroot}%{app_datadir}/examples/yui-bot.initd

%pre
# Create group and user yui-bot if they don't exist
getent group %{app_group} >/dev/null || groupadd -r %{app_group}
getent passwd %{app_user} >/dev/null || useradd -r -g %{app_group} -d %{app_datadir} -s /sbin/nologin -c "Yui Discord Bot Service Account" %{app_user} # << UPDATED USER/DESC
exit 0

%post
# --- OPTION: Install Python deps via pip ---
# %{__python3} -m pip install --upgrade -r %{app_datadir}/requirements.txt || :
%systemd_post %{name}.service

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun_with_restart %{name}.service
if [ $1 -eq 0 ] ; then # final removal
    getent passwd %{app_user} >/dev/null && userdel %{app_user} || : # << REMOVE yui-bot user
    getent group %{app_group} >/dev/null && groupdel %{app_group} || : # << REMOVE yui-bot group
fi
exit 0

%files
%license %attr(0644, root, root) LICENSE
%doc README.md
%dir %attr(0755, root, root) %{app_datadir}
%dir %attr(0755, root, root) %{app_datadir}/examples
%doc %attr(0644, root, root) %{app_datadir}/examples/yui-bot.initd
%attr(0755, root, root) %{app_datadir}/yui_bot.py # << Script name
%attr(0644, root, root) %{app_datadir}/requirements.txt
%attr(0644, root, root) %{app_datadir}/yui-bot.env.example # << Example name
%dir %attr(0750, %{app_user}, %{app_group}) %{app_confdir} # << Ownership
%config(noreplace) %attr(0640, %{app_user}, %{app_group}) %{app_confdir}/.env # << Ownership
%attr(0644, root, root) %{app_confdir}/.env.example
%dir %attr(0750, %{app_user}, %{app_group}) %{app_rundir} # << Ownership
%attr(0644, root, root) %{_unitdir}/%{name}.service

%changelog
* Sun Apr 20 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.3-1
- Changed service user and group to 'yui-bot'.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.2-1
- Final project name changed to yui-bot. Updated relevant files.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.1-1
- Apply security best practices: fixed shebang, systemd hardening, refined RPM permissions.
- Updated license headers and author information. Refactored for RHEL 9+.
- Added 'help' alias. Included init.d script as doc. Improved logging/error handling.
* Sat Apr 19 2025 Wynona Stacy Lockwood <stacy@guppylog.com> - 1.3.0-1
- Initial RPM packaging with Autotools integration.
