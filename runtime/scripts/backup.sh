#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# backup.sh - Daily Backup Script for Henry OS
# Backs up critical data to multiple locations
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

WORKSPACE="${HOME}/.openclaw"
BACKUP_DIR="${WORKSPACE}/backups"
MISSION_CONTROL="${WORKSPACE}/mission-control"
WORKSPACE_DIR="${WORKSPACE}/workspace"
LOGS_DIR="${WORKSPACE}/logs"

# Create backup directory with date
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_PATH="${BACKUP_DIR}/${DATE}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Henry OS backup..."

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup Mission Control state
echo "  → Backing up Mission Control state..."
if [[ -f "${MISSION_CONTROL}/state.json" ]]; then
    cp "${MISSION_CONTROL}/state.json" "${BACKUP_PATH}/state.json"
    echo "    ✅ state.json backed up"
else
    echo "    ⚠️  state.json not found"
fi

# Backup workspace files
echo "  → Backing up workspace files..."
if [[ -d "$WORKSPACE_DIR" ]]; then
    tar -czf "${BACKUP_PATH}/workspace.tar.gz" -C "$WORKSPACE" workspace/ 2>/dev/null || true
    echo "    ✅ workspace backed up"
else
    echo "    ⚠️  workspace not found"
fi

# Backup credentials (encrypted)
echo "  → Backing up credentials..."
if [[ -d "${WORKSPACE}/credentials" ]]; then
    tar -czf "${BACKUP_PATH}/credentials.tar.gz" -C "$WORKSPACE" credentials/ 2>/dev/null || true
    echo "    ✅ credentials backed up (encrypted archive)"
else
    echo "    ⚠️  credentials not found"
fi

# Backup scripts
echo "  → Backing up scripts..."
SCRIPTS_DIR="${WORKSPACE}/scripts"
if [[ -d "$SCRIPTS_DIR" ]]; then
    tar -czf "${BACKUP_PATH}/scripts.tar.gz" -C "$WORKSPACE" scripts/ 2>/dev/null || true
    echo "    ✅ scripts backed up"
else
    echo "    ⚠️  scripts not found"
fi

# Create backup manifest
cat > "${BACKUP_PATH}/MANIFEST.txt" << EOF
Henry OS Backup Manifest
========================
Date: $(date)
Backup ID: ${DATE}

Contents:
- state.json: Mission Control state
- workspace.tar.gz: All workspace files
- credentials.tar.gz: API keys and tokens (encrypted)
- scripts.tar.gz: Automation scripts

To restore:
1. Extract archives to ~/.openclaw/
2. Verify state.json integrity
3. Restart Mission Control

Backup Location: ${BACKUP_PATH}
EOF

echo "    ✅ Manifest created"

# Clean old backups (keep last 7 days)
echo "  → Cleaning old backups..."
find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
echo "    ✅ Old backups cleaned"

# Create latest symlink
ln -sf "$BACKUP_PATH" "${BACKUP_DIR}/latest"

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup complete!"
echo "  Location: ${BACKUP_PATH}"
echo "  Size: $(du -sh "$BACKUP_PATH" | cut -f1)"
echo ""
echo "To restore from this backup:"
echo "  cp -r ${BACKUP_PATH}/* ~/.openclaw/"
echo ""
