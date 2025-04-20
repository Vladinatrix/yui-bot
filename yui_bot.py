#!/usr/bin/python3
# -*- coding: utf-8 -*-
#
# Copyright (c) 2025 Guppy Girl Genetics Software
# SPDX-License-Identifier: BSD-2-Clause
# See LICENSE file for full text.

# Standard Library Imports
import discord
import os
import sys
import asyncio
import datetime
from datetime import timedelta
import re
import logging
import logging.handlers
import signal
import argparse
import contextlib

# Third-Party Imports
try: import google.generativeai as genai; from google.api_core import exceptions as google_api_exceptions; from google.generativeai import types as genai_types
except ImportError: print("Error: 'google-generativeai' not found. Install: `pip install google-generativeai`", file=sys.stderr); sys.exit(1)
try: from dotenv import load_dotenv
except ImportError: print("Error: 'python-dotenv' not found. Install: `pip install python-dotenv`", file=sys.stderr); sys.exit(1)
try: import pidfile
except ImportError: print("Error: 'python-pidfile' not found. Install: `pip install python-pidfile>=3.0.0`", file=sys.stderr); sys.exit(1)
try: import psutil
except ImportError: print("Error: 'psutil' not found. Install: `pip install psutil`", file=sys.stderr); sys.exit(1)

# --- Constants ---
APP_NAME = "yui-bot"
DEFAULT_CONFIG_DIR = f"/etc/{APP_NAME}"
DEFAULT_RUN_DIR = f"/var/run/{APP_NAME}"
PID_FILENAME = f"{APP_NAME}.pid"
DEFAULT_PID_PATH = os.path.join(DEFAULT_RUN_DIR, PID_FILENAME)
DEFAULT_ENV_FILE = os.path.join(DEFAULT_CONFIG_DIR, ".env")

MAX_MESSAGE_LENGTH = 1990
BOTSNACK_VIDEO_URL = "https://www.youtube.com/watch?v=vGcHnP4_i3g" # C is for Lettuce URL

# --- Logger Setup ---
logger = logging.getLogger(APP_NAME)

def setup_logging(log_level_str='INFO', log_to_console=False):
    """Configures logging to syslog and optionally console."""
    try: log_level = getattr(logging, log_level_str.upper())
    except AttributeError: print(f"Warning: Invalid log level '{log_level_str}'. Defaulting to INFO.", file=sys.stderr); log_level = logging.INFO
    logger.setLevel(log_level)
    if logger.hasHandlers(): logger.handlers.clear() # Prevent duplicate handlers
    formatter = logging.Formatter(f'{APP_NAME}[%(process)d]: %(levelname)s - %(message)s') # Syslog-like format

    # Syslog Handler
    syslog_address = '/dev/log' # Default for Linux
    if sys.platform == 'darwin': syslog_address = '/var/run/syslog'
    elif not os.path.exists(syslog_address) and not isinstance(syslog_address, tuple) :
         # Fallback for systems where /dev/log isn't a socket (rare)
         try: import socket; syslog_address = ('127.0.0.1', 514); socket.socket(socket.AF_INET, socket.SOCK_DGRAM); logger.debug("Using UDP syslog fallback.")
         except Exception: syslog_address = '/dev/log'; logger.debug("Reverting to /dev/log for syslog.") # Revert if socket fails

    try:
        syslog_handler = logging.handlers.SysLogHandler(address=syslog_address)
        syslog_handler.setFormatter(formatter)
        logger.addHandler(syslog_handler)
        addr_str = f"{syslog_address[0]}:{syslog_address[1]}" if isinstance(syslog_address, tuple) else syslog_address
        logger.debug(f"Logging initialized. Level: {logging.getLevelName(log_level)}. Output: Syslog ({addr_str})")
    except Exception as e:
        # Fallback if syslog isn't available? Log to stderr?
        print(f"Warning: Could not setup syslog handler ({syslog_address}): {e}. Check syslog service/permissions.", file=sys.stderr)
        log_to_console = True # Force console logging if syslog fails

    # Console Handler (stderr)
    if log_to_console:
        console_handler = logging.StreamHandler(sys.stderr) # Log to stderr
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)
        logger.debug("Console logging enabled.")

# --- Configuration Loading ---
def load_configuration(env_file_path):
    """Loads configuration from .env file, validates, returns config dict."""
    logger.info(f"Loading configuration from: {env_file_path}")
    if not os.path.isfile(env_file_path):
        logger.critical(f"Configuration file not found or is not a file: {env_file_path}")
        sys.exit(1)
    if not os.access(env_file_path, os.R_OK):
         logger.critical(f"Configuration file not readable: {env_file_path}. Check permissions.")
         sys.exit(1)

    try:
        load_dotenv(dotenv_path=env_file_path, override=True) # Override existing env vars if set in file
    except Exception as e:
        logger.critical(f"Error loading .env file ({env_file_path}): {e}", exc_info=True)
        sys.exit(1)

    config = {}
    config['DISCORD_BOT_TOKEN'] = os.getenv("DISCORD_BOT_TOKEN")
    config['GEMINI_API_KEY'] = os.getenv("GEMINI_API_KEY")
    config['GEMINI_MODEL_NAME'] = os.getenv("GEMINI_MODEL_NAME", "gemini-1.5-flash")
    config['AUTHOR_DISCORD_ID'] = os.getenv("AUTHOR_DISCORD_ID")
    config['ENV_FILE_PATH'] = env_file_path # Store path for reference

    # Validate required variables
    if not config['DISCORD_BOT_TOKEN']: logger.critical("DISCORD_BOT_TOKEN missing."); sys.exit(1)
    if not config['GEMINI_API_KEY']: logger.critical("GEMINI_API_KEY missing."); sys.exit(1)
    if not config['AUTHOR_DISCORD_ID']: logger.warning("AUTHOR_DISCORD_ID missing. -dono disabled.")
    else: logger.info(f"Author Discord ID loaded: {config['AUTHOR_DISCORD_ID']}")


    # Conversation Timeout
    timeout_str = os.getenv("CONVERSATION_TIMEOUT_SECONDS", "3600")
    try:
        config['CONVERSATION_TIMEOUT_SECONDS'] = int(timeout_str)
        if config['CONVERSATION_TIMEOUT_SECONDS'] <= 0: raise ValueError("Timeout must be positive")
    except (ValueError, TypeError):
        logger.warning(f"Invalid CONVERSATION_TIMEOUT_SECONDS ('{timeout_str}'). Defaulting 3600.")
        config['CONVERSATION_TIMEOUT_SECONDS'] = 3600
    config['CONVERSATION_TIMEOUT_DELTA'] = timedelta(seconds=config['CONVERSATION_TIMEOUT_SECONDS'])
    logger.info(f"Conversation timeout: {config['CONVERSATION_TIMEOUT_SECONDS']}s.")

    logger.info("Configuration loaded.")
    return config

# --- Global Variables ---
conversations = {}
config = {}
discord_client = None
gemini_model = None
# Man page content template (formatted in on_ready)
BASE_BOT_MAN_PAGE_CONTENT = """
NAME
    {bot_name} - An AI assistant Discord bot powered by Google Gemini.

SYNOPSIS
    @{bot_name} <prompt>
    @{bot_name} man <command_name>
    @{bot_name} man @{bot_name}
    @{bot_name} help
    @{bot_name} botsnack | bot snack

DESCRIPTION
    {bot_name} integrates with Google's Gemini AI ({gemini_model_name} model) to answer questions, generate text, and provide information directly within Discord. It operates by responding to direct mentions.

    It includes a feature to fetch and display standard Linux/Unix man pages by querying the AI, and provides its own documentation via the `man @{bot_name}` command. The `help` command provides a pointer to the full documentation. It also has a fun 'botsnack' command.

COMMANDS
    <prompt>
        When you mention the bot followed by any text (not matching the commands below), the text is treated as a prompt and sent to the Gemini AI for a response.

    man <command_name>
        Requests the standard manual page content for the specified <command_name>. The bot asks the Gemini AI to generate this content. If the AI cannot find or generate the man page, a standard 'no manual entry' error is returned.

    man @{bot_name}
        Displays this man page, providing detailed documentation on how to use the bot.

    help
        Displays a short message directing you to use the `man @{bot_name}` command for full help.

    botsnack | bot snack
        Replies with "OM NOM NOM!" and a link to a certain song about lettuce.

CONVERSATION HISTORY
    The bot maintains a limited conversation history for each user within each specific channel.
    - Context is remembered and sent back to the AI for follow-up questions.
    - History is kept only if the time between consecutive interactions is less than the configured timeout.
    - Current Timeout: {timeout_seconds} seconds ({timeout_delta}).
    - Mentioning the bot or receiving a response resets the timer for that specific conversation thread.
    - History is specific to a user AND channel.
    - All history is lost when the bot program restarts.

CONFIGURATION (For Bot Runner)
    The conversation history timeout (`CONVERSATION_TIMEOUT_SECONDS`) and Author ID (`AUTHOR_DISCORD_ID`) can be set in the configuration file ({env_file_path}). The bot service must be restarted after changing the file. Current setting: {timeout_seconds} seconds.

EXAMPLES
    @{bot_name} What is the airspeed velocity of an unladen swallow?
    @{bot_name} man systemd
    @{bot_name} man @{bot_name}
    @{bot_name} help
    @{bot_name} botsnack

NOTES
    Powered by `google-generativeai` and `discord.py`. AI responses depend on the underlying Gemini model. Requires specific Discord Intents (Messages, Message Content, Guilds). Ensure the bot has appropriate permissions in the channels it operates in. Check service logs for detailed operational information (e.g., using `journalctl -u {app_name}`).
"""
BOT_MAN_PAGE_CONTENT = "Bot man page content loading..."

# --- Helper Function for Honorifics ---
def format_user_mention(user_obj, author_id_config_str):
    """Formats user mentions with appropriate honorifics."""
    author_id_str = str(author_id_config_str) if author_id_config_str else None
    user_id_str = str(user_obj.id)
    name = user_obj.display_name # Use display_name for server nicknames

    if author_id_str and user_id_str == author_id_str:
        return f"@{name}-dono"
    elif user_obj.bot:
        return f"@{name}-chan"
    else:
        # Default for all other humans
        return f"@{name}-san"

# --- Other Helper Functions (History, Split Message) ---
def get_relevant_history(channel_id, user_id, current_time_utc):
    """Retrieves and filters conversation history based on timeout."""
    history_key = (channel_id, user_id)
    user_channel_history = conversations.get(history_key, [])

    if not user_channel_history:
        return [] # No history exists

    # Check expiration based on last message timestamp
    last_message_time = user_channel_history[-1]['timestamp']
    if current_time_utc - last_message_time > config['CONVERSATION_TIMEOUT_DELTA']:
        logger.debug(f"History expired for {history_key}. Clearing.")
        conversations[history_key] = [] # Clear expired history
        return []

    # Filter for continuity, iterating backwards
    relevant_history_indices = []
    last_valid_index = len(user_channel_history) - 1
    relevant_history_indices.append(last_valid_index)

    for i in range(len(user_channel_history) - 2, -1, -1):
        this_msg_time = user_channel_history[i]['timestamp']
        next_msg_time = user_channel_history[i+1]['timestamp']
        if next_msg_time - this_msg_time <= config['CONVERSATION_TIMEOUT_DELTA']:
            relevant_history_indices.append(i)
        else:
            # Gap too large, stop including older messages
            logger.debug(f"History continuity break before index {i} for {history_key}.")
            break

    # Retrieve messages in chronological order and format for API
    relevant_history = [user_channel_history[idx] for idx in sorted(relevant_history_indices)]
    gemini_api_history = [{'role': msg['role'], 'parts': msg['parts']} for msg in relevant_history]

    logger.debug(f"Using {len(gemini_api_history)} relevant history messages for {history_key}")
    return gemini_api_history

async def send_split_message(channel, text):
    """Sends potentially long messages, splitting respecting code blocks."""
    try:
        in_code_block = False; block_prefix = ""; block_suffix = "\n```"; text_inside = text
        # Improved code block detection
        if text.startswith("```") and text.endswith("```"):
            try:
                first_nl = text.index('\n') + 1
                last_nl = text.rindex('\n')
                if last_nl > first_nl: # Ensure there's content inside
                    block_prefix = text[:first_nl]
                    block_suffix = text[last_nl:]
                    text_inside = text[first_nl:last_nl].strip()
                    # Basic check if suffix is just ``` to handle multiline suffix correctly
                    if block_suffix.strip() == "```":
                        block_suffix = "\n```" # Ensure newline before suffix
                    else: # Revert if suffix seems complex/malformed
                        block_prefix = ""; block_suffix = ""; text_inside = text
                    in_code_block = True if block_prefix else False
                else: # Treat as plain if block seems empty/malformed
                    in_code_block = False
            except ValueError: # Handles cases like `````` or no newline
                in_code_block = False
        text = text_inside # Work with inner content or original text if not code block

        current_pos = 0; msg_count = 0
        while current_pos < len(text):
            limit = MAX_MESSAGE_LENGTH
            if in_code_block:
                limit -= (len(block_prefix) + len(block_suffix)) # Account for block syntax length
            if limit <= 10: limit = 10 # Ensure a minimum split length

            end_pos = min(current_pos + limit, len(text))

            # Prefer splitting at newline before the limit
            split_pos = text.rfind('\n', current_pos, end_pos)
            if split_pos != -1 and split_pos > current_pos: # Found a newline to split at
                chunk_content = text[current_pos:split_pos]
                current_pos = split_pos + 1 # Move past the newline for next chunk
            else: # No newline found, force split at limit
                chunk_content = text[current_pos:end_pos]
                current_pos = end_pos

            if not chunk_content.strip() and not (in_code_block and text == ""): # Avoid sending empty/whitespace chunks unless it's an empty code block
                 continue

            # Add block syntax if needed, handling empty content edge case
            final_chunk = f"{block_prefix}{chunk_content}{block_suffix}" if in_code_block else chunk_content
            if final_chunk: # Ensure not sending empty string
                await channel.send(final_chunk)
                msg_count += 1
                if current_pos < len(text): # Delay only if more chunks are coming
                    await asyncio.sleep(0.5)
        if msg_count > 0:
            logger.debug(f"Sent {msg_count} message chunk(s) to C:{channel.id}")
        elif len(text) > 0 : # Log if text existed but no chunks were sent (should be rare)
             logger.warning(f"Attempted to send message of length {len(text)} but no chunks were sent to C:{channel.id}")


    except discord.Forbidden:
        logger.warning(f"Permissions error sending message in C:{channel.id}/G:{channel.guild.id if channel.guild else 'DM'}")
    except discord.HTTPException as e:
        logger.error(f"Discord HTTP error sending message to C:{channel.id}: {e.status} {e.code} {e.text}")
    except Exception as e:
        logger.error(f"Error in send_split_message to C:{channel.id}: {e}", exc_info=True)


# --- Discord Event Handlers ---
async def on_ready():
    """Called when the bot successfully connects and is ready."""
    global BOT_MAN_PAGE_CONTENT, discord_client, config, APP_NAME
    if not discord_client or not discord_client.user:
        logger.error("Internal error: Discord client not ready in on_ready handler.")
        return
    logger.info(f'Logged in as {discord_client.user.name} (ID: {discord_client.user.id})')
    logger.info('Bot ready.')
    try:
        # Format the dynamic man page content
        BOT_MAN_PAGE_CONTENT = BASE_BOT_MAN_PAGE_CONTENT.format(
            bot_name=discord_client.user.name,
            gemini_model_name=config.get('GEMINI_MODEL_NAME', 'N/A'),
            timeout_seconds=config.get('CONVERSATION_TIMEOUT_SECONDS', 'N/A'),
            timeout_delta=config.get('CONVERSATION_TIMEOUT_DELTA', 'N/A'),
            env_file_path=config.get('ENV_FILE_PATH', 'N/A'),
            app_name=APP_NAME # Pass app name for journalctl example
        )
        logger.debug("Bot Man Page content formatted.")
        # Set Discord presence/status
        status_name = f"man @{discord_client.user.name}"
        await discord_client.change_presence(activity=discord.Activity(type=discord.ActivityType.listening, name=status_name))
        logger.info(f"Set status: Listening to {status_name}")
    except Exception as e:
        logger.error(f"Error during on_ready tasks (status/help format): {e}", exc_info=True)

# This decorator needs the client instance, registered in main()
# @discord_client.event
async def on_message(message):
    """Handles incoming messages."""
    global discord_client, config, conversations, gemini_model, BOTSNACK_VIDEO_URL

    if message.author == discord_client.user: return # Ignore self
    if not discord_client or not discord_client.user: return # Not ready
    if message.guild is None: return # Ignore DMs

    mentioned = False; prompt_content = ""
    if discord_client.user.mentioned_in(message):
        mentioned = True; bot_mention_pattern = f"<@!?{discord_client.user.id}>"
        # Extract content after first mention
        prompt_content = re.sub(bot_mention_pattern, '', message.content, count=1).strip()
    else:
        return # Only respond to mentions

    # Log mention receipt
    logger.debug(f"Mention detected from {message.author.name} (ID: {message.author.id}) in G:{message.guild.id}/C:{message.channel.id}")

    if mentioned and not prompt_content:
        logger.info(f"Empty mention from {message.author.name}. Ignoring.")
        return

    author_mention_str = format_user_mention(message.author, config.get('AUTHOR_DISCORD_ID'))
    prompt_lower = prompt_content.lower() # Lowercase once for checks

    # --- Handle `botsnack` Command ---
    if prompt_lower == "botsnack" or prompt_lower == "bot snack":
        logger.info(f"Botsnack command triggered by {author_mention_str} in C:{message.channel.id}")
        response_text = f"OM NOM NOM!\n{BOTSNACK_VIDEO_URL}"
        await send_split_message(message.channel, response_text)
        return # Stop processing this command

    # --- Handle `help` Alias ---
    if prompt_lower == 'help':
        if discord_client.user:
             hint_message = f"Help is available by typing `@{discord_client.user.name} man @{discord_client.user.name}`"
             logger.info(f"Sending help hint to {author_mention_str} in C:{message.channel.id}.")
             await send_split_message(message.channel, hint_message)
        return

    # --- Handle `man` Request Logic ---
    is_man_request = False; man_query = ""; gemini_prompt = prompt_content
    if prompt_lower.startswith("man "):
        is_man_request = True; man_query = prompt_content[len("man "):].strip()
        bot_mention_string_1 = f'<@{discord_client.user.id}>'; bot_mention_string_2 = f'<@!{discord_client.user.id}>'

        # Special Case: `man @BotName`
        if man_query == bot_mention_string_1 or man_query == bot_mention_string_2:
            logger.info(f"Sending Bot Man Page to {author_mention_str} in C:{message.channel.id}.")
            await send_split_message(message.channel, f"```man\n{BOT_MAN_PAGE_CONTENT.strip()}\n```")
            return

        # Regular `man <query>` Case
        elif not man_query:
            logger.info(f"Empty 'man' request from {author_mention_str}")
            usage_msg = f"Usage: `@{discord_client.user.name} man <command_name>` or `@{discord_client.user.name} man @{discord_client.user.name}`"
            await send_split_message(message.channel, usage_msg)
            return
        else:
            logger.info(f"Processing 'man' request from {author_mention_str} for: '{man_query}'")
            gemini_prompt = (f"Generate the content of the standard Linux/Unix man page for: '{man_query}'. "
                             f"Use typical man page structure (NAME, SYNOPSIS, DESCRIPTION, OPTIONS, EXAMPLES, etc.). "
                             f"If no standard man page exists or you cannot provide it, respond *only* with the exact text: 'man: no manual entry for {man_query}'")
    else:
        # --- Process Regular Prompt ---
        logger.info(f"Processing general prompt from {author_mention_str}: '{prompt_content[:100]}...'")
        # gemini_prompt is already set to prompt_content

    # --- Common Logic: Get History, Call Gemini, Handle Response ---
    current_time_utc = datetime.datetime.now(datetime.timezone.utc)
    history_key = (message.channel.id, message.author.id)
    relevant_gemini_history = get_relevant_history(message.channel.id, message.author.id, current_time_utc)

    async with message.channel.typing():
        full_response = ""; interaction_successful = True; gemini_error_msg = None
        try:
            if not gemini_model: # Safety check
                 raise Exception("Gemini model not initialized")

            logger.debug(f"Sending prompt to Gemini (history={len(relevant_gemini_history)} msgs): '{gemini_prompt[:100]}...'")
            chat = gemini_model.start_chat(history=relevant_gemini_history)
            response_stream = await chat.send_message_async(gemini_prompt, stream=True)

            buffer = ""; last_sent_time = asyncio.get_event_loop().time(); initial_chunk_sent = False
            async for chunk in response_stream:
                # Add safety checks for chunk content if API behaves unexpectedly
                if not hasattr(chunk, 'text') or chunk.text is None: continue
                chunk_text = chunk.text
                buffer += chunk_text
                full_response += chunk_text
                current_time_loop = asyncio.get_event_loop().time()
                # Stream intermediate results only for non-man general requests
                if not is_man_request and ((not initial_chunk_sent and len(buffer)>0) or len(buffer) > 500 or \
                   (current_time_loop - last_sent_time > 1.5 and len(buffer) > 0)):
                   if buffer:
                       await send_split_message(message.channel, buffer)
                       buffer = "" # Clear the buffer
                       last_sent_time = current_time_loop
                       initial_chunk_sent = True # Mark that we've started sending
            # Send remaining buffer for general requests if streaming occurred
            if buffer and not is_man_request and initial_chunk_sent:
                await send_split_message(message.channel, buffer)

            logger.debug(f"Gemini response received (length: {len(full_response)})")

        # --- Specific Error Handling for Gemini/API ---
        except genai_types.BlockedPromptException as e:
            logger.warning(f"Gemini blocked prompt from {author_mention_str}: {e}")
            gemini_error_msg = "Your prompt was blocked by the AI's safety filters."
            interaction_successful = False
        except genai_types.StopCandidateException as e:
             logger.warning(f"Gemini stopped generation unexpectedly for {author_mention_str}: {e}. Partial response: {len(full_response)}")
             gemini_error_msg = "The AI stopped generating the response unexpectedly."
             # Keep partial response? Set interaction_successful based on whether partial is useful?
             interaction_successful = True # Allow storing partial history
        except google_api_exceptions.ResourceExhausted as e:
             logger.error(f"Gemini API quota/rate limit hit: {e}")
             gemini_error_msg = "The AI service is currently overloaded or rate limited. Please try again later."
             interaction_successful = False
        except google_api_exceptions.PermissionDenied as e:
             logger.critical(f"Gemini API permission denied (API Key invalid?): {e}")
             gemini_error_msg = "AI service configuration error (Permissions). Contact admin."
             interaction_successful = False
        except google_api_exceptions.InvalidArgument as e:
             logger.error(f"Invalid argument sent to Gemini API: {e}")
             gemini_error_msg = "There was an issue sending the request to the AI (Invalid Argument)."
             interaction_successful = False
        except google_api_exceptions.GoogleAPIError as e: # Catch other google API errors
             logger.error(f"Google API Error: {type(e).__name__} - {e}", exc_info=True)
             gemini_error_msg = f"A Google API error occurred (`{type(e).__name__}`)."
             interaction_successful = False
        except Exception as e: # Catch unexpected errors during generation
            logger.error(f"Unexpected error during Gemini communication: {e}", exc_info=True)
            gemini_error_msg = f"An unexpected error occurred communicating with the AI (`{type(e).__name__}`)."
            interaction_successful = False

        # --- Post-Response Processing (Sending to Discord, History) ---
        try:
            # Send specific error message if one occurred during generation
            if gemini_error_msg:
                await send_split_message(message.channel, f"{author_mention_str}, {gemini_error_msg}")

            # Process successful response or refusal for 'man' command
            elif is_man_request:
                expected_refusal = f"man: no manual entry for {man_query}"
                if full_response.strip() == expected_refusal:
                    await send_split_message(message.channel, expected_refusal)
                    logger.info(f"Gemini indicated no man page for '{man_query}'.")
                    interaction_successful = False # Failed to find man page
                else:
                    # Send the presumed man page content, wrapped in code block
                    logger.info(f"Sending presumed man page content for '{man_query}'.")
                    await send_split_message(message.channel, f"```man\n{full_response.strip()}\n```")
                    # interaction_successful remains True

            # Process successful general response (handle cases where streaming didn't occur)
            elif not is_man_request and not initial_chunk_sent and full_response:
                 await send_split_message(message.channel, full_response)

            # Handle empty successful responses
            elif not full_response and interaction_successful:
                 logger.warning(f"Received empty successful response for prompt: {prompt_content[:50]}...")
                 await send_split_message(message.channel, f"{author_mention_str}, The AI returned an empty response.")
                 interaction_successful = False # Treat empty as not useful for history

            # --- Store Interaction in History (Only if interaction was successful) ---
            if interaction_successful:
                user_message_timestamp = message.created_at.replace(tzinfo=datetime.timezone.utc)
                response_timestamp = datetime.datetime.now(datetime.timezone.utc)
                # Store the original user prompt content, not the modified gemini_prompt for man
                user_msg_data = {'role': 'user', 'parts': [{'text': prompt_content}], 'timestamp': user_message_timestamp}
                model_msg_data = {'role': 'model', 'parts': [{'text': full_response}], 'timestamp': response_timestamp}

                if history_key not in conversations: conversations[history_key] = []
                conversations[history_key].extend([user_msg_data, model_msg_data])
                logger.debug(f"Stored interaction ({len(prompt_content)}b -> {len(full_response)}b) for {history_key}")
            else:
                logger.info(f"Interaction for {history_key} not stored due to error or refusal.")

        # Catch errors during the sending/history update phase
        except discord.Forbidden:
            logger.warning(f"Missing permissions to send response/update history in C:{message.channel.id}/G:{message.guild.id}")
        except discord.HTTPException as e:
            logger.error(f"Discord API error sending response: {e.status} {e.code} {e.text}")
        except Exception as e:
            logger.error(f"Error processing response/updating history: {e}", exc_info=True)


# --- Signal Handling and Cleanup ---
async def cleanup_shutdown():
    """Attempt graceful shutdown on signal."""
    logger.warning("Shutdown requested...")
    if discord_client and (discord_client.is_ready() or not discord_client.is_closed()):
        try:
            logger.info("Closing Discord client...")
            await discord_client.close()
            logger.info("Discord client closed.")
        except Exception as e:
            logger.error(f"Error closing Discord client: {e}", exc_info=True)
    # PID file is handled by context manager in main()

def handle_signal_sync(signum, frame):
    """Sync signal handler to schedule async cleanup."""
    signal_name = signal.Signals(signum).name
    logger.warning(f"Received signal {signal_name} ({signum}).")
    # Schedule the async cleanup function to run on the loop if possible
    try:
        if discord_client and discord_client.loop and discord_client.loop.is_running():
            asyncio.run_coroutine_threadsafe(cleanup_shutdown(), discord_client.loop)
        else:
            logger.warning("Event loop/client unavailable for async cleanup.")
            # Attempt synchronous cleanup? Risky. Rely on finally block in main.
    except Exception as e:
        logger.error(f"Error scheduling async cleanup from signal handler: {e}")

# --- Main Execution ---
def main():
    global config, discord_client, gemini_model, APP_NAME # Allow modification

    parser = argparse.ArgumentParser(description=f"{APP_NAME} - Discord bot using Google Gemini.", prog=APP_NAME)
    parser.add_argument('--config', default=DEFAULT_ENV_FILE, help=f"Path to .env config file (default: {DEFAULT_ENV_FILE})")
    parser.add_argument('--pidfile', default=DEFAULT_PID_PATH, help=f"Path to PID file (default: {DEFAULT_PID_PATH})")
    parser.add_argument('--log-level', default='INFO', choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], help="Logging level (default: INFO)")
    parser.add_argument('--foreground', '-f', action='store_true', help="Run in foreground with console logging (ignores PID file).")
    args = parser.parse_args()

    # Setup logging first
    setup_logging(log_level_str=args.log_level, log_to_console=args.foreground)
    logger.info(f"--- Starting {APP_NAME} bot ---")

    # Load configuration
    try:
        config = load_configuration(args.config)
    except SystemExit:
         raise # Propagate exit from config loading
    except Exception as e:
         logger.critical(f"Unhandled exception during configuration load: {e}", exc_info=True)
         sys.exit(1)

    # --- PID File Handling (Skip if foreground) ---
    pid_manager_context = contextlib.nullcontext() # Default for foreground
    if not args.foreground:
        pid_dir = os.path.dirname(args.pidfile)
        logger.debug(f"Checking PID file: {args.pidfile}")
        # Check for stale lock
        if os.path.exists(args.pidfile):
            try:
                with open(args.pidfile, 'r') as pf: old_pid = int(pf.read().strip())
                if psutil.pid_exists(old_pid):
                     # Check if the process command matches (more robust check)
                     # This can be tricky and platform-dependent, basic check for now
                     logger.critical(f"Another instance (PID {old_pid}) appears to be running. Lock file: {args.pidfile}. Exiting.")
                     sys.exit(1)
                else:
                    logger.warning(f"Stale PID file found ({args.pidfile} for PID {old_pid}). Removing.")
                    os.remove(args.pidfile)
            except (FileNotFoundError, IOError, ValueError, psutil.Error, OSError) as e:
                logger.warning(f"Error checking/removing stale PID file {args.pidfile}: {e}. Attempting to continue cautiously.")
                try:
                    if os.path.exists(args.pidfile): os.remove(args.pidfile)
                except OSError as rm_err:
                     logger.error(f"Failed removing stale PID file {args.pidfile}: {rm_err}")
                     # Decide whether to exit or proceed cautiously - let's proceed for now
                     pass

        # Prepare PID context manager
        try:
            os.makedirs(pid_dir, mode=0o750, exist_ok=True) # Ensure dir exists with group write
            # Note: Ownership should be set by RPM/install script
            pid_manager_context = pidfile.PIDFile(args.pidfile, appname=APP_NAME) # Add appname for potential locking checks
        except (pidfile.PIDFileAlreadyLockedError, pidfile.AlreadyLockedError): # Catch specific lock errors
             logger.critical(f"PID file {args.pidfile} is locked. Another instance running?. Exiting.")
             sys.exit(1)
        except (pidfile.PIDFileCreateError, OSError) as e:
             logger.critical(f"Could not create PID directory/file at {args.pidfile}. Check path/permissions: {e}", exc_info=True)
             sys.exit(1)
        except Exception as e: # Catch other unexpected pidfile init errors
             logger.critical(f"Unexpected error initializing PID file handling: {e}", exc_info=True)
             sys.exit(1)
    else:
        logger.info("Running in foreground, PID file handling skipped.")


    # --- Initialize Services and Run Bot ---
    main_exit_code = 0
    try:
        with pid_manager_context: # Enters context (acquires lock) if not foreground
            if not args.foreground:
                logger.info(f"Acquired PID lock file: {args.pidfile}")

            # Initialize Gemini
            try:
                logger.info(f"Initializing Gemini: {config['GEMINI_MODEL_NAME']}")
                genai.configure(api_key=config['GEMINI_API_KEY'])
                gemini_model = genai.GenerativeModel(config['GEMINI_MODEL_NAME'])
                logger.info("Gemini initialized.")
            except Exception as e:
                logger.critical(f"Gemini Init Error: {e}", exc_info=True)
                raise # Raise to exit main try block

            # Initialize Discord Client
            try:
                logger.info("Initializing Discord client...")
                intents = discord.Intents.default()
                intents.messages = True; intents.message_content = True; intents.guilds = True
                # Instantiate client FIRST
                discord_client = discord.Client(intents=intents, heartbeat_timeout=90)
                # THEN register events using the instance
                discord_client.event(on_ready)
                discord_client.event(on_message)
                logger.info("Discord client initialized.")
            except Exception as e:
                 logger.critical(f"Discord Init Error: {e}", exc_info=True)
                 raise # Raise to exit main try block

            # Setup Signal Handling (Best effort)
            try:
                 loop = asyncio.get_event_loop()
                 # Use loop.add_signal_handler on Unix systems
                 loop.add_signal_handler(signal.SIGTERM, lambda: asyncio.create_task(cleanup_shutdown()))
                 loop.add_signal_handler(signal.SIGINT, lambda: asyncio.create_task(cleanup_shutdown()))
                 logger.info("Signal handlers registered.")
            except NotImplementedError:
                 logger.warning("Signal handlers not supported on this platform (e.g., Windows).")
                 # Fallback or alternative cleanup might be needed for Windows if run as service
            except ValueError:
                 logger.warning("Cannot set signal handlers in non-main thread (might be embedded).")
            except Exception as e:
                 logger.error(f"Could not set signal handlers: {e}")

            # Start the bot's main blocking run loop
            logger.info(f"Starting {APP_NAME} Discord bot run loop...")
            discord_client.run(
                config['DISCORD_BOT_TOKEN'],
                log_handler=None, # Use our configured logger
                log_level=logging.INFO # Set discord.py's internal logger level
            )
            # This part is reached only upon clean shutdown (e.g., client.close() called)
            logger.info("Discord client run loop finished normally.")

    # --- Exception Handling for Main Execution ---
    except discord.LoginFailure:
        logger.critical("Discord login failed: Invalid Token.")
        main_exit_code = 1
    except discord.PrivilegedIntentsRequired:
         logger.critical("Discord login failed: Privileged Intents missing.")
         main_exit_code = 1
    except pidfile.AlreadyLockedError: # Should be caught before 'with' if not foreground
         logger.critical(f"PID file {args.pidfile} locked unexpectedly.")
         main_exit_code = 1
    except KeyboardInterrupt: # Handle Ctrl+C gracefully if signal handler fails/unavailable
         logger.warning("KeyboardInterrupt received.")
         # Cleanup might happen via signal handler, PID context ensures release
    except SystemExit as e: # Catch sys.exit calls
        logger.warning(f"SystemExit called with code {e.code}")
        main_exit_code = e.code if isinstance(e.code, int) else 1
    except Exception as e:
        logger.critical(f"Unhandled critical exception in main execution block: {e}", exc_info=True)
        main_exit_code = 1
    finally:
        # Context manager handles PID release automatically on exit/exception
        logger.info(f"{APP_NAME} shutdown sequence finished. Exiting code {main_exit_code}.")
        sys.exit(main_exit_code)


if __name__ == "__main__":
    main()
