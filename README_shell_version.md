# Window Position Manager for macOS

A shell script and AppleScript automation tool that saves and restores window positions across **ALL screens** (including your MacBook's built-in display). Perfect for switching between work (1 external monitor + laptop) and home (2 external monitors + laptop) environments.

## Features

- **Multi-screen support** - Captures windows across ALL displays including the laptop screen
- **Display configuration tracking** - Records screen names, positions, and resolutions
- **Save window positions** - Captures all visible application windows with their positions and sizes
- **Restore window positions** - Restores windows to saved positions on all screens
- **Auto-open applications** - Optionally opens closed applications during restore
- **Multiple profiles** - Save different layouts for work, home, or custom setups
- **Profile management** - View detailed profile info, list, and delete saved profiles
- **Display mismatch warning** - Warns if restoring to a different monitor setup
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

# Show current display configuration
./window-manager.sh --displays

# Show help
./window-manager.sh --help
```

## Typical Workflow

### At Work (1 External Monitor + Laptop Screen)

1. Arrange your windows across both screens as desired
2. Run: `./window-manager.sh --save work` or use interactive mode
3. When you return to work, run: `./window-manager.sh --restore work`

### At Home (2 External Monitors + Laptop Screen)

1. Arrange your windows across all three screens
2. Run: `./window-manager.sh --save home`
3. When you return home, run: `./window-manager.sh --restore home`

### Check Your Display Setup

```bash
./window-manager.sh --displays
```

Output example:
```
Current Display Configuration:
==============================
Total screens: 3

  Built-in Retina Display
    Position: (0, 0)
    Size: 1728x1117

  DELL U2722D
    Position: (-1728, -200)
    Size: 2560x1440

  LG HDR 4K
    Position: (1728, -400)
    Size: 3840x2160
```

## Profile Storage

Profiles are stored as JSON files in:
```
~/.config/window-manager/profiles/
```

Each profile contains:
- **Display configuration**: Number of screens, names, positions, and sizes
- **Save timestamp**: When the profile was created
- **Window data** for each window:
  - Application name and bundle ID
  - Window title and index
  - Position (x, y) - absolute coordinates spanning all screens
  - Size (width, height)
  - Center coordinates (for screen detection)

Example profile structure:
```json
{
  "saved_at": "Monday, December 8, 2025 at 10:30:00 AM",
  "display_count": 2,
  "displays": [
    {"name": "Built-in Retina Display", "x": 0, "y": 0, "width": 1728, "height": 1117},
    {"name": "DELL U2722D", "x": -1728, "y": -200, "width": 2560, "height": 1440}
  ],
  "windows": [
    {"app": "Code", "bundle": "com.microsoft.VSCode", "window": "project", "x": -1500, "y": 100, ...}
  ]
}
```

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

- **Multiple Spaces/Desktops**: Only windows on the current Space can be saved. macOS does not provide an API to access windows on other Spaces. If you use multiple Spaces, switch to each Space and save separate profiles (e.g., `work-space1`, `work-space2`).
- Certain system apps (Finder windows, Control Center) are excluded
- Apps with non-standard window handling may not restore perfectly
- Window positions are absolute; changing monitor arrangement may affect results
- Some apps create windows lazily and may need time to position correctly

## License

Free to use and modify for personal use.
