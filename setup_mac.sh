#!/usr/bin/env bash
# Mac Mini (mac-media) server setup from bare Fedora install.
#
# Idempotent: each section checks current state before doing work.
# Prompts before installing or changing anything.
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
# 1. ETHERNET
############################################################################
if section ethernet; then
  if nmcli device status | awk '/connected/ && $2 != "lo" {found=1} END {exit !found}'; then
    echo "Already have a connected interface."
    nmcli device status
  else
    iface=$(nmcli device status | awk '/disconnected/ {print $1; exit}')
    if [ -n "$iface" ] && ask "Configure $iface for DHCP + autoconnect?"; then
      nmcli connection modify "$iface" ipv4.method auto
      nmcli connection modify "$iface" connection.autoconnect yes
      nmcli connection up "$iface"
    fi
  fi
fi

############################################################################
# 2. WIFI (reference only — DO NOT enable on this server)
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

if section radios-off; then
  if rfkill list wifi 2>/dev/null | grep -q "Soft blocked: yes"; then
    echo "Wifi already soft-blocked."
  elif ask "Disable wifi radio? (we don't use it)"; then
    nmcli radio wifi off
  fi

  if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
    echo "Bluetooth already soft-blocked."
  elif ask "Disable bluetooth? (we don't use it)"; then
    sudo rfkill block bluetooth
  fi
fi

############################################################################
# 3. KERNEL POST-UPDATE CHECK (run AFTER `dnf update`, BEFORE reboot)
############################################################################
# Background: third-party kernel modules (akmod-wl, akmod-nvidia, dkms-*) are
# rebuilt against each new kernel. If you reboot before akmods completes, you
# boot into a kernel without your modules. On a headless box, that means
# carrying the server somewhere with a monitor.
#
# Run this section after every `sudo dnf update` that includes a kernel.
# Reboot ONLY when this section reports clean.

if section kernel-check; then
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
    if ask "Rebuild now?"; then
      sudo akmods --force --rebuild
    fi
  fi
fi

############################################################################
# 4. BASE PACKAGES
############################################################################
if section base-packages; then
  if rpm -q cockpit &>/dev/null; then
    echo "cockpit already installed"
  elif ask "Install cockpit (web admin UI)?"; then
    sudo dnf install -y cockpit
    sudo systemctl enable --now cockpit.socket
  fi
fi

############################################################################
# 5. FIREWALL
############################################################################
if section firewall; then
  add_svc() {
    if sudo firewall-cmd --list-services | grep -qw "$1"; then
      echo "  service $1: already open"
    elif ask "  Open service $1?"; then
      sudo firewall-cmd --permanent --add-service="$1"
    fi
  }
  add_port() {
    if sudo firewall-cmd --list-ports | grep -qw "$1"; then
      echo "  port $1: already open"
    elif ask "  Open port $1 ($2)?"; then
      sudo firewall-cmd --permanent --add-port="$1"
    fi
  }

  add_svc cockpit
  add_svc mdns       # 5353/udp for HA device discovery
  add_port 80/tcp    "nginx"
  add_port 4533/tcp  "navidrome"
  add_port 8096/tcp  "jellyfin"
  add_port 8123/tcp  "home assistant"

  if ask "Reload firewall?"; then
    sudo firewall-cmd --reload
  fi
fi

############################################################################
# 6. PODMAN (user-mode containers)
############################################################################
if section podman; then
  if systemctl --user is-enabled podman.socket &>/dev/null; then
    echo "podman.socket already enabled for user"
  elif ask "Enable user-mode podman socket?"; then
    systemctl --user enable --now podman.socket
  fi

  if loginctl show-user "$(whoami)" 2>/dev/null | grep -q 'Linger=yes'; then
    echo "Linger already enabled for $(whoami)"
  elif ask "Enable lingering (so user services start on boot, not just login)?"; then
    loginctl enable-linger "$(whoami)"
  fi
fi

############################################################################
# 7. NGINX (RPM, reverse proxy on port 80)
############################################################################
if section nginx; then
  if rpm -q nginx &>/dev/null; then
    echo "nginx already installed"
  elif ask "Install nginx (reverse proxy)?"; then
    sudo dnf install -y nginx
    sudo systemctl enable --now nginx
  fi

  if [ "$(getsebool httpd_can_network_connect 2>/dev/null | awk '{print $3}')" = "on" ]; then
    echo "SELinux httpd_can_network_connect: already on"
  elif ask "Allow nginx to proxy to local containers (SELinux boolean)?"; then
    sudo setsebool -P httpd_can_network_connect 1
  fi

  echo "Then: scp nginx/nginx.conf and nginx/mac-media.conf into /etc/nginx/"
fi

############################################################################
# 8. NAS MOUNTS (SMB)
############################################################################
if section nas-mounts; then
  if [ -f /etc/samba/private/nas-movies.cred ]; then
    echo "Credential file exists at /etc/samba/private/nas-movies.cred"
  else
    echo "Create /etc/samba/private/nas-movies.cred first."
    echo "See nas-mounts/setup.sh header for format."
  fi

  if [ -f /etc/systemd/system/mnt-nas-video.mount ]; then
    echo "NAS mount units already installed"
  elif ask "Run nas-mounts/setup.sh?"; then
    sudo bash nas-mounts/setup.sh
  fi
fi

############################################################################
# 9. CONTAINERS (deploy quadlets)
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
