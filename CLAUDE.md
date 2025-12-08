# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A macOS shell script tool that saves and restores application window positions across multiple displays. Uses AppleScript and the AppKit framework for window manipulation. Designed for users who switch between different monitor configurations (e.g., work vs home setups).

## Architecture

Single-file bash script (`window-manager.sh`) that:
- Embeds AppleScript code for macOS GUI interactions and window manipulation
- Uses `osascript` to execute AppleScript blocks for dialogs and window operations
- Stores profiles as JSON files in `~/.config/window-manager/profiles/`
- Leverages AppKit's `NSScreen` API (via AppleScript) for display detection

Key functions:
- `get_display_info()` - Gets screen configuration using AppKit framework
- `save_windows()` - Captures all visible window positions via System Events
- `restore_windows()` - Repositions windows, optionally opening closed apps
- `show_main_menu()` / `get_profile_name()` - Interactive macOS dialogs

## Running the Script

```bash
# Interactive mode (opens macOS dialogs)
./window-manager.sh

# Command-line mode
./window-manager.sh --save [profile]     # Save window positions
./window-manager.sh --restore [profile]  # Restore window positions
./window-manager.sh --list               # List saved profiles
./window-manager.sh --displays           # Show current display configuration
```

## Requirements

- macOS with Accessibility permissions granted to Terminal/iTerm2
- System Settings → Privacy & Security → Accessibility
