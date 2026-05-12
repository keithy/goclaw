#!/usr/bin/env bash
# Setup the GoClaw action watcher systemd units
set -euo pipefail

SCRIPT="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "${SCRIPT}")" && pwd)"
GOCLAW_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
RUN_DIR="$(podman volume inspect auto_goclaw-data --format '{{.Mountpoint}}' 2>/dev/null)/.runtime/host-actions"

ask() {
    local prompt="$1"
    local default="${2:-}"
    local response
    
    while true; do
        case "$default" in
            y) printf "%s [Y/n]: " "$prompt" ;;
            n) printf "%s [y/N]: " "$prompt" ;;
            *) printf "%s [y/n]: " "$prompt" ;;
        esac
        if ! read -r response </dev/tty 2>/dev/null; then
            echo
            return 1
        fi
        case "${response:-$default}" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]) return 1 ;;
        esac
        echo "Please answer y or n"
    done
}

service_unit() {
    cat << EOF
[Unit]
Description=GoClaw action dispatcher
PartOf=host-action.path
ConditionPathExists=${RUN_DIR}

[Service]
Type=simple
EnvironmentFile=${GOCLAW_DIR}/.env
ExecStart=${GOCLAW_DIR}/options/host-actions/dispatch.sh ${RUN_DIR} ${GOCLAW_DIR}/options/host-actions
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOF
}

path_unit() {
    cat << EOF
[Unit]
Description=Monitor ${RUN_DIR} for actions
PartOf=host-action.service

[Path]
DirectoryNotEmpty=${RUN_DIR}/actions
Unit=host-action.service

[Install]
WantedBy=default.target
EOF
}

install_units() {
    mkdir -p "$SYSTEMD_DIR"

    service_unit > "$SYSTEMD_DIR/host-action.service"
    path_unit > "$SYSTEMD_DIR/host-action.path"
    mkdir -p "${RUN_DIR}/actions"

    echo "✓ Created systemd units in $SYSTEMD_DIR"
}

echo "GoClaw Action Dispatcher Setup"
echo "=============================="
echo ""
echo "This will install:"
echo "  • host-action.service - dispatches actions from container to host"
echo "  • host-action.path - triggers on action changes"
echo ""
echo "Install location: $SYSTEMD_DIR"
echo ""

if ask "Proceed?" y; then
    install_units
    systemctl --user daemon-reload
    systemctl --user enable --now host-action.path
    echo ""
    echo "Started host-action.path"
    echo ""
    echo "To check logs:"
    echo "  journalctl --user -u host-action.service -f"
    echo "To check status:"
    echo "  systemctl --user status host-action.service"
else
    echo "Aborted."
    exit 0
fi
