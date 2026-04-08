#!/bin/bash
# Email Monitor - Runs every 15 minutes via launchd
# Checks for unread emails, summarizes, creates calendar events

LOG_FILE="~/.openclaw/logs/email-monitor.log"
mkdir -p ~/.openclaw/logs

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check for unread emails
log "Checking Mail.app for unread messages..."

# Get unread emails (subject, sender, date)
UNREAD=$(osascript << 'APPLESCRIPT'
tell application "Mail"
    set unreadList to {}
    repeat with m in (every message of inbox whose read status is false)
        set end of unreadList to (subject of m & "|" & sender of m & "|" & date received of m)
    end repeat
    return unreadList as string
end tell
APPLESCRIPT
)

if [ -z "$UNREAD" ]; then
    log "No unread emails"
    exit 0
fi

# Process each unread email
echo "$UNREAD" | tr "," "\n" | while read line; do
    SUBJECT=$(echo "$line" | cut -d'|' -f1)
    SENDER=$(echo "$line" | cut -d'|' -f2)
    DATE=$(echo "$line" | cut -d'|' -f3)
    
    log "Found unread: $SUBJECT from $SENDER"
    
    # Check for keywords that need action
    if echo "$SUBJECT" | grep -iE "(settlement|milestone|deadline|court|solicitor|lawyer|contract|closing)" > /dev/null; then
        log "CRITICAL: Legal/Settlement email detected - $SUBJECT"
        
        # Create notification for Henry
        echo "{
            \"type\": \"urgent_email\",
            \"subject\": \"$SUBJECT\",
            \"sender\": \"$SENDER\",
            \"received\": \"$DATE\",
            \"action\": \"summarize_and_calendar\"
        }" >> ~/.openclaw/mission-control/notifications.json
    fi
done

log "Email check complete"
