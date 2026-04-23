#!/bin/sh
# run.sh - update goclaw from upstream
# Usage: run.sh [pr numbers...]
# Example: run.sh 123 456 789
set -e

GOCLAW_DIR="${GOCLAW_DIR:-/code/goclaw}"
cd "$GOCLAW_DIR"

# Sync upstream main to origin main
git fetch upstream
git checkout main
git pull upstream main
git push origin main

# Create feature branch for PR merges
BRANCH="merge-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"

# Merge each PR
for pr in "$@"; do
    git fetch origin "pull/$pr/head:pr-$pr"
    git merge "pr-$pr" -m "Merge #$pr"
done

git checkout main
git branch -d "$BRANCH"
