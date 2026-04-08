#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# Henry Message Processor — Installation Script
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

echo "═══════════════════════════════════════════════════════════════"
echo "  Henry Message Processor — Installation"
echo "═══════════════════════════════════════════════════════════════"
echo ""

WORKSPACE="${HOME}/.openclaw"
SCRIPT_DIR="${WORKSPACE}/scripts"
DATA_DIR="${WORKSPACE}/message-processor"

check_dependency() {
    local cmd="$1"
    local name="${2:-$1}"
    
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $name installed"
        return 0
    else
        echo "❌ $name not found"
        return 1
    fi
}

echo "Checking dependencies..."
echo ""

MISSING=0

# Core dependencies
check_dependency "jq" || MISSING=$((MISSING + 1))
check_dependency "python3" || MISSING=$((MISSING + 1))
check_dependency "osascript" "AppleScript" || MISSING=$((MISSING + 1))
check_dependency "ollama" "Ollama (local LLM)" || MISSING=$((MISSING + 1))
check_dependency "imsg" "imsg (iMessage CLI)" || MISSING=$((MISSING + 1))

echo ""

if [[ $MISSING -gt 0 ]]; then
    echo "⚠️  $MISSING dependencies missing. Install them:"
    echo ""
    echo "  # Install jq"
    echo "  brew install jq"
    echo ""
    echo "  # Install Ollama"
    echo "  brew install ollama"
    echo "  ollama pull gemma3:1b  # or another model"
    echo ""
    echo "  # Install imsg"
    echo "  brew install steipete/tap/imsg"
    echo ""
    exit 1
fi

echo "═══════════════════════════════════════════════════════════════"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p "$DATA_DIR"
mkdir -p "${WORKSPACE}/logs"

echo "✅ Directories created"
echo ""

# Make scripts executable
echo "Setting up scripts..."
chmod +x "${SCRIPT_DIR}/message-processor.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/message-processor-v2.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/message-processor-lib.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/message-classifier.py" 2>/dev/null || true

echo "✅ Scripts ready"
echo ""

# Check Ollama model
echo "Checking Ollama model..."
OLLAMA_MODEL="${OLLAMA_MODEL:-gemma3:1b}"

if ollama list | grep -q "$OLLAMA_MODEL"; then
    echo "✅ Model '$OLLAMA_MODEL' available"
else
    echo "⚠️  Model '$OLLAMA_MODEL' not found"
    echo "   Run: ollama pull $OLLAMA_MODEL"
    echo ""
fi

# Check Telegram configuration
echo ""
echo "Checking Telegram configuration..."
TG_CREDS="${WORKSPACE}/credentials/telegram-pairing.json"

if [[ -f "$TG_CREDS" ]]; then
    if jq -e '.token' "$TG_CREDS" &> /dev/null; then
        echo "✅ Telegram bot token configured"
    else
        echo "⚠️  Telegram credentials found but no token"
    fi
else
    echo "⚠️  Telegram not configured (optional)"
    echo "   Notifications will be logged only"
fi

# Test classifier
echo ""
echo "Testing message classifier..."
TEST_RESULT=$(OLLAMA_MODEL="$OLLAMA_MODEL" python3 "${SCRIPT_DIR}/message-classifier.py" classify << 'EOF' 2>/dev/null || echo '{"error":"test failed"}'
{"subject":"Test bill","sender":"test@example.com","content":"Your bill of $100 is due on 2024-12-31"}
EOF
)

if echo "$TEST_RESULT" | jq -e '.categories' &> /dev/null; then
    echo "✅ Classifier working"
else
    echo "⚠️  Classifier test failed"
    echo "   Output: $TEST_RESULT"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Installation Complete"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "To run manually:"
echo "  bash ~/.openclaw/scripts/message-processor-v2.sh"
echo ""
echo "To add to cron (runs every 15 minutes):"
echo "  crontab -e"
echo "  */15 * * * * bash ~/.openclaw/scripts/message-processor-v2.sh >> ~/.openclaw/logs/message-processor-cron.log 2>&1"
echo ""
echo "Logs: ~/.openclaw/logs/message-processor.log"
echo "Data: ~/.openclaw/message-processor/"
echo ""
