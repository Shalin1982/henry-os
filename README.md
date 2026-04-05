# Henry OS

**AI Chief of Staff Framework — One-Line Installer**

Deploy a complete, production-ready AI chief of staff in under 5 minutes on any Mac, Windows, or Linux machine.

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://henryos.ai)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)](https://henryos.ai)

---

## What is Henry OS?

Henry OS packages everything you need to run an autonomous AI agent team:

- **7 specialized agents** — Henry (Chief of Staff), Nexus (CTO), Ivy (Research), Knox (Security), Mr-X (Social), Wolf (Finance), Ragnar (Business Dev)
- **Mission Control dashboard** — 16-page operational dashboard with real-time data
- **Proactive intelligence** — Anomaly detection, opportunity radar, automated briefings
- **Revenue engine** — Proposal automation, pipeline management, win/loss tracking
- **Voice & mobile** — Voice memo processing, audio briefs, mobile quick commands
- **Deep context awareness** — Owner profile, goals framework, relationship CRM
- **Learning architecture** — Mistake logging, weekly reviews, continuous improvement
- **Security hardening** — CVE patches, localhost binding, approval gates
- **Resurrection protocol** — Daily backups, 25-minute restore from any failure

**Typical cost: $3-8/month in API fees** (vs $100-700/month for unoptimised setups)

---

## Quick Start

### macOS / Linux

```bash
curl -fsSL https://henryos.ai/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://henryos.ai/install.ps1 | iex
```

The installer will:
1. Detect your OS and install prerequisites
2. Install OpenClaw (the agent runtime)
3. Download Henry OS configuration files
4. Set up Mission Control dashboard
5. Run a 10-question onboarding wizard
6. Start all services
7. Open Mission Control in your browser

**Total time: Under 5 minutes**

---

## What's Included

### Core Architecture

```
~/.openclaw/
├── workspace/
│   ├── SOUL.md           # Agent identity and operating rules
│   ├── HEARTBEAT.md      # Standing tasks and cron schedule
│   ├── GOALS.md          # Your 90-day goals and decision framework
│   ├── USER.md           # Your profile and preferences
│   ├── MISTAKES.md       # Error log with prevention rules
│   ├── CONTACTS.md       # Relationship CRM
│   └── HENRYOS-BRIEF.md  # Complete product documentation
├── mission-control/
│   └── state.json        # Real-time state database
├── config.yml            # OpenClaw configuration
└── scripts/
    └── backup.sh         # Daily backup automation
```

### Mission Control Dashboard

Access at `http://localhost:3001`

**Pages:**
- Dashboard — System health, metrics, activity feed
- Tasks — Kanban board with drag-and-drop
- Projects — Progress tracking, linked tasks
- Calendar — Cron jobs, events, scheduling
- Pipeline — Deal flow, proposals, revenue tracking
- Memory — Episodic, semantic, procedural memory
- Documents — File management, search, tagging
- Activity — Complete action log with token costs
- YouTube Studio — Video processing pipeline
- Social Media — Content approvals and scheduling
- Email Inbox — Urgency triage, draft management
- Cost Tracker — Budget monitoring, spend analysis
- Software Factory — Build pipeline, opportunity scoring
- Team — 7-agent status and mission statements
- Logs — Gateway logs, level filtering
- Settings — Budget controls, model assignments
- Learning — Mistakes, learning loop, weekly reviews
- Security — Status, incidents, backup verification
- Contacts — Relationship CRM with decay alerts
- Goals — 90-day, 1-year, 3-year objectives

### Agent Team

| Agent | Role | Primary Function |
|-------|------|------------------|
| **Henry** | Chief of Staff | Orchestrates all agents, manages owner relationship |
| **Nexus** | CTO | Coding, GitHub PRs, Vercel deploys, technical architecture |
| **Ivy** | Research | 24/7 scraping of YouTube, X, Reddit, Hacker News, Product Hunt |
| **Knox** | Security Officer | System health monitoring, anomaly detection, incident response |
| **Mr-X** | Social Media | X and LinkedIn content creation, scheduling, engagement |
| **Wolf** | Finance | Market monitoring, investment tracking, financial analysis |
| **Ragnar** | Business Development | Outreach, opportunity hunting, proposal drafting |

---

## Key Features

### Proactive Intelligence

**Anomaly Detection** (every heartbeat)
- Financial: spend spikes, budget overruns
- Pipeline: stale opportunities, unanswered proposals
- Tasks: stalled work, empty board during work hours
- Communications: unanswered client messages
- System: offline services, agent failures

**Opportunity Radar** (every 6 hours)
- Scrapes Upwork, LinkedIn Jobs for matching opportunities
- Monitors AI platform blogs for relevant news
- Tracks Hacker News, Product Hunt for trends
- Flags network intelligence from LinkedIn contacts

**Automated Briefings**
- Morning Brief (08:00 daily) — priorities, pipeline, inbox, radar
- Evening Wrap (20:00 daily) — completed, open loops, tomorrow
- Weekly Intelligence Report (Sunday) — pipeline summary, market intel, cost analysis

### Autonomous Revenue Engine

**Pre-Approved Autonomy**
- Auto-qualify opportunities (skill match ≥80%, no red flags)
- Auto-draft proposals (score ≥7, based on memory templates)
- Auto-follow-up (day 3 after send, first follow-up only)
- Never auto-send proposals — always requires approval

**Proposal Engine**
- Personalised opening referencing specific job post
- Positioning statement drawn from semantic memory
- Approach outline tailored to their problem
- Social proof from past work
- Rate and timeline (market-calibrated)
- Clear CTA (under 400 words)

### Voice & Mobile

**Voice Memo Pipeline**
- Watch folder: `~/Desktop/Voice-Memos/`
- Transcription: whisper.cpp (local, private)
- Classification: TASK / IDEA / NOTE / INSTRUCTION / QUESTION
- Confirmation via iMessage after processing

**Audio Morning Brief**
- 60-90 second spoken summary
- Generated via macOS TTS
- Saved as MP3 to Desktop

**Mobile Quick Commands** (via iMessage)
- `brief` — today's morning brief
- `status` — current system status
- `pipeline` — pipeline summary
- `spend` — today's token/cost summary
- `wins` — completed tasks this week
- `urgent` — anything requiring attention
- `ideas` — top opportunities spotted
- `add task [description]` — create task immediately

### Security Architecture

**CVE-2026-25253 Patched**
- CVSS 8.8 — 1-click RCE via WebSocket
- Fix: `origin_validation: strict` in config
- Gateway bound to 127.0.0.1 only
- Approved origins: localhost:3001 only

**Hardening Applied**
- Filesystem scope restricted to defined paths
- Skill installation requires source review + owner approval
- All high-risk actions require approval gates
- Prompt injection defence in SOUL.md

**Knox Monitoring** (every 30 mins)
- API spend anomaly detection
- File integrity hashes on critical files
- Agent scope monitoring
- Process monitoring for unexpected connections

### Resurrection Protocol

**Daily Backup** (04:30 AEST)
- GitHub private repo (version controlled)
- iCloud Drive (instant iPhone access)
- GPG-encrypted API keys

**25-Minute Restore**
From complete failure to fully operational Henry.

---

## Pricing

### Free (Open Source Core)
- Basic SOUL.md and agent setup
- Standard Mission Control dashboard
- Community support
- Self-managed updates

### Pro — $29/month
- Automatic updates (improvements pushed overnight)
- Premium SOUL.md configurations
- Industry-specific agent packs
- Priority onboarding support

### Business — $99/month
- Full 7-agent team
- All 20 Mission Control pages
- Revenue pipeline automation
- Proactive intelligence engine
- White-label Mission Control

### Done For You — $500-2000 one-off
- Personal setup and configuration
- Custom SOUL.md for your business
- Custom agent team for your workflows
- 30-day support

---

## Industry-Specific Packs

Each pack includes customised SOUL.md, HEARTBEAT.md, and agent configuration:

- Henry for Real Estate Agents
- Henry for Freelance Developers
- Henry for Content Creators
- Henry for Small Business Owners
- Henry for E-commerce Operators
- Henry for Financial Advisors

---

## Documentation

- [Getting Started Guide](docs/getting-started.md)
- [Configuration Reference](docs/configuration.md)
- [Agent Team Guide](docs/agents.md)
- [Mission Control Manual](docs/mission-control.md)
- [Security Hardening](docs/security.md)
- [API Reference](docs/api.md)
- [Troubleshooting](docs/troubleshooting.md)

---

## Community

- [Discord](https://discord.gg/henryos)
- [GitHub Discussions](https://github.com/shannon-linnan/henry-os/discussions)
- [Twitter/X](https://x.com/henryos)

---

## Contributing

Henry OS is open source. Every improvement made to Henry ships to all users.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Acknowledgements

Built on [OpenClaw](https://openclaw.ai) — the open-source AI agent runtime.

Inspired by [Alex Finn's Mission Control](https://www.youtube.com/watch?v=CxErCGVo-oo) approach to agent orchestration.

---

**Henry OS** — Your AI chief of staff, always working for you.

[Website](https://henryos.ai) · [Documentation](https://docs.henryos.ai) · [GitHub](https://github.com/shannon-linnan/henry-os)
