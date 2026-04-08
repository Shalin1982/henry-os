#!/bin/bash
# Task progression monitor — alerts on stalled tasks

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LOG_FILE="$HOME/.openclaw/logs/task-monitor.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Task Progression Check ==="

# Check for IN_PROGRESS tasks older than 2 hours
cat "$STATE_FILE" | python3 - << PYEOF
import json,sys
from datetime import datetime, timezone

state = json.load(sys.stdin)
tasks = state.get('tasks',[])
now = datetime.now(timezone.utc)

stalled = []
for t in tasks:
    if t.get('status') == 'IN_PROGRESS':
        updated = t.get('updated_at') or t.get('created_at')
        if updated:
            try:
                dt = datetime.fromisoformat(updated.replace('Z','+00:00'))
                hours_ago = (now - dt).total_seconds() / 3600
                if hours_ago > 2:
                    stalled.append({
                        'id': t.get('id'),
                        'title': t.get('title'),
                        'hours': hours_ago,
                        'assigned': t.get('assigned')
                    })
            except:
                pass

if stalled:
    print(f"STALLED_TASKS: {len(stalled)}")
    for s in stalled:
        print(f"  - {s['id']}: {s['title']} ({s['hours']:.1f}h, assigned: {s['assigned']})")
        
        # Add warning to activity feed
        activity = {
            "type": "TASK_STALLED",
            "timestamp": now.isoformat(),
            "description": f"Task {s['id']} stalled for {s['hours']:.1f} hours",
            "icon": "⚠️",
            "task_id": s['id']
        }
        state.setdefault("activity", []).insert(0, activity)
    
    with open('$STATE_FILE', 'w') as f:
        json.dump(state, f, indent=2)
else:
    print("All tasks progressing normally")
PYEOF

log "=== Check Complete ==="
