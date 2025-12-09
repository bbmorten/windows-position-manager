# How to Capture All Desktops Including External Monitor

## Current Issue
Your profile "Eeeee" only captured 3 spaces, but you have 8 desktops total:
- Desktops 1-6: On MacBook display
- **Desktop 7**: Docker Desktop (on external monitor T22D390)
- **Desktop 8**: Spotify (on external monitor T22D390)

## Solution

1. **Open the WPM app**

2. **Check "Save All Spaces"** checkbox at the top

3. **Set "Scan:" to 8** (or higher to be safe)

4. **Enter a profile name** (e.g., "Full Setup")

5. **Click "Save"**

6. **DO NOT TOUCH** your mouse/keyboard while it's scanning - let it automatically swipe through all 8 desktops

7. **Wait for completion** - you'll see a notification when done

## What Will Happen

The app will:
- Automatically switch to Desktop 1, capture windows
- Switch to Desktop 2, capture windows
- ... continue through all 8 desktops
- Switch to Desktop 7 (external monitor), capture Docker Desktop
- Switch to Desktop 8 (external monitor), capture Spotify
- Save everything to one profile

## Result

When you expand the profile and click the "T22D390" tab, you should see:
- **Space 7** sub-tab with Docker Desktop
- **Space 8** sub-tab with Spotify

---

**Note**: The app icons now use simple colored placeholders with the first letter of each app name, so they'll appear immediately without any loading delay.
