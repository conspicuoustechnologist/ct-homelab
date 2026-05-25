#!/bin/bash
# Bootstrap a fresh Raspberry Pi OS Lite install.
# Installs zsh, oh-my-zsh, Docker, clones this repo.
# Run once on a fresh Pi, then use git to manage everything else.
set -e

# ---------------------------------------------------------------
# Configuration — change these if you want different paths
HOMELAB_DIR="${1:-$HOME/ct-homelab}"   # where the stack lives
MAIN_SITE_DIR="$HOME/sites/ct-site"   # where site files are served from
# ---------------------------------------------------------------

REPO_URL="https://github.com/conspicuoustechnologist/ct-homelab.git"
REPO_DIR="$HOMELAB_DIR"

echo ""
echo "==> Updating packages..."
sudo apt update && sudo apt upgrade -y

echo ""
echo "==> Installing zsh and git..."
sudo apt install zsh git -y

echo ""
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo "==> oh-my-zsh already installed, skipping."
else
    echo "==> Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

echo ""
echo "==> Writing ~/.zshrc.homelab..."
cat > ~/.zshrc.homelab << EOF
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME=""
plugins=(git docker)
source \$ZSH/oh-my-zsh.sh

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

# homelab
export HOMELAB_DIR=$REPO_DIR
export MAIN_SITE_DIR=$MAIN_SITE_DIR

# prompt: [user@host][time][~/path](git)->
PROMPT='\$FG[015][\$FG[010]%n@%m\$FG[015]][\$FG[244]%t\$FG[015]][\$FG[087]%~\$FG[015]]\$FG[010]\$(git_prompt_info)\$FG[015]-> '
EOF

if ! grep -q 'source ~/.zshrc.homelab' ~/.zshrc 2>/dev/null; then
    echo 'source ~/.zshrc.homelab' >> ~/.zshrc
fi

echo ""
echo "==> Checking port 53..."
if sudo ss -tulpn | grep -qE ':53[^0-9]'; then
    if sudo ss -tulpn | grep -E ':53[^0-9]' | grep -q systemd-resolved; then
        echo "    systemd-resolved is on port 53 — disabling stub listener..."
        sudo mkdir -p /etc/systemd/resolved.conf.d
        sudo tee /etc/systemd/resolved.conf.d/no-stub.conf > /dev/null <<EOF
[Resolve]
DNSStubListener=no
EOF
        sudo systemctl restart systemd-resolved
        echo "    Done. Port 53 is free."
    else
        echo "    WARNING: something else is on port 53:"
        sudo ss -tulpn | grep -E ':53[^0-9]'
        echo "    Pi-hole needs port 53. Stop that service before starting the stack."
    fi
else
    echo "    Port 53 is free."
fi

echo ""
if command -v docker &>/dev/null; then
    echo "==> Docker already installed, skipping."
else
    echo "==> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi
sudo usermod -aG docker $USER

echo ""
echo "==> Cloning ct-homelab..."
if [ -d "$REPO_DIR/.git" ]; then
    echo "    Repo already exists, pulling latest..."
    git -C "$REPO_DIR" pull
else
    git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

if [ ! -f ".env" ]; then
    cp .env.example .env
    sed -i "s|MAIN_SITE_DIR=.*|MAIN_SITE_DIR=$MAIN_SITE_DIR|" .env
else
    echo "    .env already exists, skipping."
fi

echo ""
echo "==> Creating site content directory..."
mkdir -p "$MAIN_SITE_DIR"

echo ""
echo "================================================================"
echo "  Done. Next steps:"
echo ""
echo "  1. Edit your config:  vi $REPO_DIR/.env"
echo "  2. Activate docker group (or log out and back in):"
echo "     newgrp docker"
echo "  3. Start services:    cd $REPO_DIR && docker compose up -d"
echo "================================================================"
echo ""
