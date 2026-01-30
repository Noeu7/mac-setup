#!/usr/bin/env bash
set -euo pipefail

echo "== Dock setup =="

# Ensure dockutil exists
if ! command -v dockutil >/dev/null 2>&1; then
  echo "dockutil not found. Installing via Homebrew..."
  brew install dockutil
fi

# 1) Dock orientation: LEFT
echo "Setting Dock orientation to LEFT"
defaults write com.apple.dock orientation -string left

# 2) Remove all existing Dock apps
echo "Resetting Dock apps"
dockutil --remove all --no-restart

# 3) Add minimal system apps
add_if_exists() {
  local app="$1"
  if [[ -d "$app" ]]; then
    echo "Adding to Dock: $app"
    dockutil --add "$app" --no-restart
  else
    echo "Not found, skipping: $app"
  fi
}

add_if_exists "/System/Applications/Launchpad.app"
add_if_exists "/System/Applications/App Store.app"
add_if_exists "/System/Applications/System Settings.app"

# 4) Add work apps
add_if_exists "/Applications/Prisma Access Browser.app"
add_if_exists "/Applications/Google Chrome.app"
add_if_exists "/Applications/zoom.us.app"
add_if_exists "/Applications/Okta Verify.app"

# 5) Add utilities
add_if_exists "/System/Applications/Utilities/Terminal.app"
add_if_exists "/System/Applications/Utilities/Activity Monitor.app"

# 6) Restart Dock once
killall Dock

echo "Dock updated."

