#!/bin/bash
#
# Henry OS Installer for macOS
# One-line installer: curl -fsSL https://henryos.ai/install.sh | bash
#
# Deploys a complete AI chief of staff in under 5 minutes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HENRY_OS_VERSION="1.0.0"
NODE_VERSION="24"
OPENCLAW_MIN_VERSION="2026.1.29"
INSTALL_DIR="$HOME/.openclaw"
WORKSPACE_DIR="$INSTALL_DIR/workspace"
MISSION_CONTROL_DIR="$HOME/projects/henry-mission-control"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on macOS
check_macos() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "Henry OS installer currently supports macOS only."
        log_info "Linux and Windows support coming soon."
        exit 1
    fi
    log_success "macOS detected"
}

# Check for required tools
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check for curl
    if ! command -v curl &> /dev/null; then
        log_error "curl is required but not installed"
        exit 1
    fi
    
    # Check for git
    if ! command -v git &> /dev/null; then
        log_warning "git not found. Installing via Homebrew..."
        if ! command -v brew &> /dev/null; then
            log_info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        brew install git
    fi
    
    log_success "Prerequisites check passed"
}

# Install Node.js if needed
install_node() {
    log_info "Checking Node.js installation..."
    
    if command -v node &> /dev/null; then
        NODE_CURRENT=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_CURRENT" -ge "$NODE_VERSION" ]; then
            log_success "Node.js $(node --version) already installed"
            return
        fi
    fi
    
    log_info "Installing Node.js $NODE_VERSION..."
    
    if command -v brew &> /dev/null; then
        brew install node@$NODE_VERSION
        brew link node@$NODE_VERSION --force
    else
        # Install nvm and use it to install Node
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install $NODE_VERSION
        nvm use $NODE_VERSION
    fi
    
    log_success "Node.js $(node --version) installed"
}

# Install OpenClaw
install_openclaw() {
    log_info "Installing OpenClaw..."
    
    npm install -g openclaw@latest
    
    # Verify installation
    OPENCLAW_VERSION=$(openclaw --version 2>/dev/null || echo "unknown")
    log_success "OpenClaw $OPENCLAW_VERSION installed"
    
    # Check for critical security patch
    if ! openclaw --version | grep -E "2026\.(1\.(2[9]|[3-9][0-9])|[2-9]\.[0-9])" > /dev/null; then
        log_warning "OpenClaw version may not include CVE-2026-25253 patch"
        log_info "Attempting to update to latest..."
        npm install -g openclaw@latest
    fi
}

# Create directory structure
setup_directories() {
    log_info "Setting up directory structure..."
    
    mkdir -p "$WORKSPACE_DIR"
    mkdir -p "$INSTALL_DIR/mission-control"
    mkdir -p "$INSTALL_DIR/scripts"
    mkdir -p "$MISSION_CONTROL_DIR"
    mkdir -p "$HOME/Desktop/Voice-Memos"
    mkdir -p "$HOME/Desktop/Call-Recordings"
    mkdir -p "$HOME/Documents/Henry-Workspace"
    
    log_success "Directories created"
}

# Download Henry OS configuration files
download_configs() {
    log_info "Downloading Henry OS configuration..."
    
    # Base URL for Henry OS files (GitHub raw)
    HENRY_OS_REPO="https://raw.githubusercontent.com/shannon-linnan/henry-os/main"
    
    # Download core files
    curl -fsSL "$HENRY_OS_REPO/config/SOUL.md" -o "$WORKSPACE_DIR/SOUL.md" || log_warning "SOUL.md download failed"
    curl -fsSL "$HENRY_OS_REPO/config/HEARTBEAT.md" -o "$WORKSPACE_DIR/HEARTBEAT.md" || log_warning "HEARTBEAT.md download failed"
    curl -fsSL "$HENRY_OS_REPO/config/GOALS.md.template" -o "$WORKSPACE_DIR/GOALS.md" || log_warning "GOALS.md download failed"
    curl -fsSL "$HENRY_OS_REPO/config/USER.md.template" -o "$WORKSPACE_DIR/USER.md" || log_warning "USER.md download failed"
    curl -fsSL "$HENRY_OS_REPO/config/MISTAKES.md" -o "$WORKSPACE_DIR/MISTAKES.md" || log_warning "MISTAKES.md download failed"
    curl -fsSL "$HENRY_OS_REPO/config/HENRYOS-BRIEF.md" -o "$WORKSPACE_DIR/HENRYOS-BRIEF.md" || log_warning "HENRYOS-BRIEF.md download failed"
    
    log_success "Configuration files downloaded"
}

# Create initial state.json
create_state_json() {
    log_info "Creating initial state database..."
    
    cat > "$INSTALL_DIR/mission-control/state.json" << 'EOF'
{
  "system": {
    "status": "NOMINAL",
    "uptime_seconds": 0,
    "last_heartbeat": "",
    "tokens_today": 0,
    "token_budget_daily": 10000,
    "model_default": "kimi-k2.5",
    "agents_active": 1,
    "agents_total": 7,
    "anomaly_detection": {
      "enabled": true,
      "last_run": "",
      "active_anomalies": []
    }
  },
  "dashboard": {
    "net_worth_pipeline": 0,
    "tasks_completed_this_week": 0,
    "proposals_ready": 0,
    "token_spend_aud": 0
  },
  "tasks": [],
  "projects": [],
  "pipeline": [],
  "mistakes": [],
  "learning_loop": [],
  "weekly_reviews": [],
  "soul_changelog": [],
  "calendar": [],
  "memory": {
    "episodic": [],
    "semantic": [],
    "procedural": []
  },
  "documents": [],
  "activity": [],
  "anomalies": [],
  "radar": [],
  "revenue_targets": {
    "monthly_target_aud": 15000,
    "minimum_rate_hourly": 120,
    "minimum_rate_fixed": 3000,
    "max_project_weeks": 8,
    "preferred_types": ["AI integration", "Automation", "Dashboard builds"],
    "blacklist": ["WordPress", "PHP legacy", "Unpaid spec work"]
  },
  "voice_queue": [],
  "contacts": [],
  "goals": {
    "ninety_day": [],
    "one_year": "",
    "three_year": ""
  },
  "approvals": [],
  "agents": [
    {
      "id": "henry",
      "name": "Henry",
      "role": "Chief of Staff",
      "status": "ACTIVE",
      "model": "kimi-k2.5",
      "description": "Orchestrator, manages all agents"
    },
    {
      "id": "nexus",
      "name": "Nexus",
      "role": "CTO",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "Coding, GitHub PRs, Vercel deploys"
    },
    {
      "id": "ivy",
      "name": "Ivy",
      "role": "Research",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "Scrapes YouTube, X, Reddit 24/7"
    },
    {
      "id": "knox",
      "name": "Knox",
      "role": "Security Officer",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "Monitors system health"
    },
    {
      "id": "mr-x",
      "name": "Mr-X",
      "role": "Social Media",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "X and LinkedIn content"
    },
    {
      "id": "wolf",
      "name": "Wolf",
      "role": "Finance",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "Market and investment monitoring"
    },
    {
      "id": "ragnar",
      "name": "Ragnar",
      "role": "Business Development",
      "status": "STANDBY",
      "model": "kimi-k2.5",
      "description": "Outreach, opportunities"
    }
  ],
  "settings": {
    "budget": {
      "daily_limit_aud": 50,
      "alert_threshold": 0.8,
      "monthly_max_aud": 1000
    },
    "models": {
      "Henry": "kimi-k2.5",
      "Nexus": "kimi-k2.5",
      "Ivy": "kimi-k2.5",
      "Knox": "kimi-k2.5",
      "Mr-X": "kimi-k2.5",
      "Wolf": "kimi-k2.5",
      "Ragnar": "kimi-k2.5"
    },
    "notifications": {
      "morning_brief": true,
      "evening_wrap": true,
      "approval_gates": true,
      "anomaly_alerts": true
    }
  }
}
EOF
    
    log_success "State database created"
}

# Create OpenClaw config with security hardening
create_openclaw_config() {
    log_info "Creating OpenClaw configuration..."
    
    cat > "$INSTALL_DIR/config.yml" << EOF
# Henry OS OpenClaw Configuration
# Security hardening applied (CVE-2026-25253 patched)

gateway:
  host: 127.0.0.1
  port: 18789
  auth:
    enabled: true
    type: token
  websocket:
    origin_validation: strict
    allowed_origins:
      - "http://localhost:3001"
      - "http://127.0.0.1:3001"

workspace:
  allowed_paths:
    - "~/.openclaw/workspace"
    - "~/projects/henry-mission-control"
    - "~/Desktop/Voice-Memos"
    - "~/Desktop/Call-Recordings"
    - "~/Documents/Henry-Workspace"
  deny_patterns:
    - "**/.ssh/**"
    - "**/Keychain*"
    - "**/*password*"
    - "**/*secret*"
    - "**/*private_key*"
    - "**/wallet*"

exec:
  approvals:
    shell_commands: required
    file_delete: required
    file_write_outside_workspace: required
    network_requests_new_domain: required
    install_packages: required
    git_push: required
    send_email: required
    send_message: required
    api_calls_financial: required

models:
  default: "kimi-k2.5"
  fallback: "claude-sonnet-4-6"
  
  kimi-k2.5:
    provider: "moonshot"
    model: "kimi-k2.5"
    cost_per_1m_input: 0.60
    cost_per_1m_output: 3.00
    
  claude-sonnet-4-6:
    provider: "anthropic"
    model: "claude-sonnet-4-6"
    cost_per_1m_input: 3.00
    cost_per_1m_output: 15.00
    escalation_required: true
    
  claude-opus-4-6:
    provider: "anthropic"
    model: "claude-opus-4-6"
    cost_per_1m_input: 15.00
    cost_per_1m_output: 75.00
    escalation_required: true
    requires_approval: true

security:
  prompt_injection_defence: true
  external_content_is_data_only: true
  email_local_processing_only: true
  financial_data_summary_only: true
  
heartbeat:
  enabled: true
  interval_minutes: 30
  
backup:
  enabled: true
  schedule: "0 4 * * *"
  destinations:
    - github
    - icloud
EOF
    
    log_success "OpenClaw configuration created with security hardening"
}

# Install Mission Control
install_mission_control() {
    log_info "Installing Mission Control dashboard..."
    
    cd "$MISSION_CONTROL_DIR"
    
    # Clone or create Mission Control
    if [ ! -f "package.json" ]; then
        log_info "Setting up Mission Control from template..."
        
        # Download Mission Control template
        curl -fsSL "https://github.com/shannon-linnan/henry-mission-control/archive/refs/heads/main.tar.gz" -o /tmp/mc.tar.gz || {
            log_warning "Could not download Mission Control template"
            log_info "Creating minimal Mission Control setup..."
            
            # Create minimal package.json
            cat > package.json << 'EOF'
{
  "name": "henry-mission-control",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev -p 3001",
    "build": "next build",
    "start": "next start -p 3001"
  },
  "dependencies": {
    "next": "^14.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "typescript": "^5.0.0"
  }
}
EOF
        }
    fi
    
    # Install dependencies
    npm install
    
    log_success "Mission Control installed"
}

# Create backup script
create_backup_script() {
    log_info "Creating backup script..."
    
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
#!/bin/bash
# Henry OS Daily Backup Script
# Run automatically at 04:30 AEST

BACKUP_DIR="$HOME/.openclaw/backup/$(date +%Y-%m-%d)"
mkdir -p "$BACKUP_DIR"

# Copy critical files
cp "$HOME/.openclaw/workspace/SOUL.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/HEARTBEAT.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/MEMORY.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/MISTAKES.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/USER.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/GOALS.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/CONTACTS.md" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/config.yml" "$BACKUP_DIR/" 2>/dev/null || true
cp "$HOME/.openclaw/mission-control/state.json" "$BACKUP_DIR/" 2>/dev/null || true

# Encrypt .env if it exists
if [ -f "$HOME/.openclaw/.env" ]; then
    gpg --symmetric --cipher-algo AES256 --batch --passphrase-file "$HOME/.openclaw/.gpg-passphrase" \
        --output "$BACKUP_DIR/.env.gpg" "$HOME/.openclaw/.env" 2>/dev/null || true
fi

# Commit to GitHub if repo exists
if [ -d "$HOME/.openclaw/backup/.git" ]; then
    cd "$HOME/.openclaw/backup"
    git add .
    git commit -m "Daily backup $(date +%Y-%m-%d)" || true
    git push origin main || true
fi

# Copy to iCloud
mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Henry-Backup"
cp -r "$BACKUP_DIR" "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Henry-Backup/" 2>/dev/null || true

# Notify
osascript -e 'display notification "Henry OS backup complete" with title "Mission Control"' 2>/dev/null || true
EOF
    
    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    log_success "Backup script created"
}

# Setup cron jobs
setup_cron() {
    log_info "Setting up automated tasks..."
    
    # Create crontab entries
    (crontab -l 2>/dev/null || echo "") | grep -v "henry" > /tmp/crontab_henry
    
    # Add Henry OS cron jobs
    echo "# Henry OS Automated Tasks" >> /tmp/crontab_henry
    echo "30 4 * * * $INSTALL_DIR/scripts/backup.sh" >> /tmp/crontab_henry
    echo "0 8 * * * cd $INSTALL_DIR && openclaw run morning-brief" >> /tmp/crontab_henry
    echo "0 20 * * * cd $INSTALL_DIR && openclaw run evening-wrap" >> /tmp/crontab_henry
    echo "0 8 * * 0 cd $INSTALL_DIR && openclaw run weekly-review" >> /tmp/crontab_henry
    
    crontab /tmp/crontab_henry
    rm /tmp/crontab_henry
    
    log_success "Cron jobs configured"
}

# Run onboarding wizard
run_onboarding() {
    log_info ""
    log_info "========================================"
    log_info "  Welcome to Henry OS Setup"
    log_info "========================================"
    log_info ""
    
    echo "Henry OS will ask you 10 quick questions to personalise your setup."
    echo ""
    
    # Question 1
    read -p "1. What should Henry call you? [$(whoami)]: " OWNER_NAME
    OWNER_NAME=${OWNER_NAME:-$(whoami)}
    
    # Question 2
    read -p "2. What's your primary email for notifications? " OWNER_EMAIL
    
    # Question 3
    read -p "3. What's your monthly revenue target? (AUD) [15000]: " REVENUE_TARGET
    REVENUE_TARGET=${REVENUE_TARGET:-15000}
    
    # Question 4
    read -p "4. What type of work do you do? (e.g., software, consulting, real estate) " WORK_TYPE
    
    # Question 5
    read -p "5. Preferred notification channel (imessage/telegram/email) [imessage]: " NOTIFICATION_CHANNEL
    NOTIFICATION_CHANNEL=${NOTIFICATION_CHANNEL:-imessage}
    
    # Question 6
    read -p "6. Working hours (e.g., 9-17): [9-17] " WORKING_HOURS
    WORKING_HOURS=${WORKING_HOURS:-9-17}
    
    # Question 7
    read -p "7. Do you want morning briefs? (yes/no) [yes]: " MORNING_BRIEF
    MORNING_BRIEF=${MORNING_BRIEF:-yes}
    
    # Question 8
    read -p "8. Do you want evening wraps? (yes/no) [yes]: " EVENING_WRAP
    EVENING_WRAP=${EVENING_WRAP:-yes}
    
    # Question 9
    read -p "9. Preferred AI model (kimi-k2.5/claude-sonnet) [kimi-k2.5]: " PREFERRED_MODEL
    PREFERRED_MODEL=${PREFERRED_MODEL:-kimi-k2.5}
    
    # Question 10
    read -p "10. Anything else Henry should know about you? (optional) " ADDITIONAL_INFO
    
    # Save to USER.md
    cat > "$WORKSPACE_DIR/USER.md" << EOF
# USER.md — Owner Profile

## Identity
- **Name:** $OWNER_NAME
- **Email:** $OWNER_EMAIL
- **Work Type:** $WORK_TYPE
- **Location:** $(scutil --get ComputerName 2>/dev/null || echo "Unknown")

## Preferences
- **Notification Channel:** $NOTIFICATION_CHANNEL
- **Working Hours:** $WORKING_HOURS
- **Morning Briefs:** $MORNING_BRIEF
- **Evening Wraps:** $EVENING_WRAP
- **Preferred Model:** $PREFERRED_MODEL

## Financial
- **Monthly Revenue Target:** \$$REVENUE_TARGET AUD

## Notes
$ADDITIONAL_INFO

## Henry's Observations
- First setup: $(date)
- Setup completed via Henry OS installer v$HENRY_OS_VERSION
EOF
    
    # Update state.json with owner info
    node -e "
    const fs = require('fs');
    const state = JSON.parse(fs.readFileSync('$INSTALL_DIR/mission-control/state.json', 'utf8'));
    state.settings.owner = {
        name: '$OWNER_NAME',
        email: '$OWNER_EMAIL',
        notification_channel: '$NOTIFICATION_CHANNEL'
    };
    fs.writeFileSync('$INSTALL_DIR/mission-control/state.json', JSON.stringify(state, null, 2));
    " 2>/dev/null || true
    
    log_success "Onboarding complete — profile saved"
}

# Start services
start_services() {
    log_info "Starting Henry OS services..."
    
    # Start OpenClaw gateway
    openclaw gateway start &
    
    # Start Mission Control
    cd "$MISSION_CONTROL_DIR"
    npm run dev &
    
    log_success "Services started"
    
    # Wait a moment for services to initialise
    sleep 3
}

# Display completion message
show_completion() {
    log_info ""
    log_info "========================================"
    log_success "  Henry OS Installation Complete!"
    log_info "========================================"
    log_info ""
    log_info "Henry OS v$HENRY_OS_VERSION is now running."
    log_info ""
    log_info "📊 Mission Control: http://localhost:3001"
    log_info "⚙️  OpenClaw Gateway: http://localhost:18789"
    log_info ""
    log_info "Your AI chief of staff is ready."
    log_info "Henry will send you a morning brief at 08:00 AEST."
    log_info ""
    log_info "Quick commands:"
    log_info "  henryos status    — Check system status"
    log_info "  henryos doctor    — Run health check"
    log_info "  henryos backup    — Manual backup"
    log_info ""
    log_info "Documentation: ~/.openclaw/workspace/HENRYOS-BRIEF.md"
    log_info ""
    
    # Open Mission Control in browser
    open "http://localhost:3001" 2>/dev/null || true
}

# Main installation flow
main() {
    echo ""
    echo "🚀 Henry OS Installer v$HENRY_OS_VERSION"
    echo "   AI Chief of Staff Framework"
    echo ""
    
    check_macos
    check_prerequisites
    install_node
    install_openclaw
    setup_directories
    download_configs
    create_state_json
    create_openclaw_config
    install_mission_control
    create_backup_script
    setup_cron
    run_onboarding
    start_services
    show_completion
}

# Run main function
main "$@"
