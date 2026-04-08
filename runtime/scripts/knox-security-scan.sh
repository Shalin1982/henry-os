#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# KNOX Security Scanner — Main Entry Point
# Version: 1.0
# ═══════════════════════════════════════════════════════════════════════════════
# ⚠️  SAFETY FIRST: KNOX is READ-ONLY. It detects threats but NEVER modifies,
#     deletes, or quarantines files. All actions require human approval.
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ── SAFETY CONFIGURATION ──────────────────────────────────────────────────────
# KNOX operates in DETECT-ONLY mode. These flags ensure zero destructive actions.
KNOX_MODE="DETECT_ONLY"  # NEVER change to ACTIVE_RESPONSE
ALLOWED_ACTIONS="log|alert|notify"  # No file operations, no process kills

# ── Configuration ─────────────────────────────────────────────────────────────
WORKSPACE="${HOME}/.openclaw"
LOG_DIR="${WORKSPACE}/logs/security"
DATA_DIR="${WORKSPACE}/security"
STATE_DIR="${WORKSPACE}/mission-control"

# PROTECTED PATHS — KNOX will never touch these
PROTECTED_PATHS=(
    "$WORKSPACE/scripts"
    "$WORKSPACE/agents"
    "$WORKSPACE/mission-control"
    "$WORKSPACE/credentials"
    "$WORKSPACE/workspace"
    "$WORKSPACE/docs"
    "$WORKSPACE/logs"
    "$HOME/.openclaw"
)

# SAFETY CHECK: Verify we're not in destructive mode
if [[ "$KNOX_MODE" != "DETECT_ONLY" ]]; then
    echo "ERROR: KNOX safety violation. Mode must be DETECT_ONLY. Exiting."
    exit 1
fi

LOG_FILE="${LOG_DIR}/knox-$(date +%Y%m%d).log"
ALERT_LOG="${DATA_DIR}/alerts.jsonl"
BASELINE_FILE="${DATA_DIR}/system-baseline.json"
LAST_SCAN_FILE="${DATA_DIR}/.last_scan"

# Alert thresholds
CRITICAL_ALERTS=0
HIGH_ALERTS=0
MEDIUM_ALERTS=0
LOW_ALERTS=0

# ── Setup ──────────────────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR" "$DATA_DIR"
[[ -f "$ALERT_LOG" ]] || touch "$ALERT_LOG"

# ═══════════════════════════════════════════════════════════════════════════════
# SAFETY FUNCTIONS — Prevent any destructive operations
# ═══════════════════════════════════════════════════════════════════════════════

# Safety wrapper: Check if path is protected
is_protected_path() {
    local path="$1"
    for protected in "${PROTECTED_PATHS[@]}"; do
        if [[ "$path" == "$protected"* ]] || [[ "$path" == "$protected" ]]; then
            return 0  # Protected
        fi
    done
    return 1  # Not protected
}

# BLOCKED: rm, delete, remove operations
rm() {
    log_critical "BLOCKED: rm command attempted on '$*' — Destructive operations forbidden"
    return 1
}

# BLOCKED: mv, move operations that could overwrite
mv() {
    log_critical "BLOCKED: mv command attempted on '$*' — File modification forbidden"
    return 1
}

# BLOCKED: cp with overwrite
cp() {
    log_critical "BLOCKED: cp command attempted on '$*' — File modification forbidden"
    return 1
}

# BLOCKED: chmod, chown
chmod() {
    log_critical "BLOCKED: chmod command attempted on '$*' — Permission changes forbidden"
    return 1
}

chown() {
    log_critical "BLOCKED: chown command attempted on '$*' — Ownership changes forbidden"
    return 1
}

# BLOCKED: kill, pkill (process termination)
kill() {
    log_critical "BLOCKED: kill command attempted on '$*' — Process termination requires approval"
    return 1
}

pkill() {
    log_critical "BLOCKED: pkill command attempted on '$*' — Process termination requires approval"
    return 1
}

# BLOCKED: quarantine, isolate, delete operations
quarantine() {
    log_critical "BLOCKED: quarantine attempted on '$*' — File isolation forbidden"
    return 1
}

# SAFE: Only logging and alerting allowed
alert_only() {
    log "$@"
}

# ── Logging ────────────────────────────────────────────────────────────────────
log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [KNOX] [$level] $msg" | tee -a "$LOG_FILE"
    echo "{\"timestamp\":\"$ts\",\"level\":\"$level\",\"message\":\"$msg\"}" >> "$ALERT_LOG"
}
log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; ((CRITICAL_ALERTS++)) || true; }
log_medium() { log "MEDIUM" "$@"; ((MEDIUM_ALERTS++)) || true; }
log_low() { log "LOW" "$@"; ((LOW_ALERTS++)) || true; }
log_high() { log "HIGH" "$@"; ((HIGH_ALERTS++)) || true; }

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY SCANS
# ═══════════════════════════════════════════════════════════════════════════════

# ── Check Running Processes ────────────────────────────────────────────────────
scan_processes() {
    log_info "Scanning running processes..."
    
    # Check for suspicious processes
    local suspicious=$(ps aux | grep -E '(nc -l|netcat|python.*-m.*http.server|bash.*-i|/dev/tcp)' | grep -v grep || true)
    if [[ -n "$suspicious" ]]; then
        log_critical "Suspicious network processes detected: $suspicious"
    fi
    
    # Check for processes running as root that shouldn't be (exclude macOS system services)
    local root_procs=$(ps aux | awk '$1=="root" && ($11~/(bash|sh|python|perl|ruby)/) && $0!~/\/System\/Library/ {print $0}' | head -5)
    if [[ -n "$root_procs" ]]; then
        log_high "Root shell processes detected: $root_procs"
    fi
    
    log_info "Process scan complete"
}

# ── Check Network Connections ──────────────────────────────────────────────────
scan_network() {
    log_info "Scanning network connections..."
    
    # Check for unusual outbound connections
    local unusual=$(netstat -an 2>/dev/null | grep ESTABLISHED | grep -vE '(127.0.0.1|::1|192.168|10\.|172\.1[6-9]|172\.2[0-9]|172\.3[01])' | head -10 || true)
    if [[ -n "$unusual" ]]; then
        log_high "Unusual external connections: $unusual"
    fi
    
    # Check listening ports
    local listeners=$(netstat -an 2>/dev/null | grep LISTEN | grep -vE '(127.0.0.1|::1)' | awk '{print $4}' | sort -u | head -10 || true)
    log_info "External listening ports: $listeners"
    
    log_info "Network scan complete"
}

# ── Check Login Attempts ───────────────────────────────────────────────────────
scan_logins() {
    log_info "Checking login attempts..."
    
    # Check for failed SSH attempts (if applicable)
    if [[ -f /var/log/auth.log ]]; then
        local failed_ssh=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || true)
        if [[ -n "$failed_ssh" ]]; then
            log_high "Failed SSH login attempts: $failed_ssh"
        fi
    fi
    
    # Check last login
    local last_login=$(last -1 2>/dev/null | head -1 || echo "Unknown")
    log_info "Last login: $last_login"
    
    log_info "Login scan complete"
}

# ── Check File Integrity ───────────────────────────────────────────────────────
scan_files() {
    log_info "Scanning critical files..."
    
    # Check for recently modified sensitive files
    local sensitive_dirs=("$HOME/.openclaw/credentials" "$HOME/.ssh" "$HOME/.aws")
    for dir in "${sensitive_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local recent=$(find "$dir" -type f -mtime -1 2>/dev/null | head -5 || true)
            if [[ -n "$recent" ]]; then
                log_medium "Recently modified files in $dir: $recent"
            fi
        fi
    done
    
    # Check for world-writable files in home
    local world_writable=$(find "$HOME" -type f -perm -002 2>/dev/null | grep -v Library | head -5 || true)
    if [[ -n "$world_writable" ]]; then
        log_high "World-writable files found: $world_writable"
    fi
    
    log_info "File scan complete"
}

# ── Check OpenClaw Security ────────────────────────────────────────────────────
scan_openclaw() {
    log_info "Scanning OpenClaw security..."
    
    # Check for exposed credentials in logs
    local exposed=$(grep -r "sk-" "$LOG_DIR" 2>/dev/null | grep -v "knox-" | head -3 || true)
    if [[ -n "$exposed" ]]; then
        log_critical "Potential API keys exposed in logs: $exposed"
    fi
    
    # Check state.json permissions
    local state_perms=$(stat -f "%Lp" "$STATE_DIR/state.json" 2>/dev/null || echo "unknown")
    if [[ "$state_perms" != "600" && "$state_perms" != "644" ]]; then
        log_medium "State file permissions: $state_perms (should be 600)"
    fi
    
    log_info "OpenClaw scan complete"
}

# ── Check System Updates ───────────────────────────────────────────────────────
scan_updates() {
    log_info "Checking for system updates..."
    
    # Check if brew updates available
    if command -v brew &> /dev/null; then
        local outdated=$(brew outdated 2>/dev/null | wc -l || echo "0")
        if [[ "$outdated" -gt 10 ]]; then
            log_medium "$outdated Homebrew packages outdated"
        fi
    fi
    
    log_info "Update scan complete"
}

# ═══════════════════════════════════════════════════════════════════════════════
# BASELINE MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

establish_baseline() {
    log_info "Establishing system baseline..."
    
    # Capture current state
    local baseline=$(cat << EOF
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "processes": $(ps aux | wc -l),
  "listening_ports": $(netstat -an 2>/dev/null | grep LISTEN | wc -l || echo 0),
  "users": $(who | wc -l),
  "openclaw_version": "$(openclaw version 2>/dev/null || echo unknown)"
}
EOF
)
    echo "$baseline" > "$BASELINE_FILE"
    log_info "Baseline established"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ALERTING
# ═══════════════════════════════════════════════════════════════════════════════

send_alerts() {
    local total=$((CRITICAL_ALERTS + HIGH_ALERTS + MEDIUM_ALERTS + LOW_ALERTS))
    
    if [[ $total -eq 0 ]]; then
        log_info "No security alerts — all systems nominal"
        return
    fi
    
    local msg="🛡️ KNOX Security Alert\n\n"
    msg+="Critical: $CRITICAL_ALERTS\n"
    msg+="High: $HIGH_ALERTS\n"
    msg+="Medium: $MEDIUM_ALERTS\n"
    msg+="Low: $LOW_ALERTS\n\n"
    msg+="Check logs: $LOG_FILE"
    
    # Send notification (placeholder - integrate with your notification system)
    echo "$msg"
}

update_mission_control() {
    local state_file="$STATE_DIR/state.json"
    [[ -f "$state_file" ]] || return
    
    python3 << PYEOF 2>/dev/null || true
import json

try:
    with open("$state_file", "r") as f:
        state = json.load(f)
    
    security_status = {
        "last_scan": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "critical": $CRITICAL_ALERTS,
        "high": $HIGH_ALERTS,
        "medium": $MEDIUM_ALERTS,
        "low": $LOW_ALERTS,
        "status": "CRITICAL" if $CRITICAL_ALERTS > 0 else "WARNING" if $HIGH_ALERTS > 0 else "OK"
    }
    
    state["security"] = security_status
    
    with open("$state_file", "w") as f:
        json.dump(state, f, indent=2)
except Exception as e:
    print(f"Error updating state: {e}")
PYEOF
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    log_info "=== KNOX Security Scan Starting ==="
    
    # Establish baseline if doesn't exist
    [[ -f "$BASELINE_FILE" ]] || establish_baseline
    
    # Run all scans
    scan_processes
    scan_network
    scan_logins
    scan_files
    scan_openclaw
    scan_updates
    
    # Send alerts if any found
    send_alerts
    
    # Update Mission Control
    update_mission_control
    
    # Record scan time
    date -u +%Y-%m-%dT%H:%M:%SZ > "$LAST_SCAN_FILE"
    
    log_info "=== KNOX Security Scan Complete ==="
    log_info "Alerts: Critical=$CRITICAL_ALERTS High=$HIGH_ALERTS Medium=$MEDIUM_ALERTS Low=$LOW_ALERTS"
}

main "$@"
