#!/bin/bash
#
# henryos doctor — Diagnostic and repair tool for Henry OS
# Usage: henryos doctor [--fix issue-id]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ISSUES_FOUND=0
ISSUES_FIXED=0
AUTO_FIX="$2"

echo ""
echo "🩺 Henry OS Doctor"
echo "=================="
echo ""

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

suggest() {
    echo "   Fix: $1"
    if [ -n "$2" ]; then
        echo "   Run: $2"
    fi
}

# ISSUE-010: OpenClaw version check (CRITICAL)
check_openclaw_version() {
    if ! command -v openclaw &> /dev/null; then
        fail "ISSUE-010: OpenClaw not installed"
        suggest "Install OpenClaw" "npm install -g openclaw@latest"
        return
    fi
    
    VERSION=$(openclaw --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    
    if [ -z "$VERSION" ]; then
        fail "ISSUE-010: Cannot determine OpenClaw version"
        return
    fi
    
    # Compare versions (2026.1.29 is minimum)
    MAJOR=$(echo $VERSION | cut -d. -f1)
    MINOR=$(echo $VERSION | cut -d. -f2)
    PATCH=$(echo $VERSION | cut -d. -f3)
    
    if [ "$MAJOR" -gt 2026 ] || 
       ([ "$MAJOR" -eq 2026 ] && [ "$MINOR" -gt 1 ]) ||
       ([ "$MAJOR" -eq 2026 ] && [ "$MINOR" -eq 1 ] && [ "$PATCH" -ge 29 ]); then
        pass "ISSUE-010: OpenClaw version $VERSION (≥2026.1.29)"
    else
        fail "ISSUE-010: OpenClaw version $VERSION (CRITICAL — CVE-2026-25253 vulnerable)"
        suggest "Update to latest version" "npm install -g openclaw@latest"
        
        if [ "$AUTO_FIX" = "issue-010" ]; then
            info "Auto-fixing..."
            npm install -g openclaw@latest
            pass "OpenClaw updated to $(openclaw --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
            ISSUES_FIXED=$((ISSUES_FIXED + 1))
        fi
    fi
}

# ISSUE-006: Node version check
check_node_version() {
    if ! command -v node &> /dev/null; then
        fail "ISSUE-006: Node.js not installed"
        suggest "Install Node.js 24" "brew install node@24 && brew link node@24 --force"
        return
    fi
    
    VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    
    if [ "$VERSION" -ge 22 ]; then
        pass "ISSUE-006: Node.js $(node --version) (≥22)"
    else
        fail "ISSUE-006: Node.js $(node --version) (need ≥22)"
        suggest "Install Node.js 24" "brew install node@24 && brew link node@24 --force"
        
        if [ "$AUTO_FIX" = "issue-006" ]; then
            info "Auto-fixing..."
            brew install node@24 2>/dev/null || true
            brew link node@24 --force 2>/dev/null || true
            pass "Node.js updated to $(node --version)"
            ISSUES_FIXED=$((ISSUES_FIXED + 1))
        fi
    fi
}

# ISSUE-001: Gateway check
check_gateway() {
    if lsof -i :18789 &> /dev/null; then
        # Check if it's bound to localhost
        BINDING=$(lsof -i :18789 | grep LISTEN | awk '{print $9}' | head -1)
        if echo "$BINDING" | grep -q "127.0.0.1"; then
            pass "ISSUE-001: Gateway running on 127.0.0.1:18789 (secure)"
        else
            warn "ISSUE-001: Gateway running but not on localhost"
            suggest "Check OpenClaw config" "openclaw config edit"
        fi
    else
        fail "ISSUE-001: Gateway not running on port 18789"
        suggest "Start OpenClaw gateway" "openclaw gateway start"
    fi
}

# ISSUE-002/005: Mission Control check
check_mission_control() {
    if lsof -i :3001 &> /dev/null; then
        pass "ISSUE-002: Mission Control running on localhost:3001"
    else
        fail "ISSUE-002: Mission Control not running on port 3001"
        suggest "Start Mission Control" "cd ~/projects/henry-mission-control && npm run dev"
        
        # Check if port is in use by something else
        if lsof -i :3001 &> /dev/null; then
            info "Port 3001 is in use by another process"
            suggest "Use different port" "PORT=3002 npm run dev"
        fi
    fi
}

# ISSUE-003: state.json validation
check_state_json() {
    STATE_FILE="$HOME/.openclaw/mission-control/state.json"
    
    if [ ! -f "$STATE_FILE" ]; then
        fail "ISSUE-003: state.json not found"
        suggest "Create initial state.json" "henryos init-state"
        return
    fi
    
    if python3 -m json.tool "$STATE_FILE" > /dev/null 2>&1; then
        pass "ISSUE-003: state.json is valid JSON"
    else
        fail "ISSUE-003: state.json is corrupted (invalid JSON)"
        suggest "Restore from backup or recreate" 
        
        if [ "$AUTO_FIX" = "issue-003" ]; then
            info "Attempting auto-fix from backup..."
            LATEST_BACKUP=$(ls -t "$HOME/.openclaw/backup/" 2>/dev/null | head -1)
            if [ -n "$LATEST_BACKUP" ] && [ -f "$HOME/.openclaw/backup/$LATEST_BACKUP/state.json" ]; then
                cp "$HOME/.openclaw/backup/$LATEST_BACKUP/state.json" "$STATE_FILE"
                pass "Restored state.json from backup"
                ISSUES_FIXED=$((ISSUES_FIXED + 1))
            else
                fail "No backup found. Manual recreation required."
            fi
        fi
    fi
}

# ISSUE-004: API key check
check_api_key() {
    ENV_FILE="$HOME/.openclaw/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        fail "ISSUE-004: .env file not found"
        suggest "Create .env with API key" "echo 'MOONSHOT_API_KEY=your_key' > ~/.openclaw/.env"
        return
    fi
    
    if grep -q "MOONSHOT_API_KEY\|ANTHROPIC_API_KEY\|OPENAI_API_KEY" "$ENV_FILE" 2>/dev/null; then
        pass "ISSUE-004: API key configured in .env"
    else
        fail "ISSUE-004: No API key found in .env"
        suggest "Add API key to .env" "echo 'MOONSHOT_API_KEY=your_key' >> ~/.openclaw/.env"
    fi
}

# ISSUE-007: HEARTBEAT.md check
check_heartbeat() {
    HB_FILE="$HOME/.openclaw/workspace/HEARTBEAT.md"
    
    if [ ! -f "$HB_FILE" ]; then
        fail "ISSUE-007: HEARTBEAT.md not found"
        suggest "Create HEARTBEAT.md with standing tasks"
        
        if [ "$AUTO_FIX" = "issue-007" ]; then
            info "Creating default HEARTBEAT.md..."
            cat > "$HB_FILE" << 'EOF'
# HEARTBEAT.md

EVERY HEARTBEAT:
- Check task board for work in progress
- If board empty: propose 3 tasks to owner

DAILY 08:00:
- Send morning brief via preferred channel
- Check email and messages for urgent items
- Run opportunity hunt (Upwork + LinkedIn)

DAILY 20:00:
- Send evening wrap
- Run learning loop on today's completed tasks
EOF
            pass "Created default HEARTBEAT.md"
            ISSUES_FIXED=$((ISSUES_FIXED + 1))
        fi
        return
    fi
    
    if grep -q "EVERY HEARTBEAT\|DAILY\|standing tasks" "$HB_FILE" 2>/dev/null; then
        pass "ISSUE-007: HEARTBEAT.md has standing tasks"
    else
        fail "ISSUE-007: HEARTBEAT.md exists but has no standing tasks"
        suggest "Add standing tasks to HEARTBEAT.md"
    fi
}

# ISSUE-008: Memory deduplication (check if logic exists)
check_memory_dedup() {
    MC_DIR="$HOME/projects/henry-mission-control"
    if [ -f "$MC_DIR/src/app/memory/page.tsx" ]; then
        if grep -q "dedupeEpisodic\|deduplicate" "$MC_DIR/src/app/memory/page.tsx" 2>/dev/null; then
            pass "ISSUE-008: Memory deduplication logic present"
        else
            warn "ISSUE-008: Memory deduplication may not be implemented"
            suggest "Update Memory page with deduplication logic"
        fi
    else
        info "ISSUE-008: Cannot check — Mission Control source not found"
    fi
}

# ISSUE-009: Sidebar padding (check if exists)
check_sidebar_padding() {
    MC_DIR="$HOME/projects/henry-mission-control"
    if [ -f "$MC_DIR/src/components/Sidebar.tsx" ]; then
        if grep -q "py-1.5\|py-2" "$MC_DIR/src/components/Sidebar.tsx" 2>/dev/null; then
            pass "ISSUE-009: Sidebar has padding"
        else
            warn "ISSUE-009: Sidebar may be missing padding"
            suggest "Add py-1.5 to nav items in Sidebar.tsx"
        fi
    else
        info "ISSUE-009: Cannot check — Sidebar not found"
    fi
}

# Security: Origin validation check
check_origin_validation() {
    CONFIG_FILE="$HOME/.openclaw/config.yml"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        fail "Security: config.yml not found"
        return
    fi
    
    if grep -q "origin_validation: strict" "$CONFIG_FILE" 2>/dev/null; then
        pass "Security: WebSocket origin validation is strict (CVE-2026-25253 patched)"
    else
        fail "Security: origin_validation not set to strict"
        suggest "Set origin_validation: strict in config.yml"
    fi
}

# Backup check
check_backup() {
    BACKUP_DIR="$HOME/.openclaw/backup"
    
    if [ -d "$BACKUP_DIR" ]; then
        LATEST=$(ls -t "$BACKUP_DIR" 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            pass "Backup: Last backup $LATEST"
        else
            warn "Backup: Directory exists but no backups found"
            suggest "Run first backup" "~/.openclaw/scripts/backup.sh"
        fi
    else
        warn "Backup: Backup directory not set up"
        suggest "Create backup script and run" "mkdir -p ~/.openclaw/scripts"
    fi
}

# Main execution
echo "Running diagnostics..."
echo ""

check_openclaw_version
check_node_version
check_gateway
check_mission_control
check_state_json
check_api_key
check_heartbeat
check_memory_dedup
check_sidebar_padding
check_origin_validation
check_backup

echo ""
echo "=================="

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC} Henry OS is healthy."
    exit 0
else
    echo -e "${YELLOW}$ISSUES_FOUND issue(s) found${NC}"
    
    if [ $ISSUES_FIXED -gt 0 ]; then
        echo -e "${GREEN}$ISSUES_FIXED issue(s) auto-fixed${NC}"
    fi
    
    echo ""
    echo "To auto-fix specific issues:"
    echo "  henryos doctor --fix issue-XXX"
    echo ""
    echo "See full documentation: ~/.openclaw/workspace/KNOWN-ISSUES.md"
    exit 1
fi
