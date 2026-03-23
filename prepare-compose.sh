#!/usr/bin/env bash
# Generates COMPOSE_FILE from compose.d/*.yml
set -euo pipefail

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT}")" && pwd)"
ENV_FILE="${GOCLAW_ENV_FILE:-$SCRIPT_DIR/.env}"

# Show help
if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $SCRIPT"
  echo ""
  echo "  Generates COMPOSE_FILE from compose.d/*.yml files (sorted)"
  echo "  Updates .env with the resulting COMPOSE_FILE value"
  echo ""
  echo "Note: docker-compose reads .env automatically"
  echo "      for podman-compose: source .env first"
  exit 0
fi

# Check base exists
[[ ! -f "docker-compose.yml" ]] && echo "docker-compose.yml not found" && exit 1

# Build COMPOSE_FILE from compose.d files (sorted)
COMPOSE_FILE=""
for f in compose.d/*.yml; do
  [[ -e "$f" ]] && COMPOSE_FILE="$COMPOSE_FILE${COMPOSE_FILE:+:}$f"
done

# Validate compose files
DOCKER_CMD="${DOCKER_CMD:-docker}"
$DOCKER_CMD compose config > /dev/null 2>&1 || { echo "Compose config validation failed"; exit 1; }
echo "Compose config valid"

# Update .env with COMPOSE_FILE
if [[ -f "$ENV_FILE" ]]; then
  if grep -q "^COMPOSE_FILE=" "$ENV_FILE" 2>/dev/null; then
    # Update existing COMPOSE_FILE line (well-known bash pattern)
    { rm -f "$ENV_FILE"; sed "s|^COMPOSE_FILE=.*|COMPOSE_FILE='$COMPOSE_FILE'|" > "$ENV_FILE"; } < "$ENV_FILE"
  else
    echo "COMPOSE_FILE='$COMPOSE_FILE'" >> "$ENV_FILE"
  fi
  echo "COMPOSE_FILE updated in $ENV_FILE"
  echo "  COMPOSE_FILE=$COMPOSE_FILE"
else
  echo "File not found: $ENV_FILE"
fi

echo "(run '${SCRIPT} --help' for help)"
