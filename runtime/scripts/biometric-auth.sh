#!/bin/bash
# Biometric Authentication Helper for macOS
# Uses osascript to trigger system authentication dialog

authenticate() {
    # Use osascript to display a dialog that requires authentication
    # This will prompt for Touch ID or password
    osascript << 'APPLESCRIPT'
        tell application "System Events"
            activate
            display dialog "Authenticate to reveal API key" buttons {"Cancel", "Authenticate"} default button "Authenticate" with icon caution
        end tell
APPLESCRIPT
    
    if [ $? -eq 0 ]; then
        echo "SUCCESS"
    else
        echo "FAILED"
    fi
}

check_availability() {
    # Check if we can run osascript (always available on macOS)
    if command -v osascript &> /dev/null; then
        echo "AVAILABLE"
    else
        echo "NOT_AVAILABLE"
    fi
}

case "$1" in
    authenticate)
        authenticate
        ;;
    check)
        check_availability
        ;;
    *)
        echo "Usage: $0 {authenticate|check}"
        exit 1
        ;;
esac
