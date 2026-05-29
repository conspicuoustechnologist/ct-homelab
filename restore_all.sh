#!/bin/bash
# Restore Pi-hole config and Claude config after a fresh bootstrap.
# Runs restore_pihole.sh then restore_claude.sh.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/restore_env.sh"
bash "$SCRIPT_DIR/restore_pihole.sh"
bash "$SCRIPT_DIR/restore_claude.sh"
