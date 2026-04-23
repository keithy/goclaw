#!/bin/sh
# dispatch.sh - execline action dispatcher
# Queue files contain execline scripts, processed in reverse timestamp order

WATCH_DIR="${1:-/srv/auto_goclaw-data/_data/.runtime/host-actions}"
QUEUE_DIR="$WATCH_DIR/queue"
ACTIONS_DIR="${2:-$GOCLAW_DIR/options/host-actions/actions}"
DONE_DIR="$WATCH_DIR/done"

export PATH="$ACTIONS_DIR:${HOST_ACTIONS_PATH:-$PATH}"
mkdir -p "$DONE_DIR" "$WATCH_DIR/rejected"

for f in $(ls -1r "$QUEUE_DIR" 2>/dev/null); do
    f="$QUEUE_DIR/$f"
    [ -f "$f" ] || continue

    MARKER="$(basename "$f")"

    # Blacklist check: reject if content matches regex
    if [ -n "${HOST_ACTIONS_BLACKLIST:-}" ]; then
        if grep -E "$HOST_ACTIONS_BLACKLIST" "$f" >/dev/null 2>&1; then
            DEST="$WATCH_DIR/rejected/${MARKER}"
            echo "--- rejected (HOST_ACTIONS_BLACKLIST) ---" > "$DEST"
            cat "$f" >> "$DEST"
            rm -f "$f"
            continue
        fi
    fi

    # Script-only check: reject execline blocks if disabled
    if [ "${HOST_ACTIONS_SCRIPTS:-true}" = "false" ]; then
        if grep -q '{' "$f" 2>/dev/null; then
            DEST="$WATCH_DIR/rejected/${MARKER}"
            echo "--- rejected (HOST_ACTIONS_SCRIPTS=false) ---" > "$DEST"
            cat "$f" >> "$DEST"
            rm -f "$f"
            continue
        fi
    fi

    # Whitelist check
    if [ -n "${HOST_ACTIONS_WHITELIST:-}" ]; then
        CMD="$(cat "$f")"
        ACTION="${CMD%% *}"
        if ! echo "$HOST_ACTIONS_WHITELIST" | grep -qF "$ACTION"; then
            DEST="$WATCH_DIR/rejected/${MARKER}"
            echo "--- rejected (HOST_ACTIONS_WHITELIST) ---" > "$DEST"
            cat "$f" >> "$DEST"
            rm -f "$f"
            continue
        fi
    fi

    DEST="$DONE_DIR/${MARKER}"

    echo "--- input ---" > "$DEST"
    cat "$f" >> "$DEST"
    echo "--- output ---" >> "$DEST"

    TIMEOUT="${HOST_ACTIONS_TIMEOUT:-300}"
    if command -v execlineb >/dev/null 2>&1; then
        timeout "$TIMEOUT" execlineb "$f" >> "$DEST" 2>&1
    else
        echo "execlineb not found" >> "$DEST"
    fi

    rm -f "$f"
done
