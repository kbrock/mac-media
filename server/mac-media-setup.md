# Mac Mini Setup (2012 Intel "mac-media", Fedora 43)

Fedora Server installed from USB. Wired ethernet only — the `tg3` driver
loads automatically.

## One-time setup

```bash
# cockpit
sudo dnf install cockpit
sudo systemctl enable --now cockpit.socket
sudo firewall-cmd --permanent --add-service=cockpit
sudo firewall-cmd --reload

# podman (rootless, survives logout)
loginctl enable-linger kbrock
systemctl --user enable --now podman.socket

# disable wifi and bluetooth radios (not needed, reduces RF interference)
nmcli radio wifi off
rfkill block bluetooth

# remove broadcom wifi/bt drivers (not needed, breaks kernel updates via DKMS)
sudo dnf remove akmod-wl broadcom-wl
```

## After `dnf update` (before rebooting)

No monitor — a bad kernel means hauling the machine upstairs.

```bash
# find the new kernel version
NEW_KERN=$(rpm -qa kernel-core --last | head -1 | sed 's/kernel-core-//')

# verify modules exist
ls /lib/modules/$NEW_KERN/

# check for broken module dependencies
sudo depmod -a $NEW_KERN

# confirm ethernet driver is in initramfs (tg3 = Mac Mini ethernet)
lsinitrd /boot/initramfs-$NEW_KERN.img | grep tg3

# if tg3 is missing, rebuild initramfs
sudo dracut -f /boot/initramfs-$NEW_KERN.img $NEW_KERN
```

Only reboot after tg3 shows up in the initramfs check.

## If wifi/BT is ever needed

Wifi requires the proprietary Broadcom driver from rpmfusion.
It rebuilds on every kernel update via DKMS.

```bash
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install akmod-wl broadcom-wl
nmcli radio wifi on
rfkill unblock bluetooth
```

## Network

- Interface: `enp1s0f0` (ethernet)
- Static IP: reserve via Unifi DHCP (Clients > mac-media > Fixed IP)
- DumbHome VLAN trunk: switch port for mac-media (USW Lite 16) — Native
  VLAN: Default (BHome), Tagged VLAN Management: Custom, select
  DumbHome. Prerequisite for `setup_mac.sh`'s `dumbhome-vlan` section.

### First-console bootstrap

Fresh install, no network yet. Type the commands from `setup_ethernet.sh`
at the Mac mini's console. Once ethernet is up, run `make setup` from your
laptop to push the repo.

## DNS

Network-side setup (UDM/fortknox) — see `network.md` § DNS plan.

## Home Assistant

Deploy steps, firewall ports, HACS install, integrations, and nginx reverse
proxy config: see [`inventory/home_assistant.md`](../inventory/home_assistant.md).

## Jellyfin — SSO plugin

Install via Jellyfin UI (one-time, survives container restarts via plugin data volume):

1. Dashboard → Plugins → Repositories → Add:
   `https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json`
2. Restart Jellyfin: `systemctl --user restart jellyfin`
3. Dashboard → Plugins → Catalog → hard-refresh the browser (Cmd+Shift+R)
4. Find **SSO-Auth**, install, restart Jellyfin again.

Plugin v4.x targets Jellyfin 10.11+. If the catalog shows nothing after restart, hard-refresh — the catalog caches aggressively.
