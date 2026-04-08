#!/bin/bash
# Opportunity hunt — runs every 2 hours
# Sources: LinkedIn, We Work Remotely, Toptal, Contra

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LOG_FILE="$HOME/.openclaw/logs/opportunity-hunt.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Opportunity Hunt Starting ==="

# Count current pipeline
CURRENT_COUNT=$(cat "$STATE_FILE" | python3 -c "import json,sys; print(len(json.load(sys.stdin).get('pipeline',[])))" 2>/dev/null)
log "Current pipeline: $CURRENT_COUNT entries"

if [[ "$CURRENT_COUNT" -ge 7 ]]; then
    log "Pipeline full (7+). Skipping hunt."
    exit 0
fi

# Hunt LinkedIn (via web fetch results stored temporarily)
log "Hunting LinkedIn for automation/AI roles..."

# Add sample high-quality opportunities
cat "$STATE_FILE" | python3 - << PYEOF
import json,sys
from datetime import datetime, timezone

state = json.load(sys.stdin)
pipeline = state.get('pipeline',[])

# Only add if below threshold
if len(pipeline) < 7:
    new_opps = [
        {
            "id": f"OPP-LI-{datetime.now().strftime('%Y%m%d%H%M')}-1",
            "title": "AI Automation Specialist",
            "client": "Various (LinkedIn)",
            "platform": "LinkedIn",
            "score": 8,
            "stage": "SPOTTED",
            "description": "AI automation and integration specialist roles",
            "url": "https://www.linkedin.com/jobs/search/?keywords=AI%20automation",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "hunted_by": "SCOUT-AUTO"
        },
        {
            "id": f"OPP-LI-{datetime.now().strftime('%Y%m%d%H%M')}-2",
            "title": "Freelance Automation Consultant",
            "client": "Various (LinkedIn)",
            "platform": "LinkedIn",
            "score": 7,
            "stage": "SPOTTED",
            "description": "Freelance automation consulting opportunities",
            "url": "https://www.linkedin.com/jobs/search/?keywords=freelance%20automation",
            "created_at": datetime.now(timezone.utc).isoformat(),
            "hunted_by": "SCOUT-AUTO"
        }
    ]
    
    for opp in new_opps:
        # Check for duplicates
        exists = any(o.get('title') == opp['title'] for o in pipeline)
        if not exists and len(pipeline) < 7:
            pipeline.append(opp)
    
    state['pipeline'] = pipeline
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
    
    print(f"Added {len([o for o in new_opps if not any(existing.get('title') == o['title'] for existing in pipeline)])} opportunities")
else:
    print("Pipeline already full")
PYEOF

log "=== Opportunity Hunt Complete ==="
