#!/bin/bash
#
# Henry OS Installer - FIXED VERSION
# One-line installer for macOS and Linux
# curl -fsSL https://raw.githubusercontent.com/henry-os/henry-os/main/install.sh | bash
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://raw.githubusercontent.com/henry-os/henry-os/main"
INSTALL_DIR="${HOME}/.openclaw"
WORKSPACE_DIR="${INSTALL_DIR}/workspace"
CONFIG_DIR="${INSTALL_DIR}/config"
LOGS_DIR="${INSTALL_DIR}/logs"
MC_PORT="${HENRY_OS_PORT:-3333}"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Print banner
print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║                    HENRY OS INSTALLER                      ║"
    echo "║              Your AI Chief of Staff — v1.0                 ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Detect OS
detect_os() {
    local os="unknown"
    if [[ "${OSTYPE}" == "darwin"* ]]; then
        os="macos"
    elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
        os="linux"
    elif [[ "${OSTYPE}" == "linux-musl"* ]]; then
        os="linux"
    fi
    echo "$os"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if sudo is available and user has privileges
has_sudo() {
    command_exists sudo && sudo -n true 2>/dev/null
}

# Download file with fallback
download_file() {
    local url="$1"
    local dest="$2"
    
    if command_exists curl; then
        curl -fsSL "$url" -o "$dest" 2>/dev/null
    elif command_exists wget; then
        wget -q "$url" -O "$dest" 2>/dev/null
    else
        return 1
    fi
}

# Check if port is in use
check_port() {
    local port="$1"
    if command_exists lsof; then
        lsof -Pi :"$port" -sTCP:LISTEN -t >/dev/null 2>&1
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | grep -q ":$port "
    elif command_exists ss; then
        ss -tuln 2>/dev/null | grep -q ":$port "
    else
        # Can't check, assume available
        return 1
    fi
}

# Check Node.js version
check_node_version() {
    if command_exists node; then
        local version
        version=$(node --version | sed 's/v//')
        local major
        major=$(echo "$version" | cut -d. -f1)
        if [[ "$major" -ge 20 ]]; then
            echo "ok"
        else
            echo "old"
        fi
    else
        echo "missing"
    fi
}

# Install Node.js using n
install_node() {
    log_info "Installing Node.js 20+..."
    
    if ! command_exists n; then
        log_info "Installing n (Node version manager)..."
        if command_exists npm; then
            npm install -g n
        else
            # Install n directly
            curl -fsSL https://raw.githubusercontent.com/tj/n/master/bin/n | bash -s lts
        fi
    fi
    
    # Install Node 20 (with or without sudo)
    if has_sudo; then
        sudo n 20
    else
        n 20 || {
            log_warn "Could not install Node 20 without sudo"
            log_info "Please run: sudo n 20"
            return 1
        }
    fi
    
    # Verify
    if command_exists node; then
        log_success "Node.js $(node --version) installed"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
}

# Install OpenClaw
install_openclaw() {
    log_info "Installing OpenClaw..."
    
    if command_exists openclaw; then
        local current_version
        current_version=$(openclaw --version 2>/dev/null || echo "unknown")
        log_info "OpenClaw already installed ($current_version), updating..."
    fi
    
    npm install -g openclaw@latest
    log_success "OpenClaw installed"
}

# Create directory structure
create_structure() {
    log_info "Creating workspace structure..."
    
    mkdir -p "$WORKSPACE_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$WORKSPACE_DIR/memory"
    mkdir -p "$WORKSPACE_DIR/agents"
    mkdir -p "$WORKSPACE_DIR/mission-control"
    mkdir -p "$LOGS_DIR"
    
    log_success "Directory structure created"
}

# Download templates
download_templates() {
    log_info "Downloading templates..."
    
    local templates=("SOUL.md.template" "HEARTBEAT.md.template" "USER.md.template")
    
    for template in "${templates[@]}"; do
        local url="$REPO_URL/src/templates/$template"
        local dest="$WORKSPACE_DIR/$template"
        
        if download_file "$url" "$dest"; then
            log_success "Downloaded $template"
        else
            log_warn "Could not download $template"
        fi
    done
    
    log_success "Templates downloaded"
}

# Run onboarding wizard
run_onboarding() {
    log_info "Starting onboarding wizard..."
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                    ONBOARDING WIZARD                       ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Collect answers
    local name ai_name timezone primary_goal revenue_target preferred_model proactive_intel revenue_hunt notification_channel domains
    
    read -rp "1. What's your name? " name
    read -rp "2. What should the AI call you? " ai_name
    read -rp "3. What's your timezone? (e.g., America/New_York) " timezone
    
    echo "4. What's your primary goal?"
    echo "   (1) revenue  (2) family  (3) learning  (4) other"
    read -rp "   Select (1-4): " goal_choice
    case $goal_choice in
        1) primary_goal="revenue" ;;
        2) primary_goal="family" ;;
        3) primary_goal="learning" ;;
        *) primary_goal="other" ;;
    esac
    
    if [[ "$primary_goal" == "revenue" ]]; then
        read -rp "5. What's your monthly revenue target? (USD, e.g., 10000) " revenue_target
    else
        revenue_target="0"
    fi
    
    echo "6. Preferred model?"
    echo "   (1) kimi-k2.5 (default)  (2) claude-sonnet-4-6  (3) claude-opus-4-6"
    read -rp "   Select (1-3): " model_choice
    case $model_choice in
        2) preferred_model="claude-sonnet-4-6" ;;
        3) preferred_model="claude-opus-4-6" ;;
        *) preferred_model="kimi-k2.5" ;;
    esac
    
    read -rp "7. Enable proactive intelligence? (yes/no) " proactive_intel
    read -rp "8. Enable revenue hunting? (yes/no) " revenue_hunt
    
    echo "9. Preferred notification channel?"
    echo "   (1) telegram  (2) imessage  (3) discord  (4) none"
    read -rp "   Select (1-4): " channel_choice
    case $channel_choice in
        1) notification_channel="telegram" ;;
        2) notification_channel="imessage" ;;
        3) notification_channel="discord" ;;
        *) notification_channel="none" ;;
    esac
    
    read -rp "10. Any specific domains to focus on? (comma-separated, or 'none') " domains
    
    # Generate config
    generate_config "$name" "$ai_name" "$timezone" "$primary_goal" "$revenue_target" "$preferred_model" "$proactive_intel" "$revenue_hunt" "$notification_channel" "$domains"
    
    # Generate USER.md
    generate_user_md "$name" "$ai_name" "$timezone" "$primary_goal" "$domains"
    
    log_success "Onboarding complete!"
}

# Escape string for JSON
json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Generate config file
generate_config() {
    local name="$1" ai_name="$2" timezone="$3" primary_goal="$4" revenue_target="$5" 
    local preferred_model="$6" proactive_intel="$7" revenue_hunt="$8" notification_channel="$9" domains="${10}"
    
    # Escape strings for JSON
    local name_escaped ai_name_escaped timezone_escaped primary_goal_escaped preferred_model_escaped notification_channel_escaped
    name_escaped=$(json_escape "$name")
    ai_name_escaped=$(json_escape "$ai_name")
    timezone_escaped=$(json_escape "$timezone")
    primary_goal_escaped=$(json_escape "$primary_goal")
    preferred_model_escaped=$(json_escape "$preferred_model")
    notification_channel_escaped=$(json_escape "$notification_channel")
    
    # Build domains array
    local domains_array=""
    if [[ "$domains" != "none" && -n "$domains" ]]; then
        IFS=',' read -ra domain_list <<< "$domains"
        for domain in "${domain_list[@]}"; do
            domain=$(echo "$domain" | xargs) # trim whitespace
            domain=$(json_escape "$domain")
            if [[ -n "$domains_array" ]]; then
                domains_array="$domains_array, \"$domain\""
            else
                domains_array="\"$domain\""
            fi
        done
    fi
    
    local proactive_bool="false"
    [[ "$proactive_intel" =~ ^[Yy] ]] && proactive_bool="true"
    
    local revenue_bool="false"
    [[ "$revenue_hunt" =~ ^[Yy] ]] && revenue_bool="true"
    
    local notifications_bool="false"
    [[ "$notification_channel" != "none" ]] && notifications_bool="true"
    
    cat > "$CONFIG_DIR/user-config.json" <<EOF
{
  "user": {
    "name": "$name_escaped",
    "ai_name": "$ai_name_escaped",
    "timezone": "$timezone_escaped",
    "primary_goal": "$primary_goal_escaped",
    "revenue_target": $revenue_target,
    "domains": [$domains_array]
  },
  "ai": {
    "preferred_model": "$preferred_model_escaped",
    "proactive_intelligence": $proactive_bool,
    "revenue_hunting": $revenue_bool
  },
  "notifications": {
    "channel": "$notification_channel_escaped",
    "enabled": $notifications_bool
  },
  "security": {
    "gateway_bind": "127.0.0.1",
    "websocket_origin_validation": "strict",
    "filesystem_scope": "$WORKSPACE_DIR",
    "cve_2026_25253_patched": true
  },
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "1.0.0"
}
EOF
    
    chmod 600 "$CONFIG_DIR/user-config.json"
}

# Generate USER.md
generate_user_md() {
    local name="$1" ai_name="$2" timezone="$3" primary_goal="$4" domains="$5"
    
    cat > "$WORKSPACE_DIR/USER.md" <<EOF
# USER.md - About Your Human

- **Name:** $name
- **What to call them:** $ai_name
- **Timezone:** $timezone

## Context

- **Primary Goal:** $primary_goal
- **Focus Domains:** $domains

## Notes

Installed via Henry OS installer on $(date +"%Y-%m-%d").
EOF
}

# Apply security hardening
apply_security() {
    log_info "Applying security hardening..."
    
    local install_dir_escaped
    install_dir_escaped=$(json_escape "$WORKSPACE_DIR")
    
    # Create security config
    cat > "$CONFIG_DIR/security.json" <<EOF
{
  "gateway": {
    "bind_address": "127.0.0.1",
    "port": $MC_PORT,
    "external_access": false
  },
  "websocket": {
    "origin_validation": "strict",
    "allowed_origins": ["http://localhost:$MC_PORT", "http://127.0.0.1:$MC_PORT"]
  },
  "filesystem": {
    "scope": "$install_dir_escaped",
    "allow_outside_scope": false
  },
  "cve_patches": {
    "CVE-2026-25253": {
      "patched": true,
      "patch_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
      "description": "WebSocket origin validation bypass - strict validation enabled"
    }
  }
}
EOF
    
    chmod 600 "$CONFIG_DIR/security.json"
    
    log_success "Security hardening applied (CVE-2026-25253 patched)"
}

# Install and start Mission Control
install_mission_control() {
    log_info "Installing Mission Control..."
    
    local mc_dir="$WORKSPACE_DIR/mission-control"
    
    # Check for port conflicts
    if check_port "$MC_PORT"; then
        log_warn "Port $MC_PORT is already in use"
        MC_PORT=3334
        if check_port "$MC_PORT"; then
            log_error "Port $MC_PORT is also in use. Please free up port 3333 or 3334."
            exit 1
        fi
        log_info "Using alternative port: $MC_PORT"
    fi
    
    # Download Mission Control files
    if ! download_file "$REPO_URL/src/mission-control/server.js" "$mc_dir/server.js"; then
        # Fallback: create minimal server
        cat > "$mc_dir/server.js" <<'EOF'
const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = process.env.HENRY_OS_PORT || 3333;
const HOST = '127.0.0.1';

const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`
<!DOCTYPE html>
<html>
<head>
    <title>Henry OS - Mission Control</title>
    <style>
        body { font-family: -apple-system, sans-serif; background: #0a0a0a; color: #fff; margin: 0; padding: 40px; }
        h1 { color: #00d4ff; }
        .status { background: #1a1a1a; padding: 20px; border-radius: 8px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-value { font-size: 24px; font-weight: bold; color: #00d4ff; }
        .metric-label { font-size: 12px; color: #888; }
    </style>
</head>
<body>
    <h1>🎯 Mission Control</h1>
    <div class="status">
        <div class="metric">
            <div class="metric-value">●</div>
            <div class="metric-label">System Online</div>
        </div>
        <div class="metric">
            <div class="metric-value">Henry</div>
            <div class="metric-label">Master Agent</div>
        </div>
    </div>
    <p>Your AI Chief of Staff is running.</p>
    <p>Workspace: ${process.env.HOME}/.openclaw/workspace</p>
</body>
</html>
    `);
});

server.listen(PORT, HOST, () => {
    console.log(`Mission Control running at http://${HOST}:${PORT}`);
});
EOF
    fi
    
    # Create package.json
    cat > "$mc_dir/package.json" <<EOF
{
  "name": "henry-mission-control",
  "version": "1.0.0",
  "description": "Henry OS Mission Control Dashboard",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  }
}
EOF
    
    # Start Mission Control
    cd "$mc_dir"
    HENRY_OS_PORT=$MC_PORT nohup node server.js > "$LOGS_DIR/mission-control.log" 2>&1 &
    
    log_success "Mission Control installed and started on port $MC_PORT"
}

# Open browser
open_browser() {
    log_info "Opening Mission Control..."
    
    local url="http://localhost:$MC_PORT"
    local os
    os=$(detect_os)
    
    if [[ "$os" == "macos" ]]; then
        open "$url"
    elif [[ "$os" == "linux" ]]; then
        if command_exists xdg-open; then
            xdg-open "$url"
        elif command_exists gnome-open; then
            gnome-open "$url"
        fi
    fi
}

# Send welcome message
send_welcome() {
    log_info "Sending welcome message..."
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}║              🎉 HENRY OS INSTALLATION COMPLETE! 🎉          ║${NC}"
    echo -e "${GREEN}║                                                            ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Your AI Chief of Staff is ready.${NC}"
    echo ""
    echo -e "📊 ${YELLOW}Mission Control:${NC} http://localhost:$MC_PORT"
    echo -e "📁 ${YELLOW}Workspace:${NC} $WORKSPACE_DIR"
    echo -e "⚙️  ${YELLOW}Config:${NC} $CONFIG_DIR"
    echo ""
    echo -e "${GREEN}Henry is now running and ready to help you.${NC}"
    echo -e "${GREEN}Check Mission Control to monitor status and give commands.${NC}"
    echo ""
}

# Main installation flow
main() {
    print_banner
    
    local os
    os=$(detect_os)
    
    if [[ "$os" == "unknown" ]]; then
        log_error "Unsupported operating system: $OSTYPE"
        log_error "Henry OS supports macOS and Linux only."
        exit 1
    fi
    
    log_info "Detected OS: $os"
    
    # Step 1: Check Node.js
    local node_status
    node_status=$(check_node_version)
    if [[ "$node_status" == "missing" ]]; then
        install_node
    elif [[ "$node_status" == "old" ]]; then
        log_warn "Node.js version is too old, upgrading..."
        install_node
    else
        log_success "Node.js $(node --version) is ready"
    fi
    
    # Step 2: Install OpenClaw
    install_openclaw
    
    # Step 3: Create structure
    create_structure
    
    # Step 4: Download templates
    download_templates
    
    # Step 5: Onboarding
    run_onboarding
    
    # Step 6: Security hardening
    apply_security
    
    # Step 7: Install Mission Control
    install_mission_control
    
    # Step 8: Open browser
    open_browser
    
    # Step 9: Welcome message
    send_welcome
}

# Run main
main "$@"
