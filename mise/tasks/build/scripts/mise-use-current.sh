#!/bin/bash
#MISE description="Install binary"
set -e

cd "$MISE_PROJECT_ROOT"

if command -v mise &>/dev/null; then
    mise use -g github:nextlevelbuilder/goclaw@"${1:-current}"
fi
