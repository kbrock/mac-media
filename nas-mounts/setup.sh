#!/bin/bash
# Run this on mac-media with: sudo bash setup.sh
# Sets up SMB mounts for NAS media shares.
#
# Reads credentials from /etc/samba/private/nas-movies.cred (must exist before running).
# Create it manually with:
#   sudo mkdir -p /etc/samba/private
#   sudo tee /etc/samba/private/nas-movies.cred > /dev/null << 'EOF'
#   username=YOUR_USER
#   password=YOUR_PASSWORD
#   domain=WORKGROUP
#   EOF
#   sudo chmod 600 /etc/samba/private/nas-movies.cred

set -e

CRED_FILE=/etc/samba/private/nas-movies.cred

if [ ! -f "$CRED_FILE" ]; then
  echo "Missing credentials file: $CRED_FILE"
  echo "See header of this script for setup instructions."
  exit 1
fi

# Mount points
mkdir -p /mnt/nas/video /mnt/nas/music
echo "Created mount points"

# Systemd mount: Video
cat > /etc/systemd/system/mnt-nas-video.mount << EOF
[Unit]
Description=NAS Video Share
After=network-online.target
Wants=network-online.target

[Mount]
What=//diskstation/Video
Where=/mnt/nas/video
Type=cifs
Options=credentials=$CRED_FILE,vers=3.0,ro,uid=1000,gid=1000,iocharset=utf8,file_mode=0444,dir_mode=0555
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

# Systemd mount: Music
cat > /etc/systemd/system/mnt-nas-music.mount << EOF
[Unit]
Description=NAS Music Share
After=network-online.target
Wants=network-online.target

[Mount]
What=//diskstation/Music
Where=/mnt/nas/music
Type=cifs
Options=credentials=$CRED_FILE,vers=3.0,ro,uid=1000,gid=1000,iocharset=utf8,file_mode=0444,dir_mode=0555
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

# Automount units (mount on first access, not at boot - avoids boot hangs if NAS is down)
cat > /etc/systemd/system/mnt-nas-video.automount << 'EOF'
[Unit]
Description=Automount NAS Video Share

[Automount]
Where=/mnt/nas/video
TimeoutIdleSec=0

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/mnt-nas-music.automount << 'EOF'
[Unit]
Description=Automount NAS Music Share

[Automount]
Where=/mnt/nas/music
TimeoutIdleSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mnt-nas-video.automount
systemctl enable --now mnt-nas-music.automount

echo "Testing video mount..."
ls /mnt/nas/video/ | head -5
echo "Testing music mount..."
ls /mnt/nas/music/ | head -5

echo "Done! Mounts will auto-connect on first access."
