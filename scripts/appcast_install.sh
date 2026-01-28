#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   appcast_install.sh "<App Name>" "<Appcast URL>"
#
# Behavior:
# - Fetch appcast online every time
# - Pick latest enclosure URL (prefers max sparkle:version if present)
# - Download the asset
# - Install based on file type: .pkg / .dmg / .zip
# - If installing .app, logs Team ID (no hard fail)

APP_NAME="${1:?app name required}"
APPCAST_URL="${2:?appcast url required}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "== ${APP_NAME}: appcast check =="

curl -fsSL "$APPCAST_URL" -o "$WORKDIR/appcast.xml"

# Extract the latest enclosure URL.
# - Prefer items having sparkle:version and choose the max int
# - Otherwise fallback to first enclosure found (many appcasts put latest first)
DL_URL="$(
python3 - <<'PY'
import xml.etree.ElementTree as ET

path = r"'"$WORKDIR"'/appcast.xml"
tree = ET.parse(path)
root = tree.getroot()

def localname(tag: str) -> str:
    return tag.split("}", 1)[-1] if "}" in tag else tag

items = [e for e in root.iter() if localname(e.tag) == "item"]
if not items:
    raise SystemExit("No <item> found in appcast")

def find_enclosure(item):
    for c in list(item):
        if localname(c.tag) == "enclosure" and "url" in c.attrib:
            return c
    return None

def sparkle_version(enc):
    # Accept namespace-qualified attrs like {...}version and also sparkle:version
    for k, v in enc.attrib.items():
        if k.endswith("}version") or k == "sparkle:version":
            try:
                return int(v)
            except:
                return None
    return None

candidates = []
for item in items:
    enc = find_enclosure(item)
    if not enc:
        continue
    url = enc.attrib.get("url")
    if not url:
        continue
    ver = sparkle_version(enc)
    candidates.append((ver, url))

if not candidates:
    raise SystemExit("No enclosure url found")

with_ver = [c for c in candidates if c[0] is not None]
if with_ver:
    with_ver.sort(key=lambda x: x[0], reverse=True)
    print(with_ver[0][1])
else:
    print(candidates[0][1])
PY
)"

echo "Latest URL: $DL_URL"

# Download (strip query string for filename)
FILE="$WORKDIR/$(basename "${DL_URL%%\?*}")"
curl -fL "$DL_URL" -o "$FILE"

echo "Downloaded: $FILE"
file "$FILE" || true

log_team_id() {
  local app_path="$1"

  local team_id=""
  team_id="$(
    /usr/bin/codesign -dv --verbose=4 "$app_path" 2>&1 \
      | awk -F= '/^TeamIdentifier=/ {print $2; exit}'
  )" || true

  if [[ -n "${team_id:-}" ]]; then
    echo "Team ID: ${team_id}  (${app_path})"
  else
    echo "Team ID: (not found)  (${app_path})"
  fi
}

install_app_from_dir() {
  local src_app="$1"
  local dest="/Applications/$(basename "$src_app")"

  echo "Installing: $dest"
  sudo rsync -a --delete "$src_app" "$dest"

  # Log Team ID (no hard-fail)
  log_team_id "$dest"

  # Soft checks (no hard-fail)
  sudo /usr/bin/codesign -dv --verbose=2 "$dest" >/dev/null 2>&1 || true
  sudo /usr/sbin/spctl --assess --type execute "$dest" >/dev/null 2>&1 || true
}

if [[ "$FILE" == *.pkg ]]; then
  echo "Installing PKG..."
  /usr/sbin/pkgutil --check-signature "$FILE" || true
  sudo /usr/sbin/installer -pkg "$FILE" -target /
elif [[ "$FILE" == *.dmg ]]; then
  echo "Installing from DMG..."
  MOUNT="$WORKDIR/mnt"
  mkdir -p "$MOUNT"
  /usr/bin/hdiutil attach "$FILE" -nobrowse -mountpoint "$MOUNT" >/dev/null

  APP_PATH="$(find "$MOUNT" -maxdepth 2 -name "*.app" -print -quit || true)"
  if [[ -z "${APP_PATH:-}" ]]; then
    echo "No .app found in DMG. Contents:" >&2
    ls -la "$MOUNT" >&2
    /usr/bin/hdiutil detach "$MOUNT" >/dev/null || true
    exit 2
  fi

  install_app_from_dir "$APP_PATH"
  /usr/bin/hdiutil detach "$MOUNT" >/dev/null
elif [[ "$FILE" == *.zip ]]; then
  echo "Installing from ZIP..."
  /usr/bin/unzip -q "$FILE" -d "$WORKDIR/unzip"

  APP_PATH="$(find "$WORKDIR/unzip" -maxdepth 3 -name "*.app" -print -quit || true)"
  if [[ -z "${APP_PATH:-}" ]]; then
    echo "No .app found in ZIP. Contents:" >&2
    find "$WORKDIR/unzip" -maxdepth 2 -print >&2
    exit 2
  fi

  install_app_from_dir "$APP_PATH"
else
  echo "Unknown installer format: $FILE" >&2
  exit 2
fi

echo "== ${APP_NAME}: done =="
