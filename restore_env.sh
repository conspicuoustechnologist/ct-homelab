#!/bin/bash
# Restore .env from backup and recreate site content directories.
# Run before restore_pihole.sh -- other scripts depend on .env being present.
set -e

HOMELAB_DIR="${HOMELAB_DIR:-$HOME/ct-homelab}"
BACKUP_DIR="${BACKUP_DIR:-$HOMELAB_DIR/backups}"
ENV_BACKUP="$BACKUP_DIR/.env.backup"

echo ""
echo "==> Restore .env"
echo ""

if [ ! -f "$ENV_BACKUP" ]; then
    echo "    ERROR: backup not found: $ENV_BACKUP"
    echo "    Copy your .env.backup to $BACKUP_DIR/ and re-run."
    exit 1
fi

cp "$ENV_BACKUP" "$HOMELAB_DIR/.env"
echo "    Restored: $HOMELAB_DIR/.env"

echo ""
echo "==> Creating site content directories..."
grep -E '^[A-Z_]+_DIR=.' "$HOMELAB_DIR/.env" \
    | cut -d= -f2- \
    | sed 's/[[:space:]]*#.*//' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | while read -r dir; do
        mkdir -p "$dir"
        echo "    $dir"
    done

echo ""
echo "================================================================"
echo "  Done. .env restored and site directories created."
echo "  Review $HOMELAB_DIR/.env before starting services."
echo "================================================================"
echo ""
