#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   pab_install.sh packaged|standalone

TYPE="${1:-packaged}"
if [[ "$TYPE" != "packaged" && "$TYPE" != "standalone" ]]; then
  echo "Usage: pab_install.sh packaged|standalone" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

APP_NAME="Prisma Access Browser"
APP_PATH="/Applications/Prisma Access Browser.app"

PACKAGED_URL='https://release-manager.us.gs.talon-sec.com/api/v1/appcast.xml?appid=%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D&platform=mac&architecture=universal&channel=packaged'
STANDALONE_URL='https://release-manager.us.gs.talon-sec.com/api/v1/appcast.xml?appid=%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D&platform=mac&architecture=universal&channel=standalone'

if [[ "$TYPE" == "packaged" ]]; then
  URL="$PACKAGED_URL"
else
  URL="$STANDALONE_URL"
fi

"$SCRIPT_DIR/appcast_install.sh" "$URL" "$APP_NAME" --app-path "$APP_PATH" --type "$TYPE"

