#!/bin/bash
# Agent Orchestrator - Autonomous sub-agent management
# Spawns, monitors, and directs sub-agents without human prompting

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LOG_FILE="$HOME/.openclaw/logs/agent-orchestrator.log"
AGENTS_DIR="$HOME/.openclaw/agents"

# Agent definitions with autonomous behaviors
AGENTS=(
    "SCOUT:market:3600:Scrape X/Reddit/LinkedIn for opportunities:opportunity-hunt"
    "BUILDER:code:1800:Work on Finnova app build:finnova-build"
    "CONTENT:content:7200:Create marketing content:content-creation"
    "RESEARCH:research:3600:Deep research on active projects:research-tasks"
)

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if agent should run (based on last run time)
should_run() {
    local agent_name=$1
    local interval=$2
    
    local last_run=$(python3 -c "
import json
import sys
try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    agents = state.get('agents', [])
    for a in agents:
        if a.get('name') == '$agent_name':
            print(a.get('last_run', 0))
            sys.exit(0)
    print(0)
except:
    print(0)
")
    
    local now=$(date +%s)
    local elapsed=$((now - last_run))
    
    if [ $elapsed -gt $interval ]; then
        return 0
    else
        return 1
    fi
}

# Spawn an agent
spawn_agent() {
    local name=$1
    local type=$2
    local task=$3
    local task_id=$4
    
    log "Spawning $name for $task"
    
    # Create agent workspace
    mkdir -p "$AGENTS_DIR/$name"
    
    # Write agent SOUL file
    cat > "$AGENTS_DIR/$name/SOUL.md" << EOF
# $name - Autonomous Agent

## Identity
Name: $name
Type: $type
Task: $task
Created: $(date)

## Autonomous Behavior
- Work on assigned tasks without prompting
- Report progress every 15 minutes
- Escalate blockers immediately
- Complete tasks or hand off cleanly

## Current Task
$task_id: $task

## Rules
1. Never wait for human input
2. Use available tools aggressively
3. Document everything
4. Fail fast, report clearly
EOF
    
    # Update state
    python3 -c "
import json
import sys
from datetime import datetime

try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    
    if 'agents' not in state:
        state['agents'] = []
    
    # Update or add agent
    agent_found = False
    for a in state['agents']:
        if a.get('name') == '$name':
            a['status'] = 'running'
            a['task'] = '$task'
            a['started_at'] = datetime.now().isoformat()
            agent_found = True
            break
    
    if not agent_found:
        state['agents'].append({
            'name': '$name',
            'type': '$type',
            'status': 'running',
            'task': '$task',
            'started_at': datetime.now().isoformat(),
            'last_run': 0
        })
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
    
    print('Agent $name spawned')
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
"
    
    # Trigger agent via OpenClaw API (if available)
    # This would spawn an actual OpenClaw session for the agent
    log "Agent $name ready to work"
}

# Check agent health
health_check() {
    python3 -c "
import json
import sys
from datetime import datetime, timedelta

try:
    with open('$STATE_FILE', 'r') as f:
        state = json.load(f)
    
    agents = state.get('agents', [])
    for a in agents:
        if a.get('status') == 'running':
            started = a.get('started_at', '')
            if started:
                try:
                    start_time = datetime.fromisoformat(started)
                    if datetime.now() - start_time > timedelta(hours=2):
                        print(f\"STALLED: {a['name']} - running too long\")
                except:
                    pass
except:
    pass
"
}

# Main orchestration loop
log "Agent Orchestrator starting..."

for agent_def in "${AGENTS[@]}"; do
    IFS=':' read -r name type interval task task_id <<< "$agent_def"
    
    if should_run "$name" "$interval"; then
        log "$name ready to run (interval: ${interval}s)"
        spawn_agent "$name" "$type" "$task" "$task_id"
    else
        log "$name not ready yet"
    fi
done

# Health check
health_check

log "Orchestrator cycle complete"
