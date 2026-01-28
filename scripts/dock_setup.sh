#!/usr/bin/env bash
set -euo pipefail

if ! command -v dockutil >/dev/null 2>&1; then
  echo "dockutil not found. Install it first (e.g. brew install dockutil)." >&2
  exit 1
fi

add_if_exists() {
  local app_path="$1"
  if [[ -d "$app_path" ]]; then
    echo "Adding to Dock: $app_path"
    dockutil --add "$app_path" --no-restart
  else
    echo "Not found, skipping: $app_path"
  fi
}

echo "== Reset Dock apps =="

# 1) Dockのアプリ欄を全消し（スッキリ）
dockutil --remove all --no-restart

# 2) 残したい標準アプリ
add_if_exists "/System/Applications/Launchpad.app"
add_if_exists "/System/Applications/App Store.app"
add_if_exists "/System/Applications/System Settings.app"

# 3) 業務アプリ
add_if_exists "/Applications/Prisma Access Browser.app"
add_if_exists "/Applications/Google Chrome.app"
add_if_exists "/Applications/zoom.us.app"
add_if_exists "/Applications/Okta Verify.app"

# 4) 反映
killall Dock
echo "Dock updated."
