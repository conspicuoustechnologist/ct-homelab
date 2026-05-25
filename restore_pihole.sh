#!/bin/bash
# Restore Pi-hole config from a teleporter backup file.
# Reads PIHOLE_HOST from .env if available; prompts for password interactively.
# Usage: bash restore_pihole.sh [backup-file]
set -e

HOMELAB_DIR="${HOMELAB_DIR:-$HOME/ct-homelab}"

_env_get() {
    local key="$1"
    [ -f "$HOMELAB_DIR/.env" ] && grep -E "^${key}=" "$HOMELAB_DIR/.env" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

PIHOLE_HOST="${PIHOLE_HOST:-$(_env_get PIHOLE_HOST)}"
PIHOLE_HOST="${PIHOLE_HOST:-pihole.ct.home}"

PIHOLE_BACKUP="${PIHOLE_BACKUP:-${1:-}}"

echo ""
echo "==> Restore Pi-hole config"
echo ""

if [ -z "$PIHOLE_BACKUP" ]; then
    read -r -p "    Path to backup file: " PIHOLE_BACKUP
fi

if [ ! -f "$PIHOLE_BACKUP" ]; then
    echo "    ERROR: backup file not found: $PIHOLE_BACKUP"
    exit 1
fi

if [ -z "$PIHOLE_WEBPASSWORD" ]; then
    read -r -s -p "    Pi-hole web password: " PIHOLE_WEBPASSWORD
    echo ""
fi

echo ""
echo "==> Waiting for Pi-hole to be ready..."
for i in $(seq 1 30); do
    if curl -sf "http://$PIHOLE_HOST/api/auth" -o /dev/null 2>/dev/null; then
        break
    fi
    sleep 2
done

echo "==> Restoring Pi-hole backup..."
AUTH=$(curl -sf -X POST "http://$PIHOLE_HOST/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$PIHOLE_WEBPASSWORD\"}")
SID=$(echo "$AUTH" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
CSRF=$(echo "$AUTH" | grep -o '"csrf":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SID" ]; then
    echo "    WARNING: Could not authenticate with Pi-hole -- backup not restored."
    exit 1
fi

HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
    -X POST "http://$PIHOLE_HOST/api/teleporter" \
    -b "sid=$SID" \
    -H "X-CSRF-TOKEN: $CSRF" \
    -F "file=@$PIHOLE_BACKUP")
curl -s -X DELETE "http://$PIHOLE_HOST/api/auth" \
    -b "sid=$SID" \
    -H "X-CSRF-TOKEN: $CSRF" > /dev/null || true

if [ "$HTTP_STATUS" = "200" ]; then
    echo ""
    echo "================================================================"
    echo "  Done. Pi-hole config restored from $PIHOLE_BACKUP"
    echo "================================================================"
    echo ""
else
    echo "    WARNING: Restore failed (HTTP $HTTP_STATUS)."
    exit 1
fi
