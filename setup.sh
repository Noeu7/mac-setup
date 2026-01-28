#!/usr/bin/env bash
set -e

echo "== mac-setup start =="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

"$SCRIPT_DIR/scripts/brew_install.sh"

echo "== mac-setup done =="
