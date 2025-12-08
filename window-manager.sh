#!/bin/bash

# Window Position Manager for macOS
# Saves and restores application window positions across ALL screens
# Supports multiple profiles (work, home, custom)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/window-manager"
PROFILES_DIR="$CONFIG_DIR/profiles"

# Ensure directories exist
mkdir -p "$PROFILES_DIR"

# Display main menu dialog
show_main_menu() {
    local choice
    choice=$(osascript <<EOF
        set theChoice to button returned of (display dialog "Window Position Manager" & return & return & "Choose an action:" buttons {"Save Windows", "Restore Windows", "Manage Profiles"} default button "Save Windows" with title "Window Manager" with icon note)
        return theChoice
EOF
    )
    echo "$choice"
}

# Get profile name via dialog
get_profile_name() {
    local action="$1"
    local profiles
    local profile_list=""
    
    # Get existing profiles
    if [ -d "$PROFILES_DIR" ]; then
        profiles=($(ls "$PROFILES_DIR"/*.json 2>/dev/null | xargs -I {} basename {} .json))
    fi
    
    if [ "$action" = "save" ]; then
        # For save, allow new profile or existing
        local default_profiles=("work" "home" "custom")
        local all_profiles=($(echo "${default_profiles[@]}" "${profiles[@]}" | tr ' ' '\n' | sort -u))
        
        for p in "${all_profiles[@]}"; do
            if [ -n "$profile_list" ]; then
                profile_list="$profile_list, \"$p\""
            else
                profile_list="\"$p\""
            fi
        done
        
        local result
        result=$(osascript <<EOF
            set profileList to {$profile_list}
            set theChoice to choose from list profileList with prompt "Select a profile to save to:" & return & "(Or click 'New Profile' to create one)" with title "Save Profile" OK button name "Select" cancel button name "New Profile"
            if theChoice is false then
                return "NEW_PROFILE"
            else
                return item 1 of theChoice
            end if
EOF
        )
        
        if [ "$result" = "NEW_PROFILE" ]; then
            result=$(osascript <<EOF
                set newName to text returned of (display dialog "Enter new profile name:" default answer "" with title "New Profile" buttons {"Cancel", "Create"} default button "Create")
                return newName
EOF
            )
        fi
        echo "$result"
        
    elif [ "$action" = "restore" ]; then
        # For restore, only show existing profiles
        if [ ${#profiles[@]} -eq 0 ]; then
            osascript -e 'display alert "No Profiles Found" message "No saved profiles found. Please save a profile first." as warning'
            return 1
        fi
        
        for p in "${profiles[@]}"; do
            if [ -n "$profile_list" ]; then
                profile_list="$profile_list, \"$p\""
            else
                profile_list="\"$p\""
            fi
        done
        
        local result
        result=$(osascript <<EOF
            set profileList to {$profile_list}
            set theChoice to choose from list profileList with prompt "Select a profile to restore:" with title "Restore Profile" OK button name "Restore" cancel button name "Cancel"
            if theChoice is false then
                return ""
            else
                return item 1 of theChoice
            end if
EOF
        )
        echo "$result"
    fi
}

# Get current display configuration using AppKit
get_display_info() {
    osascript <<'EOF'
        use framework "AppKit"
        use scripting additions
        
        set screenInfo to ""
        set screenList to current application's NSScreen's screens()
        set screenCount to count of screenList
        
        repeat with i from 1 to screenCount
            set scr to item i of screenList
            set frame to scr's frame()
            set origin to item 1 of frame
            set screenSize to item 2 of frame
            
            set scrX to item 1 of origin as integer
            set scrY to item 2 of origin as integer
            set scrW to item 1 of screenSize as integer
            set scrH to item 2 of screenSize as integer
            
            -- Get screen name/description
            set localName to scr's localizedName() as text
            
            if i > 1 then
                set screenInfo to screenInfo & "|"
            end if
            set screenInfo to screenInfo & localName & ":" & scrX & "," & scrY & "," & scrW & "," & scrH
        end repeat
        
        return screenInfo
EOF
}

# Save window positions across ALL screens
save_windows() {
    local profile="$1"
    local profile_file="$PROFILES_DIR/${profile}.json"

    # Warn about Spaces/multiple desktops limitation
    osascript <<EOF
        display dialog "Important: Only windows on the CURRENT desktop/Space will be saved." & return & return & "Windows on other Spaces cannot be captured due to macOS limitations." & return & return & "Switch to each Space and save separate profiles if needed." buttons {"Cancel", "Continue"} default button "Continue" with title "Space Limitation" with icon note
EOF
    if [ $? -ne 0 ]; then
        return 0
    fi

    # Get display info first
    local display_info
    display_info=$(get_display_info)

    osascript <<'EOF' - "$profile_file" "$display_info"
        on run argv
            set profileFile to item 1 of argv
            set displayInfo to item 2 of argv
            
            -- Build display JSON array
            set displayJson to "["
            set AppleScript's text item delimiters to "|"
            set displayList to text items of displayInfo
            set AppleScript's text item delimiters to ""
            
            set isFirstDisplay to true
            repeat with disp in displayList
                if not isFirstDisplay then
                    set displayJson to displayJson & ", "
                end if
                set isFirstDisplay to false
                
                set AppleScript's text item delimiters to ":"
                set dispParts to text items of disp
                set dispName to item 1 of dispParts
                set dispCoords to item 2 of dispParts
                set AppleScript's text item delimiters to ","
                set coords to text items of dispCoords
                set AppleScript's text item delimiters to ""
                
                set displayJson to displayJson & "{\"name\": \"" & dispName & "\", \"x\": " & (item 1 of coords) & ", \"y\": " & (item 2 of coords) & ", \"width\": " & (item 3 of coords) & ", \"height\": " & (item 4 of coords) & "}"
            end repeat
            set displayJson to displayJson & "]"
            
            -- Get current date/time
            set currentDate to (current date) as string
            
            -- Start building JSON
            set windowData to "{" & return
            set windowData to windowData & "  \"saved_at\": \"" & currentDate & "\"," & return
            set windowData to windowData & "  \"display_count\": " & (count of displayList) & "," & return
            set windowData to windowData & "  \"displays\": " & displayJson & "," & return
            set windowData to windowData & "  \"windows\": [" & return
            
            set isFirst to true
            
            tell application "System Events"
                set allProcesses to every process whose visible is true and background only is false
                
                repeat with proc in allProcesses
                    try
                        set appName to name of proc
                        set appBundle to bundle identifier of proc
                        
                        -- Skip certain system apps
                        if appName is not in {"Finder", "Window Manager", "Control Center", "Notification Center"} then
                            tell proc
                                set allWindows to every window
                                set winIndex to 0
                                repeat with win in allWindows
                                    try
                                        set winName to name of win
                                        set winPos to position of win
                                        set winSize to size of win
                                        
                                        if winPos is not missing value and winSize is not missing value then
                                            set winX to item 1 of winPos
                                            set winY to item 2 of winPos
                                            set winW to item 1 of winSize
                                            set winH to item 2 of winSize
                                            
                                            -- Calculate window center for screen detection
                                            set winCenterX to winX + (winW / 2)
                                            set winCenterY to winY + (winH / 2)
                                            
                                            if not isFirst then
                                                set windowData to windowData & "," & return
                                            end if
                                            set isFirst to false
                                            
                                            -- Escape quotes in window name
                                            set AppleScript's text item delimiters to "\""
                                            set winNameParts to text items of winName
                                            set AppleScript's text item delimiters to "\\\""
                                            set escapedWinName to winNameParts as text
                                            set AppleScript's text item delimiters to ""
                                            
                                            set windowData to windowData & "    {" & return
                                            set windowData to windowData & "      \"app\": \"" & appName & "\"," & return
                                            set windowData to windowData & "      \"bundle\": \"" & appBundle & "\"," & return
                                            set windowData to windowData & "      \"window\": \"" & escapedWinName & "\"," & return
                                            set windowData to windowData & "      \"window_index\": " & winIndex & "," & return
                                            set windowData to windowData & "      \"x\": " & winX & "," & return
                                            set windowData to windowData & "      \"y\": " & winY & "," & return
                                            set windowData to windowData & "      \"width\": " & winW & "," & return
                                            set windowData to windowData & "      \"height\": " & winH & "," & return
                                            set windowData to windowData & "      \"center_x\": " & (winCenterX as integer) & "," & return
                                            set windowData to windowData & "      \"center_y\": " & (winCenterY as integer) & return
                                            set windowData to windowData & "    }"
                                            
                                            set winIndex to winIndex + 1
                                        end if
                                    end try
                                end repeat
                            end tell
                        end if
                    end try
                end repeat
            end tell
            
            set windowData to windowData & return & "  ]" & return & "}"
            
            -- Write to file
            set fileRef to open for access POSIX file profileFile with write permission
            set eof fileRef to 0
            write windowData to fileRef as «class utf8»
            close access fileRef
            
            return "saved"
        end run
EOF
    
    if [ $? -eq 0 ]; then
        local count=$(grep -c '"app"' "$profile_file" 2>/dev/null || echo "0")
        local displays=$(grep -o '"display_count": [0-9]*' "$profile_file" | grep -o '[0-9]*')
        osascript -e "display notification \"Saved $count windows across $displays screen(s) to profile: $profile\" with title \"Window Manager\" sound name \"Glass\""
    else
        osascript -e 'display alert "Save Failed" message "Failed to save window positions." as critical'
    fi
}

# Restore window positions
restore_windows() {
    local profile="$1"
    local profile_file="$PROFILES_DIR/${profile}.json"
    
    if [ ! -f "$profile_file" ]; then
        osascript -e "display alert \"Profile Not Found\" message \"Profile '$profile' does not exist.\" as critical"
        return 1
    fi
    
    # Get current display count and saved display count
    local current_displays
    current_displays=$(get_display_info | tr '|' '\n' | wc -l | tr -d ' ')
    local saved_displays
    saved_displays=$(grep -o '"display_count": [0-9]*' "$profile_file" | grep -o '[0-9]*')
    
    # Warn if display count differs
    if [ "$current_displays" != "$saved_displays" ]; then
        local proceed
        proceed=$(osascript <<EOF
            set theChoice to button returned of (display dialog "Display Configuration Changed" & return & return & "Profile was saved with $saved_displays screen(s), but you currently have $current_displays screen(s)." & return & return & "Window positions may not restore correctly." buttons {"Cancel", "Continue Anyway"} default button "Continue Anyway" with title "Warning" with icon caution)
            return theChoice
EOF
        )
        if [ "$proceed" != "Continue Anyway" ]; then
            return 0
        fi
    fi
    
    # Ask about opening closed apps
    local open_apps
    open_apps=$(osascript <<EOF
        set theChoice to button returned of (display dialog "Do you want to open applications that are currently closed?" buttons {"No", "Yes"} default button "Yes" with title "Restore Options" with icon note)
        return theChoice
EOF
    )
    
    local open_flag="false"
    [ "$open_apps" = "Yes" ] && open_flag="true"
    
    osascript <<'EOF' - "$profile_file" "$open_flag"
        on run argv
            set profileFile to item 1 of argv
            set shouldOpenApps to (item 2 of argv) is "true"
            
            -- Read JSON file
            set fileContent to read POSIX file profileFile as «class utf8»
            
            -- Parse windows from JSON
            set windowList to {}
            
            -- Split by window entries
            set AppleScript's text item delimiters to "\"app\": \""
            set entries to text items of fileContent
            
            repeat with i from 2 to count of entries
                set entry to item i of entries
                
                -- Extract app name
                set AppleScript's text item delimiters to "\""
                set appName to text item 1 of entry
                
                -- Extract bundle id
                set AppleScript's text item delimiters to "\"bundle\": \""
                set parts to text items of entry
                set AppleScript's text item delimiters to "\""
                set bundleId to text item 1 of (item 2 of parts)
                
                -- Extract window_index
                set AppleScript's text item delimiters to "\"window_index\": "
                set parts to text items of entry
                set AppleScript's text item delimiters to ","
                set winIdx to (text item 1 of (item 2 of parts)) as integer
                
                -- Extract x
                set AppleScript's text item delimiters to "\"x\": "
                set parts to text items of entry
                set AppleScript's text item delimiters to ","
                set xPos to (text item 1 of (item 2 of parts)) as integer
                
                -- Extract y
                set AppleScript's text item delimiters to "\"y\": "
                set parts to text items of entry
                set AppleScript's text item delimiters to ","
                set yPos to (text item 1 of (item 2 of parts)) as integer
                
                -- Extract width
                set AppleScript's text item delimiters to "\"width\": "
                set parts to text items of entry
                set AppleScript's text item delimiters to ","
                set winWidth to (text item 1 of (item 2 of parts)) as integer
                
                -- Extract height
                set AppleScript's text item delimiters to "\"height\": "
                set parts to text items of entry
                set AppleScript's text item delimiters to ","
                set winHeight to (text item 1 of (item 2 of parts)) as integer
                
                set end of windowList to {appName:appName, bundleId:bundleId, winIndex:winIdx, x:xPos, y:yPos, width:winWidth, height:winHeight}
            end repeat
            
            set AppleScript's text item delimiters to ""
            set restoredCount to 0
            set openedApps to {}
            set processedApps to {}
            
            set failedApps to {}

            -- Process each window
            repeat with winInfo in windowList
                set appName to appName of winInfo
                set bundleId to bundleId of winInfo
                set winIdx to winIndex of winInfo
                set xPos to x of winInfo
                set yPos to y of winInfo
                set winWidth to width of winInfo
                set winHeight to height of winInfo

                tell application "System Events"
                    set appRunning to (count of (every process whose bundle identifier is bundleId)) > 0
                end tell

                -- Open app if not running and user requested
                if not appRunning and shouldOpenApps then
                    set launchSuccess to false

                    -- Method 1: Use shell open command with bundle id (most reliable)
                    try
                        do shell script "open -b " & quoted form of bundleId
                        set launchSuccess to true
                    end try

                    -- Method 2: Use shell open command with app name
                    if not launchSuccess then
                        try
                            do shell script "open -a " & quoted form of appName
                            set launchSuccess to true
                        end try
                    end if

                    -- Method 3: Try AppleScript activate as last resort
                    if not launchSuccess then
                        try
                            tell application appName to activate
                            set launchSuccess to true
                        end try
                    end if

                    if launchSuccess then
                        -- Wait for app to launch with dynamic check (up to 10 seconds)
                        set maxWait to 10
                        set waitCount to 0
                        repeat while waitCount < maxWait
                            delay 1
                            set waitCount to waitCount + 1
                            tell application "System Events"
                                set appRunning to (count of (every process whose bundle identifier is bundleId)) > 0
                                if appRunning then
                                    -- Check if app has windows yet
                                    try
                                        set winCount to count of windows of (first process whose bundle identifier is bundleId)
                                        if winCount > 0 then exit repeat
                                    end try
                                end if
                            end tell
                        end repeat

                        if appRunning and appName is not in openedApps then
                            set end of openedApps to appName
                        end if
                    else
                        -- Track failed launches
                        if appName is not in failedApps then
                            set end of failedApps to appName
                        end if
                    end if
                end if
                
                -- Position window if app is running
                if appRunning then
                    try
                        tell application "System Events"
                            tell process appName
                                if appName is not in processedApps then
                                    set frontmost to true
                                    delay 0.3
                                    set end of processedApps to appName
                                end if
                                
                                set windowCount to count of windows
                                if windowCount > winIdx then
                                    set targetWin to window (winIdx + 1)
                                    set position of targetWin to {xPos, yPos}
                                    set size of targetWin to {winWidth, winHeight}
                                    set restoredCount to restoredCount + 1
                                else if windowCount > 0 then
                                    -- Fall back to first window if index doesn't exist
                                    set position of window 1 to {xPos, yPos}
                                    set size of window 1 to {winWidth, winHeight}
                                    set restoredCount to restoredCount + 1
                                end if
                            end tell
                        end tell
                    end try
                end if
            end repeat
            
            -- Show completion message
            set openedMsg to ""
            if (count of openedApps) > 0 then
                set AppleScript's text item delimiters to ", "
                set openedMsg to return & "Opened: " & (openedApps as text)
                set AppleScript's text item delimiters to ""
            end if

            set failedMsg to ""
            if (count of failedApps) > 0 then
                set AppleScript's text item delimiters to ", "
                set failedMsg to return & "Failed to open: " & (failedApps as text)
                set AppleScript's text item delimiters to ""
            end if

            display notification "Restored " & restoredCount & " windows" & openedMsg with title "Window Manager" sound name "Glass"

            -- Show alert if some apps failed to open
            if (count of failedApps) > 0 then
                set AppleScript's text item delimiters to ", "
                display dialog "Some applications could not be opened:" & return & return & (failedApps as text) & return & return & "These apps may be uninstalled or require manual launch." buttons {"OK"} default button "OK" with title "Warning" with icon caution
                set AppleScript's text item delimiters to ""
            end if

            return restoredCount
        end run
EOF
}

# Manage profiles menu
manage_profiles() {
    local action
    action=$(osascript <<EOF
        set theChoice to button returned of (display dialog "Profile Management" & return & return & "Choose an action:" buttons {"Delete Profile", "View Profile Info", "Cancel"} default button "View Profile Info" with title "Manage Profiles" with icon note)
        return theChoice
EOF
    )
    
    case "$action" in
        "View Profile Info")
            view_profile_info
            ;;
        "Delete Profile")
            delete_profile
            ;;
        "Cancel")
            return 0
            ;;
    esac
}

# View detailed profile info
view_profile_info() {
    local profiles
    local profile_list=""
    
    if [ -d "$PROFILES_DIR" ]; then
        profiles=($(ls "$PROFILES_DIR"/*.json 2>/dev/null | xargs -I {} basename {} .json))
    fi
    
    if [ ${#profiles[@]} -eq 0 ]; then
        osascript -e 'display alert "No Profiles" message "No profiles found." as warning'
        return 1
    fi
    
    for p in "${profiles[@]}"; do
        if [ -n "$profile_list" ]; then
            profile_list="$profile_list, \"$p\""
        else
            profile_list="\"$p\""
        fi
    done
    
    local selected
    selected=$(osascript <<EOF
        set profileList to {$profile_list}
        set theChoice to choose from list profileList with prompt "Select profile to view:" with title "Profile Info" OK button name "View" cancel button name "Cancel"
        if theChoice is false then
            return ""
        else
            return item 1 of theChoice
        end if
EOF
    )
    
    if [ -n "$selected" ]; then
        local profile_file="$PROFILES_DIR/${selected}.json"
        local window_count=$(grep -c '"app"' "$profile_file" 2>/dev/null || echo "0")
        local display_count=$(grep -o '"display_count": [0-9]*' "$profile_file" | grep -o '[0-9]*')
        local saved_at=$(grep -o '"saved_at": "[^"]*"' "$profile_file" | cut -d'"' -f4)
        
        # Get display names
        local display_names=$(grep -o '"name": "[^"]*"' "$profile_file" | head -"$display_count" | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//')
        
        # Get unique app names
        local apps=$(grep -o '"app": "[^"]*"' "$profile_file" | cut -d'"' -f4 | sort -u | tr '\n' ', ' | sed 's/,$//')
        
        osascript <<EOF
            display dialog "Profile: $selected" & return & return & ¬
                "Saved: $saved_at" & return & ¬
                "Screens: $display_count ($display_names)" & return & ¬
                "Windows: $window_count" & return & return & ¬
                "Applications:" & return & "$apps" ¬
                buttons {"OK"} default button "OK" with title "Profile Details" with icon note
EOF
    fi
}

# Delete a profile
delete_profile() {
    local profiles
    local profile_list=""
    
    if [ -d "$PROFILES_DIR" ]; then
        profiles=($(ls "$PROFILES_DIR"/*.json 2>/dev/null | xargs -I {} basename {} .json))
    fi
    
    if [ ${#profiles[@]} -eq 0 ]; then
        osascript -e 'display alert "No Profiles" message "No profiles to delete." as warning'
        return 1
    fi
    
    for p in "${profiles[@]}"; do
        if [ -n "$profile_list" ]; then
            profile_list="$profile_list, \"$p\""
        else
            profile_list="\"$p\""
        fi
    done
    
    local selected
    selected=$(osascript <<EOF
        set profileList to {$profile_list}
        set theChoice to choose from list profileList with prompt "Select profile to delete:" with title "Delete Profile" OK button name "Delete" cancel button name "Cancel"
        if theChoice is false then
            return ""
        else
            return item 1 of theChoice
        end if
EOF
    )
    
    if [ -n "$selected" ]; then
        local confirm
        confirm=$(osascript <<EOF
            set theChoice to button returned of (display dialog "Are you sure you want to delete profile '$selected'?" & return & "This cannot be undone." buttons {"Cancel", "Delete"} default button "Cancel" with title "Confirm Delete" with icon caution)
            return theChoice
EOF
        )
        
        if [ "$confirm" = "Delete" ]; then
            rm -f "$PROFILES_DIR/${selected}.json"
            osascript -e "display notification \"Profile '$selected' deleted\" with title \"Window Manager\" sound name \"Glass\""
        fi
    fi
}

# Quick save (for command line usage)
quick_save() {
    local profile="${1:-default}"
    save_windows "$profile"
}

# Quick restore (for command line usage)
quick_restore() {
    local profile="${1:-default}"
    restore_windows "$profile"
}

# Show current display info
show_displays() {
    local display_info
    display_info=$(get_display_info)
    local count=$(echo "$display_info" | tr '|' '\n' | wc -l | tr -d ' ')
    
    echo "Current Display Configuration:"
    echo "=============================="
    echo "Total screens: $count"
    echo ""
    
    echo "$display_info" | tr '|' '\n' | while read -r display; do
        local name=$(echo "$display" | cut -d: -f1)
        local coords=$(echo "$display" | cut -d: -f2)
        local x=$(echo "$coords" | cut -d, -f1)
        local y=$(echo "$coords" | cut -d, -f2)
        local w=$(echo "$coords" | cut -d, -f3)
        local h=$(echo "$coords" | cut -d, -f4)
        echo "  $name"
        echo "    Position: ($x, $y)"
        echo "    Size: ${w}x${h}"
        echo ""
    done
}

# Main execution
main() {
    case "${1:-}" in
        --save)
            quick_save "${2:-default}"
            ;;
        --restore)
            quick_restore "${2:-default}"
            ;;
        --list)
            echo "Saved Profiles:"
            echo "==============="
            if [ -d "$PROFILES_DIR" ]; then
                for f in "$PROFILES_DIR"/*.json; do
                    if [ -f "$f" ]; then
                        local name=$(basename "$f" .json)
                        local count=$(grep -c '"app"' "$f" 2>/dev/null || echo "0")
                        local displays=$(grep -o '"display_count": [0-9]*' "$f" | grep -o '[0-9]*')
                        local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "unknown")
                        echo "  • $name: $count windows on $displays screen(s) (saved: $modified)"
                    fi
                done
            else
                echo "  No profiles found."
            fi
            ;;
        --displays)
            show_displays
            ;;
        --help)
            echo "Window Position Manager for macOS"
            echo ""
            echo "Usage:"
            echo "  $0                       # Interactive mode with dialogs"
            echo "  $0 --save [profile]      # Quick save to profile"
            echo "  $0 --restore [profile]   # Quick restore from profile"
            echo "  $0 --list                # List all profiles"
            echo "  $0 --displays            # Show current display configuration"
            echo ""
            echo "Profiles are stored in: $PROFILES_DIR"
            echo ""
            echo "Examples:"
            echo "  $0 --save work           # Save layout for work (1 external + laptop)"
            echo "  $0 --save home           # Save layout for home (2 external + laptop)"
            echo "  $0 --restore work        # Restore work layout"
            ;;
        *)
            # Interactive mode
            local choice
            choice=$(show_main_menu)
            
            case "$choice" in
                "Save Windows")
                    local profile
                    profile=$(get_profile_name "save")
                    if [ -n "$profile" ]; then
                        save_windows "$profile"
                    fi
                    ;;
                "Restore Windows")
                    local profile
                    profile=$(get_profile_name "restore")
                    if [ -n "$profile" ]; then
                        restore_windows "$profile"
                    fi
                    ;;
                "Manage Profiles")
                    manage_profiles
                    ;;
            esac
            ;;
    esac
}

main "$@"
