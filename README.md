# yui-bot Discord Bot (GuppyGirl Genetics Software)

## Overview

This project provides a Discord bot named **yui-bot**, interfacing with the Google Gemini AI API. It allows users to interact with the AI by mentioning the bot, maintains limited conversation history, and includes features for fetching Linux/Unix man pages.

This bot is designed to run as a system service on RHEL 9+ systems, packaged as an RPM using Autotools for build standardization.

**Features:**

* Responds to @Mentions with queries to the Gemini AI.
* `man <command>` command to fetch man pages via AI.
* `man @BotName` command for detailed bot help (replace @BotName with the bot's actual Discord name, likely 'yui-bot').
* `help` command alias pointing to `man @BotName`.
* Configurable, user/channel-specific conversation history timeout.
* Runs as a systemd service under a dedicated user (`yui-bot`).
* Logging to syslog with multiple levels.
* PID file management to prevent multiple instances.
* RPM package (`yui-bot`) for easy installation on RHEL 9+.

## License

This project is licensed under the BSD-2-Clause license. See the `LICENSE` file for details.
Copyright (c) 2025 Guppy Girl Genetics Software.

## Prerequisites (Runtime)

* Python 3.8+
* Required Python libraries (see `requirements.txt`)
* Access to Discord API (Bot Token)
* Access to Google Gemini API (API Key)
* A running syslog daemon (like rsyslog or systemd-journald)

## Prerequisites (Build - for RPM)

* RHEL 9+ build environment
* `rpm-build`, `rpmdev-setuptree`
* `autoconf`, `automake`
* `python3-devel`, `python3-pip`
* `pkgconfig(systemd)`, `systemd`
* `make`, `findutils`
* `shadow-utils`

## Build Instructions (RPM)

1. Clone the repository or unpack the source tarball.
2. Run `autoreconf --install --force` in the source directory.
3. Run `./configure` (optionally pass flags like `--prefix=/usr`).
4. Run `make distcheck` to create the source tarball (`yui-bot-*.tar.gz`).
5. Set up your `rpmbuild` environment (`rpmdev-setuptree`).
6. Copy the generated tarball to `~/rpmbuild/SOURCES/`.
7. Copy `rpm/yui-bot.spec` to `~/rpmbuild/SPECS/`.
8. Run `rpmbuild -ba ~/rpmbuild/SPECS/yui-bot.spec`.
9. The RPM will be created in `~/rpmbuild/RPMS/noarch/`.

## Installation (RPM)

1. Copy the built RPM to the target RHEL 9+ system.
2. Install the RPM: `sudo dnf install ./yui-bot-*.noarch.rpm`
3. **Important:** Edit the configuration file `/etc/yui-bot/.env` and add your `DISCORD_BOT_TOKEN`, `GEMINI_API_KEY`, and `AUTHOR_DISCORD_ID`. Ensure permissions are correct (`sudo chown yui-bot:yui-bot /etc/yui-bot/.env && sudo chmod 640 /etc/yui-bot/.env`).
4. Install Python dependencies if not handled by the RPM: `sudo python3 -m pip install -r /usr/share/yui-bot/requirements.txt`
5. Enable and start the service:
    ```bash
    sudo systemctl enable yui-bot.service
    sudo systemctl start yui-bot.service
    ```

## Usage

* Invite the bot (likely named "yui-bot" in Discord) to your server.
* Mention the bot: `@yui-bot <your question>`
* Get help: `@yui-bot man @yui-bot` or `@yui-bot help`
* Get man pages: `@yui-bot man <command>`

## Service Management

* Start: `sudo systemctl start yui-bot`
* Stop: `sudo systemctl stop yui-bot`
* Restart: `sudo systemctl restart yui-bot`
* Status: `sudo systemctl status yui-bot`
* Logs: `sudo journalctl -u yui-bot -f`
