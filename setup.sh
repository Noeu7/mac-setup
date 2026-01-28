#!/usr/bin/env bash
set -euo pipefail

echo "== mac-setup start =="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1) Install Homebrew (idempotent)
"$SCRIPT_DIR/scripts/brew_install.sh"

# 2) Make sure brew is available in THIS shell, even right after install
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 3) Install apps from Brewfile (idempotent)
brew bundle --file "$SCRIPT_DIR/Brewfile"

# 4) Install Talon from appcast (idempotent-ish; will reinstall if vendor changes)
"$SCRIPT_DIR/scripts/pab_install.sh" packaged

echo "== mac-setup done =="
