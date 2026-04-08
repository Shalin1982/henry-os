#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# github-commit.sh - Safe GitHub Commit Helper
# Handles errors gracefully and provides clear feedback
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

REPO_DIR="${1:-$(pwd)}"
COMMIT_MSG="${2:-"Update: $(date +%Y-%m-%d %H:%M)"}"

cd "$REPO_DIR" || { echo "❌ Cannot access $REPO_DIR"; exit 1; }

echo "╔════════════════════════════════════════════════════════════╗"
echo "║              GITHUB COMMIT HELPER                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Repository: $REPO_DIR"
echo "Commit: $COMMIT_MSG"
echo ""

# Check if git repo
if [[ ! -d ".git" ]]; then
    echo "❌ Not a git repository"
    exit 1
fi

# Check for lock file
if [[ -f ".git/index.lock" ]]; then
    echo "⚠️  Git lock file detected, removing..."
    rm -f ".git/index.lock"
fi

# Configure git if not set
if ! git config user.email &>/dev/null; then
    echo "⚠️  Git email not set, configuring..."
    git config user.email "shannon.linnan@gmail.com"
fi

if ! git config user.name &>/dev/null; then
    echo "⚠️  Git name not set, configuring..."
    git config user.name "Henry OS"
fi

# Check status
echo "📋 Checking git status..."
if git diff --quiet && git diff --cached --quiet; then
    echo "✅ No changes to commit"
    exit 0
fi

# Fetch latest
echo "🔄 Fetching latest from remote..."
git fetch origin || { echo "❌ Failed to fetch"; exit 1; }

# Check if behind
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "$LOCAL")

if [[ "$LOCAL" != "$REMOTE" ]]; then
    echo "⚠️  Remote has changes, merging..."
    git merge origin/main --no-edit || {
        echo "❌ Merge conflict! Resolve manually:"
        echo "   cd $REPO_DIR"
        echo "   git status"
        exit 1
    }
fi

# Add and commit
echo "📝 Adding changes..."
git add -A

echo "💾 Committing..."
git commit -m "$COMMIT_MSG" --no-edit || {
    echo "⚠️  Nothing to commit or commit failed"
    exit 0
}

# Push
echo "🚀 Pushing to GitHub..."
git push || {
    echo "❌ Push failed"
    echo "   Try: git pull origin main && git push"
    exit 1
}

echo ""
echo "✅ SUCCESS! Changes committed and pushed."
echo "   Commit: $(git rev-parse --short HEAD)"
echo "   Message: $COMMIT_MSG"
echo ""
