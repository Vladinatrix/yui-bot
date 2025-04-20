#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.
#
# Configuration helper script for the yui-bot service. (Python Version)
# Sets up the .env file, verifies API key, and selects model.
# Must be run with sudo from a non-root user account.

import os
import sys
import argparse
import getpass
import pwd
import grp
import tempfile
from datetime import datetime

# --- Attempt to import required libraries ---
try: from dotenv import set_key, find_dotenv
except ImportError: print("Error: 'python-dotenv' not found.\nInstall: sudo python3 -m pip install python-dotenv", file=sys.stderr); sys.exit(1)
try: import google.generativeai as genai; from google.api_core import exceptions as google_api_exceptions
except ImportError: print("Error: 'google-generativeai' not found.\nInstall: sudo python3 -m pip install google-generativeai", file=sys.stderr); sys.exit(1)

# --- Configuration ---
APP_NAME = "yui-bot"
CONFIG_DIR = f"/etc/{APP_NAME}"
ENV_FILE = os.path.join(CONFIG_DIR, ".env")
SERVICE_USER = "yui-bot"
SERVICE_GROUP = "yui-bot"
ENV_PERMS = 0o640 # rw-r----- (Octal)
DEFAULT_TIMEOUT_SECS = "3600"
DEFAULT_MODEL_NAME = "gemini-1.5-flash"

# --- Privilege Check ---
def check_privileges():
    """Checks for correct sudo execution."""
    if os.geteuid() != 0:
        print(f"Error: Script needs root privileges.\nPlease run using 'sudo {sys.argv[0]}'.", file=sys.stderr); sys.exit(1)
    if not os.environ.get("SUDO_USER"):
        print("Error: Please run this script using 'sudo' from your regular user account,", file=sys.stderr)
        print("       instead of running it directly as root (e.g., via 'su -' or root login).", file=sys.stderr)
        print("\n  Why use 'sudo'? Better accountability, limited privilege scope, reduced risk.", file=sys.stderr); sys.exit(1)
    print("--> Running with required sudo privileges.")

# --- Get UID/GID ---
def get_service_ids():
    """Gets UID and GID for the service user/group."""
    try: uid = pwd.getpwnam(SERVICE_USER).pw_uid; gid = grp.getgrnam(SERVICE_GROUP).gr_gid; return uid, gid
    except KeyError as e: print(f"Error: Service user '{SERVICE_USER}' or group '{SERVICE_GROUP}' not found: {e}", file=sys.stderr); sys.exit(1)
    except Exception as e: print(f"Error getting service UID/GID: {e}", file=sys.stderr); sys.exit(1)

# --- Fetch Available Models ---
def get_available_models(api_key):
    """Connects to Gemini API and returns list of usable model names."""
    print("--> Verifying API key and fetching available models...")
    try:
        genai.configure(api_key=api_key); models = genai.list_models()
        usable_models = sorted([m.name for m in models if 'generateContent' in m.supported_generation_methods])
        if not usable_models: print("Error: No models supporting content generation found.", file=sys.stderr); return None, "No usable models found."
        print(f"--> Found {len(usable_models)} usable models.")
        model_ids = [name.replace('models/', '') for name in usable_models]
        return model_ids, None
    except (google_api_exceptions.PermissionDenied, google_api_exceptions.Unauthenticated): return None, "API Key is invalid or lacks permissions."
    except Exception as e: return None, f"Error connecting to Gemini API: {type(e).__name__}"

# --- Main Function ---
def main():
    check_privileges()
    uid, gid = get_service_ids()

    parser = argparse.ArgumentParser( description=f"Configure {ENV_FILE} for {APP_NAME}.", formatter_class=argparse.ArgumentDefaultsHelpFormatter )
    parser.add_argument('--token', help="Discord Bot Token")
    parser.add_argument('--apikey', help="Gemini API Key")
    parser.add_argument('--author-id', help="Author's Discord ID (for -dono)")
    parser.add_argument('--timeout', default=DEFAULT_TIMEOUT_SECS, help="Conversation timeout (seconds)")
    parser.add_argument('--model', help=f"Gemini model name (default: {DEFAULT_MODEL_NAME})")
    parser.add_argument('--non-interactive', '-y', action='store_true', help="Run non-interactively (requires --token/--apikey)")
    args = parser.parse_args()

    # Determine Mode & Get Values
    discord_token = args.token; gemini_api_key = args.apikey; author_id = args.author_id; timeout_secs = args.timeout; model_name_arg = args.model

    if args.non_interactive:
        print("--> Running in non-interactive mode.")
        if not discord_token or not gemini_api_key: parser.error("--token and --apikey are required.")
        model_name_arg = model_name_arg or DEFAULT_MODEL_NAME; author_id = author_id or ""; timeout_secs = timeout_secs or DEFAULT_TIMEOUT_SECS
    else: # Interactive Mode
        print(f"--- {APP_NAME} Interactive Configuration ---"); print(f"Configuring: {ENV_FILE}")
        if os.path.exists(ENV_FILE):
            print(f"\nWarning: Config file '{ENV_FILE}' exists."); confirm = input("Overwrite? (y/N): ").strip().lower()
            if confirm != 'y': print("Aborting."); sys.exit(0)
        print("\nEnter required information (input hidden for secrets):")
        while not discord_token: discord_token = getpass.getpass("Discord Bot Token: ")
        while not gemini_api_key: gemini_api_key = getpass.getpass("Gemini API Key:    ")
        print("\nEnter optional information (press Enter for default/skip):")
        author_id = input(f"Author Discord ID (for -dono) [Optional]: ").strip()
        input_timeout = input(f"Conversation Timeout [{DEFAULT_TIMEOUT_SECS}s]: ").strip(); timeout_secs = input_timeout or DEFAULT_TIMEOUT_SECS
        # Model selected after validation

    # Validate Timeout
    try: timeout_int = int(timeout_secs); assert timeout_int > 0; timeout_secs = str(timeout_int)
    except (ValueError, AssertionError): print(f"Warning: Invalid timeout '{timeout_secs}'. Using {DEFAULT_TIMEOUT_SECS}."); timeout_secs = DEFAULT_TIMEOUT_SECS

    # Verify API Key & Get Models
    available_models, error = get_available_models(gemini_api_key)
    if error: print(f"\nError: {error}\nConfiguration aborted.", file=sys.stderr); sys.exit(1)
    if not available_models: print("\nError: Could not retrieve usable models.\nConfiguration aborted.", file=sys.stderr); sys.exit(1)
    print("--> API Key verified.")

    # Select/Validate Model
    final_model_name = ""
    if args.non_interactive:
        if model_name_arg in available_models: final_model_name = model_name_arg; print(f"--> Using specified model: {final_model_name}")
        else: print(f"Error: Specified/Default model '{model_name_arg}' unavailable.\nAvailable: {', '.join(available_models)}", file=sys.stderr); sys.exit(1)
    else: # Interactive Model Selection
        print("\nAvailable Gemini Models:")
        for i, m_name in enumerate(available_models): print(f"  {i+1}) {m_name}")
        default_choice_num = -1
        try: default_choice_num = available_models.index(DEFAULT_MODEL_NAME) + 1
        except ValueError: pass
        prompt = f"Select model number to use [{DEFAULT_MODEL_NAME}]: "
        while not final_model_name:
            try:
                choice_str = input(prompt).strip()
                if not choice_str and default_choice_num != -1: choice = default_choice_num
                elif not choice_str: choice = 1 # Fallback to first if default invalid
                else: choice = int(choice_str)
                if 1 <= choice <= len(available_models): final_model_name = available_models[choice - 1]; print(f"Selected model: {final_model_name}")
                else: print(f"Invalid selection. Enter 1-{len(available_models)}.")
            except ValueError: print("Invalid input. Please enter a number.")

    # Final Confirmation (Interactive)
    if not args.non_interactive:
        print("\n--- Configuration Summary ---")
        print(f"Discord Token:       [REDACTED]"); print(f"Gemini API Key:      [REDACTED]")
        print(f"Author Discord ID:   {author_id or '<Not Set>'}"); print(f"Timeout Seconds:     {timeout_secs}")
        print(f"Gemini Model:        {final_model_name}"); print(f"Target File:         {ENV_FILE}")
        print(f"Owner/Permissions:   {SERVICE_USER}:{SERVICE_GROUP} / {oct(ENV_PERMS)[2:]}") # Show octal perms
        confirm_write = input("\nProceed with writing this configuration? (y/N): ").strip().lower()
        if confirm_write != 'y': print("Configuration aborted."); sys.exit(0)

    # Write .env File
    print(f"\nWriting configuration to {ENV_FILE}...")
    temp_path = None # Define temp_path outside try for cleanup
    try:
        os.makedirs(CONFIG_DIR, mode=0o750, exist_ok=True)
        # Use temp file for atomic write
        temp_fd, temp_path = tempfile.mkstemp(dir=CONFIG_DIR, prefix=".env.tmp")
        with os.fdopen(temp_fd, 'w') as f:
            f.write(f"# Configuration for {APP_NAME} - Generated by configuration script\n"); f.write(f"# {datetime.now().isoformat()}\n\n")
            f.write("# Required: Discord Bot Token\n"); f.write(f"DISCORD_BOT_TOKEN={discord_token}\n\n")
            f.write("# Required: Google Generative AI (Gemini) API Key\n"); f.write(f"GEMINI_API_KEY={gemini_api_key}\n\n")
            f.write("# Gemini Model to use (verified available)\n"); f.write(f"GEMINI_MODEL_NAME={final_model_name}\n\n")
            f.write("# Conversation history timeout in seconds\n"); f.write(f"CONVERSATION_TIMEOUT_SECONDS={timeout_secs}\n\n")
            f.write("# Optional: Author's Discord User ID for '-dono' honorific\n"); f.write(f"AUTHOR_DISCORD_ID={author_id}\n")
        os.chown(temp_path, uid, gid); os.chmod(temp_path, ENV_PERMS)
        os.replace(temp_path, ENV_FILE); print(f"Successfully wrote configuration to {ENV_FILE}")
        print("Final permissions:"); os.system(f"ls -l {ENV_FILE}")
        temp_path = None # Prevent cleanup if successful

    except Exception as e:
        print(f"\nError writing configuration file: {e}", file=sys.stderr)
        # Clean up temp file if it still exists after failure
        if temp_path and os.path.exists(temp_path): # << CORRECTED CHECK AND CLEANUP
            try:
                os.remove(temp_path)
                print(f"Cleaned up temporary file: {temp_path}")
            except OSError as rm_err:
                print(f"Warning: Could not remove temporary file {temp_path}: {rm_err}", file=sys.stderr)
        sys.exit(1)

    print("\nConfiguration complete!"); print("You may need to restart the service:"); print(f"  sudo systemctl restart {APP_NAME}.service")
    sys.exit(0)

if __name__ == "__main__":
    main()
