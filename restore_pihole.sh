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
PIHOLE_URL="http://localhost"
PIHOLE_HEADER="Host: $PIHOLE_HOST"

echo "==> Waiting for Pi-hole to be ready..."
READY=0
for i in $(seq 1 30); do
    if curl -s --max-time 3 -H "$PIHOLE_HEADER" "$PIHOLE_URL/api/auth" -o /dev/null 2>/dev/null; then
        READY=1
        break
    fi
    sleep 2
done
if [ "$READY" = "0" ]; then
    echo "    ERROR: Pi-hole did not become ready. Is the container running?"
    exit 1
fi

echo "==> Restoring Pi-hole backup..."
AUTH=$(curl -sf -X POST "$PIHOLE_URL/api/auth" \
    -H "$PIHOLE_HEADER" \
    -H "Content-Type: application/json" \
    -d "{\"password\":\"$PIHOLE_WEBPASSWORD\"}")
SID=$(echo "$AUTH" | grep -o '"sid":"[^"]*"' | cut -d'"' -f4)
CSRF=$(echo "$AUTH" | grep -o '"csrf":"[^"]*"' | cut -d'"' -f4)

if [ -z "$SID" ]; then
    echo "    WARNING: Could not authenticate with Pi-hole -- backup not restored."
    exit 1
fi

HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
    -X POST "$PIHOLE_URL/api/teleporter" \
    -H "$PIHOLE_HEADER" \
    -b "sid=$SID" \
    -H "X-CSRF-TOKEN: $CSRF" \
    -F "file=@$PIHOLE_BACKUP")
if [ "$HTTP_STATUS" != "200" ]; then
    curl -s -X DELETE "$PIHOLE_URL/api/auth" \
        -H "$PIHOLE_HEADER" \
        -b "sid=$SID" -H "X-CSRF-TOKEN: $CSRF" > /dev/null || true
    echo "    WARNING: Restore failed (HTTP $HTTP_STATUS)."
    exit 1
fi

echo "==> Injecting local DNS records into Pi-hole config..."
DNS_HOSTS=$(unzip -p "$PIHOLE_BACKUP" etc/dnsmasq.d/01-local-dns.conf 2>/dev/null \
    | grep '^address=/' \
    | sed 's|address=/\([^/]*\)/\(.*\)|"\2 \1"|' \
    | sort -u \
    | paste -sd',' -)

if [ -n "$DNS_HOSTS" ]; then
    curl -s -X PATCH "$PIHOLE_URL/api/config" \
        -H "$PIHOLE_HEADER" \
        -b "sid=$SID" \
        -H "X-CSRF-TOKEN: $CSRF" \
        -H "Content-Type: application/json" \
        -d "{\"config\":{\"dns\":{\"hosts\":[$DNS_HOSTS]}}}" > /dev/null
    echo "    DNS records restored to UI."
else
    echo "    No local DNS records found in backup."
fi

curl -s -X DELETE "$PIHOLE_URL/api/auth" \
    -H "$PIHOLE_HEADER" \
    -b "sid=$SID" -H "X-CSRF-TOKEN: $CSRF" > /dev/null || true

echo ""
echo "================================================================"
echo "  Done. Pi-hole config restored from $PIHOLE_BACKUP"
echo "================================================================"
echo ""
