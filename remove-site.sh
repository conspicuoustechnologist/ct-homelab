#!/bin/bash
# Remove a site from the nginx stack.
# Removes the nginx template, docker-compose.yml entries, .env vars,
# and Pi-hole DNS record. Prompts before removing site file content.
#
# Usage: bash remove-site.sh [name]
# Example: bash remove-site.sh pelander
set -e

HOMELAB_DIR="${HOMELAB_DIR:-$HOME/ct-homelab}"

SITE_NAME="${1:-}"

if [ -z "$SITE_NAME" ]; then
    read -r -p "Site name to remove: " SITE_NAME
fi

if [ -z "$SITE_NAME" ]; then
    echo "ERROR: site name is required." >&2
    exit 1
fi

VAR_PREFIX="${SITE_NAME^^}"
VAR_PREFIX="${VAR_PREFIX//-/_}"

TEMPLATE="$HOMELAB_DIR/nginx/templates/${SITE_NAME}.conf.template"
COMPOSE="$HOMELAB_DIR/docker-compose.yml"
ENV_FILE="$HOMELAB_DIR/.env"
LOCAL_DNS="$HOMELAB_DIR/pihole/etc-dnsmasq.d/01-local-dns.conf"

_env_get() {
    local key="$1"
    [ -f "$ENV_FILE" ] && grep -E "^${key}=" "$ENV_FILE" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

SITE_DIR="$(_env_get "${VAR_PREFIX}_DIR")"
SITE_HOST="$(_env_get "${VAR_PREFIX}_HOST")"

echo ""
echo "================================================================"
echo "  Removing site: $SITE_NAME"
[ -n "$SITE_HOST" ] && echo "  Host:          $SITE_HOST"
[ -n "$SITE_DIR" ]  && echo "  Files:         $SITE_DIR"
echo "================================================================"
echo ""
read -r -p "Continue? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""

# 1. nginx template
if [ -f "$TEMPLATE" ]; then
    rm "$TEMPLATE"
    echo "==> Removed: $TEMPLATE"
else
    echo "==> Template not found, skipping: $TEMPLATE"
fi

# 2. docker-compose.yml
python3 - << PYEOF
import sys

compose_path = "$COMPOSE"
var_prefix = "$VAR_PREFIX"
site_name = "$SITE_NAME"

with open(compose_path) as f:
    lines = f.readlines()

filtered = [
    l for l in lines
    if not (var_prefix + "_DIR}" in l and ":/var/www/" in l)
    and not (var_prefix + "_HOST=" in l)
]

if len(filtered) == len(lines):
    print("==> No entries found in docker-compose.yml, skipping")
else:
    with open(compose_path, 'w') as f:
        f.writelines(filtered)
    print("==> Updated: " + compose_path)
PYEOF

# 3. .env
if grep -qE "^${VAR_PREFIX}_(DIR|HOST)=" "$ENV_FILE" 2>/dev/null; then
    sed -i "/^${VAR_PREFIX}_DIR=/d;/^${VAR_PREFIX}_HOST=/d" "$ENV_FILE"
    echo "==> Updated: $ENV_FILE"
else
    echo "==> No vars found in .env, skipping"
fi

# 4. Pi-hole DNS record
if [ -f "$LOCAL_DNS" ] && [ -n "$SITE_HOST" ]; then
    if grep -q "$SITE_HOST" "$LOCAL_DNS"; then
        sed -i "/\/$SITE_HOST\//d" "$LOCAL_DNS"
        echo "==> Removed DNS record: $SITE_HOST"
        if docker ps --format '{{.Names}}' | grep -q '^pihole$'; then
            docker restart pihole > /dev/null
            echo "==> Restarted pihole"
        fi
    else
        echo "==> DNS record not found, skipping"
    fi
fi

# 5. optionally remove site content
if [ -n "$SITE_DIR" ] && [ -d "$SITE_DIR" ]; then
    echo ""
    read -r -p "Remove site files at $SITE_DIR? This cannot be undone. [y/N] " REMOVE_DIR
    if [[ "$REMOVE_DIR" =~ ^[Yy]$ ]]; then
        rm -rf "$SITE_DIR"
        echo "==> Removed: $SITE_DIR"
    else
        echo "==> Leaving $SITE_DIR in place."
    fi
fi

echo ""
echo "================================================================"
echo "  Done. Run the following to apply nginx changes:"
echo "  cd $HOMELAB_DIR && docker compose up -d --build"
echo "================================================================"
echo ""
