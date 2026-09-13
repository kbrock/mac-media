# mac-media Decisions

## Firewall: only nginx, ssh, cockpit, mdns, and Govee discovery are opened

- **80/443/tcp** — nginx, the only path in for every service (jellyfin,
  navidrome, homeassistant proxy through it via `127.0.0.1`, no direct
  LAN port needed for them).
- **ssh, cockpit** — admin access.
- **mdns service (5353/udp)** — Home Assistant's own zeroconf/discovery,
  not a system Avahi daemon (none installed).
- **4001-4003/udp** — Govee LAN light discovery. UDP broadcast, can't be
  proxied through nginx, so opened directly.
