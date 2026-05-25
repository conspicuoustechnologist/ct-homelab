#!/bin/bash
# Bootstrap a fresh Raspberry Pi OS Lite install.
# Installs zsh, oh-my-zsh, Docker, clones this repo.
# Run once on a fresh Pi, then use git to manage everything else.
set -e

# ---------------------------------------------------------------
# Configuration — priority: env var > existing .env > auto-detect
#   HOMELAB_DIR=~/my-homelab MAIN_SITE_HOST=mysite.home bash <(curl ...)
HOMELAB_DIR="${HOMELAB_DIR:-${1:-$HOME/ct-homelab}}"

_env_get() {
    local key="$1"
    [ -f "$HOMELAB_DIR/.env" ] && grep -E "^${key}=" "$HOMELAB_DIR/.env" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

MAIN_SITE_DIR="${MAIN_SITE_DIR:-$(_env_get MAIN_SITE_DIR)}"
MAIN_SITE_DIR="${MAIN_SITE_DIR:-$HOME/sites/ct-site}"

MAIN_SITE_HOST="${MAIN_SITE_HOST:-$(_env_get MAIN_SITE_HOST)}"
MAIN_SITE_HOST="${MAIN_SITE_HOST:-conspicuoustechnologist.ct.home}"

PIHOLE_HOST="${PIHOLE_HOST:-$(_env_get PIHOLE_HOST)}"
PIHOLE_HOST="${PIHOLE_HOST:-pihole.ct.home}"

PIHOLE_WEBPASSWORD="${PIHOLE_WEBPASSWORD:-$(_env_get PIHOLE_WEBPASSWORD)}"

PI_IP="${PI_IP:-$(_env_get PI_IP)}"
PI_IP="${PI_IP:-$(hostname -I | awk '{print $1}')}"

MAIN_SITE_IP="${MAIN_SITE_IP:-$(_env_get MAIN_SITE_IP)}"
MAIN_SITE_IP="${MAIN_SITE_IP:-$PI_IP}"
# ---------------------------------------------------------------

REPO_URL="${REPO_URL:-https://github.com/conspicuoustechnologist/ct-homelab.git}"
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
if [ -d "$HOME/.nvm" ]; then
    echo "==> nvm already installed, skipping."
else
    echo "==> Installing nvm..."
    NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
    export PROFILE=~/.zshrc
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo ""
if command -v node &>/dev/null; then
    echo "==> Node.js already installed, skipping."
else
    echo "==> Installing Node.js LTS..."
    nvm install --lts
fi

echo ""
if command -v claude &>/dev/null; then
    echo "==> Claude Code already installed, skipping."
else
    echo "==> Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
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
    echo "    Repo already exists, syncing to remote..."
    git -C "$REPO_DIR" fetch origin && git -C "$REPO_DIR" reset --hard origin/main
else
    git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

if [ ! -f ".env" ]; then
    cp .env.example .env
    sed -i "s|MAIN_SITE_DIR=.*|MAIN_SITE_DIR=$MAIN_SITE_DIR|" .env
    sed -i "s|MAIN_SITE_HOST=.*|MAIN_SITE_HOST=$MAIN_SITE_HOST|" .env
    sed -i "s|PI_IP=.*|PI_IP=$PI_IP|" .env
    sed -i "s|MAIN_SITE_IP=.*|MAIN_SITE_IP=$MAIN_SITE_IP|" .env
    sed -i "s|PIHOLE_HOST=.*|PIHOLE_HOST=$PIHOLE_HOST|" .env
    if [ -n "$PIHOLE_WEBPASSWORD" ]; then
        sed -i "s|PIHOLE_WEBPASSWORD=.*|PIHOLE_WEBPASSWORD=$PIHOLE_WEBPASSWORD|" .env
    fi
else
    echo "    .env already exists, skipping."
fi

if [ "${NO_PROMPT:-0}" != "1" ]; then
    echo ""
    echo "================================================================"
    echo "  Review your config before continuing:"
    echo "  vi $REPO_DIR/.env"
    echo ""
    echo "  Press Enter when done (or set NO_PROMPT=1 to skip this)."
    echo "================================================================"
    read -r
fi

echo ""
echo "==> Writing Pi-hole local DNS records..."
mkdir -p ./pihole/etc-dnsmasq.d
LOCAL_DNS=./pihole/etc-dnsmasq.d/01-local-dns.conf
if ! grep -q "$PIHOLE_HOST" "$LOCAL_DNS" 2>/dev/null; then
    echo "address=/$PIHOLE_HOST/$PI_IP" >> "$LOCAL_DNS"
fi
if ! grep -q "$MAIN_SITE_HOST" "$LOCAL_DNS" 2>/dev/null; then
    echo "address=/$MAIN_SITE_HOST/$MAIN_SITE_IP" >> "$LOCAL_DNS"
fi

echo ""
echo "==> Creating site content directory..."
mkdir -p "$MAIN_SITE_DIR"

echo ""
echo "==> Starting services..."
docker compose up -d

echo ""
echo "================================================================"
echo "  Done."
echo ""
echo "  To update:  cd $REPO_DIR && git pull && docker compose up -d"
echo "  To backup:  bash $REPO_DIR/backup.sh"
echo "  To restore: bash $REPO_DIR/restore_all.sh"
echo "================================================================"
echo ""
