#!/bin/bash
# Daily Self-Audit — Henry's Continuous Improvement System
# Runs every day at 6 PM AEST
# Generates 5 improvement recommendations based on system analysis

STATE_FILE="$HOME/.openclaw/mission-control/state.json"
LOG_DIR="$HOME/.openclaw/mission-control/logs/audits"
LOG_FILE="$LOG_DIR/audit-$(date +%Y-%m-%d).md"
MEMORY_FILE="$HOME/.openclaw/workspace/memory/$(date +%Y-%m-%d).md"

mkdir -p "$LOG_DIR"

TS=$(date '+%Y-%m-%d %H:%M:%S')

# Start the audit report
cat > "$LOG_FILE" << 'HEADER'
# Henry Self-Audit — DATE_PLACEHOLDER

## System Health Check

HEADER

# Replace date placeholder
sed -i '' "s/DATE_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M')/g" "$LOG_FILE" 2>/dev/null || sed -i "s/DATE_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M')/g" "$LOG_FILE"

# Check system status
python3 >> "$LOG_FILE" << 'PYCODE'
import json, sys
from datetime import datetime, timezone

state_file = "/Users/shannonlinnan/.openclaw/mission-control/state.json"

try:
    with open(state_file) as f:
        state = json.load(f)
    
    sys = state.get('system', {})
    tasks = state.get('tasks', [])
    pipeline = state.get('pipeline', [])
    agents = state.get('agents', [])
    mistakes = state.get('mistakes', [])
    learning = state.get('learning_loop', [])
    
    print(f"- **Status:** {sys.get('status', 'UNKNOWN')}")
    print(f"- **Tokens Today:** {sys.get('tokens_today', 0):,}")
    print(f"- **Token Budget:** {sys.get('token_budget_daily', 100000):,}")
    print(f"- **Token Usage:** {(sys.get('tokens_today', 0) / max(sys.get('token_budget_daily', 100000), 1) * 100):.1f}%")
    print(f"- **Agents Active:** {sys.get('agents_active', 0)} / {sys.get('agents_total', 0)}")
    print(f"- **Last Heartbeat:** {sys.get('last_heartbeat', 'Never')}")
    print()
    
    in_progress = [t for t in tasks if t.get('status') == 'IN_PROGRESS']
    done = [t for t in tasks if t.get('status') == 'DONE']
    blocked = [t for t in tasks if t.get('status') == 'BLOCKED']
    p0 = [t for t in tasks if t.get('priority') == 'P0' and t.get('status') != 'DONE']
    
    print("### Tasks")
    print(f"- **In Progress:** {len(in_progress)}")
    print(f"- **Done:** {len(done)}")
    print(f"- **Blocked:** {len(blocked)}")
    print(f"- **P0 Priorities:** {len(p0)}")
    print()
    
    print("### Pipeline")
    print(f"- **Total Opportunities:** {len(pipeline)}")
    high_score = [p for p in pipeline if p.get('score', 0) >= 8]
    print(f"- **High Score (8+):** {len(high_score)}")
    print()
    
    active_agents = [a for a in agents if a.get('status') in ['ACTIVE', 'RUNNING']]
    print("### Agents")
    print(f"- **Total:** {len(agents)}")
    print(f"- **Active:** {len(active_agents)}")
    print()
    
    print("### Quality")
    print(f"- **Mistakes Logged:** {len(mistakes)}")
    print(f"- **Learning Cycles:** {len(learning)}")
    recurring = [m for m in mistakes if m.get('recurring') or m.get('status') == 'RECURRING']
    print(f"- **Recurring Mistakes:** {len(recurring)}")
    
except Exception as e:
    print(f"Error reading state: {e}")
PYCODE

# Generate recommendations
cat >> "$LOG_FILE" << 'RECS'

---

## 5 Improvement Recommendations

RECS

python3 >> "$LOG_FILE" << 'PYCODE2'
import json
from datetime import datetime, timezone

state_file = "/Users/shannonlinnan/.openclaw/mission-control/state.json"
recommendations = []

try:
    with open(state_file) as f:
        state = json.load(f)
    
    sys = state.get('system', {})
    tasks = state.get('tasks', [])
    pipeline = state.get('pipeline', [])
    agents = state.get('agents', [])
    
    if len(pipeline) < 7:
        recommendations.append({
            'priority': 'HIGH',
            'area': 'Pipeline',
            'issue': f"Only {len(pipeline)} opportunities (target: 7+)",
            'action': 'Increase opportunity hunt frequency. Run hunts every 2 hours.',
            'impact': 'More revenue opportunities'
        })
    
    in_progress = [t for t in tasks if t.get('status') == 'IN_PROGRESS']
    stalled = 0
    for t in in_progress:
        updated = t.get('updated_at') or t.get('created_at')
        if updated:
            try:
                dt = datetime.fromisoformat(updated.replace('Z', '+00:00'))
                hours = (datetime.now(timezone.utc) - dt).total_seconds() / 3600
                if hours > 4:
                    stalled += 1
            except:
                pass
    
    if stalled > 0:
        recommendations.append({
            'priority': 'HIGH',
            'area': 'Task Management',
            'issue': f"{stalled} tasks stalled for >4 hours",
            'action': 'Implement task timeout alerts. Auto-ping after 4h inactivity.',
            'impact': 'Faster task completion'
        })
    
    active = [a for a in agents if a.get('status') in ['ACTIVE', 'RUNNING']]
    if len(active) < 3:
        recommendations.append({
            'priority': 'MEDIUM',
            'area': 'Agent Fleet',
            'issue': f"Only {len(active)} agents active (target: 4-6)",
            'action': 'Spawn more sub-agents for revenue tasks.',
            'impact': 'Higher throughput'
        })
    
    learning = state.get('learning_loop', [])
    if len(learning) == 0:
        recommendations.append({
            'priority': 'HIGH',
            'area': 'Learning System',
            'issue': 'No learning cycles recorded',
            'action': 'Ensure learn.sh runs after every task.',
            'impact': 'Continuous improvement'
        })
    
    tokens = sys.get('tokens_today', 0)
    budget = sys.get('token_budget_daily', 100000)
    if tokens > budget * 0.8:
        recommendations.append({
            'priority': 'MEDIUM',
            'area': 'Cost Control',
            'issue': f"Token usage at {tokens/budget*100:.0f}% of budget",
            'action': 'Switch to cheaper models. Batch non-urgent work.',
            'impact': 'Reduced costs'
        })
    elif len(recommendations) < 5:
        recommendations.append({
            'priority': 'LOW',
            'area': 'Documentation',
            'issue': 'Memory writes may be inconsistent',
            'action': 'Verify memory/YYYY-MM-DD.md is updated.',
            'impact': 'Better continuity'
        })
    
    for i, rec in enumerate(recommendations[:5], 1):
        print(f"### {i}. [{rec['priority']}] {rec['area']}")
        print(f"**Issue:** {rec['issue']}")
        print(f"**Action:** {rec['action']}")
        print(f"**Impact:** {rec['impact']}")
        print()
        
except Exception as e:
    print(f"Error: {e}")
PYCODE2

# Add footer
cat >> "$LOG_FILE" << 'FOOTER'

---

## Action Items for Tomorrow

1. [ ] Review stalled tasks and update status
2. [ ] Run opportunity hunt if pipeline < 7
3. [ ] Verify learning loop is functioning
4. [ ] Check agent activity levels
5. [ ] Update memory files

---

FOOTER

echo "*Audit generated: $(date '+%Y-%m-%d %H:%M:%S')*" >> "$LOG_FILE"
echo "*Next audit: Tomorrow at 18:00*" >> "$LOG_FILE"

# Append to memory
echo "" >> "$MEMORY_FILE"
echo "## Self-Audit: $(date '+%H:%M')" >> "$MEMORY_FILE"
echo "Full audit: $LOG_FILE" >> "$MEMORY_FILE"

# Log completion
mkdir -p "$HOME/.openclaw/logs"
echo "[$TS] Self-audit complete: $LOG_FILE" >> "$HOME/.openclaw/logs/audit.log"
