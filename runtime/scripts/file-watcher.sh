#!/bin/bash
# File Watcher - Auto-refresh Mission Control when files change
# Runs continuously, watches for new files in workspace

WATCH_DIRS=(
    "$HOME/.openclaw/workspace"
    "$HOME/.openclaw/agents"
    "$HOME/.openclaw/scripts"
    "$HOME/.openclaw/commerce"
)

LOG_FILE="$HOME/.openclaw/logs/file-watcher.log"
LAST_REFRESH_FILE="$HOME/.openclaw/.last-file-refresh"

mkdir -p "$HOME/.openclaw/logs"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to notify Mission Control to refresh
notify_refresh() {
    local changed_file="$1"
    log "File changed: $changed_file"
    
    # Touch the refresh marker file
    touch "$LAST_REFRESH_FILE"
    
    # Optional: Send signal to Mission Control via API
    curl -s -X POST http://localhost:3333/api/refresh-files \
        -H "Content-Type: application/json" \
        -d "{\"file\":\"$changed_file\",\"timestamp\":$(date +%s)}" 2>/dev/null || true
}

log "Starting file watcher..."
log "Watching: ${WATCH_DIRS[*]}"

# Use fswatch if available, otherwise fallback to find loop
if command -v fswatch &> /dev/null; then
    log "Using fswatch for file monitoring"
    fswatch -o "${WATCH_DIRS[@]}" | while read -r event; do
        notify_refresh "batch change"
    done
else
    log "fswatch not available, using polling fallback"
    # Polling fallback - check every 10 seconds
    LAST_CHECK=$(date +%s)
    while true; do
        sleep 10
        
        # Find files modified in last 10 seconds
        for dir in "${WATCH_DIRS[@]}"; do
            if [ -d "$dir" ]; then
                NEW_FILES=$(find "$dir" -type f -mtime -0.002 2>/dev/null | head -5)
                if [ -n "$NEW_FILES" ]; then
                    notify_refresh "$NEW_FILES"
                fi
            fi
        done
    done
fi
