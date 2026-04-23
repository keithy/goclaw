#!/bin/sh
# dispatch.sh - execline action dispatcher
# Queue files contain execline scripts, processed in reverse timestamp order

WATCH_DIR="${1:-/srv/auto_goclaw-data/_data/.runtime/host-actions}"
QUEUE_DIR="$WATCH_DIR/queue"
ACTIONS_DIR="${2:-$GOCLAW_DIR/options/host-actions/actions}"
DONE_DIR="$WATCH_DIR/done"

export PATH="$ACTIONS_DIR:${HOST_ACTIONS_PATH:-$PATH}"
mkdir -p "$DONE_DIR" "$WATCH_DIR/rejected"

# Escape JSON string - portable POSIX version
json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g' | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//'
}

for f in $(ls -1r "$QUEUE_DIR" 2>/dev/null); do
    f="$QUEUE_DIR/$f"
    [ -f "$f" ] || continue

    MARKER="$(basename "$f")"
    ID="$MARKER"
    REQUEST="$(cat "$f")"

    # Blacklist check: reject if content matches regex
    if [ -n "${HOST_ACTIONS_BLACKLIST:-}" ]; then
        if grep -E "$HOST_ACTIONS_BLACKLIST" "$f" >/dev/null 2>&1; then
            ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            stdout="$(json_escape "$(cat "$f")")"
            DEST="$DONE_DIR/${ID}.json"
            cat > "$DEST" <<JSON
{
  "id": "${ID}",
  "request": "$stdout",
  "status": "rejected",
  "reason": "HOST_ACTIONS_BLACKLIST",
  "timestamp": "$ts"
}
JSON
            rm -f "$f"
            continue
        fi
    fi

    # Script-only check: reject execline blocks if disabled
    if [ "${HOST_ACTIONS_SCRIPTS:-true}" = "false" ]; then
        if grep -q '{' "$f" 2>/dev/null; then
            ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            stdout="$(json_escape "$(cat "$f")")"
            DEST="$DONE_DIR/${ID}.json"
            cat > "$DEST" <<JSON
{
  "id": "${ID}",
  "request": "$stdout",
  "status": "rejected",
  "reason": "HOST_ACTIONS_SCRIPTS=false",
  "timestamp": "$ts"
}
JSON
            rm -f "$f"
            continue
        fi
    fi

    # Whitelist check
    if [ -n "${HOST_ACTIONS_WHITELIST:-}" ]; then
        ACTION="${REQUEST%% *}"
        if ! echo "$HOST_ACTIONS_WHITELIST" | grep -qF "$ACTION"; then
            ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
            stdout="$(json_escape "$(cat "$f")")"
            DEST="$DONE_DIR/${ID}.json"
            cat > "$DEST" <<JSON
{
  "id": "${ID}",
  "request": "$stdout",
  "status": "rejected",
  "reason": "HOST_ACTIONS_WHITELIST",
  "timestamp": "$ts"
}
JSON
            rm -f "$f"
            continue
        fi
    fi

    TIMEOUT="${HOST_ACTIONS_TIMEOUT:-300}"
    START="$(date +%s%3N)"

    # Capture output
    STDOUT_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"
    EXIT_CODE=0

    if command -v execlineb >/dev/null 2>&1; then
        timeout "$TIMEOUT" execlineb "$f" >> "$STDOUT_FILE" 2>> "$STDERR_FILE" || EXIT_CODE=$?
    else
        echo "execlineb not found" >> "$STDOUT_FILE"
        EXIT_CODE=127
    fi

    END="$(date +%s%3N)"
    DURATION=$((END - START))
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    stdout="$(json_escape "$(cat "$STDOUT_FILE")")"
    stderr="$(json_escape "$(cat "$STDERR_FILE")")"
    request="$(json_escape "$REQUEST")"

    if [ $EXIT_CODE -eq 0 ]; then
        status="success"
    else
        status="failed"
    fi

    DEST="$DONE_DIR/${ID}.json"
    cat > "$DEST" <<JSON
{
  "id": "${ID}",
  "request": "$request",
  "status": "$status",
  "exit_code": $EXIT_CODE,
  "stdout": "$stdout",
  "stderr": "$stderr",
  "duration_ms": $DURATION,
  "timestamp": "$ts"
}
JSON

    rm -f "$f" "$STDOUT_FILE" "$STDERR_FILE"
done
