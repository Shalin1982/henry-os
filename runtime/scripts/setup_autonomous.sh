#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# setup_autonomous.sh - Activate Henry's Autonomous Mode
# Run this to enable Henry to work between sessions
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

WORKSPACE="${HOME}/.openclaw"
SCRIPTS_DIR="${WORKSPACE}/scripts"
LOGS_DIR="${WORKSPACE}/logs"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           HENRY OS - AUTONOMOUS MODE ACTIVATOR             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Ensure directories exist
mkdir -p "$LOGS_DIR"

# Function to add cron job
add_cron_job() {
    local schedule="$1"
    local command="$2"
    local identifier="$3"
    
    # Remove existing entry if present
    (crontab -l 2>/dev/null | grep -v "$identifier" || true) | crontab -
    
    # Add new entry
    (crontab -l 2>/dev/null || echo "") | \
        echo -e "$(cat)\n$schedule $command # $identifier" | crontab -
    
    echo "✅ $identifier scheduled"
}

echo "Setting up autonomous jobs..."
echo ""

# 1. Opportunity Hunter - Every 2 hours
add_cron_job "0 */2 * * *" \
    "bash ${SCRIPTS_DIR}/opportunity-hunt-2hr.sh >> ${LOGS_DIR}/opportunity-hunt.log 2>&1" \
    "henry-opportunity-hunt"

# 2. Token Monitor - Every 15 minutes
add_cron_job "*/15 * * * *" \
    "bash ${SCRIPTS_DIR}/token-monitor.sh >> ${LOGS_DIR}/token-monitor.log 2>&1" \
    "henry-token-monitor"

# 3. KNOX Security Scan - Every 30 minutes
add_cron_job "*/30 * * * *" \
    "bash ${SCRIPTS_DIR}/knox-security-scan.sh >> ${LOGS_DIR}/knox-security.log 2>&1" \
    "henry-knox-security"

# 4. Message Processor - Every 15 minutes
add_cron_job "*/15 * * * *" \
    "bash ${SCRIPTS_DIR}/message-processor-v2.sh >> ${LOGS_DIR}/message-processor.log 2>&1" \
    "henry-message-processor"

# 5. Learning Checkpoint - Every hour
add_cron_job "0 * * * *" \
    "bash ${SCRIPTS_DIR}/learning-checkpoint.sh >> ${LOGS_DIR}/learning.log 2>&1" \
    "henry-learning-checkpoint"

# 6. Daily Backup - 4:30 AM
add_cron_job "30 4 * * *" \
    "bash ${SCRIPTS_DIR}/backup.sh >> ${LOGS_DIR}/backup.log 2>&1" \
    "henry-daily-backup"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Autonomous jobs activated!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Henry will now:"
echo "  • Hunt opportunities every 2 hours"
echo "  • Monitor token usage every 15 minutes"
echo "  • Run security scans every 30 minutes"
echo "  • Process messages every 15 minutes"
echo "  • Run learning checkpoints hourly"
echo "  • Create daily backups at 4:30 AM"
echo ""
echo "View all cron jobs: crontab -l"
echo "View logs: tail -f ${LOGS_DIR}/*.log"
echo ""
echo "Henry is now running autonomously between sessions."
echo ""
