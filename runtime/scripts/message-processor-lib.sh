#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Library Functions
# Version: 1.0
# ═══════════════════════════════════════════════════════════════════════════════

# ── Fetch Recent Emails from Mail.app ───────────────────────────────────────────
fetch_recent_emails() {
    local since_minutes="${1:-15}"
    local since_date
    since_date=$(date -v-${since_minutes}M '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 date -d "${since_minutes} minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || \
                 date '+%Y-%m-%d %H:%M:%S')
    
    # Use osascript to read Mail.app
    osascript << APPLESCRIPT 2>/dev/null | jq -s '.'
        tell application "Mail"
            set emailList to {}
            set sinceDate to date "$since_date"
            
            try
                set allMessages to every message of inbox whose date received > sinceDate and read status is false
                
                repeat with msg in allMessages
                    try
                        set msgId to message id of msg
                        set msgSubject to subject of msg
                        set msgSender to sender of msg
                        set msgDate to date received of msg
                        set msgContent to content of msg
                        
                        # Build JSON object
                        set jsonStr to "{"
                        set jsonStr to jsonStr & "\"id\":\"" & msgId & "\","
                        set jsonStr to jsonStr & "\"type\":\"email\","
                        set jsonStr to jsonStr & "\"subject\":\"" & my escapeJson(msgSubject) & "\","
                        set jsonStr to jsonStr & "\"sender\":\"" & my escapeJson(msgSender) & "\","
                        set jsonStr to jsonStr & "\"date\":\"" & (msgDate as string) & "\","
                        set jsonStr to jsonStr & "\"content\":\"" & my escapeJson(msgContent) & "\""
                        set jsonStr to jsonStr & "}"
                        
                        set end of emailList to jsonStr
                    on error errMsg
                        # Skip problematic messages
                    end try
                end repeat
            on error errMsg
                # Mail.app might not be running or accessible
            end try
            
            return "[" & my joinList(emailList, ",") & "]"
        end tell
        
        on escapeJson(str)
            set str to my replaceString(str, "\\", "\\\\")
            set str to my replaceString(str, "\"", "\\\"")
            set str to my replaceString(str, "\n", "\\n")
            set str to my replaceString(str, "\r", "\\r")
            set str to my replaceString(str, "\t", "\\t")
            return str
        end escapeJson
        
        on replaceString(source, find, replace)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to find
            set textItems to text items of source
            set AppleScript's text item delimiters to replace
            set resultStr to textItems as string
            set AppleScript's text item delimiters to oldDelimiters
            return resultStr
        end replaceString
        
        on joinList(theList, delimiter)
            set oldDelimiters to AppleScript's text item delimiters
            set AppleScript's text item delimiters to delimiter
            set resultStr to theList as string
            set AppleScript's text item delimiters to oldDelimiters
            return resultStr
        end joinList
APPLESCRIPT
}

# ── Fetch Recent iMessage/SMS ──────────────────────────────────────────────────
fetch_recent_messages() {
    local since_minutes="${1:-15}"
    
    # Use imsg CLI if available
    if command -v imsg &> /dev/null; then
        # Get recent chats and their messages
        local since_timestamp
        since_timestamp=$(date -v-${since_minutes}M +%s 2>/dev/null || date -d "${since_minutes} minutes ago" +%s 2>/dev/null || echo "0")
        
        # Fetch recent chats
        imsg chats --limit 20 --json 2>/dev/null | jq -c '.[]' | while read -r chat; do
            local chat_id
            chat_id=$(echo "$chat" | jq -r '.id // .chatId // empty')
            [[ -z "$chat_id" ]] && continue
            
            # Get recent messages from this chat
            imsg history --chat-id "$chat_id" --limit 10 --json 2>/dev/null | jq -c '.[]' | while read -r msg; do
                local msg_date
                msg_date=$(echo "$msg" | jq -r '.date // .timestamp // empty')
                [[ -z "$msg_date" ]] && continue
                
                # Check if message is recent enough
                local msg_timestamp
                msg_timestamp=$(date -j -f '%Y-%m-%d %H:%M:%S' "$msg_date" +%s 2>/dev/null || echo "0")
                if [[ "$msg_timestamp" -gt "$since_timestamp" ]]; then
                    echo "$msg" | jq '{
                        id: (.id // .messageId // "unknown"),
                        type: "imessage",
                        sender: (.sender // .from // "Unknown"),
                        content: (.text // .content // .body // ""),
                        date: (.date // .timestamp // ""),
                        chat_id: '"$chat_id"',
                        service: (.service // "imessage")
                    }'
                fi
            done
        done | jq -s '.'
    else
        # Fallback: return empty array
        echo "[]"
    fi
}

# ── Classify Message Using Local LLM ───────────────────────────────────────────
classify_message() {
    local content="$1"
    local subject="${2:-}"
    local sender="${3:-}"
    
    # Prepare prompt for classification
    local prompt
    prompt=$(cat << 'PROMPT'
You are a message classifier. Analyze the following message and classify it into one or more categories:

Categories:
- BILL: Payment due, invoice, bill notification, payment confirmation, subscription renewal
- APPOINTMENT: Meeting scheduled, calendar invite, appointment confirmation, reservation
- DEADLINE: Due date, task deadline, project milestone, expiration date
- SOCIAL: Personal message from family/friend, social invitation, casual conversation
- WORK: Work-related communication, project updates, client messages
- SPAM: Unwanted marketing, promotional emails, newsletters
- FYI: Informational only, no action needed

For each category detected, extract:
1. Category name
2. Confidence (0-1)
3. Key details (dates, amounts, people, etc.)
4. Suggested action

Respond ONLY in JSON format:
{
  "categories": [
    {"name": "BILL", "confidence": 0.95, "details": {"amount": "$50", "due_date": "2024-01-15"}, "action": "Add to Finnova and calendar"}
  ],
  "priority": "high|medium|low",
  "summary": "Brief description of what this message is about"
}

Message to classify:
Subject: {{SUBJECT}}
From: {{SENDER}}
Content: {{CONTENT}}
PROMPT
)
    
    # Escape content for prompt
    local escaped_content
    escaped_content=$(echo "$content" | sed 's/"/\\"/g' | tr '\n' ' ' | head -c 2000)
    local escaped_subject
    escaped_subject=$(echo "$subject" | sed 's/"/\\"/g')
    local escaped_sender
    escaped_sender=$(echo "$sender" | sed 's/"/\\"/g')
    
    # Replace placeholders
    prompt="${prompt//\{\{CONTENT\}\}/$escaped_content}"
    prompt="${prompt//\{\{SUBJECT\}\}/$escaped_subject}"
    prompt="${prompt//\{\{SENDER\}\}/$escaped_sender}"
    
    # Call local LLM via Ollama
    local response
    response=$(echo "$prompt" | ollama run "$OLLAMA_MODEL" --format json 2>/dev/null || echo '{"categories":[],"priority":"low","summary":"Classification failed"}')
    
    # Validate JSON response
    if ! echo "$response" | jq -e '.' > /dev/null 2>&1; then
        # Try to extract JSON from response
        response=$(echo "$response" | grep -o '\{.*\}' | tail -1)
        if ! echo "$response" | jq -e '.' > /dev/null 2>&1; then
            response='{"categories":[],"priority":"low","summary":"Invalid response from classifier"}'
        fi
    fi
    
    echo "$response"
}

# ── Process a Single Message ───────────────────────────────────────────────────
process_message() {
    local msg_json="$1"
    local msg_type="$2"  # email or imessage
    
    # Extract message fields
    local msg_id subject sender content date
    msg_id=$(echo "$msg_json" | jq -r '.id // .messageId // empty')
    subject=$(echo "$msg_json" | jq -r '.subject // .text // ""')
    sender=$(echo "$msg_json" | jq -r '.sender // .from // "Unknown"')
    content=$(echo "$msg_json" | jq -r '.content // .body // .text // ""')
    date=$(echo "$msg_json" | jq -r '.date // .timestamp // ""')
    
    # Check if already processed
    if is_processed "$msg_id"; then
        log_info "Skipping already processed message: $msg_id"
        return 0
    fi
    
    log_info "Processing $msg_type from $sender: ${subject:0:50}..."
    
    # Classify the message
    local classification
    classification=$(classify_message "$content" "$subject" "$sender")
    
    log_info "Classification: $(echo "$classification" | jq -r '.summary // "No summary"')"
    
    # Extract categories and process each
    local categories
    categories=$(echo "$classification" | jq -c '.categories[]' 2>/dev/null)
    
    while IFS= read -r category; do
        [[ -z "$category" ]] && continue
        
        local cat_name confidence
        cat_name=$(echo "$category" | jq -r '.name // empty')
        confidence=$(echo "$category" | jq -r '.confidence // 0')
        
        # Only process high-confidence classifications
        if [[ "$(echo "$confidence > 0.7" | bc -l)" == "1" ]]; then
            case "$cat_name" in
                BILL)
                    process_bill "$msg_json" "$category"
                    ((BILLS_FOUND++))
                    ;;
                APPOINTMENT)
                    process_appointment "$msg_json" "$category"
                    ((APPOINTMENTS_FOUND++))
                    ;;
                DEADLINE)
                    process_deadline "$msg_json" "$category"
                    ((DEADLINES_FOUND++))
                    ;;
                SOCIAL|WORK)
                    process_social_work "$msg_json" "$category"
                    ((SOCIAL_FOUND++))
                    ;;
            esac
        fi
    done <<< "$categories"
    
    # Mark as processed
    mark_processed "$msg_id"
    
    # Log the action
    log_action "$msg_type" "$sender" "$subject" "$classification"
}

# ── Process a Bill ─────────────────────────────────────────────────────────────
process_bill() {
    local msg_json="$1"
    local category="$2"
    
    local subject sender content details
    subject=$(echo "$msg_json" | jq -r '.subject // "Bill"')
    sender=$(echo "$msg_json" | jq -r '.sender // "Unknown"')
    content=$(echo "$msg_json" | jq -r '.content // ""')
    details=$(echo "$category" | jq -r '.details // {}')
    
    local amount due_date
    amount=$(echo "$details" | jq -r '.amount // "Unknown"')
    due_date=$(echo "$details" | jq -r '.due_date // ""')
    
    log_info "Processing BILL: $subject, Amount: $amount, Due: $due_date"
    
    # Add to Finnova (if API available)
    add_to_finnova "$subject" "$amount" "$due_date" "$sender"
    
    # Add calendar reminder
    if [[ -n "$due_date" ]]; then
        add_calendar_reminder "$subject" "$due_date" "Bill due: $amount from $sender"
    fi
    
    # Track action
    ACTIONS_TAKEN+=("💰 Bill added: $subject ($amount)")
}

# ── Process an Appointment ─────────────────────────────────────────────────────
process_appointment() {
    local msg_json="$1"
    local category="$2"
    
    local subject sender content details
    subject=$(echo "$msg_json" | jq -r '.subject // "Appointment"')
    sender=$(echo "$msg_json" | jq -r '.sender // "Unknown"')
    details=$(echo "$category" | jq -r '.details // {}')
    
    local appt_date location
    appt_date=$(echo "$details" | jq -r '.date // .datetime // ""')
    location=$(echo "$details" | jq -r '.location // ""')
    
    log_info "Processing APPOINTMENT: $subject, Date: $appt_date"
    
    # Add to calendar
    if [[ -n "$appt_date" ]]; then
        add_calendar_event "$subject" "$appt_date" "$location" "$sender"
        ACTIONS_TAKEN+=("📅 Appointment added: $subject on $appt_date")
    else
        # Create task to follow up
        add_mission_control_task "Schedule: $subject" "medium" "From: $sender"
        ACTIONS_TAKEN+=("📝 Task created: Schedule appointment - $subject")
    fi
}

# ── Process a Deadline ─────────────────────────────────────────────────────────
process_deadline() {
    local msg_json="$1"
    local category="$2"
    
    local subject sender details
    subject=$(echo "$msg_json" | jq -r '.subject // "Deadline"')
    sender=$(echo "$msg_json" | jq -r '.sender // "Unknown"')
    details=$(echo "$category" | jq -r '.details // {}')
    
    local deadline_date
    deadline_date=$(echo "$details" | jq -r '.due_date // .date // ""')
    
    log_info "Processing DEADLINE: $subject, Due: $deadline_date"
    
    # Add to Mission Control as high priority task
    local priority="high"
    add_mission_control_task "$subject" "$priority" "Deadline from $sender, due: $deadline_date"
    
    ACTIONS_TAKEN+=("⏰ Deadline task: $subject (due $deadline_date)")
}

# ── Process Social/Work Message ────────────────────────────────────────────────
process_social_work() {
    local msg_json="$1"
    local category="$2"
    
    local subject sender cat_name
    subject=$(echo "$msg_json" | jq -r '.subject // "Message"')
    sender=$(echo "$msg_json" | jq -r '.sender // "Unknown"')
    cat_name=$(echo "$category" | jq -r '.name // "UNKNOWN"')
    
    log_info "Processing $cat_name message from $sender"
    
    # Categorize and add to Mission Control for tracking
    local tag
    [[ "$cat_name" == "SOCIAL" ]] && tag="personal" || tag="work"
    
    # Only add important ones to Mission Control
    local priority
    priority=$(echo "$category" | jq -r '.priority // "low"')
    
    if [[ "$priority" == "high" ]]; then
        add_mission_control_task "Follow up: $subject" "$priority" "$cat_name message from $sender" "$tag"
        ACTIONS_TAKEN+=("🏷️ Tagged [$tag]: $subject from $sender")
    fi
}

# ── Add to Finnova ─────────────────────────────────────────────────────────────
add_to_finnova() {
    local description="$1"
    local amount="$2"
    local due_date="$3"
    local vendor="$4"
    
    # Check if Finnova API is configured
    local finnova_creds="$HOME/.openclaw/credentials/finnova.json"
    
    if [[ -f "$finnova_creds" ]]; then
        # API integration would go here
        log_info "Adding to Finnova: $description - $amount"
        
        # For now, log to a file that can be imported
        local finnova_queue="$DATA_DIR/finnova_queue.jsonl"
        printf '{"timestamp":"%s","description":"%s","amount":"%s","due_date":"%s","vendor":"%s"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$description" "$amount" "$due_date" "$vendor" >> "$finnova_queue"
    else
        # Queue for manual import
        log_warn "Finnova credentials not found. Queuing for manual import."
        local finnova_queue="$DATA_DIR/finnova_queue.jsonl"
        printf '{"timestamp":"%s","description":"%s","amount":"%s","due_date":"%s","vendor":"%s","status":"pending"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$description" "$amount" "$due_date" "$vendor" >> "$finnova_queue"
    fi
}

# ── Add Calendar Reminder ──────────────────────────────────────────────────────
add_calendar_reminder() {
    local title="$1"
    local date_str="$2"
    local notes="$3"
    
    log_info "Adding calendar reminder: $title on $date_str"
    
    # Try to parse the date
    local parsed_date
    parsed_date=$(date -j -f '%Y-%m-%d' "$date_str" '+%Y-%m-%d' 2>/dev/null || \
                  date -j -f '%d/%m/%Y' "$date_str" '+%Y-%m-%d' 2>/dev/null || \
                  echo "$date_str")
    
    # Use AppleScript to add to Calendar.app
    osascript << APPLESCRIPT 2>/dev/null
        tell application "Calendar"
            tell calendar "Home"
                make new event with properties {summary:"💰 $title", start date:date "$parsed_date", description:"$notes", allday event:true}
            end tell
        end tell
APPLESCRIPT
    
    # Also try Exchange calendar if available
    if [[ -f "$HOME/.openclaw/credentials/ms-graph.json" ]]; then
        "$HOME/.openclaw/scripts/exchange_calendar.sh" create "$title" "$parsed_date" "$parsed_date" "" "$notes" 2>/dev/null || true
    fi
}

# ── Add Calendar Event ─────────────────────────────────────────────────────────
add_calendar_event() {
    local title="$1"
    local date_str="$2"
    local location="${3:-}"
    local notes="${4:-}"
    
    log_info "Adding calendar event: $title on $date_str"
    
    # Parse date - handle various formats
    local start_date end_date
    
    # Try ISO format first
    if [[ "$date_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2} ]]; then
        start_date="$date_str"
        # Add 1 hour for end time
        end_date=$(date -j -v+1H -f '%Y-%m-%dT%H:%M:%S' "${date_str:0:19}" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "$date_str")
    else
        # Assume all-day event
        start_date="$date_str"
        end_date="$date_str"
    fi
    
    # Use AppleScript to add to Calendar.app
    osascript << APPLESCRIPT 2>/dev/null
        tell application "Calendar"
            tell calendar "Home"
                make new event with properties {summary:"📅 $title", start date:date "$start_date", end date:date "$end_date", location:"$location", description:"$notes"}
            end tell
        end tell
APPLESCRIPT
}

# ── Add Mission Control Task ───────────────────────────────────────────────────
add_mission_control_task() {
    local title="$1"
    local priority="${2:-medium}"
    local description="${3:-}"
    local tags="${4:-}"
    
    log_info "Adding Mission Control task: $title (priority: $priority)"
    
    local state_file="$STATE_DIR/state.json"
    local task_id
    task_id="TASK-$(date +%s)-$RANDOM"
    
    # Read current state and add task
    if [[ -f "$state_file" ]]; then
        local tmp_file
        tmp_file=$(mktemp)
        
        cat "$state_file" | python3 << PYEOF
import json, sys, datetime

try:
    state = json.load(sys.stdin)
except:
    state = {"tasks": []}

task = {
    "id": "$task_id",
    "title": "$title",
    "description": "$description",
    "status": "todo",
    "priority": "$priority",
    "tags": "$tags".split(",") if "$tags" else [],
    "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source": "message-processor"
}

state.setdefault("tasks", []).insert(0, task)

with open("$tmp_file", "w") as f:
    json.dump(state, f, indent=2)
PYEOF
        
        mv "$tmp_file" "$state_file"
    fi
}

# ── Update Mission Control State ───────────────────────────────────────────────
update_mission_control_state() {
    local state_file="$STATE_DIR/state.json"
    
    if [[ -f "$state_file" ]]; then
        local tmp_file
        tmp_file=$(mktemp)
        
        cat "$state_file" | python3 << PYEOF
import json, sys, datetime

try:
    state = json.load(sys.stdin)
except:
    state = {}

# Add activity entry
activity = {
    "type": "MESSAGE_PROCESSOR",
    "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "description": f"Processed messages: $BILLS_FOUND bills, $APPOINTMENTS_FOUND appointments, $DEADLINES_FOUND deadlines",
    "icon": "📨",
    "bills": $BILLS_FOUND,
    "appointments": $APPOINTMENTS_FOUND,
    "deadlines": $DEADLINES_FOUND,
    "social": $SOCIAL_FOUND
}

state.setdefault("activity", []).insert(0, activity)
state["activity"] = state["activity"][:100]  # Keep last 100

with open("$tmp_file", "w") as f:
    json.dump(state, f, indent=2)
PYEOF
        
        mv "$tmp_file" "$state_file"
    fi
}

# ── Send Telegram Summary ──────────────────────────────────────────────────────
send_telegram_summary() {
    local total_actions=$((BILLS_FOUND + APPOINTMENTS_FOUND + DEADLINES_FOUND + SOCIAL_FOUND))
    
    if [[ $total_actions -eq 0 ]]; then
        log_info "No actions taken. Skipping Telegram notification."
        return 0
    fi
    
    # Build message
    local message="📨 <b>Message Processor Summary</b>

"
    message+="<b>Actions taken in last 15 minutes:</b>

"
    
    if [[ $BILLS_FOUND -gt 0 ]]; then
        message+="💰 <b>Bills:</b> $BILLS_FOUND
"
    fi
    
    if [[ $APPOINTMENTS_FOUND -gt 0 ]]; then
        message+="📅 <b>Appointments:</b> $APPOINTMENTS_FOUND
"
    fi
    
    if [[ $DEADLINES_FOUND -gt 0 ]]; then
        message+="⏰ <b>Deadlines:</b> $DEADLINES_FOUND
"
    fi
    
    if [[ $SOCIAL_FOUND -gt 0 ]]; then
        message+="🏷️ <b>Social/Work tagged:</b> $SOCIAL_FOUND
"
    fi
    
    message+="
<b>Details:</b>
"
    
    for action in "${ACTIONS_TAKEN[@]}"; do
        message+="• $action
"
    done
    
    message+="
<i>Processed at $(date '+%H:%M')</i>"
    
    # Send via Telegram
    if [[ -n "$TELEGRAM_BOT_TOKEN" ]]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d "chat_id=$TELEGRAM_CHAT_ID" \
            -d "parse_mode=HTML" \
            -d "text=$message" > /dev/null 2>&1
        log_info "Telegram notification sent"
    else
        # Log the message that would have been sent
        log_info "Telegram notification (bot token not configured):"
        log_info "$message"
    fi
}

# ── Log Action ─────────────────────────────────────────────────────────────────
log_action() {
    local msg_type="$1"
    local sender="$2"
    local subject="$3"
    local classification="$4"
    
    local action_log="$DATA_DIR/actions.jsonl"
    
    printf '{"timestamp":"%s","type":"%s","sender":"%s","subject":"%s","classification":%s}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$msg_type" "$sender" "$subject" "$classification" >> "$action_log"
}
