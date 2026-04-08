#!/bin/bash
# Runs every hour via cron
# Forces memory write regardless of what Henry is doing

TIMESTAMP=$(date '+%Y-%m-%d %H:%M AEST')
DATE=$(date '+%Y-%m-%d')
MEMORY_FILE=~/.openclaw/workspace/memory/$DATE.md
CHECKPOINT_FLAG=~/.openclaw/.last-memory-write

# Check when memory was last written
if [ -f "$CHECKPOINT_FLAG" ]; then
 LAST_WRITE=$(cat "$CHECKPOINT_FLAG")
 NOW=$(date +%s)
 DIFF=$((NOW - LAST_WRITE))
 
 # If more than 55 minutes since last write
 if [ $DIFF -gt 3300 ]; then
 echo "[$TIMESTAMP] ⚠️ Memory checkpoint overdue — forcing write"
 
 # Trigger Henry to write memory via OpenClaw
 openclaw message "SYSTEM: Memory checkpoint. Write your current progress to memory/$DATE.md immediately. Include: current task, what's done, what's pending, any issues hit. This is automated — not optional."
 
 # Update timestamp
 date +%s > "$CHECKPOINT_FLAG"
 echo "[$TIMESTAMP] ✓ Checkpoint triggered"
 else
 echo "[$TIMESTAMP] ✓ Memory write within window ($DIFF seconds ago)"
 fi
else
 # First run — create flag
 date +%s > "$CHECKPOINT_FLAG"
 echo "[$TIMESTAMP] ✓ First run — checkpoint flag created"
fi

# Also check if MISTAKES.md exists
if [ ! -f ~/.openclaw/workspace/MISTAKES.md ]; then
 echo "[$TIMESTAMP] ⚠️ MISTAKES.md missing — alerting Henry"
 openclaw message "SYSTEM: MISTAKES.md does not exist. Create it immediately."
fi
