#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Main Entry Point
# Version: 1.0
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
WORKSPACE="${HOME}/.openclaw"
LOG_DIR="${WORKSPACE}/logs"
DATA_DIR="${WORKSPACE}/message-processor"
STATE_DIR="${WORKSPACE}/mission-control"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOG_FILE="${LOG_DIR}/message-processor.log"
JSON_LOG="${LOG_DIR}/message-processor.jsonl"
LOCK_FILE="${DATA_DIR}/.processor.lock"
LAST_RUN_FILE="${DATA_DIR}/.last_run"
PROCESSED_IDS_FILE="${DATA_DIR}/.processed_ids"

OLLAMA_MODEL="${OLLAMA_MODEL:-gemma3:1b}"
SINCE_MINUTES="${SINCE_MINUTES:-15}"

# Counters
BILLS_FOUND=0
APPOINTMENTS_FOUND=0
DEADLINES_FOUND=0
SOCIAL_FOUND=0
ACTIONS_TAKEN=()

# ── Setup ──────────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$DATA_DIR"
[[ -f "$PROCESSED_IDS_FILE" ]] || touch "$PROCESSED_IDS_FILE"

# ── Logging ────────────────────────────────────────────────────────────────────
log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $msg" | tee -a "$LOG_FILE"
}
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# ── Lock Management ────────────────────────────────────────────────────────────
acquire_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "0")
        if ps -p "$pid" > /dev/null 2>&1; then
            log_warn "Already running (PID: $pid). Exiting."
            exit 0
        fi
        rm -f "$LOCK_FILE"
    fi
    echo $$ > "$LOCK_FILE"
}

release_lock() {
    rm -f "$LOCK_FILE"
}

cleanup() {
    release_lock
}
trap cleanup EXIT

# ── Processed ID Tracking ──────────────────────────────────────────────────────
is_processed() {
    grep -q "^$1$" "$PROCESSED_IDS_FILE" 2>/dev/null
}

mark_processed() {
    echo "$1" >> "$PROCESSED_IDS_FILE"
    tail -n 1000 "$PROCESSED_IDS_FILE" > "${PROCESSED_IDS_FILE}.tmp" 2>/dev/null && \
        mv "${PROCESSED_IDS_FILE}.tmp" "$PROCESSED_IDS_FILE"
}

# ── Fetch Emails via AppleScript ───────────────────────────────────────────────
fetch_emails() {
    local since_date
    since_date=$(date -v-${SINCE_MINUTES}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    
    osascript << 'APPLESCRIPT'
    tell application "Mail"
        set emailList to {}
        try
            set sinceDate to date (do shell script "date -v-15M '+%Y-%m-%d %H:%M:%S'")
            set unreadMsgs to every message of inbox whose date received > sinceDate and read status is false
            
            repeat with msg in unreadMsgs
                try
                    set msgData to {|
                        id:message id of msg,
                        type:"email",
                        subject:subject of msg,
                        sender:(sender of msg as string),
                        date:(date received of msg as string),
                        content:content of msg
                    |}
                    set end of emailList to msgData
                end try
            end repeat
        end try
        return emailList
    end tell
APPLESCRIPT
}

# ── Fetch iMessages via imsg CLI ───────────────────────────────────────────────
fetch_imessages() {
    if ! command -v imsg &> /dev/null; then
        echo "[]"
        return
    fi
    
    # Get recent messages from all chats
    local output="["
    local first=true
    
    while IFS= read -r chat_id; do
        [[ -z "$chat_id" ]] && continue
        
        local messages
        messages=$(imsg history --chat-id "$chat_id" --limit 5 --json 2>/dev/null)
        
        if [[ -n "$messages" && "$messages" != "[]" ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                output+=","
            fi
            # Extract and format messages
            output+=$(echo "$messages" | jq -c '.[] | {
                id: (.id // .messageId // tostring(now)),
                type: "imessage",
                sender: (.sender // .from // "Unknown"),
                subject: (.text // .content // ""),
                content: (.text // .content // ""),
                date: (.date // .timestamp // ""),
                chat_id: '"$chat_id"'
            }' | jq -s -c '.')
        fi
    done < <(imsg chats --limit 10 --json 2>/dev/null | jq -r '.[].id // .[].chatId // empty')
    
    output+="]"
    echo "$output" | jq -c '.[]' 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]"
}

# ── Classify with Python ───────────────────────────────────────────────────────
classify_message() {
    local subject="$1"
    local sender="$2"
    local content="$3"
    
    local json_input
    json_input=$(printf '{"subject":"%s","sender":"%s","content":"%s"}' \
        "$(echo "$subject" | sed 's/"/\\"/g')" \
        "$(echo "$sender" | sed 's/"/\\"/g')" \
        "$(echo "$content" | sed 's/"/\\"/g' | head -c 1500)")
    
    OLLAMA_MODEL="$OLLAMA_MODEL" python3 "$SCRIPT_DIR/message-classifier.py" classify <<< "$json_input" 2>/dev/null || \
        echo '{"categories":[],"priority":"low","summary":"Classification failed"}' 
}

# ── Add to Calendar ────────────────────────────────────────────────────────────
add_to_calendar() {
    local title="$1"
    local date_str="$2"
    local notes="${3:-}"
    local is_all_day="${4:-false}"
    
    log_info "Adding to calendar: $title on $date_str"
    
    # Try AppleScript first
    osascript << APPLESCRIPT 2>/dev/null || true
        tell application "Calendar"
            try
                tell calendar "Home"
                    if "$is_all_day" is "true" then
                        make new event with properties {summary:"$title", start date:date "$date_str", allday event:true, description:"$notes"}
                    else
                        make new event with properties {summary:"$title", start date:date "$date_str", description:"$notes"}
                    end if
                end tell
            on error
                -- Try default calendar
                make new event with properties {summary:"$title", start date:date "$date_str", description:"$notes"}
            end try
        end tell
APPLESCRIPT
}

# ── Add Task to Mission Control ────────────────────────────────────────────────
add_task() {
    local title="$1"
    local priority="${2:-medium}"
    local description="${3:-}"
    local tags="${4:-}"
    
    log_info "Adding task: $title (priority: $priority)"
    
    local state_file="$STATE_DIR/state.json"
    [[ -f "$state_file" ]] || return
    
    local task_id="MSG-$(date +%s)-$RANDOM"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Use Python to safely update JSON
    python3 << PYEOF 2>/dev/null || true
import json
import sys

try:
    with open("$state_file", "r") as f:
        state = json.load(f)
except:
    state = {"tasks": []}

task = {
    "id": "$task_id",
    "title": "$title",
    "description": "$description",
    "status": "todo",
    "priority": "$priority",
    "tags": "$tags".split(",") if "$tags" else [],
    "created_at": "$timestamp",
    "source": "message-processor"
}

state.setdefault("tasks", []).insert(0, task)

with open("$state_file", "w") as f:
    json.dump(state, f, indent=2)
PYEOF
}

# ── Queue for Finnova ──────────────────────────────────────────────────────────
queue_for_finnova() {
    local description="$1"
    local amount="$2"
    local due_date="$3"
    local vendor="$4"
    
    log_info "Queueing for Finnova: $description - $amount"
    
    local queue_file="$DATA_DIR/finnova_queue.jsonl"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    printf '{"timestamp":"%s","description":"%s","amount":"%s","due_date":"%s","vendor":"%s","status":"pending"}\n' \
        "$timestamp" "$description" "$amount" "$due_date" "$vendor" >> "$queue_file"
}

# ── Process Single Message ─────────────────────────────────────────────────────
process_single_message() {
    local msg_json="$1"
    
    local msg_id msg_type subject sender content date
    msg_id=$(echo "$msg_json" | jq -r '.id // empty')
    msg_type=$(echo "$msg_json" | jq -r '.type // "unknown"')
    subject=$(echo "$msg_json" | jq -r '.subject // .text // "No Subject"')
    sender=$(echo "$msg_json" | jq -r '.sender // .from // "Unknown"')
    content=$(echo "$msg_json" | jq -r '.content // .text // .body // ""')
    date=$(echo "$msg_json" | jq -r '.date // empty')
    
    [[ -z "$msg_id" ]] && return
    
    if is_processed "$msg_id"; then
        log_info "Skipping processed message: $msg_id"
        return
    fi
    
    log_info "Processing $msg_type from $sender: ${subject:0:40}..."
    
    # Classify
    local classification
    classification=$(classify_message "$subject" "$sender" "$content")
    
    local summary
    summary=$(echo "$classification" | jq -r '.summary // "No summary"')
    log_info "  → $summary"
    
    # Process each category
    local categories
    categories=$(echo "$classification" | jq -c '.categories[]' 2>/dev/null)
    
    while IFS= read -r cat; do
        [[ -z "$cat" ]] && continue
        
        local cat_name confidence
        cat_name=$(echo "$cat" | jq -r '.name // empty' | tr '[:lower:]' '[:upper:]')
        confidence=$(echo "$cat" | jq -r '.confidence // 0')
        
        # Skip low confidence
        if (( $(echo "$confidence < 0.6" | bc -l) )); then
            continue
        fi
        
        case "$cat_name" in
            BILL)
                local amount due_date
                amount=$(echo "$cat" | jq -r '.details.amount // "Unknown"')
                due_date=$(echo "$classification" | jq -r '.dates[0] // ""')
                
                queue_for_finnova "$subject" "$amount" "$due_date" "$sender"
                
                if [[ -n "$due_date" ]]; then
                    add_to_calendar "💰 Bill Due: ${subject:0:30}" "$due_date" "Amount: $amount from $sender" "true"
                fi
                
                ACTIONS_TAKEN+=("💰 Bill: ${subject:0:40} ($amount)")
                ((BILLS_FOUND++))
                ;;
                
            APPOINTMENT)
                local appt_date
                appt_date=$(echo "$classification" | jq -r '.dates[0] // ""')
                
                if [[ -n "$appt_date" ]]; then
                    add_to_calendar "📅 $subject" "$appt_date" "From: $sender"
                    ACTIONS_TAKEN+=("📅 Appointment: ${subject:0:40} on $appt_date")
                else
                    add_task "Schedule: $subject" "medium" "From: $sender" "appointment"
                    ACTIONS_TAKEN+=("📝 Task: Schedule appointment - ${subject:0:40}")
                fi
                ((APPOINTMENTS_FOUND++))
                ;;
                
            DEADLINE)
                local deadline_date
                deadline_date=$(echo "$classification" | jq -r '.dates[0] // ""')
                
                add_task "⏰ Deadline: $subject" "high" "Due: $deadline_date | From: $sender" "deadline"
                ACTIONS_TAKEN+=("⏰ Deadline: ${subject:0:40}")
                ((DEADLINES_FOUND++))
                ;;
                
            SOCIAL|WORK)
                local tag="${cat_name,,}"
                local priority
                priority=$(echo "$classification" | jq -r '.priority // "low"')
                
                if [[ "$priority" == "high" ]]; then
                    add_task "Follow up: $subject" "$priority" "From: $sender" "$tag"
                    ACTIONS_TAKEN+=("🏷️ [$tag] ${subject:0:40}")
                    ((SOCIAL_FOUND++))
                fi
                ;;
        esac
    done <<< "$categories"
    
    mark_processed "$msg_id"
}

# ── Send Email Notification ──────────────────────────────────────────────────
send_email_notification() {
    local total=$((BILLS_FOUND + APPOINTMENTS_FOUND + DEADLINES_FOUND + SOCIAL_FOUND))
    
    if [[ $total -eq 0 ]]; then
        return
    fi
    
    local subject="Henry: $total new actions from your messages"
    local body="Message Processor Summary - $(date '+%Y-%m-%d %H:%M')\n\n"
    
    [[ $BILLS_FOUND -gt 0 ]] && body+="💰 Bills: $BILLS_FOUND\n"
    [[ $APPOINTMENTS_FOUND -gt 0 ]] && body+="📅 Appointments: $APPOINTMENTS_FOUND\n"
    [[ $DEADLINES_FOUND -gt 0 ]] && body+="⏰ Deadlines: $DEADLINES_FOUND\n"
    [[ $SOCIAL_FOUND -gt 0 ]] && body+="🏷️ Tagged: $SOCIAL_FOUND\n"
    
    body+="\nDetails:\n"
    for action in "${ACTIONS_TAKEN[@]}"; do
        body+="  • $action\n"
    done
    
    body+="\n---\nProcessed by Henry Message Processor"
    
    # Send via Mail.app AppleScript
    osascript << EOF 2>/dev/null || log_warn "Failed to send email notification"
tell application "Mail"
    set newMessage to make new outgoing message with properties {subject:"$subject", content:"$body"}
    tell newMessage
        make new to recipient at end of to recipients with properties {address:"shannon.linnan@gmail.com"}
        make new to recipient at end of to recipients with properties {address:"slinnan@ljhgc.com.au"}
        send
    end tell
end tell
EOF
    
    log_info "Email notification sent to shannon.linnan@gmail.com and slinnan@ljhgc.com.au"
}

# ── Send Telegram Notification ─────────────────────────────────────────────────
send_telegram() {
    local total=$((BILLS_FOUND + APPOINTMENTS_FOUND + DEADLINES_FOUND + SOCIAL_FOUND))
    
    if [[ $total -eq 0 ]]; then
        log_info "No actions to report"
        return
    fi
    
    # Build message
    local msg="📨%20<b>Message%20Processor%20Summary</b>%0A%0A"
    msg+="<b>Actions%20taken:</b>%0A"
    
    [[ $BILLS_FOUND -gt 0 ]] && msg+="💰%20Bills:%20$BILLS_FOUND%0A"
    [[ $APPOINTMENTS_FOUND -gt 0 ]] && msg+="📅%20Appointments:%20$APPOINTMENTS_FOUND%0A"
    [[ $DEADLINES_FOUND -gt 0 ]] && msg+="⏰%20Deadlines:%20$DEADLINES_FOUND%0A"
    [[ $SOCIAL_FOUND -gt 0 ]] && msg+="🏷️%20Tagged:%20$SOCIAL_FOUND%0A"
    
    msg+="%0A<i>Processed%20at%20$(date '+%H:%M')</i>"
    
    # Get bot token from credentials if not set
    if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        local creds_file="$WORKSPACE/credentials/telegram-pairing.json"
        if [[ -f "$creds_file" ]]; then
            TELEGRAM_BOT_TOKEN=$(jq -r '.token // empty' "$creds_file" 2>/dev/null)
        fi
    fi
    
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
        curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d "chat_id=${TELEGRAM_CHAT_ID:-1396755187}" \
            -d "parse_mode=HTML" \
            -d "text=$msg" > /dev/null 2>&1 || log_warn "Failed to send Telegram notification"
    else
        log_warn "Telegram bot token not configured"
    fi
    
    # Also send email notification
    send_email_notification
}

# ── Update Mission Control Activity ────────────────────────────────────────────
update_activity() {
    local state_file="$STATE_DIR/state.json"
    [[ -f "$state_file" ]] || return
    
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    python3 << PYEOF 2>/dev/null || true
import json

try:
    with open("$state_file", "r") as f:
        state = json.load(f)
except:
    state = {}

activity = {
    "type": "MESSAGE_PROCESSOR",
    "timestamp": "$timestamp",
    "description": f"Processed: $BILLS_FOUND bills, $APPOINTMENTS_FOUND appointments, $DEADLINES_FOUND deadlines",
    "icon": "📨",
    "bills": $BILLS_FOUND,
    "appointments": $APPOINTMENTS_FOUND,
    "deadlines": $DEADLINES_FOUND,
    "social": $SOCIAL_FOUND
}

state.setdefault("activity", []).insert(0, activity)
state["activity"] = state["activity"][:100]

with open("$state_file", "w") as f:
    json.dump(state, f, indent=2)
PYEOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

log_info "=== Message Processor Starting ==="
log_info "Model: $OLLAMA_MODEL | Window: ${SINCE_MINUTES}min"

acquire_lock

# Check dependencies
command -v jq &> /dev/null || { log_error "jq not installed"; exit 1; }
command -v python3 &> /dev/null || { log_error "python3 not installed"; exit 1; }

# Fetch and process emails
log_info "Fetching emails..."
EMAILS=$(fetch_emails 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")
EMAIL_COUNT=$(echo "$EMAILS" | jq 'length' | tr -d '\n')
log_info "Found $EMAIL_COUNT new emails"

if [[ $EMAIL_COUNT -gt 0 ]]; then
    echo "$EMAILS" | jq -c '.[]' | while read -r email; do
        process_single_message "$email"
    done
fi

# Fetch and process iMessages
log_info "Fetching iMessages..."
MESSAGES=$(fetch_imessages 2>/dev/null)
MSG_COUNT=$(echo "$MESSAGES" | jq 'length' | tr -d '\n')
log_info "Found $MSG_COUNT new messages"

if [[ $MSG_COUNT -gt 0 ]]; then
    echo "$MESSAGES" | jq -c '.[]' | while read -r msg; do
        process_single_message "$msg"
    done
fi

# Update state
update_activity

# Send notification
send_telegram

# Record run time
date -u +%Y-%m-%dT%H:%M:%SZ > "$LAST_RUN_FILE"

log_info "=== Complete: $BILLS_FOUND bills, $APPOINTMENTS_FOUND appointments, $DEADLINES_FOUND deadlines ==="

exit 0
