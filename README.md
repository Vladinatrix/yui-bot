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

## License

This project is licensed under the BSD-2-Clause license. See the `LICENSE` file for details.
Copyright (c) 2025 Guppy Girl Genetics Software.

## Prerequisites (Runtime)

* Python 3.8+
* Required Python libraries: `discord.py`, `google-generativeai`, `python-dotenv`, `python-pidfile`, `psutil` (see `requirements.txt`)
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

1.  Clone the repository or unpack the source tarball (`yui-bot-*.tar.gz`).
2.  Run `autoreconf --install --force` in the source directory.
3.  Run `./configure` (optionally pass flags like `--prefix=/usr`).
4.  Run `make distcheck` to create the source tarball (`yui-bot-*.tar.gz`).
5.  Set up your `rpmbuild` environment (`rpmdev-setuptree`).
6.  Copy the generated tarball to `~/rpmbuild/SOURCES/`.
7.  Copy `rpm/yui-bot.spec` to `~/rpmbuild/SPECS/`.
8.  Run `rpmbuild -ba ~/rpmbuild/SPECS/yui-bot.spec`.
9.  The RPM will be created in `~/rpmbuild/RPMS/noarch/`.

## Installation (RPM)

1.  Copy the built RPM to the target RHEL 9+ system.
2.  Install the RPM: `sudo dnf install ./yui-bot-*.noarch.rpm`
    *(This should install the bot, service files, config script, and pull dependencies listed in Requires if available in repos)*
3.  **Important: Configure Secrets & Settings:**
    * **Method A (Recommended): Run the helper script using `sudo`:**
        ```bash
        # Interactive mode (recommended first time)
        sudo /usr/sbin/configure-yui-bot.py --interactive

        # Or provide all required args non-interactively
        # sudo /usr/sbin/configure-yui-bot.py --token YOUR_TOKEN --apikey YOUR_KEY [--author-id ID] [--timeout SECS] [--model NAME]
        ```
    * This script will guide you (prompting for values), verify your Gemini API key, let you select an available model, and create `/etc/yui-bot/.env` with the correct content, ownership (`yui-bot:yui-bot`), and permissions (`640`).
    * **Note:** Ensure Python 3 and the required libraries (`google-generativeai`, `python-dotenv`) are installed before running the configure script if they weren't pulled in automatically by the RPM installation (see step 4).
    * **Method B (Manual):**
        * Copy the example: `sudo cp /etc/yui-bot/.env.example /etc/yui-bot/.env`
        * Edit the new file: `sudo nano /etc/yui-bot/.env` (or use another editor)
        * Add your `DISCORD_BOT_TOKEN`, `GEMINI_API_KEY`, and optional `AUTHOR_DISCORD_ID`. Set `GEMINI_MODEL_NAME` and `CONVERSATION_TIMEOUT_SECONDS` if desired.
        * Set ownership and permissions: `sudo chown yui-bot:yui-bot /etc/yui-bot/.env && sudo chmod 640 /etc/yui-bot/.env`
4.  **[If needed] Install Python Dependencies Manually:** If the RPM `Requires` did not cover all Python libraries (e.g., if `python3-google-generativeai` isn't in your repos), install them now:
    ```bash
    sudo python3 -m pip install -r /usr/share/yui-bot/requirements.txt
    ```
5.  Enable and start the service:
    ```bash
    sudo systemctl enable yui-bot.service
    sudo systemctl start yui-bot.service
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
* Logs: `sudo journalctl -u yui-bot -f`
