#!/usr/bin/env bash
# Mac Mini (mac-media) server setup from bare Fedora install.
#
# Idempotent: state-check before each action. Only prompts on destructive
# or rate-limited actions (initial LE cert issuance).
# Bootstrap (ethernet, getting the repo on the box) is in setup_ethernet.sh.
#
# Run section by section; do not pipe to bash blind.
#
# Last validated: 2026-05 on Fedora 43

set -u
SECTION="${1:-}"

ask() {
  local prompt="$1" default="${2:-Y}"
  local hint="[Y/n]"
  [ "$default" = "N" ] && hint="[y/N]"
  read -r -p "$prompt $hint " ans
  if [ -z "$ans" ]; then ans="$default"; fi
  case "$ans" in [Yy]*) return 0;; *) return 1;; esac
}

section() {
  local name="$1"
  if [ -n "$SECTION" ] && [ "$SECTION" != "$name" ]; then return 1; fi
  echo ""
  echo "=== $name ==="
  return 0
}

############################################################################
# WIFI (reference only — DO NOT enable on this server)
############################################################################
# History: we tried to use wifi on this Mac Mini once. Saga:
#   - Need to bootstrap with internet to get RPMs
#   - Plugged into another Mac, used Internet Sharing to provide ethernet
#   - Added rpmfusion-free + rpmfusion-nonfree
#   - Installed akmod-wl + broadcom-wl + kernel-devel + Development Tools
#   - akmods --force --rebuild to compile
#   - sudo modprobe wl, wifi worked
#   - Moved to basement, no monitor
#   - dnf update changed kernel, akmods didn't auto-rebuild
#   - No wifi, no console -> had to drag the box upstairs to fix
# Conclusion: wifi on a headless server you treat as appliance is a tax we
# don't want to pay. Server stays wired.
#
# If you ever need wifi on this hardware:
#   sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
#   sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
#   sudo dnf install -y akmod-wl broadcom-wl kernel-devel @development-tools
#   sudo akmods --force --rebuild
#   sudo modprobe wl

# Disabled (radios off, drivers removed). Flip to `if section radios-off; then`
# if wifi/BT come back.
if false; then  # was: section radios-off
  if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    echo "Wifi already soft-blocked."
  else
    nmcli radio wifi off
  fi

  if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
    echo "Bluetooth already soft-blocked."
  else
    sudo rfkill block bluetooth
  fi
fi

############################################################################
# KERNEL POST-UPDATE CHECK (run AFTER `dnf update`, BEFORE reboot)
############################################################################
# Background: third-party kernel modules (akmod-wl, akmod-nvidia, dkms-*) are
# rebuilt against each new kernel. If you reboot before akmods completes, you
# boot into a kernel without your modules. On a headless box, that means
# carrying the server somewhere with a monitor.
#
# Run this section after every `sudo dnf update` that includes a kernel.
# Reboot ONLY when this section reports clean.
#
# Disabled: no akmod-* installed. kmod/DKMS modules rebuild synchronously
# inside the dnf transaction so they don't need this check. Re-enable below
# if akmods come back.
if false; then  # was: section kernel-check
  running=$(uname -r)
  newest=$(rpm -q kernel-core --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" | sort -V | tail -1)
  echo "Running kernel: $running"
  echo "Newest kernel:  $newest"

  echo ""
  echo "Third-party akmods installed:"
  rpm -qa | grep -E '^akmod-' || echo "  (none — nothing to worry about)"

  echo ""
  echo "Built kmod-* packages:"
  rpm -qa | grep -E '^kmod-' || echo "  (none)"

  echo ""
  if rpm -qa | grep -q '^akmod-'; then
    echo "Force-rebuild all akmods against newest kernel? This is the safety check."
    sudo akmods --force --rebuild
  fi
fi

############################################################################
# 1. BASE PACKAGES
############################################################################
if section base-packages; then
  sudo dnf install -y \
    cockpit \
    nginx \
    certbot python3-certbot-dns-cloudflare

  systemctl is-enabled cockpit.socket &>/dev/null || sudo systemctl enable --now cockpit.socket
fi

############################################################################
# 2. FIREWALL
############################################################################
if section firewall; then
  add_svc() {
    if sudo firewall-cmd --list-services | grep -qw "$1"; then
      echo "  service $1: already open"
    else
      sudo firewall-cmd --permanent --add-service="$1"
    fi
  }
  add_port() {
    if sudo firewall-cmd --list-ports | grep -qw "$1"; then
      echo "  port $1: already open"
    else
      sudo firewall-cmd --permanent --add-port="$1"
    fi
  }

  add_svc cockpit
  add_svc mdns       # 5353/udp for HA device discovery
  add_port 80/tcp    "nginx http"
  add_port 443/tcp   "nginx https"
  add_port 4533/tcp  "navidrome"
  add_port 8096/tcp  "jellyfin"
  add_port 8123/tcp  "home assistant"

  sudo firewall-cmd --reload
fi

############################################################################
# 3. PODMAN (user-mode containers)
############################################################################
if section podman; then
  systemctl --user is-enabled podman.socket &>/dev/null || systemctl --user enable --now podman.socket

  if loginctl show-user "$(whoami)" 2>/dev/null | grep -q 'Linger=yes'; then
    echo "linger: already enabled for $(whoami)"
  else
    loginctl enable-linger "$(whoami)"
  fi
fi

############################################################################
# 4. NGINX (RPM, reverse proxy)
############################################################################
if section nginx; then
  systemctl is-enabled nginx &>/dev/null || sudo systemctl enable --now nginx

  if [ "$(getsebool httpd_can_network_connect 2>/dev/null | awk '{print $3}')" = "on" ]; then
    echo "SELinux httpd_can_network_connect: already on"
  else
    sudo setsebool -P httpd_can_network_connect 1
  fi

  echo "Then: scp nginx/nginx.conf and nginx/home.conf into /etc/nginx/"
fi

############################################################################
# 5. CERTBOT (Let's Encrypt wildcard via Cloudflare DNS-01)
############################################################################
# certbot + python3-certbot-dns-cloudflare via dnf. Renewal via
# certbot-renew.timer (ships with the RPM). Credentials in
# /etc/letsencrypt/cloudflare.ini (600 root:root), sourced from
# ./certbot/cloudflare.ini in staging (gitignored, never committed).
# Initial --certonly is rate-limited — guarded by cert check AND prompt.
# SELinux: certbot RPM sets fcontext policy; restorecon -RF applies it.

if section certbot; then
  if [ -f /etc/letsencrypt/cloudflare.ini ]; then
    echo "/etc/letsencrypt/cloudflare.ini: already installed"
  elif [ -f ./certbot/cloudflare.ini ]; then
    sudo install -m 600 -o root -g root ./certbot/cloudflare.ini /etc/letsencrypt/cloudflare.ini
    rm ./certbot/cloudflare.ini
  else
    echo "  Skip — ./certbot/cloudflare.ini not present in staging."
  fi

  if [ -f /etc/letsencrypt/live/home.thebrocks.net/fullchain.pem ]; then
    echo "Cert: already issued for home.thebrocks.net"
  elif ask "Run certbot certonly for home.thebrocks.net + wildcard (one-time, rate-limited)?"; then
    sudo certbot certonly \
      --dns-cloudflare \
      --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
      --email keenan@thebrocks.net \
      --agree-tos \
      -d home.thebrocks.net \
      -d '*.home.thebrocks.net'
    sudo restorecon -RFv /etc/letsencrypt/
  fi

  systemctl is-enabled certbot-renew.timer &>/dev/null || sudo systemctl enable --now certbot-renew.timer

  if [ -f ~/.ssh/id_diskstation ]; then
    echo "diskstation SSH key: already present"
  else
    ssh-keygen -t ed25519 -f ~/.ssh/id_diskstation -N ""
    echo "diskstation SSH key: generated"
  fi

  echo "(sudo: enter kbrock's password on mac-media)"
  sudo bash -c '
    if [ -f /root/.ssh/id_diskstation ]; then
      echo "diskstation SSH key: already in root"
    else
      cp /home/kbrock/.ssh/id_diskstation /root/.ssh/id_diskstation
      cp /home/kbrock/.ssh/id_diskstation.pub /root/.ssh/id_diskstation.pub
      chmod 600 /root/.ssh/id_diskstation
      echo "diskstation SSH key: copied to root"
    fi

    HOOK=/etc/letsencrypt/renewal-hooks/deploy/push-cert-diskstation.sh
    if [ -f "${HOOK}" ]; then
      echo "Certbot deploy hook: already installed"
    else
      install -m 755 -o root -g root ./certbot/push-cert-diskstation.sh "${HOOK}"
      echo "Certbot deploy hook: installed"
    fi
  '

  echo "(enter kbrock@diskstation password to authorize this key)"
  ssh-copy-id -f -i ~/.ssh/id_diskstation.pub kbrock@diskstation
fi

############################################################################
# 6. NAS MOUNTS (SMB to Synology)
############################################################################
# Unit files in ./nas-mounts/. Credential file is created manually as root —
# password is sensitive, never in repo, never scp'd. To create:
#   sudo mkdir -p /etc/samba/private
#   sudo tee /etc/samba/private/nas-movies.cred > /dev/null << 'EOF'
#   username=YOUR_USER
#   password=YOUR_PASSWORD
#   domain=WORKGROUP
#   EOF
#   sudo chmod 600 /etc/samba/private/nas-movies.cred

if section nas-mounts; then
  if [ ! -f /etc/samba/private/nas-movies.cred ]; then
    echo "Missing /etc/samba/private/nas-movies.cred — see comment above."
  elif [ -f /etc/systemd/system/mnt-nas-video.mount ]; then
    echo "NAS mount units: already installed"
  else
    sudo mkdir -p /mnt/nas/video /mnt/nas/music
    sudo install -m 644 nas-mounts/mnt-nas-video.mount      /etc/systemd/system/
    sudo install -m 644 nas-mounts/mnt-nas-music.mount      /etc/systemd/system/
    sudo install -m 644 nas-mounts/mnt-nas-video.automount  /etc/systemd/system/
    sudo install -m 644 nas-mounts/mnt-nas-music.automount  /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable --now mnt-nas-video.automount mnt-nas-music.automount
  fi
fi

############################################################################
# 7. CONTAINERS (deploy quadlets)
############################################################################
if section containers; then
  echo "From your laptop:"
  echo "  scp quadlet/*.container mac-media:~/.config/containers/systemd/"
  echo ""
  echo "On mac-media:"
  echo "  mkdir -p ~/srv/{landing,jellyfin/{config,cache},homeassistant/config,navidrome/data}"
  echo "  systemctl --user daemon-reload"
  echo "  systemctl --user enable --now homeassistant jellyfin landing navidrome"
fi
