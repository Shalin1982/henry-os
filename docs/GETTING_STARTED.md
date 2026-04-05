# Getting Started with Henry OS

Welcome to Henry OS — your AI Chief of Staff. This guide will help you get the most out of your new autonomous operator.

## What Just Happened?

The installer has:
- ✅ Installed OpenClaw runtime
- ✅ Created your workspace at `~/.openclaw/workspace/`
- ✅ Generated your configuration
- ✅ Started Mission Control at http://localhost:3333
- ✅ Applied security hardening

## First Steps

### 1. Meet Your AI

Your AI has read your USER.md and knows:
- What to call you
- Your timezone and goals
- Your preferences for notifications and proactivity

Start by saying hello and giving it a test task.

### 2. Explore Mission Control

Open http://localhost:3333 in your browser. This is your command center where you can:
- Monitor system health
- View active tasks
- Check memory and learning logs
- Send commands directly to Henry

### 3. Connect Your Apps

Henry works best when connected to your data:

**Mail.app** — Henry can read and triage your emails
**Calendar.app** — Henry knows your schedule
**Messages.app** — Henry can draft replies

No setup required on macOS — Henry uses native AppleScript integration.

### 4. Set Up Notifications

If you selected a notification channel during onboarding:

**Telegram**: Add @HenryOSBot and send your chat ID
**iMessage**: Already works on macOS
**Discord**: Join the server and link your account

## Daily Workflow

### Morning
Henry will deliver a morning brief with:
- Today's calendar
- Overnight emails requiring action
- Active tasks and priorities

### During the Day
- Delegate tasks to Henry via chat
- Henry works autonomously and reports back
- Check Mission Control for status updates

### Evening
Henry will send a session summary with:
- Tasks completed
- Money saved/earned
- Tomorrow's priorities

## Key Commands

```
"Check my email" — Triage inbox
"What's on my calendar?" — Daily agenda
"Find me leads" — Run revenue hunting
"Watch this video" — Add to YouTube queue
"Remember that..." — Write to memory
```

## Sub-Agents

Henry can spawn specialized sub-agents:

- **Scout** — Research and intelligence gathering
- **Builder** — Coding and automation
- **Writer** — Content and communications
- **Hunter** — Opportunity identification
- **Watcher** — Content monitoring

Just ask: "Spawn a Hunter to find me freelance gigs"

## Learning Loop

Henry improves continuously:
1. Every task gets logged to memory
2. Mistakes are documented
3. Lessons are extracted
4. Rules are updated

You can view the learning log in Mission Control.

## Security

Henry OS implements defense-in-depth:
- Gateway bound to localhost only
- Strict WebSocket origin validation
- Filesystem scope restricted
- CVE-2026-25253 patched

Your data stays on your machine.

## Next Steps

1. **Customize SOUL.md** — Edit `~/.openclaw/workspace/SOUL.md` to change Henry's personality
2. **Set up HEARTBEAT.md** — Define what Henry checks periodically
3. **Connect more tools** — Add skills for specific workflows

## Getting Help

- **Documentation**: https://docs.henry-os.io
- **Discord**: https://discord.gg/openclaw
- **GitHub Issues**: https://github.com/henry-os/henry-os/issues

---

**Henry is now running. What would you like to work on?**
