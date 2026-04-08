#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Cron Setup
# Adds the 15-minute message processor job to crontab
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══════════════════════════════════════════════════════════════"
echo "  Message Processor Cron Setup"
echo "═══════════════════════════════════════════════════════════════"
echo ""

SCRIPT_PATH="${HOME}/.openclaw/scripts/message-processor-v2.sh"
LOG_PATH="${HOME}/.openclaw/logs/message-processor-cron.log"

# Check if already in crontab
if crontab -l 2>/dev/null | grep -q "message-processor-v2.sh"; then
    echo "⚠️  Message processor already in crontab"
    echo ""
    echo "Current entry:"
    crontab -l | grep "message-processor-v2.sh"
    echo ""
    read -p "Replace it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
    # Remove existing entry
    crontab -l 2>/dev/null | grep -v "message-processor-v2.sh" | crontab -
fi

echo "Adding cron job (runs every 15 minutes)..."
echo ""

# Add to crontab
(crontab -l 2>/dev/null || echo "") | {
    cat
    echo "# Henry Message Processor - Check Mail + iMessage every 15 minutes"
    echo "*/15 * * * * bash $SCRIPT_PATH >> $LOG_PATH 2>&1"
} | crontab -

echo "✅ Cron job added"
echo ""
echo "Schedule: Every 15 minutes"
echo "Script: $SCRIPT_PATH"
echo "Log: $LOG_PATH"
echo ""
echo "Current crontab:"
echo "───────────────────────────────────────────────────────────────"
crontab -l | grep -A1 "Henry Message Processor"
echo "───────────────────────────────────────────────────────────────"
echo ""
echo "To remove: crontab -e and delete the lines"
echo ""
