#!/bin/bash
# KNOX - Security & Monitoring Agent Runner
# Watches all agents, detects anomalies, enforces boundaries

AGENT_NAME="KNOX"
WORKSPACE="$HOME/.openclaw"
AGENT_DIR="$WORKSPACE/agents/$AGENT_NAME"
LOG_DIR="$AGENT_DIR/memory/health-logs"
INCIDENT_DIR="$AGENT_DIR/memory/incidents"

mkdir -p "$LOG_DIR" "$INCIDENT_DIR"

AGENTS=("SCOUT" "BUILDER" "CONTENT" "RESEARCH" "AXEL" "KNOX")

log() {
    echo "[$(date '+%H:%M:%S')] KNOX: $1" | tee -a "$AGENT_DIR/agent.log"
}

update_heartbeat() {
    echo '{"timestamp":'$(date +%s)',"status":"working","task":"'$1'"}' > "$AGENT_DIR/heartbeat.json"
}

# Function to check agent heartbeat
check_agent_health() {
    local agent=$1
    local heartbeat_file="$WORKSPACE/agents/$agent/heartbeat.json"
    local log_file="$WORKSPACE/agents/$agent/agent.log"
    
    if [ ! -f "$heartbeat_file" ]; then
        echo "MISSING:$agent:No heartbeat file"
        return 2
    fi
    
    local last_beat=$(cat "$heartbeat_file" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('timestamp',0))" 2>/dev/null || echo "0")
    local current_time=$(date +%s)
    local diff=$((current_time - last_beat))
    local status=$(cat "$heartbeat_file" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('status','unknown'))" 2>/dev/null || echo "unknown")
    
    # Check for repetition in logs (scope creep indicator)
    local repetition_count=0
    if [ -f "$log_file" ]; then
        repetition_count=$(tail -100 "$log_file" 2>/dev/null | grep -c "$(tail -5 "$log_file" 2>/dev/null | head -1)" || echo "0")
    fi
    
    if [ $diff -lt 300 ]; then  # 5 minutes
        if [ "$repetition_count" -gt 10 ]; then
            echo "WARNING:$agent:Possible loop detected ($repetition_count similar entries)"
            return 1
        fi
        echo "HEALTHY:$agent:$status (${diff}s ago)"
        return 0
    elif [ $diff -lt 900 ]; then  # 15 minutes
        echo "SLOW:$agent:$status (${diff}s ago)"
        return 1
    else
        echo "MISSING:$agent:No heartbeat for ${diff}s"
        return 2
    fi
}

# Function to check cost anomalies
check_cost_anomaly() {
    # Check if token usage is spiking
    if [ -f "$WORKSPACE/mission-control/state.json" ]; then
        local cost_data=$(cat "$WORKSPACE/mission-control/state.json" | python3 -c "
import json, sys
try:
    state = json.load(sys.stdin)
    costs = state.get('costs', {})
    today = costs.get('today_aud', 0)
    print(f'{today}')
except:
    print('0')
" 2>/dev/null)
        
        # Alert if daily cost > $50 AUD
        if [ -n "$cost_data" ] && [ "${cost_data%.*}" -gt 50 ]; then
            echo "ALERT:High daily cost: \$$cost_data AUD"
            return 1
        fi
    fi
    echo "OK:Cost normal"
    return 0
}

# Function to generate health report
generate_health_report() {
    local report_file="$LOG_DIR/health-$(date +%Y%m%d-%H%M).json"
    
    local healthy=0
    local warning=0
    local missing=0
    
    local report='{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","agents":['
    local first=true
    
    for agent in "${AGENTS[@]}"; do
        result=$(check_agent_health "$agent")
        status_code=$?
        
        if [ "$first" = true ]; then
            first=false
        else
            report+=","
        fi
        
        agent_status=$(echo "$result" | cut -d: -f1)
        agent_name=$(echo "$result" | cut -d: -f2)
        agent_detail=$(echo "$result" | cut -d: -f3-)
        
        report+='{"name":"'$agent_name'","status":"'$agent_status'","detail":"'$agent_detail'"}'
        
        case $agent_status in
            "HEALTHY") ((healthy++)) ;;
            "WARNING") ((warning++)) ;;
            "MISSING") ((missing++)) ;;
        esac
    done
    
    report+='],"summary":{"healthy":'$healthy',"warning":'$warning',"missing":'$missing'}}'
    
    echo "$report" > "$report_file"
    
    # Update Mission Control
    echo "$report" > "$WORKSPACE/mission-control/agent-status.json"
    
    log "Health report: $healthy healthy, $warning warning, $missing missing"
    
    # Alert if issues detected
    if [ $warning -gt 0 ] || [ $missing -gt 0 ]; then
        log "⚠️ ALERT: $warning warnings, $missing missing agents"
        
        # Create incident report
        echo "$report" > "$INCIDENT_DIR/incident-$(date +%s).json"
    fi
}

# Main KNOX loop
log "KNOX Security Officer starting up..."
log "Monitoring agents: ${AGENTS[*]}"

CYCLE=0

while true; do
    ((CYCLE++))
    
    update_heartbeat "monitoring"
    
    # Every cycle: Quick health check
    if [ $((CYCLE % 1)) -eq 0 ]; then
        generate_health_report
    fi
    
    # Every 3 cycles (15 min): Cost check
    if [ $((CYCLE % 3)) -eq 0 ]; then
        update_heartbeat "cost_check"
        cost_result=$(check_cost_anomaly)
        if [[ "$cost_result" == *"ALERT"* ]]; then
            log "🚨 $cost_result"
        fi
    fi
    
    # Every 12 cycles (1 hour): Full audit
    if [ $((CYCLE % 12)) -eq 0 ]; then
        update_heartbeat "full_audit"
        log "Running full security audit..."
        # Additional audit logic here
    fi
    
    update_heartbeat "idle"
    
    # Check every 5 minutes
    sleep 300
done
