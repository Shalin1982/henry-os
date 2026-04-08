#!/bin/bash
# Token Monitor - Automatic Model Fallback System
# Runs every 5 minutes, checks token usage, switches models if needed

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LOG_FILE="$HOME/.openclaw/logs/token-monitor.log"

# Thresholds
WARNING=40000
CRITICAL=60000
EMERGENCY=80000

# Ensure log directory exists
mkdir -p "$HOME/.openclaw/logs"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Get current token count
get_tokens() {
    if [ -f "$STATE_FILE" ]; then
        python3 -c "
import json
import sys
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    print(state.get('system', {}).get('tokens_today', 0))
except:
    print(0)
"
    else
        echo 0
    fi
}

# Update model in state
update_model() {
    local model=$1
    python3 -c "
import json
import sys

try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    
    if 'system' not in state:
        state['system'] = {}
    
    state['system']['current_model'] = '$model'
    state['system']['model_switched_at'] = '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
    state['system']['model_switch_reason'] = 'token_threshold'
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
    
    print('Model updated to $model')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# Send notification
notify() {
    local title=$1
    local message=$2
    osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
}

# Get actual token usage from session (not state.json)
get_actual_tokens() {
    # Try to get from session status if available
    local session_tokens=$(openclaw status 2>/dev/null | grep -o 'Tokens: [0-9]*k in' | grep -o '[0-9]*' || echo "0")
    if [ "$session_tokens" != "0" ]; then
        echo $((session_tokens * 1000))
    else
        # Fallback to state.json
        get_tokens
    fi
}

# Main monitoring logic
TOKENS=$(get_actual_tokens)
log "Current tokens: $TOKENS"

# Get current model from session
CURRENT_MODEL=$(openclaw status 2>/dev/null | grep -o 'Model: [^ ]*' | cut -d' ' -f2 || echo "unknown")
log "Current model: $CURRENT_MODEL"

if [ "$TOKENS" -gt "$EMERGENCY" ]; then
    log "EMERGENCY: Token usage at $TOKENS"
    if [[ "$CURRENT_MODEL" != *"ollama"* ]]; then
        log "Would switch to local-ollama, but automatic model switching requires session restart"
        notify "Henry OS - Emergency Mode" "Token usage critical ($TOKENS). Consider switching to Ollama."
        update_model "local-ollama (pending)"
    fi
elif [ "$TOKENS" -gt "$CRITICAL" ]; then
    log "CRITICAL: Token usage at $TOKENS"
    if [[ "$CURRENT_MODEL" == *"claude"* ]] || [[ "$CURRENT_MODEL" == *"gpt-4"* ]]; then
        log "Would downgrade to kimi-k2.5, but automatic model switching requires session restart"
        notify "Henry OS - Cost Saving Mode" "Token usage high ($TOKENS). Consider switching to kimi-k2.5."
        update_model "kimi-k2.5 (pending)"
    fi
elif [ "$TOKENS" -gt "$WARNING" ]; then
    log "WARNING: Token usage at $TOKENS, approaching limit"
    # Just log, don't switch yet
fi

# Clean old log entries (keep last 1000 lines)
if [ -f "$LOG_FILE" ]; then
    tail -n 1000 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
fi
