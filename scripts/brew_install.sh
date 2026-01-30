#!/usr/bin/env bash
set -euo pipefail

echo "== Homebrew install check =="

# IMPORTANT:
# Do NOT rely on `command -v brew` here because PATH may not be set yet.
# Check actual brew paths instead.
if [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
  echo "Homebrew already installed (found brew binary)."
  exit 0
fi

echo "Installing Homebrew (interactive)..."
echo "You may be prompted for sudo password and ENTER confirmation."

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo "Homebrew installation completed."

