#!/bin/bash
# Sets up Samba file sharing on the Pi.
# Run from the ct-homelab directory: bash samba/setup.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOMELAB_DIR="$(dirname "$SCRIPT_DIR")"

_env_get() {
    local key="$1"
    [ -f "$HOMELAB_DIR/.env" ] && grep -E "^${key}=" "$HOMELAB_DIR/.env" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

SAMBA_USER="${SAMBA_USER:-$(_env_get SAMBA_USER)}"
SAMBA_USER="${SAMBA_USER:-$(whoami)}"

SAMBA_SHARE_DIR="${SAMBA_SHARE_DIR:-$(_env_get SAMBA_SHARE_DIR)}"
SAMBA_SHARE_DIR="${SAMBA_SHARE_DIR:-$HOME/transfer}"

HOSTNAME="${HOSTNAME:-$(_env_get HOSTNAME)}"
HOSTNAME="${HOSTNAME:-$(hostname)}"

echo ""
echo "==> Installing Samba..."
sudo apt update && sudo apt install -y samba samba-common-bin

echo ""
echo "==> Creating share directory: $SAMBA_SHARE_DIR"
mkdir -p "$SAMBA_SHARE_DIR"

echo ""
echo "==> Checking sambashare group..."
if ! getent group sambashare > /dev/null 2>&1; then
    echo "    Creating sambashare group..."
    sudo groupadd sambashare
else
    echo "    sambashare group exists."
fi

echo ""
echo "==> Adding $SAMBA_USER to sambashare group..."
sudo usermod -aG sambashare "$SAMBA_USER"

echo ""
echo "==> Setting directory permissions..."
sudo chown -R "$SAMBA_USER":sambashare "$SAMBA_SHARE_DIR"
sudo chmod -R 0770 "$SAMBA_SHARE_DIR"

echo ""
echo "==> Writing /etc/samba/smb.conf..."
sudo cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
HOSTNAME="$HOSTNAME" SAMBA_SHARE_DIR="$SAMBA_SHARE_DIR" \
    envsubst < "$SCRIPT_DIR/smb.conf.template" | sudo tee /etc/samba/smb.conf > /dev/null

echo ""
echo "==> Validating config..."
testparm -s

echo ""
echo "==> Restarting Samba services..."
sudo systemctl restart smbd nmbd
sudo systemctl enable smbd nmbd

echo ""
echo "================================================================"
echo "  Samba is running. Set your Samba password:"
echo "  sudo smbpasswd -a $SAMBA_USER"
echo ""
echo "  Share available at: \\\\$(hostname)\\shared"
echo "================================================================"
echo ""
