#!/usr/bin/env bash
# Build goclaw binary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOCLAW_DIR="$SCRIPT_DIR/../.."
BIN_DIR="$GOCLAW_DIR/bin"

mkdir -p "$BIN_DIR"

echo "Building goclaw..."
cd "$GOCLAW_DIR"
go build -o "$BIN_DIR/goclaw" .

echo "✓ Built goclaw → $BIN_DIR/goclaw"
