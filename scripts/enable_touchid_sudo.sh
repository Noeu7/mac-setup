#!/usr/bin/env bash
set -euo pipefail

# Enable Touch ID for sudo by adding:
#   auth       sufficient     pam_tid.so
# to the top of /etc/pam.d/sudo
#
# Idempotent:
# - If already present, do nothing
# Safe-ish:
# - Creates a timestamped backup
#
# Requires:
# - Running as normal user (NOT root)
# - Will ask sudo password once

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  echo "ERROR: Don't run this script as root. Run as a normal admin user." >&2
  exit 1
fi

SUDO_PAM="/etc/pam.d/sudo"
LINE="auth       sufficient     pam_tid.so"

echo "== Enable Touch ID for sudo =="

if [[ ! -f "$SUDO_PAM" ]]; then
  echo "ERROR: $SUDO_PAM not found." >&2
  exit 1
fi

# If already enabled, exit
if /usr/bin/grep -qE '^\s*auth\s+sufficient\s+pam_tid\.so\s*$' "$SUDO_PAM"; then
  echo "Touch ID for sudo already enabled. (pam_tid.so found)"
  exit 0
fi

echo "This will modify $SUDO_PAM (requires sudo)."
sudo -v

BACKUP="${SUDO_PAM}.bak.$(date +%Y%m%d-%H%M%S)"
echo "Creating backup: $BACKUP"
sudo /bin/cp -p "$SUDO_PAM" "$BACKUP"

# Insert at first line
# macOS sed needs: -i '' (empty extension)
echo "Patching $SUDO_PAM ..."
sudo /usr/bin/sed -i '' "1s|^|${LINE}\n|" "$SUDO_PAM"

echo "Done. Verifying..."
sudo /usr/bin/head -n 3 "$SUDO_PAM" || true

echo "NOTE: macOS updates may revert this file. Re-run setup with --enable-touchid-sudo if needed."

