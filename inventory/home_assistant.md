# Home Assistant

Config snapshot lives in [`server/homeassistant/`](../server/homeassistant/)
(config, automations, scripts, scenes, dashboard). Manual snapshot today —
see backlog below for wiring it into the scp-deploy pattern.

For *why* certain HA settings were chosen, see
[home-assistant-decisions.md](home-assistant-decisions.md). For the
dual-homed network wiring that lets HA discover DumbHome IoT devices, see
[network.md](network.md) and [network-decisions.md](network-decisions.md).

## Deploy

```bash
# create directories on server
ssh mac-media 'mkdir -p ~/ha-config ~/.config/containers/systemd'

# copy quadlet file (rootless = user's systemd directory)
scp quadlet/homeassistant.container mac-media:~/.config/containers/systemd/

# start it
ssh mac-media 'systemctl --user daemon-reload && systemctl --user start homeassistant'
```

## Firewall

```bash
sudo firewall-cmd --permanent --add-port=4001-4003/udp
sudo firewall-cmd --reload
```

- 4001-4003/udp — Govee LAN light discovery (UDP broadcast, can't be
  proxied through nginx)

8123/tcp is **not** opened — HA is reached only via nginx
(`hub.home.thebrocks.net` → `127.0.0.1:8123`). The Jellyfin/HA companion
apps are configured with the hostname, not a raw IP:port, so no direct
port is needed.

## nginx reverse proxy config

Edit `~/srv/homeassistant/config/configuration.yaml` on mac-media:

```yaml
homeassistant:
  external_url: https://hub.home.thebrocks.net

http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1

homeassistant:
  auth_providers:
    - type: trusted_networks
      trusted_networks:
        - 127.0.0.1/32
      trusted_users:
        127.0.0.1: kbrock
      allow_bypass_login: true
    - type: homeassistant
```

Then restart: `systemctl --user restart homeassistant`

Without the `http:` block, HA returns 400 when accessed via nginx.

## HACS (community integrations)

Not needed for built-in integrations. Required for community-only integrations.

```bash
podman exec -it homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"
systemctl --user restart homeassistant
```

Then in HA: Settings > Integrations > Add > HACS. Requires a GitHub personal
access token (no scopes needed).

## Installed integrations (audited 2026-09-13)

Built-in (`default_config` + UI-configured, live in `.storage/core.config_entries`
— not represented as YAML, so a rebuild means re-adding these by hand or
restoring an HA Backup):

| Integration | Notes |
|---|---|
| `govee_light_local` | Built-in "Govee lights local". Enable LAN control per light in the Govee app first. |
| `roomba` | Wall-E |
| `wallbox` | Wallbox Portal (Pulsar charger) |
| `homekit_controller` | "Main Floor" |
| `ipp` | HP Color LaserJet MFP M277dw |
| `ecobee` | Ecobee 3 |
| `hydrawise` | Sprinkler controller |
| `sleepiq` | |
| `bluetooth` | hci0 |
| `mobile_app`, `go2rtc`, `met`, `google_translate`, `backup`, `sun` | HA defaults |

HACS-installed (`custom_components/`):

| Component | Status |
|---|---|
| `hacs` | The HACS manager itself |
| `vag_connect` (`its-me-prash/vwgroup-connect-ha`) | Installed, no active config entry — EU-only accounts, skipped for now (see decisions doc) |

## Backlog

- **Dashboard** — Custom Sections dashboard, halfway done:
  - Add device sections (Wall-E, Govee lights, car charger, Emporia plugs)
  - Pick entities per device (skip noise)
  - History graph cards for bed temp / sleep metrics
- **New integrations to add**:
  - Emporia plugs x4
  - Govee H6066 (no LAN; firmware update or skip)
  - VocoLinc SmartBar (HomeKit-native, locations unknown)
  - VW Group Connect — see decisions doc, US-compatible alternative needed
- **Config deploy flow** — currently a manual snapshot into `server/homeassistant/`.
  Decide: wire into scp-to-server deploy pattern like quadlets/nginx, or keep
  read-only for history/diffing.
