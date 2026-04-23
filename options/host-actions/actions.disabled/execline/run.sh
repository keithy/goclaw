#!/bin/sh
# run.sh - execute execline command on host
# Usage: run.sh <marker>
# Command is read from stdin (written by container's host-action)
# Security: only execline allowed, no shell fallback
set -e

MARKER="${1:-}"
if [ -z "$MARKER" ]; then
    echo "Usage: run.sh <marker>" >&2
    exit 1
fi

# Require execlineb - no fallback to shell eval
if ! command -v execlineb >/dev/null 2>&1; then
    echo "ERROR: execlineb not found on host" >&2
    exit 1
fi

# Read command from stdin
CMD=$(cat)
if [ -z "$CMD" ]; then
    echo "ERROR: No command provided" >&2
    exit 1
fi

echo "Executing execline: $CMD"
execlineb -c "$CMD"
