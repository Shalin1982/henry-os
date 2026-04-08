#!/bin/bash
# SSH Remote Control Tunnel
# Usage: Email subject "HENRY: [command]" to your dedicated email
# This script polls that email and executes commands

EMAIL_ACCOUNT="henry-remote@yourdomain.com"  # Configure this
POLL_INTERVAL=60  # seconds
LOG_FILE="~/.openclaw/remote-control.log"
ALLOWED_SENDERS=("shannon@yourdomain.com")  # Whitelist

# Security: Only allow specific safe commands
ALLOWED_COMMANDS=("status" "tasks" "agents" "approve" "reject" "deploy" "logs")

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

execute_command() {
    local cmd="$1"
    local sender="$2"
    
    log "Executing '$cmd' from $sender"
    
    case "$cmd" in
        "status")
            curl -s http://localhost:3333/api/data?type=stats
            ;;
        "tasks")
            cat ~/.openclaw/mission-control/state.json | jq '.tasks'
            ;;
        "agents")
            echo "Active agents:"
            ls ~/.openclaw/agents/
            ;;
        "approve"*)
            # Extract approval ID
            local id=$(echo "$cmd" | cut -d' ' -f2)
            curl -X POST http://localhost:3333/api/approvals/$id/approve
            ;;
        "deploy")
            cd ~/.openclaw/mission-control-unified && npm run build
            ;;
        "logs")
            tail -50 ~/.openclaw/logs/henry.log
            ;;
        *)
            echo "Unknown command: $cmd"
            ;;
    esac
}

# Main loop
while true; do
    # Check email via IMAP (requires himalaya or similar)
    # This is a placeholder - actual implementation needs email client
    
    # Example with himalaya:
    # himalaya list --folder INBOX --query "SUBJECT 'HENRY:'" | while read msg; do
    #     sender=$(echo "$msg" | extract_sender)
    #     subject=$(echo "$msg" | extract_subject)
    #     cmd=$(echo "$subject" | sed 's/HENRY: //')
    #     
    #     if [[ " ${ALLOWED_SENDERS[@]} " =~ " ${sender} " ]]; then
    #         result=$(execute_command "$cmd" "$sender")
    #         # Send result back
    #         echo "$result" | himalaya send --to "$sender" --subject "HENRY RESULT: $cmd"
    #     fi
    # done
    
    sleep $POLL_INTERVAL
done
