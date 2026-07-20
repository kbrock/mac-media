#!/usr/bin/env bash
# Synology NAS (diskstation) setup — run from local mac.
#
# Idempotent: state-check before each action.
# Run from the repo root: bash server/setup_nas.sh [section]
#
# Prereq: SSH enabled on diskstation (DSM → Terminal & SNMP → Enable SSH).
# Prereq: setup_mac.sh certbot section run first (generates SSH key, ssh-copy-id to diskstation).
# Last validated: 2026-07 on DSM 7

set -u
SECTION="${1:-}"

section() {
  local name="$1"
  if [ -n "$SECTION" ] && [ "$SECTION" != "$name" ]; then return 1; fi
  echo ""
  echo "=== $name ==="
  return 0
}

############################################################################
# 1. CERT PUSH (install helper script + sudoers entry)
############################################################################
# mac-media's certbot deploy hook SSHes as kbrock@diskstation and pipes
# cert files to ~/install-cert.sh via `sudo bash ~/install-cert.sh`.

if section cert-push; then
  # Always overwrite — script may have changed
  ssh kbrock@diskstation 'cat > ~/install-cert.sh && chmod 755 ~/install-cert.sh' < server/certbot/diskstation-install-cert.sh
  echo "install-cert.sh: installed"

  # Allow kbrock to run install-cert.sh as root without a password
  SUDOERS_LINE='kbrock ALL=(ALL) NOPASSWD: /bin/bash /var/services/homes/kbrock/install-cert.sh'
  if ssh kbrock@diskstation "grep -qF '${SUDOERS_LINE}' /etc/sudoers /etc/sudoers.d/* 2>/dev/null"; then
    echo "sudoers: already configured"
  else
    ssh kbrock@diskstation "echo '${SUDOERS_LINE}' | sudo tee /etc/sudoers.d/install-cert > /dev/null && sudo chmod 440 /etc/sudoers.d/install-cert"
    echo "sudoers: configured"
  fi
fi
