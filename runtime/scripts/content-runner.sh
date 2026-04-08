#!/bin/bash
# CONTENT - Social Media & Content Agent
# Drafts tweets, LinkedIn posts, YouTube scripts

AGENT_NAME="CONTENT"
WORKSPACE="$HOME/.openclaw"
AGENT_DIR="$WORKSPACE/agents/$AGENT_NAME"
INPUT_DIR="$AGENT_DIR/input"
OUTPUT_DIR="$AGENT_DIR/output"
APPROVAL_QUEUE="$AGENT_DIR/approval-queue"

mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$APPROVAL_QUEUE"

log() {
    echo "[$(date '+%H:%M:%S')] CONTENT: $1" >> "$AGENT_DIR/agent.log"
}

update_heartbeat() {
    echo '{"timestamp":'$(date +%s)',"status":"working","task":"'$1'"}' > "$AGENT_DIR/heartbeat.json"
}

# Function to draft tweet
draft_tweet() {
    local topic=$1
    local output_file="$OUTPUT_DIR/tweet-$(date +%s).json"
    
    cat > "$output_file" << EOF
{
  "platform": "twitter",
  "content": "Exploring the future of AI agents and autonomous operations. What if your computer could actually work for you while you sleep? 🤖\n\n#AI #Automation #OpenClaw",
  "topic": "$topic",
  "status": "pending_approval",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "CONTENT"
}
EOF
    
    # Add to approval queue
    ln -sf "$output_file" "$APPROVAL_QUEUE/$(basename $output_file)"
    log "Drafted tweet: $output_file"
}

# Function to draft LinkedIn post
draft_linkedin() {
    local topic=$1
    local output_file="$OUTPUT_DIR/linkedin-$(date +%s).json"
    
    cat > "$output_file" << EOF
{
  "platform": "linkedin",
  "content": "I've been experimenting with AI agents that can actually run parts of my business autonomously.\n\nNot chatbots. Not assistants. Actual agents that:\n\n→ Monitor markets 24/7\n→ Draft content for approval\n→ Write code and submit PRs\n→ Track finances and flag opportunities\n\nThe future isn't AI tools.\nThe future is AI employees.\n\nWhat would you delegate to an AI agent?",
  "topic": "$topic",
  "status": "pending_approval",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "CONTENT"
}
EOF
    
    ln -sf "$output_file" "$APPROVAL_QUEUE/$(basename $output_file)"
    log "Drafted LinkedIn post: $output_file"
}

# Main CONTENT loop
log "CONTENT starting up..."

while true; do
    log "Checking for research input..."
    update_heartbeat "checking_input"
    
    # Check for research digests
    for digest in "$INPUT_DIR"/digest-*.md; do
        if [ -f "$digest" ]; then
            log "Found research digest: $digest"
            update_heartbeat "drafting_content"
            
            # Draft content based on research
            draft_tweet "AI agents"
            draft_linkedin "AI automation"
            
            # Move processed digest
            mv "$digest" "$AGENT_DIR/memory/"
            log "Processed digest"
        fi
    done
    
    # If no input, create evergreen content
    if [ ! "$(ls -A $INPUT_DIR 2>/dev/null)" ]; then
        log "No new research, creating evergreen content"
        update_heartbeat "creating_evergreen"
        
        # Draft periodic content
        if [ $(($(date +%s) % 86400)) -lt 3600 ]; then  # Once per day
            draft_tweet "daily"
        fi
    fi
    
    # Update Mission Control with queue status
    QUEUE_COUNT=$(ls -1 "$APPROVAL_QUEUE" 2>/dev/null | wc -l)
    log "Approval queue: $QUEUE_COUNT items pending"
    
    # Update state
    python3 << PYEOF
import json

try:
    with open('$WORKSPACE/mission-control/state.json', 'r') as f:
        state = json.load(f)
    
    if 'approvals' not in state:
        state['approvals'] = {}
    
    state['approvals']['content'] = {
        'pending': $QUEUE_COUNT,
        'last_update': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
    }
    
    with open('$WORKSPACE/mission-control/state.json', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"Error: {e}")
PYEOF
    
    log "Cycle complete. Sleeping..."
    update_heartbeat "idle"
    
    # Check every 15 minutes
    sleep 900
done
