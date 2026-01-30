#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   appcast_install.sh <appcast_url> <app_name> [--app-path "/Applications/Foo.app"] [--type packaged|standalone]
#
# What it does:
# - Downloads appcast.xml
# - Parses latest enclosure URL + version
# - Downloads the asset (pkg or dmg)
# - Installs it (pkg installer or copy .app from dmg)
#
# Notes:
# - Idempotent-ish: if app exists and version matches, it skips install.
# - No signature / TeamID verification in this script (you can add later).

APPCAST_URL="${1:-}"
APP_NAME="${2:-}"
shift 2 || true

APP_PATH="/Applications/${APP_NAME}.app"
CHANNEL_TYPE="packaged" # informational only

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path) APP_PATH="$2"; shift 2 ;;
    --type) CHANNEL_TYPE="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$APPCAST_URL" || -z "$APP_NAME" ]]; then
  echo "Usage: appcast_install.sh <appcast_url> <app_name> [--app-path PATH] [--type packaged|standalone]" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

APPCAST_XML="$WORKDIR/appcast.xml"

echo "== ${APP_NAME} (${CHANNEL_TYPE}): appcast check =="
echo "Fetching appcast: $APPCAST_URL"
curl -fsSL "$APPCAST_URL" -o "$APPCAST_XML"

# Parse appcast with Python (NO inline bash expansion in python source)
PARSED="$(
python3 - "$APPCAST_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()

# Sparkle namespace is commonly used.
NS = {
  "sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle",
}

# We want the first <item> in RSS channel (typically latest)
channel = root.find("./channel")
if channel is None:
  print("ERROR\tNo channel node")
  sys.exit(1)

item = channel.find("./item")
if item is None:
  print("ERROR\tNo item node")
  sys.exit(1)

enclosure = item.find("./enclosure")
if enclosure is None:
  print("ERROR\tNo enclosure node")
  sys.exit(1)

url = enclosure.attrib.get("url", "").strip()
if not url:
  print("ERROR\tNo enclosure url")
  sys.exit(1)

# Sparkle version fields (may or may not exist)
ver = enclosure.attrib.get("{%s}version" % NS["sparkle"], "").strip()
shortver = enclosure.attrib.get("{%s}shortVersionString" % NS["sparkle"], "").strip()

# Some feeds put version in <sparkle:version> etc. (less common)
if not ver:
  vtag = item.find("./sparkle:version", NS)
  if vtag is not None and vtag.text:
    ver = vtag.text.strip()

print("OK\t{}\t{}\t{}".format(url, ver, shortver))
PY
)"

STATUS="$(cut -f1 <<<"$PARSED")"
if [[ "$STATUS" != "OK" ]]; then
  echo "ERROR: Failed to parse appcast: $PARSED" >&2
  exit 1
fi

ASSET_URL="$(cut -f2 <<<"$PARSED")"
LATEST_VER="$(cut -f3 <<<"$PARSED")"
LATEST_SHORT="$(cut -f4 <<<"$PARSED")"

echo "Latest asset: $ASSET_URL"
[[ -n "$LATEST_SHORT" ]] && echo "Latest short version: $LATEST_SHORT"
[[ -n "$LATEST_VER" ]] && echo "Latest version: $LATEST_VER"

# If app exists, compare version (best effort)
if [[ -d "$APP_PATH" ]]; then
  INSTALLED_VER=""
  INSTALLED_SHORT=""

  PLIST="$APP_PATH/Contents/Info.plist"
  if [[ -f "$PLIST" ]]; then
    INSTALLED_SHORT="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PLIST" 2>/dev/null || true)"
    INSTALLED_VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$PLIST" 2>/dev/null || true)"
  fi

  if [[ -n "$LATEST_SHORT" && "$INSTALLED_SHORT" == "$LATEST_SHORT" ]]; then
    echo "Already installed: $APP_NAME $INSTALLED_SHORT (matches appcast). Skipping."
    exit 0
  fi
  if [[ -z "$LATEST_SHORT" && -n "$LATEST_VER" && "$INSTALLED_VER" == "$LATEST_VER" ]]; then
    echo "Already installed: $APP_NAME $INSTALLED_VER (matches appcast). Skipping."
    exit 0
  fi

  echo "Installed version: short='$INSTALLED_SHORT' ver='$INSTALLED_VER' -> will update/reinstall."
fi

# Download asset
ASSET_FILE="$WORKDIR/asset"
echo "Downloading asset..."
curl -fL "$ASSET_URL" -o "$ASSET_FILE"

# Determine type by file signature / extension hint
FILE_TYPE="$(file -b "$ASSET_FILE" || true)"
EXT_HINT="$(python3 - <<PY
import os,sys,urllib.parse
u="${ASSET_URL}"
p=urllib.parse.urlparse(u).path
print(os.path.splitext(p)[1].lower())
PY
)"

install_pkg() {
  local pkg="$1"
  echo "Installing PKG: $pkg"
  sudo /usr/sbin/installer -pkg "$pkg" -target /
}

install_dmg() {
  local dmg="$1"
  echo "Mounting DMG: $dmg"
  local mountpoint
  mountpoint="$(/usr/bin/hdiutil attach "$dmg" -nobrowse -readonly | awk 'END{print $NF}')"
  if [[ -z "$mountpoint" ]]; then
    echo "ERROR: Failed to mount DMG" >&2
    exit 1
  fi

  # Find the first .app in the mounted volume
  local found_app
  found_app="$(/usr/bin/find "$mountpoint" -maxdepth 2 -name "*.app" -print -quit)"
  if [[ -z "$found_app" ]]; then
    /usr/bin/hdiutil detach "$mountpoint" -quiet || true
    echo "ERROR: No .app found inside DMG" >&2
    exit 1
  fi

  echo "Copying app to /Applications: $found_app"
  sudo /bin/rm -rf "$APP_PATH" || true
  sudo /bin/cp -R "$found_app" "$APP_PATH"

  /usr/bin/hdiutil detach "$mountpoint" -quiet
  echo "DMG install complete."
}

# If url ends with .pkg or file looks like xar/cpio package, treat as pkg.
if [[ "$EXT_HINT" == ".pkg" ]]; then
  PKG_PATH="$WORKDIR/asset.pkg"
  mv "$ASSET_FILE" "$PKG_PATH"
  install_pkg "$PKG_PATH"
elif [[ "$EXT_HINT" == ".dmg" ]]; then
  DMG_PATH="$WORKDIR/asset.dmg"
  mv "$ASSET_FILE" "$DMG_PATH"
  install_dmg "$DMG_PATH"
else
  # Try to infer from 'file' output
  if grep -qiE 'xar archive|installer|package' <<<"$FILE_TYPE"; then
    PKG_PATH="$WORKDIR/asset.pkg"
    mv "$ASSET_FILE" "$PKG_PATH"
    install_pkg "$PKG_PATH"
  elif grep -qiE 'apple disk image|dmg' <<<"$FILE_TYPE"; then
    DMG_PATH="$WORKDIR/asset.dmg"
    mv "$ASSET_FILE" "$DMG_PATH"
    install_dmg "$DMG_PATH"
  else
    echo "ERROR: Unknown asset type. ext='$EXT_HINT' file='$FILE_TYPE'" >&2
    exit 1
  fi
fi

echo "Installed/updated: $APP_NAME"

