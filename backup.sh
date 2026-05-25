#!/bin/bash
# Back up Pi-hole configuration via the Teleporter API.
# Saves a timestamped zip to BACKUP_DIR (default: ./backups/).
# Keeps the last KEEP_BACKUPS zips (default: 5).
#
# Usage:
#   bash backup.sh
#   BACKUP_DIR=/mnt/nas/pihole-backups bash backup.sh
set -e

HOMELAB_DIR="${HOMELAB_DIR:-${1:-$HOME/ct-homelab}}"

_env_get() {
    local key="$1"
    [ -f "$HOMELAB_DIR/.env" ] && grep -E "^${key}=" "$HOMELAB_DIR/.env" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

PIHOLE_HOST="${PIHOLE_HOST:-$(_env_get PIHOLE_HOST)}"
PIHOLE_HOST="${PIHOLE_HOST:-pihole.ct.home}"

PIHOLE_WEBPASSWORD="${PIHOLE_WEBPASSWORD:-$(_env_get PIHOLE_WEBPASSWORD)}"

BACKUP_DIR="${BACKUP_DIR:-$(_env_get BACKUP_DIR)}"
BACKUP_DIR="${BACKUP_DIR:-$HOMELAB_DIR/backups}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"

PIHOLE_URL="http://${PIHOLE_HOST}"

if [ -z "$PIHOLE_WEBPASSWORD" ]; then
    echo "ERROR: PIHOLE_WEBPASSWORD not set in .env or environment." >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

echo "==> Authenticating with Pi-hole..."
AUTH=$(curl -sf -X POST "$PIHOLE_URL/api/auth" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$PIHOLE_WEBPASSWORD\"}")

SID=$(echo "$AUTH" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
CSRF=$(echo "$AUTH" | grep -o '"csrf":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SID" ]; then
    echo "ERROR: Failed to authenticate with Pi-hole. Check PIHOLE_WEBPASSWORD." >&2
    exit 1
fi

TIMESTAMP=$(date +"%Y-%m-%d-%H%M%S")
OUTFILE="$BACKUP_DIR/pihole-$TIMESTAMP.zip"

echo "==> Downloading Teleporter backup..."
HTTP_STATUS=$(curl -s -o "$OUTFILE" -w "%{http_code}" \
    -b "sid=$SID" \
    -H "X-CSRF-TOKEN: $CSRF" \
    "$PIHOLE_URL/api/teleporter")

echo "==> Deleting session..."
curl -s -X DELETE "$PIHOLE_URL/api/auth" \
    -b "sid=$SID" \
    -H "X-CSRF-TOKEN: $CSRF" > /dev/null || true

if [ "$HTTP_STATUS" != "200" ]; then
    echo "ERROR: Teleporter export failed (HTTP $HTTP_STATUS)." >&2
    rm -f "$OUTFILE"
    exit 1
fi

echo "    Saved: $OUTFILE"

echo "==> Pruning old backups (keeping last $KEEP_BACKUPS)..."
ls -t "$BACKUP_DIR"/pihole-*.zip 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm --
echo "    Done."
