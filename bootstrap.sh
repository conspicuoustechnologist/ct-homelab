#!/bin/bash
# Bootstrap a fresh Raspberry Pi OS Lite install.
# Installs zsh, oh-my-zsh, Docker, clones this repo.
# Run once on a fresh Pi, then use git to manage everything else.
set -e

REPO_URL="https://github.com/conspicuoustechnologist/ct-homelab.git"
REPO_DIR="$HOME/ct-homelab"

echo ""
echo "==> Updating packages..."
sudo apt update && sudo apt upgrade -y

echo ""
echo "==> Installing zsh and git..."
sudo apt install zsh git -y

echo ""
echo "==> Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo ""
echo "==> Writing .zshrc..."
truncate -s 0 ~/.zshrc
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git docker)
source $ZSH/oh-my-zsh.sh

# history
unsetopt share_history

# colors
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ll='ls -alF'
alias l='ls -CF'

# docker
alias dc='docker compose'
alias dps='docker ps'
alias dimg='docker images'

# prompt: [user@host][time][~/path](git)->
PROMPT='$FG[015][$FG[010]%n@%m$FG[015]][$FG[244]%t$FG[015]][$FG[087]%~$FG[015]]$FG[010]$(git_prompt_info)$FG[015]-> '
EOF

echo ""
echo "==> Installing Docker..."
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

echo ""
echo "==> Cloning ct-homelab..."
git clone "$REPO_URL" "$REPO_DIR"
cd "$REPO_DIR"
cp .env.example .env

echo ""
echo "================================================================"
echo "  Done. Next steps:"
echo ""
echo "  1. Edit your config:  nano $REPO_DIR/.env"
echo "  2. Activate docker group (or log out and back in):"
echo "     newgrp docker"
echo "  3. Start services:    cd $REPO_DIR && docker compose up -d"
echo "================================================================"
echo ""
