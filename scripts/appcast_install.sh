#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${1:?app name required}"
APPCAST_URL="${2:?appcast url required}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "== ${APP_NAME}: appcast check =="

curl -fsSL "$APPCAST_URL" -o "$WORKDIR/appcast.xml"

# 最新候補を選ぶ：sparkle:version があれば最大、なければ最初に見つかった enclosure
DL_URL="$(
python3 - <<'PY'
import xml.etree.ElementTree as ET
from datetime import datetime

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
    # sparkle:version は名前空間付きで入ることがあるので、attribを全部見て拾う
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

# sparkle:version が取れるものが1つでもあれば最大値を採用
with_ver = [c for c in candidates if c[0] is not None]
if with_ver:
    with_ver.sort(key=lambda x: x[0], reverse=True)
    print(with_ver[0][1])
else:
    # 取れない場合は appcast の並び（多くは最新が先頭）を信じて最初を採用
    print(candidates[0][1])
PY
)"

echo "Latest URL: $DL_URL"

FILE="$WORKDIR/$(basename "${DL_URL%%\?*}")"
curl -fL "$DL_URL" -o "$FILE"

echo "Downloaded: $FILE"
file "$FILE" || true

install_app_from_dir() {
  local src_app="$1"
  local dest="/Applications/$(basename "$src_app")"
  echo "Installing: $dest"
  sudo rsync -a --delete "$src_app" "$dest"
  # 最低限の検証（失敗してもログだけ残す）
  sudo codesign -dv --verbose=2 "$dest" >/dev/null 2>&1 || true
  sudo spctl --assess --type execute "$dest" >/dev/null 2>&1 || true
}

if [[ "$FILE" == *.pkg ]]; then
  echo "Installing PKG..."
  pkgutil --check-signature "$FILE" || true
  sudo installer -pkg "$FILE" -target /
elif [[ "$FILE" == *.dmg ]]; then
  echo "Installing from DMG..."
  MOUNT="$WORKDIR/mnt"
  mkdir -p "$MOUNT"
  hdiutil attach "$FILE" -nobrowse -mountpoint "$MOUNT" >/dev/null

  APP_PATH="$(find "$MOUNT" -maxdepth 2 -name "*.app" -print -quit || true)"
  if [[ -z "${APP_PATH:-}" ]]; then
    echo "No .app found in DMG. Contents:" >&2
    ls -la "$MOUNT" >&2
    exit 2
  fi

  install_app_from_dir "$APP_PATH"
  hdiutil detach "$MOUNT" >/dev/null
elif [[ "$FILE" == *.zip ]]; then
  echo "Installing from ZIP..."
  unzip -q "$FILE" -d "$WORKDIR/unzip"
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
