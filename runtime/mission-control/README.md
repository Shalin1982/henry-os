# Mission Control

Personal command center for monitoring and managing Henry.

## Quick Start

```bash
cd ~/.openclaw/mission-control
node server.js
```

Open http://localhost:3333

## Files

- `server.js` — Express server with SSE endpoint
- `index.html` — Full dashboard (single file, inline CSS/JS)
- `state.json` — Live state storage (read/write by both Henry and dashboard)
- `README.md` — This file

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `` ` `` | Toggle chat panel |
| `H` | Toggle health bar |
| `P` | Toggle privacy mode (blurs sensitive content) |
| `Esc` | Close modal |

## State.json Schema

```json
{
  "system": {
    "uptime_seconds": 0,
    "token_usage": { "used": 0, "quota": 0, "percent": 0, "resets_at": "" },
    "agent_count": 0,
    "active_agents": [],
    "last_learning_loop": "",
    "status": "NOMINAL"
  },
  "tasks": [{
    "id": "",
    "title": "",
    "description": "",
    "priority": "P1",
    "status": "BACKLOG",
    "owner": "",
    "acceptance_criteria": "",
    "history": [],
    "created_at": "",
    "updated_at": ""
  }],
  "memory": {
    "episodic": [{ "id", "timestamp", "task_id", "action", "result", "duration_seconds", "tags": [] }],
    "semantic": [{ "key", "value", "confidence", "updated_at" }],
    "procedural": [{ "name", "version", "steps": [], "source", "updated_at" }],
    "youtube": {}
  },
  "learning_loop": [{ "cycle_id", "task_id", "timestamp", "lessons": [], "rules_changed": [], "provisional": false }],
  "cron": [{ "name", "condition", "last_run", "next_run", "history": [] }],
  "pipeline": [{ "id", "title", "source", "score", "status", "brief", "draft_ready", "created_at", "updated_at" }],
  "approvals": [{ "id", "action", "context", "risk", "recommendation", "status", "decision", "feedback", "timestamp" }],
  "youtube_queue": [{ "url", "status", "domain", "added_at" }],
  "chat_history": [{ "id", "role", "content", "timestamp" }]
}
```

## API Endpoints

- `GET /events` — SSE stream for live updates (broadcasts every 2s)
- `GET /api/state` — Current state
- `POST /api/update` — Update state (deep merge)
- `POST /api/chat` — Send chat message

## How Henry Writes to It

Henry writes all state changes immediately:
- Task updates (status changes, new tasks)
- Memory entries (episodic, semantic, procedural)
- Learning loop cycles
- Pipeline updates
- Approval requests
- Chat history

Dashboard reads via SSE and writes back user decisions.

## Design

- Dark utilitarian aesthetic
- Air traffic control energy
- Monospace fonts (JetBrains Mono, Share Tech Mono)
- Amber/green/red status indicators
- No rounded corners
- Scan-line texture overlay
- Fully local — no external calls, no CDNs

## Notifications

Browser notifications enabled for:
- New approval gates (high urgency)
- Blocked tasks (medium urgency)
- Learning loop completions (low urgency)

## Extending

Add new panels by:
1. Adding data to state.json schema
2. Adding UI section to index.html
3. Adding update handler in index.html `updateDashboard()`
4. Adding write handler in server.js if needed
