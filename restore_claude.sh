#!/bin/bash
# Restore ~/.claude config from a private GitHub repo.
# Prompts for credentials interactively so nothing ends up in shell history.
# Run after bootstrap.sh + claude auth.
set -e

echo ""
echo "==> Restore Claude config from GitHub"
echo ""
read -r -p "    GitHub username: " GH_USER
read -r -s -p "    GitHub Personal Access Token: " GH_PAT
echo ""

REPO_URL="https://${GH_USER}:${GH_PAT}@github.com/${GH_USER}/claude-config.git"
unset GH_PAT

if [ -f "$HOME/.claude/.credentials.json" ]; then
    echo ""
    echo "==> Backing up existing credentials..."
    cp "$HOME/.claude/.credentials.json" "$HOME/claude-credentials.bak"
fi

echo ""
echo "==> Cloning config repo..."
rm -rf "$HOME/.claude"
git clone "$REPO_URL" "$HOME/.claude"

if [ -f "$HOME/claude-credentials.bak" ]; then
    echo ""
    echo "==> Restoring credentials..."
    cp "$HOME/claude-credentials.bak" "$HOME/.claude/.credentials.json"
    rm "$HOME/claude-credentials.bak"
fi

echo ""
echo "================================================================"
echo "  Done. Claude config restored."
echo "  Run 'claude' to verify."
echo "================================================================"
echo ""
