#!/usr/bin/env bash
set -euo pipefail

echo "== mac-setup start =="

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "ERROR: Don't run setup.sh with sudo/root. Run as a normal admin user." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENABLE_TOUCHID_SUDO=0
for arg in "$@"; do
  case "$arg" in
    --enable-touchid-sudo) ENABLE_TOUCHID_SUDO=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./setup.sh [options]
  --enable-touchid-sudo   Enable Touch ID for sudo (modifies /etc/pam.d/sudo)
EOF
      exit 0
      ;;
    *) ;;
  esac
done

# Optional: enable Touch ID sudo first
if [[ "$ENABLE_TOUCHID_SUDO" -eq 1 ]]; then
  if [[ -x "$SCRIPT_DIR/scripts/enable_touchid_sudo.sh" ]]; then
    "$SCRIPT_DIR/scripts/enable_touchid_sudo.sh"
  else
    echo "WARN: scripts/enable_touchid_sudo.sh not found/executable; skipping."
  fi
fi

# Sudo warm-up (once)
echo "== Sudo authentication (once) =="
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done ) 2>/dev/null &

# 1) Install Homebrew (idempotent)
"$SCRIPT_DIR/scripts/brew_install.sh"

# 2) Ensure brew in this shell
if ! command -v brew >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "ERROR: brew command not found after install." >&2
  exit 1
fi

BUNDLE_OK=1

# 3) Brewfile (skip upgrades; continue even if failure)
if [[ -f "$SCRIPT_DIR/Brewfile" ]]; then
  echo "== brew bundle (no-upgrade) =="
  if ! brew bundle --file "$SCRIPT_DIR/Brewfile" --no-upgrade; then
    echo "WARN: brew bundle failed (continuing)."
    BUNDLE_OK=0
  fi
else
  echo "WARN: Brewfile not found; skipping brew bundle."
fi

# 4) Prisma Access Browser
if [[ -x "$SCRIPT_DIR/scripts/pab_install.sh" ]]; then
  echo "== Prisma Access Browser install =="
  if ! "$SCRIPT_DIR/scripts/pab_install.sh" packaged; then
    echo "WARN: PAB install failed (continuing)."
  fi
else
  echo "WARN: scripts/pab_install.sh not found/executable; skipping PAB install."
fi

# 5) Dock
if [[ -x "$SCRIPT_DIR/scripts/dock_setup.sh" ]]; then
  echo "== Dock setup =="
  if ! "$SCRIPT_DIR/scripts/dock_setup.sh"; then
    echo "WARN: Dock setup failed."
  fi
else
  echo "WARN: scripts/dock_setup.sh not found/executable; skipping Dock setup."
fi

echo "== mac-setup done =="

if [[ "$BUNDLE_OK" -eq 0 ]]; then
  echo "NOTE: Some Brewfile items failed. You can re-run brew bundle later:"
  echo "  brew bundle --file \"$SCRIPT_DIR/Brewfile\""
fi

