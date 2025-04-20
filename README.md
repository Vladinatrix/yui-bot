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
* Runs as a systemd service under a dedicated user (`yui-bot`).
* Logging to syslog with multiple levels.
* PID file management to prevent multiple instances.
* RPM package (`yui-bot`) for easy installation on RHEL 9+.

## License

This project is licensed under the BSD-2-Clause license. See the `LICENSE` file for details.
Copyright (c) 2025 Guppy Girl Genetics Software.

## Prerequisites (Runtime)
*(Same as before)*

## Prerequisites (Build - for RPM)
*(Same as before)*

## Build Instructions (RPM)
*(Same as before)*

## Installation (RPM)
*(Same as before, ensure user runs `chown yui-bot:yui-bot /etc/yui-bot/.env`)*

## Usage

* Invite the bot (likely named "yui-bot" in Discord) to your server.
* Mention the bot: `@yui-bot <your question>`
* Get help: `@yui-bot man @yui-bot` or `@yui-bot help`
* Get man pages: `@yui-bot man <command>`
* Give the bot a snack: `@yui-bot botsnack` (or `@yui-bot bot snack`)

## Service Management
*(Same as before)*
