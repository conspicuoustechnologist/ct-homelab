#!/bin/bash
# Restore Samba config after a fresh bootstrap.
# Re-runs samba/setup.sh to reinstall and reconfigure.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "==> Restoring Samba..."
bash "$SCRIPT_DIR/samba/setup.sh"

echo ""
echo "================================================================"
echo "  Samba config restored. You must reset your Samba password:"
echo ""
echo "  sudo smbpasswd -a \$(whoami)"
echo "================================================================"
echo ""
