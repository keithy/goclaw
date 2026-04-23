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

check_json_status() {
    file="$1"
    expected="$2"
    actual="$(grep -o '"status": *"[^"]*"' "$file" | cut -d'"' -f4)"
    [ "$actual" = "$expected" ]
}

check_json_request() {
    file="$1"
    expected="$2"
    actual="$(grep -o '"request": *"[^"]*"' "$file" | cut -d'"' -f4)"
    [ "$actual" = "$expected" ]
}

echo "Testing host-actions dispatch hardening..."
echo ""

setup
trap cleanup EXIT

# Basic execution test
echo "--- Basic execution ---"
echo "echo hello from dispatch" > /tmp/test-dispatch/queue/100-test
run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "success"; then
    echo "✓ PASS: basic dispatch works"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: basic dispatch failed"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo ""
echo "--- Whitelist tests ---"
echo "echo whitelist test" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_WHITELIST="echo" HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "success"; then
    echo "✓ PASS: whitelist allows 'echo'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: whitelist should allow 'echo'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

# Whitelist reject test
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_WHITELIST="commit restart" HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "rejected" && \
   grep -q "HOST_ACTIONS_WHITELIST" "$RESULT_FILE"; then
    echo "✓ PASS: whitelist rejects 'echo'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: whitelist should reject 'echo'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo ""
echo "--- Blacklist tests ---"
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_BLACKLIST='\{' HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_SCRIPTS= \
    run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "success"; then
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
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "rejected" && \
   grep -q "HOST_ACTIONS_BLACKLIST" "$RESULT_FILE"; then
    echo "✓ PASS: blacklist rejects '{'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: blacklist should reject '{'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo ""
echo "--- Script-only mode tests ---"
echo "echo x" > /tmp/test-dispatch/queue/100-test
HOST_ACTIONS_SCRIPTS="false" HOST_ACTIONS_WHITELIST= HOST_ACTIONS_PATH= HOST_ACTIONS_BLACKLIST= \
    run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "success"; then
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
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_status "$RESULT_FILE" "rejected" && \
   grep -q "HOST_ACTIONS_SCRIPTS" "$RESULT_FILE"; then
    echo "✓ PASS: script-only mode rejects '{'"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: script-only mode should reject '{'"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

echo ""
echo "--- JSON response format tests ---"
echo "restart mycontainer" > /tmp/test-dispatch/queue/100-test
run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && \
   grep -q '"id":' "$RESULT_FILE" && \
   grep -q '"request":' "$RESULT_FILE" && \
   grep -q '"status":' "$RESULT_FILE" && \
   grep -q '"exit_code":' "$RESULT_FILE" && \
   grep -q '"stdout":' "$RESULT_FILE" && \
   grep -q '"stderr":' "$RESULT_FILE" && \
   grep -q '"duration_ms":' "$RESULT_FILE" && \
   grep -q '"timestamp":' "$RESULT_FILE"; then
    echo "✓ PASS: JSON response has all required fields"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: JSON response missing fields"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

# Test request field is preserved
echo "echo hello" > /tmp/test-dispatch/queue/100-test
run_dispatch
RESULT_FILE="$(ls /tmp/test-dispatch/done/*.json 2>/dev/null)"
if [ -n "$RESULT_FILE" ] && check_json_request "$RESULT_FILE" "echo hello"; then
    echo "✓ PASS: request field preserved in response"
    PASS=$((PASS+1))
else
    echo "✗ FAIL: request field not preserved"
    FAIL=$((FAIL+1))
fi
rm -f /tmp/test-dispatch/queue/* /tmp/test-dispatch/done/*

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
