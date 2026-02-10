#!/usr/bin/env bash
set -euo pipefail

echo "== mac-setup start =="

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "ERROR: Don't run setup.sh with sudo/root. Run as a normal admin user." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ENABLE_TOUCHID_SUDO=0
INSTALL_ZSHRC=0

for arg in "$@"; do
  case "$arg" in
    --enable-touchid-sudo) ENABLE_TOUCHID_SUDO=1 ;;
    --install-zshrc)       INSTALL_ZSHRC=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./setup.sh [options]
  --enable-touchid-sudo   Enable Touch ID for sudo (modifies /etc/pam.d/sudo)
  --install-zshrc         Install repo zshrc to ~/.zshrc (backs up existing)
EOF
      exit 0
      ;;
    *) ;;
  esac
done

# ---- Optional: enable Touch ID for sudo ----
if [[ "$ENABLE_TOUCHID_SUDO" -eq 1 ]]; then
  if [[ -x "$SCRIPT_DIR/scripts/enable_touchid_sudo.sh" ]]; then
    "$SCRIPT_DIR/scripts/enable_touchid_sudo.sh"
  else
    echo "WARN: scripts/enable_touchid_sudo.sh not found/executable; skipping."
  fi
fi

# ---- Sudo warm-up (once) ----
echo "== Sudo authentication (once) =="
sudo -v
# keep sudo alive while this script runs
( while true; do sudo -n true; sleep 60; kill -0 "$$" >/dev/null 2>&1 || exit; done ) 2>/dev/null &

# ---- 1) Install Homebrew (idempotent) ----
if [[ -x "$SCRIPT_DIR/scripts/brew_install.sh" ]]; then
  "$SCRIPT_DIR/scripts/brew_install.sh"
else
  echo "ERROR: scripts/brew_install.sh not found/executable." >&2
  exit 1
fi

# ---- 2) Ensure brew available in THIS shell ----
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

# ---- 3) Brewfile (idempotent-ish) ----
BUNDLE_OK=1
if [[ -f "$SCRIPT_DIR/Brewfile" ]]; then
  echo "== brew bundle (no-upgrade) =="
  if ! brew bundle --file "$SCRIPT_DIR/Brewfile" --no-upgrade; then
    echo "WARN: brew bundle failed (continuing)."
    BUNDLE_OK=0
  fi
else
  echo "WARN: Brewfile not found; skipping brew bundle."
fi

# ---- 4) Install ~/.zshrc from repo (optional) ----
if [[ "$INSTALL_ZSHRC" -eq 1 ]]; then
  echo "== Install .zshrc =="
  if [[ -f "$SCRIPT_DIR/zshrc" ]]; then
    if [[ -f "$HOME/.zshrc" ]]; then
      BACKUP="$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
      cp -p "$HOME/.zshrc" "$BACKUP"
      echo "Backed up existing ~/.zshrc -> $BACKUP"
    fi
    cp -p "$SCRIPT_DIR/zshrc" "$HOME/.zshrc"
    echo "Installed $HOME/.zshrc"
    echo "NOTE: Open a new Terminal window (or run: source ~/.zshrc) to apply."
  else
    echo "WARN: repo zshrc not found; skipping."
  fi
else
  echo "== Skip .zshrc install (use --install-zshrc to enable) =="
fi

# ---- 5) Prisma Access Browser install ----
if [[ -x "$SCRIPT_DIR/scripts/pab_install.sh" ]]; then
  echo "== Prisma Access Browser install =="
  if ! "$SCRIPT_DIR/scripts/pab_install.sh" packaged; then
    echo "WARN: PAB install failed (continuing)."
  fi
else
  echo "WARN: scripts/pab_install.sh not found/executable; skipping PAB install."
fi

# ---- 6) Dock setup ----
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
  echo "  brew bundle --file \"$SCRIPT_DIR/Brewfile\" --no-upgrade"
fi
