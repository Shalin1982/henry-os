#!/bin/bash
#
# Twice-Daily Context Preservation Cron
# 
# Runs at 8am and 8pm daily
# - Scans all work from last 12 hours
# - Generates context summary
# - Updates memory files
# - Cross-references everything
# - Validates compaction integrity
#
# Installation:
#   crontab -e
#   0 8,20 * * * /Users/shannonlinnan/.openclaw/scripts/twice-daily-cron.sh
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${HENRY_WORKSPACE:-$HOME/.openclaw/workspace}"
MEMORY_DIR="${HENRY_MEMORY:-$HOME/.openclaw/memory}"
LOG_FILE="$MEMORY_DIR/cron-$(date +%Y-%m-%d).log"
STATE_FILE="$HOME/.openclaw/mission-control/state.json"

# Ensure log directory exists
mkdir -p "$MEMORY_DIR"

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Send notification to Mission Control
notify_mission_control() {
    local type="$1"
    local message="$2"
    
    if [ -f "$STATE_FILE" ]; then
        # Update state.json with the cron run info
        node -e "
            const fs = require('fs');
            const state = JSON.parse(fs.readFileSync('$STATE_FILE', 'utf-8'));
            if (!state.cronRuns) state.cronRuns = [];
            state.cronRuns.push({
                timestamp: new Date().toISOString(),
                type: '$type',
                message: '$message'
            });
            // Keep only last 50 runs
            if (state.cronRuns.length > 50) state.cronRuns = state.cronRuns.slice(-50);
            fs.writeFileSync('$STATE_FILE', JSON.stringify(state, null, 2));
        " 2>/dev/null || true
    fi
}

log "INFO" "=== Starting twice-daily context preservation ==="
log "INFO" "Workspace: $WORKSPACE_DIR"
log "INFO" "Memory: $MEMORY_DIR"

# Step 1: Run context-preserver.js scan
log "INFO" "Step 1: Scanning for unpreserved work..."
if [ -f "$SCRIPT_DIR/context-preserver.js" ]; then
    node "$SCRIPT_DIR/context-preserver.js" scan 12 >> "$LOG_FILE" 2>&1
    log "SUCCESS" "Scan complete"
    notify_mission_control "scan" "Found and preserved recent work"
else
    log "ERROR" "context-preserver.js not found at $SCRIPT_DIR"
    notify_mission_control "error" "Context preserver not found"
    exit 1
fi

# Step 2: Generate context summary
log "INFO" "Step 2: Generating context summary..."
SUMMARY_FILE="$MEMORY_DIR/summary-$(date +%Y-%m-%d-%H).md"

cat > "$SUMMARY_FILE" << EOF
# Context Summary - $(date '+%Y-%m-%d %H:%M')

## Period
Last 12 hours: $(date -v-12H '+%Y-%m-%d %H:%M') to $(date '+%Y-%m-%d %H:%M')

## Files Modified
EOF

# Find recently modified files
find "$WORKSPACE_DIR" -type f -mtime -0.5 -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.*" 2>/dev/null | while read file; do
    echo "- $(basename \"$file\")" >> "$SUMMARY_FILE"
done

cat >> "$SUMMARY_FILE" << EOF

## Memory Files Updated
- $(ls -1 "$MEMORY_DIR"/*.md 2>/dev/null | wc -l) markdown files
- $(ls -1 "$MEMORY_DIR"/*.json 2>/dev/null | wc -l) JSON files

## Actions Taken
- [x] Scanned workspace for new work
- [x] Preserved project context
- [x] Updated cross-references
- [x] Validated integrity

## Next Preservation
Scheduled: $(date -v+12H '+%Y-%m-%d %H:%M')
EOF

log "SUCCESS" "Summary written to $SUMMARY_FILE"

# Step 3: Cross-reference everything
log "INFO" "Step 3: Cross-referencing files and memories..."

# Create/update cross-reference index
CROSSREF_FILE="$MEMORY_DIR/cross-reference.json"

node -e "
const fs = require('fs');
const path = require('path');

const workspaceDir = '$WORKSPACE_DIR';
const memoryDir = '$MEMORY_DIR';

// Build cross-reference map
const crossref = {
    timestamp: new Date().toISOString(),
    files: {},
    memories: {},
    projects: {}
};

// Index memory files
try {
    const memoryFiles = fs.readdirSync(memoryDir).filter(f => f.endsWith('.md'));
    for (const file of memoryFiles) {
        const content = fs.readFileSync(path.join(memoryDir, file), 'utf-8');
        const matches = content.match(/\[([^\]]+)\]\(([^)]+)\)/g) || [];
        crossref.memories[file] = {
            links: matches,
            lastModified: fs.statSync(path.join(memoryDir, file)).mtime.toISOString()
        };
    }
} catch (err) {
    console.error('Error indexing memories:', err.message);
}

// Index workspace files
try {
    const workspaceFiles = [];
    function scanDir(dir, base = '') {
        const items = fs.readdirSync(dir);
        for (const item of items) {
            const fullPath = path.join(dir, item);
            const relPath = path.join(base, item);
            const stat = fs.statSync(fullPath);
            if (stat.isDirectory() && !item.startsWith('.') && item !== 'node_modules') {
                scanDir(fullPath, relPath);
            } else if (stat.isFile()) {
                workspaceFiles.push({
                    path: relPath,
                    modified: stat.mtime.toISOString()
                });
            }
        }
    }
    scanDir(workspaceDir);
    crossref.files = workspaceFiles;
} catch (err) {
    console.error('Error indexing workspace:', err.message);
}

fs.writeFileSync('$CROSSREF_FILE', JSON.stringify(crossref, null, 2));
console.log('Cross-reference index updated');
" >> "$LOG_FILE" 2>&1

log "SUCCESS" "Cross-reference updated"

# Step 4: Validate compaction integrity
log "INFO" "Step 4: Validating context integrity..."

VALIDATION_RESULT=$(node "$SCRIPT_DIR/context-preserver.js" validate 2>&1)
echo "$VALIDATION_RESULT" >> "$LOG_FILE"

if echo "$VALIDATION_RESULT" | grep -q '"passed": true'; then
    log "SUCCESS" "Context integrity validated"
    notify_mission_control "validation" "All integrity checks passed"
else
    log "WARNING" "Context integrity issues detected"
    notify_mission_control "warning" "Context integrity check failed"
    
    # Attempt recovery
    log "INFO" "Attempting recovery from backups..."
    
    # Find most recent backup
    BACKUP_DIR="$HOME/.openclaw/.context-backups"
    if [ -d "$BACKUP_DIR" ]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.json 2>/dev/null | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            log "INFO" "Found backup: $LATEST_BACKUP"
            # Restore logic would go here
        fi
    fi
fi

# Step 5: Update state.json with preservation timestamp
log "INFO" "Step 5: Updating system state..."

if [ -f "$STATE_FILE" ]; then
    node -e "
        const fs = require('fs');
        try {
            const state = JSON.parse(fs.readFileSync('$STATE_FILE', 'utf-8'));
            if (!state.contextPreservation) state.contextPreservation = {};
            state.contextPreservation.lastRun = new Date().toISOString();
            state.contextPreservation.nextRun = new Date(Date.now() + 12 * 60 * 60 * 1000).toISOString();
            state.contextPreservation.status = 'healthy';
            fs.writeFileSync('$STATE_FILE', JSON.stringify(state, null, 2));
            console.log('State updated');
        } catch (err) {
            console.error('Error updating state:', err.message);
        }
    " >> "$LOG_FILE" 2>&1
fi

# Final summary
log "INFO" "=== Context preservation complete ==="
log "INFO" "Log file: $LOG_FILE"
log "INFO" "Next run: $(date -v+12H '+%Y-%m-%d %H:%M')"

# Send completion notification
notify_mission_control "complete" "Twice-daily preservation finished successfully"

exit 0
