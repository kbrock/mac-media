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

## Deploy Home Assistant

```bash
# create directories on server
ssh mac-media 'mkdir -p ~/ha-config ~/.config/containers/systemd'

# copy quadlet file (rootless = user's systemd directory)
scp quadlet/homeassistant.container mac-media:~/.config/containers/systemd/

# start it
ssh mac-media 'systemctl --user daemon-reload && systemctl --user start homeassistant'
```

## Open firewall

```bash
sudo firewall-cmd --permanent --add-port=8123/tcp
sudo firewall-cmd --permanent --add-port=4001-4003/udp
sudo firewall-cmd --reload
```

- 8123/tcp — Home Assistant web UI
- 4001-4003/udp — Govee LAN light discovery

## Install HACS (community integrations, optional)

Not needed for built-in integrations. Required for community-only integrations.

```bash
podman exec -it homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"
systemctl --user restart homeassistant
```

Then in HA: Settings > Integrations > Add > HACS. Requires a GitHub personal access token (no scopes needed).

## Integrations

- **Govee lights**: built-in "Govee lights local". Enable LAN control per light in the Govee app first.
- **Ecobee**: TBD — developer API removed, HomeKit pairing not discovering.
- **Pulsar charger**: TBD
