# Window Position Manager (WPM)

<div align="center">
  <img src="assets/robot-logo.png" alt="WPM Logo" width="150" height="150">
  <h3>Save and Restore Your Perfect Layout</h3>
</div>

**Window Position Manager** is a macOS utility built with Electron that solves the frustration of rearranging windows every time you disconnect your monitor or reboot. 

It remembers exactly where your windows are—across multiple monitors and Mission Control spaces—and puts them back for you with a single click.

## ✨ Features

- **Multi-Monitor Support**: Correctly handles external displays and remembers window coordinates relative to specific screens.
- **Spaces / Mission Control Support**: Can automatically swipe through your desktop spaces to save and restore windows on every virtual desktop.
- **Profiles**: Create as many presets as you need (e.g., "Work", "Home", "Streaming").
- **App Launching**: If an app is closed when you restore a layout, WPM can automatically launch it for you.
- **Smart Logic**: Prioritizes window bundle IDs but falls back to app names if necessary.

## 🚀 How It Works

### Saving a Profile
1. Arrange your windows exactly how you like them.
2. Open Window Position Manager.
3. Enter a name for your profile (e.g., "Deep Work").
4. Click **Save Profile**.

> **Note**: For multi-space saving, check the "Save all spaces" box. The app will take control of your screen and swipe through each space to capture window data. **Please do not touch the mouse or keyboard during this process.**

### Restoring a Profile
1. Open the dashboard.
2. Find your desired profile card.
3. Click **Restore Layout**.
4. Watch as your windows snap back into place!

## 🛠️ Installation & Development

### Prerequisites
- macOS (tested on macOS Sequoia/Sonoma)
- Node.js & npm

### Running Locally
```bash
# Clone the repository
git clone https://github.com/bbmorten/windows-position-manager.git

# Install dependencies
npm install

# Start the application
npm start
```

### Building for Production
To create a standalone `.dmg` installer:

```bash
npm run dist
```
The output file will be in the `dist/` directory.

## 🔒 Permissions
On first launch, macOS will ask for **Accessibility Permissions**. This is required for the app to query window positions and move them.
1. Go to **System Settings > Privacy & Security > Accessibility**.
2. Toggle the switch for **Window Position Manager** (or your terminal if running locally).

## 📝 License
ISC
