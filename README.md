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
