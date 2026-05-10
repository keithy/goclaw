#!/usr/bin/env bash
# Setup host-actions compose overlay
set -euo pipefail

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT}")" && pwd)"
GOCLAW_DIR="$SCRIPT_DIR/../.."

COMPOSE_D="$GOCLAW_DIR/compose.d"
mkdir -p "$COMPOSE_D"

RUN_DIR="$(podman volume inspect auto_goclaw-data --format '{{.Mountpoint}}' 2>/dev/null)/.runtime/host-actions"

src="$SCRIPT_DIR/host-action.yml"
dest="$COMPOSE_D/host-action.yml"

if [[ -f "$dest" ]] || [[ -L "$dest" ]]; then
    echo "host-action.yml already installed in $COMPOSE_D"
else
    ln -s "$src" "$COMPOSE_D/"
    echo "Linked host-action.yml to $COMPOSE_D"
fi

"$GOCLAW_DIR/prepare-compose.sh"
