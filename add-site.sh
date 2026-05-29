#!/bin/bash
# Add a new site to the nginx stack.
# Creates the nginx template, updates docker-compose.yml and .env,
# creates the content directory, and adds a Pi-hole DNS record.
#
# Usage: bash add-site.sh <name> <host> <dir>
# Example: bash add-site.sh pelander pelander.ct.home /home/jd/sites/pelander
set -e

HOMELAB_DIR="${HOMELAB_DIR:-$HOME/ct-homelab}"

_env_get() {
    local key="$1"
    [ -f "$HOMELAB_DIR/.env" ] && grep -E "^${key}=" "$HOMELAB_DIR/.env" | cut -d= -f2 | sed 's/[[:space:]]*#.*//' | xargs || true
}

SITE_NAME="${1:-}"
SITE_HOST="${2:-}"
SITE_DIR="${3:-}"

if [ -z "$SITE_NAME" ]; then
    read -r -p "Site name (short slug, e.g. pelander): " SITE_NAME
fi
if [ -z "$SITE_HOST" ]; then
    read -r -p "Local hostname (e.g. pelander.ct.home): " SITE_HOST
fi
if [ -z "$SITE_DIR" ]; then
    read -r -p "Site files directory (e.g. /home/jd/sites/pelander): " SITE_DIR
fi

if [ -z "$SITE_NAME" ] || [ -z "$SITE_HOST" ] || [ -z "$SITE_DIR" ]; then
    echo "ERROR: all three values are required." >&2
    exit 1
fi

VAR_PREFIX="${SITE_NAME^^}"
VAR_PREFIX="${VAR_PREFIX//-/_}"

TEMPLATE="$HOMELAB_DIR/nginx/templates/${SITE_NAME}.conf.template"
COMPOSE="$HOMELAB_DIR/docker-compose.yml"
ENV_FILE="$HOMELAB_DIR/.env"
LOCAL_DNS="$HOMELAB_DIR/pihole/etc-dnsmasq.d/01-local-dns.conf"

PI_IP="${PI_IP:-$(_env_get PI_IP)}"
PI_IP="${PI_IP:-$(hostname -I | awk '{print $1}')}"

echo ""

# 1. nginx template
if [ -f "$TEMPLATE" ]; then
    echo "ERROR: $TEMPLATE already exists" >&2
    exit 1
fi

cat > "$TEMPLATE" << EOF
server {
    listen 80;
    server_name \${${VAR_PREFIX}_HOST};
    root /var/www/${SITE_NAME};
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
echo "==> Created: $TEMPLATE"

# 2. docker-compose.yml -- insert after last *_DIR volume and last *_HOST env var
python3 - << PYEOF
import sys

compose_path = "$COMPOSE"
site_name = "$SITE_NAME"
var_prefix = "$VAR_PREFIX"

with open(compose_path) as f:
    lines = f.readlines()

last_vol = last_env = -1
for i, line in enumerate(lines):
    s = line.strip()
    if s.startswith('- \${') and ':/var/www/' in s:
        last_vol = i
    if s.startswith('- ') and '_HOST=' in s:
        last_env = i

if last_vol == -1 or last_env == -1:
    print("ERROR: could not find insertion points in docker-compose.yml", file=sys.stderr)
    sys.exit(1)

indent = '      '
new_vol = indent + "- \${" + var_prefix + "_DIR}:/var/www/" + site_name + ":ro\n"
new_env = indent + "- " + var_prefix + "_HOST=\${" + var_prefix + "_HOST}\n"

lines.insert(last_env + 1, new_env)
lines.insert(last_vol + 1, new_vol)

with open(compose_path, 'w') as f:
    f.writelines(lines)

print("==> Updated: " + compose_path)
PYEOF

# 3. .env
if grep -qE "^${VAR_PREFIX}_DIR=" "$ENV_FILE" 2>/dev/null; then
    echo "WARNING: ${VAR_PREFIX}_DIR already in .env, skipping"
else
    printf "\n%s_DIR=%s\n%s_HOST=%s\n" "$VAR_PREFIX" "$SITE_DIR" "$VAR_PREFIX" "$SITE_HOST" >> "$ENV_FILE"
    echo "==> Updated: $ENV_FILE"
fi

# 4. content directory
mkdir -p "$SITE_DIR"
echo "==> Created: $SITE_DIR"

# 5. Pi-hole DNS record
if [ -f "$LOCAL_DNS" ]; then
    if grep -q "$SITE_HOST" "$LOCAL_DNS"; then
        echo "==> DNS record for $SITE_HOST already exists, skipping"
    else
        echo "address=/$SITE_HOST/$PI_IP" >> "$LOCAL_DNS"
        echo "==> Added DNS record: $SITE_HOST -> $PI_IP"
        if docker ps --format '{{.Names}}' | grep -q '^pihole$'; then
            docker restart pihole > /dev/null
            echo "==> Restarted pihole"
        fi
    fi
else
    echo "WARNING: $LOCAL_DNS not found -- add DNS record manually in Pi-hole"
fi

# 6. optionally clone a git repo into the site directory
echo ""
read -r -p "Clone a git repository into $SITE_DIR? [y/N] " CLONE_REPO
if [[ "$CLONE_REPO" =~ ^[Yy]$ ]]; then
    read -r -p "Repository URL: " REPO_URL
    if [ -n "$REPO_URL" ]; then
        git clone "$REPO_URL" "$SITE_DIR"
        echo "==> Cloned $REPO_URL into $SITE_DIR"
    else
        echo "No URL provided, skipping."
    fi
fi

echo ""
echo "================================================================"
echo "  Site added: $SITE_NAME"
echo "  Host:       $SITE_HOST -> $PI_IP"
echo "  Files:      $SITE_DIR"
echo ""
echo "  Next: deploy files to $SITE_DIR, then:"
echo "  cd $HOMELAB_DIR && docker compose up -d --build"
echo "================================================================"
echo ""
