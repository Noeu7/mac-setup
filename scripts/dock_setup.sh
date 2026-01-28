#!/usr/bin/env bash
set -euo pipefail

# Require dockutil
if ! command -v dockutil >/dev/null 2>&1; then
  echo "dockutil not found. Install it first (e.g. brew install dockutil)." >&2
  exit 1
fi

add_if_exists() {
  local app_path="$1"
  if [[ -d "$app_path" ]]; then
    if ! dockutil --find "$app_path" >/dev/null 2>&1; then
      echo "Adding to Dock: $app_path"
      dockutil --add "$app_path" --no-restart
    else
      echo "Already in Dock: $app_path"
    fi
  else
    echo "Not found, skipping: $app_path"
  fi
}

# (Optional) wipe existing Dock apps
# dockutil --remove all --no-restart

add_if_exists "/Applications/Prisma Access Browser.app"
add_if_exists "/Applications/Google Chrome.app"
add_if_exists "/Applications/zoom.us.app"
add_if_exists "/Applications/Okta Verify.app"

# Restart Dock once at the end
killall Dock
echo "Dock updated."
