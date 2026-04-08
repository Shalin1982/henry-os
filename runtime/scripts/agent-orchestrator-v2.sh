#!/bin/bash
# Agent Orchestrator - Spawns and manages sub-agents
# Runs every 15 minutes via launchd

WORKSPACE="$HOME/.openclaw"
AGENTS_DIR="$WORKSPACE/agents"
LOG_DIR="$WORKSPACE/logs/orchestrator"

mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/orchestrator.log"
}

# Function to check if agent is running
check_agent_running() {
    local agent=$1
    local pid_file="$AGENTS_DIR/$agent/agent.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if ps -p "$pid" > /dev/null 2>&1; then
            return 0  # Running
        fi
    fi
    return 1  # Not running
}

# Function to spawn agent
spawn_agent() {
    local agent=$1
    local agent_dir="$AGENTS_DIR/$agent"
    
    log "Spawning $agent..."
    
    # Create agent workspace
    mkdir -p "$agent_dir/memory" "$agent_dir/tasks" "$agent_dir/output"
    
    # Initialize heartbeat
    echo '{"timestamp":'$(date +%s)',"status":"starting"}' > "$agent_dir/heartbeat.json"
    
    # Spawn agent process based on type
    case $agent in
        "SCOUT")
            nohup bash "$WORKSPACE/scripts/scout-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
        "BUILDER")
            nohup bash "$WORKSPACE/scripts/builder-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
        "CONTENT")
            nohup bash "$WORKSPACE/scripts/content-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
        "RESEARCH")
            nohup bash "$WORKSPACE/scripts/research-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
        "AXEL")
            nohup bash "$WORKSPACE/scripts/axel-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
        "KNOX")
            nohup bash "$WORKSPACE/scripts/knox-runner.sh" > "$agent_dir/agent.log" 2>&1 &
            ;;
    esac
    
    echo $! > "$agent_dir/agent.pid"
    log "$agent spawned with PID $(cat "$agent_dir/agent.pid")"
}

# Function to update agent heartbeat
update_heartbeat() {
    local agent=$1
    local status=$2
    echo '{"timestamp":'$(date +%s)',"status":"'$status'","agent":"'$agent'"}' > "$AGENTS_DIR/$agent/heartbeat.json"
}

# Main orchestration loop
log "=== Orchestrator Starting ==="

AGENTS=("SCOUT" "BUILDER" "CONTENT" "RESEARCH" "AXEL" "KNOX")

for agent in "${AGENTS[@]}"; do
    if check_agent_running "$agent"; then
        log "$agent: Running ✓"
        update_heartbeat "$agent" "active"
    else
        log "$agent: Not running, spawning..."
        spawn_agent "$agent"
        update_heartbeat "$agent" "starting"
    fi
done

# Update Mission Control state
STATE_FILE="$WORKSPACE/mission-control/state.json"
if [ -f "$STATE_FILE" ]; then
    # Update agent count and last check
    python3 << EOF
import json
import sys

try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    
    state['agents'] = {
        'count': 6,
        'last_check': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
        'status': 'active'
    }
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"Error updating state: {e}")
EOF
fi

log "=== Orchestrator Complete ==="
