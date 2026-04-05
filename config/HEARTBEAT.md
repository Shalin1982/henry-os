# Henry's Standing Tasks — Proactive Work Between Messages

## DAILY (Morning Run — Once Per Day)

### 1. Email Triage via Mail.app
- Check LJ Hooker inbox for urgent items
- Flag anything requiring same-day response
- Draft replies for items needing follow-up
- Queue non-urgent items for batch processing
- **Decision:** What needs immediate attention vs. can wait?

### 2. Opportunity Hunt (Upwork + LinkedIn Jobs)
- Scrape for: software development, automation, AI integration, consulting
- Score matches 1-10 based on: budget, fit, location, complexity
- Add 7+ scores to Mission Control pipeline tab
- Brief note on why each is worth pursuing
- **Decision:** Which opportunities to prioritize?

### 3. Mission Control Build — Advance One Task
- Check backlog for unstarted build tasks
- Pick highest priority (or oldest if tied)
- Work on it for 15-30 min without waiting for approval
- Update task status in state.json
- **Decision:** What can I move forward right now?

---

## AFTER EVERY TASK

### Learning Loop (Auto-run)
- **Capture:** Log task, approach, output, duration, result
- **Reflect:** What worked? What failed? Compare to similar past tasks
- **Extract:** Write 1-2 lessons: "When [X], prefer [Y] because [Z]"
- **Write to state.json:** Add to learning_loop section
- **Activity feed:** Log LESSON_EXTRACTED event
- **Check validation:** If lesson seen 2+ times → flag for promotion
- **Approval gate:** If ready to promote → create pending approval

---

## DAILY

### Learning Health Check
- Check mistakes for any marked RECURRING
- If recurring mistakes exist → Create P0 task:
  "RECURRING MISTAKE: [ID] — investigate root cause"
- Check lessons pending promotion >3 days → Notify owner
- Review Learning Health widget on Dashboard

---

## SUNDAY 08:00 AEST

### Weekly Review Generation
- Generate comprehensive weekly review
- Write to state.json weekly_reviews
- Write to ~/workspace/WEEKLY-REVIEW-[date].md
- Send to owner via Telegram/iMessage
- Display in Mission Control Weekly Reviews tab
- Include: tasks completed, mistakes logged, lessons extracted, proposed SOUL.md changes

---

## CONTINUOUS (Every Heartbeat)

### Priority Check (in order):

**A. Build Tasks Pending?**
- If YES → Continue work on current build task
- Update progress, commit changes, note blockers

**B. Pipeline Has 7+ Opportunities?**
- If YES → Draft proposal for highest-scored opportunity
- Save draft to Documents, flag for review

**C. Nothing Urgent?**
- Run learning loop on recent completed tasks
- Extract lessons, update MEMORY.md
- Document what worked / what didn't

**Decision each heartbeat:** Which of A/B/C applies right now?

---

## WEEKLY (Sunday)

### Performance Summary Generation:
- Tasks completed this week (count, list)
- Tasks stalled (why, what needs to unblock)
- Opportunities found (count, best 3)
- Token costs (total, per-task breakdown)
- **Output:** Write summary to memory/YYYY-MM-DD.md

### Week Ahead Planning:
- Propose 3 tasks for coming week
- Rank by impact vs. effort
- Note any dependencies or blockers
- **Output:** Add to Mission Control as proposed tasks

---

## HENRY OS PRODUCT PRIORITIES

When no urgent operational tasks exist, work on Henry OS product:

1. **Henry OS Installer** (P0 — highest product priority)
   - Build install.sh for macOS
   - Test on clean machine
   - GitHub repo: henry-os

2. **Landing Page** (P1 — marketing foundation)
   - Vercel deployment
   - Email waitlist capture
   - Weekly newsletter setup

3. **ClawHub Listing** (P1 — distribution)
   - Package SOUL.md as free skill
   - Link to GitHub repo

4. **Content Strategy** (P2 — growth)
   - Mr-X: "building in public" threads
   - Weekly progress updates

Read HENRYOS-BRIEF.md for full product context.

---

## Heartbeat Decision Tree

```
Every heartbeat:
├── Is there an urgent email? → Handle it
├── Is a build task in progress? → Continue it
├── Pipeline has 7+ opportunities? → Draft proposal
├── Henry OS product work? → Continue installer/build
├── Nothing urgent? → Learning loop
└── Log what I did, update state.json
```

Never reply HEARTBEAT_OK without first checking these.
