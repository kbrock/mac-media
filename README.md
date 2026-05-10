# mac-media

Personal home server. Runs media and smart-home services for the household.

## Foundations

- **Podman + Quadlet.** Ships with Fedora, systemd-native, no daemon.
- **Quadlet units.** Packaging is the unit file, no RPM or Helm.
- **Host network mode.** Home Assistant needs mDNS/SSDP for LAN device discovery.
- **Bind mounts.** Service data lives under `~/srv/<service>/`, visible on disk.

## Services

- [x] [Home Assistant](quadlet/homeassistant.container)
- [x] [Jellyfin](quadlet/jellyfin.container)
- [x] [Navidrome](quadlet/navidrome.container)
- [x] [Landing page](quadlet/landing.container)
- [ ] SSO

## Rebuild from scratch

From a fresh Fedora install on the server, in a clone of this repo:

```bash
./setup_mac.sh   # interactive: cockpit, podman linger, firewall, NAS mounts (see mac-media-setup.md)
mkdir -p ~/srv/{landing,jellyfin/{config,cache},homeassistant/config,navidrome/data}
cp quadlet/*.container ~/.config/containers/systemd/
systemctl --user daemon-reload && systemctl --user enable --now homeassistant jellyfin landing navidrome
```

Then restore the Home Assistant backup via the HA web UI if available.
