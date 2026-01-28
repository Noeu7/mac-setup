#!/usr/bin/env bash
set -euo pipefail

CHANNEL="${1:-packaged}"  # packaged / standalone
APPCAST_BASE="https://release-manager.us.gs.talon-sec.com/api/v1/appcast.xml"
APPID="%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D"

URL="${APPCAST_BASE}?appid=${APPID}&platform=mac&architecture=universal&channel=${CHANNEL}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
"$SCRIPT_DIR/appcast_install.sh" "Talon (${CHANNEL})" "$URL"
