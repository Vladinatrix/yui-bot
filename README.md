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
* `rpmlint`, `git`, `tar`, `gzip`, `gcc` (for running `make smokecheck` or `make distcheck`)

## Build Instructions (RPM)

There are two main ways to build the RPM:

**Method 1: Using Make Targets (Recommended)**

1.  Clone the repository or unpack the source tarball (`yui-bot-*.tar.gz`).
2.  Ensure you have the RPM build environment and prerequisites installed (see above). Run `rpmdev-setuptree` once if needed.
3.  Run `autoreconf --install --force` in the source directory to generate the `configure` script.
4.  Run `./configure` (optionally pass flags like `--prefix=/usr` or path overrides).
5.  **(Optional) Run Smoke Tests:** Before building the final package, you can run checks:
    ```bash
    make smokecheck
    ```
    This executes `test-project.sh` which performs syntax checks, attempts prerequisite installs via `sudo dnf`, runs `make distcheck`, and lints the spec file. Review its output carefully.
6.  Run `make rpm` to build both the binary RPM and the source RPM (SRPM).
    * Alternatively, run `make srpm` to build
