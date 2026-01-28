#!/usr/bin/env bash
set -e

echo "== mac-setup start =="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/scripts/brew_install.sh"

# Install apps from Brewfile (idempotent)
brew bundle --file "$SCRIPT_DIR/Brewfile"

echo "== mac-setup done =="
