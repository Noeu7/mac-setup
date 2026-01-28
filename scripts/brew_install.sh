#!/usr/bin/env bash
set -e

echo "== Homebrew install check =="

if command -v brew >/dev/null 2>&1; then
  echo "Homebrew already installed:"
  brew --version
  exit 0
fi

echo "Installing Homebrew..."

NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Apple Silicon / Intel 両対応
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

echo "Homebrew installed:"
brew --version
