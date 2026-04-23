#!/bin/sh
# test-dispatch.sh - Test hardening for host-actions dispatch

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
DISPATCH="$SCRIPT_DIR/dispatch.sh"
HOST_ACTION="$SCRIPT_DIR/bin/host-action"
ACTIONS="$SCRIPT_DIR/actions"

setup() {
    rm -rf /tmp/test-dispatch
    mkdir -p /tmp/test-dispatch/queue /tmp/test-dispatch/done /tmp/test-dispatch/rejected
    cp -r "$ACTIONS" /tmp/test-dispatch/
}

cleanup() {
    rm -rf /tmp/test-dispatch
}

PASS=0
FAIL=0

run_dispatch() {
    HOST_ACTIONS_WHITELIST="$HOST_ACTIONS_WHITELIST" \
    HOST_ACTIONS_PATH="$HOST_ACTIONS_PATH" \
    HOST_ACTIONS_BLACKLIST="$HOST_ACTIONS_BLACKLIST" \
    HOST_ACTIONS_SCRIPTS="$HOST_ACTIONS_SCRIPTS" \
        sh "$DISPATCH" /tmp/test-dispatch >/dev/null 2>&1 || true
}

echo "Testing host-actions dispatch hardening..."
echo ""

setup
trap cleanup EXIT

# Basic execution test
echo "--- Basic execution ---"
HOST_ACTIONS_QUEUE_DIR=/tmp/test-dispatch/queue \
    HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= HOST_ACTIONS_SCRIPTS= \
    "$HOST_ACTION" restart mycontainer
run_dispatch
if [ "$(ls -A /tmp/test-dispatch/done 2>/dev/null)" ]; then
    echo "✓ PASS: basic dispatch works"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: basic dispatch failed"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo ""
echo "--- Whitelist tests ---"
HOST_ACTIONS_QUEUE_DIR=/tmp/test-dispatch/queue \
    HOST_ACTIONS_WHITELIST="commit restart" HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= HOST_ACTIONS_SCRIPTS= \
    "$HOST_ACTION" commit mycontainer
run_dispatch
if [ "$(ls -A /tmp/test-dispatch/done 2>/dev/null)" ]; then
    echo "✓ PASS: whitelist allows 'commit'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: whitelist should allow 'commit'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

# For tests with special chars, write directly
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_WHITELIST="commit restart" HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
if [ "$(ls -A /tmp/test-dispatch/rejected 2>/dev/null)" ]; then
    echo "✓ PASS: whitelist rejects 'echo'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: whitelist should reject 'echo'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/* /tmp/test-dispatch/rejected/*

echo ""
echo "--- Blacklist tests ---"
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_BLACKLIST='\{' HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
if [ "$(ls -A /tmp/test-dispatch/done 2>/dev/null)" ]; then
    echo "✓ PASS: blacklist allows 'echo' (no { in content)"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: blacklist should allow 'echo'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo "echo { hello" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_BLACKLIST='\{' HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
if [ "$(ls -A /tmp/test-dispatch/rejected 2>/dev/null)" ]; then
    echo "✓ PASS: blacklist rejects '{'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: blacklist should reject '{'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/* /tmp/test-dispatch/rejected/*

echo ""
echo "--- Script-only mode tests ---"
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_SCRIPTS="false" HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= \
    run_dispatch
if [ "$(ls -A /tmp/test-dispatch/done 2>/dev/null)" ]; then
    echo "✓ PASS: script-only mode allows 'echo' (no { in content)"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: script-only mode should allow 'echo'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo "echo { hello" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_SCRIPTS="false" HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= \
    run_dispatch
if [ "$(ls -A /tmp/test-dispatch/rejected 2>/dev/null)" ]; then
    echo "✓ PASS: script-only mode rejects '{'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: script-only mode should reject '{'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/* /tmp/test-dispatch/rejected/*

echo ""
echo "--- host-action tests ---"
rm -f /tmp/test-dispatch/queue/*
HOST_ACTIONS_QUEUE_DIR=/tmp/test-dispatch/queue "$HOST_ACTION" commit mycontainer next
if [ "$(ls /tmp/test-dispatch/queue/ | grep -c 'commit_mycontainer_next')" = "1" ]; then
    echo "✓ PASS: host-action creates queue file"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: host-action should create queue file"
    FAIL=$((FAIL+1))
fi

rm -f /tmp/test-dispatch/queue/*
HOST_ACTIONS_QUEUE_DIR=/tmp/test-dispatch/queue "$HOST_ACTION" restart mycontainer
QUEUE_FILE="$(ls /tmp/test-dispatch/queue/)"
CONTENT="$(cat /tmp/test-dispatch/queue/$QUEUE_FILE)"
if [ "$CONTENT" = "restart mycontainer" ]; then
    echo "✓ PASS: host-action writes correct content"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: host-action content was '$CONTENT'"
    FAIL=$((FAIL+1))
fi

rm -rf /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/* /tmp/test-dispatch/rejected/*

echo ""
echo "======================================"
echo "Results: $PASS passed, $FAIL failed"
echo "======================================"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1