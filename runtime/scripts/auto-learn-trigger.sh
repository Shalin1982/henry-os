#!/bin/bash
# Auto-run learning loop after any state.json task status change to DONE

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LAST_CHECK_FILE="$HOME/.openclaw/.last-learning-check"

# Get current timestamp
NOW=$(date +%s)

# Check if state.json was modified since last run
if [[ -f "$LAST_CHECK_FILE" ]]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE")
    if [[ -f "$STATE_FILE" ]]; then
        STATE_MTIME=$(stat -f %m "$STATE_FILE" 2>/dev/null || stat -c %Y "$STATE_FILE" 2>/dev/null)
        if [[ "$STATE_MTIME" -le "$LAST_CHECK" ]]; then
            exit 0  # No changes
        fi
    fi
fi

# Check for newly completed tasks
NEWLY_DONE=$(cat "$STATE_FILE" | python3 -c "
import json,sys,os
from datetime import datetime, timezone

state = json.load(sys.stdin)
tasks = state.get('tasks',[])
now = datetime.now(timezone.utc)

# Find tasks completed in last 5 minutes
newly_done = []
for t in tasks:
    if t.get('status') in ['DONE','done','completed','COMPLETED']:
        updated = t.get('updated_at') or t.get('completed_at')
        if updated:
            try:
                dt = datetime.fromisoformat(updated.replace('Z','+00:00'))
                mins_ago = (now - dt).total_seconds() / 60
                if mins_ago < 5:
                    newly_done.append(t.get('id'))
            except:
                pass

print(' '.join(newly_done))
" 2>/dev/null)

if [[ -n "$NEWLY_DONE" ]]; then
    # Run learning loop
    "$HOME/.openclaw/scripts/learn.sh" > /dev/null 2>&1 &
fi

# Update last check timestamp
echo "$NOW" > "$LAST_CHECK_FILE"
