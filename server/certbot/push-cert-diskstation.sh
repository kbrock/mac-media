#!/bin/bash
# Certbot deploy hook: push renewed wildcard cert to diskstation.
# Installed to /etc/letsencrypt/renewal-hooks/deploy/ by setup_mac.sh.
# Runs as root after every successful certbot renewal.
#
# Prereq: root@mac-media key authorized on kbrock@diskstation (via setup_nas.sh).
# kbrock has NOPASSWD sudo on Synology (admin group).

set -euo pipefail

CERT_DIR="/etc/letsencrypt/live/home.thebrocks.net"
KEY="/root/.ssh/id_diskstation"
SSH="ssh -i ${KEY} -o StrictHostKeyChecking=accept-new"

echo "Pushing cert to diskstation"
tar -h -C "${CERT_DIR}" -c cert.pem chain.pem fullchain.pem privkey.pem \
  | ${SSH} kbrock@diskstation 'sudo bash ~/install-cert.sh'
echo "Done."
