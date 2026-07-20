#!/bin/bash
# Install cert files piped in as a tar stream from mac-media.
# Lives at ~/install-cert.sh on diskstation, called as root via sudo.
# Called by mac-media's certbot deploy hook.
#
# Usage (from mac-media):
#   tar -h -C /etc/letsencrypt/live/home.thebrocks.net -c cert.pem chain.pem fullchain.pem privkey.pem \
#     | ssh kbrock@diskstation 'sudo bash ~/install-cert.sh'

set -euo pipefail

CERT_ID=$(cat /usr/syno/etc/certificate/_archive/DEFAULT)
if [[ -z "${CERT_ID}" ]]; then
  echo "ERROR: could not read cert ID" >&2
  exit 1
fi

STAGING=$(mktemp -d)
trap 'rm -rf "${STAGING}"' EXIT

cat > "${STAGING}/cert.tar"
tar -x -f "${STAGING}/cert.tar" -C "${STAGING}"

for dir in \
  "/usr/syno/etc/certificate/_archive/${CERT_ID}" \
  "/usr/syno/etc/certificate/system/default"; do
  cp "${STAGING}"/*.pem "${dir}/"
done

/usr/syno/bin/synow3tool --gen-all
nginx -s reload
echo "Done (cert id: ${CERT_ID})"
