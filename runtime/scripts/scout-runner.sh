#!/bin/bash
# SCOUT - Market Intelligence Agent Runner
# Discovers freelance opportunities, competitor activity, market trends

AGENT_NAME="SCOUT"
WORKSPACE="$HOME/.openclaw"
AGENT_DIR="$WORKSPACE/agents/$AGENT_NAME"
OUTPUT_DIR="$AGENT_DIR/output"
MEMORY_DIR="$AGENT_DIR/memory"

mkdir -p "$OUTPUT_DIR" "$MEMORY_DIR"

log() {
    echo "[$(date '+%H:%M:%S')] SCOUT: $1" >> "$AGENT_DIR/agent.log"
}

update_heartbeat() {
    echo '{"timestamp":'$(date +%s)',"status":"working","task":"'$1'"}' > "$AGENT_DIR/heartbeat.json"
}

# Main SCOUT loop
log "SCOUT starting up..."

while true; do
    log "Beginning opportunity hunt cycle"
    update_heartbeat "hunting"
    
    # 1. Check Upwork for new opportunities
    log "Scanning Upwork..."
    # Use web search to find recent opportunities
    curl -s "https://www.upwork.com/search/jobs/?q=automation+AI+integration&sort=recency" 2>/dev/null | \
        grep -oE '\$[0-9]+-[0-9]+/hr|\$[0-9]+,?[0-9]* fixed' | head -20 > "$OUTPUT_DIR/upwork-rates.txt"
    
    # 2. Check LinkedIn Jobs
    log "Scanning LinkedIn..."
    # Search for relevant job postings
    curl -s "https://www.linkedin.com/jobs/search/?keywords=AI%20automation" 2>/dev/null | \
        grep -oE 'job-title[^>]*>[^<]+' | head -10 > "$OUTPUT_DIR/linkedin-jobs.txt"
    
    # 3. Check IndieHackers
    log "Scanning IndieHackers..."
    curl -s "https://www.indiehackers.com/group/looking-to-hire" 2>/dev/null | \
        grep -oE 'post-title[^>]*>[^<]+' | head -10 > "$OUTPUT_DIR/indiehackers-posts.txt"
    
    # 4. Analyze and score opportunities
    log "Analyzing opportunities..."
    
    # Create opportunity report
    cat > "$OUTPUT_DIR/opportunities-$(date +%Y%m%d-%H%M).json" << EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "agent": "SCOUT",
  "sources_scanned": ["upwork", "linkedin", "indiehackers"],
  "opportunities_found": $(cat "$OUTPUT_DIR/upwork-rates.txt" "$OUTPUT_DIR/linkedin-jobs.txt" "$OUTPUT_DIR/indiehackers-posts.txt" 2>/dev/null | wc -l),
  "status": "complete"
}
EOF
    
    # 5. Update Mission Control Pipeline
    log "Updating pipeline..."
    
    # Add to state.json if opportunities found
    if [ -s "$OUTPUT_DIR/upwork-rates.txt" ] || [ -s "$OUTPUT_DIR/linkedin-jobs.txt" ]; then
        log "Found opportunities, updating pipeline"
        
        # Create pipeline entry
        python3 << PYEOF
import json
import os

state_file = '$WORKSPACE/mission-control/state.json'

try:
    with open(state_file, 'r') as f:
        state = json.load(f)
    
    if 'pipeline' not in state:
        state['pipeline'] = []
    
    # Add new opportunity
    new_opp = {
        'id': 'scout-$(date +%s)',
        'source': 'SCOUT',
        'title': 'AI Automation Opportunity',
        'value': 'TBD',
        'status': 'discovered',
        'discovered_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
        'requires_review': True
    }
    
    state['pipeline'].append(new_opp)
    
    with open(state_file, 'w') as f:
        json.dump(state, f, indent=2)
        
except Exception as e:
    print(f"Error: {e}")
PYEOF
    fi
    
    log "Cycle complete. Sleeping..."
    update_heartbeat "idle"
    
    # Sleep for 30 minutes
    sleep 1800
done
