#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Automated Email & SMS Processing System
# Version: 1.0
# Frequency: Every 15 minutes via cron
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"
WORKSPACE="$HOME/.openclaw"
LOG_DIR="$WORKSPACE/logs"
STATE_DIR="$WORKSPACE/mission-control"
DATA_DIR="$WORKSPACE/message-processor"
LOCK_FILE="$DATA_DIR/.processor.lock"
LAST_RUN_FILE="$DATA_DIR/.last_run"
PROCESSED_IDS_FILE="$DATA_DIR/.processed_ids"

# Logging
LOG_FILE="$LOG_DIR/message-processor.log"
JSON_LOG="$LOG_DIR/message-processor.jsonl"

# External tools
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma3:1b}"  # Default to lightweight model
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-1396755187}"  # From credentials

# ── Ensure directories exist ───────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$DATA_DIR" "$STATE_DIR"

# ── Logging functions ──────────────────────────────────────────────────────────
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # Also write structured JSON log
    printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$message" >> "$JSON_LOG"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# ── Lock mechanism to prevent concurrent runs ──────────────────────────────────
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warn "Another instance is running (PID: $pid). Exiting."
            exit 0
        else
            log_warn "Stale lock file found. Removing."
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# ── Cleanup on exit ────────────────────────────────────────────────────────────
cleanup() {
    release_lock
    log_info "=== Message Processor Finished ==="
}
trap cleanup EXIT

# ── Initialize processed IDs file ──────────────────────────────────────────────
init_processed_ids() {
    [[ -f "$PROCESSED_IDS_FILE" ]] || touch "$PROCESSED_IDS_FILE"
}

# ── Check if message was already processed ─────────────────────────────────────
is_processed() {
    local msg_id="$1"
    grep -q "^${msg_id}$" "$PROCESSED_IDS_FILE" 2>/dev/null
}

# ── Mark message as processed ──────────────────────────────────────────────────
mark_processed() {
    local msg_id="$1"
    echo "$msg_id" >> "$PROCESSED_IDS_FILE"
    # Keep only last 1000 IDs to prevent file bloat
    tail -n 1000 "$PROCESSED_IDS_FILE" > "$PROCESSED_IDS_FILE.tmp" && \
        mv "$PROCESSED_IDS_FILE.tmp" "$PROCESSED_IDS_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

log_info "=== Message Processor Starting ==="
log_info "PID: $$ | Model: $OLLAMA_MODEL"

acquire_lock
init_processed_ids

# Initialize results tracking
BILLS_FOUND=0
APPOINTMENTS_FOUND=0
DEADLINES_FOUND=0
SOCIAL_FOUND=0
ACTIONS_TAKEN=()

# ── Source the module files ────────────────────────────────────────────────────
source "$SCRIPT_DIR/message-processor-lib.sh" 2>/dev/null || {
    log_error "Failed to load message-processor-lib.sh"
    exit 1
}

# ── Fetch Messages ─────────────────────────────────────────────────────────────
log_info "Fetching messages from Mail.app and iMessage..."

# Get recent emails (last 15 minutes)
EMAILS_JSON=$(fetch_recent_emails)
EMAIL_COUNT=$(echo "$EMAILS_JSON" | jq 'length')
log_info "Found $EMAIL_COUNT new emails"

# Get recent iMessage/SMS
MESSAGES_JSON=$(fetch_recent_messages)
MESSAGE_COUNT=$(echo "$MESSAGES_JSON" | jq 'length')
log_info "Found $MESSAGE_COUNT new iMessage/SMS messages"

# ── Process Each Email ─────────────────────────────────────────────────────────
log_info "Processing emails..."
echo "$EMAILS_JSON" | jq -c '.[]' 2>/dev/null | while read -r email; do
    process_message "$email" "email"
done

# ── Process Each iMessage ──────────────────────────────────────────────────────
log_info "Processing iMessage/SMS..."
echo "$MESSAGES_JSON" | jq -c '.[]' 2>/dev/null | while read -r msg; do
    process_message "$msg" "imessage"
done

# ── Update Mission Control State ───────────────────────────────────────────────
update_mission_control_state

# ── Send Telegram Summary ──────────────────────────────────────────────────────
send_telegram_summary

# ── Update Last Run Time ───────────────────────────────────────────────────────
date -u +%Y-%m-%dT%H:%M:%SZ > "$LAST_RUN_FILE"

log_info "Processing complete. Bills: $BILLS_FOUND, Appointments: $APPOINTMENTS_FOUND, Deadlines: $DEADLINES_FOUND, Social: $SOCIAL_FOUND"

exit 0
