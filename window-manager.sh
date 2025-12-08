#!/bin/bash

# Window Position Manager for macOS
# Saves and restores application window positions
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

# Save window positions
save_windows() {
    local profile="$1"
    local profile_file="$PROFILES_DIR/${profile}.json"
    
    osascript <<'EOF' - "$profile_file"
        on run argv
            set profileFile to item 1 of argv
            set windowData to "[\n"
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
                                            
                                            if not isFirst then
                                                set windowData to windowData & ",\n"
                                            end if
                                            set isFirst to false
                                            
                                            -- Escape quotes in window name
                                            set AppleScript's text item delimiters to "\""
                                            set winNameParts to text items of winName
                                            set AppleScript's text item delimiters to "\\\""
                                            set escapedWinName to winNameParts as text
                                            set AppleScript's text item delimiters to ""
                                            
                                            set windowData to windowData & "  {\"app\": \"" & appName & "\", \"bundle\": \"" & appBundle & "\", \"window\": \"" & escapedWinName & "\", \"x\": " & winX & ", \"y\": " & winY & ", \"width\": " & winW & ", \"height\": " & winH & "}"
                                        end if
                                    end try
                                end repeat
                            end tell
                        end if
                    end try
                end repeat
            end tell
            
            set windowData to windowData & "\n]"
            
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
        osascript -e "display notification \"Saved $count windows to profile: $profile\" with title \"Window Manager\" sound name \"Glass\""
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
            
            -- Parse simple JSON (basic parser for our format)
            set windowList to {}
            set AppleScript's text item delimiters to "{"
            set entries to text items of fileContent
            
            repeat with entry in entries
                if entry contains "\"app\"" then
                    -- Extract app name
                    set AppleScript's text item delimiters to "\"app\": \""
                    set parts to text items of entry
                    if (count of parts) > 1 then
                        set AppleScript's text item delimiters to "\""
                        set appName to text item 1 of (item 2 of parts)
                        
                        -- Extract bundle id
                        set AppleScript's text item delimiters to "\"bundle\": \""
                        set parts to text items of entry
                        set AppleScript's text item delimiters to "\""
                        set bundleId to text item 1 of (item 2 of parts)
                        
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
                        set AppleScript's text item delimiters to "}"
                        set winHeight to (text item 1 of (item 2 of parts)) as integer
                        
                        set end of windowList to {appName:appName, bundleId:bundleId, x:xPos, y:yPos, width:winWidth, height:winHeight}
                    end if
                end if
            end repeat
            
            set AppleScript's text item delimiters to ""
            set restoredCount to 0
            set openedApps to {}
            
            -- Process each window
            repeat with winInfo in windowList
                set appName to appName of winInfo
                set bundleId to bundleId of winInfo
                set xPos to x of winInfo
                set yPos to y of winInfo
                set winWidth to width of winInfo
                set winHeight to height of winInfo
                
                tell application "System Events"
                    set appRunning to (count of (every process whose bundle identifier is bundleId)) > 0
                end tell
                
                -- Open app if not running and user requested
                if not appRunning and shouldOpenApps then
                    try
                        tell application id bundleId to activate
                        delay 1.5 -- Give app time to open
                        if appName is not in openedApps then
                            set end of openedApps to appName
                        end if
                        set appRunning to true
                    on error
                        -- Try by name if bundle id fails
                        try
                            tell application appName to activate
                            delay 1.5
                            if appName is not in openedApps then
                                set end of openedApps to appName
                            end if
                            set appRunning to true
                        end try
                    end try
                end if
                
                -- Position window if app is running
                if appRunning then
                    try
                        tell application "System Events"
                            tell process appName
                                set frontmost to true
                                delay 0.2
                                if (count of windows) > 0 then
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
            
            display notification "Restored " & restoredCount & " windows" & openedMsg with title "Window Manager" sound name "Glass"
            
            return restoredCount
        end run
EOF
}

# Manage profiles menu
manage_profiles() {
    local action
    action=$(osascript <<EOF
        set theChoice to button returned of (display dialog "Profile Management" & return & return & "Choose an action:" buttons {"Delete Profile", "List Profiles", "Cancel"} default button "List Profiles" with title "Manage Profiles" with icon note)
        return theChoice
EOF
    )
    
    case "$action" in
        "List Profiles")
            list_profiles
            ;;
        "Delete Profile")
            delete_profile
            ;;
        "Cancel")
            return 0
            ;;
    esac
}

# List all profiles
list_profiles() {
    local profiles_info=""
    
    if [ -d "$PROFILES_DIR" ]; then
        for f in "$PROFILES_DIR"/*.json; do
            if [ -f "$f" ]; then
                local name=$(basename "$f" .json)
                local count=$(grep -c '"app"' "$f" 2>/dev/null || echo "0")
                local modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || echo "unknown")
                profiles_info="$profiles_info• $name: $count windows (saved: $modified)\n"
            fi
        done
    fi
    
    if [ -z "$profiles_info" ]; then
        profiles_info="No profiles found."
    fi
    
    osascript -e "display dialog \"Saved Profiles:\" & return & return & \"$profiles_info\" buttons {\"OK\"} default button \"OK\" with title \"Profile List\" with icon note"
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
            list_profiles
            ;;
        --help)
            echo "Window Position Manager"
            echo ""
            echo "Usage:"
            echo "  $0              # Interactive mode with dialogs"
            echo "  $0 --save [profile]    # Quick save to profile"
            echo "  $0 --restore [profile] # Quick restore from profile"
            echo "  $0 --list              # List all profiles"
            echo ""
            echo "Profiles are stored in: $PROFILES_DIR"
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
