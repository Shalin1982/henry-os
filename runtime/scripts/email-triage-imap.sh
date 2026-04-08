#!/bin/bash
# Email triage via himalaya CLI (IMAP fallback when AppleScript fails)

LOG_FILE="$HOME/.openclaw/logs/email-triage.log"
STATE_FILE="$HOME/.openclaw/mission-control/state.json"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Email Triage Starting ==="

# Check if himalaya is configured
if ! command -v himalaya &> /dev/null; then
    log "ERROR: himalaya not installed"
    exit 1
fi

# Get unread count
UNREAD_COUNT=$(himalaya list --page-size 100 2>/dev/null | grep -c "UNREAD" || echo "0")
log "Unread emails: $UNREAD_COUNT"

if [[ "$UNREAD_COUNT" -eq 0 ]]; then
    log "No unread emails"
    exit 0
fi

# Get subjects of unread emails
SUBJECTS=$(himalaya list --page-size 10 2>/dev/null | grep "UNREAD" | head -5 | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')

log "Top 5 unread subjects:"
echo "$SUBJECTS" | while read subject; do
    log "  - $subject"
done

# Update state.json with email status
cat "$STATE_FILE" | python3 - << PYEOF
import json,sys
from datetime import datetime, timezone

state = json.load(sys.stdin)

# Add to activity feed
activity = {
    "type": "EMAIL_TRIAGE",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "description": f"Email triage: $UNREAD_COUNT unread messages",
    "icon": "📧",
    "unread_count": $UNREAD_COUNT
}
state.setdefault("activity", []).insert(0, activity)

with open('$STATE_FILE', 'w') as f:
    json.dump(state, f, indent=2)
PYEOF

log "=== Email Triage Complete ==="
