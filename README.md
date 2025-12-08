# Window Position Manager for macOS

A shell script and AppleScript automation tool that saves and restores window positions across different monitor setups. Perfect for switching between work (1 external monitor) and home (2 external monitors) environments.

## Features

- **Save window positions** - Captures all visible application windows with their positions and sizes
- **Restore window positions** - Restores windows to saved positions
- **Auto-open applications** - Optionally opens closed applications during restore
- **Multiple profiles** - Save different layouts for work, home, or custom setups
- **Profile management** - List, delete, and manage saved profiles
- **Interactive dialogs** - User-friendly macOS dialogs for all interactions
- **Command-line mode** - Quick save/restore via terminal for automation

## Installation

1. Download the script:
   ```bash
   mkdir -p ~/bin
   cp window-manager.sh ~/bin/
   chmod +x ~/bin/window-manager.sh
   ```

2. (Optional) Add to PATH in your `~/.zshrc` or `~/.bashrc`:
   ```bash
   export PATH="$HOME/bin:$PATH"
   ```

3. Grant required permissions:
   - Go to **System Settings → Privacy & Security → Accessibility**
   - Add **Terminal** (or your terminal app like iTerm2)
   - If using from Automator/Shortcuts, add **System Events**

## Usage

### Interactive Mode (Recommended)

Simply run the script without arguments:

```bash
./window-manager.sh
```

This opens a dialog with three options:
- **Save Windows** - Save current window positions to a profile
- **Restore Windows** - Restore windows from a saved profile
- **Manage Profiles** - List or delete existing profiles

### Command-Line Mode

For quick operations or scripting:

```bash
# Save to default profile
./window-manager.sh --save

# Save to specific profile
./window-manager.sh --save work
./window-manager.sh --save home

# Restore from default profile
./window-manager.sh --restore

# Restore from specific profile
./window-manager.sh --restore work
./window-manager.sh --restore home

# List all profiles
./window-manager.sh --list

# Show help
./window-manager.sh --help
```

## Typical Workflow

### At Work (1 External Monitor)

1. Arrange your windows as desired
2. Run: `./window-manager.sh --save work` or use interactive mode
3. When you return to work, run: `./window-manager.sh --restore work`

### At Home (2 External Monitors)

1. Arrange your windows across monitors
2. Run: `./window-manager.sh --save home`
3. When you return home, run: `./window-manager.sh --restore home`

## Profile Storage

Profiles are stored as JSON files in:
```
~/.config/window-manager/profiles/
```

Each profile contains:
- Application name and bundle ID
- Window title
- Position (x, y)
- Size (width, height)

## Creating Quick Access

### Option 1: Keyboard Shortcut with Automator

1. Open **Automator** → New → **Quick Action**
2. Set "Workflow receives" to **no input**
3. Add "Run Shell Script" action
4. Enter: `/path/to/window-manager.sh`
5. Save (e.g., "Window Manager")
6. Go to **System Settings → Keyboard → Keyboard Shortcuts → Services**
7. Assign a shortcut (e.g., ⌘⌥W)

### Option 2: Menu Bar with Automator

1. Open **Automator** → New → **Application**
2. Add "Run Shell Script" action
3. Enter: `/path/to/window-manager.sh`
4. Save as an application
5. Add to **Login Items** for easy access

### Option 3: Alfred/Raycast Integration

Create a workflow/script command that calls the script.

## Troubleshooting

### "Not authorized to send Apple events"

Grant Accessibility permissions:
1. **System Settings → Privacy & Security → Accessibility**
2. Add your terminal application
3. You may need to restart the terminal

### Windows not restoring correctly

- Some apps may not support programmatic window positioning
- Certain apps have minimum window sizes that may override saved sizes
- Multi-monitor setups may behave differently if monitor arrangement changes

### Application won't open on restore

- Ensure the application is installed
- Some apps may require manual launch first time after installation

## Limitations

- Certain system apps (Finder windows, Control Center) are excluded
- Apps with non-standard window handling may not restore perfectly
- Window positions are absolute; changing monitor arrangement may affect results
- Some apps create windows lazily and may need time to position correctly

## License

Free to use and modify for personal use.
