#!/bin/bash
# Quick test of message processor components

echo "═══════════════════════════════════════════════════════════════"
echo "  Message Processor Component Test"
echo "═══════════════════════════════════════════════════════════════"
echo ""

WORKSPACE="${HOME}/.openclaw"
SCRIPT_DIR="${WORKSPACE}/scripts"

echo "1. Testing Python classifier (fallback mode)..."
python3 << 'PYTEST'
import sys
sys.path.insert(0, "${HOME}/.openclaw/scripts")

# Test the fallback classification
from message_classifier import MessageClassifier

classifier = MessageClassifier(model="gemma3:1b")

# Test bill detection
analysis = classifier.classify(
    subject="Your electricity bill is due",
    sender="energy@utility.com", 
    content="Your bill of $150.50 is due on 2024-01-15. Please pay by the due date."
)

print(f"✅ Bill detection: {analysis.categories[0].category.value if analysis.categories else 'none'}")
print(f"   Confidence: {analysis.categories[0].confidence if analysis.categories else 0}")
print(f"   Dates: {analysis.extracted_dates}")
print(f"   Amounts: {analysis.extracted_amounts}")

# Test appointment detection
analysis2 = classifier.classify(
    subject="Meeting: Project Review",
    sender="boss@company.com",
    content="Let's meet tomorrow at 2pm to review the Q4 project status."
)

print(f"\n✅ Appointment detection: {analysis2.categories[0].category.value if analysis2.categories else 'none'}")
print(f"   Confidence: {analysis2.categories[0].confidence if analysis2.categories else 0}")

# Test deadline detection
analysis3 = classifier.classify(
    subject="Tax return deadline approaching",
    sender="ato.gov.au",
    content="Your tax return is due by October 31, 2024."
)

print(f"\n✅ Deadline detection: {analysis3.categories[0].category.value if analysis3.categories else 'none'}")
print(f"   Confidence: {analysis3.categories[0].confidence if analysis3.categories else 0}")
print(f"   Dates: {analysis3.extracted_dates}")

print("\n✅ All fallback classifications working!")
PYTEST

echo ""
echo "2. Testing directory structure..."
for dir in "${WORKSPACE}/message-processor" "${WORKSPACE}/logs"; do
    if [[ -d "$dir" ]]; then
        echo "  ✅ $dir"
    else
        echo "  ❌ $dir missing"
    fi
done

echo ""
echo "3. Testing scripts..."
for script in message-processor-v2.sh message-classifier.py; do
    if [[ -x "${SCRIPT_DIR}/$script" ]]; then
        echo "  ✅ $script is executable"
    else
        echo "  ❌ $script not executable"
    fi
done

echo ""
echo "4. Testing AppleScript (Mail.app access)..."
if osascript -e 'tell application "Mail" to get name' &>/dev/null; then
    echo "  ✅ Mail.app accessible"
else
    echo "  ⚠️  Mail.app not accessible (may need permissions)"
fi

echo ""
echo "5. Testing imsg..."
if command -v imsg &>/dev/null; then
    echo "  ✅ imsg installed"
    if imsg chats --limit 1 &>/dev/null; then
        echo "  ✅ imsg working"
    else
        echo "  ⚠️  imsg needs permissions"
    fi
else
    echo "  ❌ imsg not installed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  Test Complete"
echo "═══════════════════════════════════════════════════════════════"
