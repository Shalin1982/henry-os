# MISTAKES.md — Henry's Error Log

## Format Template

```
DATE: [YYYY-MM-DD]
MISTAKE_ID: [AUTO-GENERATED]
WHAT_HAPPENED: [Specific description of what went wrong]
ROOT_CAUSE: [Honest analysis of why it happened]
IMPACT: [Cost in time, tokens, trust, or revenue]
FIX_APPLIED: [Correction made immediately]
PREVENTION_RULE: [Specific rule added to prevent recurrence]
ADDED_TO: [SOUL.md / HEARTBEAT.md / Procedural / QA Standard]
STATUS: [OPEN / RESOLVED / RECURRING]
RECURRENCE_COUNT: [0 if first time, increment if repeated]
```

## Seeded Mistakes (Examples)

### MISTAKE-001
**DATE:** 2026-04-03  
**WHAT HAPPENED:** Built Mission Control UI without design system first  
**ROOT CAUSE:** Rushed to show progress, skipped foundational work  
**IMPACT:** Complete rebuild required, 8 hours wasted  
**FIX APPLIED:** Defined hex color palette, spacing, typography before any components  
**PREVENTION RULE:** Always define design system with hex colors before building any pages  
**ADDED TO:** SOUL.md, Dashboard Build Protocol  
**STATUS:** RESOLVED  
**RECURRENCE COUNT:** 0

### MISTAKE-002
**DATE:** 2026-04-03  
**WHAT HAPPENED:** Henry went idle overnight with no standing HEARTBEAT tasks  
**ROOT CAUSE:** No proactive work protocol defined  
**IMPACT:** Lost 8 hours of potential productivity  
**FIX APPLIED:** Created HEARTBEAT.md with standing tasks for every heartbeat  
**PREVENTION RULE:** Henry always has standing tasks; never reply HEARTBEAT_OK without checking  
**ADDED TO:** HEARTBEAT.md, SOUL.md  
**STATUS:** RESOLVED  
**RECURRENCE COUNT:** 0

### MISTAKE-003
**DATE:** 2026-04-04  
**WHAT HAPPENED:** Tasks marked DONE without testing  
**ROOT CAUSE:** Eagerness to show completion, skipped verification  
**IMPACT:** Bugs discovered later, reputation hit  
**FIX APPLIED:** Definition of Done checklist; move to IN REVIEW, never directly to DONE  
**PREVENTION RULE:** All tasks require testing before marking complete; use IN REVIEW status  
**ADDED TO:** SOUL.md, QA Standard  
**STATUS:** RESOLVED  
**RECURRENCE COUNT:** 0

### MISTAKE-004
**DATE:** 2026-04-04  
**WHAT HAPPENED:** Duplicate memory entries created in state.json  
**ROOT CAUSE:** No deduplication logic on write  
**IMPACT:** Data bloat, confusion  
**FIX APPLIED:** Added deduplication by title+date on load  
**PREVENTION RULE:** Deduplicate episodic memories by title+date before display  
**ADDED TO:** Memory page logic  
**STATUS:** RESOLVED  
**RECURRENCE COUNT:** 0

### MISTAKE-005
**DATE:** 2026-04-05  
**WHAT HAPPENED:** Sidebar nav items had no padding  
**ROOT CAUSE:** Rushed CSS, didn't verify visual polish  
**IMPACT:** UI looked broken, unprofessional  
**FIX APPLIED:** Added consistent padding, tested all breakpoints  
**PREVENTION RULE:** Every UI element must be visually verified at all breakpoints  
**ADDED TO:** QA Standard  
**STATUS:** RESOLVED  
**RECURRENCE COUNT:** 0

---

## Active Mistakes

*None currently active*

---

## Recurring Mistakes

*None currently recurring*

---

## Learning from Mistakes

Every mistake logged here feeds into:
1. **SOUL.md** — Prevention rules become standing operating procedures
2. **HEARTBEAT.md** — Checks added to daily/weekly routines
3. **Procedural Memory** — Step-by-step guides updated
4. **QA Standard** — Checklists expanded

**Goal: Never the same mistake twice.**

---

*Last updated: April 5, 2026*
